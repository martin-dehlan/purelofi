import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'controls_visibility.controller.g.dart';

/// Whether the player chrome is on screen.
///
/// The scene is the hero, so the controls step out of the way after a few
/// seconds of stillness and come back on any tap (see `docs/09`).
@riverpod
class ControlsVisibilityController extends _$ControlsVisibilityController {
  static const Duration idleTimeout = Duration(seconds: 4);

  Timer? _timer;

  @override
  bool build() {
    ref.onDispose(() => _timer?.cancel());
    _scheduleHide();
    return true;
  }

  /// Shows the controls and restarts the countdown.
  void reveal() {
    state = true;
    _scheduleHide();
  }

  void hideNow() {
    _timer?.cancel();
    state = false;
  }

  void _scheduleHide() {
    _timer?.cancel();
    _timer = Timer(idleTimeout, () {
      if (ref.mounted) state = false;
    });
  }
}
