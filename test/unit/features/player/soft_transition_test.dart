import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/features/player/domain/soft_transition.dart';

void main() {
  const Duration length = Duration(minutes: 3);

  double level(
    Duration position, {
    bool enabled = true,
    bool loops = false,
    bool fadesIn = false,
    Duration? duration = length,
  }) => softTransitionLevel(
    position: position,
    duration: duration,
    enabled: enabled,
    loops: loops,
    fadesIn: fadesIn,
  );

  test('the middle of a track is at full volume', () {
    expect(level(const Duration(minutes: 1)), 1);
  });

  test('the last seconds go down to silence', () {
    expect(level(length - softFadeOut), 1);
    expect(level(length - softFadeOut ~/ 2), closeTo(0.5, 0.001));
    expect(level(length), 0);
  });

  test('a track that followed one running out comes in softly', () {
    expect(level(Duration.zero, fadesIn: true), 0);
    expect(level(softFadeIn ~/ 2, fadesIn: true), closeTo(0.5, 0.001));
    expect(level(softFadeIn, fadesIn: true), 1);
  });

  test('one picked by the listener starts at full volume', () {
    expect(level(Duration.zero), 1);
  });

  test('nothing fades with transitions off', () {
    expect(level(length, enabled: false), 1);
    expect(level(Duration.zero, enabled: false, fadesIn: true), 1);
  });

  test('a looping track never fades out: its end is not an end', () {
    expect(level(length, loops: true), 1);
  });

  test('a length not known yet is no reason to fade', () {
    expect(level(const Duration(minutes: 5), duration: null), 1);
  });

  test('a track shorter than both fades takes the quieter of the two', () {
    const Duration short = Duration(seconds: 3);
    expect(
      softTransitionLevel(
        position: const Duration(seconds: 1),
        duration: short,
        enabled: true,
        loops: false,
        fadesIn: true,
      ),
      closeTo(0.5, 0.001),
    );
  });
}
