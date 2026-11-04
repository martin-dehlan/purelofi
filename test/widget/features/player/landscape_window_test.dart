import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/presentation/screens/player.screen.dart';
import 'package:purelofi/features/player/presentation/widgets/player_controls.widget.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/fake_screen_awake.dart';
import '../../../helpers/mock_repositories.dart';
import '../../../helpers/pump_routed_app.dart';

/// Landscape, tablets and window mode (#149).
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
    when(
      () => mockRepo.getScenes(),
    ).thenAnswer((_) async => <SceneEntity>[makeScene('scene-a')]);
  });

  List<Override> overrides({ScreenAwakeOverride? awake}) => <Override>[
    contentRepositoryProvider.overrideWithValue(mockRepo),
    audioPlayerServiceProvider.overrideWithValue(fakeAudio),
    sceneVideoBuilderProvider.overrideWithValue(
      (SceneEntity scene) => const SizedBox.shrink(),
    ),
  ];

  for (final (String name, Size size) in <(String, Size)>[
    ('a phone on its side', const Size(2622, 1206)),
    ('a tablet upright', const Size(2048, 2732)),
    ('a tablet on its side', const Size(2732, 2048)),
  ]) {
    testWidgets('the player and the room page hold together on $name', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = size.width > 2500 && size.height < 1300
          ? 3
          : 2;
      addTearDown(tester.view.reset);
      await tester.pumpRoutedApp(overrides: overrides());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await openMenu(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('window mode: the room alone, the screen on, a tap for the way '
      'out', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpRoutedApp(overrides: overrides());
    await tester.pumpAndSettle();
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(PlayerScreen)),
    );
    final FakeScreenAwake awake =
        container.read(screenAwakeProvider) as FakeScreenAwake;

    await openMenu(tester);
    await tester.ensureVisible(find.text('Window mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Window mode'));
    // The sheet closes; settled by time, not pumpAndSettle.
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(awake.awake, isTrue);
    // The controls are gone and stay gone on a tap.
    AnimatedOpacity controls() => tester.widget<AnimatedOpacity>(
      find
          .ancestor(
            of: find.byType(PlayerControls),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    );
    expect(controls().opacity, 0);

    await tester.tapAt(const Offset(200, 300));
    await tester.pump();
    expect(find.text('Leave window mode'), findsOneWidget);
    expect(controls().opacity, 0);

    await tester.tap(find.text('Leave window mode'));
    await tester.pump(const Duration(milliseconds: 300));
    // Let the controls' own countdown run out before the test ends.
    await tester.pump(const Duration(seconds: 5));
    expect(awake.awake, isFalse);
    expect(find.text('Leave window mode'), findsNothing);
  });
}

/// Kept for symmetry with other helpers; the default fake is used.
typedef ScreenAwakeOverride = Override;
