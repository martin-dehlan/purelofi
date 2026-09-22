import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'player.provider.dart';

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

  /// Marks or unmarks [trackId]. The stream carries the new state back.
  Future<void> toggle(String trackId) async {
    await ref.read(favoritesRepositoryProvider).toggle(trackId);
  }
}
