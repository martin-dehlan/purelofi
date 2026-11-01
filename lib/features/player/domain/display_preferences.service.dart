/// How the player looks, kept between launches.
abstract class DisplayPreferences {
  /// Whether the controls step aside after a few seconds without a tap.
  Future<bool> loadAutoHide();

  Future<void> saveAutoHide(bool autoHide);
}
