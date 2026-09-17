import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/presentation/screens/player.screen.dart';
import 'package:purelofi/features/player/presentation/widgets/player_controls.widget.dart';

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
    sceneVideoBuilderProvider.overrideWithValue(
      (SceneEntity scene) => const SizedBox.shrink(),
    ),
  ];

  double controlsOpacity(WidgetTester tester) {
    final AnimatedOpacity opacity = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.byType(PlayerControls),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    return opacity.opacity;
  }

  testWidgets('starts the stream once the tracks load', (tester) async {
    await tester.pumpProviderApp(
      child: const PlayerScreen(),
      overrides: overrides(),
    );
    await tester.pump();
    await tester.pump();

    expect(fakeAudio.playedTracks.single.id, 'a');
  });

  testWidgets('shows the controls when it opens', (tester) async {
    await tester.pumpProviderApp(
      child: const PlayerScreen(),
      overrides: overrides(),
    );
    await tester.pump();

    expect(controlsOpacity(tester), 1);
  });

  testWidgets('hides the controls after 4s of stillness', (tester) async {
    await tester.pumpProviderApp(
      child: const PlayerScreen(),
      overrides: overrides(),
    );
    await tester.pump();

    await tester.pump(const Duration(seconds: 4));
    await tester.pump();

    expect(controlsOpacity(tester), 0);
  });

  testWidgets('a tap brings them back', (tester) async {
    await tester.pumpProviderApp(
      child: const PlayerScreen(),
      overrides: overrides(),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(controlsOpacity(tester), 0);

    await tester.tapAt(tester.getCenter(find.byType(PlayerScreen)));
    await tester.pump();

    expect(controlsOpacity(tester), 1);
  });

  testWidgets('a tap on hidden controls does not toggle playback', (
    tester,
  ) async {
    await tester.pumpProviderApp(
      child: const PlayerScreen(),
      overrides: overrides(),
    );
    await tester.pump();
    await tester.pump();
    final int playedBefore = fakeAudio.playedTracks.length;

    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    await tester.tapAt(tester.getCenter(find.byType(PlayerScreen)));
    await tester.pump();

    expect(fakeAudio.pauseCalls, 0);
    expect(fakeAudio.playedTracks, hasLength(playedBefore));
  });
}
