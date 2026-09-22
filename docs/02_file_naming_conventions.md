# File & Class Naming Conventions

**TL;DR:** Use `name.type.dart` for files, `NameType` for classes. One widget per file. Match folder structure to feature/layer.

---

## File Naming Pattern

```
name.type.dart
```

### Recognized Type Suffixes

| Suffix | Example | Purpose |
|---|---|---|
| `.entity.dart` | `track.entity.dart` | Domain model (Freezed, no JSON) |
| `.model.dart` | `track.model.dart` | Data/API model (Freezed + JSON) |
| `.repository.dart` | `content.repository.dart` | Abstract repository interface |
| `.repository.impl.dart` | `content.repository.impl.dart` | Concrete repository implementation |
| `.api.dart` | `content.api.dart` | Supabase/REST API calls |
| `.provider.dart` | `player.provider.dart` | All Riverpod providers for a feature |
| `.controller.dart` | `player.controller.dart` | AsyncNotifier / StateNotifier |
| `.state.dart` | `player.state.dart` | Freezed state class for a controller |
| `.screen.dart` | `player.screen.dart` | Full-screen routable widget |
| `.widget.dart` | `scene_switcher.widget.dart` | Reusable sub-widget |
| `.routes.dart` | `player.routes.dart` | Feature route definitions |
| `.service.dart` | `analytics.service.dart` | Cross-feature service |
| `.dao.dart` | `track.dao.dart` | Drift access object |
| `.table.dart` | `track.table.dart` | Drift table definition |
| `.mapper.dart` | `content_cache.mapper.dart` | Translation between two layers' types |

---

## Class Naming

File suffix maps directly to class name suffix:

```dart
// track.entity.dart
class TrackEntity { ... }

// track.model.dart
class TrackModel { ... }

// content.repository.dart
abstract class ContentRepository { ... }

// content.repository.impl.dart
class ContentRepositoryImpl implements ContentRepository { ... }

// player.provider.dart  ← all providers for this feature live here
final sceneListProvider = ...
final trackListProvider = ...

// player.controller.dart
class PlayerController extends AsyncNotifier<PlayerState> { ... }
```

### Provider Naming

Pattern: `entityTypeProvider` (camelCase)

```dart
final sceneListProvider    = ...   // list of scenes
final trackListProvider    = ...   // list of tracks
final playerControllerProvider = ...   // playback notifier
final activeSceneProvider  = ...   // currently displayed scene
```

---

## Folder Structure

```
lib/
  features/
    player/
      data/
        scene.model.dart
        track.model.dart
        content.api.dart
        content.repository.impl.dart
      domain/
        scene.entity.dart
        track.entity.dart
        content.repository.dart
      controller/
        player.controller.dart
        scene.controller.dart
        player.provider.dart          ← ALL providers for this feature
      presentation/
        screens/
          player.screen.dart
        widgets/
          scene_background.widget.dart
          player_controls.widget.dart
          scene_switcher.widget.dart
          bts_modal.widget.dart
        player.routes.dart
  common/
    analytics/
      analytics.service.dart
    utils/
      responsive.dart
    errors/
      app_error.dart
      error_mapper.dart
    widgets/
      error_state.widget.dart
      loading_state.widget.dart
```

---

## Rules

- **One widget per file.** `SceneSwitcher` lives in `scene_switcher.widget.dart`.
- **One class per file** for entities, models, repositories.
- **One provider file per feature** — `player.provider.dart` contains all
  `xxxProvider` declarations for that feature.
- **Sub-folders only when 5+ related files** exist in the same layer. Don't
  pre-create empty folders.
- Screen files always end in `.screen.dart`, never just `player.dart`.
- Never put providers in the same file as a controller — always separate
  `.provider.dart`.
