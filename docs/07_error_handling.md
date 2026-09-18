# Error Handling Rules

**TL;DR:** All errors funnel through `AppError` (Freezed union). The repository catches exceptions and maps to `AppError`. Controllers use `AsyncValue.guard`. UI uses `.when()` with `ErrorState`. Network is the main failure path (streaming); there is no auth in the MVP.

---

## AppError Union

File: `lib/common/errors/app_error.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_error.freezed.dart';

@freezed
sealed class AppError with _$AppError implements Exception {
  const factory AppError.network({
    String? message,
    int?    statusCode,
  }) = NetworkError;

  const factory AppError.notFound({
    required String resource,
  }) = NotFoundError;

  const factory AppError.serverError({
    String? message,
    int?    statusCode,
  }) = ServerError;

  const factory AppError.playback({
    required String message,
  }) = PlaybackError;

  const factory AppError.unknown({
    required Object cause,
    StackTrace? stackTrace,
  }) = UnknownError;
}

extension AppErrorX on AppError {
  // Freezed 3 removed `when`/`map` — match on the subclasses instead.
  String get userMessage => switch (this) {
    NetworkError(:final message) =>
      message ?? 'No internet connection. Check your network.',
    NotFoundError(:final resource) => '$resource not found.',
    ServerError(:final message, :final statusCode) =>
      message ?? 'Server error (${statusCode ?? '?'}). Try again.',
    PlaybackError(:final message) => 'Playback error: $message',
    UnknownError() => 'Something went wrong. Please try again.',
  };
}
```

> Dropped from the wine-app lineage: `unauthorized`, `validation`, `database`.
> No auth, no forms, no local DB in the MVP. Added `playback` for
> `just_audio` / `video_player` failures (a real, streaming-specific case).

---

## ErrorMapper

File: `lib/common/errors/error_mapper.dart`

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_error.dart';

class ErrorMapper {
  static AppError fromException(Object error, [StackTrace? st]) {
    if (error is AppError) return error;

    // Supabase
    if (error is PostgrestException) {
      return switch (error.code) {
        'PGRST116' => const AppError.notFound(resource: 'record'),
        _          => AppError.serverError(message: error.message),
      };
    }

    if (error is StorageException) {
      return AppError.serverError(message: error.message);
    }

    // Common network signatures
    final s = error.toString();
    if (s.contains('SocketException') ||
        s.contains('Connection') ||
        s.contains('timeout')) {
      return const AppError.network();
    }

    return AppError.unknown(cause: error, stackTrace: st);
  }
}
```

---

## Repository Error Handling

The repository catches all exceptions and maps to `AppError`:

```dart
// content.repository.impl.dart
@override
Future<List<TrackEntity>> getTracks() async {
  try {
    final models = await api.fetchTracks();
    return models.map((m) => m.toEntity()).toList();
  } on Object catch (e, st) {
    throw ErrorMapper.fromException(e, st);
  }
}
```

---

## Controller: AsyncValue.guard

```dart
@riverpod
class TrackListController extends _$TrackListController {
  @override
  Future<List<TrackEntity>> build() async {
    return ref.watch(contentRepositoryProvider).getTracks();
  }
}
```

`build()` throwing an `AppError` surfaces as `AsyncError` automatically. For
manual actions, wrap in `AsyncValue.guard`.

---

## UI: .when() with ErrorState

```dart
// player.screen.dart
ref.watch(trackListControllerProvider).when(
  data:    (tracks) => PlayerView(tracks: tracks),
  loading: ()       => const LoadingState(),
  error:   (e, _)   => ErrorState(error: e),
)
```

File: `lib/common/widgets/error_state.widget.dart`

```dart
class ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;

  const ErrorState({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final appError = ErrorMapper.fromException(error);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: cs.error),
          SizedBox(height: context.spaceM),
          Text(
            appError.userMessage,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: context.fontM),
          ),
          if (onRetry != null) ...[
            SizedBox(height: context.spaceM),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}
```

---

## Rules Checklist

- [ ] All exceptions caught in the repository and mapped via `ErrorMapper`
- [ ] Repository throws `AppError`, never raw exceptions
- [ ] Controllers use `AsyncValue.guard` for manual actions
- [ ] UI always handles all three `AsyncValue` states (data/loading/error)
- [ ] User-visible messages come from `AppError.userMessage`, never raw exceptions
- [ ] Playback failures map to `AppError.playback`, not silent failure
