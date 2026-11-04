import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/mood.table.dart';

part 'mood.dao.g.dart';

/// The moods' offline copy (#141).
@DriftAccessor(tables: <Type>[MoodTable])
class MoodDao extends DatabaseAccessor<AppDatabase> with _$MoodDaoMixin {
  MoodDao(super.db);

  Future<List<MoodTableData>> getAll() =>
      (select(moodTable)..orderBy(<OrderClauseGenerator<$MoodTableTable>>[
            ($MoodTableTable m) => OrderingTerm.asc(m.sortOrder),
          ]))
          .get();

  /// What the server just sent, and nothing it no longer lists.
  Future<void> replaceAll(List<MoodTableCompanion> moods) =>
      transaction(() async {
        await delete(moodTable).go();
        await batch((Batch b) => b.insertAll(moodTable, moods));
      });
}
