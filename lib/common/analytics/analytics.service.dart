import 'package:posthog_flutter/posthog_flutter.dart';

import '../config/env.dart';

/// The four things worth knowing: that people open the app, that they listen,
/// that they check the footage, and which scenes they pick.
///
/// No PII, no user ids — there are no accounts.
abstract class AnalyticsService {
  Future<void> appOpened();

  Future<void> trackPlayed(String trackId);

  Future<void> btsOpened(String trackId);

  Future<void> sceneSwitched(String sceneId);
}

/// Event names, kept in one place so the dashboard and the code agree.
abstract final class AnalyticsEvents {
  static const String appOpened = 'app_opened';
  static const String trackPlayed = 'track_played';
  static const String btsOpened = 'bts_opened';
  static const String sceneSwitched = 'scene_switched';
}

/// Sends events to PostHog.
class PostHogAnalyticsService implements AnalyticsService {
  const PostHogAnalyticsService(this._posthog);

  final Posthog _posthog;

  /// Configures PostHog from `.env`, or returns a no-op service when no key
  /// is set — a missing key disables analytics, it never breaks the app.
  static Future<AnalyticsService> create() async {
    final String? apiKey = Env.maybeRead(Env.posthogApiKeyEnv);
    if (apiKey == null) return const NoopAnalyticsService();

    final PostHogConfig config = PostHogConfig(apiKey);
    final String? host = Env.maybeRead(Env.posthogHostEnv);
    if (host != null) config.host = host;

    await Posthog().setup(config);
    return PostHogAnalyticsService(Posthog());
  }

  @override
  Future<void> appOpened() => _capture(AnalyticsEvents.appOpened);

  @override
  Future<void> trackPlayed(String trackId) => _capture(
    AnalyticsEvents.trackPlayed,
    <String, Object>{'track_id': trackId},
  );

  @override
  Future<void> btsOpened(String trackId) => _capture(
    AnalyticsEvents.btsOpened,
    <String, Object>{'track_id': trackId},
  );

  @override
  Future<void> sceneSwitched(String sceneId) => _capture(
    AnalyticsEvents.sceneSwitched,
    <String, Object>{'scene_id': sceneId},
  );

  Future<void> _capture(String event, [Map<String, Object>? properties]) =>
      _posthog.capture(eventName: event, properties: properties);
}

/// Used when analytics is not configured, and in tests.
class NoopAnalyticsService implements AnalyticsService {
  const NoopAnalyticsService();

  @override
  Future<void> appOpened() async {}

  @override
  Future<void> trackPlayed(String trackId) async {}

  @override
  Future<void> btsOpened(String trackId) async {}

  @override
  Future<void> sceneSwitched(String sceneId) async {}
}
