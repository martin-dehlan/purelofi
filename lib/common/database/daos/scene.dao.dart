import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/scene.table.dart';
import '../tables/scene_layer.table.dart';

part 'scene.dao.g.dart';

/// A cached scene together with the layers that belong to it.
typedef CachedScene = (SceneTableData scene, List<SceneLayerTableData> layers);

@DriftAccessor(tables: <Type>[SceneTable, SceneLayerTable])
class SceneDao extends DatabaseAccessor<AppDatabase> with _$SceneDaoMixin {
  SceneDao(super.db);

  Future<List<CachedScene>> getScenes() async {
    final List<SceneTableData> scenes =
        await (select(sceneTable)
              ..orderBy(<OrderClauseGenerator<$SceneTableTable>>[
                ($SceneTableTable s) => OrderingTerm.asc(s.sortOrder),
              ]))
            .get();
    if (scenes.isEmpty) return <CachedScene>[];

    // One query for every layer, then grouped in memory: a query per scene
    // would be a handful of round trips for something this small.
    final List<SceneLayerTableData> layers =
        await (select(sceneLayerTable)
              ..orderBy(<OrderClauseGenerator<$SceneLayerTableTable>>[
                ($SceneLayerTableTable l) => OrderingTerm.asc(l.zIndex),
              ]))
            .get();

    final Map<String, List<SceneLayerTableData>> bySceneId =
        <String, List<SceneLayerTableData>>{};
    for (final SceneLayerTableData layer in layers) {
      bySceneId
          .putIfAbsent(layer.sceneId, () => <SceneLayerTableData>[])
          .add(layer);
    }

    return <CachedScene>[
      for (final SceneTableData scene in scenes)
        (scene, bySceneId[scene.id] ?? <SceneLayerTableData>[]),
    ];
  }

  /// Writes what the server just sent, and forgets scenes it no longer lists.
  ///
  /// Layers are replaced rather than merged, for the same reason the upload
  /// tool replaces them: a layer deleted from a scene has to disappear, not
  /// linger.
  Future<void> replaceScenes(
    List<SceneTableCompanion> scenes,
    List<SceneLayerTableCompanion> layers,
  ) async {
    await transaction(() async {
      final Set<String> keep = scenes
          .map((SceneTableCompanion s) => s.id.value)
          .toSet();

      await (delete(
        sceneTable,
      )..where(($SceneTableTable s) => s.id.isNotIn(keep))).go();
      await (delete(
        sceneLayerTable,
      )..where(($SceneLayerTableTable l) => l.sceneId.isIn(keep))).go();
      await (delete(
        sceneLayerTable,
      )..where(($SceneLayerTableTable l) => l.sceneId.isNotIn(keep))).go();

      await batch((Batch b) {
        b.insertAllOnConflictUpdate(sceneTable, scenes);
        b.insertAll(sceneLayerTable, layers);
      });
    });
  }
}
