import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../common/database/app_database.dart';
import '../../../common/database/daos/scene.dao.dart';
import 'ambient_sound.model.dart';
import '../domain/artist.entity.dart';
import '../domain/scene.entity.dart';
import '../domain/scene_layer.entity.dart';
import '../domain/track.entity.dart';

/// Between the cache and the domain.
///
/// The entities are what the rest of the app speaks; the table rows are what
/// survives a restart. Keeping the translation in one file means a column
/// added to the mirror has exactly one place that has to learn about it.

extension TrackRowX on TrackTableData {
  /// [artist] is the name for [artistId], when the artist is known.
  TrackEntity toEntity({String? artist}) => TrackEntity(
    id: id,
    title: title,
    audioUrl: audioUrl,
    createdAt: createdAt,
    btsVideoUrl: btsVideoUrl,
    durationSeconds: durationSeconds,
    artistId: artistId,
    artist: artist,
    coverUrl: coverUrl,
  );
}

extension TrackEntityX on TrackEntity {
  TrackTableCompanion toCompanion({required DateTime now}) =>
      TrackTableCompanion(
        id: Value<String>(id),
        title: Value<String>(title),
        audioUrl: Value<String>(audioUrl),
        btsVideoUrl: Value<String?>(btsVideoUrl),
        durationSeconds: Value<int?>(durationSeconds),
        artistId: Value<String?>(artistId),
        coverUrl: Value<String?>(coverUrl),
        createdAt: Value<DateTime>(createdAt),
        updatedAt: Value<DateTime>(now),
      );
}

extension ArtistRowX on ArtistTableData {
  ArtistEntity toEntity() => ArtistEntity(
    id: id,
    name: name,
    bio: bio,
    avatarUrl: avatarUrl,
    links: <String>[
      for (final String link in links.split('\n'))
        if (link.isNotEmpty) link,
    ],
  );
}

extension ArtistEntityX on ArtistEntity {
  ArtistTableCompanion toCompanion({required DateTime now}) =>
      ArtistTableCompanion(
        id: Value<String>(id),
        name: Value<String>(name),
        bio: Value<String?>(bio),
        avatarUrl: Value<String?>(avatarUrl),
        links: Value<String>(links.join('\n')),
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
      createdAt: scene.createdAt,
      ambients: AmbientSoundModel.fromCache(_decode(scene.ambients)),
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
    tapLabel: tapLabel,
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
        // The server's date, not the moment of caching: the "new" marks
        // (#148) compare it with the first launch.
        createdAt: Value<DateTime>(createdAt ?? now),
        updatedAt: Value<DateTime>(now),
        ambients: Value<String>(
          jsonEncode(AmbientSoundModel.toCache(ambients)),
        ),
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
    tapLabel: Value<String?>(tapLabel),
    idleFrameCount: Value<int>(idleFrameCount),
    onTrackChange: Value<bool>(onTrackChange),
    hideWhenClipped: Value<bool>(hideWhenClipped),
    eventIntervalMinSeconds: Value<int?>(eventIntervalMinSeconds),
    eventIntervalMaxSeconds: Value<int?>(eventIntervalMaxSeconds),
    createdAt: Value<DateTime>(now),
    updatedAt: Value<DateTime>(now),
  );
}

/// A JSON column read back; anything unreadable is no sounds at all.
Object? _decode(String json) {
  try {
    return jsonDecode(json);
  } on FormatException {
    return null;
  }
}
