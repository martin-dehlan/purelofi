/// Every route path in the app, in one place.
abstract final class AppRoutes {
  /// The player — the whole app.
  static const String player = '/';

  /// Deep link to a track's behind-the-scenes clip, e.g. from the YouTube
  /// channel: `purelofi://app/track/<id>`.
  static const String trackPath = 'track/:trackId';

  static String track(String trackId) => '/track/$trackId';

  /// The track id in a deep link, or `null` when it is not a UUID.
  ///
  /// A deep link is typed by whoever made it, not by us: anything but the
  /// shape of an id is dropped here, before it reaches a query.
  static String? trackIdFrom(String? raw) {
    final String? id = raw?.trim().toLowerCase();
    if (id == null || !_uuid.hasMatch(id)) return null;
    return id;
  }

  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  /// Where the browser sign-in fallback lands: `purelofi://app/auth-callback`.
  /// supabase_flutter reads the session out of the link itself; the route
  /// only has to show the room again (#38).
  static const String authCallbackPath = 'auth-callback';
}
