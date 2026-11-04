import 'package:freezed_annotation/freezed_annotation.dart';

import 'ambient_sound.entity.dart';
import 'scene_layer.entity.dart';

part 'scene.entity.freezed.dart';

/// A looping pixel-art background the listener can switch between.
@freezed
abstract class SceneEntity with _$SceneEntity {
  const factory SceneEntity({
    required String id,
    required String title,
    required String videoUrl,
    required int sortOrder,
    String? thumbnailUrl,

    /// When it was added, for marking what is new (#148). Null for scenes
    /// built in code, like the dev scene.
    DateTime? createdAt,

    /// The authoring grid the layers are drawn on. The renderer scales from
    /// it by an integer factor, which is what keeps the pixels square.
    @Default(320) int canvasWidth,
    @Default(696) int canvasHeight,

    /// Sprite layers, back to front. Empty means this is still a video
    /// scene and [videoUrl] is what plays.
    @Default(<SceneLayerEntity>[]) List<SceneLayerEntity> layers,

    /// The sounds the room brings (#136), in the order they are listed.
    @Default(<AmbientSoundEntity>[]) List<AmbientSoundEntity> ambients,

    /// The mood the room plays when the music follows the room (#143).
    String? moodId,
  }) = _SceneEntity;

  const SceneEntity._();

  /// Whether this scene is drawn from sprites rather than played as a video.
  bool get isLayered => layers.isNotEmpty;
}
