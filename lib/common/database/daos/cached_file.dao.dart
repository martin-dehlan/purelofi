import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/cached_file.table.dart';

part 'cached_file.dao.g.dart';

@DriftAccessor(tables: <Type>[CachedFileTable])
class CachedFileDao extends DatabaseAccessor<AppDatabase>
    with _$CachedFileDaoMixin {
  CachedFileDao(super.db);

  Future<CachedFileTableData?> find(String url) => (select(
    cachedFileTable,
  )..where(($CachedFileTableTable f) => f.url.equals(url))).getSingleOrNull();

  Future<List<CachedFileTableData>> all() => select(cachedFileTable).get();

  /// What the files take up: the downloads ([pinned]) or the rest.
  Future<int> totalBytes({bool pinned = false}) async {
    final Expression<int> sum = cachedFileTable.sizeBytes.sum();
    final TypedResult row =
        await (selectOnly(cachedFileTable)
              ..addColumns(<Expression<Object>>[sum])
              ..where(cachedFileTable.isPinned.equals(pinned)))
            .getSingle();

    return row.read(sum) ?? 0;
  }

  Future<List<CachedFileTableData>> pinned() => (select(
    cachedFileTable,
  )..where(($CachedFileTableTable f) => f.isPinned.equals(true))).get();

  Future<void> setPinned(String url, {required bool pinned}) =>
      (update(cachedFileTable)
            ..where(($CachedFileTableTable f) => f.url.equals(url)))
          .write(CachedFileTableCompanion(isPinned: Value<bool>(pinned)));

  Future<void> remember({
    required String url,
    required String fileName,
    required int sizeBytes,
    required DateTime now,
  }) => into(cachedFileTable).insertOnConflictUpdate(
    CachedFileTableCompanion(
      url: Value<String>(url),
      fileName: Value<String>(fileName),
      sizeBytes: Value<int>(sizeBytes),
      createdAt: Value<DateTime>(now),
      updatedAt: Value<DateTime>(now),
      lastUsedAt: Value<DateTime>(now),
    ),
  );

  Future<void> touch(String url, DateTime now) =>
      (update(cachedFileTable)
            ..where(($CachedFileTableTable f) => f.url.equals(url)))
          .write(CachedFileTableCompanion(lastUsedAt: Value<DateTime>(now)));

  Future<void> forget(String url) => (delete(
    cachedFileTable,
  )..where(($CachedFileTableTable f) => f.url.equals(url))).go();

  /// Least recently used first — the order things are thrown away in.
  /// Downloads are never among them.
  Future<List<CachedFileTableData>> oldestFirst() =>
      (select(cachedFileTable)
            ..where(($CachedFileTableTable f) => f.isPinned.equals(false))
            ..orderBy(<OrderClauseGenerator<$CachedFileTableTable>>[
              ($CachedFileTableTable f) => OrderingTerm.asc(f.lastUsedAt),
            ]))
          .get();
}
