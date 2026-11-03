import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/player/controller/player.controller.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/controller/sleep_timer.controller.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';

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
}
