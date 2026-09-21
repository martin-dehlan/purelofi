# PureLofi

A minimalist pixel-art lo-fi music player for Android and iOS.

A fullscreen looping pixel-art video — the *scene* — sits behind a continuous
audio stream of **real** guitar and bass tracks. Not AI-generated: every track
is played by a human, and a behind-the-scenes clip in the app proves it. The
same tracks feed the companion YouTube channel.

- No login. Public content, nothing to sign up for.
- Streaming, server-first: Supabase is the source of truth.
- Audio keeps playing in the background, with lock-screen controls.

Domain: [purelofi.app](https://purelofi.app)

## Status

MVP (`v0.1.0`). The player works end to end:

- a fullscreen scene video loops behind everything, silent, `BoxFit.cover`
- audio streams continuously and keeps playing when the app is backgrounded
  or the screen is locked, with notification and lock-screen controls
- a track that ends is followed by another, picked at random and never the
  one just played
- the chrome — play/pause, scene switcher, behind-the-scenes — hides itself
  after four seconds of stillness and returns on a tap
- the behind-the-scenes clip shows the track actually being played; the music
  pauses while it runs and picks up afterwards
- `purelofi://app/track/<id>` opens the player with that track's clip

Offline caching, favorites and a paid tier are Phase 2.

The pixel icons in `assets/icons/` are placeholders — plain white glyphs, to
be replaced with the real PixelLab art. Scenes are authored as sprite layers;
[`docs/12`](docs/12_scene_assets.md) is the authoring contract, and

```bash
dart run tool/upload_scene.dart --scene rainy_room --dir ~/Desktop/rainy_room
```

turns a folder into a playable scene.

## Stack

Flutter · Riverpod (code-gen) · Freezed + json_serializable · Supabase
(`supabase_flutter`, read-only) · `just_audio` + `audio_service` ·
`video_player` · `go_router` · `posthog_flutter` · `mocktail`

## Setup

```bash
flutter pub get
cp .env.example .env    # fill in SUPABASE_URL, SUPABASE_ANON_KEY,
                        # POSTHOG_API_KEY, POSTHOG_HOST
dart run build_runner build
flutter run
```

Generated files (`*.g.dart`, `*.freezed.dart`) are not committed — run
`build_runner` after cloning and after any annotation change.

## Tests

```bash
flutter test                   # unit + widget
flutter test integration_test/ # integration
```

CI runs `dart format --set-exit-if-changed`, `flutter analyze` and
`flutter test` on every pull request. The testing policy — tests for new
behaviour, a regression test for every fix — is in
[CONTRIBUTING.md](CONTRIBUTING.md#testing-policy).

## Architecture

```
lib/
  features/player/
    domain/        entities, repository + audio player interfaces, player.state
    data/          models, content.api, repository impl, audio_player.service.impl
    controller/    player.provider (all providers) + the controllers
    presentation/  player.screen, player.routes, widgets
  common/
    analytics/     analytics.service + provider
    config/        env, supabase client provider
    errors/        app_error (sealed union) + error_mapper
    routes/        app_routes, app_router
    utils/         responsive, app_assets
    widgets/       loading/error state, pixel_icon
```

Layer flow: **Domain → Data → Controller → UI.** Domain is pure Dart and
imports no Flutter, no Riverpod and no Supabase. The UI never touches the
Supabase client or a repository directly — it goes through the controllers.

| Doc | What it governs |
|---|---|
| [`01`](docs/01_core_architecture.md) | Layers and the dependency rules |
| [`02`](docs/02_file_naming_conventions.md) | `name.type.dart`, `NameType`, one widget per file |
| [`03`](docs/03_responsive_ui_rules.md) | All spacing and font sizes from `MediaQuery` |
| [`04`](docs/04_drift_database_rules.md) | **Phase 2 only** — no Drift in the MVP |
| [`05`](docs/05_riverpod_patterns.md) | Riverpod code-gen, one provider file per feature |
| [`06`](docs/06_code_generation.md) | Freezed + json_serializable + riverpod_generator |
| [`07`](docs/07_error_handling.md) | `AppError`, `ErrorMapper`, the three `AsyncValue` states |
| [`08`](docs/08_navigation_structure.md) | go_router, deep links, no auth guard, no shell |
| [`09`](docs/09_design_principles.md) | Anti-AI-slop: theme colors, no gradients |
| [`10`](docs/10_testing_rules.md) | The test pyramid and the mocking approach |
| [`11`](docs/11_versioning_commits.md) | Semver, Conventional Commits, branch and PR flow |
| [`12`](docs/12_scene_assets.md) | Scene sprite layers: canvas, naming, `scene.json`, upload |

[`docs/SPEC.md`](docs/SPEC.md) defines the app scope and the intentional MVP
deviations — **no auth, no Drift, no paywall**. Where `SPEC.md` and a numbered
rule disagree, `SPEC.md` wins.

### Testing seams

`video_player`, `just_audio` and `audio_service` all talk to platform
channels, so they sit behind things a test can replace: `AudioPlayerService`
has a fake, and the two video surfaces are injected through
`sceneVideoBuilderProvider` and `btsVideoBuilderProvider`. No test touches the
network, Supabase or a real player.

Contributions: see [CONTRIBUTING.md](CONTRIBUTING.md), including the
[testing policy](CONTRIBUTING.md#testing-policy).
