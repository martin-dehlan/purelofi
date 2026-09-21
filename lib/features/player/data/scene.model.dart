import 'package:freezed_annotation/freezed_annotation.dart';

import '../domain/scene.entity.dart';
import '../domain/scene_layer.entity.dart';
import 'scene_layer.model.dart';

part 'scene.model.freezed.dart';
part 'scene.model.g.dart';

/// A row of the Supabase `scenes` table.
@freezed
abstract class SceneModel with _$SceneModel {
  const factory SceneModel({
    required String id,
    required String title,
    @JsonKey(name: 'video_url') required String videoUrl,
    @JsonKey(name: 'sort_order') required int sortOrder,
    @JsonKey(name: 'is_active') required bool isActive,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'thumbnail_url') String? thumbnailUrl,
    @JsonKey(name: 'canvas_width') @Default(320) int canvasWidth,
    @JsonKey(name: 'canvas_height') @Default(568) int canvasHeight,

    /// Embedded by PostgREST from the `scene_layers` relation.
    @JsonKey(name: 'scene_layers')
    @Default(<SceneLayerModel>[])
    List<SceneLayerModel> layers,
  }) = _SceneModel;

  factory SceneModel.fromJson(Map<String, dynamic> json) =>
      _$SceneModelFromJson(json);
}

extension SceneModelX on SceneModel {
  SceneEntity toEntity() => SceneEntity(
    id: id,
    title: title,
    videoUrl: videoUrl,
    sortOrder: sortOrder,
    thumbnailUrl: thumbnailUrl,
    canvasWidth: canvasWidth,
    canvasHeight: canvasHeight,
    // Back to front, whatever order the API happened to return them in.
    layers: (layers.map((SceneLayerModel layer) => layer.toEntity()).toList()
      ..sort(
        (SceneLayerEntity a, SceneLayerEntity b) =>
            a.zIndex.compareTo(b.zIndex),
      )),
  );
}
