import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/artist.table.dart';

part 'artist.dao.g.dart';

@DriftAccessor(tables: <Type>[ArtistTable])
class ArtistDao extends DatabaseAccessor<AppDatabase> with _$ArtistDaoMixin {
  ArtistDao(super.db);

  /// By name, the order the list shows them in.
  Future<List<ArtistTableData>> getArtists() =>
      (select(artistTable)..orderBy(<OrderClauseGenerator<$ArtistTableTable>>[
            ($ArtistTableTable t) => OrderingTerm.asc(t.name.lower()),
          ]))
          .get();

  /// Writes what the server just sent, and forgets artists it no longer
  /// lists, as with the tracks.
  Future<void> replaceArtists(List<ArtistTableCompanion> artists) async {
    await transaction(() async {
      final Set<String> keep = artists
          .map((ArtistTableCompanion a) => a.id.value)
          .toSet();

      await (delete(
        artistTable,
      )..where(($ArtistTableTable t) => t.id.isNotIn(keep))).go();
      await batch(
        (Batch b) => b.insertAllOnConflictUpdate(artistTable, artists),
      );
    });
  }
}
