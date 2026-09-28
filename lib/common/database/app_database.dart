import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/cached_file.dao.dart';
import 'daos/local_track.dao.dart';
import 'daos/scene.dao.dart';
import 'daos/track.dao.dart';
import 'tables/cached_file.table.dart';
import 'tables/local_track.table.dart';
import 'tables/scene.table.dart';
import 'tables/scene_layer.table.dart';
import 'tables/track.table.dart';

part 'app_database.g.dart';

/// The local mirror of the content Supabase serves, and the listener's own
/// library.
///
/// Supabase stays the source of truth for the content; this is what the app
/// falls back to when there is no network, and what it reads from once a
/// fetch has finished (see `docs/04`). `local_tracks` is the exception: it
/// exists only on this device and is never synced (#66).
@DriftDatabase(
  tables: <Type>[
    TrackTable,
    SceneTable,
    SceneLayerTable,
    CachedFileTable,
    LocalTrackTable,
  ],
  daos: <Type>[TrackDao, SceneDao, CachedFileDao, LocalTrackDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// An in-memory database, for tests.
  AppDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) => m.createAll(),
    onUpgrade: (Migrator m, int from, int to) async {
      // 2: the file registry. The content tables are untouched — they hold
      // nothing that is not on the server, so they refill themselves on the
      // next fetch. Favorites (#15) will be the first rows that cannot be
      // thrown away, and will need a real migration rather than this.
      if (from < 2) await m.createTable(cachedFileTable);

      // 3: the listener's own library. A whole table whose rows no fetch can
      // bring back, so it is created here and never dropped and recreated.
      if (from < 3) await m.createTable(localTrackTable);
    },
  );

  static QueryExecutor _openConnection() => driftDatabase(name: 'purelofi_db');
}
