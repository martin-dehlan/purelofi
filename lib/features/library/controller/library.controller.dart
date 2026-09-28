import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../player/controller/player.controller.dart';
import '../../player/domain/player.state.dart';
import '../../player/domain/track.entity.dart';
import '../domain/import_report.dart';
import 'library.provider.dart';

part 'library.controller.g.dart';

/// The listener's own tracks, and the two things they can do with them:
/// bring more in, and take one out (#66).
///
/// Watched as a stream from the database, like the favourites, so an import
/// shows up in the list the moment its row is written.
@Riverpod(keepAlive: true)
class LibraryController extends _$LibraryController {
  @override
  Stream<List<TrackEntity>> build() =>
      ref.watch(libraryRepositoryProvider).watchTracks();

  /// Opens the system picker and copies in what the listener chose.
  ///
  /// `null` when they cancelled — nothing happened, so there is nothing to
  /// report.
  Future<ImportReport?> importFromDevice() async {
    final List<ImportSource> picked = await ref
        .read(trackPickerProvider)
        .pick();
    if (picked.isEmpty) return null;

    return ref.read(libraryRepositoryProvider).import(picked);
  }

  /// Removes [id] from the app. The listener's original is not touched.
  ///
  /// Taking out the track that is playing moves the stream on first, so the
  /// player is never left holding a file that no longer exists.
  Future<void> remove(String id) async {
    final PlayerState player = ref.read(playerControllerProvider);
    final bool isCurrent = player.currentTrack?.id == id;

    await ref.read(libraryRepositoryProvider).delete(id);

    if (isCurrent) await ref.read(playerControllerProvider.notifier).playNext();
  }
}
