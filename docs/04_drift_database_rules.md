# Drift Database Rules (Local-First)

> **Active since 0.2.0.** The MVP streamed everything from Supabase with no
> local store. Offline caching turned this file on: Supabase is still the
> source of truth, and Drift is the mirror the app falls back to and reads
> from.
>
> The flow is now: **Supabase → cache in Drift → serve from Drift**, with the
> network failure swallowed whenever there is something cached to show, and
> raised when there is not.
>
> Favorites (`#15`) are the first data that will be written locally *first*,
> which is what `isSynced` exists for. Nothing writes it yet.

---

## Architecture: Local-First Flow

```
UI
 ↓ triggers action
Repository
 ↓ 1. fetch from Supabase
 ↓ 2. save to Drift
 ↓ 3. return/watch from Drift
UI ← stream/future from Drift
```

On network failure → fall back to local Drift data.
Never expose raw Supabase responses to the controller or UI layer.

---

## Folder Structure

```
lib/
  common/
    database/
      tables/
        track.table.dart
        scene.table.dart
        favorite.table.dart
      daos/
        track.dao.dart
        scene.dao.dart
      app_database.dart              ← single AppDatabase class
```

---

## Table Definition Pattern

File: `lib/common/database/tables/track.table.dart`

```dart
import 'package:drift/drift.dart';

@DataClassName('TrackTableData')
class TrackTable extends Table {
  @override
  String get tableName => 'tracks';

  TextColumn get id            => text()();
  TextColumn get title         => text()();
  TextColumn get audioUrl      => text()();
  TextColumn get btsVideoUrl   => text().nullable()();
  IntColumn  get durationSeconds => integer().nullable()();
  TextColumn get localAudioPath => text().nullable()();   // cached file for offline
  BoolColumn get isFavorite    => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced      => boolean().withDefault(const Constant(false))();
}
```

Rules:
- Class name: `EntityTable` (e.g. `TrackTable`, `SceneTable`)
- Always add `@DataClassName('EntityTableData')`
- Add `isSynced` for optimistic local writes (favorites)
- Use `text()` for IDs — UUIDs from Supabase
- Add `createdAt` / `updatedAt` on every table

---

## AppDatabase

File: `lib/common/database/app_database.dart`

```dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'tables/track.table.dart';
import 'tables/scene.table.dart';
import 'daos/track.dao.dart';
import 'daos/scene.dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [TrackTable, SceneTable],
  daos: [TrackDao, SceneDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'purelofi_db');
  }
}
```

---

## DAO Pattern

File: `lib/common/database/daos/track.dao.dart`

```dart
import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/track.table.dart';

part 'track.dao.g.dart';

@DriftAccessor(tables: [TrackTable])
class TrackDao extends DatabaseAccessor<AppDatabase> with _$TrackDaoMixin {
  TrackDao(super.db);

  Stream<List<TrackTableData>> watchTracks() {
    return (select(trackTable)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  Stream<List<TrackTableData>> watchFavorites() {
    return (select(trackTable)..where((t) => t.isFavorite.equals(true))).watch();
  }

  Future<void> upsertTracks(List<TrackTableCompanion> tracks) async {
    await batch((b) => b.insertAllOnConflictUpdate(trackTable, tracks));
  }

  Future<void> setFavorite(String id, bool value) {
    return (update(trackTable)..where((t) => t.id.equals(id)))
        .write(TrackTableCompanion(isFavorite: Value(value)));
  }
}
```

---

## Repository Pattern

Local-first: trigger background sync, serve local stream immediately, optimistic
writes for favorites. (Same shape as the wine-app lineage — see git history of
this file for the full example.)

---

## Build Commands

```bash
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch --delete-conflicting-outputs
```

---

## Rules Checklist

- [ ] UI never reads from Supabase directly
- [ ] Every table has `isSynced`, `createdAt`, `updatedAt`
- [ ] DAOs have both `watch*` (Stream) and `get*` (Future) variants
- [ ] Repositories do optimistic local write before Supabase call
- [ ] Network failures are caught silently; local data serves as fallback
- [ ] Migrations increment `schemaVersion` and use `MigrationStrategy`
