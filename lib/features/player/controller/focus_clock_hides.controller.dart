import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'player.provider.dart';

part 'focus_clock_hides.controller.g.dart';

/// Whether the focus clock on the scene steps aside with the controls —
/// on unless the listener wants it in view the whole time.
@Riverpod(keepAlive: true)
class FocusClockHidesController extends _$FocusClockHidesController {
  @override
  Future<bool> build() async {
    try {
      return await ref.read(displayPreferencesProvider).loadFocusClockHides();
    } on Object {
      return true;
    }
  }

  Future<void> set(bool hides) async {
    state = AsyncData<bool>(hides);
    try {
      await ref.read(displayPreferencesProvider).saveFocusClockHides(hides);
    } on Object {
      // A setting that fails to save is set again next time.
    }
  }
}
