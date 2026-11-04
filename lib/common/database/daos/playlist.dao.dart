import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/playlist.table.dart';

part 'playlist.dao.g.dart';

/// The listener's playlists (#141).
@DriftAccessor(tables: <Type>[PlaylistTable])
class PlaylistDao extends DatabaseAccessor<AppDatabase>
    with _$PlaylistDaoMixin {
  PlaylistDao(super.db);

  /// Every playlist not deleted, most recently changed first.
  Stream<List<PlaylistTableData>> watchLive() =>
      (select(playlistTable)
            ..where(($PlaylistTableTable p) => p.deletedAt.isNull())
            ..orderBy(<OrderClauseGenerator<$PlaylistTableTable>>[
              ($PlaylistTableTable p) => OrderingTerm.desc(p.updatedAt),
            ]))
          .watch();

  Future<List<PlaylistTableData>> getAll() => select(playlistTable).get();

  Future<PlaylistTableData?> find(String id) => (select(
    playlistTable,
  )..where(($PlaylistTableTable p) => p.id.equals(id))).getSingleOrNull();

  Future<void> put(PlaylistTableCompanion playlist) =>
      into(playlistTable).insertOnConflictUpdate(playlist);

  Future<void> markSynced(Iterable<String> ids) =>
      (update(playlistTable)
            ..where(($PlaylistTableTable p) => p.id.isIn(ids.toList())))
          .write(const PlaylistTableCompanion(isSynced: Value<bool>(true)));
}
