import 'package:purelofi/common/analytics/analytics.service.dart';

/// Records what would have been sent, so tests can assert on event names and
/// payload keys without touching the network.
class RecordingAnalyticsService implements AnalyticsService {
  final List<(String event, Map<String, Object> properties)> events =
      <(String, Map<String, Object>)>[];

  List<String> get eventNames =>
      events.map(((String, Map<String, Object>) e) => e.$1).toList();

  @override
  Future<void> appOpened() async =>
      events.add((AnalyticsEvents.appOpened, <String, Object>{}));

  @override
  Future<void> trackPlayed(String trackId) async => events.add((
    AnalyticsEvents.trackPlayed,
    <String, Object>{'track_id': trackId},
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
