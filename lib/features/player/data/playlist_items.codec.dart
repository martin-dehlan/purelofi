import 'dart:convert';

import '../domain/playlist.entity.dart';
import '../domain/track.entity.dart';

/// Playlist items as JSON, the same shape on the device and on the account
/// (#141): `[{"track_id": "...", "source": "catalogue"}]`.
abstract final class PlaylistItemsCodec {
  static List<Map<String, String>> toJson(
    List<PlaylistItem> items,
  ) => <Map<String, String>>[
    for (final PlaylistItem item in items)
      <String, String>{'track_id': item.trackId, 'source': item.source.name},
  ];

  static List<PlaylistItem> fromJson(Object? json) {
    if (json is! List) return const <PlaylistItem>[];

    return <PlaylistItem>[
      for (final Object? row in json)
        if (row is Map && row['track_id'] is String)
          PlaylistItem(
            trackId: row['track_id'] as String,
            source: row['source'] == TrackSource.local.name
                ? TrackSource.local
                : TrackSource.catalogue,
          ),
    ];
  }

  static String encode(List<PlaylistItem> items) => jsonEncode(toJson(items));

  static List<PlaylistItem> decode(String text) {
    try {
      return fromJson(jsonDecode(text));
    } on FormatException {
      return const <PlaylistItem>[];
    }
  }
}
