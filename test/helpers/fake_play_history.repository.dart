import 'dart:async';

import 'package:purelofi/features/player/domain/play_event.entity.dart';
import 'package:purelofi/features/player/domain/play_history.repository.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';

/// The listening log in memory, so no widget test opens a database.
class FakePlayHistoryRepository implements PlayHistoryRepository {
  FakePlayHistoryRepository([List<PlayEventEntity>? events])
    : events = events ?? <PlayEventEntity>[];

  final List<PlayEventEntity> events;

  /// Synchronous, so a test's fake clock never has to flush a microtask
  /// scheduled outside its zone.
  final StreamController<List<PlayEventEntity>> _changes =
      StreamController<List<PlayEventEntity>>.broadcast(sync: true);
  int _nextId = 1;
  int prunes = 0;

  List<PlayEventEntity> get _newest => List<PlayEventEntity>.of(events)
    ..sort(
      (PlayEventEntity a, PlayEventEntity b) =>
          b.startedAt.compareTo(a.startedAt),
    );

  void _emit() => _changes.add(_newest);

  @override
  Future<int> record({
    required String trackId,
    required TrackSource source,
    String? sceneId,
    required DateTime startedAt,
    required int listenedSeconds,
  }) async {
    final int id = _nextId++;
    events.add(
      PlayEventEntity(
        id: id,
        trackId: trackId,
        source: source,
        sceneId: sceneId,
        startedAt: startedAt,
        listenedSeconds: listenedSeconds,
      ),
    );
    _emit();
    return id;
  }

  @override
  Future<void> updateListened(int id, int seconds) async {
    final int index = events.indexWhere((PlayEventEntity e) => e.id == id);
    if (index < 0) return;
    events[index] = events[index].copyWith(listenedSeconds: seconds);
    _emit();
  }

  @override
  Stream<List<PlayEventEntity>> watchNewest({int limit = 200}) =>
      Stream<List<PlayEventEntity>>.multi((
        MultiStreamController<List<PlayEventEntity>> out,
      ) {
        out.add(_newest.take(limit).toList());
        final StreamSubscription<List<PlayEventEntity>> changes = _changes
            .stream
            .listen(
              (List<PlayEventEntity> all) => out.add(all.take(limit).toList()),
            );
        out.onCancel = changes.cancel;
      });

  @override
  Future<List<PlayEventEntity>> between(DateTime from, DateTime to) async =>
      events
          .where(
            (PlayEventEntity e) =>
                !e.startedAt.isBefore(from) && e.startedAt.isBefore(to),
          )
          .toList()
        ..sort(
          (PlayEventEntity a, PlayEventEntity b) =>
              a.startedAt.compareTo(b.startedAt),
        );

  @override
  Future<void> prune({required DateTime now}) async => prunes++;

  @override
  Future<void> clear() async {
    events.clear();
    _emit();
  }

  Future<void> dispose() => _changes.close();
}
