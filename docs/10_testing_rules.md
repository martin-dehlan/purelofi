# Testing Rules

> **Policy:** This file is the test *strategy*. The public test *policy
> commitment* (tests required for new behaviour, regression tests for fixes)
> lives in [`CONTRIBUTING.md`](../CONTRIBUTING.md#testing-policy).

**TL;DR:** Three-tier test pyramid: unit (fast, most), widget (medium),
integration (slow, few). Use Mocktail for mocks. Override Riverpod providers with
`ProviderScope`. Keep tests in `test/` mirroring `lib/` structure.

---

## Test Pyramid

```
         /\
        /  \   Integration tests   (integration_test/)
       /----\  Widget tests        (test/widget/)
      /      \ Unit tests          (test/unit/)
     /________\
```

- **Unit**: repository, controllers, mappers — no Flutter framework
- **Widget**: screens and widgets with mock providers — no real network
- **Integration**: full app flow (player loads, track plays)

---

## Dependencies

```yaml
# pubspec.yaml dev_dependencies
dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.x.x
  integration_test:
    sdk: flutter
```

---

## Folder Structure

```
test/
  unit/
    features/
      player/
        player_controller_test.dart
        content_repository_test.dart
    common/
      error_mapper_test.dart
  widget/
    features/
      player/
        player_screen_test.dart
        bts_modal_test.dart
  helpers/
    pump_routed_app.dart        ← shared test helper
    mock_repositories.dart      ← centralized mock declarations
integration_test/
  player_flow_test.dart
```

---

## Mocktail Setup

File: `test/helpers/mock_repositories.dart`

```dart
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/player/domain/content.repository.dart';
import 'package:purelofi/features/player/data/content.api.dart';

class MockContentRepository extends Mock implements ContentRepository {}
class MockContentApi extends Mock implements ContentApi {}

TrackEntity makeTrack(String id, {String title = 'Rainy Nights'}) => TrackEntity(
  id: id,
  title: title,
  audioUrl: 'https://example.com/$id.mp3',
  createdAt: DateTime(2026),
);

SceneEntity makeScene(String id, {String title = 'Rainy Room'}) => SceneEntity(
  id: id,
  title: title,
  videoUrl: 'https://example.com/$id.mp4',
  sortOrder: 0,
);
```

---

## Unit Tests: Controllers

Test state transitions, not implementation details.

```dart
// test/unit/features/player/player_controller_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  late MockContentRepository mockRepo;
  late ProviderContainer container;

  setUp(() {
    mockRepo = MockContentRepository();
    container = ProviderContainer(
      overrides: [
        contentRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
    addTearDown(container.dispose);
  });

  group('TrackListController', () {
    test('loads tracks from repository', () async {
      final tracks = [makeTrack('id-1'), makeTrack('id-2')];
      when(() => mockRepo.getTracks()).thenAnswer((_) async => tracks);

      final result = await container.read(trackListControllerProvider.future);

      expect(result, tracks);
    });

    test('state terminates — never stays in loading indefinitely', () async {
      when(() => mockRepo.getTracks()).thenAnswer((_) async => []);

      final future = container.read(trackListControllerProvider.future);
      await expectLater(future, completes);
    });
  });

  group('PlayerController', () {
    test('togglePlayPause flips isPlaying', () {
      final notifier = container.read(playerControllerProvider.notifier);
      final before = container.read(playerControllerProvider).isPlaying;
      notifier.togglePlayPause();
      expect(container.read(playerControllerProvider).isPlaying, !before);
    });

    test('nextTrack never repeats the current track when >1 available', () {
      final tracks = [makeTrack('a'), makeTrack('b')];
      final notifier = container.read(playerControllerProvider.notifier);
      notifier.playRandomTrack(tracks);
      final first = container.read(playerControllerProvider).currentTrackId;
      notifier.nextTrack(tracks);
      final second = container.read(playerControllerProvider).currentTrackId;
      expect(second, isNot(first));
    });
  });
}
```

---

## Unit Tests: Repository

```dart
// test/unit/features/player/content_repository_test.dart
void main() {
  late MockContentApi mockApi;
  late ContentRepositoryImpl repository;

  setUp(() {
    mockApi = MockContentApi();
    repository = ContentRepositoryImpl(api: mockApi);
  });

  test('getTracks maps models to entities', () async {
    when(() => mockApi.fetchTracks()).thenAnswer(
      (_) async => [/* TrackModel fixtures */],
    );

    final result = await repository.getTracks();

    expect(result, isA<List<TrackEntity>>());
  });

  test('getTracks throws AppError on failure', () async {
    when(() => mockApi.fetchTracks()).thenThrow(Exception('boom'));

    expect(() => repository.getTracks(), throwsA(isA<AppError>()));
  });
}
```

---

## Widget Tests

```dart
// test/widget/features/player/player_screen_test.dart
void main() {
  late MockContentRepository mockRepo;

  setUp(() => mockRepo = MockContentRepository());

  testWidgets('shows error state on failure', (tester) async {
    when(() => mockRepo.getScenes()).thenThrow(const AppError.network());
    when(() => mockRepo.getTracks()).thenAnswer((_) async => []);

    await tester.pumpProviderApp(
      overrides: [contentRepositoryProvider.overrideWithValue(mockRepo)],
    );
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);
  });
}
```

> Note: `video_player` and `just_audio` need fakes in widget tests (they hit
> platform channels). Inject them behind a thin service you can mock, or gate
> the video/audio widgets behind a provider you override with a no-op in tests.

---

## pump_routed_app Helper

File: `test/helpers/pump_routed_app.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

extension PumpRouted on WidgetTester {
  Future<void> pumpProviderApp({
    required List<Override> overrides,
    String initialRoute = '/',
  }) async {
    final router = GoRouter(
      initialLocation: initialRoute,
      routes: playerRoutes, // import your route list
    );

    await pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }
}
```

---

## Integration Tests

```dart
// integration_test/player_flow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app opens and shows the player', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PureLofiApp()));
    await tester.pumpAndSettle();

    expect(find.byType(PlayerScreen), findsOneWidget);
  });
}
```

Run:
```bash
flutter test                      # unit + widget
flutter test integration_test/    # integration
```

---

## Rules Checklist

- [ ] Unit tests use `ProviderContainer` directly (no Flutter framework)
- [ ] Widget tests use `pumpProviderApp` helper
- [ ] Every async controller test checks for state termination
- [ ] Mocks declared centrally in `test/helpers/mock_repositories.dart`
- [ ] No real network or Supabase calls in unit or widget tests
- [ ] `video_player` / `just_audio` are faked or provider-overridden in tests
- [ ] `addTearDown(container.dispose)` in every unit test with `ProviderContainer`
