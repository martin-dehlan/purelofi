import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` is exported from misc.dart, not the main entry point, in Riverpod 3.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/features/player/presentation/widgets/settings_button.widget.dart';
import 'package:go_router/go_router.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/presentation/player.routes.dart';

import 'package:purelofi/features/library/controller/library.provider.dart';

import 'fake_favorites.repository.dart';
import 'fake_library.repository.dart';
import 'fake_library_preferences.dart';
import 'fake_playback_preferences.dart';
import 'fake_track_picker.dart';

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

/// The listener's library and the file picker, in memory, for the same
/// reason as the favourites: no widget test opens a database or a dialog
/// it cannot answer.
List<Override> _fakeLibrary(
  FakeLibraryRepository? library,
  FakeTrackPicker? picker,
) {
  final FakeLibraryRepository fake = library ?? FakeLibraryRepository();
  addTearDown(fake.dispose);

  return <Override>[
    libraryRepositoryProvider.overrideWithValue(fake),
    trackPickerProvider.overrideWithValue(picker ?? FakeTrackPicker()),
    libraryPreferencesProvider.overrideWithValue(FakeLibraryPreferences()),
    playbackPreferencesProvider.overrideWithValue(FakePlaybackPreferences()),
  ];
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
    FakeLibraryRepository? library,
    FakeTrackPicker? picker,
    Duration? Function(int retryCount, Object error)? retry,
  }) {
    return pumpWidget(
      ProviderScope(
        overrides: <Override>[
          _fakeFavorites(favorites),
          ..._fakeLibrary(library, picker),
          ...overrides,
        ],
        retry: retry ?? (_, _) => null,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: child,
        ),
      ),
    );
  }

  /// Pumps the real router, so deep links can be exercised end to end.
  ///
  /// [theme] defaults to plain Material dark; pass the app's own to see the
  /// chrome as a listener does.
  Future<void> pumpRoutedApp({
    String initialRoute = '/',
    ThemeData? theme,
    List<Override> overrides = const <Override>[],
    FakeFavoritesRepository? favorites,
    FakeLibraryRepository? library,
    FakeTrackPicker? picker,
    Duration? Function(int retryCount, Object error)? retry,
  }) {
    return pumpWidget(
      ProviderScope(
        overrides: <Override>[
          _fakeFavorites(favorites),
          ..._fakeLibrary(library, picker),
          ...overrides,
        ],
        retry: retry ?? (_, _) => null,
        child: MaterialApp.router(
          theme: theme ?? ThemeData.dark(useMaterial3: true),
          routerConfig: GoRouter(
            initialLocation: initialRoute,
            routes: playerRoutes,
          ),
        ),
      ),
    );
  }
}

/// Opens the menu top right and waits for the sheet: the scene, the
/// footage, the account.
Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(find.byType(SettingsButton));
  await tester.pumpAndSettle();
}

/// Taps a row inside the open menu.
Future<void> tapMenuEntry(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// Opens the library from the right of the transport.
Future<void> openLibrary(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Library'));
  await tester.pumpAndSettle();
}

/// Taps one of the library's pills, found by name — the favourites one is a
/// heart without a word on it.
Future<void> tapPill(WidgetTester tester, String label) async {
  final Finder pill = find.byWidgetPredicate(
    (Widget w) => w is ChoiceChip && w.tooltip == label,
  );
  await tester.ensureVisible(pill);
  await tester.pumpAndSettle();
  await tester.tap(pill);
  await tester.pumpAndSettle();
}

/// Opens the library on its "Up next" pill: the queue.
Future<void> openQueue(WidgetTester tester) async {
  await openLibrary(tester);
  await tapPill(tester, 'Up next');
}

/// The menu's entry for the playing track's behind-the-scenes clip.
final Finder footageEntry = find.widgetWithText(ListTile, 'Behind the scenes');

/// Opens the footage from the open menu.
Future<void> openFootage(WidgetTester tester) async {
  await tester.tap(footageEntry);
  await tester.pumpAndSettle();
}
