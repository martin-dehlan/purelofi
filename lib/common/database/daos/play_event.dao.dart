import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/play_event.table.dart';

part 'play_event.dao.g.dart';

/// The listening log (#142). Rows are added as plays count, updated while
/// they go on, and only ever removed by pruning or the listener's "Clear".
@DriftAccessor(tables: <Type>[PlayEventTable])
class PlayEventDao extends DatabaseAccessor<AppDatabase>
    with _$PlayEventDaoMixin {
  PlayEventDao(super.db);

  /// Returns the new row's id.
  Future<int> add(PlayEventTableCompanion event) =>
      into(playEventTable).insert(event);

  Future<void> setListened(int id, int seconds) =>
      (update(playEventTable)
            ..where(($PlayEventTableTable t) => t.id.equals(id)))
          .write(PlayEventTableCompanion(listenedSeconds: Value<int>(seconds)));

  /// Newest first.
  Stream<List<PlayEventTableData>> watchNewest(int limit) =>
      (select(playEventTable)
            ..orderBy(<OrderClauseGenerator<$PlayEventTableTable>>[
              ($PlayEventTableTable t) => OrderingTerm.desc(t.startedAt),
              ($PlayEventTableTable t) => OrderingTerm.desc(t.id),
            ])
            ..limit(limit))
          .watch();

  /// Every play that started in [from, to).
  Future<List<PlayEventTableData>> between(DateTime from, DateTime to) =>
      (select(playEventTable)
            ..where(
              ($PlayEventTableTable t) =>
                  t.startedAt.isBiggerOrEqualValue(from) &
                  t.startedAt.isSmallerThanValue(to),
            )
            ..orderBy(<OrderClauseGenerator<$PlayEventTableTable>>[
              ($PlayEventTableTable t) => OrderingTerm.asc(t.startedAt),
            ]))
          .get();

  /// Drops what started before [before], and anything past the newest
  /// [keep] rows.
  Future<void> prune({required DateTime before, required int keep}) async {
    await (delete(playEventTable)..where(
          ($PlayEventTableTable t) => t.startedAt.isSmallerThanValue(before),
        ))
        .go();
    await customStatement(
      'DELETE FROM play_events WHERE id NOT IN '
      '(SELECT id FROM play_events ORDER BY started_at DESC, id DESC LIMIT ?)',
      <Object>[keep],
    );
  }

  Future<void> clear() => delete(playEventTable).go();
}
