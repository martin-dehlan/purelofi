import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/presentation/widgets/waveform.widget.dart';

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
    when(() => mockRepo.getTracks()).thenAnswer(
      (_) async => <TrackEntity>[makeTrack('a'), makeTrack('b')],
    );
    when(
      () => mockRepo.getScenes(),
    ).thenAnswer((_) async => <SceneEntity>[makeScene('scene-a')]);
  });

  List<Override> overrides() => <Override>[
    contentRepositoryProvider.overrideWithValue(mockRepo),
    audioPlayerServiceProvider.overrideWithValue(fakeAudio),
    sceneVideoBuilderProvider.overrideWithValue(
      (SceneEntity scene) => const SizedBox.shrink(),
    ),
  ];

  group('waveform', () {
    test('the same track always draws the same bars', () {
      expect(Waveform.barsFor('track-a'), Waveform.barsFor('track-a'));
      expect(
        Waveform.barsFor('track-a'),
        isNot(Waveform.barsFor('track-b')),
        reason: 'two tracks should not look identical',
      );
    });

    test('every bar stays inside the frame', () {
      for (final double bar in Waveform.barsFor('track-a')) {
        expect(bar, inInclusiveRange(0.15, 1.0));
      }
    });

    testWidgets('dragging it seeks', (tester) async {
      await tester.pumpRoutedApp(overrides: overrides());
      await tester.pumpAndSettle();

      // The player has to know how long the track is before seeking means
      // anything.
      fakeAudio.durationController.add(const Duration(minutes: 2));
      // Stream delivery is asynchronous; one frame is not enough.
      await tester.pumpAndSettle();

      final Rect wave = tester.getRect(find.byType(Waveform));
      await tester.tapAt(Offset(wave.left + wave.width * 0.5, wave.center.dy));
      await tester.pumpAndSettle();

      expect(fakeAudio.seeks, hasLength(1));
      expect(
        fakeAudio.seeks.single.inSeconds,
        closeTo(60, 3),
        reason: 'tapping the middle should land near the middle',
      );
    });

    testWidgets('does nothing while the length is unknown', (tester) async {
      await tester.pumpRoutedApp(overrides: overrides());
      await tester.pumpAndSettle();

      final Rect wave = tester.getRect(find.byType(Waveform));
      await tester.tapAt(wave.center);
      await tester.pumpAndSettle();

      expect(fakeAudio.seeks, isEmpty);
    });
  });

  group('transport', () {
    testWidgets('skip plays a different track', (tester) async {
      await tester.pumpRoutedApp(overrides: overrides());
      await tester.pumpAndSettle();

      final int before = fakeAudio.playedTracks.length;
      await tester.tap(find.bySemanticsLabel('Next track'));
      await tester.pumpAndSettle();

      expect(fakeAudio.playedTracks, hasLength(before + 1));
    });

    testWidgets('back to the start seeks to zero, it does not skip', (
      tester,
    ) async {
      await tester.pumpRoutedApp(overrides: overrides());
      await tester.pumpAndSettle();

      final int before = fakeAudio.playedTracks.length;
      await tester.tap(find.bySemanticsLabel('Start over'));
      await tester.pumpAndSettle();

      expect(fakeAudio.seeks, <Duration>[Duration.zero]);
      expect(
        fakeAudio.playedTracks,
        hasLength(before),
        reason: 'there is no history to step back through',
      );
    });

    testWidgets('the clock follows the position', (tester) async {
      await tester.pumpRoutedApp(overrides: overrides());
      await tester.pumpAndSettle();

      fakeAudio.positionController.add(const Duration(seconds: 75));
      await tester.pumpAndSettle();

      expect(find.text('1:15'), findsOneWidget);
    });
  });
}
