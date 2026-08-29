import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/constants/callables.dart';
import '../../../core/errors/app_exception.dart';

/// Handles sign-in/out and profile provisioning.
///
/// Anonymous sign-in is the default zero-config path (great for a virtual-coin
/// game). Google sign-in is offered as an optional upgrade. In every case the
/// server provisions/refreshes the profile: a Firebase Auth `onCreate` trigger
/// (`provisionUser`) creates it, and we also call `ensureProfileFn` after
/// sign-in as a belt-and-suspenders and to bump `lastActiveAt`.
class AuthRepository {
  AuthRepository({
    required FirebaseAuth auth,
    required FirebaseFunctions functions,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth,
        _functions = functions,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  final GoogleSignIn _googleSignIn;

  User? get currentUser => _auth.currentUser;

  Future<void> signInAnonymously() async {
    try {
      await _auth.signInAnonymously();
      await ensureProfile();
    } on FirebaseAuthException catch (e) {
      throw AppException(e.message ?? 'Could not start a guest session.', code: e.code);
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw const AppException('Sign-in was cancelled.');
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final current = _auth.currentUser;
      if (current != null && current.isAnonymous) {
        // Upgrade the guest account, preserving its balance/history.
        try {
          await current.linkWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use' ||
              e.code == 'email-already-in-use') {
            await _auth.signInWithCredential(credential);
          } else {
            rethrow;
          }
        }
      } else {
        await _auth.signInWithCredential(credential);
      }
      await ensureProfile(displayName: googleUser.displayName);
    } on FirebaseAuthException catch (e) {
      throw AppException(e.message ?? 'Google sign-in failed.', code: e.code);
    }
  }

  /// Idempotently provisions/refreshes the server-side profile.
  Future<void> ensureProfile({String? displayName}) async {
    try {
      await _functions.httpsCallable(Callables.ensureProfile).call<Map<String, dynamic>>(
        {if (displayName != null) 'displayName': displayName},
      );
    } catch (e) {
      throw mapError(e);
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut().catchError((_) {});
    await _auth.signOut();
  }
}
