import 'account.entity.dart';

/// Signing in and out. Every method either finishes or throws an `AppError`;
/// the sign-in methods return `false` when the listener backed out of a
/// native sheet, which is not an error.
abstract class AuthRepository {
  /// The listener now, and every change after.
  Stream<Account?> get changes;

  Account? get current;

  bool get canUseApple;

  bool get canUseGoogle;

  Future<bool> signInWithApple();

  /// The native Google sheet, or — where there is none — the browser.
  Future<bool> signInWithGoogle();

  /// Sends a six-digit code to [email].
  Future<void> sendEmailCode(String email);

  Future<void> verifyEmailCode({required String email, required String code});

  Future<void> signOut();

  /// Deletes the account and everything tied to it, then signs out. The app
  /// stores require that this can be done from inside the app.
  Future<void> deleteAccount();
}
