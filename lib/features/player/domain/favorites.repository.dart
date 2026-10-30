/// The tracks the listener marked, on this device.
///
/// The device is always what the app reads: a mark works at once, offline
/// and signed out alike. For a signed-in listener the marks also follow the
/// account (#78) — every toggle is left unsynced (`isSynced`) for
/// `syncFavorites` to take up, and the account's list comes back down.
abstract class FavoritesRepository {
  /// The favourite track ids, and every change to them.
  Stream<Set<String>> watchFavoriteIds();

  /// The favourite track ids right now.
  Future<Set<String>> getFavoriteIds();

  /// Marks or unmarks [trackId]. Returns what it now is.
  Future<bool> toggle(String trackId);
}
