import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/common/widgets/app_icon.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/menu_button.widget.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/presentation/widgets/settings_sheet.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/sleep_timer_sheet.widget.dart';

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

  group('sleep timer', () {
    testWidgets('is off until set, then says when it stops', (tester) async {
      await start(tester);
      expect(find.text('Off'), findsOneWidget);

      await tapMenuEntry(tester, 'Sleep timer');
      expect(find.byType(SleepTimerSheet), findsOneWidget);
      expect(find.text('Turn off'), findsNothing);

      await tester.tap(find.text('30 minutes'));
      await tester.pumpAndSettle();
      await openMenu(tester);

      expect(find.textContaining('Stops at'), findsOneWidget);

      await tapMenuEntry(tester, 'Sleep timer');
      await tapMenuEntry(tester, 'Turn off');
      await openMenu(tester);

      expect(find.text('Off'), findsOneWidget);
    });
  });

  group('settings', () {
    testWidgets('hiding the controls can be turned off', (tester) async {
      await start(tester);
      await tapMenuEntry(tester, 'Settings');
      expect(find.byType(SettingsSheet), findsOneWidget);

      final Finder toggle = find.byType(Switch);
      expect(tester.widget<Switch>(toggle).value, isTrue);

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(toggle).value, isFalse);
    });

    testWidgets('says what the saved files take, and clears them', (
      tester,
    ) async {
      await start(tester);
      await tapMenuEntry(tester, 'Settings');

      expect(find.text('84 MB on this phone'), findsOneWidget);

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(cache.cleared, isTrue);
      expect(find.text('0 MB on this phone'), findsOneWidget);
    });
  });

  test('sizes read in whole megabytes, then gigabytes', () {
    expect(SettingsSheet.sizeLabel(84 * 1024 * 1024), '84 MB');
    expect(SettingsSheet.sizeLabel(1288490189), '1.2 GB');
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
