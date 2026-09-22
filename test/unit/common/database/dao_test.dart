import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/common/database/app_database.dart';
import 'package:purelofi/common/database/daos/scene.dao.dart';
import 'package:purelofi/common/database/daos/track.dao.dart';

void main() {
  late AppDatabase database;
  late TrackDao tracks;
  late SceneDao scenes;

  final DateTime now = DateTime.utc(2026, 9, 22);

  TrackTableCompanion track(String id, {int daysOld = 0}) =>
      TrackTableCompanion(
        id: Value<String>(id),
        title: Value<String>(id),
        audioUrl: Value<String>('https://example.com/$id.mp3'),
        createdAt: Value<DateTime>(now.subtract(Duration(days: daysOld))),
        updatedAt: Value<DateTime>(now),
      );

  SceneTableCompanion scene(String id, {int sortOrder = 0}) =>
      SceneTableCompanion(
        id: Value<String>(id),
        title: Value<String>(id),
        videoUrl: const Value<String>(''),
        sortOrder: Value<int>(sortOrder),
        createdAt: Value<DateTime>(now),
        updatedAt: Value<DateTime>(now),
      );

  SceneLayerTableCompanion layer(String id, String sceneId, int zIndex) =>
      SceneLayerTableCompanion(
        id: Value<String>(id),
        sceneId: Value<String>(sceneId),
        zIndex: Value<int>(zIndex),
        spriteUrl: Value<String>('https://example.com/$id.png'),
        createdAt: Value<DateTime>(now),
        updatedAt: Value<DateTime>(now),
      );

  setUp(() {
    database = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory()),
    );
    addTearDown(database.close);
    tracks = TrackDao(database);
    scenes = SceneDao(database);
  });

  group('TrackDao', () {
    test('hands tracks back oldest first, as the server orders them', () async {
      await tracks.replaceTracks(<TrackTableCompanion>[
        track('new'),
        track('old', daysOld: 30),
      ]);

      expect(
        (await tracks.getTracks()).map((TrackTableData t) => t.id),
        <String>['old', 'new'],
      );
    });

    test('a second write updates rather than duplicates', () async {
      await tracks.replaceTracks(<TrackTableCompanion>[track('a')]);
      await tracks.replaceTracks(<TrackTableCompanion>[
        track('a').copyWith(title: const Value<String>('renamed')),
      ]);

      final List<TrackTableData> all = await tracks.getTracks();
      expect(all, hasLength(1));
      expect(all.single.title, 'renamed');
    });

    test('a favorite is marked unsynced, because nobody has it yet', () async {
      // The column earns its keep with the favorites feature: a local change
      // the server has not been told about.
      await tracks.replaceTracks(<TrackTableCompanion>[track('a')]);
      expect((await tracks.getTrackById('a'))?.isSynced, isTrue);

      await tracks.setFavorite('a', isFavorite: true);

      final TrackTableData? row = await tracks.getTrackById('a');
      expect(row?.isFavorite, isTrue);
      expect(row?.isSynced, isFalse);
      expect((await tracks.getFavorites()).single.id, 'a');
    });

    test('watchTracks reports a change without being asked again', () async {
      await tracks.replaceTracks(<TrackTableCompanion>[track('a')]);

      final Future<List<TrackTableData>> second = tracks
          .watchTracks()
          .skip(1)
          .first;
      await tracks.replaceTracks(<TrackTableCompanion>[track('a'), track('b')]);

      expect(await second, hasLength(2));
    });
  });

  group('SceneDao', () {
    test('groups each scene with its own layers, in draw order', () async {
      await scenes.replaceScenes(
        <SceneTableCompanion>[scene('s2', sortOrder: 1), scene('s1')],
        <SceneLayerTableCompanion>[
          layer('b', 's1', 2),
          layer('a', 's1', 1),
          layer('c', 's2', 1),
        ],
      );

      final List<CachedScene> cached = await scenes.getScenes();

      expect(cached.map((CachedScene row) => row.$1.id), <String>['s1', 's2']);
      expect(cached.first.$2.map((SceneLayerTableData l) => l.id), <String>[
        'a',
        'b',
      ]);
      expect(cached.last.$2.single.id, 'c');
    });

    test('a scene the server dropped takes its layers with it', () async {
      await scenes.replaceScenes(
        <SceneTableCompanion>[scene('s1'), scene('s2')],
        <SceneLayerTableCompanion>[layer('a', 's1', 1), layer('c', 's2', 1)],
      );

      await scenes.replaceScenes(
        <SceneTableCompanion>[scene('s1')],
        <SceneLayerTableCompanion>[layer('a', 's1', 1)],
      );

      final List<CachedScene> cached = await scenes.getScenes();
      expect(cached, hasLength(1));
      expect(
        await database.select(database.sceneLayerTable).get(),
        hasLength(1),
        reason: 'an orphaned layer would be cached forever',
      );
    });
  });
}
