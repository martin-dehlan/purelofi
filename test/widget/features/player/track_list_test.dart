import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/common/utils/app_fonts.dart';
import 'package:purelofi/common/widgets/app_icon.widget.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/presentation/widgets/settings_sheet.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/track_list.widget.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/mock_repositories.dart';
import '../../../helpers/pump_routed_app.dart';

void main() {
  late MockContentRepository mockRepo;
  late FakeAudioPlayerService fakeAudio;

  final TrackEntity travel = makeTrack(
    'a',
    title: 'Travel Lofi',
  ).copyWith(durationSeconds: 118);
  final TrackEntity bass = makeTrack(
    'b',
    title: 'Slow Bass',
    btsVideoUrl: 'https://example.com/b-bts.mp4',
  );

  setUp(() {
    mockRepo = MockContentRepository();
    fakeAudio = FakeAudioPlayerService();
    addTearDown(fakeAudio.dispose);
    when(
      () => mockRepo.getScenes(),
    ).thenAnswer((_) async => <SceneEntity>[makeScene('scene-1')]);
    when(
      () => mockRepo.getTracks(),
    ).thenAnswer((_) async => <TrackEntity>[travel, bass]);
  });

  List<Override> overrides() => <Override>[
    contentRepositoryProvider.overrideWithValue(mockRepo),
    audioPlayerServiceProvider.overrideWithValue(fakeAudio),
    sceneVideoBuilderProvider.overrideWithValue(
      (SceneEntity scene) => const SizedBox.shrink(),
    ),
  ];

  Future<void> openTrackList(WidgetTester tester) async {
    await tester.pumpRoutedApp(overrides: overrides());
    await tester.pumpAndSettle();
    await openMenu(tester);
  }

  /// The row of [title] in the open list. The title playing is also in the
  /// player bar, so the search stays inside the list.
  Finder rowOf(String title) => find.ancestor(
    of: find.descendant(of: find.byType(TrackList), matching: find.text(title)),
    matching: find.byType(Row),
  );

  final Finder nowPlaying = find.byWidgetPredicate(
    (Widget w) => w is AppIcon && w.glyph == AppGlyph.nowPlaying,
  );

  testWidgets('the menu leads with every track', (tester) async {
    await openTrackList(tester);

    expect(find.byType(TrackList), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TrackList),
        matching: find.text('Travel Lofi'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(TrackList),
        matching: find.text('Slow Bass'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a known length is shown in the mono face', (tester) async {
    await openTrackList(tester);

    final Text duration = tester.widget<Text>(find.text('1:58'));
    expect(duration.style?.fontFamily, AppFonts.mono);
  });

  testWidgets('tapping a track plays it and closes the menu', (tester) async {
    await openTrackList(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(TrackList),
        matching: find.text('Slow Bass'),
      ),
    );
    await tester.pumpAndSettle();

    expect(fakeAudio.playedTracks.last.id, 'b');
    expect(find.byType(SettingsSheet), findsNothing);
  });

  testWidgets('only the track playing is marked', (tester) async {
    await openTrackList(tester);
    final String playing = fakeAudio.playedTracks.last.title;
    final String other = playing == 'Travel Lofi' ? 'Slow Bass' : 'Travel Lofi';

    expect(nowPlaying, findsOneWidget);
    expect(
      find.descendant(of: rowOf(playing).first, matching: nowPlaying),
      findsOneWidget,
    );
    expect(
      find.descendant(of: rowOf(other).first, matching: nowPlaying),
      findsNothing,
    );
  });

  testWidgets('only a track with footage carries the camera', (tester) async {
    await openTrackList(tester);

    expect(footageCamera, findsOneWidget);
    expect(
      find.descendant(of: rowOf('Slow Bass').first, matching: footageCamera),
      findsOneWidget,
    );
  });
}
