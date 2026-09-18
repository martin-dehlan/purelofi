import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/common/errors/app_error.dart';
import 'package:purelofi/common/widgets/error_state.widget.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/presentation/screens/player.screen.dart';
import 'package:purelofi/features/player/presentation/widgets/scene_switcher.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/scene_switcher_sheet.widget.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/mock_repositories.dart';
import '../../../helpers/pump_routed_app.dart';

void main() {
  late MockContentRepository mockRepo;
  late FakeAudioPlayerService fakeAudio;

  final List<SceneEntity> scenes = <SceneEntity>[
    makeScene('scene-a', title: 'Rainy Room').copyWith(sortOrder: 1),
    makeScene('scene-b', title: 'Night Bus').copyWith(sortOrder: 2),
  ];

  setUp(() {
    mockRepo = MockContentRepository();
    fakeAudio = FakeAudioPlayerService();
    addTearDown(fakeAudio.dispose);
    when(() => mockRepo.getScenes()).thenAnswer((_) async => scenes);
    when(
      () => mockRepo.getTracks(),
    ).thenAnswer((_) async => <TrackEntity>[makeTrack('a')]);
  });

  List<Override> overrides() => <Override>[
    contentRepositoryProvider.overrideWithValue(mockRepo),
    audioPlayerServiceProvider.overrideWithValue(fakeAudio),
    sceneVideoBuilderProvider.overrideWithValue(
      (SceneEntity scene) => Text('scene ${scene.id}'),
    ),
  ];

  Future<void> openSwitcher(WidgetTester tester) async {
    await tester.pumpProviderApp(
      child: const PlayerScreen(),
      overrides: overrides(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SceneSwitcher));
    await tester.pumpAndSettle();
  }

  testWidgets('lists the active scenes in sort_order', (tester) async {
    await openSwitcher(tester);

    expect(find.byType(SceneSwitcherSheet), findsOneWidget);
    final Offset rainy = tester.getTopLeft(find.text('Rainy Room'));
    final Offset night = tester.getTopLeft(find.text('Night Bus'));
    expect(rainy.dy, lessThan(night.dy));
  });

  testWidgets('picking a scene switches the background and closes the sheet', (
    tester,
  ) async {
    await openSwitcher(tester);
    expect(find.text('scene scene-a'), findsOneWidget);

    await tester.tap(find.text('Night Bus'));
    await tester.pumpAndSettle();

    expect(find.byType(SceneSwitcherSheet), findsNothing);
    expect(find.text('scene scene-b'), findsOneWidget);
  });

  testWidgets('switching scenes leaves the audio alone', (tester) async {
    await openSwitcher(tester);
    final int playedBefore = fakeAudio.playedTracks.length;

    await tester.tap(find.text('Night Bus'));
    await tester.pumpAndSettle();

    expect(fakeAudio.playedTracks, hasLength(playedBefore));
    expect(fakeAudio.pauseCalls, 0);
    expect(fakeAudio.stopCalls, 0);
  });

  testWidgets('shows an error state when the scenes cannot be loaded', (
    tester,
  ) async {
    when(() => mockRepo.getScenes()).thenThrow(const AppError.network());

    await tester.pumpProviderApp(
      child: const SceneSwitcherSheet(),
      overrides: overrides(),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);
  });

  testWidgets('marks the scene that is already playing', (tester) async {
    await openSwitcher(tester);

    final ListTile active = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Rainy Room'),
        matching: find.byType(ListTile),
      ),
    );
    expect(active.selected, isTrue);
  });
}
