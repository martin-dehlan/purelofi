import 'account.entity.dart';

/// How a password sign-in ended.
enum EmailSignIn {
  signedIn,

  /// The address still waits for its confirmation code.
  needsCode,
}

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

  /// Email and password. [EmailSignIn.needsCode] when the address was
  /// never confirmed: a fresh code is on its way, for [confirmEmail].
  Future<EmailSignIn> signInWithPassword({
    required String email,
    required String password,
  });

  /// A new account. [EmailSignIn.needsCode] until the six-digit code
  /// mailed to [email] comes back through [confirmEmail].
  Future<EmailSignIn> createAccount({
    required String email,
    required String password,
  });

  Future<void> confirmEmail({required String email, required String code});

  /// Mails a fresh confirmation code.
  Future<void> resendConfirmation(String email);

  /// Mails a six-digit code for [resetPassword].
  Future<void> sendPasswordReset(String email);

  /// Signs in with the reset code and sets [newPassword].
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });

  Future<void> signOut();

  /// Deletes the account and everything tied to it, then signs out. The app
  /// stores require that this can be done from inside the app.
  Future<void> deleteAccount();
}
