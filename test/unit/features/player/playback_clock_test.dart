import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/features/player/domain/playback_clock.dart';

void main() {
  group('PlaybackClock', () {
    test('the scene clock runs whether or not audio plays', () {
      final PlaybackClock clock = PlaybackClock();

      clock.tick(const Duration(seconds: 1), isPlaying: false);
      clock.tick(const Duration(seconds: 2), isPlaying: true);

      expect(clock.sceneTime, const Duration(seconds: 2));
    });

    test('the playing clock only advances while audio plays', () {
      final PlaybackClock clock = PlaybackClock();

      clock.tick(const Duration(seconds: 1), isPlaying: true);
      clock.tick(const Duration(seconds: 2), isPlaying: true);

      expect(clock.playingTime, const Duration(seconds: 2));
    });

    test('pausing freezes it where it stood', () {
      final PlaybackClock clock = PlaybackClock();
      clock.tick(const Duration(seconds: 2), isPlaying: true);

      clock.tick(const Duration(seconds: 5), isPlaying: false);
      clock.tick(const Duration(seconds: 9), isPlaying: false);

      expect(
        clock.playingTime,
        const Duration(seconds: 2),
        reason: 'the reels must not turn while the music is paused',
      );
      expect(clock.sceneTime, const Duration(seconds: 9));
    });

    test('resuming continues rather than jumping forward', () {
      final PlaybackClock clock = PlaybackClock();
      clock.tick(const Duration(seconds: 2), isPlaying: true);
      clock.tick(const Duration(seconds: 10), isPlaying: false);

      clock.tick(const Duration(seconds: 11), isPlaying: true);

      expect(
        clock.playingTime,
        const Duration(seconds: 3),
        reason: 'the paused stretch must not be credited retroactively',
      );
    });

    test('a ticker that restarts does not run time backwards', () {
      final PlaybackClock clock = PlaybackClock();
      clock.tick(const Duration(seconds: 5), isPlaying: true);

      clock.tick(const Duration(seconds: 1), isPlaying: true);

      expect(clock.playingTime, const Duration(seconds: 5));
    });
  });
}
