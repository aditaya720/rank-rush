import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnimplementedError(
      'DefaultFirebaseOptions has not been configured. '
      'Run flutterfire configure to generate firebase_options.dart',
    );
  }
}
