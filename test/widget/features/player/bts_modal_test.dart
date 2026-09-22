import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/presentation/widgets/bts_modal.widget.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/mock_repositories.dart';
import '../../../helpers/pump_routed_app.dart';

void main() {
  late MockContentRepository mockRepo;
  late FakeAudioPlayerService fakeAudio;

  TrackEntity trackWithBts() => makeTrack(
    'a',
    title: 'Dusk Tape',
  ).copyWith(btsVideoUrl: 'https://example.com/a-bts.mp4');

  setUp(() {
    mockRepo = MockContentRepository();
    fakeAudio = FakeAudioPlayerService();
    addTearDown(fakeAudio.dispose);
    when(
      () => mockRepo.getScenes(),
    ).thenAnswer((_) async => <SceneEntity>[makeScene('scene-1')]);
    when(
      () => mockRepo.getTracks(),
    ).thenAnswer((_) async => <TrackEntity>[trackWithBts()]);
  });

  List<Override> overrides() => <Override>[
    contentRepositoryProvider.overrideWithValue(mockRepo),
    audioPlayerServiceProvider.overrideWithValue(fakeAudio),
    sceneVideoBuilderProvider.overrideWithValue(
      (SceneEntity scene) => const SizedBox.shrink(),
    ),
    btsVideoBuilderProvider.overrideWithValue((String url) => Text('bts $url')),
  ];

  group('from the player chrome', () {
    testWidgets('opens as a bottom sheet and plays the clip', (tester) async {
      await tester.pumpRoutedApp(overrides: overrides());
      await tester.pumpAndSettle();

      await openMenu(tester);
      await tapMenuEntry(tester, 'Behind the scenes');

      expect(find.byType(BtsModal), findsOneWidget);
      expect(find.text('bts https://example.com/a-bts.mp4'), findsOneWidget);
      expect(find.text('Dusk Tape'), findsWidgets);
    });

    testWidgets('pauses the music while the footage plays', (tester) async {
      await tester.pumpRoutedApp(overrides: overrides());
      await tester.pumpAndSettle();
      expect(fakeAudio.playedTracks, hasLength(1));

      await openMenu(tester);
      await tapMenuEntry(tester, 'Behind the scenes');

      expect(fakeAudio.pauseCalls, 1);
    });

    testWidgets('dismissing it leaves the audio playing', (tester) async {
      await tester.pumpRoutedApp(overrides: overrides());
      await tester.pumpAndSettle();

      await openMenu(tester);
      await tapMenuEntry(tester, 'Behind the scenes');
      Navigator.of(tester.element(find.byType(BtsModal))).pop();
      await tester.pumpAndSettle();

      expect(find.byType(BtsModal), findsNothing);
      expect(fakeAudio.playCalls, 1);
    });

    testWidgets('is not offered before anything is playing', (tester) async {
      when(() => mockRepo.getTracks()).thenAnswer((_) async => <TrackEntity>[]);

      await tester.pumpRoutedApp(overrides: overrides());
      await tester.pumpAndSettle();

      await openMenu(tester);
      expect(find.text('Behind the scenes'), findsNothing);
      expect(find.byType(BtsModal), findsNothing);
    });
  });

  group('a track without footage', () {
    testWidgets('shows no camera at all', (tester) async {
      when(() => mockRepo.getTracks()).thenAnswer(
        (_) async => <TrackEntity>[makeTrack('a', title: 'No Clip Yet')],
      );

      await tester.pumpRoutedApp(overrides: overrides());
      await tester.pumpAndSettle();

      await openMenu(tester);

      expect(
        find.text('Behind the scenes'),
        findsNothing,
        reason:
            'but no camera is drawn — one that opens no clip is a dead '
            'button',
      );
    });

    testWidgets('a deep link to it still explains itself', (tester) async {
      // Nothing stops someone opening purelofi://app/track/<id> for a track
      // that was never filmed, so the modal keeps its message.
      when(
        () => mockRepo.getTrackById('a'),
      ).thenAnswer((_) async => makeTrack('a', title: 'No Clip Yet'));

      await tester.pumpRoutedApp(
        initialRoute: '/track/a',
        overrides: overrides(),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No behind-the-scenes clip for this track yet.'),
        findsOneWidget,
      );
      expect(find.textContaining('bts '), findsNothing);
    });
  });

  group('deep link', () {
    testWidgets('purelofi://app/track/<id> opens that track’s clip', (
      tester,
    ) async {
      when(
        () => mockRepo.getTrackById('a'),
      ).thenAnswer((_) async => trackWithBts());

      await tester.pumpRoutedApp(
        initialRoute: '/track/a',
        overrides: overrides(),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BtsModal), findsOneWidget);
      expect(find.text('bts https://example.com/a-bts.mp4'), findsOneWidget);
    });

    testWidgets('an unknown track id just opens the player', (tester) async {
      when(() => mockRepo.getTrackById('nope')).thenAnswer((_) async => null);

      await tester.pumpRoutedApp(
        initialRoute: '/track/nope',
        overrides: overrides(),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BtsModal), findsNothing);
    });
  });
}
