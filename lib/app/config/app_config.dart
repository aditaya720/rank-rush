/// App-wide configuration, supplied at build time via `--dart-define` (or a
/// `--dart-define-from-file=dart_defines.json`). NO secrets live in source.
///
/// Example run:
///   flutter run --dart-define-from-file=dart_defines.json
///
/// See `dart_defines.example.json` for the full list of keys.
class AppConfig {
  const AppConfig._();

  /// Firebase project id (from the Firebase console).
  static const String firebaseProjectId =
      String.fromEnvironment('FIREBASE_PROJECT_ID');

  /// Region your Cloud Functions are deployed to (must match the backend).
  static const String functionsRegion =
      String.fromEnvironment('FUNCTIONS_REGION', defaultValue: 'us-central1');

  /// Logical game "table" id. The backend defaults to `main`.
  static const String gameId =
      String.fromEnvironment('GAME_ID', defaultValue: 'main');

  /// Optional App Check debug token for local development on real devices.
  static const String appCheckDebugToken =
      String.fromEnvironment('APP_CHECK_DEBUG_TOKEN');

  /// When true, connect to local Firebase emulators instead of production.
  static const bool useEmulators =
      bool.fromEnvironment('USE_EMULATORS', defaultValue: false);

  /// Emulator host (Android emulators reach the host machine at 10.0.2.2).
  static const String emulatorHost =
      String.fromEnvironment('EMULATOR_HOST', defaultValue: 'localhost');

  /// True only when the minimum Firebase config needed to boot is present.
  static bool get hasFirebaseConfig => firebaseProjectId.isNotEmpty;

  static bool get hasAppCheckDebugToken => appCheckDebugToken.isNotEmpty;
}
