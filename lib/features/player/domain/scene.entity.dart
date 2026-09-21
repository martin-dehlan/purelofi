import 'package:freezed_annotation/freezed_annotation.dart';

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

    /// The authoring grid the layers are drawn on. The renderer scales from
    /// it by an integer factor, which is what keeps the pixels square.
    @Default(320) int canvasWidth,
    @Default(696) int canvasHeight,

    /// Sprite layers, back to front. Empty means this is still a video
    /// scene and [videoUrl] is what plays.
    @Default(<SceneLayerEntity>[]) List<SceneLayerEntity> layers,
  }) = _SceneEntity;

  const SceneEntity._();

  /// Whether this scene is drawn from sprites rather than played as a video.
  bool get isLayered => layers.isNotEmpty;
}
