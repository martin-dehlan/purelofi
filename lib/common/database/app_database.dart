import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/scene.dao.dart';
import 'daos/track.dao.dart';
import 'tables/scene.table.dart';
import 'tables/scene_layer.table.dart';
import 'tables/track.table.dart';

part 'app_database.g.dart';

/// The local mirror of the content Supabase serves.
///
/// Supabase stays the source of truth; this is what the app falls back to
/// when there is no network, and what it reads from once a fetch has
/// finished (see `docs/04`).
@DriftDatabase(
  tables: <Type>[TrackTable, SceneTable, SceneLayerTable],
  daos: <Type>[TrackDao, SceneDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// An in-memory database, for tests.
  AppDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() => driftDatabase(name: 'purelofi_db');
}
