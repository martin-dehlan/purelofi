import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/mood.entity.dart';
import 'package:purelofi/features/player/domain/playlist.entity.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/presentation/widgets/collection_page.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/library_sheet.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/playlist_actions_sheet.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/scope_line.widget.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/fake_collections.dart';
import '../../../helpers/mock_repositories.dart';
import '../../../helpers/pump_routed_app.dart';

/// Moods and playlists in the library (#141).
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

  Future<FakePlaylistRepository> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final FakePlaylistRepository playlists = FakePlaylistRepository();
    await tester.pumpRoutedApp(
      overrides: overrides(),
      moods: FakeMoodRepository(const <MoodEntity>[
        MoodEntity(
          id: 'm',
          slug: 'rainy',
          title: 'Rainy evenings',
          trackIds: <String>['b'],
        ),
      ]),
      playlistStore: playlists,
    );
    await tester.pumpAndSettle();
    await openLibrary(tester);
    return playlists;
  }

  Finder inLibrary(Finder f) =>
      find.descendant(of: find.byType(LibrarySheet), matching: f);

  testWidgets('a mood opens on its tracks and plays from them', (tester) async {
    await open(tester);

    await tester.tap(find.bySemanticsLabel('Rainy evenings, mood'));
    await tester.pumpAndSettle();
    expect(
      inLibrary(find.widgetWithText(ListTile, 'Slow Bass')),
      findsOneWidget,
    );
    expect(inLibrary(find.widgetWithText(ListTile, 'Dusk Tape')), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pumpAndSettle();

    expect(fakeAudio.playedTracks.last.id, 'b');
    expect(
      find.descendant(
        of: find.byType(ScopeLine),
        matching: find.textContaining('Rainy evenings'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a new playlist is made from the library and filled from a '
      'track\'s menu', (tester) async {
    final FakePlaylistRepository playlists = await open(tester);

    // One row for all playlists in the overview; the list is its own tab.
    await tester.tap(inLibrary(find.text('Playlists')).first);
    await tester.pumpAndSettle();
    await tester.tap(inLibrary(find.text('New playlist')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Study');
    await tester.tap(find.widgetWithText(TextButton, 'Create'));
    await tester.pumpAndSettle();
    expect(inLibrary(find.text('Study')), findsOneWidget);

    await tapPill(tester, 'Tracks');
    await tester.tap(find.byTooltip('More: Dusk Tape'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to playlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Study').last);
    await tester.pumpAndSettle();

    final PlaylistEntity study = playlists.playlists.values.single.$1;
    expect(study.items.single.trackId, 'a');
  });

  testWidgets('a playlist row plays on a tap, its ⋯ holds the rest', (
    tester,
  ) async {
    await open(tester);
    // Made and filled the way a listener does.
    await tapPill(tester, 'Playlists');
    await tester.tap(inLibrary(find.text('New playlist')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Study');
    await tester.tap(find.widgetWithText(TextButton, 'Create'));
    await tester.pumpAndSettle();
    await tapPill(tester, 'Tracks');
    await tester.tap(find.byTooltip('More: Dusk Tape'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to playlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Study').last);
    await tester.pumpAndSettle();
    await tapPill(tester, 'Playlists');

    await tester.tap(inLibrary(find.text('Study')));
    await tester.pumpAndSettle();
    // The play reads the playlist from the store, outside the test's clock.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    // The stream plays from the playlist now, as the line under the
    // player says; nothing slid in over the list.
    expect(
      find.descendant(
        of: find.byType(ScopeLine),
        matching: find.textContaining('Study'),
      ),
      findsOneWidget,
    );
    expect(inLibrary(find.text('New playlist')), findsOneWidget);

    await tester.tap(find.byTooltip('More: Study'));
    await tester.pumpAndSettle();
    for (final String row in <String>[
      'Edit playlist',
      'Rename playlist',
      'Share',
      'Delete playlist',
    ]) {
      expect(find.text(row), findsOneWidget);
    }

    // Edit opens its tracks, with only Play on top: no icons beside it.
    await tester.tap(find.text('Edit playlist'));
    await tester.pumpAndSettle();
    // Its tracks are read from the store, outside the test's clock.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.byType(CollectionPage), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CollectionPage),
        matching: find.text('Dusk Tape'),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Rename playlist'), findsNothing);
    expect(find.byTooltip('Delete playlist'), findsNothing);
  });

  test('a shared playlist reads as its name and its tracks', () {
    expect(
      PlaylistActionsSheet.shareText('Study', <TrackEntity>[
        makeTrack('a', title: 'Dusk Tape'),
      ]),
      startsWith('Study\n\nDusk Tape · '),
    );
  });
}
