import 'package:freezed_annotation/freezed_annotation.dart';

import '../domain/track.entity.dart';

part 'track.model.freezed.dart';
part 'track.model.g.dart';

/// A row of the Supabase `tracks` table.
@freezed
abstract class TrackModel with _$TrackModel {
  const factory TrackModel({
    required String id,
    required String title,
    @JsonKey(name: 'audio_url') required String audioUrl,
    @JsonKey(name: 'is_active') required bool isActive,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'bts_video_url') String? btsVideoUrl,
    @JsonKey(name: 'duration_seconds') int? durationSeconds,
  }) = _TrackModel;

  factory TrackModel.fromJson(Map<String, dynamic> json) =>
      _$TrackModelFromJson(json);
}

extension TrackModelX on TrackModel {
  TrackEntity toEntity() => TrackEntity(
    id: id,
    title: title,
    audioUrl: audioUrl,
    createdAt: createdAt,
    btsVideoUrl: btsVideoUrl,
    durationSeconds: durationSeconds,
  );
}
