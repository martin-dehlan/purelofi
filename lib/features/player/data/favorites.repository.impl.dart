import '../../../common/database/app_database.dart';
import '../../../common/database/daos/track.dao.dart';
import '../../../common/errors/error_mapper.dart';
import '../domain/favorites.repository.dart';

/// Favourites on top of the cached track rows.
///
/// They live in the same table the content cache fills, which is why a
/// favourite disappears when the server stops listing the track: a mark on
/// something nobody can play any more is not worth keeping.
class FavoritesRepositoryImpl implements FavoritesRepository {
  const FavoritesRepositoryImpl({required TrackDao dao}) : _dao = dao;

  final TrackDao _dao;

  @override
  Stream<Set<String>> watchFavoriteIds() => _dao.watchFavorites().map(
    (List<TrackTableData> rows) =>
        rows.map((TrackTableData row) => row.id).toSet(),
  );

  @override
  Future<Set<String>> getFavoriteIds() async {
    try {
      final List<TrackTableData> rows = await _dao.getFavorites();

      return rows.map((TrackTableData row) => row.id).toSet();
    } on Object catch (error, stackTrace) {
      throw ErrorMapper.fromException(error, stackTrace);
    }
  }

  @override
  Future<bool> toggle(String trackId) async {
    try {
      final TrackTableData? row = await _dao.getTrackById(trackId);
      // Nothing to mark: the track is not in the cache, which means it was
      // never fetched or has just been dropped from the catalogue.
      if (row == null) return false;

      final bool next = !row.isFavorite;
      await _dao.setFavorite(trackId, isFavorite: next);

      return next;
    } on Object catch (error, stackTrace) {
      throw ErrorMapper.fromException(error, stackTrace);
    }
  }
}
