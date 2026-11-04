import 'package:drift/drift.dart';

/// A room or track the listener has already met (#148), so it is no longer
/// marked new. On this device only.
@DataClassName('SeenItemTableData')
class SeenItemTable extends Table {
  @override
  String get tableName => 'seen_items';

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{kind, id};

  /// `scene` or `track`.
  TextColumn get kind => text()();
  TextColumn get id => text()();
  DateTimeColumn get seenAt => dateTime()();
}
