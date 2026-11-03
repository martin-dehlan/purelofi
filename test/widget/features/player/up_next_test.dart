import 'package:flutter/material.dart';
import 'package:purelofi/common/widgets/app_icon.widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/player/controller/player.controller.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/presentation/widgets/up_next.widget.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/mock_repositories.dart';
import '../../../helpers/pump_routed_app.dart';

void main() {
  late MockContentRepository mockRepo;
  late FakeAudioPlayerService fakeAudio;
  // Not in the catalogue, so it can only turn up through the queue.
  final TrackEntity queued = makeTrack('q', title: 'Queued Tape');

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

  Future<PlayerController> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpRoutedApp(overrides: overrides());
    await tester.pumpAndSettle();

    return ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    ).read(playerControllerProvider.notifier);
  }

  Finder inQueue(String text) =>
      find.descendant(of: find.byType(UpNext), matching: find.text(text));

  testWidgets('shows what plays now and what the stream plays next', (
    tester,
  ) async {
    await start(tester);
    await openQueue(tester);

    expect(inQueue('Now playing'), findsOneWidget);
    expect(inQueue('Next up'), findsOneWidget);
    expect(inQueue('Next in queue'), findsNothing);
    expect(
      find.descendant(of: find.byType(UpNext), matching: find.byType(ListTile)),
      findsAtLeastNWidgets(2),
    );
  });

  Finder repeatMark() => find.descendant(
    of: find.byType(UpNext),
    matching: find.byWidgetPredicate(
      (Widget w) => w is AppIcon && w.glyph == AppGlyph.repeatOne,
    ),
  );

  testWidgets('on repeat, the track playing is marked and nothing listed', (
    tester,
  ) async {
    await start(tester);
    await tester.tap(find.bySemanticsLabel('Play order'));
    await tester.pumpAndSettle();
    await openQueue(tester);

    expect(repeatMark(), findsOneWidget);
    expect(inQueue('Next up'), findsNothing);
  });

  testWidgets('the only track is marked as coming again, not listed twice', (
    tester,
  ) async {
    when(
      () => mockRepo.getTracks(),
    ).thenAnswer((_) async => <TrackEntity>[makeTrack('a', title: 'Only One')]);
    await start(tester);
    await openQueue(tester);

    expect(
      find.descendant(
        of: find.byType(UpNext),
        matching: find.widgetWithText(ListTile, 'Only One'),
      ),
      findsOneWidget,
    );
    expect(repeatMark(), findsOneWidget);
    expect(inQueue('Next up'), findsNothing);
  });

  testWidgets('with more to come, there is no repeat mark', (tester) async {
    await start(tester);
    await openQueue(tester);

    expect(repeatMark(), findsNothing);
  });

  testWidgets('a queued track has its own section and jumps on tap', (
    tester,
  ) async {
    final PlayerController player = await start(tester);
    player.addToQueue(queued);
    await openQueue(tester);

    expect(inQueue('Next in queue'), findsOneWidget);

    await tester.tap(
      find
          .descendant(
            of: find.byType(UpNext),
            matching: find.widgetWithText(ListTile, 'Queued Tape'),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(fakeAudio.playedTracks.last.id, 'q');
    expect(inQueue('Next in queue'), findsNothing);
  });

  testWidgets('clear empties the queue', (tester) async {
    final PlayerController player = await start(tester);
    player
      ..addToQueue(queued)
      ..addToQueue(queued);
    await openQueue(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Clear'));
    await tester.pumpAndSettle();

    expect(inQueue('Next in queue'), findsNothing);
  });
}
