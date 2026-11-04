import 'package:purelofi/features/player/domain/mix_preferences.service.dart';

/// The mix in memory.
class FakeMixPreferences implements MixPreferences {
  FakeMixPreferences([this.stored = const MixSettings()]);

  MixSettings stored;
  int saves = 0;

  @override
  Future<MixSettings> load() async => stored;

  @override
  Future<void> save(MixSettings settings) async {
    stored = settings;
    saves++;
  }
}
