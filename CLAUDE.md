# PureLofi — Claude Code Rules (Entry Point)

> **Read this first.** This is the root instruction file for the PureLofi app.
> The binding architecture rules live in `docs/01`–`docs/11`. The app scope and
> deviations live in `docs/SPEC.md`. **Where `SPEC.md` and a numbered rule
> disagree, `SPEC.md` wins for this app** (it records the intentional MVP
> deviations).

## What PureLofi is

A public, minimalist **pixel-art lo-fi music player** built with Flutter.
A fullscreen looping pixel-art video (the *scene*) sits behind a continuous
audio stream of **real** guitar/bass tracks (not AI-generated). Content lives
in Supabase; the same tracks feed a companion YouTube channel.

- **No login.** Public content consumption — nothing user-owned to protect.
- **Streaming, server-first.** Supabase is the source of truth. Audio/video
  stream from Supabase Storage.
- Domain: `purelofi.app` · Dart package name: `purelofi`

## MVP scope (v0.1.0) vs Phase 2

| In MVP | Deferred to Phase 2 |
|---|---|
| Fullscreen looping scene video | RevenueCat paywall |
| Continuous audio stream (`just_audio` + `audio_service`) | More scenes / user accounts |
| Random track selection, background/lock-screen controls | |
| Scene switcher | |
| BTS ("this is real, not AI") modal | |
| PostHog analytics (4 events) | |

Offline caching (Drift — `docs/04`) is built, content cache and file cache
both, and favourite tracks with it. They ship as **0.2.0** and **0.3.0** on
the next store uploads (`docs/11`).

**Still not a dependency:** `purchases_flutter`.

## The rules (docs/)

| Doc | Applies to MVP? |
|---|---|
| `01_core_architecture.md` | Yes — Supabase is the source of truth, Drift the mirror |
| `02_file_naming_conventions.md` | Yes, verbatim |
| `03_responsive_ui_rules.md` | Yes, verbatim |
| `04_drift_database_rules.md` | Yes — active since 0.2.0 |
| `05_riverpod_patterns.md` | Yes |
| `06_code_generation.md` | Yes (Freezed + Riverpod + Drift) |
| `07_error_handling.md` | Yes (network is the main error path; no auth) |
| `08_navigation_structure.md` | Yes — single screen + modal, **no auth guard, no bottom nav** |
| `09_design_principles.md` | Yes — anti-AI-slop; pixel vibe comes from assets, not styling |
| `10_testing_rules.md` | Yes |
| `11_versioning_commits.md` | Yes |

## Non-negotiables (quick reference)

- Layer flow: Domain (pure Dart) → Data (Supabase) → Controller (Riverpod) → UI.
- File naming: `name.type.dart`; classes `NameType`. One widget per file.
- All providers for a feature in one `feature.provider.dart`.
- Zero fixed spacing/font sizes — everything from `MediaQuery` (`docs/03`).
- Colors from `Theme.of(context).colorScheme` only. No gradients/glassmorphism.
- Code-gen (`@riverpod`, `@freezed`): run `build_runner` after annotation changes.
- Conventional Commits; feature work on `feat/<name>` → PR (`docs/11`).
- Tests required for new behavior; see `CONTRIBUTING.md`.

## Secrets

Never hardcode keys. Two git-ignored files, and the split is not cosmetic:

- **`.env`** — `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `POSTHOG_API_KEY`,
  `POSTHOG_HOST`. This file is an **asset in `pubspec.yaml`**, so it ships
  inside the app bundle, which anyone can unzip. Only publishable keys.
- **`.env.tools`** — `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_DB_PASSWORD`.
  Read only by `tool/`, never bundled. The service role key bypasses RLS.

`Env.load()` throws if a `.env.tools` key turns up in `.env`. Each has an
`.example` shipping the keys with empty values.
