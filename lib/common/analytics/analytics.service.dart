import 'package:posthog_flutter/posthog_flutter.dart';

import '../config/env.dart';
import '../errors/app_error.dart';

/// What PureLofi learns about how it is used: that people open the app,
/// listen, check the footage and pick scenes — and, since accounts and Pro
/// (#38, #16), who signs in and how they get to Pro (#82).
///
/// Never an email, a name or free text. A signed-in listener is known by
/// their Supabase user id and nothing else; a signed-out one is anonymous.
///
/// Errors go the same way, to PostHog's error tracking: the crashes it
/// catches by itself, and through [error] the failures the app caught and
/// lived with but that should not have happened.
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

  /// A failure the app caught: a track that would not play, a purchase the
  /// store refused, a sign-in that broke. [where] names the part of the app
  /// it happened in. A lost connection or a wrong password is not a bug and
  /// is left out.
  Future<void> error(
    Object error, {
    required String where,
    StackTrace? stackTrace,
  });
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

  // The focus timer (#137): whether people use it, and which plan.
  static const String focusStarted = 'focus_started';

  // Support links (#152): how often PureLofi sends someone to an artist.
  static const String artistSupportOpened = 'artist_support_opened';
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

    // Crashes, and errors nothing caught: in the framework, in Dart and in
    // the Android and iOS code underneath.
    config.errorTrackingConfig
      ..captureFlutterErrors = true
      ..capturePlatformDispatcherErrors = true
      ..captureNativeExceptions = true
      ..inAppIncludes.add('package:purelofi');
    config.beforeSend = <BeforeSendCallback>[PrivateDataScrubber.event];

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

  @override
  Future<void> error(
    Object error, {
    required String where,
    StackTrace? stackTrace,
  }) async {
    if (!isWorthReporting(error)) return;

    // What the mapper wrapped, with the trace from where it was thrown.
    final (Object cause, StackTrace? trace) = switch (error) {
      UnknownError(:final Object cause, stackTrace: final StackTrace? at) => (
        cause,
        at ?? stackTrace,
      ),
      _ => (error, stackTrace),
    };

    await _safely(
      () => _posthog.captureException(
        error: cause,
        stackTrace: trace,
        properties: <String, Object>{'where': where},
      ),
    );
  }

  /// A dropped connection is the network's, and a wrong password or a
  /// taken email the listener's. Neither is something to fix in the app.
  static bool isWorthReporting(Object error) =>
      error is! NetworkError && error is! AuthError;

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

  @override
  Future<void> error(
    Object error, {
    required String where,
    StackTrace? stackTrace,
  }) async {}
}

/// Takes what could say who someone is out of an event before it leaves
/// the phone. Mostly for error reports, whose messages are whatever the
/// code that failed put in them: an email address in a sign-in error, the
/// path of a song from the listener's own phone.
abstract final class PrivateDataScrubber {
  static final RegExp _email = RegExp(
    r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}',
  );

  /// A file of the listener's own (#66): a path, from its first slash, or
  /// a bare name, up to an audio file's extension. It takes a stream's URL
  /// along too, which is no loss: the events carry the track's id.
  static final RegExp _audioFile = RegExp(
    r'''(?:/[^\n'"]*?|[^\s/'"]+)\.(?:mp3|m4a|aac|flac|wav|ogg|opus)\b''',
    caseSensitive: false,
  );

  static PostHogEvent event(PostHogEvent event) {
    final Map<String, Object>? properties = event.properties;
    if (properties != null) {
      event.properties = value(properties) as Map<String, Object>;
    }
    return event;
  }

  /// [input] with every string in it, however deep, scrubbed.
  static Object value(Object input) => switch (input) {
    final String text =>
      text.replaceAll(_email, '[email]').replaceAll(_audioFile, '[file]'),
    final Map<Object?, Object?> map => <String, Object>{
      for (final MapEntry<Object?, Object?> entry in map.entries)
        if (entry.value != null) entry.key.toString(): value(entry.value!),
    },
    final List<Object?> list => <Object>[
      for (final Object? item in list)
        if (item != null) value(item),
    ],
    _ => input,
  };
}
