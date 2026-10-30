import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../common/errors/error_mapper.dart';
import '../domain/auth.repository.dart';
import '../domain/account.entity.dart';
import '../domain/identity.service.dart';

/// Supabase Auth, signed into natively wherever the platform allows.
///
/// Apple and Google hand over an ID token from their own sheets, which
/// Supabase verifies (`signInWithIdToken`) — no browser, no redirect. Email
/// is an address and a password; confirming the address and resetting the
/// password both run on six-digit codes typed into the app, never on a link.
/// The browser is only the fallback for Google where the phone has no native
/// sheet.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required GoTrueClient auth,
    required IdentityService apple,
    required IdentityService google,
    required Future<void> Function() openGoogleInBrowser,
    required Future<void> Function() deleteOwnAccount,
  }) : _auth = auth,
       _apple = apple,
       _google = google,
       _openGoogleInBrowser = openGoogleInBrowser,
       _deleteOwnAccount = deleteOwnAccount;

  final GoTrueClient _auth;
  final IdentityService _apple;
  final IdentityService _google;
  final Future<void> Function() _openGoogleInBrowser;
  final Future<void> Function() _deleteOwnAccount;

  /// Where the browser fallback comes back to. The app already answers to
  /// `purelofi://app/…`; supabase_flutter picks the session out of the link.
  static const String callbackUrl = 'purelofi://app/auth-callback';

  @override
  Stream<Account?> get changes => _auth.onAuthStateChange.map(
    (AuthState state) => _toUser(state.session?.user),
  );

  @override
  Account? get current => _toUser(_auth.currentUser);

  @override
  bool get canUseApple => _apple.isAvailable;

  @override
  bool get canUseGoogle => _google.isAvailable;

  @override
  Future<bool> signInWithApple() => _guard(() async {
    final IdentityToken? token = await _apple.requestToken();
    if (token == null) return false;

    await _auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: token.idToken,
      nonce: token.nonce,
    );

    // Apple tells the name once, on the very first sign-in, and never again:
    // keep it now or lose it.
    final String? name = token.name;
    if (name != null) {
      await _auth.updateUser(
        UserAttributes(data: <String, dynamic>{'full_name': name}),
      );
    }

    return true;
  });

  @override
  Future<bool> signInWithGoogle() => _guard(() async {
    final IdentityToken? token;
    try {
      token = await _google.requestToken();
    } on NativeSignInUnavailable {
      // The session arrives later, through the callback link; the listener
      // sees it land through [changes].
      await _openGoogleInBrowser();
      return true;
    }
    if (token == null) return false;

    await _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: token.idToken,
      accessToken: token.accessToken,
    );

    return true;
  });

  @override
  Future<EmailSignIn> signInWithPassword({
    required String email,
    required String password,
  }) => _guard(() async {
    try {
      await _auth.signInWithPassword(email: email.trim(), password: password);
      return EmailSignIn.signedIn;
    } on AuthException catch (error) {
      if (error.code != 'email_not_confirmed') rethrow;
    }

    // Right password, address never confirmed: send the code again rather
    // than leave them stuck. A rate limit here means a recent code is still
    // in the inbox, so it is no reason to fail.
    try {
      await _auth.resend(type: OtpType.signup, email: email.trim());
    } on AuthException {
      // The code step offers "Send a new code".
    }
    return EmailSignIn.needsCode;
  });

  @override
  Future<EmailSignIn> createAccount({
    required String email,
    required String password,
  }) => _guard(() async {
    final AuthResponse response = await _auth.signUp(
      email: email.trim(),
      password: password,
    );

    // With confirmations on, Supabase answers an address that already has
    // an account with a stand-in user and no identities, and mails nothing.
    // Say so instead of waiting on a code that never comes.
    final List<UserIdentity>? identities = response.user?.identities;
    if (identities != null && identities.isEmpty) {
      throw const AuthException(
        'User already registered',
        code: 'user_already_exists',
      );
    }

    // No session means the confirmation code is on its way.
    return response.session == null
        ? EmailSignIn.needsCode
        : EmailSignIn.signedIn;
  });

  @override
  Future<void> confirmEmail({required String email, required String code}) =>
      _guard(
        () => _auth.verifyOTP(
          email: email.trim(),
          token: code.trim(),
          type: OtpType.signup,
        ),
      );

  @override
  Future<void> resendConfirmation(String email) =>
      _guard(() => _auth.resend(type: OtpType.signup, email: email.trim()));

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.resetPasswordForEmail(email.trim()));

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) => _guard(() async {
    // The recovery code signs in; the new password is set on that session.
    await _auth.verifyOTP(
      email: email.trim(),
      token: code.trim(),
      type: OtpType.recovery,
    );
    await _auth.updateUser(UserAttributes(password: newPassword));
  });

  @override
  Future<void> signOut() => _guard(() async {
    await _auth.signOut();
    await _google.forget();
  });

  @override
  Future<void> deleteAccount() => _guard(() async {
    await _deleteOwnAccount();
    await signOut();
  });

  static Account? _toUser(User? user) {
    if (user == null) return null;

    final Object? name =
        user.userMetadata?['full_name'] ?? user.userMetadata?['name'];

    return Account(
      id: user.id,
      email: user.email,
      name: name is String && name.trim().isNotEmpty ? name : null,
      method: switch (user.appMetadata['provider']) {
        'apple' => SignInMethod.apple,
        'google' => SignInMethod.google,
        _ => SignInMethod.email,
      },
    );
  }

  /// Every failure leaves as an `AppError` (see `docs/07`).
  static Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on Object catch (error, stackTrace) {
      throw ErrorMapper.fromException(error, stackTrace);
    }
  }
}
