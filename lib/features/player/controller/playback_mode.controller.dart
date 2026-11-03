import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/playback_mode.dart';
import 'player.provider.dart';

part 'playback_mode.controller.g.dart';

/// The play order — shuffle, repeat or in order — remembered across
/// launches.
///
/// The player follows this — it hands the mode to the audio service, which
/// loops and shows it on the lock screen — and a change made there comes back
/// in through [set].
@Riverpod(keepAlive: true)
class PlaybackModeController extends _$PlaybackModeController {
  @override
  Future<PlaybackMode> build() async {
    try {
      return await ref.read(playbackPreferencesProvider).load();
    } on Object {
      return PlaybackMode.shuffle;
    }
  }

  /// The button: shuffle, then repeat, then in order, then round again.
  Future<void> cycle() => _update((PlaybackMode mode) => mode.following);

  Future<void> set(PlaybackMode mode) => _update((_) => mode);

  Future<void> _update(PlaybackMode Function(PlaybackMode) change) async {
    final PlaybackMode current = state.value ?? await future;
    final PlaybackMode next = change(current);
    if (next == current) return;

    // Shown at once; written behind it. A preference that fails to save is
    // one the listener sets again next time, not an error to show them.
    state = AsyncData<PlaybackMode>(next);
    try {
      await ref.read(playbackPreferencesProvider).save(next);
    } on Object {
      // Deliberately ignored, see above.
    }
  }
}
