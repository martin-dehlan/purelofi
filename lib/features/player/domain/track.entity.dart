import 'package:freezed_annotation/freezed_annotation.dart';

part 'track.entity.freezed.dart';

/// A single recorded track. [btsVideoUrl] is the behind-the-scenes footage
/// that shows it being played — the "this is real, not AI" proof.
@freezed
abstract class TrackEntity with _$TrackEntity {
  const factory TrackEntity({
    required String id,
    required String title,
    required String audioUrl,
    required DateTime createdAt,
    String? btsVideoUrl,
    int? durationSeconds,
  }) = _TrackEntity;
}
