import 'package:freezed_annotation/freezed_annotation.dart';

import '../domain/scene_layer.entity.dart';

part 'scene_layer.model.freezed.dart';
part 'scene_layer.model.g.dart';

/// A row of the Supabase `scene_layers` table.
@freezed
abstract class SceneLayerModel with _$SceneLayerModel {
  const factory SceneLayerModel({
    required String id,
    @JsonKey(name: 'scene_id') required String sceneId,
    @JsonKey(name: 'z_index') required int zIndex,
    @JsonKey(name: 'sprite_url') required String spriteUrl,
    @JsonKey(name: 'frame_count') @Default(1) int frameCount,
    @Default(0) double fps,
    @JsonKey(name: 'offset_x') @Default(0) int offsetX,
    @JsonKey(name: 'offset_y') @Default(0) int offsetY,
    @Default(1) double parallax,
    @Default(false) bool tiles,
    @JsonKey(name: 'only_while_playing') @Default(false) bool onlyWhilePlaying,
    @JsonKey(name: 'hide_when_paused') @Default(false) bool hideWhenPaused,
    @JsonKey(name: 'event_interval_min_seconds') int? eventIntervalMinSeconds,
    @JsonKey(name: 'event_interval_max_seconds') int? eventIntervalMaxSeconds,
  }) = _SceneLayerModel;

  factory SceneLayerModel.fromJson(Map<String, dynamic> json) =>
      _$SceneLayerModelFromJson(json);
}

extension SceneLayerModelX on SceneLayerModel {
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
    eventIntervalMinSeconds: eventIntervalMinSeconds,
    eventIntervalMaxSeconds: eventIntervalMaxSeconds,
  );
}
