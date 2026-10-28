import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'startup.controller.g.dart';

/// Whether the first room has been drawn yet.
///
/// Until it has, the start screen is all there is: a transport floating over
/// a loading bar is a player that looks ready and is not. Once the room is
/// up this stays true for the life of the app — a later scene switch is not
/// a start.
@Riverpod(keepAlive: true)
class StartupController extends _$StartupController {
  @override
  bool build() => false;

  /// The room is on screen, or has said why it cannot be.
  void finish() {
    if (!state) state = true;
  }
}
