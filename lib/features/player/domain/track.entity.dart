import 'package:freezed_annotation/freezed_annotation.dart';

part 'track.entity.freezed.dart';

/// Where a track came from.
enum TrackSource {
  /// PureLofi's own recordings, from Supabase.
  catalogue,

  /// A file the listener copied in from their own device (#66). Played from
  /// disk, never cached, never reported by title.
  local,
}

/// A single recorded track. [btsVideoUrl] is the behind-the-scenes footage
/// that shows it being played — the "this is real, not AI" proof.
///
/// A local track is one of the listener's own files: [audioUrl] is then a
/// `file://` URI, there is never footage, and [artist] and [coverPath] come
/// from the file's tags.
@freezed
abstract class TrackEntity with _$TrackEntity {
  const factory TrackEntity({
    required String id,
    required String title,
    required String audioUrl,
    required DateTime createdAt,
    String? btsVideoUrl,
    int? durationSeconds,
    @Default(TrackSource.catalogue) TrackSource source,
    String? artist,
    String? coverPath,
  }) = _TrackEntity;
}
