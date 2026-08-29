import 'package:cloud_functions/cloud_functions.dart';

/// A user-safe, presentable error. The backend never leaks internals; this
/// turns transport/Firebase errors into friendly, actionable messages.
class AppException implements Exception {
  const AppException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Maps a caught error (usually from a callable Cloud Function) into an
/// [AppException] with a friendly message. Codes/messages mirror the backend's
/// `toHttpsError` mapping.
AppException mapError(Object error) {
  if (error is AppException) return error;

  if (error is FirebaseFunctionsException) {
    final message = _messageForFunctionsError(error);
    return AppException(message, code: error.code);
  }

  return const AppException('Something went wrong. Please try again.');
}

String _messageForFunctionsError(FirebaseFunctionsException e) {
  // The backend sets a friendly `message` already; prefer it when present.
  final serverMessage = e.message?.trim();
  if (serverMessage != null && serverMessage.isNotEmpty) {
    switch (e.code) {
      case 'unauthenticated':
        return 'Please sign in again to continue.';
      case 'permission-denied':
        return 'You do not have permission to do that.';
      case 'resource-exhausted':
        return serverMessage; // e.g. daily limit reached
      case 'failed-precondition':
      case 'already-exists':
      case 'invalid-argument':
      case 'not-found':
        return serverMessage;
      default:
        return serverMessage;
    }
  }

  switch (e.code) {
    case 'unauthenticated':
      return 'Please sign in again to continue.';
    case 'unavailable':
      return 'Network problem. Check your connection and try again.';
    default:
      return 'Something went wrong. Please try again.';
  }
}
