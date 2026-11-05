import 'package:purelofi/features/player/domain/display_preferences.service.dart';

/// The display settings in memory: hiding on, unless a test says otherwise.
class FakeDisplayPreferences implements DisplayPreferences {
  FakeDisplayPreferences({
    this.autoHide = true,
    this.language,
    this.focusClockHides = true,
    this.palette,
  });

  bool autoHide;
  String? language;
  bool focusClockHides;
  String? palette;

  @override
  Future<bool> loadAutoHide() async => autoHide;

  @override
  Future<void> saveAutoHide(bool autoHide) async => this.autoHide = autoHide;

  @override
  Future<String?> loadLanguage() async => language;

  @override
  Future<void> saveLanguage(String? code) async => language = code;

  @override
  Future<bool> loadFocusClockHides() async => focusClockHides;

  @override
  Future<void> saveFocusClockHides(bool hides) async => focusClockHides = hides;

  @override
  Future<String?> loadPalette() async => palette;

  @override
  Future<void> savePalette(String name) async => palette = name;
}
