import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';

import '../domain/tag_reader.service.dart';

/// Tags through `audio_metadata_reader`, which is pure Dart and reads mp3,
/// m4a, flac and wav without a platform channel.
class TagReaderImpl implements TagReader {
  const TagReaderImpl();

  @override
  TrackTags read(File file) {
    try {
      final AudioMetadata tags = readMetadata(file, getImage: true);
      final Picture? cover = tags.pictures.isEmpty ? null : tags.pictures.first;

      return TrackTags(
        title: _clean(tags.title),
        artist: _clean(tags.artist),
        duration: tags.duration,
        cover: cover?.bytes,
        coverMimeType: cover?.mimetype,
      );
    } on Object {
      // No parser for the container, or a broken tag block. The music may
      // still play; the file name will stand in for the title.
      return TrackTags.none;
    }
  }

  static String? _clean(String? value) {
    final String? trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
