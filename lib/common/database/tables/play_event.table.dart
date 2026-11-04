import 'package:drift/drift.dart';

/// One time a track was listened to (#142), kept on this device only.
///
/// A log rather than a list: "recently played" reads the newest of it, and
/// the listening stats (#151) count over all of it. Only plays that count
/// are written — a track skipped after three seconds was not listened to.
@DataClassName('PlayEventTableData')
class PlayEventTable extends Table {
  @override
  String get tableName => 'play_events';

  IntColumn get id => integer().autoIncrement()();

  /// A catalogue id or a local track id; which one is [source].
  TextColumn get trackId => text()();

  /// `catalogue` or `local`, the name of `TrackSource`.
  TextColumn get source => text()();

  /// The room it was heard in, for the stats. Null before a room loaded.
  TextColumn get sceneId => text().nullable()();

  DateTimeColumn get startedAt => dateTime()();

  /// How much of it was actually heard, seeks and pauses left out.
  IntColumn get listenedSeconds => integer()();
}
