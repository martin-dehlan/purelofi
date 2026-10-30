/// The account's side of the favorites, as the sync sees it (#78).
abstract class AccountFavorites {
  Future<Set<String>> fetchIds();

  Future<void> add(String userId, Iterable<String> trackIds);

  Future<void> remove(Iterable<String> trackIds);
}

/// The device's side: the marks in the local database.
abstract class DeviceFavorites {
  /// Marks the account has not seen yet, and whether each is on or off.
  Future<Map<String, bool>> pending();

  Future<void> markSynced(Iterable<String> ids);

  /// The synced marks now match the account; pending ones are untouched.
  Future<void> apply(Set<String> accountIds);

  /// After sign-out: every mark is the device's own again.
  Future<void> release();
}

/// One round of keeping a signed-in listener's favorites the same on every
/// device.
///
/// Push first, then pull: a mark made here — offline, or before signing in —
/// is newer than the account's copy, so it goes up before the account's list
/// comes down. That order is also what makes the first sign-in a union
/// rather than a replacement: the device's marks are all pending, so they
/// all go up, and nothing on either side is lost.
Future<void> syncFavorites({
  required String userId,
  required DeviceFavorites device,
  required AccountFavorites account,
}) async {
  final Map<String, bool> pending = await device.pending();

  final List<String> marked = <String>[
    for (final MapEntry<String, bool> e in pending.entries)
      if (e.value) e.key,
  ];
  final List<String> unmarked = <String>[
    for (final MapEntry<String, bool> e in pending.entries)
      if (!e.value) e.key,
  ];

  await account.add(userId, marked);
  await account.remove(unmarked);
  await device.markSynced(pending.keys);

  await device.apply(await account.fetchIds());
}
