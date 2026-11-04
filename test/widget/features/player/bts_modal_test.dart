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

/// Deep links only carry UUIDs (AppRoutes.trackIdFrom), so the track has one.
const String trackId = '0a000000-0000-4000-8000-000000000001';

void main() {
  late MockContentRepository mockRepo;
  late FakeAudioPlayerService fakeAudio;

  TrackEntity trackWithBts() => makeTrack(
    trackId,
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

  group('a track without footage', () {
    testWidgets('a deep link to it still explains itself', (tester) async {
      // Nothing stops someone opening purelofi://app/track/<id> for a track
      // that was never filmed, so the modal keeps its message.
      when(
        () => mockRepo.getTrackById(trackId),
      ).thenAnswer((_) async => makeTrack(trackId, title: 'No Clip Yet'));

      await tester.pumpRoutedApp(
        initialRoute: '/track/$trackId',
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
        () => mockRepo.getTrackById(trackId),
      ).thenAnswer((_) async => trackWithBts());

      await tester.pumpRoutedApp(
        initialRoute: '/track/$trackId',
        overrides: overrides(),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BtsModal), findsOneWidget);
      expect(find.text('bts https://example.com/a-bts.mp4'), findsOneWidget);
    });

    testWidgets('an unknown track id just opens the player', (tester) async {
      const String unknown = '0a000000-0000-4000-8000-0000000000ff';
      when(() => mockRepo.getTrackById(unknown)).thenAnswer((_) async => null);

      await tester.pumpRoutedApp(
        initialRoute: '/track/$unknown',
        overrides: overrides(),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BtsModal), findsNothing);
    });

    testWidgets('an id that is not a UUID never reaches the repository', (
      tester,
    ) async {
      await tester.pumpRoutedApp(
        initialRoute: '/track/nope',
        overrides: overrides(),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BtsModal), findsNothing);
      verifyNever(() => mockRepo.getTrackById(any()));
    });
  });
}
