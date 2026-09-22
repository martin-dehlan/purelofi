import 'package:drift/drift.dart';

/// A track as it was last seen on the server.
///
/// [localAudioPath] is filled once the file itself has been cached; until
/// then playback streams from [audioUrl]. [isFavorite] has no UI yet — it is
/// what the favorites feature will write to, and the reason this table
/// carries [isSynced] at all.
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

  /// Where the audio lives on this device, once it has been downloaded.
  TextColumn get localAudioPath => text().nullable()();

  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// False when this row holds a local change the server has not seen.
  /// Content mirrored from Supabase is synced by definition; favorites are
  /// what will set this to false.
  BoolColumn get isSynced => boolean().withDefault(const Constant(true))();
}
