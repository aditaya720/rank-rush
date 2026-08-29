import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/config/app_config.dart';
import 'app/theme/app_theme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // If the build wasn't given Firebase config, show a helpful screen instead of
  // crashing with an opaque error.
  if (!AppConfig.hasFirebaseConfig) {
    runApp(const _ConfigNeededApp());
    return;
  }

  await runZonedGuarded(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // App Check protects the backend from abuse/bots. In debug we use the debug
    // provider; in release, platform attestation.
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider:
            kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider:
            kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
      );
    } catch (_) {
      // App Check is best-effort in development; never block startup on it.
    }

    // Route uncaught framework + async errors to Crashlytics in release.
    if (!kDebugMode) {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
    }

    runApp(const ProviderScope(child: RankRushApp()));
  }, (error, stack) {
    if (!kDebugMode) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } else {
      debugPrint('Uncaught zone error: $error\n$stack');
    }
  });
}

/// Shown when the app is launched without the required Firebase --dart-defines.
class _ConfigNeededApp extends StatelessWidget {
  const _ConfigNeededApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rank Rush',
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.settings_suggest, size: 56, color: AppColors.gold),
                const SizedBox(height: 16),
                Text('Configuration required',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                const Text(
                  'Rank Rush needs Firebase configuration to run. Provide it at '
                  'build time, for example:\n\n'
                  'flutter run --dart-define-from-file=dart_defines.json\n\n'
                  'See dart_defines.example.json and README.md for the full setup.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
