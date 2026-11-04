import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/player/controller/player.controller.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/controller/scene.controller.dart';
import 'package:purelofi/features/player/controller/wake_alarm.controller.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/domain/volume_layer.dart';
import 'package:purelofi/features/player/domain/wake_alarm.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/fake_favorites.repository.dart';
import '../../../helpers/fake_wake.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  group('nextWake', () {
    // Wednesday 4 November 2026.
    final DateTime wednesdayMorning = DateTime(2026, 11, 4, 6, 30);

    test('later today when the time has not come yet', () {
      expect(
        nextWake(
          const WakeAlarm(hour: 7, minute: 0, weekdays: <int>{3}),
          wednesdayMorning,
        ),
        DateTime(2026, 11, 4, 7),
      );
    });

    test('the next chosen day once today has passed', () {
      expect(
        nextWake(
          const WakeAlarm(hour: 6, minute: 0, weekdays: <int>{1, 5}),
          wednesdayMorning,
        ),
        DateTime(2026, 11, 6, 6), // Friday
      );
    });

    test('no days chosen is once, the next time the clock reads it', () {
      expect(
        nextWake(
          const WakeAlarm(hour: 6, minute: 0, weekdays: <int>{}),
          wednesdayMorning,
        ),
        DateTime(2026, 11, 5, 6),
      );
    });

    test('a clock change does not move it', () {
      // Europe goes back an hour on 25 October 2026: 7:00 stays 7:00.
      final DateTime at = nextWake(
        const WakeAlarm(hour: 7, minute: 0, weekdays: <int>{7}),
        DateTime(2026, 10, 24, 12),
      );
      expect(at.hour, 7);
      expect(at.day, 25);
    });

    test('it survives a round trip through the store', () {
      const WakeAlarm alarm = WakeAlarm(
        hour: 6,
        minute: 45,
        weekdays: <int>{1, 2},
        sceneId: 'rainy',
        fade: Duration(seconds: 90),
        enabled: true,
      );
      final WakeAlarm back = WakeAlarm.fromJson(alarm.toJson());
      expect(back.hour, 6);
      expect(back.minute, 45);
      expect(back.weekdays, <int>{1, 2});
      expect(back.sceneId, 'rainy');
      expect(back.fade, const Duration(seconds: 90));
      expect(back.enabled, isTrue);
    });
  });

  group('WakeAlarmController', () {
    late MockContentRepository content;
    late FakeAudioPlayerService audio;
    late FakeFavoritesRepository favorites;
    late FakeWakeScheduler scheduler;
    late FakeWakeAlarmStore store;

    ProviderContainer start(
      FakeAsync async, {
      WakeAlarm alarm = const WakeAlarm(hour: 7, minute: 0),
      bool allowed = true,
    }) {
      content = MockContentRepository();
      audio = FakeAudioPlayerService();
      favorites = FakeFavoritesRepository();
      scheduler = FakeWakeScheduler(isSupported: true, allowed: allowed);
      store = FakeWakeAlarmStore(alarm);
      when(() => content.getScenes()).thenAnswer(
        (_) async => <SceneEntity>[
          makeScene('first'),
          makeScene('rainy', title: 'Rainy').copyWith(sortOrder: 1),
        ],
      );
      when(
        () => content.getTracks(),
      ).thenAnswer((_) async => <TrackEntity>[makeTrack('a')]);
      final ProviderContainer container = ProviderContainer(
        overrides: [
          contentRepositoryProvider.overrideWithValue(content),
          audioPlayerServiceProvider.overrideWithValue(audio),
          favoritesRepositoryProvider.overrideWithValue(favorites),
          wakeSchedulerProvider.overrideWithValue(scheduler),
          wakeAlarmStoreProvider.overrideWithValue(store),
        ],
        retry: (_, _) => null,
      );
      addTearDown(() {
        container.dispose();
        audio.dispose();
        favorites.dispose();
        scheduler.dispose();
      });
      container
        ..listen(wakeAlarmControllerProvider, (_, _) {})
        ..listen(playerControllerProvider, (_, _) {})
        ..listen(activeSceneControllerProvider, (_, _) {});
      async.flushMicrotasks();
      return container;
    }

    test('off, nothing is set; on, the next ring is', () {
      fakeAsync((FakeAsync async) {
        final ProviderContainer c = start(async);
        expect(scheduler.scheduled, isNull);

        c
            .read(wakeAlarmControllerProvider.notifier)
            .set(const WakeAlarm(hour: 7, minute: 0, enabled: true));
        async.flushMicrotasks();

        expect(scheduler.scheduled, isNotNull);
        expect(scheduler.scheduled!.hour, 7);
        expect(store.alarm.enabled, isTrue);
      });
    });

    test('a refused exact alarm is said, not hidden', () {
      fakeAsync((FakeAsync async) {
        final ProviderContainer c = start(
          async,
          alarm: const WakeAlarm(hour: 7, minute: 0, enabled: true),
          allowed: false,
        );

        expect(c.read(wakeAlarmControllerProvider).value?.refused, isTrue);
      });
    });

    test('when it rings: the chosen room, the music from silence, slowly', () {
      fakeAsync((FakeAsync async) {
        final ProviderContainer c = start(
          async,
          alarm: const WakeAlarm(
            hour: 7,
            minute: 0,
            sceneId: 'rainy',
            fade: Duration(seconds: 60),
            enabled: true,
          ),
        );
        c.read(sceneListControllerProvider);
        async.flushMicrotasks();

        scheduler.ring();
        async.flushMicrotasks();

        expect(c.read(activeSceneControllerProvider)?.id, 'rainy');
        expect(audio.playedTracks, isNotEmpty);
        expect(audio.layer(VolumeLayer.alarm), lessThan(0.1));

        async.elapse(const Duration(seconds: 30));
        expect(audio.layer(VolumeLayer.alarm), closeTo(0.5, 0.05));
        async.elapse(const Duration(seconds: 30));
        expect(audio.layer(VolumeLayer.alarm), closeTo(1, 0.001));

        // Repeating: the next day is already set.
        expect(scheduler.scheduled, isNotNull);
      });
    });

    test('a one-off alarm turns itself off after ringing', () {
      fakeAsync((FakeAsync async) {
        start(
          async,
          alarm: const WakeAlarm(
            hour: 7,
            minute: 0,
            weekdays: <int>{},
            enabled: true,
          ),
        );

        scheduler.ring();
        async.flushMicrotasks();

        expect(store.alarm.enabled, isFalse);
        expect(scheduler.scheduled, isNull);
      });
    });
  });
}
