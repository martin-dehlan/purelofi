/// What can be marked new (#148).
enum SeenKind { scene, track }

/// Where the "new" marks keep what the listener has met, on this device.
abstract class NewContentRepository {
  /// When the app was first opened here. Set on the first call, the same
  /// ever after.
  Future<DateTime> firstLaunch();

  /// The ids of [kind] already met.
  Stream<Set<String>> watchSeen(SeenKind kind);

  Future<void> markSeen(SeenKind kind, String id);
}

/// The ids of [items] that are new: added after [firstLaunch] — so a fresh
/// install does not mark everything — and not met yet.
Set<String> newIds<T>(
  Iterable<T> items, {
  required String Function(T) id,
  required DateTime? Function(T) createdAt,
  required DateTime firstLaunch,
  required Set<String> seen,
}) => <String>{
  for (final T item in items)
    if (createdAt(item)?.isAfter(firstLaunch) ?? false)
      if (!seen.contains(id(item))) id(item),
};
