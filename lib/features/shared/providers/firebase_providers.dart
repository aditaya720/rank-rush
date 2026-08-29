import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';

/// Singleton Firebase service handles, exposed through Riverpod so features
/// depend on providers (easily overridable in tests) rather than globals.

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final functionsProvider = Provider<FirebaseFunctions>((ref) {
  return FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion);
});

/// Streams Firebase auth state (null when signed out).
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// The current user's uid, or null when signed out.
final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateChangesProvider).valueOrNull?.uid;
});
