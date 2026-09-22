import 'package:drift/drift.dart';

/// A track as it was last seen on the server.
///
/// Whether its audio is on disk is not recorded here — `cached_files` owns
/// that, keyed by URL, because eviction needs a size and a last-used stamp
/// per file and those belong to the file, not to the track.
///
/// [isFavorite] has no UI yet: it is what the favorites feature will write
/// to, and the reason this table carries [isSynced] at all.
@DataClassName('TrackTableData')
class TrackTable extends Table {
  @override
  String get tableName => 'tracks';

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get audioUrl => text()();
  TextColumn get btsVideoUrl => text().nullable()();
  IntColumn get durationSeconds => integer().nullable()();

  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// False when this row holds a local change the server has not seen.
  /// Content mirrored from Supabase is synced by definition; favorites are
  /// what will set this to false.
  BoolColumn get isSynced => boolean().withDefault(const Constant(true))();
}
