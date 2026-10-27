import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/library/presentation/widgets/my_music.widget.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/presentation/widgets/library_sheet.widget.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/fake_library.repository.dart';
import '../../../helpers/fake_track_picker.dart';
import '../../../helpers/mock_repositories.dart';
import '../../../helpers/pump_routed_app.dart';

void main() {
  late MockContentRepository content;
  late FakeAudioPlayerService audio;
  late FakeLibraryRepository library;
  late FakeTrackPicker picker;

  setUp(() {
    content = MockContentRepository();
    audio = FakeAudioPlayerService();
    addTearDown(audio.dispose);
    library = FakeLibraryRepository();
    picker = FakeTrackPicker();
    when(
      () => content.getScenes(),
    ).thenAnswer((_) async => <SceneEntity>[makeScene('scene-1')]);
    when(() => content.getTracks()).thenAnswer(
      (_) async => <TrackEntity>[makeTrack('ours', title: 'Travel Lofi')],
    );
  });

  List<Override> overrides() => <Override>[
    contentRepositoryProvider.overrideWithValue(content),
    audioPlayerServiceProvider.overrideWithValue(audio),
    sceneVideoBuilderProvider.overrideWithValue(
      (SceneEntity scene) => const SizedBox.shrink(),
    ),
  ];

  Future<void> start(WidgetTester tester) async {
    // A phone, not the default 800×600 landscape box: the sheet's list is
    // lazy, and rows below its fold are never built.
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpRoutedApp(
      overrides: overrides(),
      library: library,
      picker: picker,
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMyMusic(WidgetTester tester) async {
    await openLibrary(tester);
    await tapPill(tester, 'My music');
  }

  bool chipSelected(WidgetTester tester, String label) => tester
      .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label))
      .selected;

  testWidgets('the library opens on PureLofi\'s music', (tester) async {
    await start(tester);
    await openLibrary(tester);

    expect(chipSelected(tester, 'PureLofi'), isTrue);
    expect(find.byType(MyMusic), findsNothing);
  });

  testWidgets('an empty library says what it is for', (tester) async {
    await start(tester);
    await openMyMusic(tester);

    expect(find.textContaining('Your own music'), findsOneWidget);
    expect(find.text('Add music'), findsOneWidget);
  });

  testWidgets('adding brings the files in and names what was turned away', (
    tester,
  ) async {
    picker.names = <String>['Kitchen Demo.mp3', 'notes.pdf'];
    library.refuse.add('notes.pdf');
    await start(tester);
    await openMyMusic(tester);

    await tester.tap(find.text('Add music'));
    await tester.pumpAndSettle();

    expect(find.text('Kitchen Demo.mp3'), findsOneWidget);
    expect(find.textContaining('notes.pdf: Refused.'), findsOneWidget);
  });

  testWidgets('a cancelled picker changes nothing', (tester) async {
    await start(tester);
    await openMyMusic(tester);

    await tester.tap(find.text('Add music'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Your own music'), findsOneWidget);
  });

  testWidgets('playing one hands the stream to the library, and back', (
    tester,
  ) async {
    library = FakeLibraryRepository(<TrackEntity>[
      makeLocalTrack('mine', title: 'Kitchen Demo'),
    ]);
    await start(tester);
    await openMyMusic(tester);

    await tester.tap(find.text('Kitchen Demo'));
    await tester.pumpAndSettle();

    expect(audio.playedTracks.last.id, 'mine');
    expect(find.byType(LibrarySheet), findsNothing);
    expect(
      find.textContaining('Back to PureLofi', findRichText: true),
      findsOneWidget,
    );

    await tester.tap(find.bySemanticsLabel('Back to PureLofi'));
    await tester.pumpAndSettle();

    expect(audio.playedTracks.last.id, 'ours');
    expect(
      find.bySemanticsLabel('Back to PureLofi'),
      findsNothing,
      reason: 'the chrome is as it was for anyone on PureLofi\'s music',
    );
  });

  testWidgets('the library opens on the side that is playing', (tester) async {
    library = FakeLibraryRepository(<TrackEntity>[
      makeLocalTrack('mine', title: 'Kitchen Demo'),
    ]);
    await start(tester);
    await openMyMusic(tester);
    await tester.tap(find.text('Kitchen Demo'));
    await tester.pumpAndSettle();

    await openLibrary(tester);

    expect(chipSelected(tester, 'My music'), isTrue);
    expect(find.byType(MyMusic), findsOneWidget);
  });

  group('removing', () {
    Future<void> swipeAway(WidgetTester tester, String title) async {
      await tester.drag(find.text(title), const Offset(-500, 0));
      await tester.pumpAndSettle();
    }

    setUp(() {
      library = FakeLibraryRepository(<TrackEntity>[
        makeLocalTrack('mine', title: 'Kitchen Demo'),
      ]);
    });

    testWidgets('asks first, and says the original stays', (tester) async {
      await start(tester);
      await openMyMusic(tester);

      await swipeAway(tester, 'Kitchen Demo');

      expect(
        find.textContaining('The file on your phone stays'),
        findsOneWidget,
      );
    });

    testWidgets('keep leaves it where it was', (tester) async {
      await start(tester);
      await openMyMusic(tester);
      await swipeAway(tester, 'Kitchen Demo');

      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();

      expect(library.deleted, isEmpty);
      expect(find.text('Kitchen Demo'), findsOneWidget);
    });

    testWidgets('remove takes it out', (tester) async {
      await start(tester);
      await openMyMusic(tester);
      await swipeAway(tester, 'Kitchen Demo');

      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(library.deleted, <String>['mine']);
      expect(find.text('Kitchen Demo'), findsNothing);
    });
  });

  group('sort and search', () {
    List<TrackEntity> named(List<String> titles) => <TrackEntity>[
      for (final String title in titles) makeLocalTrack(title, title: title),
    ];

    /// The titles in the list, top to bottom.
    List<String> shown(WidgetTester tester) => tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(MyMusic),
            matching: find.byWidgetPredicate(
              (Widget w) =>
                  w is Text &&
                  w.data != null &&
                  w.style?.fontWeight == FontWeight.w600,
            ),
          ),
        )
        .map((Text t) => t.data!)
        .toList();

    testWidgets('the sort chip opens the orders, and title reorders', (
      tester,
    ) async {
      library = FakeLibraryRepository(
        named(<String>['Charlie', 'Alpha', 'Bravo']),
      );
      await start(tester);
      await openMyMusic(tester);

      await tester.tap(find.widgetWithText(ActionChip, 'Recently added'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, 'Title'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ActionChip, 'Title'), findsOneWidget);
      expect(shown(tester), <String>['Alpha', 'Bravo', 'Charlie']);
    });

    testWidgets('search appears only once the library is big enough', (
      tester,
    ) async {
      library = FakeLibraryRepository(named(<String>['a', 'b', 'c']));
      await start(tester);
      await openMyMusic(tester);

      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('search narrows the list by title', (tester) async {
      library = FakeLibraryRepository(
        named(<String>['Kitchen Demo', 'Late Tape', 'c', 'd', 'e', 'f']),
      );
      await start(tester);
      await openMyMusic(tester);

      await tester.enterText(find.byType(TextField), 'kitchen');
      await tester.pumpAndSettle();

      expect(shown(tester), <String>['Kitchen Demo']);

      await tester.enterText(find.byType(TextField), 'nothing like it');
      await tester.pumpAndSettle();

      expect(find.textContaining('Nothing called'), findsOneWidget);
    });
  });
}
