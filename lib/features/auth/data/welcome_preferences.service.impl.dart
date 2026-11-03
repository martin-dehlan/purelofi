import 'package:shared_preferences/shared_preferences.dart';

import '../domain/welcome_preferences.service.dart';

/// One flag in the platform's preferences store. Anything unreadable counts
/// as seen: a second offer is worse than a missed one.
class WelcomePreferencesImpl implements WelcomePreferences {
  WelcomePreferencesImpl([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _seenKey = 'welcome.seen';

  final SharedPreferencesAsync _preferences;

  @override
  Future<bool> loadSeen() async {
    try {
      return await _preferences.getBool(_seenKey) ?? false;
    } on Object {
      return true;
    }
  }

  @override
  Future<void> markSeen() => _preferences.setBool(_seenKey, true);
}
