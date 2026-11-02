import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/presentation/widgets/track_actions_sheet.widget.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/fake_favorites.repository.dart';
import '../../../helpers/fake_library.repository.dart';
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
        makeTrack('b', title: 'Slow Bass'),
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

  Future<void> start(
    WidgetTester tester, {
    FakeFavoritesRepository? favorites,
  }) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpRoutedApp(overrides: overrides(), favorites: favorites);
    await tester.pumpAndSettle();
  }

  Future<void> openFromLibrary(WidgetTester tester, String title) async {
    await openLibrary(tester);
    await tester.tap(find.byTooltip('More: $title'));
    await tester.pumpAndSettle();
  }

  testWidgets('a track of ours: its card, then mark, queue, share, report', (
    tester,
  ) async {
    await start(tester);
    await openFromLibrary(tester, 'Slow Bass');

    final Finder sheet = find.byType(TrackActionsSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('Slow Bass')),
      findsOneWidget,
    );
    for (final String row in <String>[
      'Add to favorites',
      'Play next',
      'Add to queue',
      'Share',
      'Report a problem',
    ]) {
      expect(
        find.descendant(of: sheet, matching: find.text(row)),
        findsOneWidget,
      );
    }
    expect(find.text('Remove from PureLofi'), findsNothing);
  });

  testWidgets('marking it closes the sheet and keeps the mark', (tester) async {
    final FakeFavoritesRepository favorites = FakeFavoritesRepository();
    await start(tester, favorites: favorites);
    await openFromLibrary(tester, 'Slow Bass');

    await tester.tap(find.text('Add to favorites'));
    await tester.pumpAndSettle();

    expect(find.byType(TrackActionsSheet), findsNothing);
    expect(await favorites.getFavoriteIds(), contains('b'));
  });

  testWidgets('add to queue lines it up', (tester) async {
    await start(tester);
    await openFromLibrary(tester, 'Slow Bass');

    await tester.tap(find.text('Add to queue'));
    await tester.pumpAndSettle();
    await tapPill(tester, 'Up next');

    expect(find.text('Next in queue'), findsOneWidget);
  });

  testWidgets('the bar has the same actions for the track playing', (
    tester,
  ) async {
    await start(tester);
    final String playing = fakeAudio.playedTracks.last.title;

    await tester.tap(find.bySemanticsLabel('More: $playing'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(TrackActionsSheet),
        matching: find.text(playing),
      ),
      findsOneWidget,
    );
    expect(find.text('Share'), findsOneWidget);
  });

  testWidgets('a file of the listener\'s own can only be taken out', (
    tester,
  ) async {
    await tester.pumpProviderApp(
      overrides: overrides(),
      child: Scaffold(
        body: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () => showTrackActionsSheet(
              context,
              makeLocalTrack('l1', artist: 'Me'),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Me'), findsOneWidget);
    expect(find.text('Remove from PureLofi'), findsOneWidget);
    expect(find.text('Play next'), findsOneWidget);
    expect(find.text('Add to favorites'), findsNothing);
    expect(find.text('Share'), findsNothing);
    expect(find.text('Report a problem'), findsNothing);
  });
}
