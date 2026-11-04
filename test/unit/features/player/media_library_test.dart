import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/player/controller/collections.controller.dart';
import 'package:purelofi/features/player/controller/media_library.controller.dart';
import 'package:purelofi/features/player/controller/player.controller.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/controller/scene.controller.dart';
import 'package:purelofi/features/player/domain/media_library.dart';
import 'package:purelofi/features/player/domain/mood.entity.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/pro/controller/pro.provider.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/fake_collections.dart';
import '../../../helpers/fake_favorites.repository.dart';
import '../../../helpers/fake_pro.repository.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  late MockContentRepository content;
  late FakeAudioPlayerService audio;
  late FakeFavoritesRepository favorites;
  late FakePlaylistRepository playlists;
  late FakeProRepository pro;

  Future<ProviderContainer> start() async {
    content = MockContentRepository();
    audio = FakeAudioPlayerService();
    favorites = FakeFavoritesRepository(<String>{'b'});
    playlists = FakePlaylistRepository();
    pro = FakeProRepository(available: false);
    when(() => content.getScenes()).thenAnswer(
      (_) async => <SceneEntity>[
        makeScene('rainy', title: 'Rainy Room'),
        makeScene('roof', title: 'Rooftop').copyWith(sortOrder: 1),
      ],
    );
    when(() => content.getTracks()).thenAnswer(
      (_) async => <TrackEntity>[
        makeTrack('a', title: 'Dusk Tape'),
        makeTrack('b', title: 'Slow Bass'),
      ],
    );
    final ProviderContainer container = ProviderContainer(
      overrides: [
        contentRepositoryProvider.overrideWithValue(content),
        audioPlayerServiceProvider.overrideWithValue(audio),
        favoritesRepositoryProvider.overrideWithValue(favorites),
        playlistRepositoryProvider.overrideWithValue(playlists),
        proRepositoryProvider.overrideWithValue(pro),
        moodRepositoryProvider.overrideWithValue(
          FakeMoodRepository(const <MoodEntity>[
            MoodEntity(
              id: 'm',
              slug: 'm',
              title: 'Slow',
              trackIds: <String>['a'],
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
      pro.dispose();
    });
    container
      ..listen(playerControllerProvider, (_, _) {})
      ..listen(activeSceneControllerProvider, (_, _) {})
      ..read(mediaLibraryProvider);
    await pumpEventQueue();
    return container;
  }

  List<String> titles(List<BrowseNode> nodes) =>
      nodes.map((BrowseNode n) => n.title).toList();

  test('the library is handed to the audio service', () async {
    await start();

    expect(audio.library, isA<AppMediaLibrary>());
  });

  test(
    'the top shows what there is, folders that have nothing stay out',
    () async {
      await start();

      expect(titles(await audio.library!.children(BrowseIds.root)), <String>[
        'Rooms',
        'Favorites',
        'Moods',
      ]);

      await playlists.create('Drive');
      expect(
        titles(await audio.library!.children(BrowseIds.root)),
        contains('Playlists'),
      );
    },
  );

  test('rooms, favorites and moods list their entries, all playable', () async {
    await start();

    final List<BrowseNode> rooms = await audio.library!.children(
      BrowseIds.rooms,
    );
    expect(titles(rooms), <String>['Rainy Room', 'Rooftop']);
    expect(rooms.every((BrowseNode n) => n.playable), isTrue);

    expect(titles(await audio.library!.children(BrowseIds.favorites)), <String>[
      'Slow Bass',
    ]);
    expect(titles(await audio.library!.children(BrowseIds.moods)), <String>[
      'Slow',
    ]);
  });

  test('playing from the car: a track, a room, a mood', () async {
    final ProviderContainer container = await start();
    final MediaLibrary library = audio.library!;

    await library.play(BrowseIds.track('b'));
    expect(audio.playedTracks.last.id, 'b');

    await library.play(BrowseIds.room('roof'));
    expect(container.read(activeSceneControllerProvider)?.id, 'roof');

    await library.play(BrowseIds.mood('m'));
    expect(container.read(playbackScopeControllerProvider)?.id, 'm');
    expect(audio.playedTracks.last.id, 'a');
  });

  test('ids say what they are', () {
    expect(BrowseIds.parse('track:abc'), ('track', 'abc'));
    expect(BrowseIds.parse(BrowseIds.rooms), isNull);
  });
}
