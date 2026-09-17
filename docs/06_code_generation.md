# Code Generation Rules

**TL;DR:** Two code-gen systems in the MVP — Freezed (entities + models) and Riverpod Generator (providers). Each requires its own `part` directive. Run `build_runner` after any change to annotated files. (Drift codegen is Phase 2 only — see `docs/04`.)

---

## Overview

| Tool | Annotation | Output | MVP? |
|---|---|---|---|
| Freezed | `@freezed` | `.freezed.dart` | Yes |
| json_serializable | `@JsonSerializable` | `.g.dart` (via Freezed) | Yes |
| Riverpod Generator | `@riverpod` | `.g.dart` | Yes |
| Drift | `@DriftDatabase`, `@DriftAccessor` | `.g.dart` | **Phase 2** |

---

## Freezed: Entities (no JSON)

Domain entities have no JSON serialization — they never touch the network directly.

```dart
// lib/features/player/domain/track.entity.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'track.entity.freezed.dart';

@freezed
class TrackEntity with _$TrackEntity {
  const factory TrackEntity({
    required String id,
    required String title,
    required String audioUrl,
    String? btsVideoUrl,
    int?    durationSeconds,
    required DateTime createdAt,
  }) = _TrackEntity;
}
```

```dart
// lib/features/player/domain/scene.entity.dart
part 'scene.entity.freezed.dart';

@freezed
class SceneEntity with _$SceneEntity {
  const factory SceneEntity({
    required String id,
    required String title,
    required String videoUrl,
    String? thumbnailUrl,
    required int sortOrder,
  }) = _SceneEntity;
}
```

Rules:
- No `@JsonKey`, no `fromJson`, no `toJson`
- Only `.freezed.dart` part — no `.g.dart`

---

## Freezed: Models (with JSON)

Models are the data/API layer. They map to Supabase column names (snake_case).

```dart
// lib/features/player/data/track.model.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'track.model.freezed.dart';
part 'track.model.g.dart';

@freezed
class TrackModel with _$TrackModel {
  const factory TrackModel({
    required String id,
    required String title,
    @JsonKey(name: 'audio_url')        required String audioUrl,
    @JsonKey(name: 'bts_video_url')    String? btsVideoUrl,
    @JsonKey(name: 'duration_seconds') int? durationSeconds,
    @JsonKey(name: 'is_active')        required bool isActive,
    @JsonKey(name: 'created_at')       required DateTime createdAt,
  }) = _TrackModel;

  factory TrackModel.fromJson(Map<String, dynamic> json) =>
      _$TrackModelFromJson(json);
}
```

Rules:
- Two `part` directives: `.freezed.dart` AND `.g.dart`
- Use `@JsonKey(name: 'snake_case')` to map Supabase column names
- Always include `fromJson` factory. `toJson()` is auto-generated (unused in
  MVP since there are no writes, but keep it for symmetry).

---

## Model → Entity Conversion

Define as an extension on the model:

```dart
// lib/features/player/data/track.model.dart (bottom of file)
extension TrackModelX on TrackModel {
  TrackEntity toEntity() => TrackEntity(
    id: id,
    title: title,
    audioUrl: audioUrl,
    btsVideoUrl: btsVideoUrl,
    durationSeconds: durationSeconds,
    createdAt: createdAt,
  );
}
```

---

## Riverpod Generator

```dart
// lib/features/player/controller/player.provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'player.provider.g.dart';  // ← required

@riverpod
ContentRepository contentRepository(Ref ref) { ... }

@riverpod
class PlayerController extends _$PlayerController {
  @override
  PlayerState build() => const PlayerState.initial();
}
```

---

## Drift — Phase 2 only

See `docs/04`. Do not add Drift parts/annotations in the MVP.

---

## Build Runner Commands

```bash
# Full build (clean + regenerate everything)
dart run build_runner build --delete-conflicting-outputs

# Watch mode (auto-rebuild on save)
dart run build_runner watch --delete-conflicting-outputs

# Clean generated files
dart run build_runner clean
```

---

## Common Errors & Fixes

| Error | Cause | Fix |
|---|---|---|
| `Missing 'part' directive` | Forgot `part 'file.g.dart'` | Add the correct `part` line |
| `_$ClassName not found` | Build not run yet | Run `build_runner build` |
| `Duplicate output` | Stale `.g.dart` files | Run with `--delete-conflicting-outputs` |
| `fromJson not generated` | Missing `fromJson` factory on `@freezed` class | Add the factory |
| `@riverpod on non-class` | Using class syntax for simple provider | Use function form |

---

## Rules Checklist

- [ ] Entities: only `.freezed.dart` part, no JSON
- [ ] Models: both `.freezed.dart` and `.g.dart` parts, have `fromJson`
- [ ] Use `@JsonKey(name: ...)` for snake_case Supabase columns
- [ ] Conversion extensions defined (Model → Entity)
- [ ] Run `build_runner` after every annotation change before testing
- [ ] Never hand-edit `.g.dart` or `.freezed.dart` files
