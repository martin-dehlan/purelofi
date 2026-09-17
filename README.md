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

MVP (`v0.1.0`) in progress: scene video loop, continuous audio streaming,
random track selection, scene switcher, BTS modal, PostHog analytics.
Offline caching, favorites and a paid tier are Phase 2.

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

## Architecture

```
lib/
  features/player/
    domain/        entities + repository interface (pure Dart)
    data/          models, content.api, repository impl (Supabase)
    controller/    Riverpod providers + controllers
    presentation/  player.screen + widgets
  common/          analytics, errors, routes, utils, widgets
```

Layer flow: Domain → Data → Controller → UI. The full rules live in
[`docs/`](docs/) — `docs/01`–`docs/11` are binding, and
[`docs/SPEC.md`](docs/SPEC.md) defines the app scope and the intentional
deviations (no auth, no Drift in the MVP). Where they disagree, `SPEC.md` wins.

Contributions: see [CONTRIBUTING.md](CONTRIBUTING.md), including the
[testing policy](CONTRIBUTING.md#testing-policy).
