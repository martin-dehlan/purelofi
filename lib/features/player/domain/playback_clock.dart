/// Two clocks for one scene.
///
/// [sceneTime] always runs. [playingTime] only advances while audio plays,
/// and layers marked `only_while_playing` follow it — so the tape reels stop
/// with the music while the rain keeps falling.
class PlaybackClock {
  Duration _sceneTime = Duration.zero;
  Duration _playingTime = Duration.zero;
  Duration _lastTick = Duration.zero;

  Duration get sceneTime => _sceneTime;
  Duration get playingTime => _playingTime;

  /// Advances both clocks to [elapsed], the ticker's running total.
  void tick(Duration elapsed, {required bool isPlaying}) {
    final Duration delta = elapsed - _lastTick;
    _lastTick = elapsed;
    _sceneTime = elapsed;

    // A negative delta would mean the ticker restarted; ignore it rather
    // than running time backwards.
    if (isPlaying && delta > Duration.zero) _playingTime += delta;
  }
}
