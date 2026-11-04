import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'player.provider.dart';

part 'soft_transitions.controller.g.dart';

/// Whether one track fades into the next (#139) — on unless the listener
/// turned it off in the settings.
///
/// The audio service does the fading; this keeps the setting and hands it
/// over, once when it is loaded and again on every change.
@Riverpod(keepAlive: true)
class SoftTransitionsController extends _$SoftTransitionsController {
  @override
  Future<bool> build() async {
    bool enabled;
    try {
      enabled = await ref
          .read(playbackPreferencesProvider)
          .loadSoftTransitions();
    } on Object {
      enabled = true;
    }
    unawaited(ref.read(audioPlayerServiceProvider).setSoftTransitions(enabled));

    return enabled;
  }

  Future<void> set(bool enabled) async {
    // Heard at once; written behind it, as with the play order.
    state = AsyncData<bool>(enabled);
    unawaited(ref.read(audioPlayerServiceProvider).setSoftTransitions(enabled));
    try {
      await ref.read(playbackPreferencesProvider).saveSoftTransitions(enabled);
    } on Object {
      // A setting that fails to save is set again next time.
    }
  }
}
