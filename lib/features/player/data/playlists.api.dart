import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/playlist.entity.dart';
import '../domain/playlist_sync.dart';
import 'playlist_items.codec.dart';

/// The account's playlists in Supabase (#141). Row-level security scopes
/// every call to the signed-in listener.
class PlaylistsApi implements AccountPlaylists {
  const PlaylistsApi(this._client);

  static const String table = 'user_playlists';

  final SupabaseClient _client;

  @override
  Future<List<PlaylistEntity>> fetchAll() async {
    final List<Map<String, dynamic>> rows = await _client
        .from(table)
        .select('id, name, items, updated_at, deleted_at');

    return <PlaylistEntity>[
      for (final Map<String, dynamic> row in rows)
        PlaylistEntity(
          id: row['id'] as String,
          name: row['name'] as String,
          items: PlaylistItemsCodec.fromJson(row['items']),
          updatedAt: DateTime.parse(row['updated_at'] as String),
          deletedAt: row['deleted_at'] == null
              ? null
              : DateTime.parse(row['deleted_at'] as String),
        ),
    ];
  }

  @override
  Future<void> upsert(String userId, List<PlaylistEntity> playlists) async {
    if (playlists.isEmpty) return;
    await _client.from(table).upsert(<Map<String, dynamic>>[
      for (final PlaylistEntity p in playlists)
        <String, dynamic>{
          'id': p.id,
          'user_id': userId,
          'name': p.name,
          'items': PlaylistItemsCodec.toJson(p.items),
          'updated_at': p.updatedAt.toUtc().toIso8601String(),
          'deleted_at': p.deletedAt?.toUtc().toIso8601String(),
        },
    ]);
  }
}
