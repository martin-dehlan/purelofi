import 'package:posthog_flutter/posthog_flutter.dart';

import '../config/env.dart';

/// What PureLofi learns about how it is used: that people open the app,
/// listen, check the footage and pick scenes — and, since accounts and Pro
/// (#38, #16), who signs in and how they get to Pro (#82).
///
/// Never an email, a name or free text. A signed-in listener is known by
/// their Supabase user id and nothing else; a signed-out one is anonymous.
abstract class AnalyticsService {
  /// From now on, events belong to [userId]. PostHog joins the anonymous
  /// history from before the sign-in onto the same person.
  Future<void> identify(String userId, Map<String, Object> properties);

  /// The listener signed out: whoever uses the device next is someone new.
  Future<void> reset();

  /// Any event in [AnalyticsEvents], with ids and enums only.
  Future<void> capture(String event, [Map<String, Object>? properties]);

  Future<void> appOpened();

  Future<void> trackPlayed(String trackId);

  /// One of the listener's own files started (#66). Deliberately without an
  /// id or a title: what someone keeps on their phone is none of PostHog's
  /// business. The source alone says whether the feature is used.
  Future<void> localTrackPlayed();

  Future<void> btsOpened(String trackId);

  Future<void> sceneSwitched(String sceneId);
}

/// Event names, kept in one place so the dashboard and the code agree.
abstract final class AnalyticsEvents {
  static const String appOpened = 'app_opened';
  static const String trackPlayed = 'track_played';
  static const String btsOpened = 'bts_opened';
  static const String sceneSwitched = 'scene_switched';

  // Accounts (#38).
  static const String signInStarted = 'sign_in_started';
  static const String signInCompleted = 'sign_in_completed';
  static const String signInFailed = 'sign_in_failed';
  static const String emailCodeSent = 'email_code_sent';
  static const String signedOut = 'signed_out';
  static const String accountDeleted = 'account_deleted';

  // Pro (#16).
  static const String paywallViewed = 'paywall_viewed';
  static const String proSceneTapped = 'pro_scene_tapped';
  static const String planSelected = 'plan_selected';
  static const String purchaseStarted = 'purchase_started';
  static const String purchaseCompleted = 'purchase_completed';
  static const String purchaseCancelled = 'purchase_cancelled';

  /// The store is waiting on someone; RevenueCat reports how it ends.
  static const String purchasePending = 'purchase_pending';
  static const String purchaseFailed = 'purchase_failed';
  static const String restoreTapped = 'restore_tapped';
  static const String restoreCompleted = 'restore_completed';
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
  Future<void> identify(String userId, Map<String, Object> properties) =>
      _safely(
        () => _posthog.identify(userId: userId, userProperties: properties),
      );

  @override
  Future<void> reset() => _safely(_posthog.reset);

  @override
  Future<void> capture(String event, [Map<String, Object>? properties]) =>
      _capture(event, properties);

  @override
  Future<void> appOpened() => _capture(AnalyticsEvents.appOpened);

  @override
  Future<void> trackPlayed(String trackId) => _capture(
    AnalyticsEvents.trackPlayed,
    <String, Object>{'track_id': trackId},
  );

  @override
  Future<void> localTrackPlayed() => _capture(
    AnalyticsEvents.trackPlayed,
    <String, Object>{'source': 'local'},
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
      _safely(() => _posthog.capture(eventName: event, properties: properties));

  /// Analytics never gets in the way: a failed send is dropped, never
  /// thrown into a sign-in or a purchase.
  static Future<void> _safely(Future<void> Function() send) async {
    try {
      await send();
    } on Object {
      // Nothing to do; the event is simply not counted.
    }
  }
}

/// Used when analytics is not configured, and in tests.
class NoopAnalyticsService implements AnalyticsService {
  const NoopAnalyticsService();

  @override
  Future<void> identify(String userId, Map<String, Object> properties) async {}

  @override
  Future<void> reset() async {}

  @override
  Future<void> capture(String event, [Map<String, Object>? properties]) async {}

  @override
  Future<void> appOpened() async {}

  @override
  Future<void> trackPlayed(String trackId) async {}

  @override
  Future<void> localTrackPlayed() async {}

  @override
  Future<void> btsOpened(String trackId) async {}

  @override
  Future<void> sceneSwitched(String sceneId) async {}
}
