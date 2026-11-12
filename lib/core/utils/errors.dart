import 'package:firebase_auth/firebase_auth.dart';

import '../../l10n/strings.dart';

/// A business-rule error with a message that can be shown to the user,
/// e.g. 'Not enough stock (only {left} left).' with args {'left': 2}.
/// The message is translated when it is shown.
class AppException implements Exception {
  const AppException(this.text, [this.args = const {}]);
  final String text;
  final Map<String, Object?> args;

  String get message => AppStrings.tr(text, args);

  @override
  String toString() => message;
}

/// Turns any error into a short message for a SnackBar.
String friendlyError(Object error) {
  const tr = AppStrings.tr;
  if (error is AppException) return error.message;
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return tr('That email address is not valid.');
      case 'user-disabled':
        return tr('This account has been disabled.');
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return tr('Wrong email or password.');
      case 'email-already-in-use':
        return tr('An account already exists for that email.');
      case 'weak-password':
        return tr('Password is too weak.');
      case 'too-many-requests':
        return tr('Too many attempts. Please wait and try again.');
      case 'network-request-failed':
        return tr('No connection, try again.');
      case 'requires-recent-login':
        return tr('Please log out and log in again, then try again.');
    }
    return error.message ?? tr('Login failed ({code}).', {'code': error.code});
  }
  if (error is FirebaseException) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return tr('No connection, try again.');
      case 'permission-denied':
        return tr('You do not have permission to do that.');
      case 'not-found':
        return tr('Not found.');
    }
    return error.message ??
        tr('Something went wrong ({code}).', {'code': error.code});
  }
  return error.toString().replaceFirst('Exception: ', '');
}
