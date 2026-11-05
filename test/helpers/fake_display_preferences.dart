import 'package:purelofi/features/player/domain/display_preferences.service.dart';

/// The display settings in memory: hiding on, unless a test says otherwise.
class FakeDisplayPreferences implements DisplayPreferences {
  FakeDisplayPreferences({this.autoHide = true, this.language});

  bool autoHide;
  String? language;

  @override
  Future<bool> loadAutoHide() async => autoHide;

  @override
  Future<void> saveAutoHide(bool autoHide) async => this.autoHide = autoHide;

  @override
  Future<String?> loadLanguage() async => language;

  @override
  Future<void> saveLanguage(String? code) async => language = code;
}
