import 'package:flutter/material.dart';

import '../utils/app_fonts.dart';
import 'app_palette.dart';

/// Dark, with quiet type.
///
/// The pixel art belongs to the rooms. Chrome that repeats it reads as a
/// costume, and Pixelify Sans across every label was exactly that. Karla is
/// plain and a little warm, so the text stays out of the scene's way; the
/// pixel face is kept for the wordmark alone (#67).
///
/// The one accent is the palette's light ([AppPalette.accent]). It marks
/// what is active — the track playing, the room you are in.
///
/// The rest of the scheme is grown from that same light by Material's tonal
/// palettes, so the containers behind a selected row or segment are a dim
/// tone that belongs with it, not Material's default violet. Neutral, so
/// the sheets stay near grey: a coloured sheet over a blue room is mud.
abstract final class AppTheme {
  /// Text and glyphs on the accent: the scenes' darkest colour.
  static const Color _onAccent = Color(0xFF030308);

  static final Map<AppPalette, ThemeData> _built = <AppPalette, ThemeData>{};

  /// The theme for [palette], built once and kept.
  static ThemeData of(AppPalette palette) =>
      _built.putIfAbsent(palette, () => _build(palette));

  static ThemeData _build(AppPalette palette) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.neutral,
    ).copyWith(primary: palette.accent, onPrimary: _onAccent);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: ThemeData.dark(
        useMaterial3: true,
      ).textTheme.apply(fontFamily: AppFonts.body),
      // Every sheet in the app is a Material sheet: a handle to drag it by
      // and the low container tone, a step off the scene's darkest colours.
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: scheme.surfaceContainerLow,
        dragHandleColor: scheme.onSurfaceVariant,
      ),
      listTileTheme: ListTileThemeData(
        selectedColor: scheme.primary,
        selectedTileColor: scheme.secondaryContainer,
        iconColor: scheme.onSurfaceVariant,
      ),
    );
  }
}

/// The app's default theme, public so widget tests can render with it.
final ThemeData appTheme = AppTheme.of(AppPalette.lamp);
