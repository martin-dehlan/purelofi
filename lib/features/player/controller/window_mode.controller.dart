import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/screen_awake.service.dart';
import 'controls_visibility.controller.dart';
import 'player.provider.dart';

part 'window_mode.controller.g.dart';

/// Window mode (#149): the room alone, no controls, the screen kept on —
/// a window on the desk or on a tablet stand. Not remembered: leaving the
/// app or the mode lets the screen sleep again.
@Riverpod(keepAlive: true)
class WindowModeController extends _$WindowModeController {
  @override
  bool build() {
    // Taken now: a provider cannot be read while it is being disposed.
    final ScreenAwake awake = ref.read(screenAwakeProvider);
    ref.onDispose(() => unawaited(awake.keep(false)));
    return false;
  }

  void enter() {
    state = true;
    unawaited(ref.read(screenAwakeProvider).keep(true));
    ref.read(controlsVisibilityControllerProvider.notifier).hideNow();
  }

  void leave() {
    state = false;
    unawaited(ref.read(screenAwakeProvider).keep(false));
    ref.read(controlsVisibilityControllerProvider.notifier).reveal();
  }
}
