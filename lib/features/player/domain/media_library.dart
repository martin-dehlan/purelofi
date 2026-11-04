/// One entry in what a car, a watch or another media browser shows (#145):
/// a folder to open, or something to play.
class BrowseNode {
  const BrowseNode({
    required this.id,
    required this.title,
    this.subtitle,
    this.artUri,
    this.playable = false,
  });

  final String id;
  final String title;
  final String? subtitle;
  final Uri? artUri;
  final bool playable;
}

/// What the audio service asks the app for when a media browser — Android
/// Auto, mostly — opens it (#145). The app decides what is in it and what
/// playing an entry means; the service only passes it on.
abstract class MediaLibrary {
  /// The entries under [parentId]; `root` is the top.
  Future<List<BrowseNode>> children(String parentId);

  /// Plays the entry [id] — a track, a room, a mood, a playlist.
  Future<void> play(String id);
}

/// The ids the library speaks, one prefix per kind.
abstract final class BrowseIds {
  static const String root = 'root';
  static const String rooms = 'rooms';
  static const String favorites = 'favorites';
  static const String moods = 'moods';
  static const String playlists = 'playlists';

  static String room(String id) => 'room:$id';
  static String track(String id) => 'track:$id';
  static String mood(String id) => 'mood:$id';
  static String playlist(String id) => 'playlist:$id';

  /// The kind and the id of [browseId], or `null` for a folder.
  static (String kind, String id)? parse(String browseId) {
    final int colon = browseId.indexOf(':');
    if (colon <= 0) return null;
    return (browseId.substring(0, colon), browseId.substring(colon + 1));
  }
}
