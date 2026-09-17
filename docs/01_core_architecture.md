# 01 - Core Architecture

## TL;DR

```
Layer Flow: Domain (pure) → Data (Supabase) → Controller (Riverpod) → Presentation (UI)

Golden Rules:
- Domain = Pure Dart (no Flutter, no Riverpod, no external deps)
- Data = Supabase API (read-only for MVP: streaming content)
- Controller = ALL providers centralized in ONE file per feature
- UI = Dumb (no business logic)
- File naming: name.type.dart (e.g., track.model.dart)
- Source of truth = Supabase (MVP). Drift local-first is Phase 2 only (see docs/04).
```

> **MVP deviation from the wine-app lineage:** this is a *streaming* app with
> no user-owned data and no login. Supabase is the source of truth and is read
> directly. The local-first Drift flow in `docs/04` is **Phase 2** (offline
> playback + favorites) and must not be introduced in the MVP.

## Checklist

- [ ] Domain layer has no `import 'package:flutter'` or `flutter_riverpod`
- [ ] No `AsyncValue` in domain entities
- [ ] All providers in `controller/feature.provider.dart`
- [ ] Repository interface in `domain/`, implementation in `data/`
- [ ] UI only calls controllers, never repositories or the Supabase client

---

## Layer Responsibilities

```
features/<feature>/
├── domain/                    ← Pure Business Logic (Dart only)
│   ├── entities/              ← Business objects (Freezed)
│   └── repositories/          ← Interface definitions (abstract)
├── data/                      ← External Data Handling
│   ├── models/                ← JSON serialization (Freezed + json_serializable)
│   ├── data_sources/          ← Supabase client wrappers (*.api.dart)
│   └── repositories/          ← Repository implementations
├── controller/                ← State Management (Riverpod)
└── presentation/              ← UI Layer
    ├── screens/               ← Screens + routes
    └── widgets/               ← Reusable UI components
```

> The `application/` layer and `domain/CRUD/` use-cases from the wine app are
> **skipped for MVP** — there is no cross-feature workflow and no user CRUD.
> Repository → controller is enough. Add use-cases only when a real workflow
> appears (e.g. Phase 2 favorites sync).

## Data Flow (server-first, read-only)

```
App opens PlayerScreen
         ↓
PlayerScreen watches ref.watch(sceneListProvider) / ref.watch(trackListProvider)
         ↓
ContentController.build() calls ContentRepository.getScenes() / getTracks()
         ↓
ContentRepositoryImpl:
  1. Fetch active rows from Supabase (scenes / tracks tables)
  2. Map models → entities
  3. Return entities
         ↓
Controller exposes AsyncValue<List<SceneEntity>> / <List<TrackEntity>>
         ↓
UI renders the active scene video + streams the selected track
```

No writes in MVP. The only "state" that mutates is playback (which track/scene
is active, play/pause) — that lives in the player controller, not the backend.

## Dependency Rules

```
Allowed:
Domain      → (nothing)
Data        → Domain
Controller  → Domain, Data
Presentation → Domain, Controller

Forbidden:
Domain → Data, Controller, Presentation, Riverpod
UI     → Supabase client directly, or Repository directly
```

## Phase 2 note

When offline playback lands, `ContentRepositoryImpl` gains the local-first flow
from `docs/04` (fetch from Supabase → cache in Drift → serve from Drift). Until
then, keep the repository a thin Supabase reader.
