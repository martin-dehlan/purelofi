/// Pixel-art asset paths.
///
/// The retro character of the app comes from these PNGs and the scene videos,
/// never from Flutter styling (see `docs/09`). Render them with
/// `FilterQuality.none` so they stay crisp when scaled.
abstract final class AppAssets {
  static const String playIcon = 'assets/icons/play_icon.png';
  static const String pauseIcon = 'assets/icons/pause_icon.png';
  static const String cameraIcon = 'assets/icons/camera_icon.png';
  static const String prevIcon = 'assets/icons/prev_icon.png';
  static const String nextIcon = 'assets/icons/next_icon.png';
  static const String settingsIcon = 'assets/icons/settings_icon.png';
  static const String sceneSwitchIcon = 'assets/icons/scene_switch_icon.png';
}
