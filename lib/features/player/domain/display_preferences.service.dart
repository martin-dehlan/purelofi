/// How the player looks, kept between launches.
abstract class DisplayPreferences {
  /// Whether the controls step aside after a few seconds without a tap.
  Future<bool> loadAutoHide();

  Future<void> saveAutoHide(bool autoHide);

  /// The language picked in the app, as a language code, or `null` to
  /// follow the phone.
  Future<String?> loadLanguage();

  Future<void> saveLanguage(String? code);

  /// Whether the focus clock on the scene steps aside with the controls.
  Future<bool> loadFocusClockHides();

  Future<void> saveFocusClockHides(bool hides);
}
