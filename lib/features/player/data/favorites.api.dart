import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/favorites_sync.dart';

/// The account's favorites in Supabase (#78). Row-level security scopes
/// every call to the signed-in listener, so there is no user id to pass
/// for reading — only for adding, where the policy checks it.
class FavoritesApi implements AccountFavorites {
  const FavoritesApi(this._client);

  static const String table = 'user_favorites';

  final SupabaseClient _client;

  @override
  Future<Set<String>> fetchIds() async {
    final List<Map<String, dynamic>> rows = await _client
        .from(table)
        .select('track_id');

    return rows
        .map((Map<String, dynamic> row) => row['track_id'] as String)
        .toSet();
  }

  /// Marks [trackIds] on the account. A mark already there is not an error:
  /// another device got there first.
  @override
  Future<void> add(String userId, Iterable<String> trackIds) async {
    if (trackIds.isEmpty) return;
    await _client
        .from(table)
        .upsert(
          <Map<String, dynamic>>[
            for (final String id in trackIds)
              <String, dynamic>{'user_id': userId, 'track_id': id},
          ],
          onConflict: 'user_id,track_id',
          ignoreDuplicates: true,
        );
  }

  @override
  Future<void> remove(Iterable<String> trackIds) async {
    if (trackIds.isEmpty) return;
    await _client.from(table).delete().inFilter('track_id', trackIds.toList());
  }
}
