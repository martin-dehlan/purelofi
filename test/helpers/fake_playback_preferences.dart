import 'package:purelofi/features/player/domain/playback_mode.dart';
import 'package:purelofi/features/player/domain/playback_preferences.service.dart';

/// Shuffle and repeat kept in memory rather than the platform's store.
class FakePlaybackPreferences implements PlaybackPreferences {
  FakePlaybackPreferences([this.stored = PlaybackMode.shuffle]);

  PlaybackMode stored;
  int saves = 0;

  @override
  Future<PlaybackMode> load() async => stored;

  @override
  Future<void> save(PlaybackMode mode) async {
    stored = mode;
    saves++;
  }
}
