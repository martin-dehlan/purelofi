import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/common/analytics/analytics.service.dart';

import '../../helpers/recording_analytics.service.dart';

void main() {
  group('the MVP event set', () {
    test('is exactly four events, named as the dashboard expects', () {
      expect(AnalyticsEvents.appOpened, 'app_opened');
      expect(AnalyticsEvents.trackPlayed, 'track_played');
      expect(AnalyticsEvents.btsOpened, 'bts_opened');
      expect(AnalyticsEvents.sceneSwitched, 'scene_switched');
    });

    test('carries only the id it needs, never anything personal', () async {
      final RecordingAnalyticsService analytics = RecordingAnalyticsService();

      await analytics.appOpened();
      await analytics.trackPlayed('track-1');
      await analytics.btsOpened('track-1');
      await analytics.sceneSwitched('scene-1');

      expect(analytics.eventNames, <String>[
        'app_opened',
        'track_played',
        'bts_opened',
        'scene_switched',
      ]);
      expect(analytics.events[0].$2, isEmpty);
      expect(analytics.events[1].$2, <String, Object>{'track_id': 'track-1'});
      expect(analytics.events[2].$2, <String, Object>{'track_id': 'track-1'});
      expect(analytics.events[3].$2, <String, Object>{'scene_id': 'scene-1'});
    });
  });

  group('setup', () {
    test('falls back to a no-op service when no key is configured', () async {
      final AnalyticsService analytics = await PostHogAnalyticsService.create();

      expect(analytics, isA<NoopAnalyticsService>());
    });
  });

  group('NoopAnalyticsService', () {
    test('swallows every event without complaint', () async {
      const NoopAnalyticsService analytics = NoopAnalyticsService();

      await expectLater(analytics.appOpened(), completes);
      await expectLater(analytics.trackPlayed('t'), completes);
      await expectLater(analytics.btsOpened('t'), completes);
      await expectLater(analytics.sceneSwitched('s'), completes);
    });
  });
}
