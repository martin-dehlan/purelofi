import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/common/database/app_database.dart';
import 'package:purelofi/common/database/daos/playlist.dao.dart';
import 'package:purelofi/features/library/controller/library.provider.dart';
import 'package:purelofi/features/player/controller/collections.controller.dart';
import 'package:purelofi/features/player/controller/player.controller.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/data/mood.repository.impl.dart';
import 'package:purelofi/features/player/data/playlist.repository.impl.dart';
import 'package:purelofi/features/player/domain/mood.entity.dart';
import 'package:purelofi/features/player/domain/playback_mode.dart';
import 'package:purelofi/features/player/domain/playback_scope.dart';
import 'package:purelofi/features/player/domain/playlist.entity.dart';
import 'package:purelofi/features/player/domain/playlist_sync.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/fake_collections.dart';
import '../../../helpers/fake_favorites.repository.dart';
import '../../../helpers/fake_library.repository.dart';
import '../../../helpers/fake_playback_preferences.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  final DateTime t0 = DateTime.utc(2026, 11, 5, 10);
  PlaylistEntity list(String id, int minute, {String name = 'Evening'}) =>
      PlaylistEntity(
        id: id,
        name: name,
        updatedAt: t0.add(Duration(minutes: minute)),
      );

  group('mergePlaylists', () {
    test('only on one side goes to the other', () {
      final PlaylistMerge merge = mergePlaylists(
        device: <(PlaylistEntity, bool)>[(list('here', 1), false)],
        account: <PlaylistEntity>[list('there', 1)],
      );

      expect(merge.push.map((PlaylistEntity p) => p.id), <String>['here']);
      expect(merge.pull.map((PlaylistEntity p) => p.id), <String>['there']);
    });

    test('the newer copy wins, a deletion included', () {
      final PlaylistMerge merge = mergePlaylists(
        device: <(PlaylistEntity, bool)>[
          (list('a', 5, name: 'Renamed here'), false),
          (list('b', 1), true),
        ],
        account: <PlaylistEntity>[
          list('a', 2),
          list('b', 3).copyWith(deletedAt: t0.add(const Duration(minutes: 3))),
        ],
      );

      expect(merge.push.single.name, 'Renamed here');
      expect(merge.pull.single.isDeleted, isTrue);
    });

    test('a synced, unchanged copy stays where it is', () {
      final PlaylistMerge merge = mergePlaylists(
        device: <(PlaylistEntity, bool)>[(list('a', 1), true)],
        account: <PlaylistEntity>[list('a', 1)],
      );

      expect(merge.push, isEmpty);
      expect(merge.pull, isEmpty);
    });

    test('a round pushes, marks synced and pulls', () async {
      final FakePlaylistRepository device = FakePlaylistRepository(
        <PlaylistEntity>[list('mine', 1)],
      );
      final FakeAccountPlaylists account = FakeAccountPlaylists()
        ..rows['theirs'] = list('theirs', 1);
      addTearDown(device.dispose);

      await syncPlaylists(userId: 'u', device: device, account: account);

      expect(account.rows.keys, containsAll(<String>['mine', 'theirs']));
      expect(device.playlists['mine']!.$2, isTrue);
      expect(device.playlists['theirs']!.$2, isTrue);
    });
  });

  group('PlaylistRepositoryImpl', () {
    late AppDatabase database;
    late PlaylistRepositoryImpl playlists;
    late int changes;

    setUp(() {
      database = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.memory()),
      );
      addTearDown(database.close);
      changes = 0;
      int tick = 0;
      playlists = PlaylistRepositoryImpl(
        PlaylistDao(database),
        newId: () => 'p1',
        now: () => t0.add(Duration(seconds: tick++)),
        onChange: () => changes++,
      );
    });

    test('makes, fills, reorders and empties a playlist', () async {
      final String id = await playlists.create('  Study  ');
      await playlists.add(id, const PlaylistItem(trackId: 'a'));
      await playlists.add(
        id,
        const PlaylistItem(trackId: 'mine', source: TrackSource.local),
      );
      await playlists.add(id, const PlaylistItem(trackId: 'b'));
      await playlists.move(id, 2, 0);
      await playlists.removeAt(id, 1);

      final PlaylistEntity p = (await playlists.watchPlaylists().first).single;
      expect(p.name, 'Study');
      expect(p.items.map((PlaylistItem i) => i.trackId), <String>['b', 'mine']);
      expect(p.items.last.source, TrackSource.local);
      expect(changes, 6);
    });

    test('a deleted playlist leaves the list but stays for the sync', () async {
      final String id = await playlists.create('Gone');
      await playlists.delete(id);

      expect(await playlists.watchPlaylists().first, isEmpty);
      final List<(PlaylistEntity, bool)> all = await playlists.all();
      expect(all.single.$1.isDeleted, isTrue);
      expect(all.single.$2, isFalse);
    });
  });

  test('a mood row is read with its tracks in position order', () {
    final MoodEntity mood = MoodRepositoryImpl.fromRow(<String, dynamic>{
      'id': 'm',
      'slug': 'rainy',
      'title': 'Rainy evenings',
      'cover_url': null,
      'mood_tracks': <Object?>[
        <String, dynamic>{'track_id': 'b', 'position': 2},
        <String, dynamic>{'track_id': 'a', 'position': 1},
      ],
    });

    expect(mood.trackIds, <String>['a', 'b']);
  });

  group('playing a mood or playlist', () {
    late MockContentRepository content;
    late FakeAudioPlayerService audio;
    late FakeFavoritesRepository favorites;
    late FakeLibraryRepository library;
    late FakePlaylistRepository playlists;

    Future<ProviderContainer> start() async {
      content = MockContentRepository();
      audio = FakeAudioPlayerService();
      favorites = FakeFavoritesRepository();
      library = FakeLibraryRepository(<TrackEntity>[
        makeTrack('mine').copyWith(source: TrackSource.local),
        makeTrack('also-mine').copyWith(source: TrackSource.local),
      ]);
      playlists = FakePlaylistRepository();
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
          libraryRepositoryProvider.overrideWithValue(library),
          playbackPreferencesProvider.overrideWithValue(
            FakePlaybackPreferences(PlaybackMode.inOrder),
          ),
          moodRepositoryProvider.overrideWithValue(
            FakeMoodRepository(const <MoodEntity>[
              MoodEntity(
                id: 'rainy',
                slug: 'rainy',
                title: 'Rainy',
                trackIds: <String>['c', 'a'],
              ),
            ]),
          ),
          playlistRepositoryProvider.overrideWithValue(playlists),
        ],
        retry: (_, _) => null,
      );
      addTearDown(() {
        container.dispose();
        audio.dispose();
        favorites.dispose();
        library.dispose();
        playlists.dispose();
      });
      container.listen(playerControllerProvider, (_, _) {});
      container.listen(playlistsProvider, (_, _) {});
      await pumpEventQueue();
      return container;
    }

    List<String> played() =>
        audio.playedTracks.map((TrackEntity t) => t.id).toList();

    test('a mood plays its own tracks, in its own order', () async {
      final ProviderContainer container = await start();
      final PlayerController player = container.read(
        playerControllerProvider.notifier,
      );

      await player.playScope(
        const PlaybackScope(kind: ScopeKind.mood, id: 'rainy', title: 'Rainy'),
      );
      await player.playNext();
      await player.playNext();

      expect(played(), <String>['c', 'a', 'c']);
    });

    test(
      'a playlist mixes both sides, and leaving it is everything again',
      () async {
        final ProviderContainer container = await start();
        final String id = await playlists.create('Mixed');
        await playlists.add(id, const PlaylistItem(trackId: 'b'));
        await playlists.add(
          id,
          const PlaylistItem(trackId: 'mine', source: TrackSource.local),
        );
        await pumpEventQueue();
        final PlayerController player = container.read(
          playerControllerProvider.notifier,
        );

        await player.playScope(
          PlaybackScope(kind: ScopeKind.playlist, id: id, title: 'Mixed'),
        );
        await player.playNext();
        expect(played(), <String>['b', 'mine']);

        await player.leaveScope();
        expect(container.read(playbackScopeControllerProvider), isNull);
        expect(
          container
              .read(playerControllerProvider)
              .upNext
              .map((TrackEntity t) => t.source),
          everyElement(TrackSource.local),
          reason: 'back to everything on the side last played',
        );
      },
    );

    test('a track picked from outside the mood ends the mood', () async {
      final ProviderContainer container = await start();
      final PlayerController player = container.read(
        playerControllerProvider.notifier,
      );
      await player.playScope(
        const PlaybackScope(kind: ScopeKind.mood, id: 'rainy', title: 'Rainy'),
      );

      await player.playTrack(makeTrack('d'));

      expect(container.read(playbackScopeControllerProvider), isNull);
    });
  });
}
