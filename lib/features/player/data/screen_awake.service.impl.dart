import 'package:wakelock_plus/wakelock_plus.dart';

import '../domain/screen_awake.service.dart';

/// The platform's wake lock. A failure only means the screen may dim as
/// usual — never worth more than that.
class ScreenAwakeImpl implements ScreenAwake {
  const ScreenAwakeImpl();

  @override
  Future<void> keep(bool awake) async {
    try {
      await WakelockPlus.toggle(enable: awake);
    } on Object {
      // The screen dims as it always does.
    }
  }
}
