/// The app's typefaces, all bundled (see `pubspec.yaml`).
///
/// The chrome is quiet so the rooms can be loud: the pixel art lives in the
/// scenes, not in the text over them (#67).
abstract final class AppFonts {
  /// Everything that is read. Set on the theme, so plain `TextStyle`s get it.
  static const String body = 'Karla';

  /// Durations and other numbers, so they line up in a column.
  static const String mono = 'DMMono';

  /// The PureLofi wordmark, and nothing else.
  static const String wordmark = 'PixelifySans';
}
