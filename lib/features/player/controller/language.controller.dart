import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'player.provider.dart';

part 'language.controller.g.dart';

/// The language the app reads in, as a language code, or `null` to follow
/// the phone — which it does until the listener picks one in the settings.
@Riverpod(keepAlive: true)
class LanguageController extends _$LanguageController {
  @override
  Future<String?> build() async {
    try {
      return await ref.read(displayPreferencesProvider).loadLanguage();
    } on Object {
      return null;
    }
  }

  Future<void> set(String? code) async {
    // Shown at once; written behind it.
    state = AsyncData<String?>(code);
    try {
      await ref.read(displayPreferencesProvider).saveLanguage(code);
    } on Object {
      // A setting that fails to save is picked again next time.
    }
  }
}
