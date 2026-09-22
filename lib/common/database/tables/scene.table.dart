import 'package:drift/drift.dart';

/// A scene as it was last seen on the server. Its layers live in
/// `scene_layers` and are replaced wholesale whenever the scene is cached,
/// the same way the upload tool replaces them server-side.
@DataClassName('SceneTableData')
class SceneTable extends Table {
  @override
  String get tableName => 'scenes';

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get videoUrl => text()();
  TextColumn get thumbnailUrl => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get canvasWidth => integer().withDefault(const Constant(320))();
  IntColumn get canvasHeight => integer().withDefault(const Constant(696))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(true))();
}
