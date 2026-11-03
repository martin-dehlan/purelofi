/// What a native sign-in sheet hands back: a token from Apple or Google that
/// Supabase can verify, and whatever the provider told us about the person.
class IdentityToken {
  const IdentityToken({
    required this.idToken,
    this.nonce,
    this.accessToken,
    this.name,
  });

  final String idToken;

  /// The raw nonce the token was requested with. Apple only.
  final String? nonce;

  final String? accessToken;

  /// Apple sends the name once, on the very first sign-in, and never again.
  final String? name;
}

/// A platform's own sign-in sheet — Apple's or Google's.
///
/// Behind an interface because neither sheet exists in a test (see
/// `docs/10`). `null` means the listener closed the sheet: a choice, not an
/// error, so nothing is shown for it.
abstract class IdentityService {
  /// Whether this sheet exists here at all. Apple's does not on Android.
  bool get isAvailable;

  Future<IdentityToken?> requestToken();

  /// Lets go of whatever the provider remembers on this device, on sign-out.
  Future<void> forget();
}

/// The platform has no native sheet after all — an Android phone without
/// Google Play services, for instance. The repository falls back to the
/// browser on this, and only on this.
class NativeSignInUnavailable implements Exception {
  const NativeSignInUnavailable(this.reason);

  final String reason;

  @override
  String toString() => 'NativeSignInUnavailable: $reason';
}
