import 'package:drift/drift.dart';

/// One file that has been downloaded to this device, keyed by the URL it
/// came from.
///
/// A registry rather than a column on tracks and layers: eviction needs a
/// size and a last-used stamp per file, both of which belong to the file and
/// not to whatever happens to point at it. Keyed by URL, it also works for
/// anything else the app ever caches — a behind-the-scenes clip, a sprite
/// strip shared by two scenes.
@DataClassName('CachedFileTableData')
class CachedFileTable extends Table {
  @override
  String get tableName => 'cached_files';

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{url};

  TextColumn get url => text()();

  /// Relative to the cache directory, never absolute: the sandbox path
  /// changes between installs and an absolute one would go stale.
  TextColumn get fileName => text()();

  IntColumn get sizeBytes => integer()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// What eviction sorts by: the least recently played track goes first.
  DateTimeColumn get lastUsedAt => dateTime()();

  /// Always true — nothing here is a local change the server has not seen.
  /// Kept for the shape every table in `docs/04` has.
  BoolColumn get isSynced => boolean().withDefault(const Constant(true))();
}
