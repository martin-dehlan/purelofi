import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/player/controller/player.controller.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/controller/sleep_timer.controller.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/domain/volume_layer.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/fake_favorites.repository.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  late MockContentRepository mockRepo;
  late FakeAudioPlayerService fakeAudio;

  setUp(() {
    mockRepo = MockContentRepository();
    fakeAudio = FakeAudioPlayerService();
    when(
      () => mockRepo.getTracks(),
    ).thenAnswer((_) async => <TrackEntity>[makeTrack('a')]);
  });

  /// A player with track `a` playing, inside [async]'s clock.
  ProviderContainer playing(FakeAsync async) {
    final FakeFavoritesRepository favorites = FakeFavoritesRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        contentRepositoryProvider.overrideWithValue(mockRepo),
        audioPlayerServiceProvider.overrideWithValue(fakeAudio),
        favoritesRepositoryProvider.overrideWithValue(favorites),
      ],
      retry: (_, _) => null,
    );
    addTearDown(() {
      container.dispose();
      favorites.dispose();
      fakeAudio.dispose();
    });
    container
      ..listen(playerControllerProvider, (_, _) {})
      ..listen(sleepTimerControllerProvider, (_, _) {});
    container.read(playerControllerProvider.notifier).playNext();
    async.flushMicrotasks();
    fakeAudio.playingController.add(true);
    async.flushMicrotasks();
    return container;
  }

  test('pauses the music once the time is up, and clears itself', () {
    fakeAsync((FakeAsync async) {
      final ProviderContainer container = playing(async);
      final int before = fakeAudio.pauseCalls;

      container
          .read(sleepTimerControllerProvider.notifier)
          .start(const Duration(minutes: 30));
      expect(container.read(sleepTimerControllerProvider), isNotNull);

      async.elapse(const Duration(minutes: 29, seconds: 59));
      expect(fakeAudio.pauseCalls, before);

      async.elapse(const Duration(seconds: 1));
      expect(fakeAudio.pauseCalls, before + 1);
      expect(container.read(sleepTimerControllerProvider), isNull);
    });
  });

  test('turned off, it lets the music play on', () {
    fakeAsync((FakeAsync async) {
      final ProviderContainer container = playing(async);
      final int before = fakeAudio.pauseCalls;
      final SleepTimerController timer = container.read(
        sleepTimerControllerProvider.notifier,
      );

      timer
        ..start(const Duration(minutes: 15))
        ..cancel();
      async.elapse(const Duration(hours: 1));

      expect(fakeAudio.pauseCalls, before);
      expect(container.read(sleepTimerControllerProvider), isNull);
    });
  });

  test('end of track stops just before the track ends', () {
    fakeAsync((FakeAsync async) {
      final ProviderContainer container = playing(async);
      final int before = fakeAudio.pauseCalls;
      fakeAudio.durationController.add(const Duration(minutes: 3));
      fakeAudio.positionController.add(const Duration(minutes: 1));
      async.flushMicrotasks();

      container.read(sleepTimerControllerProvider.notifier).endOfTrack();
      async.elapse(const Duration(minutes: 1, seconds: 59));
      expect(fakeAudio.pauseCalls, before);

      async.elapse(const Duration(seconds: 1));
      expect(fakeAudio.pauseCalls, before + 1);
    });
  });

  group('fading out (#138)', () {
    test('the music goes quiet over the last 30 seconds, not at once', () {
      fakeAsync((FakeAsync async) {
        final ProviderContainer container = playing(async);
        container
            .read(sleepTimerControllerProvider.notifier)
            .start(const Duration(minutes: 15));

        async.elapse(const Duration(minutes: 14, seconds: 29));
        expect(fakeAudio.layer(VolumeLayer.sleepTimer), 1);

        // Halfway through the fade, about half as loud.
        async.elapse(const Duration(seconds: 16));
        expect(fakeAudio.layer(VolumeLayer.sleepTimer), closeTo(0.5, 0.05));

        // Every step down, never up.
        final List<double> history =
            fakeAudio.layerHistory[VolumeLayer.sleepTimer]!;
        for (int i = 2; i < history.length; i++) {
          expect(history[i], lessThanOrEqualTo(history[i - 1]));
        }
      });
    });

    test('it pauses at silence, and the next play is at full volume', () {
      fakeAsync((FakeAsync async) {
        final ProviderContainer container = playing(async);
        final int before = fakeAudio.pauseCalls;
        container
            .read(sleepTimerControllerProvider.notifier)
            .start(const Duration(minutes: 15));

        async.elapse(const Duration(minutes: 15));

        expect(fakeAudio.pauseCalls, before + 1);
        expect(fakeAudio.layerHistory[VolumeLayer.sleepTimer], contains(0.0));
        expect(fakeAudio.layer(VolumeLayer.sleepTimer), 1);
      });
    });

    test('turned off mid-fade, the music is back at once', () {
      fakeAsync((FakeAsync async) {
        final ProviderContainer container = playing(async);
        final int before = fakeAudio.pauseCalls;
        final SleepTimerController timer = container.read(
          sleepTimerControllerProvider.notifier,
        )..start(const Duration(minutes: 15));

        async.elapse(const Duration(minutes: 14, seconds: 50));
        expect(fakeAudio.layer(VolumeLayer.sleepTimer), lessThan(1));

        timer.cancel();
        expect(fakeAudio.layer(VolumeLayer.sleepTimer), 1);

        async.elapse(const Duration(minutes: 5));
        expect(fakeAudio.layer(VolumeLayer.sleepTimer), 1);
        expect(fakeAudio.pauseCalls, before);
      });
    });

    test('a timer shorter than the fade fades over all of it', () {
      fakeAsync((FakeAsync async) {
        final ProviderContainer container = playing(async);
        container
            .read(sleepTimerControllerProvider.notifier)
            .start(const Duration(seconds: 10));

        async.elapse(const Duration(seconds: 5));
        expect(fakeAudio.layer(VolumeLayer.sleepTimer), closeTo(0.5, 0.05));
      });
    });
  });
}
