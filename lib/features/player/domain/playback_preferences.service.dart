import 'playback_mode.dart';

/// Where shuffle and repeat are kept between launches, and how one track
/// gives way to the next.
abstract class PlaybackPreferences {
  Future<PlaybackMode> load();

  Future<void> save(PlaybackMode mode);

  /// Whether tracks fade into each other (#139). On unless turned off.
  Future<bool> loadSoftTransitions();

  Future<void> saveSoftTransitions(bool enabled);

  /// Whether the stream plays the room's mood (#143). Off unless turned on.
  Future<bool> loadFollowRoom();

  Future<void> saveFollowRoom(bool enabled);
}
