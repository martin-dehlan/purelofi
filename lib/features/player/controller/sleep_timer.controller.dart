import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/audio_player.service.dart';
import '../domain/player.state.dart';
import '../domain/volume_fader.dart';
import '../domain/volume_layer.dart';
import 'player.controller.dart';
import 'player.provider.dart';

part 'sleep_timer.controller.g.dart';

/// When the music stops on its own, or `null` when it plays on.
///
/// A moment rather than a countdown: the menu says "Stops at 23:40", which
/// needs no ticking. The timer pauses, and nothing else — the room stays,
/// and play picks up where it left off.
///
/// It does not cut the music off: the last [fadeLength] goes down to
/// silence first (#138), because a sudden stop is what wakes someone who
/// was nearly asleep. Turned off mid-fade, the music is back at once.
@Riverpod(keepAlive: true)
class SleepTimerController extends _$SleepTimerController {
  Timer? _timer;
  Timer? _fadeStart;
  VolumeFader? _fader;

  /// How long the music takes to go quiet before the pause.
  static const Duration fadeLength = Duration(seconds: 30);

  @override
  DateTime? build() {
    ref.onDispose(() {
      _timer?.cancel();
      _fadeStart?.cancel();
      _fader?.cancel();
    });
    return null;
  }

  AudioPlayerService get _audio => ref.read(audioPlayerServiceProvider);

  VolumeFader get _volume => _fader ??= VolumeFader(
    (double level) => _audio.setVolumeLayer(VolumeLayer.sleepTimer, level),
  );

  /// Stops the music [after] from now, replacing any timer set before.
  void start(Duration after) {
    _stopTimers();
    _volume.jumpTo(1);

    // A timer shorter than the fade fades over all of it.
    final Duration fade = after < fadeLength ? after : fadeLength;
    _fadeStart = Timer(after - fade, () => _volume.fadeTo(0, fade));
    _timer = Timer(after, _fire);
    state = DateTime.now().add(after);
  }

  /// Stops the music when the track playing ends. Nothing playing, or a
  /// length not known yet, sets nothing.
  void endOfTrack() {
    final PlayerState player = ref.read(playerControllerProvider);
    final Duration? duration = player.duration;
    if (player.currentTrack == null || duration == null) return;

    // A beat early: pausing on the last note is better than letting the
    // next track begin and cutting it off.
    final Duration left = duration - player.position - _beforeTheEnd;
    start(left.isNegative ? Duration.zero : left);
  }

  void cancel() {
    _stopTimers();
    if (_fader != null) _volume.jumpTo(1);
    state = null;
  }

  Future<void> _fire() async {
    _timer = null;
    state = null;
    // The fade's last step and the pause land on the same moment; the pause
    // must not wait for it.
    _volume.jumpTo(0);
    await ref.read(playerControllerProvider.notifier).pause();
    // Paused, the level does not matter any more; the next play is at full
    // volume.
    _volume.jumpTo(1);
  }

  void _stopTimers() {
    _timer?.cancel();
    _timer = null;
    _fadeStart?.cancel();
    _fadeStart = null;
    _fader?.cancel();
  }

  static const Duration _beforeTheEnd = Duration(milliseconds: 300);
}
