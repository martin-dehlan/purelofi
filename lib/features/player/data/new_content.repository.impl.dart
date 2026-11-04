import 'package:shared_preferences/shared_preferences.dart';

import '../../../common/database/daos/seen_item.dao.dart';
import '../domain/new_content.dart';

/// The "new" marks' memory (#148): the first launch in the preferences,
/// what was seen in Drift.
class NewContentRepositoryImpl implements NewContentRepository {
  NewContentRepositoryImpl({
    required SeenItemDao dao,
    SharedPreferencesAsync? preferences,
    DateTime Function()? now,
  }) : _dao = dao,
       _preferences = preferences ?? SharedPreferencesAsync(),
       _now = now ?? DateTime.now;

  static const String _firstLaunchKey = 'content.firstLaunch';

  final SeenItemDao _dao;
  final SharedPreferencesAsync _preferences;
  final DateTime Function() _now;

  @override
  Future<DateTime> firstLaunch() async {
    try {
      final int? stored = await _preferences.getInt(_firstLaunchKey);
      if (stored != null) return DateTime.fromMillisecondsSinceEpoch(stored);
    } on Object {
      // Falls through: treated as a first launch now.
    }
    final DateTime now = _now();
    try {
      await _preferences.setInt(_firstLaunchKey, now.millisecondsSinceEpoch);
    } on Object {
      // Not remembered: the next launch counts as first again, which only
      // means nothing is marked new. Never wrong, at worst quiet.
    }
    return now;
  }

  @override
  Stream<Set<String>> watchSeen(SeenKind kind) => _dao.watchIds(kind.name);

  @override
  Future<void> markSeen(SeenKind kind, String id) =>
      _dao.markSeen(kind.name, id, _now());
}
