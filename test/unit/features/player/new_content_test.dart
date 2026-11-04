import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/common/database/app_database.dart';
import 'package:purelofi/common/database/daos/seen_item.dao.dart';
import 'package:purelofi/features/player/controller/new_content.controller.dart';
import 'package:purelofi/features/player/controller/player.controller.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/controller/scene.controller.dart';
import 'package:purelofi/features/player/data/content_cache.mapper.dart';
import 'package:purelofi/features/player/data/new_content.repository.impl.dart';
import 'package:purelofi/features/player/domain/new_content.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/fake_favorites.repository.dart';
import '../../../helpers/fake_new_content.repository.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  final DateTime installed = DateTime(2026, 10, 1);

  group('newIds', () {
    final List<(String, DateTime?)> items = <(String, DateTime?)>[
      ('before', DateTime(2026, 9, 1)),
      ('after', DateTime(2026, 10, 20)),
      ('seen', DateTime(2026, 10, 21)),
      ('unknown', null),
    ];

    test('only what came after the first launch and was not met yet', () {
      expect(
        newIds<(String, DateTime?)>(
          items,
          id: ((String, DateTime?) i) => i.$1,
          createdAt: ((String, DateTime?) i) => i.$2,
          firstLaunch: installed,
          seen: <String>{'seen'},
        ),
        <String>{'after'},
      );
    });
  });

  group('NewContentRepositoryImpl', () {
    late AppDatabase database;

    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      database = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.memory()),
      );
      addTearDown(database.close);
    });

    test('the first launch is set once and kept', () async {
      final NewContentRepositoryImpl first = NewContentRepositoryImpl(
        dao: SeenItemDao(database),
        now: () => installed,
      );
      expect(await first.firstLaunch(), installed);

      final NewContentRepositoryImpl later = NewContentRepositoryImpl(
        dao: SeenItemDao(database),
        now: () => DateTime(2027),
      );
      expect(await later.firstLaunch(), installed);
    });

    test('remembers what was seen, per kind, once', () async {
      final NewContentRepositoryImpl repository = NewContentRepositoryImpl(
        dao: SeenItemDao(database),
      );
      await repository.markSeen(SeenKind.scene, 'rainy');
      await repository.markSeen(SeenKind.scene, 'rainy');
      await repository.markSeen(SeenKind.track, 'a');

      expect(await repository.watchSeen(SeenKind.scene).first, <String>{
        'rainy',
      });
      expect(await repository.watchSeen(SeenKind.track).first, <String>{'a'});
    });
  });

  group('marks', () {
    late MockContentRepository content;
    late FakeAudioPlayerService audio;
    late FakeFavoritesRepository favorites;
    late FakeNewContentRepository seen;

    SceneEntity scene(String id, DateTime createdAt) =>
        makeScene(id).copyWith(createdAt: createdAt);
    TrackEntity track(String id, DateTime createdAt) =>
        makeTrack(id).copyWith(createdAt: createdAt);

    Future<ProviderContainer> start() async {
      content = MockContentRepository();
      audio = FakeAudioPlayerService();
      favorites = FakeFavoritesRepository();
      seen = FakeNewContentRepository(firstLaunch: installed);
      when(() => content.getScenes()).thenAnswer(
        (_) async => <SceneEntity>[
          scene('old-room', DateTime(2026, 9, 1)),
          scene('new-room', DateTime(2026, 10, 20)),
        ],
      );
      when(() => content.getTracks()).thenAnswer(
        (_) async => <TrackEntity>[
          track('old', DateTime(2026, 9, 1)),
          track('new', DateTime(2026, 10, 20)),
        ],
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [
          contentRepositoryProvider.overrideWithValue(content),
          audioPlayerServiceProvider.overrideWithValue(audio),
          favoritesRepositoryProvider.overrideWithValue(favorites),
          newContentRepositoryProvider.overrideWithValue(seen),
        ],
        retry: (_, _) => null,
      );
      addTearDown(() {
        container.dispose();
        audio.dispose();
        favorites.dispose();
        seen.dispose();
      });
      container
        ..listen(newContentMarkerProvider, (_, _) {})
        ..listen(newScenesProvider, (_, _) {})
        ..listen(newTracksProvider, (_, _) {});
      await container.read(sceneListControllerProvider.future);
      await container.read(firstLaunchProvider.future);
      await pumpEventQueue();
      return container;
    }

    test('what came after the first launch is marked new', () async {
      final ProviderContainer container = await start();

      expect(container.read(newTracksProvider), <String>{'new'});
      // The room the app opens in is stepped into at once, so it is the
      // other new one that stays marked — here the first room is old.
      expect(container.read(newScenesProvider), <String>{'new-room'});
    });

    test(
      'stepping into a room and playing a track take the marks off',
      () async {
        final ProviderContainer container = await start();

        container
            .read(activeSceneControllerProvider.notifier)
            .switchTo(scene('new-room', DateTime(2026, 10, 20)));
        await container
            .read(playerControllerProvider.notifier)
            .playTrack(track('new', DateTime(2026, 10, 20)));
        await pumpEventQueue();

        expect(container.read(newScenesProvider), isEmpty);
        expect(container.read(newTracksProvider), isEmpty);
      },
    );
  });

  test('the cache keeps a room\'s own date, not the moment it was cached', () {
    // Otherwise every room read back offline would look new (#148).
    final DateTime added = DateTime(2026, 9, 1);
    final SceneTableCompanion row = makeScene(
      's',
    ).copyWith(createdAt: added).toCompanion(now: DateTime(2026, 11, 5));

    expect(row.createdAt.value, added);
  });
}
