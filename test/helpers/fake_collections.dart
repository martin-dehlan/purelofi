import 'dart:async';

import 'package:purelofi/features/player/domain/mood.entity.dart';
import 'package:purelofi/features/player/domain/playlist.entity.dart';
import 'package:purelofi/features/player/domain/playlist_sync.dart';

/// Moods in memory (#141).
class FakeMoodRepository implements MoodRepository {
  FakeMoodRepository([this.moods = const <MoodEntity>[]]);

  final List<MoodEntity> moods;

  @override
  Future<List<MoodEntity>> getMoods() async => moods;
}

/// Playlists in memory, both as the app's store and the sync's device side.
class FakePlaylistRepository implements PlaylistRepository, DevicePlaylists {
  FakePlaylistRepository([List<PlaylistEntity>? playlists])
    : playlists = <String, (PlaylistEntity, bool)>{
        for (final PlaylistEntity p in playlists ?? <PlaylistEntity>[])
          p.id: (p, false),
      };

  final Map<String, (PlaylistEntity, bool)> playlists;
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );
  int _next = 1;
  DateTime _clock = DateTime(2026, 11, 5);

  DateTime _tick() => _clock = _clock.add(const Duration(seconds: 1));

  List<PlaylistEntity> get _live =>
      <PlaylistEntity>[
        for (final (PlaylistEntity, bool) p in playlists.values)
          if (!p.$1.isDeleted) p.$1,
      ]..sort(
        (PlaylistEntity a, PlaylistEntity b) =>
            b.updatedAt.compareTo(a.updatedAt),
      );

  @override
  Stream<List<PlaylistEntity>> watchPlaylists() =>
      Stream<List<PlaylistEntity>>.multi((
        MultiStreamController<List<PlaylistEntity>> out,
      ) {
        out.add(_live);
        final StreamSubscription<void> sub = _changes.stream.listen(
          (_) => out.add(_live),
        );
        out.onCancel = sub.cancel;
      });

  void _put(PlaylistEntity p, {bool synced = false}) {
    playlists[p.id] = (p, synced);
    _changes.add(null);
  }

  Future<void> _change(
    String id,
    PlaylistEntity Function(PlaylistEntity) f,
  ) async {
    final (PlaylistEntity, bool)? p = playlists[id];
    if (p == null) return;
    _put(f(p.$1).copyWith(updatedAt: _tick()));
  }

  @override
  Future<String> create(String name) async {
    final String id = 'p${_next++}';
    _put(PlaylistEntity(id: id, name: name, updatedAt: _tick()));
    return id;
  }

  @override
  Future<void> rename(String id, String name) =>
      _change(id, (PlaylistEntity p) => p.copyWith(name: name));

  @override
  Future<void> delete(String id) =>
      _change(id, (PlaylistEntity p) => p.copyWith(deletedAt: _clock));

  @override
  Future<void> add(String id, PlaylistItem item) => _change(
    id,
    (PlaylistEntity p) => p.copyWith(items: <PlaylistItem>[...p.items, item]),
  );

  @override
  Future<void> removeAt(String id, int index) => _change(
    id,
    (PlaylistEntity p) =>
        p.copyWith(items: <PlaylistItem>[...p.items]..removeAt(index)),
  );

  @override
  Future<void> move(String id, int from, int to) =>
      _change(id, (PlaylistEntity p) {
        final List<PlaylistItem> items = <PlaylistItem>[...p.items];
        items.insert(to, items.removeAt(from));
        return p.copyWith(items: items);
      });

  @override
  Future<List<(PlaylistEntity, bool)>> all() async => playlists.values.toList();

  @override
  Future<void> putSynced(List<PlaylistEntity> list) async {
    for (final PlaylistEntity p in list) {
      _put(p, synced: true);
    }
  }

  @override
  Future<void> markSynced(Iterable<String> ids) async {
    for (final String id in ids) {
      final (PlaylistEntity, bool)? p = playlists[id];
      if (p != null) playlists[id] = (p.$1, true);
    }
  }

  Future<void> dispose() => _changes.close();
}

/// The account's playlists in memory.
class FakeAccountPlaylists implements AccountPlaylists {
  final Map<String, PlaylistEntity> rows = <String, PlaylistEntity>{};
  int upserts = 0;

  @override
  Future<List<PlaylistEntity>> fetchAll() async => rows.values.toList();

  @override
  Future<void> upsert(String userId, List<PlaylistEntity> playlists) async {
    upserts++;
    for (final PlaylistEntity p in playlists) {
      rows[p.id] = p;
    }
  }
}
