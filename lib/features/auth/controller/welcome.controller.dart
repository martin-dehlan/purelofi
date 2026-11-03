import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/account.entity.dart';
import '../domain/welcome_preferences.service.dart';
import 'auth.provider.dart';

part 'welcome.controller.g.dart';

/// The sign-in offered once, on the very first launch, with a way past it.
///
/// It gates nothing: the music is already playing behind it and the same
/// sheet stays in the menu for later (#38).
@Riverpod(keepAlive: true)
class WelcomeController extends _$WelcomeController {
  @override
  void build() {}

  /// `true` once, when the offer is due: a first launch, nobody signed in.
  /// Marked as seen as soon as it is claimed, so a launch that ends with
  /// the sheet still up does not bring it back.
  Future<bool> claim() async {
    final WelcomePreferences preferences = ref.read(welcomePreferencesProvider);
    try {
      if (await preferences.loadSeen()) return false;
      final Account? account = ref.read(authRepositoryProvider).current;
      await preferences.markSeen();
      return account == null;
    } on Object {
      return false;
    }
  }
}
