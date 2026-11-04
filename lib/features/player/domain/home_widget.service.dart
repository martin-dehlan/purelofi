/// What the home and lock screen widgets show (#144): the room, the track,
/// whether it plays. Written by the app, read by the platform's widget.
class WidgetSnapshot {
  const WidgetSnapshot({
    required this.room,
    required this.isPlaying,
    this.track,
    this.artist,
    this.coverPath,
  });

  final String room;
  final String? track;
  final String? artist;

  /// The room's cover as a file on the device; widgets cannot fetch.
  final String? coverPath;
  final bool isPlaying;

  @override
  bool operator ==(Object other) =>
      other is WidgetSnapshot &&
      other.room == room &&
      other.track == track &&
      other.artist == artist &&
      other.coverPath == coverPath &&
      other.isPlaying == isPlaying;

  @override
  int get hashCode => Object.hash(room, track, artist, coverPath, isPlaying);
}

/// Hands [WidgetSnapshot]s to the platform's widgets.
abstract class HomeWidgetService {
  Future<void> show(WidgetSnapshot snapshot);
}

/// The keys the native widgets read. Kept in one place: the Kotlin and
/// Swift sides spell them the same way.
abstract final class WidgetKeys {
  static const String room = 'room';
  static const String track = 'track';
  static const String artist = 'artist';
  static const String cover = 'cover';
  static const String playing = 'playing';

  /// The iOS App Group shared with the widget extension.
  static const String appGroup = 'group.app.purelofi';

  static const String androidProvider = 'app.purelofi.PureLofiWidgetProvider';
  static const String iosKind = 'PureLofiWidget';
}
