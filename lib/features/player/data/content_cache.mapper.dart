import 'package:drift/drift.dart';

import '../../../common/database/app_database.dart';
import '../../../common/database/daos/scene.dao.dart';
import '../domain/scene.entity.dart';
import '../domain/scene_layer.entity.dart';
import '../domain/track.entity.dart';

/// Between the cache and the domain.
///
/// The entities are what the rest of the app speaks; the table rows are what
/// survives a restart. Keeping the translation in one file means a column
/// added to the mirror has exactly one place that has to learn about it.

extension TrackRowX on TrackTableData {
  TrackEntity toEntity() => TrackEntity(
    id: id,
    title: title,
    audioUrl: audioUrl,
    createdAt: createdAt,
    btsVideoUrl: btsVideoUrl,
    durationSeconds: durationSeconds,
  );
}

extension TrackEntityX on TrackEntity {
  /// [localAudioPath] is deliberately absent: the server knows nothing about
  /// this device's files, so writing it here would erase a cached download on
  /// every refresh.
  TrackTableCompanion toCompanion({required DateTime now}) =>
      TrackTableCompanion(
        id: Value<String>(id),
        title: Value<String>(title),
        audioUrl: Value<String>(audioUrl),
        btsVideoUrl: Value<String?>(btsVideoUrl),
        durationSeconds: Value<int?>(durationSeconds),
        createdAt: Value<DateTime>(createdAt),
        updatedAt: Value<DateTime>(now),
      );
}

extension CachedSceneX on CachedScene {
  SceneEntity toEntity() {
    final (SceneTableData scene, List<SceneLayerTableData> layers) = this;

    return SceneEntity(
      id: scene.id,
      title: scene.title,
      videoUrl: scene.videoUrl,
      sortOrder: scene.sortOrder,
      thumbnailUrl: scene.thumbnailUrl,
      canvasWidth: scene.canvasWidth,
      canvasHeight: scene.canvasHeight,
      layers: layers
          .map((SceneLayerTableData layer) => layer.toEntity())
          .toList(),
    );
  }
}

extension SceneLayerRowX on SceneLayerTableData {
  SceneLayerEntity toEntity() => SceneLayerEntity(
    id: id,
    zIndex: zIndex,
    spriteUrl: spriteUrl,
    frameCount: frameCount,
    fps: fps,
    offsetX: offsetX,
    offsetY: offsetY,
    parallax: parallax,
    tiles: tiles,
    onlyWhilePlaying: onlyWhilePlaying,
    hideWhenPaused: hideWhenPaused,
    tappable: tappable,
    idleFrameCount: idleFrameCount,
    onTrackChange: onTrackChange,
    hideWhenClipped: hideWhenClipped,
    eventIntervalMinSeconds: eventIntervalMinSeconds,
    eventIntervalMaxSeconds: eventIntervalMaxSeconds,
  );
}

extension SceneEntityX on SceneEntity {
  SceneTableCompanion toCompanion({required DateTime now}) =>
      SceneTableCompanion(
        id: Value<String>(id),
        title: Value<String>(title),
        videoUrl: Value<String>(videoUrl),
        thumbnailUrl: Value<String?>(thumbnailUrl),
        sortOrder: Value<int>(sortOrder),
        canvasWidth: Value<int>(canvasWidth),
        canvasHeight: Value<int>(canvasHeight),
        createdAt: Value<DateTime>(now),
        updatedAt: Value<DateTime>(now),
      );

  List<SceneLayerTableCompanion> toLayerCompanions({required DateTime now}) =>
      <SceneLayerTableCompanion>[
        for (final SceneLayerEntity layer in layers)
          layer.toCompanion(sceneId: id, now: now),
      ];
}

extension SceneLayerEntityX on SceneLayerEntity {
  SceneLayerTableCompanion toCompanion({
    required String sceneId,
    required DateTime now,
  }) => SceneLayerTableCompanion(
    id: Value<String>(id),
    sceneId: Value<String>(sceneId),
    zIndex: Value<int>(zIndex),
    spriteUrl: Value<String>(spriteUrl),
    frameCount: Value<int>(frameCount),
    fps: Value<double>(fps),
    offsetX: Value<int>(offsetX),
    offsetY: Value<int>(offsetY),
    parallax: Value<double>(parallax),
    tiles: Value<bool>(tiles),
    onlyWhilePlaying: Value<bool>(onlyWhilePlaying),
    hideWhenPaused: Value<bool>(hideWhenPaused),
    tappable: Value<bool>(tappable),
    idleFrameCount: Value<int>(idleFrameCount),
    onTrackChange: Value<bool>(onTrackChange),
    hideWhenClipped: Value<bool>(hideWhenClipped),
    eventIntervalMinSeconds: Value<int?>(eventIntervalMinSeconds),
    eventIntervalMaxSeconds: Value<int?>(eventIntervalMaxSeconds),
    createdAt: Value<DateTime>(now),
    updatedAt: Value<DateTime>(now),
  );
}
