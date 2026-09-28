import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/local_track.table.dart';

part 'local_track.dao.g.dart';

/// The listener's own tracks. Nothing here is ever replaced wholesale: rows
/// come in one import at a time and leave only when the listener deletes
/// them.
@DriftAccessor(tables: <Type>[LocalTrackTable])
class LocalTrackDao extends DatabaseAccessor<AppDatabase>
    with _$LocalTrackDaoMixin {
  LocalTrackDao(super.db);

  /// Newest first. How the list is sorted for the listener is the
  /// controller's business; this is only a stable default.
  Stream<List<LocalTrackTableData>> watchAll() => _newestFirst().watch();

  Future<List<LocalTrackTableData>> getAll() => _newestFirst().get();

  Future<LocalTrackTableData?> find(String id) => (select(
    localTrackTable,
  )..where(($LocalTrackTableTable t) => t.id.equals(id))).getSingleOrNull();

  Future<void> add(LocalTrackTableCompanion track) =>
      into(localTrackTable).insert(track);

  /// Returns whether there was anything to remove.
  Future<bool> remove(String id) async {
    final int removed = await (delete(
      localTrackTable,
    )..where(($LocalTrackTableTable t) => t.id.equals(id))).go();

    return removed > 0;
  }

  /// What the whole library costs on disk.
  Future<int> totalBytes() async {
    final Expression<int> sum = localTrackTable.sizeBytes.sum();
    final TypedResult row = await (selectOnly(
      localTrackTable,
    )..addColumns(<Expression<Object>>[sum])).getSingle();

    return row.read(sum) ?? 0;
  }

  SimpleSelectStatement<$LocalTrackTableTable, LocalTrackTableData>
  _newestFirst() => select(localTrackTable)
    ..orderBy(<OrderClauseGenerator<$LocalTrackTableTable>>[
      ($LocalTrackTableTable t) => OrderingTerm.desc(t.createdAt),
    ]);
}
