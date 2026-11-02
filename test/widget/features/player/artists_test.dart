import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/player/controller/player.controller.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/artist.entity.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/presentation/screens/player.screen.dart';
import 'package:purelofi/features/player/presentation/widgets/artist_sheet.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/library_sheet.widget.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/mock_repositories.dart';
import '../../../helpers/pump_routed_app.dart';

void main() {
  late MockContentRepository mockRepo;
  late FakeAudioPlayerService fakeAudio;

  const ArtistEntity ada = ArtistEntity(
    id: 'ada',
    name: 'Ada Tapes',
    bio: 'Late nights, warm tape.',
    links: <String>[
      'https://www.youtube.com/@adatapes',
      'https://example.com/ada',
    ],
  );
  const ArtistEntity quiet = ArtistEntity(id: 'quiet', name: 'No Tracks Yet');

  TrackEntity by(String id, String title, String? artist, int day) =>
      makeTrack(id, title: title).copyWith(
        artistId: artist,
        artist: artist == null ? null : 'Ada Tapes',
        createdAt: DateTime.utc(2026, 10, day),
      );

  setUp(() {
    mockRepo = MockContentRepository();
    fakeAudio = FakeAudioPlayerService();
    addTearDown(fakeAudio.dispose);
    when(() => mockRepo.getTracks()).thenAnswer(
      (_) async => <TrackEntity>[
        by('a', 'Dusk Tape', 'ada', 1),
        by('b', 'Slow Bass', 'ada', 2),
        by('c', 'Uncredited', null, 3),
      ],
    );
    when(
      () => mockRepo.getArtists(),
    ).thenAnswer((_) async => <ArtistEntity>[ada, quiet]);
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
  }

  Future<void> openAda(WidgetTester tester) async {
    await openLibrary(tester);
    await tapPill(tester, 'Artists');
    await tester.tap(find.text('Ada Tapes'));
    await tester.pumpAndSettle();
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(PlayerScreen)));

  testWidgets('the artists pill lists who has music, with a count', (
    tester,
  ) async {
    await start(tester);
    await openLibrary(tester);
    await tapPill(tester, 'Artists');

    expect(find.text('Ada Tapes'), findsOneWidget);
    expect(find.text('2 tracks'), findsOneWidget);
    expect(find.text('No Tracks Yet'), findsNothing);
  });

  testWidgets('a track names its artist, an uncredited one PureLofi', (
    tester,
  ) async {
    await start(tester);
    await openLibrary(tester);
    await tapPill(tester, 'Tracks');

    final Finder sheet = find.byType(LibrarySheet);
    expect(
      find.descendant(of: sheet, matching: find.text('Ada Tapes')),
      findsNWidgets(2),
    );
    expect(
      find.descendant(of: sheet, matching: find.text('PureLofi')),
      findsWidgets,
    );
  });

  testWidgets('the page has the bio, the link out and the tracks', (
    tester,
  ) async {
    await start(tester);
    await openAda(tester);

    final Finder page = find.byType(ArtistSheet);
    expect(
      find.descendant(of: page, matching: find.text('Late nights, warm tape.')),
      findsOneWidget,
    );
    // Every channel, by the name of the place.
    expect(find.text('YouTube'), findsOneWidget);
    expect(find.text('Website'), findsOneWidget);
    expect(
      find.descendant(of: page, matching: find.text('Dusk Tape')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: page, matching: find.text('Uncredited')),
      findsNothing,
    );
  });

  testWidgets('play plays the first and lines up the rest', (tester) async {
    await start(tester);
    await openAda(tester);

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();

    expect(find.byType(ArtistSheet), findsNothing);
    expect(fakeAudio.playedTracks.last.id, 'a');
    expect(
      container(
        tester,
      ).read(playerControllerProvider).queue.map((TrackEntity t) => t.id),
      <String>['b'],
    );
  });

  testWidgets('a track\'s menu goes to its artist', (tester) async {
    await start(tester);
    await openLibrary(tester);
    await tapPill(tester, 'Tracks');
    await tester.tap(find.byTooltip('More: Slow Bass'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Go to artist'));
    await tester.pumpAndSettle();

    expect(find.byType(ArtistSheet), findsOneWidget);
    expect(find.text('Ada Tapes'), findsWidgets);
  });

  testWidgets('an uncredited track has no way to an artist', (tester) async {
    await start(tester);
    await openLibrary(tester);
    await tapPill(tester, 'Tracks');
    await tester.tap(find.byTooltip('More: Uncredited'));
    await tester.pumpAndSettle();

    expect(find.text('Go to artist'), findsNothing);
  });
}
