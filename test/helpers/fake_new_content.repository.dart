import 'dart:async';

import 'package:purelofi/features/player/domain/new_content.dart';

/// The "new" marks' memory in memory. The first launch is long ago unless a
/// test says otherwise, so nothing is new by default only if nothing was
/// added — tests that are not about the marks never see one, because their
/// content has no recent `createdAt`.
class FakeNewContentRepository implements NewContentRepository {
  FakeNewContentRepository({DateTime? firstLaunch})
    : _firstLaunch = firstLaunch ?? DateTime(2100);

  final DateTime _firstLaunch;
  final Map<SeenKind, Set<String>> seen = <SeenKind, Set<String>>{
    SeenKind.scene: <String>{},
    SeenKind.track: <String>{},
  };
  final StreamController<void> _changes = StreamController<void>.broadcast(
    sync: true,
  );

  @override
  Future<DateTime> firstLaunch() async => _firstLaunch;

  @override
  Stream<Set<String>> watchSeen(SeenKind kind) =>
      Stream<Set<String>>.multi((MultiStreamController<Set<String>> out) {
        out.add(Set<String>.of(seen[kind]!));
        final StreamSubscription<void> changes = _changes.stream.listen(
          (_) => out.add(Set<String>.of(seen[kind]!)),
        );
        out.onCancel = changes.cancel;
      });

  @override
  Future<void> markSeen(SeenKind kind, String id) async {
    if (seen[kind]!.add(id)) _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}
