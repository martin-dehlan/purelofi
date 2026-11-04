import 'package:drift/drift.dart';

/// A mood as it was last seen on the server (#141), so moods work offline.
@DataClassName('MoodTableData')
class MoodTable extends Table {
  @override
  String get tableName => 'moods';

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  TextColumn get id => text()();
  TextColumn get slug => text()();
  TextColumn get title => text()();
  TextColumn get coverUrl => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// The track ids in order, as JSON: read whole with the mood, always.
  TextColumn get trackIds => text().withDefault(const Constant('[]'))();
}
