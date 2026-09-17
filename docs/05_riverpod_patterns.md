# Riverpod Patterns

**TL;DR:** Use code-gen (`@riverpod`) everywhere. All providers for a feature live in one `feature.provider.dart` file. Use `AsyncNotifier` for async state, `Notifier` for synchronous playback state, `.family` for parameterized providers.

---

## Setup

```yaml
# pubspec.yaml
dependencies:
  flutter_riverpod: ^2.x.x
  riverpod_annotation: ^2.x.x

dev_dependencies:
  riverpod_generator: ^2.x.x
  build_runner: ^2.x.x
```

Every file using code-gen needs:
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'player.provider.g.dart';  // or player.controller.g.dart
```

---

## Provider Types

### Simple Provider (dependency / value)

```dart
// player.provider.dart
@riverpod
ContentRepository contentRepository(Ref ref) {
  return ContentRepositoryImpl(
    api: ref.watch(contentApiProvider),
  );
}
```

### AsyncNotifier (async content load)

Use for: load scenes/tracks once from Supabase.

```dart
// content.controller.dart  (or inside player controller)
@riverpod
class TrackListController extends _$TrackListController {
  @override
  Future<List<TrackEntity>> build() async {
    return ref.watch(contentRepositoryProvider).getTracks();
  }
}

@riverpod
class SceneListController extends _$SceneListController {
  @override
  Future<List<SceneEntity>> build() async {
    return ref.watch(contentRepositoryProvider).getScenes();
  }
}
```

### Notifier (synchronous playback state)

Use for: which track/scene is active, play/pause. This is the heart of the
player — it is not backed by the network, so a plain `Notifier` fits.

```dart
// player.controller.dart
@riverpod
class PlayerController extends _$PlayerController {
  @override
  PlayerState build() => const PlayerState.initial();

  void playRandomTrack(List<TrackEntity> tracks) { ... }
  void togglePlayPause() { ... }
  void nextTrack(List<TrackEntity> tracks) { ... }
}

@riverpod
class ActiveSceneController extends _$ActiveSceneController {
  @override
  SceneEntity? build() => null;

  void switchTo(SceneEntity scene) => state = scene;
}
```

### Family (parameterized)

```dart
@riverpod
Future<TrackEntity?> trackDetail(Ref ref, String trackId) {
  return ref.watch(contentRepositoryProvider).getTrackById(trackId);
}
```

---

## Centralizing Providers

All providers for a feature go in `controller/player.provider.dart`:

```dart
// lib/features/player/controller/player.provider.dart

part 'player.provider.g.dart';

@riverpod
ContentApi contentApi(Ref ref) => ContentApi(ref.watch(supabaseClientProvider));

@riverpod
ContentRepository contentRepository(Ref ref) =>
    ContentRepositoryImpl(api: ref.watch(contentApiProvider));

// Controllers live in their own .controller.dart but are imported/re-exported
// here so callers only need to import player.provider.dart
```

---

## UI Consumption

### AsyncValue.when

```dart
class PlayerScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scenesAsync = ref.watch(sceneListControllerProvider);

    return scenesAsync.when(
      data: (scenes) => PlayerView(scenes: scenes),
      loading: () => const LoadingState(),
      error: (error, _) => ErrorState(error: error),
    );
  }
}
```

### Listening to state changes (side effects)

```dart
ref.listen<AsyncValue<List<TrackEntity>>>(
  trackListControllerProvider,
  (_, next) {
    next.whenOrNull(
      error: (e, _) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      ),
    );
  },
);
```

---

## Useful Patterns

### Invalidate (force refresh)

```dart
ref.invalidate(trackListControllerProvider);
```

### Select (prevent unnecessary rebuilds)

```dart
// Only rebuild when play state flips
final isPlaying = ref.watch(
  playerControllerProvider.select((s) => s.isPlaying),
);
```

### Override in tests

```dart
ProviderScope(
  overrides: [
    contentRepositoryProvider.overrideWithValue(MockContentRepository()),
  ],
  child: const MyApp(),
)
```

---

## Build Commands

```bash
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch --delete-conflicting-outputs
```

---

## Rules Checklist

- [ ] All providers use `@riverpod` annotation (no manual `Provider(...)`)
- [ ] All feature providers in one `feature.provider.dart` file
- [ ] Async content loads wrapped in `AsyncValue.guard` when mutated
- [ ] Playback state uses a plain `Notifier` (synchronous)
- [ ] Use `.family` for ID-parameterized providers
- [ ] UI uses `.when()` — never access `.value` directly without null check
