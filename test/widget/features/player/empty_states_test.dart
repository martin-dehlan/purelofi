import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/common/errors/app_error.dart';
import 'package:purelofi/common/widgets/empty_state.widget.dart';
import 'package:purelofi/common/widgets/error_state.widget.dart';
import 'package:purelofi/common/widgets/pixel_icon.widget.dart';
import 'package:purelofi/common/utils/app_assets.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/presentation/widgets/player_controls.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/scene_background.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/scene_switcher.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/scene_switcher_sheet.widget.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/mock_repositories.dart';
import '../../../helpers/pump_routed_app.dart';

void main() {
  late MockContentRepository mockRepo;
  late FakeAudioPlayerService fakeAudio;

  setUp(() {
    mockRepo = MockContentRepository();
    fakeAudio = FakeAudioPlayerService();
    addTearDown(fakeAudio.dispose);
  });

  List<Override> overrides() => <Override>[
    contentRepositoryProvider.overrideWithValue(mockRepo),
    audioPlayerServiceProvider.overrideWithValue(fakeAudio),
    sceneVideoBuilderProvider.overrideWithValue(
      (SceneEntity scene) => const SizedBox.shrink(),
    ),
  ];

  group('no scenes', () {
    testWidgets('says so instead of showing an unexplained black screen', (
      tester,
    ) async {
      when(
        () => mockRepo.getScenes(),
      ).thenAnswer((_) async => <SceneEntity>[]);
      when(() => mockRepo.getTracks()).thenAnswer((_) async => <TrackEntity>[]);

      await tester.pumpProviderApp(
        child: const SceneBackground(),
        overrides: overrides(),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No scenes yet.'), findsOneWidget);
    });

    testWidgets('the switcher sheet says so too', (tester) async {
      when(
        () => mockRepo.getScenes(),
      ).thenAnswer((_) async => <SceneEntity>[]);
      when(() => mockRepo.getTracks()).thenAnswer((_) async => <TrackEntity>[]);

      await tester.pumpProviderApp(
        child: const SceneSwitcherSheet(),
        overrides: overrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('No scenes to switch to yet.'), findsOneWidget);
    });
  });

  group('no tracks', () {
    testWidgets('replaces the play button with a plain explanation', (
      tester,
    ) async {
      when(() => mockRepo.getTracks()).thenAnswer((_) async => <TrackEntity>[]);

      await tester.pumpProviderApp(
        child: const PlayerControls(),
        overrides: overrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('No tracks yet.'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (Widget w) => w is PixelIcon && w.asset == AppAssets.playIcon,
        ),
        findsNothing,
        reason: 'an inert play button looks like a bug',
      );
    });

    testWidgets('the scene switcher stays reachable', (tester) async {
      when(() => mockRepo.getTracks()).thenAnswer((_) async => <TrackEntity>[]);
      when(
        () => mockRepo.getScenes(),
      ).thenAnswer((_) async => <SceneEntity>[makeScene('scene-a')]);

      await tester.pumpProviderApp(
        child: const PlayerControls(),
        overrides: overrides(),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SceneSwitcher), findsOneWidget);
    });

    testWidgets('a track list that loads normally still shows the button', (
      tester,
    ) async {
      when(
        () => mockRepo.getTracks(),
      ).thenAnswer((_) async => <TrackEntity>[makeTrack('a')]);

      await tester.pumpProviderApp(
        child: const PlayerControls(),
        overrides: overrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('No tracks yet.'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (Widget w) => w is PixelIcon && w.asset == AppAssets.playIcon,
        ),
        findsOneWidget,
      );
    });
  });

  group('empty is not the same as broken', () {
    testWidgets('a failure still shows the error state, not the empty one', (
      tester,
    ) async {
      when(() => mockRepo.getScenes()).thenThrow(const AppError.network());
      when(() => mockRepo.getTracks()).thenAnswer((_) async => <TrackEntity>[]);

      await tester.pumpProviderApp(
        child: const SceneBackground(),
        overrides: overrides(),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.byType(EmptyState), findsNothing);
    });
  });
}
