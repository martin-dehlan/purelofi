import 'playlist.entity.dart';

/// The account's side of the playlists, as the sync sees it (#141).
abstract class AccountPlaylists {
  /// Every playlist on the account, deleted ones included.
  Future<List<PlaylistEntity>> fetchAll();

  Future<void> upsert(String userId, List<PlaylistEntity> playlists);
}

/// The device's side.
abstract class DevicePlaylists {
  /// Every playlist here, deleted ones included, and whether each has been
  /// synced since it last changed.
  Future<List<(PlaylistEntity, bool synced)>> all();

  /// Writes what the account had, as synced.
  Future<void> putSynced(List<PlaylistEntity> playlists);

  Future<void> markSynced(Iterable<String> ids);
}

/// What one round of syncing does: what goes up, what comes down.
typedef PlaylistMerge = ({
  List<PlaylistEntity> push,
  List<PlaylistEntity> pull,
});

/// The newer copy of each playlist wins, by `updatedAt`; a deletion is a
/// change like any other. A playlist only on one side goes to the other.
///
/// A device copy that is synced and unchanged never goes up, even if its
/// clock is ahead: it is the account's copy already.
PlaylistMerge mergePlaylists({
  required List<(PlaylistEntity, bool synced)> device,
  required List<PlaylistEntity> account,
}) {
  final Map<String, PlaylistEntity> remote = <String, PlaylistEntity>{
    for (final PlaylistEntity p in account) p.id: p,
  };
  final Map<String, (PlaylistEntity, bool)> local =
      <String, (PlaylistEntity, bool)>{for (final d in device) d.$1.id: d};

  final List<PlaylistEntity> push = <PlaylistEntity>[];
  final List<PlaylistEntity> pull = <PlaylistEntity>[];

  for (final String id in <String>{...remote.keys, ...local.keys}) {
    final PlaylistEntity? theirs = remote[id];
    final (PlaylistEntity, bool)? ours = local[id];

    if (ours == null) {
      pull.add(theirs!);
    } else if (theirs == null) {
      push.add(ours.$1);
    } else if (!ours.$2 && ours.$1.updatedAt.isAfter(theirs.updatedAt)) {
      push.add(ours.$1);
    } else if (theirs.updatedAt.isAfter(ours.$1.updatedAt) || ours.$2) {
      if (theirs != ours.$1) pull.add(theirs);
    } else {
      push.add(ours.$1);
    }
  }

  return (push: push, pull: pull);
}

/// One round: what changed here goes up, what changed elsewhere comes down.
Future<void> syncPlaylists({
  required String userId,
  required DevicePlaylists device,
  required AccountPlaylists account,
}) async {
  final PlaylistMerge merge = mergePlaylists(
    device: await device.all(),
    account: await account.fetchAll(),
  );

  if (merge.push.isNotEmpty) {
    await account.upsert(userId, merge.push);
    await device.markSynced(merge.push.map((PlaylistEntity p) => p.id));
  }
  if (merge.pull.isNotEmpty) await device.putSynced(merge.pull);
}
