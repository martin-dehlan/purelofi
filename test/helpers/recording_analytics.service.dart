import 'package:purelofi/common/analytics/analytics.service.dart';

/// Records what would have been sent, so tests can assert on event names and
/// payload keys without touching the network.
class RecordingAnalyticsService implements AnalyticsService {
  final List<(String event, Map<String, Object> properties)> events =
      <(String, Map<String, Object>)>[];

  List<String> get eventNames =>
      events.map(((String, Map<String, Object>) e) => e.$1).toList();

  /// Who events belong to now; `null` after a [reset], or before any sign-in.
  String? identifiedAs;
  Map<String, Object> personProperties = <String, Object>{};
  int resets = 0;

  /// The properties of the last [event] recorded.
  Map<String, Object>? last(String event) {
    for (final (String, Map<String, Object>) e in events.reversed) {
      if (e.$1 == event) return e.$2;
    }
    return null;
  }

  @override
  Future<void> identify(String userId, Map<String, Object> properties) async {
    identifiedAs = userId;
    personProperties = properties;
  }

  @override
  Future<void> reset() async {
    identifiedAs = null;
    resets++;
  }

  @override
  Future<void> capture(String event, [Map<String, Object>? properties]) async =>
      events.add((event, properties ?? <String, Object>{}));

  @override
  Future<void> appOpened() async =>
      events.add((AnalyticsEvents.appOpened, <String, Object>{}));

  @override
  Future<void> trackPlayed(String trackId) async => events.add((
    AnalyticsEvents.trackPlayed,
    <String, Object>{'track_id': trackId},
  ));

  @override
  Future<void> localTrackPlayed() async => events.add((
    AnalyticsEvents.trackPlayed,
    <String, Object>{'source': 'local'},
  ));

  @override
  Future<void> btsOpened(String trackId) async => events.add((
    AnalyticsEvents.btsOpened,
    <String, Object>{'track_id': trackId},
  ));

  @override
  Future<void> sceneSwitched(String sceneId) async => events.add((
    AnalyticsEvents.sceneSwitched,
    <String, Object>{'scene_id': sceneId},
  ));
}
