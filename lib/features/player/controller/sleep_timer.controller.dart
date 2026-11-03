import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/player.state.dart';
import 'player.controller.dart';

part 'sleep_timer.controller.g.dart';

/// When the music stops on its own, or `null` when it plays on.
///
/// A moment rather than a countdown: the menu says "Stops at 23:40", which
/// needs no ticking. The timer pauses, and nothing else — the room stays,
/// and play picks up where it left off.
@Riverpod(keepAlive: true)
class SleepTimerController extends _$SleepTimerController {
  Timer? _timer;

  @override
  DateTime? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  /// Stops the music [after] from now, replacing any timer set before.
  void start(Duration after) {
    _timer?.cancel();
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
    _timer?.cancel();
    _timer = null;
    state = null;
  }

  Future<void> _fire() async {
    _timer = null;
    state = null;
    await ref.read(playerControllerProvider.notifier).pause();
  }

  static const Duration _beforeTheEnd = Duration(milliseconds: 300);
}
