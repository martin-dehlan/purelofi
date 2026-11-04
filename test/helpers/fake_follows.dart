import 'dart:async';

import 'package:purelofi/features/player/data/follows.impl.dart';
import 'package:purelofi/features/player/domain/favorites_sync.dart';

/// Follows in memory (#147).
class FakeDeviceFollows implements DeviceFollows {
  final Map<String, (bool followed, bool synced)> rows =
      <String, (bool, bool)>{};
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );

  Set<String> get _followed => <String>{
    for (final MapEntry<String, (bool, bool)> e in rows.entries)
      if (e.value.$1) e.key,
  };

  @override
  Stream<Set<String>> watchFollowed() =>
      Stream<Set<String>>.multi((MultiStreamController<Set<String>> out) {
        out.add(_followed);
        final StreamSubscription<void> sub = _changes.stream.listen(
          (_) => out.add(_followed),
        );
        out.onCancel = sub.cancel;
      });

  @override
  Future<void> set(String artistId, {required bool followed}) async {
    rows[artistId] = (followed, false);
    _changes.add(null);
  }

  @override
  Future<Map<String, bool>> pending() async => <String, bool>{
    for (final MapEntry<String, (bool, bool)> e in rows.entries)
      if (!e.value.$2) e.key: e.value.$1,
  };

  @override
  Future<void> markSynced(Iterable<String> ids) async {
    for (final String id in ids) {
      final (bool, bool)? r = rows[id];
      if (r != null) rows[id] = (r.$1, true);
    }
  }

  @override
  Future<void> apply(Set<String> accountIds) async {
    for (final String id in accountIds) {
      rows.putIfAbsent(id, () => (true, true));
    }
    _changes.add(null);
  }

  @override
  Future<void> release() async {}

  Future<void> dispose() => _changes.close();
}

/// The account's follows in memory.
class FakeAccountFollows implements AccountFavorites {
  final Set<String> ids = <String>{};

  @override
  Future<Set<String>> fetchIds() async => Set<String>.of(ids);

  @override
  Future<void> add(String userId, Iterable<String> artistIds) async =>
      ids.addAll(artistIds);

  @override
  Future<void> remove(Iterable<String> artistIds) async =>
      ids.removeAll(artistIds);
}
