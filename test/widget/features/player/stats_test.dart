import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/listening_stats.dart';
import 'package:purelofi/features/player/domain/play_event.entity.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/presentation/widgets/recap_card.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/recap_sheet.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/room_page.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/stats_view.widget.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/fake_play_history.repository.dart';
import '../../../helpers/mock_repositories.dart';
import '../../../helpers/pump_routed_app.dart';

/// "Your week" (#151).
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
      (_) async => <SceneEntity>[makeScene('rainy', title: 'Rainy Room')],
    );
  });

  List<Override> overrides() => <Override>[
    contentRepositoryProvider.overrideWithValue(mockRepo),
    audioPlayerServiceProvider.overrideWithValue(fakeAudio),
    sceneVideoBuilderProvider.overrideWithValue(
      (SceneEntity scene) => const SizedBox.shrink(),
    ),
  ];

  Future<void> open(
    WidgetTester tester,
    FakePlayHistoryRepository history,
  ) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpRoutedApp(overrides: overrides(), playHistory: history);
    await tester.pumpAndSettle();
    await openLibrary(tester);
    // A row of the overview, under Playlists; it opens as History does.
    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();
  }

  testWidgets('a page of the library, saying how it fills while empty', (
    tester,
  ) async {
    await open(tester, FakePlayHistoryRepository());

    expect(find.byType(StatsView), findsOneWidget);
    expect(find.textContaining('Nothing heard this week'), findsOneWidget);
    expect(find.byType(RecapCard), findsNothing);
  });

  testWidgets('the week, the details and the recap, on the Stats page', (
    tester,
  ) async {
    final DateTime start = ListeningStats.weekStartOf(DateTime.now());
    await open(
      tester,
      FakePlayHistoryRepository(<PlayEventEntity>[
        PlayEventEntity(
          id: 1,
          trackId: 'a',
          source: TrackSource.catalogue,
          sceneId: 'rainy',
          startedAt: start.add(const Duration(hours: 1)),
          listenedSeconds: 95 * 60,
        ),
      ]),
    );

    expect(find.text('1 h 35 min'), findsOneWidget);
    expect(find.text('Rainy Room'), findsOneWidget);
    expect(find.text('Dusk Tape'), findsWidgets);
    // The recap card waits until the listener goes to share.
    expect(find.byType(RecapCard), findsNothing);

    final Finder share = find.widgetWithText(OutlinedButton, 'Share your week');
    await tester.ensureVisible(share);
    await tester.pumpAndSettle();
    await tester.tap(share);
    await tester.pumpAndSettle();

    expect(find.byType(RecapCard), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(RecapSheet),
        matching: find.text('Share your week'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the room page no longer carries the week', (tester) async {
    await open(tester, FakePlayHistoryRepository());
    Navigator.of(tester.element(find.byType(StatsView))).pop();
    await tester.pumpAndSettle();
    await openMenu(tester);

    expect(
      find.descendant(
        of: find.byType(RoomPage),
        matching: find.textContaining('this week'),
      ),
      findsNothing,
    );
  });

  testWidgets('the recap card fits at any width it is drawn', (tester) async {
    const ListeningStats stats = ListeningStats(
      total: Duration(hours: 12, minutes: 45),
      perDay: <Duration>[
        Duration.zero,
        Duration.zero,
        Duration.zero,
        Duration.zero,
        Duration.zero,
        Duration.zero,
        Duration.zero,
      ],
      streak: 3,
      topArtist: 'An Artist With A Rather Long Name Indeed',
    );
    for (final double width in <double>[180, 240, 360]) {
      await tester.pumpProviderApp(
        child: Center(
          child: RecapCard(
            stats: stats,
            width: width,
            room: makeScene('rainy', title: 'Rainy Room'),
            topTrack: 'A Track Whose Title Goes On For Quite A While',
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'at $width');
    }
  });
}
