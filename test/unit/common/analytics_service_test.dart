import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:purelofi/common/analytics/analytics.service.dart';
import 'package:purelofi/common/errors/app_error.dart';

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

  group('errors', () {
    late _MockPosthog posthog;
    late PostHogAnalyticsService analytics;

    setUp(() {
      posthog = _MockPosthog();
      analytics = PostHogAnalyticsService(posthog);
      when(
        () => posthog.captureException(
          error: any(named: 'error'),
          stackTrace: any(named: 'stackTrace'),
          properties: any(named: 'properties'),
        ),
      ).thenAnswer((_) async {});
    });

    test('sends a failure with where it happened', () async {
      const AppError failure = AppError.playback(message: 'the stream failed');

      await analytics.error(failure, where: 'playback');

      verify(
        () => posthog.captureException(
          error: failure,
          stackTrace: null,
          properties: <String, Object>{'where': 'playback'},
        ),
      ).called(1);
    });

    test('sends what the mapper wrapped, with its own trace', () async {
      final StateError cause = StateError('broken');
      final StackTrace trace = StackTrace.current;

      await analytics.error(
        AppError.unknown(cause: cause, stackTrace: trace),
        where: 'tracks',
      );

      verify(
        () => posthog.captureException(
          error: cause,
          stackTrace: trace,
          properties: <String, Object>{'where': 'tracks'},
        ),
      ).called(1);
    });

    test('leaves out a lost connection and a wrong password', () async {
      await analytics.error(const AppError.network(), where: 'tracks');
      await analytics.error(
        const AppError.auth(message: 'Wrong email or password.'),
        where: 'sign_in',
      );

      verifyNever(
        () => posthog.captureException(
          error: any(named: 'error'),
          stackTrace: any(named: 'stackTrace'),
          properties: any(named: 'properties'),
        ),
      );
    });

    test('a failed send is dropped, never thrown', () async {
      when(
        () => posthog.captureException(
          error: any(named: 'error'),
          stackTrace: any(named: 'stackTrace'),
          properties: any(named: 'properties'),
        ),
      ).thenThrow(Exception('offline'));

      await expectLater(
        analytics.error(StateError('x'), where: 'playback'),
        completes,
      );
    });
  });

  group('PrivateDataScrubber', () {
    test('takes email addresses out of any text', () {
      expect(
        PrivateDataScrubber.value(
          'no account for jo.doe+lofi@mail.example.com',
        ),
        'no account for [email]',
      );
    });

    test('takes the listener\'s own files out, path and name', () {
      expect(
        PrivateDataScrubber.value(
          'Cannot open /storage/emulated/0/Music/My Song.mp3 now',
        ),
        'Cannot open [file] now',
      );
      expect(
        PrivateDataScrubber.value('bad tag in demo_take2.FLAC'),
        'bad tag in [file]',
      );
    });

    test('leaves the rest of a report alone', () {
      const String frame = 'package:purelofi/features/player/a.dart:12';
      expect(PrivateDataScrubber.value(frame), frame);
      expect(PrivateDataScrubber.value(42), 42);
    });

    test('goes through maps and lists however deep', () {
      final Object scrubbed = PrivateDataScrubber.value(<String, Object>{
        'where': 'sign_in',
        r'$exception_list': <Object>[
          <String, Object>{
            'value': 'user a@b.io not found',
            'mechanism': <String, Object>{'handled': true},
          },
        ],
      });

      expect(scrubbed, <String, Object>{
        'where': 'sign_in',
        r'$exception_list': <Object>[
          <String, Object>{
            'value': 'user [email] not found',
            'mechanism': <String, Object>{'handled': true},
          },
        ],
      });
    });

    test('scrubs an event on its way out', () {
      final PostHogEvent event = PrivateDataScrubber.event(
        PostHogEvent(
          event: r'$exception',
          properties: <String, Object>{'message': 'for a@b.io'},
        ),
      );

      expect(event.properties, <String, Object>{'message': 'for [email]'});
    });
  });
}

class _MockPosthog extends Mock implements Posthog {}
