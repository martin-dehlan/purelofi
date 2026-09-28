import 'package:drift/drift.dart';

/// A track the listener brought themselves: a file copied into the app from
/// their own device (#66).
///
/// Its own table rather than rows in `tracks`, and that is load-bearing:
/// `tracks` is a mirror of the server, and `TrackDao.replaceTracks` deletes
/// every row the server did not send. A listener's own music would be gone
/// after the next fetch.
///
/// Nor are the files in the media cache. That one evicts; these are the only
/// copy the app has, and only the listener may throw them away.
@DataClassName('LocalTrackTableData')
class LocalTrackTable extends Table {
  @override
  String get tableName => 'local_tracks';

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  /// Made on this device at import. Never a server id — there is no server
  /// row to point at.
  TextColumn get id => text()();

  /// From the file's tags, or its name without the extension.
  TextColumn get title => text()();
  TextColumn get artist => text().nullable()();

  /// Relative to the library directory, never absolute: the sandbox path
  /// changes between installs and app updates, and an absolute one would
  /// point at nothing afterwards.
  TextColumn get fileName => text()();

  /// The embedded cover, extracted once at import so a scrolling list does
  /// not reread every file's tags. Relative, like [fileName].
  TextColumn get coverFileName => text().nullable()();

  IntColumn get durationSeconds => integer().nullable()();

  /// What the copy costs on disk: the library duplicates what the listener
  /// already has, so the sheet should be able to say how much.
  IntColumn get sizeBytes => integer()();

  /// When it was imported — what "recently added" sorts by.
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Always true: this row never goes to the server, so there is nothing it
  /// could be out of step with. Kept for the shape every table in `docs/04`
  /// has.
  BoolColumn get isSynced => boolean().withDefault(const Constant(true))();
}
