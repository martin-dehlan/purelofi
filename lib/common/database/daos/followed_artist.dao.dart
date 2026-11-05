import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/followed_artist.table.dart';

part 'followed_artist.dao.g.dart';

/// The artists the listener follows (#147).
@DriftAccessor(tables: <Type>[FollowedArtistTable])
class FollowedArtistDao extends DatabaseAccessor<AppDatabase>
    with _$FollowedArtistDaoMixin {
  FollowedArtistDao(super.db);

  Stream<Set<String>> watchFollowed() =>
      (select(followedArtistTable)
            ..where(($FollowedArtistTableTable t) => t.isFollowed.equals(true)))
          .watch()
          .map(
            (List<FollowedArtistTableData> rows) => <String>{
              for (final FollowedArtistTableData r in rows) r.artistId,
            },
          );

  Future<void> set(String artistId, {required bool followed}) =>
      into(followedArtistTable).insertOnConflictUpdate(
        FollowedArtistTableCompanion.insert(
          artistId: artistId,
          isFollowed: followed,
          isSynced: const Value<bool>(false),
        ),
      );

  Future<List<FollowedArtistTableData>> unsynced() => (select(
    followedArtistTable,
  )..where(($FollowedArtistTableTable t) => t.isSynced.equals(false))).get();

  Future<void> markSynced(Iterable<String> ids) =>
      (update(
        followedArtistTable,
      )..where(($FollowedArtistTableTable t) => t.artistId.isIn(ids))).write(
        const FollowedArtistTableCompanion(isSynced: Value<bool>(true)),
      );

  /// Makes the synced marks match the account; one still waiting to be
  /// pushed is newer than the account's copy and stays.
  Future<void> apply(Set<String> accountIds) => transaction(() async {
    final List<FollowedArtistTableData> rows = await select(followedArtistTable)
        .get();
    final Set<String> pending = <String>{
      for (final FollowedArtistTableData r in rows)
        if (!r.isSynced) r.artistId,
    };
    for (final FollowedArtistTableData r in rows) {
      if (!r.isSynced) continue;
      final bool followed = accountIds.contains(r.artistId);
      if (followed != r.isFollowed) {
        await (update(followedArtistTable)..where(
              ($FollowedArtistTableTable t) => t.artistId.equals(r.artistId),
            ))
            .write(
              FollowedArtistTableCompanion(isFollowed: Value<bool>(followed)),
            );
      }
    }
    final Set<String> known = <String>{
      for (final FollowedArtistTableData r in rows) r.artistId,
    };
    for (final String id in accountIds) {
      if (known.contains(id) || pending.contains(id)) continue;
      await into(followedArtistTable).insert(
        FollowedArtistTableCompanion.insert(
          artistId: id,
          isFollowed: true,
          isSynced: const Value<bool>(true),
        ),
      );
    }
  });

  /// After sign-out every follow is the device's own again.
  Future<void> release() =>
      (update(followedArtistTable)
            ..where(($FollowedArtistTableTable t) => t.isFollowed.equals(true)))
          .write(
            const FollowedArtistTableCompanion(isSynced: Value<bool>(false)),
          );
}
