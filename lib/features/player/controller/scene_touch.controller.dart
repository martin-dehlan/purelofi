import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'scene_touch.controller.g.dart';

/// Whether the last touch landed on something in the scene.
///
/// The scene and the chrome both want taps. The scene sees the pointer first
/// and, if it hit something interactive, says so here; the chrome then leaves
/// that tap alone instead of showing the transport again.
@riverpod
class SceneTouchController extends _$SceneTouchController {
  @override
  bool build() => false;

  /// The scene handled this touch.
  void consume() => state = true;

  /// Reads the flag and clears it.
  bool take() {
    final bool consumed = state;
    state = false;

    return consumed;
  }
}
