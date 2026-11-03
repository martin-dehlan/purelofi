import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../domain/identity.service.dart';

/// Apple's own sheet, on iOS only.
///
/// Android has no native Apple sign-in, and offering the browser flow there
/// would be the one sign-in in the app that is not native (#38).
///
/// The nonce is what stops a stolen token from being replayed: Apple signs
/// its SHA-256 into the token, Supabase is handed the raw value and checks
/// the two match.
class AppleIdentityServiceImpl implements IdentityService {
  const AppleIdentityServiceImpl();

  @override
  bool get isAvailable => Platform.isIOS;

  @override
  Future<IdentityToken?> requestToken() async {
    final String rawNonce = _nonce();

    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: <AppleIDAuthorizationScopes>[
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }

    final String? idToken = credential.identityToken;
    if (idToken == null) {
      throw StateError('Apple returned no identity token');
    }

    final String name = <String?>[credential.givenName, credential.familyName]
        .whereType<String>()
        .where((String part) => part.trim().isNotEmpty)
        .join(' ');

    return IdentityToken(
      idToken: idToken,
      nonce: rawNonce,
      name: name.isEmpty ? null : name,
    );
  }

  /// Apple keeps nothing on the device that needs letting go of.
  @override
  Future<void> forget() async {}

  static String _nonce([int length = 32]) {
    const String chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final Random random = Random.secure();

    return List<String>.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }
}
