import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/presentation/widgets/now_playing_bars.widget.dart';

import '../../../helpers/fake_audio_player.service.dart';

void main() {
  late FakeAudioPlayerService fakeAudio;

  setUp(() {
    fakeAudio = FakeAudioPlayerService();
    addTearDown(fakeAudio.dispose);
  });

  /// The bars alone, with real motion unless [still] asks for less.
  Future<void> pumpBars(WidgetTester tester, {bool still = false}) =>
      tester.pumpWidget(
        ProviderScope(
          overrides: [audioPlayerServiceProvider.overrideWithValue(fakeAudio)],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(400, 800),
              ).copyWith(disableAnimations: still),
              child: const Center(
                child: NowPlayingBars(size: 40, color: Color(0xFFFFFFFF)),
              ),
            ),
          ),
        ),
      );

  Future<void> setPlaying(WidgetTester tester, bool playing) async {
    fakeAudio.playingController.add(playing);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('bounce while the music plays', (tester) async {
    await pumpBars(tester);
    await setPlaying(tester, true);

    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('rest when it is paused', (tester) async {
    await pumpBars(tester);
    await setPlaying(tester, true);
    await setPlaying(tester, false);

    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('rest under reduced motion, even while playing', (tester) async {
    await pumpBars(tester, still: true);
    await setPlaying(tester, true);

    expect(tester.hasRunningAnimations, isFalse);
  });
}
