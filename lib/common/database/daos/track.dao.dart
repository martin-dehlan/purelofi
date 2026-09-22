import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/track.table.dart';

part 'track.dao.g.dart';

@DriftAccessor(tables: <Type>[TrackTable])
class TrackDao extends DatabaseAccessor<AppDatabase> with _$TrackDaoMixin {
  TrackDao(super.db);

  /// Oldest first, matching the order the server sends.
  Future<List<TrackTableData>> getTracks() =>
      (select(trackTable)..orderBy(<OrderClauseGenerator<$TrackTableTable>>[
            ($TrackTableTable t) => OrderingTerm.asc(t.createdAt),
          ]))
          .get();

  Stream<List<TrackTableData>> watchTracks() =>
      (select(trackTable)..orderBy(<OrderClauseGenerator<$TrackTableTable>>[
            ($TrackTableTable t) => OrderingTerm.asc(t.createdAt),
          ]))
          .watch();

  Future<TrackTableData?> getTrackById(String id) => (select(
    trackTable,
  )..where(($TrackTableTable t) => t.id.equals(id))).getSingleOrNull();

  Future<List<TrackTableData>> getFavorites() => (select(
    trackTable,
  )..where(($TrackTableTable t) => t.isFavorite.equals(true))).get();

  Stream<List<TrackTableData>> watchFavorites() => (select(
    trackTable,
  )..where(($TrackTableTable t) => t.isFavorite.equals(true))).watch();

  /// Writes what the server just sent, and forgets tracks it no longer lists.
  ///
  /// Deleting is the point: a track pulled from the catalogue must stop
  /// playing, and a cache that only ever grows would keep it forever.
  Future<void> replaceTracks(List<TrackTableCompanion> tracks) async {
    await transaction(() async {
      final Set<String> keep = tracks
          .map((TrackTableCompanion t) => t.id.value)
          .toSet();

      await (delete(
        trackTable,
      )..where(($TrackTableTable t) => t.id.isNotIn(keep))).go();
      await batch((Batch b) => b.insertAllOnConflictUpdate(trackTable, tracks));
    });
  }

  Future<void> setFavorite(String id, {required bool isFavorite}) =>
      (update(
        trackTable,
      )..where(($TrackTableTable t) => t.id.equals(id))).write(
        TrackTableCompanion(
          isFavorite: Value<bool>(isFavorite),
          isSynced: const Value<bool>(false),
          updatedAt: Value<DateTime>(DateTime.now()),
        ),
      );
}
