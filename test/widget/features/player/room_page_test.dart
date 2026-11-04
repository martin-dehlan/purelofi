import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/common/widgets/app_icon.widget.dart';
import 'package:purelofi/common/widgets/menu_row.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/focus_timer_chips.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/menu_button.widget.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/auth/presentation/widgets/account_sheet.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/room_page.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/scene_strip.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/settings_section.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/sleep_timer_chips.widget.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/fake_media_cache.dart';
import '../../../helpers/mock_repositories.dart';
import '../../../helpers/pump_routed_app.dart';

void main() {
  late MockContentRepository mockRepo;
  late FakeAudioPlayerService fakeAudio;
  late FakeMediaCache cache;

  setUp(() {
    mockRepo = MockContentRepository();
    fakeAudio = FakeAudioPlayerService();
    addTearDown(fakeAudio.dispose);
    cache = FakeMediaCache(size: 84 * 1024 * 1024);
    when(
      () => mockRepo.getScenes(),
    ).thenAnswer((_) async => <SceneEntity>[makeScene('scene-1')]);
    when(
      () => mockRepo.getTracks(),
    ).thenAnswer((_) async => <TrackEntity>[makeTrack('a')]);
  });

  List<Override> overrides() => <Override>[
    contentRepositoryProvider.overrideWithValue(mockRepo),
    audioPlayerServiceProvider.overrideWithValue(fakeAudio),
    mediaCacheProvider.overrideWithValue(cache),
    sceneVideoBuilderProvider.overrideWithValue(
      (SceneEntity scene) => const SizedBox.shrink(),
    ),
  ];

  Future<void> start(WidgetTester tester) async {
    await tester.pumpRoutedApp(overrides: overrides());
    await tester.pumpAndSettle();
    await openMenu(tester);
  }

  Finder onPage(Finder finder) =>
      find.descendant(of: find.byType(RoomPage), matching: finder);

  /// A chip of the sleep timer; the focus timer has an "Off" of its own.
  Finder sleepChip(String label) => find.descendant(
    of: find.byType(SleepTimerChips),
    matching: find.widgetWithText(ChoiceChip, label),
  );

  ChoiceChip chip(WidgetTester tester, String label) =>
      tester.widget<ChoiceChip>(sleepChip(label));

  Finder focusChip(String label) => find.descendant(
    of: find.byType(FocusTimerChips),
    matching: find.widgetWithText(ChoiceChip, label),
  );

  Future<void> tapChip(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  /// The switch on the settings row titled [title].
  Finder toggleOf(String title) => find.descendant(
    of: find.widgetWithText(MenuRow, title),
    matching: find.byType(Switch),
  );

  testWidgets('one page with the room, the timer and the settings open', (
    tester,
  ) async {
    await start(tester);

    expect(onPage(find.byType(SceneStrip)), findsOneWidget);
    expect(onPage(find.byType(SleepTimerChips)), findsOneWidget);
    expect(onPage(find.byType(SettingsSection)), findsOneWidget);
    // Nothing to open first, and no way back that is a page of its own.
    expect(find.byTooltip('Back'), findsNothing);
  });

  testWidgets('a tap on the scene above the sheet goes back', (tester) async {
    await start(tester);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.byType(RoomPage), findsNothing);
  });

  testWidgets('a swipe down puts the page away too', (tester) async {
    await start(tester);

    await tester.fling(find.byType(AccountPanel), const Offset(0, 600), 2000);
    await tester.pumpAndSettle();

    expect(find.byType(RoomPage), findsNothing);
  });

  testWidgets('choosing something keeps the page the same height', (
    tester,
  ) async {
    await start(tester);
    final double page = tester.getSize(find.byType(RoomPage)).height;

    await tapMenuEntry(tester, '30 min');

    expect(tester.getSize(find.byType(RoomPage)).height, page);
  });

  group('sleep timer', () {
    testWidgets('is off until set, then says when it stops', (tester) async {
      await start(tester);
      expect(chip(tester, 'Off').selected, isTrue);
      expect(find.textContaining('Stops at'), findsNothing);

      await tapMenuEntry(tester, '30 min');

      expect(chip(tester, 'Off').selected, isFalse);
      expect(find.textContaining('Stops at'), findsOneWidget);
      // The page stays open.
      expect(find.byType(RoomPage), findsOneWidget);

      await tapChip(tester, sleepChip('Off'));

      expect(chip(tester, 'Off').selected, isTrue);
      expect(find.textContaining('Stops at'), findsNothing);
    });

    testWidgets('with nothing playing, the end of a track sets nothing', (
      tester,
    ) async {
      await start(tester);

      await tapMenuEntry(tester, 'End of track');

      expect(chip(tester, 'Off').selected, isTrue);
    });
  });

  group('focus timer (#137)', () {
    testWidgets('is off until a plan is picked, then says until when', (
      tester,
    ) async {
      await start(tester);
      expect(tester.widget<ChoiceChip>(focusChip('Off')).selected, isTrue);

      await tapChip(tester, focusChip('25 / 5 min'));

      expect(
        tester.widget<ChoiceChip>(focusChip('25 / 5 min')).selected,
        isTrue,
      );
      // On the page, and on the player behind it.
      expect(find.textContaining('Focus until'), findsWidgets);

      await tapChip(tester, focusChip('Off'));

      expect(find.textContaining('Focus until'), findsNothing);
    });
  });

  group('settings', () {
    testWidgets('hiding the controls can be turned off', (tester) async {
      await start(tester);
      await tapMenuEntry(tester, 'Settings');

      final Finder toggle = toggleOf('Hide controls');
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(toggle).value, isTrue);

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(toggle).value, isFalse);
    });

    testWidgets('soft transitions are on, and reach the player when '
        'turned off', (tester) async {
      await start(tester);
      await tapMenuEntry(tester, 'Settings');

      final Finder toggle = toggleOf('Soft transitions');
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(toggle).value, isTrue);

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(toggle).value, isFalse);
      expect(fakeAudio.softTransitions, isFalse);
    });

    testWidgets('says what the saved files take, and clears them', (
      tester,
    ) async {
      await start(tester);

      expect(find.text('84 MB on this phone'), findsOneWidget);

      await tapMenuEntry(tester, 'Clear');

      expect(cache.cleared, isTrue);
      expect(find.text('0 MB on this phone'), findsOneWidget);
    });
  });

  test('sizes read in whole megabytes, then gigabytes', () {
    expect(SettingsSection.sizeLabel(84 * 1024 * 1024), '84 MB');
    expect(SettingsSection.sizeLabel(1288490189), '1.2 GB');
  });

  testWidgets('the menu button is a gear', (tester) async {
    await tester.pumpRoutedApp(overrides: overrides());
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(MenuButton),
        matching: find.byWidgetPredicate(
          (Widget w) => w is AppIcon && w.glyph == AppGlyph.settings,
        ),
      ),
      findsOneWidget,
    );
  });
}
