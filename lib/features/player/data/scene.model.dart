import 'package:freezed_annotation/freezed_annotation.dart';

import '../domain/scene.entity.dart';

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
  );
}
