/// Every route path in the app, in one place.
abstract final class AppRoutes {
  /// The player — the whole app.
  static const String player = '/';

  /// Deep link to a track's behind-the-scenes clip, e.g. from the YouTube
  /// channel: `purelofi://app/track/<id>`.
  static const String trackPath = 'track/:trackId';

  static String track(String trackId) => '/track/$trackId';
}
