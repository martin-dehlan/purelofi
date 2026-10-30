import '../../../common/database/app_database.dart';
import '../../../common/database/daos/track.dao.dart';
import '../domain/favorites_sync.dart';

/// The device's marks, in the cached track rows (#78).
class DeviceFavoritesImpl implements DeviceFavorites {
  const DeviceFavoritesImpl(this._dao);

  final TrackDao _dao;

  @override
  Future<Map<String, bool>> pending() async => <String, bool>{
    for (final TrackTableData row in await _dao.getUnsyncedMarks())
      row.id: row.isFavorite,
  };

  @override
  Future<void> markSynced(Iterable<String> ids) => _dao.markSynced(ids);

  @override
  Future<void> apply(Set<String> accountIds) =>
      _dao.applyAccountFavorites(accountIds);

  @override
  Future<void> release() => _dao.releaseMarks();
}
