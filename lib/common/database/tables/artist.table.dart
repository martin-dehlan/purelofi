import 'package:drift/drift.dart';

/// An artist as last seen on the server.
@DataClassName('ArtistTableData')
class ArtistTable extends Table {
  @override
  String get tableName => 'artists';

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get bio => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();

  /// The artist's channels, one URL per line.
  TextColumn get links => text().withDefault(const Constant(''))();

  DateTimeColumn get updatedAt => dateTime()();
}
