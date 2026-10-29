import '../../player/domain/track.entity.dart';

/// How the list is sorted, which is also the order the listener's music
/// plays in with shuffle off.
enum LibrarySort { recent, title, artist }

/// The listener's choices for their library. Remembered across launches,
/// unlike which side is playing (#66). Shuffle is not here: it belongs to
/// the transport and covers both sides (`PlaybackMode`).
class LibraryView {
  const LibraryView({this.sort = LibrarySort.recent});

  final LibrarySort sort;

  LibraryView copyWith({LibrarySort? sort}) =>
      LibraryView(sort: sort ?? this.sort);

  @override
  bool operator ==(Object other) => other is LibraryView && other.sort == sort;

  @override
  int get hashCode => sort.hashCode;
}

/// [tracks] in [sort] order. Titles and artists compare without case, and a
/// track with no artist goes last rather than first.
List<TrackEntity> sortTracks(List<TrackEntity> tracks, LibrarySort sort) {
  final List<TrackEntity> sorted = List<TrackEntity>.of(tracks);
  int byTitle(TrackEntity a, TrackEntity b) =>
      a.title.toLowerCase().compareTo(b.title.toLowerCase());

  switch (sort) {
    case LibrarySort.recent:
      sorted.sort(
        (TrackEntity a, TrackEntity b) => b.createdAt.compareTo(a.createdAt),
      );
    case LibrarySort.title:
      sorted.sort(byTitle);
    case LibrarySort.artist:
      sorted.sort((TrackEntity a, TrackEntity b) {
        final String? x = a.artist?.toLowerCase();
        final String? y = b.artist?.toLowerCase();
        if (x == y) return byTitle(a, b);
        if (x == null) return 1;
        if (y == null) return -1;
        return x.compareTo(y);
      });
  }
  return sorted;
}

/// The tracks whose title or artist contains [query], ignoring case. An
/// empty query is everything.
List<TrackEntity> searchTracks(List<TrackEntity> tracks, String query) {
  final String q = query.trim().toLowerCase();
  if (q.isEmpty) return tracks;

  return tracks
      .where(
        (TrackEntity t) =>
            t.title.toLowerCase().contains(q) ||
            (t.artist?.toLowerCase().contains(q) ?? false),
      )
      .toList();
}
