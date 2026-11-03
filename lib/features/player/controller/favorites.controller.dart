import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/track.entity.dart';
import 'favorites_sync.controller.dart';
import 'player.provider.dart';
import 'track.controller.dart';

part 'favorites.controller.g.dart';

/// Which tracks are marked, and the one way to change that.
///
/// Kept alive and watched as a stream: the mark is written to the database
/// and read back from it, so the heart in the chrome and the weighting in
/// the shuffle can never disagree about what is favourited.
@Riverpod(keepAlive: true)
class FavoritesController extends _$FavoritesController {
  @override
  Stream<Set<String>> build() =>
      ref.watch(favoritesRepositoryProvider).watchFavoriteIds();

  /// Marks or unmarks [trackId]. The stream carries the new state back, and
  /// a signed-in listener's account hears about it shortly after (#78).
  Future<void> toggle(String trackId) async {
    await ref.read(favoritesRepositoryProvider).toggle(trackId);
    ref.read(favoritesSyncControllerProvider.notifier).soon();
  }
}

/// The marked tracks themselves, in the order the catalogue lists them.
///
/// Derived rather than queried: the marks are ids, the catalogue is already
/// loaded, and joining them here keeps one list of tracks in the app instead
/// of two that can disagree.
@riverpod
List<TrackEntity> favoriteTracks(Ref ref) {
  final Set<String> marked =
      ref.watch(favoritesControllerProvider).value ?? const <String>{};
  if (marked.isEmpty) return const <TrackEntity>[];

  final List<TrackEntity> all =
      ref.watch(trackListControllerProvider).value ?? const <TrackEntity>[];

  return all.where((TrackEntity track) => marked.contains(track.id)).toList();
}
