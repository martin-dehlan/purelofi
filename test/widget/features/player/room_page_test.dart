import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/common/widgets/app_icon.widget.dart';
import 'package:purelofi/common/widgets/menu_row.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/focus_timer_card.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/menu_button.widget.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/focus_session.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/auth/presentation/widgets/account_sheet.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/room_page.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/scene_strip.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/settings_section.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/sleep_timer_slider.widget.dart';
import 'package:purelofi/l10n/l10n.dart';

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

  /// Within the sleep timer: the sound card and the focus timer have a
  /// slider and an "Off" of their own.
  Finder inTimer(Finder finder) =>
      find.descendant(of: find.byType(SleepTimerSlider), matching: finder);

  Finder inFocus(Finder finder) =>
      find.descendant(of: find.byType(FocusTimerCard), matching: finder);

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
  Future<void> slideTo(WidgetTester tester, double fraction) async {
    final Finder slider = inTimer(find.byType(Slider));
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();
    final Rect box = tester.getRect(slider);
    // The track sits inset from the box by the thumb's reach.
    final double inset = box.height / 2;
    final Offset from = Offset(box.left + inset, box.center.dy);
    final Offset to = Offset(
      box.left + inset + (box.width - 2 * inset) * fraction,
      box.center.dy,
    );
    final TestGesture gesture = await tester.startGesture(from);
    await gesture.moveTo(to);
    await gesture.up();
    await tester.pumpAndSettle();
  }

  double sliderValue(WidgetTester tester) =>
      tester.widget<Slider>(inTimer(find.byType(Slider))).value;

  testWidgets('one page with the room, the timer and the settings open', (
    tester,
  ) async {
    await start(tester);

    expect(onPage(find.byType(SceneStrip)), findsOneWidget);
    expect(onPage(find.byType(SleepTimerSlider)), findsOneWidget);
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

    await slideTo(tester, 0.25);

    expect(tester.getSize(find.byType(RoomPage)).height, page);
  });

  group('sleep timer', () {
    testWidgets('is off until dragged, then says when it stops', (
      tester,
    ) async {
      await start(tester);
      expect(sliderValue(tester), 0);
      expect(inTimer(find.text('Off')), findsOneWidget);
      expect(find.textContaining('Stops at'), findsNothing);

      // A quarter of two hours.
      await slideTo(tester, 0.25);

      expect(inTimer(find.text('30 min')), findsOneWidget);
      expect(find.textContaining('Stops at'), findsOneWidget);
      // The page stays open.
      expect(find.byType(RoomPage), findsOneWidget);

      // Past the left end, so the thumb lands on off for sure.
      await slideTo(tester, -0.2);

      expect(sliderValue(tester), 0);
      expect(find.textContaining('Stops at'), findsNothing);
    });

    testWidgets('with nothing playing, the end of a track sets nothing', (
      tester,
    ) async {
      await start(tester);

      await tapMenuEntry(tester, 'End of track');

      expect(sliderValue(tester), 0);
      expect(find.textContaining('Stops at'), findsNothing);
    });

    test('lengths read the way people say them', () async {
      final AppLocalizations en = await AppLocalizations.delegate.load(
        const Locale('en'),
      );
      expect(SleepTimerSlider.lengthLabel(en, 0), 'Off');
      expect(SleepTimerSlider.lengthLabel(en, 45), '45 min');
      expect(SleepTimerSlider.lengthLabel(en, 60), '1 h');
      expect(SleepTimerSlider.lengthLabel(en, 90), '1 h 30');
      expect(SleepTimerSlider.lengthLabel(en, 65), '1 h 05');

      final AppLocalizations de = await AppLocalizations.delegate.load(
        const Locale('de'),
      );
      expect(SleepTimerSlider.lengthLabel(de, 0), 'Aus');
      expect(SleepTimerSlider.lengthLabel(de, 90), '1 Std. 30');
    });
  });

  group('focus timer (#137)', () {
    testWidgets('plans are tiles; running, it counts down until stopped', (
      tester,
    ) async {
      await start(tester);
      expect(
        inFocus(find.text('25 / 5 min', findRichText: true)),
        findsOneWidget,
      );
      expect(inFocus(find.byType(LinearProgressIndicator)), findsNothing);

      await tapChip(
        tester,
        inFocus(find.text('25 / 5 min', findRichText: true)),
      );

      // The count, the line under it and the bar.
      // The clock is real here, so a slow run may already read 24:59.
      final Finder count = find.textContaining(RegExp(r'^2[45]:\d\d$'));
      expect(inFocus(count), findsOneWidget);
      expect(inFocus(find.byType(LinearProgressIndicator)), findsOneWidget);
      // On the page, and on the player behind it.
      expect(find.textContaining('Focus until'), findsWidgets);
      // Under the gear too.
      expect(
        find.descendant(of: find.byType(MenuButton), matching: count),
        findsOneWidget,
      );

      await tapChip(tester, inFocus(find.widgetWithText(ActionChip, 'Off')));

      expect(find.textContaining('Focus until'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(MenuButton),
          matching: find.textContaining(':'),
        ),
        findsNothing,
      );
    });

    test('what is left reads in minutes and seconds, rounded up', () {
      final DateTime now = DateTime(2026, 11, 5, 9);
      final FocusSession session = FocusSession.start(FocusPlan.classic, now);

      expect(FocusTimerCard.remaining(session, now), '25:00');
      expect(
        FocusTimerCard.remaining(
          session,
          now.add(const Duration(minutes: 1, milliseconds: 500)),
        ),
        '24:00',
      );
      expect(
        FocusTimerCard.remaining(session, now.add(const Duration(hours: 1))),
        '0:00',
      );
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

      // The saved files' Clear, not the listening history's.
      await tapChip(
        tester,
        find.descendant(
          of: find.widgetWithText(MenuRow, 'Saved music and rooms'),
          matching: find.widgetWithText(TextButton, 'Clear'),
        ),
      );

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
