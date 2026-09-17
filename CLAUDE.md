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
| Fullscreen looping scene video | Offline caching (Drift — `docs/04`) |
| Continuous audio stream (`just_audio` + `audio_service`) | Favorites |
| Random track selection, background/lock-screen controls | RevenueCat paywall |
| Scene switcher | More scenes / user accounts |
| BTS ("this is real, not AI") modal | |
| PostHog analytics (4 events) | |

**Not in MVP dependencies:** `drift`, `drift_flutter`, `purchases_flutter`.

## The rules (docs/)

| Doc | Applies to MVP? |
|---|---|
| `01_core_architecture.md` | Yes — but source of truth is Supabase, not Drift |
| `02_file_naming_conventions.md` | Yes, verbatim |
| `03_responsive_ui_rules.md` | Yes, verbatim |
| `04_drift_database_rules.md` | **Phase 2 only** — do not add Drift in MVP |
| `05_riverpod_patterns.md` | Yes |
| `06_code_generation.md` | Yes (Freezed + Riverpod; Drift codegen is Phase 2) |
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

Never hardcode keys. Use `.env` (git-ignored) with `SUPABASE_URL`,
`SUPABASE_ANON_KEY`, `POSTHOG_API_KEY`, `POSTHOG_HOST`. `.env.example` ships
the keys with empty values.
