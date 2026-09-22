import 'package:drift/drift.dart';

/// One sprite layer of a cached scene. Mirrors `scene_layers` on the server,
/// column for column, plus [localSpritePath] for the cached strip.
@DataClassName('SceneLayerTableData')
class SceneLayerTable extends Table {
  @override
  String get tableName => 'scene_layers';

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  TextColumn get id => text()();
  TextColumn get sceneId => text()();
  IntColumn get zIndex => integer()();
  TextColumn get spriteUrl => text()();

  /// Where the strip lives on this device, once it has been downloaded.
  TextColumn get localSpritePath => text().nullable()();

  IntColumn get frameCount => integer().withDefault(const Constant(1))();
  RealColumn get fps => real().withDefault(const Constant(0))();
  IntColumn get offsetX => integer().withDefault(const Constant(0))();
  IntColumn get offsetY => integer().withDefault(const Constant(0))();
  RealColumn get parallax => real().withDefault(const Constant(1))();
  BoolColumn get tiles => boolean().withDefault(const Constant(false))();
  BoolColumn get onlyWhilePlaying =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get hideWhenPaused =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get tappable => boolean().withDefault(const Constant(false))();
  IntColumn get idleFrameCount => integer().withDefault(const Constant(0))();
  BoolColumn get onTrackChange =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get hideWhenClipped =>
      boolean().withDefault(const Constant(false))();
  IntColumn get eventIntervalMinSeconds => integer().nullable()();
  IntColumn get eventIntervalMaxSeconds => integer().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(true))();
}
