import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/common/analytics/analytics.provider.dart';
import 'package:purelofi/common/routes/app_router.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/presentation/screens/player.screen.dart';
import 'package:purelofi/features/player/presentation/widgets/bts_modal.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/settings_button.widget.dart';

import '../test/helpers/fake_audio_player.service.dart';
import '../test/helpers/mock_repositories.dart';
import '../test/helpers/recording_analytics.service.dart';

/// The whole app on a real device, with the network and the platform players
/// replaced. Run with: `flutter test integration_test/`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockContentRepository mockRepo;
  late FakeAudioPlayerService fakeAudio;
  late RecordingAnalyticsService analytics;

  setUp(() {
    mockRepo = MockContentRepository();
    fakeAudio = FakeAudioPlayerService();
    analytics = RecordingAnalyticsService();
    addTearDown(fakeAudio.dispose);

    when(() => mockRepo.getScenes()).thenAnswer(
      (_) async => <SceneEntity>[
        makeScene('scene-a', title: 'Rainy Room').copyWith(sortOrder: 1),
        makeScene('scene-b', title: 'Night Bus').copyWith(sortOrder: 2),
      ],
    );
    when(() => mockRepo.getTracks()).thenAnswer(
      (_) async => <TrackEntity>[
        makeTrack(
          'track-1',
          title: 'Dusk Tape',
        ).copyWith(btsVideoUrl: 'https://example.com/bts.mp4'),
        makeTrack('track-2', title: 'Late Bus'),
      ],
    );
  });

  Future<void> launchApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          contentRepositoryProvider.overrideWithValue(mockRepo),
          audioPlayerServiceProvider.overrideWithValue(fakeAudio),
          analyticsServiceProvider.overrideWithValue(analytics),
          sceneVideoBuilderProvider.overrideWithValue(
            (SceneEntity scene) => Text('scene ${scene.id}'),
          ),
          btsVideoBuilderProvider.overrideWithValue(
            (String url) => const SizedBox.shrink(),
          ),
        ],
        child: Consumer(
          builder: (_, WidgetRef ref, _) => MaterialApp.router(
            theme: ThemeData.dark(useMaterial3: true),
            routerConfig: ref.watch(appRouterProvider),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the app opens on the player and starts a track', (tester) async {
    await launchApp(tester);

    expect(find.byType(PlayerScreen), findsOneWidget);
    expect(find.text('scene scene-a'), findsOneWidget);
    expect(fakeAudio.playedTracks, hasLength(1));
    expect(analytics.eventNames, contains('track_played'));
  });

  testWidgets('a finished track is followed by another one', (tester) async {
    await launchApp(tester);
    final String first = fakeAudio.playedTracks.single.id;

    fakeAudio.emitNextRequest();
    await tester.pumpAndSettle();

    expect(fakeAudio.playedTracks, hasLength(2));
    expect(fakeAudio.playedTracks.last.id, isNot(first));
  });

  testWidgets('switching the scene leaves the music alone', (tester) async {
    await launchApp(tester);
    final int playedBefore = fakeAudio.playedTracks.length;

    await tester.tap(find.byType(SettingsButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change scene'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Night Bus'));
    await tester.pumpAndSettle();

    expect(find.text('scene scene-b'), findsOneWidget);
    expect(fakeAudio.playedTracks, hasLength(playedBefore));
    expect(fakeAudio.pauseCalls, 0);
  });

  testWidgets('the footage plays, then the music resumes', (tester) async {
    await launchApp(tester);

    await tester.tap(find.byType(SettingsButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Behind the scenes'));
    await tester.pumpAndSettle();
    expect(find.byType(BtsModal), findsOneWidget);
    expect(fakeAudio.pauseCalls, 1);

    Navigator.of(tester.element(find.byType(BtsModal))).pop();
    await tester.pumpAndSettle();

    expect(find.byType(BtsModal), findsNothing);
    expect(fakeAudio.playCalls, 1);
  });

  testWidgets('the chrome hides itself and comes back on a tap', (
    tester,
  ) async {
    await launchApp(tester);

    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(find.byType(SettingsButton).hitTestable(), findsNothing);

    await tester.tapAt(tester.getCenter(find.byType(PlayerScreen)));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsButton).hitTestable(), findsOneWidget);
  });
}
