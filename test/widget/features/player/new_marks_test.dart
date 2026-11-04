import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/presentation/widgets/library_button.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/new_dot.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/track_tile.widget.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/fake_new_content.repository.dart';
import '../../../helpers/mock_repositories.dart';
import '../../../helpers/pump_routed_app.dart';

/// The quiet "new" marks (#148).
void main() {
  late MockContentRepository mockRepo;
  late FakeAudioPlayerService fakeAudio;
  final DateTime installed = DateTime(2026, 10, 1);

  setUp(() {
    mockRepo = MockContentRepository();
    fakeAudio = FakeAudioPlayerService();
    addTearDown(fakeAudio.dispose);
    when(() => mockRepo.getTracks()).thenAnswer(
      (_) async => <TrackEntity>[
        makeTrack('old', title: 'Old Tape'),
        makeTrack(
          'new',
          title: 'Fresh Tape',
        ).copyWith(createdAt: DateTime(2026, 10, 20)),
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

  testWidgets('a new track puts a dot on the library and on its row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpRoutedApp(
      overrides: overrides(),
      newContent: FakeNewContentRepository(firstLaunch: installed),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(LibraryButton),
        matching: find.byType(NewDot),
      ),
      findsOneWidget,
    );

    await openLibrary(tester);
    await tapPill(tester, 'Tracks');

    expect(
      find.descendant(
        of: find.widgetWithText(TrackTile, 'Fresh Tape'),
        matching: find.byType(NewDot),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(TrackTile, 'Old Tape'),
        matching: find.byType(NewDot),
      ),
      findsNothing,
    );
  });

  testWidgets('on a fresh install nothing is marked', (tester) async {
    await tester.pumpRoutedApp(
      overrides: overrides(),
      newContent: FakeNewContentRepository(firstLaunch: DateTime(2027)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NewDot), findsNothing);
  });
}
