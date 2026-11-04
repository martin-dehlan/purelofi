import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/artist.entity.dart';
import '../domain/content.repository.dart';
import '../domain/track.entity.dart';
import 'player.provider.dart';
import 'track.controller.dart';

part 'artist.controller.g.dart';

/// The artists behind PureLofi's tracks, by name. Kept alive like the
/// tracks: both are the app's content.
@Riverpod(keepAlive: true)
class ArtistListController extends _$ArtistListController {
  @override
  Future<List<ArtistEntity>> build() {
    final ContentRepository content = ref.watch(contentRepositoryProvider);
    onLateUpdate(
      ref,
      content,
      () => content.getArtists(cachedOnly: true),
      (List<ArtistEntity> artists) =>
          state = AsyncData<List<ArtistEntity>>(artists),
    );
    return content.getArtists();
  }
}

/// The artists with at least one track to play: a page with nothing on it
/// is not worth opening.
@riverpod
List<ArtistEntity> playableArtists(Ref ref) {
  final List<ArtistEntity> artists =
      ref.watch(artistListControllerProvider).value ?? const <ArtistEntity>[];
  final Set<String> credited = <String>{
    for (final TrackEntity track
        in ref.watch(trackListControllerProvider).value ??
            const <TrackEntity>[])
      ?track.artistId,
  };

  return artists
      .where((ArtistEntity artist) => credited.contains(artist.id))
      .toList();
}

/// One artist, once the list is in; `null` while it loads or for an id it
/// does not hold.
@riverpod
ArtistEntity? artistById(Ref ref, String id) {
  final List<ArtistEntity> artists =
      ref.watch(artistListControllerProvider).value ?? const <ArtistEntity>[];
  for (final ArtistEntity artist in artists) {
    if (artist.id == id) return artist;
  }
  return null;
}

/// An artist's tracks, oldest first, the order they were added in.
@riverpod
List<TrackEntity> artistTracks(Ref ref, String artistId) {
  final List<TrackEntity> all =
      ref.watch(trackListControllerProvider).value ?? const <TrackEntity>[];

  return all.where((TrackEntity track) => track.artistId == artistId).toList()
    ..sort(
      (TrackEntity a, TrackEntity b) => a.createdAt.compareTo(b.createdAt),
    );
}
