import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` is exported from misc.dart, not the main entry point, in Riverpod 3.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/features/player/presentation/widgets/settings_button.widget.dart';
import 'package:go_router/go_router.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/presentation/player.routes.dart';

import 'fake_favorites.repository.dart';

/// Favourites in memory, so no widget test opens a database.
///
/// Drift schedules timers of its own and `testWidgets` fails a test that
/// leaves one pending, so the real database stays out of the widget layer;
/// what it does is covered by the DAO and repository tests.
Override _fakeFavorites(FakeFavoritesRepository? repository) {
  final FakeFavoritesRepository fake = repository ?? FakeFavoritesRepository();
  addTearDown(fake.dispose);

  return favoritesRepositoryProvider.overrideWithValue(fake);
}

extension PumpRouted on WidgetTester {
  /// Pumps [child] inside a themed `MaterialApp` and a `ProviderScope` with
  /// [overrides] applied.
  ///
  /// Riverpod 3 retries a failed provider on an exponential backoff. That is
  /// what we want in the app — a dropped connection recovers on its own — but
  /// it makes error tests non-deterministic, so retries are off by default
  /// here. Pass [retry] to exercise them.
  ///
  /// [favorites] is supplied when a test cares what is marked; otherwise an
  /// empty one is made for it.
  Future<void> pumpProviderApp({
    required Widget child,
    List<Override> overrides = const <Override>[],
    FakeFavoritesRepository? favorites,
    Duration? Function(int retryCount, Object error)? retry,
  }) {
    return pumpWidget(
      ProviderScope(
        overrides: <Override>[_fakeFavorites(favorites), ...overrides],
        retry: retry ?? (_, _) => null,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: child,
        ),
      ),
    );
  }

  /// Pumps the real router, so deep links can be exercised end to end.
  Future<void> pumpRoutedApp({
    String initialRoute = '/',
    List<Override> overrides = const <Override>[],
    FakeFavoritesRepository? favorites,
    Duration? Function(int retryCount, Object error)? retry,
  }) {
    return pumpWidget(
      ProviderScope(
        overrides: <Override>[_fakeFavorites(favorites), ...overrides],
        retry: retry ?? (_, _) => null,
        child: MaterialApp.router(
          theme: ThemeData.dark(useMaterial3: true),
          routerConfig: GoRouter(
            initialLocation: initialRoute,
            routes: playerRoutes,
          ),
        ),
      ),
    );
  }
}

/// Opens the menu behind the gear and waits for the sheet.
///
/// Scene switching and the footage moved in there, so tests reach them the
/// same way a listener does.
Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(find.byType(SettingsButton));
  await tester.pumpAndSettle();
}

/// Taps a row inside the open menu.
Future<void> tapMenuEntry(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}
