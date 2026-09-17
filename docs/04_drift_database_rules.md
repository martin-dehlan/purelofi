# Drift Database Rules (Local-First) — ⚠️ PHASE 2 ONLY

> **NOT PART OF THE MVP.** PureLofi's MVP streams content from Supabase with
> Supabase as the source of truth (see `docs/01` and `SPEC.md`). Do **not** add
> `drift` / `drift_flutter` to `pubspec.yaml` for the MVP, and do not introduce
> DAOs, tables, or an `AppDatabase`.
>
> This file is kept as the **blueprint for Phase 2**, when we add:
> - **Offline playback** (cache streamed tracks/scenes locally for travel), and
> - **Favorites** (the first genuinely user-owned data).
>
> When that work starts, this local-first pattern becomes active and `docs/01`'s
> data flow switches to: Supabase → cache in Drift → serve from Drift.

---

## Architecture: Local-First Flow (Phase 2)

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

## Folder Structure (Phase 2)

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

## Table Definition Pattern (Phase 2)

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

## AppDatabase (Phase 2)

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

## DAO Pattern (Phase 2)

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

## Repository Pattern (Phase 2)

Local-first: trigger background sync, serve local stream immediately, optimistic
writes for favorites. (Same shape as the wine-app lineage — see git history of
this file for the full example.)

---

## Build Commands (Phase 2)

```bash
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch --delete-conflicting-outputs
```

---

## Rules Checklist (Phase 2)

- [ ] UI never reads from Supabase directly
- [ ] Every table has `isSynced`, `createdAt`, `updatedAt`
- [ ] DAOs have both `watch*` (Stream) and `get*` (Future) variants
- [ ] Repositories do optimistic local write before Supabase call
- [ ] Network failures are caught silently; local data serves as fallback
- [ ] Migrations increment `schemaVersion` and use `MigrationStrategy`
