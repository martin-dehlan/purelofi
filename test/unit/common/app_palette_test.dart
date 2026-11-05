import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/common/theme/app_palette.dart';
import 'package:purelofi/common/theme/app_theme.dart';

void main() {
  test('a saved palette is found by name; none or a gone one is the lamp', () {
    expect(AppPalette.fromName('sea'), AppPalette.sea);
    expect(AppPalette.fromName(null), AppPalette.lamp);
    expect(AppPalette.fromName('neon'), AppPalette.lamp);
  });

  test('every palette is dark with its own accent, built once', () {
    for (final AppPalette palette in AppPalette.values) {
      final ThemeData theme = AppTheme.of(palette);
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, palette.accent);
      expect(identical(AppTheme.of(palette), theme), isTrue);
    }
    expect(appTheme.colorScheme.primary, AppPalette.lamp.accent);
  });
}
