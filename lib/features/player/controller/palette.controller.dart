import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../common/theme/app_palette.dart';
import 'player.provider.dart';

part 'palette.controller.g.dart';

/// The accent the app is coloured with, picked in the settings. The lamp
/// until the listener picks another.
@Riverpod(keepAlive: true)
class PaletteController extends _$PaletteController {
  @override
  Future<AppPalette> build() async {
    try {
      return AppPalette.fromName(
        await ref.read(displayPreferencesProvider).loadPalette(),
      );
    } on Object {
      return AppPalette.lamp;
    }
  }

  Future<void> set(AppPalette palette) async {
    // Shown at once; written behind it.
    state = AsyncData<AppPalette>(palette);
    try {
      await ref.read(displayPreferencesProvider).savePalette(palette.name);
    } on Object {
      // A setting that fails to save is picked again next time.
    }
  }
}
