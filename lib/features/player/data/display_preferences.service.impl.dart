import 'package:shared_preferences/shared_preferences.dart';

import '../domain/display_preferences.service.dart';

/// One value in the platform's preferences store. Anything unreadable falls
/// back to hiding, which is how the app has always behaved.
class DisplayPreferencesImpl implements DisplayPreferences {
  DisplayPreferencesImpl([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _autoHideKey = 'display.autoHide';

  final SharedPreferencesAsync _preferences;

  @override
  Future<bool> loadAutoHide() async {
    try {
      return await _preferences.getBool(_autoHideKey) ?? true;
    } on Object {
      return true;
    }
  }

  @override
  Future<void> saveAutoHide(bool autoHide) =>
      _preferences.setBool(_autoHideKey, autoHide);
}
