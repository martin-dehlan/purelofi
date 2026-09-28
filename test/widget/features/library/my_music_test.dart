import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/library/presentation/widgets/my_music.widget.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/presentation/widgets/settings_sheet.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/track_list.widget.dart';

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
    await tester.pumpRoutedApp(
      overrides: overrides(),
      library: library,
      picker: picker,
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMyMusic(WidgetTester tester) async {
    await openMenu(tester);
    await tester.tap(find.text('My music'));
    await tester.pumpAndSettle();
  }

  testWidgets('the menu opens on PureLofi\'s music', (tester) async {
    await start(tester);
    await openMenu(tester);

    expect(find.byType(TrackList), findsOneWidget);
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
    expect(find.byType(SettingsSheet), findsNothing);
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

  testWidgets('the menu opens on the side that is playing', (tester) async {
    library = FakeLibraryRepository(<TrackEntity>[
      makeLocalTrack('mine', title: 'Kitchen Demo'),
    ]);
    await start(tester);
    await openMyMusic(tester);
    await tester.tap(find.text('Kitchen Demo'));
    await tester.pumpAndSettle();

    await openMenu(tester);

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
}
