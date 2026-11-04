import 'play_event.entity.dart';
import 'track.entity.dart';

/// The listening log on this device (#142). Nothing here goes to a server.
abstract class PlayHistoryRepository {
  /// Writes a play that just started counting; returns its id.
  Future<int> record({
    required String trackId,
    required TrackSource source,
    String? sceneId,
    required DateTime startedAt,
    required int listenedSeconds,
  });

  /// How much of play [id] has been heard by now.
  Future<void> updateListened(int id, int seconds);

  /// The newest plays first, at most [limit].
  Stream<List<PlayEventEntity>> watchNewest({int limit});

  /// Every play that started in [from, to), oldest first.
  Future<List<PlayEventEntity>> between(DateTime from, DateTime to);

  /// Keeps the log from growing without end.
  Future<void> prune({required DateTime now});

  /// The listener's "Clear history".
  Future<void> clear();
}
