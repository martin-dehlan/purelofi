import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/common/errors/app_error.dart';
import 'package:purelofi/common/utils/app_assets.dart';
import 'package:purelofi/common/widgets/pixel_icon.widget.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/presentation/widgets/player_controls.widget.dart';

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
      (_) async => <TrackEntity>[makeTrack('a', title: 'Dusk Tape')],
    );
  });

  List<Override> overrides() => <Override>[
    contentRepositoryProvider.overrideWithValue(mockRepo),
    audioPlayerServiceProvider.overrideWithValue(fakeAudio),
  ];

  /// The play/pause button — the chrome holds other pixel icons too.
  final Finder playPause = find.byWidgetPredicate(
    (Widget widget) =>
        widget is PixelIcon &&
        (widget.asset == AppAssets.playIcon ||
            widget.asset == AppAssets.pauseIcon),
  );

  String assetOf(WidgetTester tester) {
    final Image image = tester.widget<Image>(
      find.descendant(of: playPause, matching: find.byType(Image)),
    );
    return (image.image as AssetImage).assetName;
  }

  testWidgets('shows the play icon while paused', (tester) async {
    await tester.pumpProviderApp(
      child: const PlayerControls(),
      overrides: overrides(),
    );
    await tester.pumpAndSettle();

    expect(assetOf(tester), AppAssets.playIcon);
  });

  testWidgets('renders pixel assets without smoothing', (tester) async {
    await tester.pumpProviderApp(
      child: const PlayerControls(),
      overrides: overrides(),
    );
    await tester.pumpAndSettle();

    final Image image = tester.widget<Image>(
      find.descendant(of: playPause, matching: find.byType(Image)),
    );
    expect(image.filterQuality, FilterQuality.none);
    expect(image.isAntiAlias, isFalse);
  });

  testWidgets('tapping starts playback and swaps to the pause icon', (
    tester,
  ) async {
    await tester.pumpProviderApp(
      child: const PlayerControls(),
      overrides: overrides(),
    );
    await tester.pumpAndSettle();

    await tester.tap(playPause);
    await tester.pumpAndSettle();

    expect(fakeAudio.playedTracks.single.id, 'a');
    expect(assetOf(tester), AppAssets.pauseIcon);
  });

  testWidgets('tapping again pauses', (tester) async {
    await tester.pumpProviderApp(
      child: const PlayerControls(),
      overrides: overrides(),
    );
    await tester.pumpAndSettle();

    await tester.tap(playPause);
    await tester.pumpAndSettle();
    await tester.tap(playPause);
    await tester.pumpAndSettle();

    expect(fakeAudio.pauseCalls, 1);
    expect(assetOf(tester), AppAssets.playIcon);
  });

  testWidgets('shows the track title once something is playing', (
    tester,
  ) async {
    await tester.pumpProviderApp(
      child: const PlayerControls(),
      overrides: overrides(),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dusk Tape'), findsNothing);

    await tester.tap(playPause);
    await tester.pumpAndSettle();

    expect(find.text('Dusk Tape'), findsOneWidget);
  });

  testWidgets('shows a playback failure in the user’s words', (tester) async {
    fakeAudio.failureOnPlay = const AppError.playback(
      message: 'the stream failed',
    );

    await tester.pumpProviderApp(
      child: const PlayerControls(),
      overrides: overrides(),
    );
    await tester.pumpAndSettle();
    await tester.tap(playPause);
    await tester.pumpAndSettle();

    expect(find.text('Playback error: the stream failed'), findsOneWidget);
  });
}
