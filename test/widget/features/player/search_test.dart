import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/artist.entity.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/presentation/widgets/artist_sheet.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/search_results.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/library_sheet.widget.dart';

import '../../../helpers/fake_audio_player.service.dart';
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
        makeTrack(
          'a',
          title: 'Feeling You',
        ).copyWith(artistId: 'masso', artist: 'massomusicofficial'),
        makeTrack('b', title: 'Travel Lofi'),
      ],
    );
    when(() => mockRepo.getArtists()).thenAnswer(
      (_) async => <ArtistEntity>[
        const ArtistEntity(id: 'masso', name: 'massomusicofficial'),
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

  Future<void> openSearch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final FakeLibraryRepository library = FakeLibraryRepository(<TrackEntity>[
      makeLocalTrack('l1', title: 'Kitchen Demo'),
    ]);
    await tester.pumpRoutedApp(overrides: overrides(), library: library);
    await tester.pumpAndSettle();
    await openLibrary(tester);
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
  }

  Finder inSearch(Finder f) =>
      find.descendant(of: find.byType(SearchResults), matching: f);

  testWidgets('an artist\'s name finds them and their tracks', (tester) async {
    await openSearch(tester);

    await tester.enterText(find.byType(SearchBar), 'masso');
    await tester.pumpAndSettle();

    expect(inSearch(find.text('Artists')), findsOneWidget);
    expect(inSearch(find.text('Feeling You')), findsOneWidget);
    expect(inSearch(find.text('Travel Lofi')), findsNothing);
  });

  testWidgets('it searches the listener\'s own music too', (tester) async {
    await openSearch(tester);

    await tester.enterText(find.byType(SearchBar), 'kitchen');
    await tester.pumpAndSettle();

    expect(inSearch(find.text('Kitchen Demo')), findsOneWidget);
  });

  testWidgets('a track found plays and the library stays open', (tester) async {
    await openSearch(tester);
    await tester.enterText(find.byType(SearchBar), 'travel');
    await tester.pumpAndSettle();

    await tester.tap(inSearch(find.text('Travel Lofi')));
    await tester.pumpAndSettle();

    expect(find.byType(LibrarySheet), findsOneWidget);
    expect(fakeAudio.playedTracks.last.id, 'b');
  });

  testWidgets('an artist found opens their page', (tester) async {
    await openSearch(tester);
    await tester.enterText(find.byType(SearchBar), 'masso');
    await tester.pumpAndSettle();

    await tester.tap(inSearch(find.text('Artist')));
    await tester.pumpAndSettle();

    expect(find.byType(ArtistSheet), findsOneWidget);
  });

  testWidgets('says so when nothing matches', (tester) async {
    await openSearch(tester);

    await tester.enterText(find.byType(SearchBar), 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('Nothing matches "zzz".'), findsOneWidget);
  });

  testWidgets('search stays in the library, and Cancel closes it', (
    tester,
  ) async {
    await openSearch(tester);

    // The library's own sheet, not one on top of it.
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Your Library'), findsNothing);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(SearchResults), findsNothing);
    expect(find.text('Your Library'), findsOneWidget);
  });
}
