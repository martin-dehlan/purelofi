import 'package:shared_preferences/shared_preferences.dart';

import '../domain/display_preferences.service.dart';

/// One value in the platform's preferences store. Anything unreadable falls
/// back to hiding, which is how the app has always behaved.
class DisplayPreferencesImpl implements DisplayPreferences {
  DisplayPreferencesImpl([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _autoHideKey = 'display.autoHide';
  static const String _languageKey = 'display.language';
  static const String _focusClockHidesKey = 'display.focusClockHides';
  static const String _paletteKey = 'display.palette';

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

  @override
  Future<String?> loadLanguage() async {
    try {
      return await _preferences.getString(_languageKey);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> saveLanguage(String? code) => code == null
      ? _preferences.remove(_languageKey)
      : _preferences.setString(_languageKey, code);

  @override
  Future<bool> loadFocusClockHides() async {
    try {
      return await _preferences.getBool(_focusClockHidesKey) ?? true;
    } on Object {
      return true;
    }
  }

  @override
  Future<void> saveFocusClockHides(bool hides) =>
      _preferences.setBool(_focusClockHidesKey, hides);

  @override
  Future<String?> loadPalette() async {
    try {
      return await _preferences.getString(_paletteKey);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> savePalette(String name) =>
      _preferences.setString(_paletteKey, name);
}
