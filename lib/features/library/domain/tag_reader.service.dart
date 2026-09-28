import 'dart:io';
import 'dart:typed_data';

/// What a file says about itself.
class TrackTags {
  const TrackTags({
    this.title,
    this.artist,
    this.duration,
    this.cover,
    this.coverMimeType,
  });

  static const TrackTags none = TrackTags();

  final String? title;
  final String? artist;
  final Duration? duration;
  final Uint8List? cover;
  final String? coverMimeType;
}

/// Reads the tags of an audio file. Behind an interface so the importer can
/// be tested without real audio files (see `docs/10`).
abstract class TagReader {
  /// Never throws: a file without readable tags is [TrackTags.none], and the
  /// importer falls back to the file name.
  TrackTags read(File file);
}
