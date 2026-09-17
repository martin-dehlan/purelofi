# PureLofi — App Spec

> Complements the numbered architecture rules (`01`–`11`) in `docs/`.
> Where this spec and a rule doc disagree, this spec wins for *this* app
> (the deviations are listed under "Scope decisions").

## TL;DR

Public, minimalist pixel-art lo-fi player. A fullscreen looping pixel-art
video (the *scene*) sits behind a continuous audio stream of **real** tracks
(guitar/bass, not AI). Content lives in Supabase Storage; the same tracks feed
a companion YouTube channel. **No login** — public content consumption. Audio
plays in the background with lock-screen controls. Architecture follows rules
`01`–`11`, with the deviations below.

## Scope decisions (differs from the initial draft)

| Area | Decision | Why |
|---|---|---|
| **Auth** | None for MVP | Public content; nothing user-owned to protect. Drops the auth guard/redirect from rule `08`. |
| **Drift local-first** (rule `04`) | Deferred → Phase 2 | Streaming app; source of truth is Supabase, not local. Add Drift only for offline playback + favorites. |
| **RevenueCat / paywall** | Deferred → Phase 2 | No product to gate yet. Ship the player first. |
| **PostHog** | MVP, minimal events | Lightweight; validates that people actually open + listen. |
| **PixelLab (AI visuals)** | OK | Stylistic choice. The "human lo-fi" selling point is the audio, not the art. |
| **Application layer** (rule `01`) | Skipped | No cross-feature workflow yet. Repository → controller is enough. |

## Content model (Supabase)

Two independent tables. Audio plays continuously (random track selection);
the visual *scene* is swapped independently by the user — classic lo-fi model.

**`scenes`**
| column | type | notes |
|---|---|---|
| `id` | uuid | pk |
| `title` | text | e.g. "Rainy Room" |
| `video_url` | text | public URL, vertical MP4 loop (1080×1920) |
| `thumbnail_url` | text? | for the scene switcher |
| `sort_order` | int | display order |
| `is_active` | bool | soft toggle |
| `created_at` | timestamptz | |

**`tracks`**
| column | type | notes |
|---|---|---|
| `id` | uuid | pk |
| `title` | text | |
| `audio_url` | text | public URL, streamed |
| `bts_video_url` | text? | behind-the-scenes / proof media |
| `duration_seconds` | int? | |
| `is_active` | bool | |
| `created_at` | timestamptz | |

Storage buckets (public read): `scenes`, `tracks`, `bts`.

## Tech stack (MVP)

- **Framework:** Flutter
- **State:** `flutter_riverpod` + `riverpod_annotation` (code-gen, per rule `05`/`06`)
- **Codegen models:** `freezed` + `json_serializable` (per rule `06`)
- **Backend:** `supabase_flutter` (Storage + DB read only — no auth)
- **Audio:** `just_audio` + `audio_service` (background + lock-screen controls)
- **Video:** `video_player` (looping scene background, `BoxFit.cover`)
- **Nav:** `go_router` (per rule `08`, but no redirect/auth guard)
- **Analytics:** `posthog_flutter`
- **Test:** `mocktail` + `flutter_test` (per rule `10`)

**Not in MVP:** `drift`, `purchases_flutter`.

Platform config to remember: `audio_service` needs the Android foreground
service + `<uses-permission>` entries, and iOS `UIBackgroundModes: audio`.

## Architecture mapping

```
features/player/
  domain/      scene.entity.dart, track.entity.dart, content.repository.dart
  data/        scene.model.dart, track.model.dart, content.api.dart,
               content.repository.impl.dart
  controller/  player.provider.dart, player.controller.dart,
               scene.controller.dart
  presentation/
    screens/   player.screen.dart
    widgets/   scene_background.widget.dart, player_controls.widget.dart,
               scene_switcher.widget.dart, bts_modal.widget.dart
common/
  analytics/   analytics.service.dart
  errors/      app_error.dart, error_mapper.dart   (per rule 07)
  utils/       responsive.dart                     (per rule 03)
  widgets/     error_state.widget.dart, loading_state.widget.dart
```

- Naming per rule `02` (`name.type.dart`, `NameType`).
- One provider file per feature per rule `05` (`player.provider.dart`).
- UI chrome (buttons, controls, modal) follows the anti-AI-slop rules `09`:
  theme colors, no gradients/glassmorphism, minimal elevation. The pixel-art
  *vibe* comes from the video/PNG assets, not from Flutter styling.

## Screens

**PlayerScreen** (the whole app, essentially)
- Fullscreen looping `video_player` for the active scene (`BoxFit.cover`).
- `just_audio` streams tracks continuously; random next-track selection.
- Pixel play/pause overlay (`play_icon.png` / `pause_icon.png`).
- Controls auto-hide after 4s of inactivity; tap to reveal.
- Scene switcher (`scene_switch_icon.png`) → picks another active scene.
- Info/camera icon (`camera_icon.png`) → BTS modal.

**BTS modal**
- Shows the current track's `bts_video_url` (your phone footage of you
  playing) — the "this is real, not AI" proof.

## Analytics events (MVP)

`app_opened`, `track_played` (track_id), `bts_opened` (track_id),
`scene_switched` (scene_id). That's enough to see retention + which scenes
and tracks land.

## Phases

**MVP (v0.1.0)** — player works end to end: scenes loop, audio streams in the
background, scene switch, BTS modal, PostHog wired.

**Phase 2** — offline caching via Drift (rule `04`) for travel; favorites;
RevenueCat gate (e.g. extra scenes / offline as the paid tier); more scenes.
