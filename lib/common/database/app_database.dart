import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/artist.dao.dart';
import 'daos/cached_file.dao.dart';
import 'daos/local_track.dao.dart';
import 'daos/mood.dao.dart';
import 'daos/play_event.dao.dart';
import 'daos/playlist.dao.dart';
import 'daos/scene.dao.dart';
import 'daos/seen_item.dao.dart';
import 'daos/track.dao.dart';
import 'tables/artist.table.dart';
import 'tables/cached_file.table.dart';
import 'tables/local_track.table.dart';
import 'tables/mood.table.dart';
import 'tables/play_event.table.dart';
import 'tables/playlist.table.dart';
import 'tables/scene.table.dart';
import 'tables/scene_layer.table.dart';
import 'tables/seen_item.table.dart';
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
    ArtistTable,
    PlayEventTable,
    SeenItemTable,
    MoodTable,
    PlaylistTable,
  ],
  daos: <Type>[
    TrackDao,
    SceneDao,
    CachedFileDao,
    LocalTrackDao,
    ArtistDao,
    PlayEventDao,
    SeenItemDao,
    MoodDao,
    PlaylistDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// An in-memory database, for tests.
  AppDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 12;

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

      // 4: who made each track, a page for each of them and the track's
      // artwork. Both refill on
      // the next fetch, like the rest of the content.
      if (from < 4) {
        await m.createTable(artistTable);
        await m.addColumn(trackTable, trackTable.artistId);
        await m.addColumn(trackTable, trackTable.coverUrl);
      }

      // 5: downloads, files kept on purpose. A column on the registry, so the
      // files already on disk stay where they are.
      if (from < 5) {
        await m.addColumn(cachedFileTable, cachedFileTable.isPinned);
      }

      // 6: every link an artist has, not one (#109). The table is only a
      // copy of the server's, so it is rebuilt rather than altered — but
      // only when it was there to begin with: from < 4 just made it new.
      if (from >= 4 && from < 6) {
        await m.deleteTable(artistTable.actualTableName);
        await m.createTable(artistTable);
      }

      // 7: the listening log (#142). Rows no fetch can bring back, so the
      // table is created and never rebuilt.
      if (from < 7) await m.createTable(playEventTable);

      // 8: what the listener has already met, for the "new" marks (#148).
      if (from < 8) await m.createTable(seenItemTable);

      // 9: what a screen reader says for a tappable layer (#153). Only a
      // copy of the server's, but a column is cheap to add in place.
      // Checked first: a database whose layers table was made from the
      // current definition already has the column.
      if (from < 9 && !await _hasColumn('scene_layers', 'tap_label')) {
        await m.addColumn(sceneLayerTable, sceneLayerTable.tapLabel);
      }

      // 10: the sounds each room brings (#136), as a JSON column.
      if (from < 10 && !await _hasColumn('scenes', 'ambients')) {
        await m.addColumn(sceneTable, sceneTable.ambients);
      }

      // 11: moods and the listener's playlists (#141).
      if (from < 11) {
        await m.createTable(moodTable);
        await m.createTable(playlistTable);
      }

      // 12: the mood each room plays (#143).
      if (from < 12 && !await _hasColumn('scenes', 'mood_id')) {
        await m.addColumn(sceneTable, sceneTable.moodId);
      }
    },
  );

  Future<bool> _hasColumn(String table, String column) async {
    final List<QueryRow> rows = await customSelect(
      'PRAGMA table_info($table)',
    ).get();

    return rows.any((QueryRow row) => row.read<String>('name') == column);
  }

  static QueryExecutor _openConnection() => driftDatabase(name: 'purelofi_db');
}
