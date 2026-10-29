import 'playback_mode.dart';

/// Where shuffle and repeat are kept between launches.
abstract class PlaybackPreferences {
  Future<PlaybackMode> load();

  Future<void> save(PlaybackMode mode);
}
