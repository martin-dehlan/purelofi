import 'package:shared_preferences/shared_preferences.dart';

import '../domain/library_preferences.service.dart';
import '../domain/library_view.dart';

/// One small value in the platform's preferences store. Anything unreadable
/// — a value from a later version, say — falls back to the default rather
/// than failing the menu.
class LibraryPreferencesImpl implements LibraryPreferences {
  LibraryPreferencesImpl([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _sortKey = 'library.sort';

  final SharedPreferencesAsync _preferences;

  @override
  Future<LibraryView> load() async {
    try {
      return LibraryView(
        sort: _byName(
          LibrarySort.values,
          await _preferences.getString(_sortKey),
          LibrarySort.recent,
        ),
      );
    } on Object {
      return const LibraryView();
    }
  }

  @override
  Future<void> save(LibraryView view) async {
    await _preferences.setString(_sortKey, view.sort.name);
  }

  static T _byName<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final T value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}
