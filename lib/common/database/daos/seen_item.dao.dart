import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/seen_item.table.dart';

part 'seen_item.dao.g.dart';

/// What the listener has already met (#148).
@DriftAccessor(tables: <Type>[SeenItemTable])
class SeenItemDao extends DatabaseAccessor<AppDatabase>
    with _$SeenItemDaoMixin {
  SeenItemDao(super.db);

  /// The ids of [kind] seen so far.
  Stream<Set<String>> watchIds(String kind) =>
      (select(
        seenItemTable,
      )..where(($SeenItemTableTable t) => t.kind.equals(kind))).watch().map(
        (List<SeenItemTableData> rows) => <String>{
          for (final SeenItemTableData row in rows) row.id,
        },
      );

  /// Marks [id] seen; seeing it again changes nothing.
  Future<void> markSeen(String kind, String id, DateTime at) =>
      into(seenItemTable).insert(
        SeenItemTableCompanion.insert(kind: kind, id: id, seenAt: at),
        mode: InsertMode.insertOrIgnore,
      );
}
