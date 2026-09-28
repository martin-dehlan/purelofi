import '../../player/domain/track.entity.dart';

/// How the stream moves through the listener's own music.
enum LibraryOrder {
  /// Down the list as sorted, then round again.
  inOrder,

  /// Any track but the one just played.
  shuffle,
}

/// How the list is sorted, which is also the order [LibraryOrder.inOrder]
/// plays in.
enum LibrarySort { recent, title, artist }

/// The listener's choices for their library. Remembered across launches,
/// unlike which side is playing (#66).
class LibraryView {
  const LibraryView({
    this.order = LibraryOrder.shuffle,
    this.sort = LibrarySort.recent,
  });

  final LibraryOrder order;
  final LibrarySort sort;

  LibraryView copyWith({LibraryOrder? order, LibrarySort? sort}) =>
      LibraryView(order: order ?? this.order, sort: sort ?? this.sort);

  @override
  bool operator ==(Object other) =>
      other is LibraryView && other.order == order && other.sort == sort;

  @override
  int get hashCode => Object.hash(order, sort);
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
