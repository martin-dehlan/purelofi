import 'package:purelofi/features/player/domain/screen_awake.service.dart';

/// The wake lock in memory (#149).
class FakeScreenAwake implements ScreenAwake {
  bool awake = false;

  @override
  Future<void> keep(bool awake) async => this.awake = awake;
}
