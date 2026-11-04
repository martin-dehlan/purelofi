import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/player/controller/collections.controller.dart';
import 'package:purelofi/features/player/controller/player.controller.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/controller/room_music.controller.dart';
import 'package:purelofi/features/player/controller/scene.controller.dart';
import 'package:purelofi/features/player/data/scene_manifest.dart';
import 'package:purelofi/features/player/domain/mood.entity.dart';
import 'package:purelofi/features/player/domain/playback_mode.dart';
import 'package:purelofi/features/player/domain/playback_scope.dart';
import 'package:purelofi/features/player/domain/playlist.entity.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/fake_collections.dart';
import '../../../helpers/fake_favorites.repository.dart';
import '../../../helpers/fake_playback_preferences.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  late MockContentRepository content;
  late FakeAudioPlayerService audio;
  late FakeFavoritesRepository favorites;
  late FakePlaybackPreferences preferences;
  late FakePlaylistRepository playlists;

  final SceneEntity rainy = makeScene('rainy').copyWith(moodId: 'slow');
  final SceneEntity roof = makeScene(
    'roof',
    title: 'Rooftop',
  ).copyWith(sortOrder: 1, moodId: 'warm');
  final SceneEntity plain = makeScene('plain').copyWith(sortOrder: 2);

  Future<ProviderContainer> start({bool follow = true}) async {
    content = MockContentRepository();
    audio = FakeAudioPlayerService();
    favorites = FakeFavoritesRepository();
    preferences = FakePlaybackPreferences(PlaybackMode.inOrder, true, follow);
    playlists = FakePlaylistRepository();
    when(
      () => content.getScenes(),
    ).thenAnswer((_) async => <SceneEntity>[rainy, roof, plain]);
    when(() => content.getTracks()).thenAnswer(
      (_) async => <TrackEntity>[
        makeTrack('a'),
        makeTrack('b'),
        makeTrack('c'),
        makeTrack('d'),
      ],
    );
    final ProviderContainer container = ProviderContainer(
      overrides: [
        contentRepositoryProvider.overrideWithValue(content),
        audioPlayerServiceProvider.overrideWithValue(audio),
        favoritesRepositoryProvider.overrideWithValue(favorites),
        playbackPreferencesProvider.overrideWithValue(preferences),
        playlistRepositoryProvider.overrideWithValue(playlists),
        moodRepositoryProvider.overrideWithValue(
          FakeMoodRepository(const <MoodEntity>[
            MoodEntity(
              id: 'slow',
              slug: 'slow',
              title: 'Slow',
              trackIds: <String>['c', 'd'],
            ),
            MoodEntity(
              id: 'warm',
              slug: 'warm',
              title: 'Warm',
              trackIds: <String>['b'],
            ),
          ]),
        ),
      ],
      retry: (_, _) => null,
    );
    addTearDown(() {
      container.dispose();
      audio.dispose();
      favorites.dispose();
      playlists.dispose();
    });
    container
      ..listen(playerControllerProvider, (_, _) {})
      ..listen(roomMusicProvider, (_, _) {})
      ..listen(activeSceneControllerProvider, (_, _) {});
    await container.read(sceneListControllerProvider.future);
    container.read(activeSceneControllerProvider);
    await container.read(moodsProvider.future);
    await container.read(followRoomControllerProvider.future);
    await pumpEventQueue();
    return container;
  }

  PlaybackScope? scope(ProviderContainer c) =>
      c.read(playbackScopeControllerProvider);

  test('off, the rooms change nothing about the music', () async {
    final ProviderContainer c = await start(follow: false);

    expect(scope(c), isNull);
  });

  test('on, the room the app opens in plays its mood', () async {
    final ProviderContainer c = await start();

    expect(scope(c)?.id, 'slow');
    expect(scope(c)?.fromRoom, isTrue);

    await c.read(playerControllerProvider.notifier).playNext();
    expect(audio.playedTracks.last.id, 'c');
  });

  test('another room, another mood, from the next track on', () async {
    final ProviderContainer c = await start();
    final PlayerController player = c.read(playerControllerProvider.notifier);
    await player.playNext();
    final int before = audio.playedTracks.length;

    c.read(activeSceneControllerProvider.notifier).switchTo(roof);
    await pumpEventQueue();

    // The track playing is not cut.
    expect(audio.playedTracks.length, before);
    expect(scope(c)?.id, 'warm');
    expect(c.read(playerControllerProvider).upNext.first.id, 'b');
  });

  test('a room without a mood plays everything again', () async {
    final ProviderContainer c = await start();
    await c.read(playerControllerProvider.notifier).playNext();

    c.read(activeSceneControllerProvider.notifier).switchTo(plain);
    await pumpEventQueue();

    expect(scope(c), isNull);
  });

  test('a playlist the listener picked is never replaced by a room', () async {
    final ProviderContainer c = await start();
    final String id = await playlists.create('Mine');
    await playlists.add(id, const PlaylistItem(trackId: 'a'));
    await pumpEventQueue();
    await c
        .read(playerControllerProvider.notifier)
        .playScope(
          PlaybackScope(kind: ScopeKind.playlist, id: id, title: 'Mine'),
        );

    c.read(activeSceneControllerProvider.notifier).switchTo(roof);
    await pumpEventQueue();

    expect(scope(c)?.id, id);
  });

  test('scene.json can name the room\'s mood', () {
    final SceneManifest manifest = SceneManifest.parse(
      sceneJson: '{"title": "Rainy", "mood": "slow", "layers": {}}',
      spriteFileNames: const <String>[],
    );

    expect(manifest.mood, 'slow');
  });
}
