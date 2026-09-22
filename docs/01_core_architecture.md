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
- Source of truth = Supabase. Drift is the local mirror it is served from (docs/04).
```

> **Deviation from the wine-app lineage:** this is a *streaming* app with no
> user-owned data and no login, so Supabase stays the source of truth and
> nothing is ever written back to it. What the Drift layer added in 0.2.0 is
> a read-through cache, not a second master: a fetch fills it, and it is what
> the repository reads from afterwards.

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

## The cache

`ContentRepositoryImpl` runs the local-first flow from `docs/04`: fetch from
Supabase, write the rows to Drift, read the answer back out of Drift. A failed
fetch is swallowed when the cache has something to serve and raised when it
does not, so a train tunnel looks like a train tunnel and a broken install
looks broken.
