import 'dart:ui' show Color;

/// The accent colours a listener can pick in the settings. Each one is a
/// light that could sit in a room: the app's whole scheme grows from it.
///
/// [lamp] comes first and is the default: the warm light every scene has
/// (`assets/palette/purelofi.gpl`, Lamp #F0A05D). The others are kept as
/// soft and as bright as it, so text on them reads the same.
enum AppPalette {
  lamp(Color(0xFFF0A05D)),
  moss(Color(0xFF9CC48A)),
  sea(Color(0xFF74B9D6)),
  dusk(Color(0xFFB3A1E6)),
  blossom(Color(0xFFE89AAE)),
  paper(Color(0xFFDDD5C7));

  const AppPalette(this.accent);

  /// The colour that marks what is active, and the seed of the scheme.
  final Color accent;

  /// The palette saved under [name], or [lamp] for none or one that is
  /// gone.
  static AppPalette fromName(String? name) {
    for (final AppPalette palette in values) {
      if (palette.name == name) return palette;
    }
    return lamp;
  }
}
