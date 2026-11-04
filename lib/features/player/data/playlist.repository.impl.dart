import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../../common/database/app_database.dart';
import '../../../common/database/daos/playlist.dao.dart';
import '../domain/playlist.entity.dart';
import '../domain/playlist_sync.dart';
import 'playlist_items.codec.dart';

/// The listener's playlists in Drift (#141): what the app plays from, and
/// the device's side of the sync.
class PlaylistRepositoryImpl implements PlaylistRepository, DevicePlaylists {
  PlaylistRepositoryImpl(
    this._dao, {
    String Function()? newId,
    DateTime Function()? now,
    void Function()? onChange,
  }) : _newId = newId ?? const Uuid().v4,
       _now = now ?? DateTime.now,
       _onChange = onChange;

  final PlaylistDao _dao;
  final String Function() _newId;
  final DateTime Function() _now;

  /// Told after every change, so a signed-in listener's sync can follow.
  final void Function()? _onChange;

  @override
  Stream<List<PlaylistEntity>> watchPlaylists() => _dao.watchLive().map(
    (List<PlaylistTableData> rows) => rows.map(_toEntity).toList(),
  );

  @override
  Future<String> create(String name) async {
    final String id = _newId();
    await _write(PlaylistEntity(id: id, name: name.trim(), updatedAt: _now()));
    return id;
  }

  @override
  Future<void> rename(String id, String name) =>
      _change(id, (PlaylistEntity p) => p.copyWith(name: name.trim()));

  @override
  Future<void> delete(String id) =>
      _change(id, (PlaylistEntity p) => p.copyWith(deletedAt: _now()));

  @override
  Future<void> add(String id, PlaylistItem item) => _change(
    id,
    (PlaylistEntity p) => p.copyWith(items: <PlaylistItem>[...p.items, item]),
  );

  @override
  Future<void> removeAt(String id, int index) =>
      _change(id, (PlaylistEntity p) {
        if (index < 0 || index >= p.items.length) return p;
        return p.copyWith(items: <PlaylistItem>[...p.items]..removeAt(index));
      });

  @override
  Future<void> move(String id, int from, int to) =>
      _change(id, (PlaylistEntity p) {
        final int length = p.items.length;
        if (from < 0 || from >= length || to < 0 || to >= length) return p;
        final List<PlaylistItem> items = <PlaylistItem>[...p.items];
        items.insert(to, items.removeAt(from));
        return p.copyWith(items: items);
      });

  @override
  Future<List<(PlaylistEntity, bool)>> all() async => <(PlaylistEntity, bool)>[
    for (final PlaylistTableData row in await _dao.getAll())
      (_toEntity(row), row.isSynced),
  ];

  @override
  Future<void> putSynced(List<PlaylistEntity> playlists) async {
    for (final PlaylistEntity p in playlists) {
      await _dao.put(_toRow(p, synced: true));
    }
  }

  @override
  Future<void> markSynced(Iterable<String> ids) => _dao.markSynced(ids);

  Future<void> _change(
    String id,
    PlaylistEntity Function(PlaylistEntity) change,
  ) async {
    final PlaylistTableData? row = await _dao.find(id);
    if (row == null) return;
    await _write(change(_toEntity(row)).copyWith(updatedAt: _now()));
  }

  Future<void> _write(PlaylistEntity playlist) async {
    await _dao.put(_toRow(playlist, synced: false));
    _onChange?.call();
  }

  static PlaylistTableCompanion _toRow(
    PlaylistEntity p, {
    required bool synced,
  }) => PlaylistTableCompanion(
    id: Value<String>(p.id),
    name: Value<String>(p.name),
    items: Value<String>(PlaylistItemsCodec.encode(p.items)),
    updatedAt: Value<DateTime>(p.updatedAt),
    deletedAt: Value<DateTime?>(p.deletedAt),
    isSynced: Value<bool>(synced),
  );

  static PlaylistEntity _toEntity(PlaylistTableData row) => PlaylistEntity(
    id: row.id,
    name: row.name,
    items: PlaylistItemsCodec.decode(row.items),
    updatedAt: row.updatedAt,
    deletedAt: row.deletedAt,
  );
}
