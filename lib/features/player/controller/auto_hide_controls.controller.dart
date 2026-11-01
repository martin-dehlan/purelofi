import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'player.provider.dart';

part 'auto_hide_controls.controller.g.dart';

/// Whether the controls step aside on their own — on unless the listener
/// turned it off in the settings.
@Riverpod(keepAlive: true)
class AutoHideControlsController extends _$AutoHideControlsController {
  @override
  Future<bool> build() async {
    try {
      return await ref.read(displayPreferencesProvider).loadAutoHide();
    } on Object {
      return true;
    }
  }

  Future<void> set(bool autoHide) async {
    // Shown at once; written behind it, as with the play order.
    state = AsyncData<bool>(autoHide);
    try {
      await ref.read(displayPreferencesProvider).saveAutoHide(autoHide);
    } on Object {
      // A setting that fails to save is set again next time.
    }
  }
}
