import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/app.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';

import '../helpers/fake_audio_player.service.dart';
import '../helpers/mock_repositories.dart';
import '../helpers/pump_routed_app.dart';

/// The guardrails of the accessibility pass (#153): every screen keeps tap
/// targets a finger can hit, names on everything tappable, readable
/// contrast, and holds together at twice the text size.
void main() {
  late MockContentRepository mockRepo;
  late FakeAudioPlayerService fakeAudio;

  setUp(() {
    mockRepo = MockContentRepository();
    fakeAudio = FakeAudioPlayerService();
    addTearDown(fakeAudio.dispose);
    when(() => mockRepo.getTracks()).thenAnswer(
      (_) async => <TrackEntity>[makeTrack('a', title: 'Dusk Tape')],
    );
    when(() => mockRepo.getScenes()).thenAnswer(
      (_) async => <SceneEntity>[
        makeScene('s1'),
        makeScene('s2', title: 'Snow Cabin'),
      ],
    );
  });

  List<Override> overrides() => <Override>[
    contentRepositoryProvider.overrideWithValue(mockRepo),
    audioPlayerServiceProvider.overrideWithValue(fakeAudio),
    sceneVideoBuilderProvider.overrideWithValue(
      (SceneEntity scene) => const SizedBox.shrink(),
    ),
  ];

  Future<void> open(WidgetTester tester, String where) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpRoutedApp(overrides: overrides(), theme: appTheme);
    await tester.pumpAndSettle();
    if (where == 'room page') await openMenu(tester);
    if (where == 'library') await openLibrary(tester);
  }

  for (final String where in <String>['player', 'room page', 'library']) {
    testWidgets('the $where meets the platform guidelines', (tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await open(tester, where);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });
  }

  for (final String where in <String>['player', 'room page', 'library']) {
    testWidgets('the $where holds together at twice the text size', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await open(tester, where);

      // An overflow is reported as an exception; none may be left.
      expect(tester.takeException(), isNull);
    });
  }

  for (final String where in <String>['player', 'room page', 'library']) {
    testWidgets('the $where holds together in German (#140)', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpRoutedApp(
        overrides: overrides(),
        theme: appTheme,
        locale: const Locale('de'),
      );
      await tester.pumpAndSettle();
      if (where == 'room page') await openMenu(tester);
      if (where == 'library') await openLibrary(tester);

      expect(tester.takeException(), isNull);
    });
  }
}
