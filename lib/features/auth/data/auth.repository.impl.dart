import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../common/errors/error_mapper.dart';
import '../domain/auth.repository.dart';
import '../domain/account.entity.dart';
import '../domain/identity.service.dart';

/// Supabase Auth, signed into natively wherever the platform allows.
///
/// Apple and Google hand over an ID token from their own sheets, which
/// Supabase verifies (`signInWithIdToken`) — no browser, no redirect. Email
/// is a six-digit code the listener types into the app. The browser is only
/// the fallback for Google where the phone has no native sheet.
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
  Future<void> sendEmailCode(String email) =>
      _guard(() => _auth.signInWithOtp(email: email.trim()));

  @override
  Future<void> verifyEmailCode({required String email, required String code}) =>
      _guard(
        () => _auth.verifyOTP(
          email: email.trim(),
          token: code.trim(),
          type: OtpType.email,
        ),
      );

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
