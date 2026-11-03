import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';

import '../domain/identity.service.dart';

/// Google's own sheet, on iOS and Android.
///
/// [webClientId] is what Supabase checks the token against on both
/// platforms; [iosClientId] is the app's own client on iOS. Both are OAuth
/// client IDs, which are public — they identify the app, they do not grant
/// anything. Without a web client ID Google sign-in is simply not offered.
class GoogleIdentityServiceImpl implements IdentityService {
  GoogleIdentityServiceImpl({
    required String? webClientId,
    required String? iosClientId,
  }) : _webClientId = webClientId,
       _iosClientId = iosClientId;

  final String? _webClientId;
  final String? _iosClientId;

  Future<void>? _ready;

  @override
  bool get isAvailable =>
      _webClientId != null && (!Platform.isIOS || _iosClientId != null);

  /// Initialised once, the first time it is needed, not at app start: the
  /// listener who never signs in never pays for it.
  Future<void> _initialise() => _ready ??= GoogleSignIn.instance.initialize(
    serverClientId: _webClientId,
    clientId: Platform.isIOS ? _iosClientId : null,
  );

  @override
  Future<IdentityToken?> requestToken() async {
    await _initialise();

    final GoogleSignIn google = GoogleSignIn.instance;
    if (!google.supportsAuthenticate()) {
      throw const NativeSignInUnavailable('no native Google sheet');
    }

    final GoogleSignInAccount account;
    try {
      account = await google.authenticate();
    } on GoogleSignInException catch (error) {
      switch (error.code) {
        case GoogleSignInExceptionCode.canceled:
        case GoogleSignInExceptionCode.interrupted:
          return null;
        // The phone has no working Google sign-in of its own — no Play
        // services, typically. The browser can still do it.
        case GoogleSignInExceptionCode.providerConfigurationError:
          throw NativeSignInUnavailable(error.description ?? error.code.name);
        default:
          rethrow;
      }
    }

    final String? idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError('Google returned no ID token');
    }

    return IdentityToken(idToken: idToken, name: account.displayName);
  }

  /// Forgets the Google account on this device too, so the next sign-in
  /// asks which account rather than silently picking the last one.
  @override
  Future<void> forget() async {
    if (_ready == null) return;
    await GoogleSignIn.instance.signOut();
  }
}
