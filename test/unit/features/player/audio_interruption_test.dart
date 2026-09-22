import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/features/player/domain/audio_interruption.dart';

void main() {
  InterruptionAction act({
    required InterruptionKind kind,
    required bool beginning,
    bool isPlaying = true,
    bool pausedByInterruption = false,
  }) => actionForInterruption(
    kind: kind,
    beginning: beginning,
    isPlaying: isPlaying,
    pausedByInterruption: pausedByInterruption,
  );

  group('while it is playing', () {
    test('a call stops the music', () {
      expect(
        act(kind: InterruptionKind.pause, beginning: true),
        InterruptionAction.pause,
      );
    });

    test('a navigation prompt only ducks under it', () {
      expect(
        act(kind: InterruptionKind.duck, beginning: true),
        InterruptionAction.duck,
      );
    });
  });

  group('while it is already stopped', () {
    test('an interruption changes nothing', () {
      expect(
        act(kind: InterruptionKind.pause, beginning: true, isPlaying: false),
        InterruptionAction.none,
      );
      expect(
        act(kind: InterruptionKind.duck, beginning: true, isPlaying: false),
        InterruptionAction.none,
      );
    });
  });

  group('when the interruption is over', () {
    test('the volume comes back up after ducking', () {
      expect(
        act(kind: InterruptionKind.duck, beginning: false, isPlaying: false),
        InterruptionAction.restoreVolume,
        reason: 'ducking never stopped playback, so isPlaying is irrelevant',
      );
    });

    test('a call we paused for hands the music back', () {
      expect(
        act(
          kind: InterruptionKind.pause,
          beginning: false,
          isPlaying: false,
          pausedByInterruption: true,
        ),
        InterruptionAction.resume,
      );
    });

    test('a pause the listener asked for is left alone', () {
      // The rule this whole thing exists for. Somebody pressed pause, put the
      // phone away, took a call — the music must not come back on in their
      // pocket afterwards.
      expect(
        act(
          kind: InterruptionKind.pause,
          beginning: false,
          isPlaying: false,
          pausedByInterruption: false,
        ),
        InterruptionAction.none,
      );
    });
  });

  test('ducking is quieter, not silent', () {
    // The point of ducking is that the music is still under the announcement.
    expect(duckedVolume, greaterThan(0));
    expect(duckedVolume, lessThan(1));
  });
}
