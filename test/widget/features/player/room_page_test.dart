import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/common/widgets/app_icon.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/menu_button.widget.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/auth/presentation/widgets/account_sheet.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/room_page.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/scene_strip.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/settings_section.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/sleep_timer_slider.widget.dart';

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

  Future<void> slideTo(WidgetTester tester, double fraction) async {
    final Finder slider = onPage(find.byType(Slider));
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
      tester.widget<Slider>(onPage(find.byType(Slider))).value;

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
      expect(onPage(find.text('Off')), findsOneWidget);
      expect(find.textContaining('Stops at'), findsNothing);

      // A quarter of two hours.
      await slideTo(tester, 0.25);

      expect(onPage(find.text('30 min')), findsOneWidget);
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

    test('lengths read the way people say them', () {
      expect(SleepTimerSlider.lengthLabel(0), 'Off');
      expect(SleepTimerSlider.lengthLabel(45), '45 min');
      expect(SleepTimerSlider.lengthLabel(60), '1 h');
      expect(SleepTimerSlider.lengthLabel(90), '1 h 30');
      expect(SleepTimerSlider.lengthLabel(65), '1 h 05');
    });
  });

  group('settings', () {
    testWidgets('hiding the controls can be turned off', (tester) async {
      await start(tester);
      await tapMenuEntry(tester, 'Settings');

      final Finder toggle = find.byType(Switch);
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(toggle).value, isTrue);

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(toggle).value, isFalse);
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
