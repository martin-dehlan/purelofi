import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` is exported from misc.dart, not the main entry point, in Riverpod 3.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/features/player/presentation/widgets/library_button.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/menu_button.widget.dart';
import 'package:go_router/go_router.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/presentation/player.routes.dart';

import 'package:purelofi/features/auth/controller/auth.provider.dart';
import 'package:purelofi/features/library/controller/library.provider.dart';
import 'package:purelofi/features/pro/controller/pro.provider.dart';

import 'fake_auth.repository.dart';
import 'fake_display_preferences.dart';
import 'fake_favorites.repository.dart';
import 'fake_library.repository.dart';
import 'fake_library_preferences.dart';
import 'fake_new_content.repository.dart';
import 'fake_play_history.repository.dart';
import 'fake_playback_preferences.dart';
import 'fake_pro.repository.dart';
import 'fake_track_picker.dart';
import 'fake_welcome_preferences.dart';

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

/// Accounts in memory. Signed out unless [repository] says otherwise:
/// accounts are optional, so a test that is not about them never needs one.
Override _fakeAuth(FakeAuthRepository? repository) {
  final FakeAuthRepository fake = repository ?? FakeAuthRepository();
  addTearDown(fake.dispose);

  return authRepositoryProvider.overrideWithValue(fake);
}

/// Pro in memory. Not for sale unless [repository] says otherwise, which is
/// how a build without RevenueCat's keys behaves: nothing is locked.
Override _fakePro(FakeProRepository? repository) {
  final FakeProRepository fake =
      repository ?? FakeProRepository(available: false);
  addTearDown(fake.dispose);

  return proRepositoryProvider.overrideWithValue(fake);
}

/// The first launch is behind every test unless it says otherwise, so the
/// welcome does not cover the player.
Override _fakeWelcome(FakeWelcomePreferences? preferences) {
  return welcomePreferencesProvider.overrideWithValue(
    preferences ?? FakeWelcomePreferences(),
  );
}

/// The listener's library and the file picker, in memory, for the same
/// reason as the favourites: no widget test opens a database or a dialog
/// it cannot answer.
List<Override> _fakeLibrary(
  FakeLibraryRepository? library,
  FakeTrackPicker? picker, [
  FakePlayHistoryRepository? playHistory,
  FakeNewContentRepository? newContent,
]) {
  final FakeLibraryRepository fake = library ?? FakeLibraryRepository();
  addTearDown(fake.dispose);
  final FakePlayHistoryRepository history =
      playHistory ?? FakePlayHistoryRepository();
  addTearDown(history.dispose);
  final FakeNewContentRepository seen =
      newContent ?? FakeNewContentRepository();
  addTearDown(seen.dispose);

  return <Override>[
    libraryRepositoryProvider.overrideWithValue(fake),
    trackPickerProvider.overrideWithValue(picker ?? FakeTrackPicker()),
    libraryPreferencesProvider.overrideWithValue(FakeLibraryPreferences()),
    playbackPreferencesProvider.overrideWithValue(FakePlaybackPreferences()),
    displayPreferencesProvider.overrideWithValue(FakeDisplayPreferences()),
    playHistoryRepositoryProvider.overrideWithValue(history),
    newContentRepositoryProvider.overrideWithValue(seen),
  ];
}

/// Reduced motion, as a listener can ask for in the system settings.
///
/// The playing track's bars bounce for as long as it plays, and an endless
/// animation never lets `pumpAndSettle` return. Tests that are about the
/// motion pump an app of their own.
Widget _stillMotion(BuildContext context, Widget? child) => MediaQuery(
  data: MediaQuery.of(context).copyWith(disableAnimations: true),
  child: child!,
);

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
    FakePlayHistoryRepository? playHistory,
    FakeNewContentRepository? newContent,
    FakeAuthRepository? auth,
    FakeProRepository? pro,
    FakeWelcomePreferences? welcome,
    Duration? Function(int retryCount, Object error)? retry,
  }) {
    return pumpWidget(
      ProviderScope(
        overrides: <Override>[
          _fakeFavorites(favorites),
          ..._fakeLibrary(library, picker, playHistory, newContent),
          _fakeAuth(auth),
          _fakePro(pro),
          _fakeWelcome(welcome),
          ...overrides,
        ],
        retry: retry ?? (_, _) => null,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          builder: _stillMotion,
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
    FakePlayHistoryRepository? playHistory,
    FakeNewContentRepository? newContent,
    FakeAuthRepository? auth,
    FakeProRepository? pro,
    FakeWelcomePreferences? welcome,
    Duration? Function(int retryCount, Object error)? retry,
  }) {
    return pumpWidget(
      ProviderScope(
        overrides: <Override>[
          _fakeFavorites(favorites),
          ..._fakeLibrary(library, picker, playHistory, newContent),
          _fakeAuth(auth),
          _fakePro(pro),
          _fakeWelcome(welcome),
          ...overrides,
        ],
        retry: retry ?? (_, _) => null,
        child: MaterialApp.router(
          theme: theme ?? ThemeData.dark(useMaterial3: true),
          builder: _stillMotion,
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
  await tester.tap(find.byType(MenuButton));
  await tester.pumpAndSettle();
}

/// Taps a row on the open room page, scrolling to it first.
///
/// The room, the sleep timer and the settings used to be pages of their
/// own behind a row; they are sections of the page now, already open, so
/// for those this only scrolls their heading into view.
Future<void> tapMenuEntry(WidgetTester tester, String label) async {
  const Map<String, String> sections = <String, String>{
    'Change room': 'Room',
    'Sleep timer': 'Sleep timer',
    'Settings': 'Settings',
  };
  final String? section = sections[label];
  final Finder target = find.text(section ?? label).first;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  if (section == null) {
    await tester.tap(target);
    await tester.pumpAndSettle();
  }
}

/// Opens the library from the right of the transport.
Future<void> openLibrary(WidgetTester tester) async {
  // By type: its label also says when there are new tracks (#148).
  await tester.tap(find.byType(LibraryButton));
  await tester.pumpAndSettle();
}

/// Taps one of the library's filters, found by name.
Future<void> tapPill(WidgetTester tester, String label) async {
  final Finder pill = find.byWidgetPredicate(
    (Widget w) => w is ChoiceChip && w.tooltip == label,
  );
  await tester.ensureVisible(pill);
  await tester.pumpAndSettle();
  await tester.tap(pill);
  await tester.pumpAndSettle();
}

/// Opens the favourites, pinned on top of the library's overview.
Future<void> openFavorites(WidgetTester tester) async {
  final Finder all = find.byTooltip('All');
  if (all.evaluate().isNotEmpty) {
    await tester.tap(all);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.widgetWithText(InkWell, 'Favorites'));
  await tester.pumpAndSettle();
}

/// Opens the queue, from its button beside the library's.
Future<void> openQueue(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Queue'));
  await tester.pumpAndSettle();
}
