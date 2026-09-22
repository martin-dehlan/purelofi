import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/common/errors/app_error.dart';
import 'package:purelofi/features/player/controller/player.controller.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/controller/track.controller.dart';
import 'package:purelofi/features/player/domain/player.state.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/fake_favorites.repository.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  late MockContentRepository mockRepo;
  late FakeAudioPlayerService fakeAudio;
  late FakeFavoritesRepository fakeFavorites;
  late ProviderContainer container;

  Future<ProviderContainer> makeContainer(
    List<TrackEntity> tracks, {
    Set<String> favorites = const <String>{},
  }) async {
    when(() => mockRepo.getTracks()).thenAnswer((_) async => tracks);
    fakeFavorites = FakeFavoritesRepository(favorites);
    addTearDown(fakeFavorites.dispose);

    final ProviderContainer container = ProviderContainer(
      overrides: [
        contentRepositoryProvider.overrideWithValue(mockRepo),
        audioPlayerServiceProvider.overrideWithValue(fakeAudio),
        favoritesRepositoryProvider.overrideWithValue(fakeFavorites),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    container.listen(playerControllerProvider, (_, _) {});
    await container.read(trackListControllerProvider.future);
    return container;
  }

  setUp(() {
    mockRepo = MockContentRepository();
    fakeAudio = FakeAudioPlayerService();
    addTearDown(fakeAudio.dispose);
  });

  group('initial state', () {
    test('starts paused with no track', () async {
      container = await makeContainer(<TrackEntity>[makeTrack('a')]);

      final PlayerState state = container.read(playerControllerProvider);

      expect(state.isPlaying, isFalse);
      expect(state.currentTrack, isNull);
      expect(state.error, isNull);
    });
  });

  group('playNext', () {
    test(
      'hands a track to the audio player and records it as current',
      () async {
        container = await makeContainer(<TrackEntity>[makeTrack('a')]);

        await container.read(playerControllerProvider.notifier).playNext();

        expect(fakeAudio.playedTracks.single.id, 'a');
        expect(container.read(playerControllerProvider).currentTrack?.id, 'a');
      },
    );

    test('does nothing when there are no tracks', () async {
      container = await makeContainer(<TrackEntity>[]);

      await container.read(playerControllerProvider.notifier).playNext();

      expect(fakeAudio.playedTracks, isEmpty);
      expect(container.read(playerControllerProvider).currentTrack, isNull);
    });

    test('never repeats the current track when another is available', () async {
      container = await makeContainer(<TrackEntity>[
        makeTrack('a'),
        makeTrack('b'),
      ]);
      final PlayerController controller = container.read(
        playerControllerProvider.notifier,
      );

      await controller.playNext();
      final String? first = container
          .read(playerControllerProvider)
          .currentTrack
          ?.id;
      await controller.playNext();
      final String? second = container
          .read(playerControllerProvider)
          .currentTrack
          ?.id;

      expect(second, isNot(first));
    });

    test('replays the only track when it is the only one there is', () async {
      container = await makeContainer(<TrackEntity>[makeTrack('a')]);
      final PlayerController controller = container.read(
        playerControllerProvider.notifier,
      );

      await controller.playNext();
      await controller.playNext();

      expect(fakeAudio.playedTracks.map((TrackEntity t) => t.id), <String>[
        'a',
        'a',
      ]);
    });
  });

  group('continuous playback', () {
    test('a finished track triggers the next one', () async {
      container = await makeContainer(<TrackEntity>[
        makeTrack('a'),
        makeTrack('b'),
      ]);
      await container.read(playerControllerProvider.notifier).playNext();

      fakeAudio.emitNextRequest();
      await pumpEventQueue();

      expect(fakeAudio.playedTracks, hasLength(2));
      expect(
        fakeAudio.playedTracks.last.id,
        isNot(fakeAudio.playedTracks.first.id),
      );
    });

    test('a lock-screen skip advances the same way', () async {
      container = await makeContainer(<TrackEntity>[
        makeTrack('a'),
        makeTrack('b'),
      ]);

      fakeAudio.emitNextRequest();
      await pumpEventQueue();

      expect(fakeAudio.playedTracks, hasLength(1));
    });
  });

  group('togglePlayPause', () {
    test('starts the stream when nothing is playing yet', () async {
      container = await makeContainer(<TrackEntity>[makeTrack('a')]);

      await container.read(playerControllerProvider.notifier).togglePlayPause();

      expect(fakeAudio.playedTracks.single.id, 'a');
    });

    test('pauses while playing and resumes while paused', () async {
      container = await makeContainer(<TrackEntity>[makeTrack('a')]);
      final PlayerController controller = container.read(
        playerControllerProvider.notifier,
      );
      await controller.playNext();
      await pumpEventQueue();
      expect(container.read(playerControllerProvider).isPlaying, isTrue);

      await controller.togglePlayPause();
      await pumpEventQueue();

      expect(fakeAudio.pauseCalls, 1);
      expect(container.read(playerControllerProvider).isPlaying, isFalse);

      await controller.togglePlayPause();
      await pumpEventQueue();

      expect(fakeAudio.playCalls, 1);
      expect(container.read(playerControllerProvider).isPlaying, isTrue);
    });
  });

  group('failures', () {
    test('a playback failure surfaces as AppError.playback', () async {
      container = await makeContainer(<TrackEntity>[makeTrack('a')]);
      fakeAudio.failureOnPlay = const AppError.playback(
        message: 'the stream failed',
      );

      await container.read(playerControllerProvider.notifier).playNext();
      await pumpEventQueue();

      final PlayerState state = container.read(playerControllerProvider);
      expect(state.error, isA<PlaybackError>());
      expect(state.error?.userMessage, 'Playback error: the stream failed');
      expect(state.isPlaying, isFalse);
    });

    test('a later successful play clears the error', () async {
      container = await makeContainer(<TrackEntity>[makeTrack('a')]);
      fakeAudio.failureOnPlay = const AppError.playback(message: 'nope');
      await container.read(playerControllerProvider.notifier).playNext();
      await pumpEventQueue();

      fakeAudio.failureOnPlay = null;
      await container.read(playerControllerProvider.notifier).playNext();
      await pumpEventQueue();

      expect(container.read(playerControllerProvider).error, isNull);
    });
  });

  group('TrackListController', () {
    test('loads tracks from the repository', () async {
      container = await makeContainer(<TrackEntity>[makeTrack('a')]);

      expect(container.read(trackListControllerProvider).value?.single.id, 'a');
    });

    test('terminates instead of hanging in loading', () async {
      when(() => mockRepo.getTracks()).thenAnswer((_) async => <TrackEntity>[]);
      final ProviderContainer container = ProviderContainer(
        overrides: [
          contentRepositoryProvider.overrideWithValue(mockRepo),
          audioPlayerServiceProvider.overrideWithValue(fakeAudio),
        ],
        retry: (_, _) => null,
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(trackListControllerProvider.future),
        completes,
      );
    });
  });
}
