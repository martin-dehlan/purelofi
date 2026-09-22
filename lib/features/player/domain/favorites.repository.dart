/// The tracks the listener marked. Local only.
///
/// There is no account to tie them to, so nothing is sent anywhere: the
/// marks live on this device and survive a restart because they are in the
/// same database the content cache uses. When accounts arrive (`#38`) this
/// is the seam that grows a sync — which is what `isSynced` on the table is
/// already there for.
abstract class FavoritesRepository {
  /// The favourite track ids, and every change to them.
  Stream<Set<String>> watchFavoriteIds();

  /// The favourite track ids right now.
  Future<Set<String>> getFavoriteIds();

  /// Marks or unmarks [trackId]. Returns what it now is.
  Future<bool> toggle(String trackId);
}
