import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/features/player/domain/play_tally.dart';

void main() {
  group('PlayTally', () {
    test('counts small steps forward while playing', () {
      final PlayTally tally = PlayTally();
      for (int ms = 0; ms <= 10000; ms += 200) {
        tally.observe(Duration(milliseconds: ms), playing: true);
      }

      expect(tally.heard, const Duration(seconds: 10));
    });

    test('a seek is not listening, nor is time spent paused', () {
      final PlayTally tally = PlayTally()
        ..observe(Duration.zero, playing: true)
        ..observe(const Duration(seconds: 1), playing: true)
        // Seek to the middle.
        ..observe(const Duration(minutes: 2), playing: true)
        ..observe(const Duration(minutes: 2, seconds: 1), playing: true)
        // Paused: the playhead does not move, nothing is heard.
        ..observe(const Duration(minutes: 2, seconds: 1), playing: false)
        ..observe(const Duration(minutes: 2, seconds: 2), playing: false);

      expect(tally.heard, const Duration(seconds: 2));
    });

    test('a play counts after 30 seconds heard', () {
      final PlayTally tally = PlayTally();
      for (int s = 0; s <= 29; s++) {
        tally.observe(Duration(seconds: s), playing: true);
      }
      expect(tally.counts(const Duration(minutes: 3)), isFalse);

      tally.observe(const Duration(seconds: 30), playing: true);
      expect(tally.counts(const Duration(minutes: 3)), isTrue);
    });

    test('a track shorter than that counts once nearly all of it is heard', () {
      final PlayTally tally = PlayTally();
      for (int s = 0; s <= 19; s++) {
        tally.observe(Duration(seconds: s), playing: true);
      }

      expect(tally.counts(const Duration(seconds: 20)), isTrue);
    });
  });

  group('recentTrackIds', () {
    test('each track once, newest first, at most the limit', () {
      expect(
        recentTrackIds(<String>['c', 'a', 'c', 'b', 'a', 'd'], limit: 3),
        <String>['c', 'a', 'b'],
      );
    });
  });
}
