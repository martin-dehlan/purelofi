import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../common/database/app_database.dart';
import '../../../common/database/daos/followed_artist.dao.dart';
import '../domain/favorites_sync.dart';

/// The artists the listener follows, on the device (#147): what the app
/// shows, and the device's side of the same sync the favorites use.
class DeviceFollows implements DeviceFavorites {
  const DeviceFollows(this._dao);

  final FollowedArtistDao _dao;

  Stream<Set<String>> watchFollowed() => _dao.watchFollowed();

  Future<void> set(String artistId, {required bool followed}) =>
      _dao.set(artistId, followed: followed);

  @override
  Future<Map<String, bool>> pending() async => <String, bool>{
    for (final FollowedArtistTableData r in await _dao.unsynced())
      r.artistId: r.isFollowed,
  };

  @override
  Future<void> markSynced(Iterable<String> ids) => _dao.markSynced(ids);

  @override
  Future<void> apply(Set<String> accountIds) => _dao.apply(accountIds);

  @override
  Future<void> release() => _dao.release();
}

/// The account's follows in Supabase (#147). Row-level security scopes
/// every call to the signed-in listener.
class FollowsApi implements AccountFavorites {
  const FollowsApi(this._client);

  static const String table = 'user_follows';

  final SupabaseClient _client;

  @override
  Future<Set<String>> fetchIds() async {
    final List<Map<String, dynamic>> rows = await _client
        .from(table)
        .select('artist_id');
    return <String>{
      for (final Map<String, dynamic> row in rows) row['artist_id'] as String,
    };
  }

  @override
  Future<void> add(String userId, Iterable<String> artistIds) async {
    if (artistIds.isEmpty) return;
    await _client
        .from(table)
        .upsert(
          <Map<String, dynamic>>[
            for (final String id in artistIds)
              <String, dynamic>{'user_id': userId, 'artist_id': id},
          ],
          onConflict: 'user_id,artist_id',
          ignoreDuplicates: true,
        );
  }

  @override
  Future<void> remove(Iterable<String> artistIds) async {
    if (artistIds.isEmpty) return;
    await _client
        .from(table)
        .delete()
        .inFilter('artist_id', artistIds.toList());
  }
}
