import 'package:freezed_annotation/freezed_annotation.dart';

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
  }) = _SceneEntity;
}
