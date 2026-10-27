import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/presentation/widgets/library_sheet.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/track_cover.widget.dart';

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
      (_) async => <TrackEntity>[
        makeTrack('a', title: 'Dusk Tape'),
        makeTrack(
          'b',
          title: 'Slow Bass',
          btsVideoUrl: 'https://example.com/b-bts.mp4',
        ),
      ],
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

  Future<void> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpRoutedApp(overrides: overrides());
    await tester.pumpAndSettle();
    await openLibrary(tester);
  }

  Finder row(String title) => find.descendant(
    of: find.byType(LibrarySheet),
    matching: find.widgetWithText(ListTile, title),
  );

  Future<void> openMore(WidgetTester tester, String title) async {
    await tester.tap(find.byTooltip('More: $title'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists every track, each with a cover', (tester) async {
    await start(tester);

    expect(row('Dusk Tape'), findsOneWidget);
    expect(row('Slow Bass'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(LibrarySheet),
        matching: find.byType(TrackCover),
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('tapping a track plays it and goes back to the room', (
    tester,
  ) async {
    await start(tester);

    await tester.tap(row('Slow Bass'));
    await tester.pumpAndSettle();

    expect(fakeAudio.playedTracks.last.id, 'b');
    expect(find.byType(LibrarySheet), findsNothing);
  });

  testWidgets('the track playing is the selected tile', (tester) async {
    await start(tester);
    final String playing = fakeAudio.playedTracks.last.title;

    expect(tester.widget<ListTile>(row(playing)).selected, isTrue);
  });

  testWidgets('play next puts it at the head of the queue', (tester) async {
    await start(tester);

    await openMore(tester, 'Slow Bass');
    await tester.tap(find.widgetWithText(MenuItemButton, 'Play next'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(LibrarySheet))).pop();
    await tester.pumpAndSettle();
    await openQueue(tester);

    expect(find.text('Next in queue'), findsOneWidget);
  });

  testWidgets('a track with footage offers it', (tester) async {
    await start(tester);

    await openMore(tester, 'Slow Bass');
    expect(find.text('Behind the scenes'), findsOneWidget);
  });

  testWidgets('a track without footage does not', (tester) async {
    await start(tester);

    await openMore(tester, 'Dusk Tape');
    expect(find.text('Play next'), findsOneWidget);
    expect(find.text('Behind the scenes'), findsNothing);
  });

  testWidgets('favorites says how to fill it while it is empty', (
    tester,
  ) async {
    await start(tester);

    await tapPill(tester, 'Favorites');

    expect(find.textContaining('Nothing marked yet'), findsOneWidget);
  });
}
