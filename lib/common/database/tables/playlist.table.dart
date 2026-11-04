import 'package:drift/drift.dart';

/// A playlist the listener made (#141). The device's copy is the one played
/// from; a signed-in listener's is synced with the account.
@DataClassName('PlaylistTableData')
class PlaylistTable extends Table {
  @override
  String get tableName => 'playlists';

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  TextColumn get id => text()();
  TextColumn get name => text()();

  /// `[{"track_id": ..., "source": ...}]` in order. Read and written whole.
  TextColumn get items => text().withDefault(const Constant('[]'))();

  DateTimeColumn get updatedAt => dateTime()();

  /// Kept with the date it was deleted, so the deletion can be synced.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// Whether the account has this version.
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
}
