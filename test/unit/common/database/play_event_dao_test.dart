import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/common/database/app_database.dart';
import 'package:purelofi/common/database/daos/play_event.dao.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 11, 4, 12);
  late AppDatabase database;
  late PlayEventDao log;

  setUp(() {
    database = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory()),
    );
    addTearDown(database.close);
    log = PlayEventDao(database);
  });

  Future<int> play(String trackId, {required Duration ago, int seconds = 60}) =>
      log.add(
        PlayEventTableCompanion.insert(
          trackId: trackId,
          source: 'catalogue',
          sceneId: const Value<String?>('rainy'),
          startedAt: now.subtract(ago),
          listenedSeconds: seconds,
        ),
      );

  test('hands plays back newest first', () async {
    await play('a', ago: const Duration(hours: 2));
    await play('b', ago: const Duration(hours: 1));

    final List<PlayEventTableData> rows = await log.watchNewest(10).first;
    expect(rows.map((PlayEventTableData r) => r.trackId), <String>['b', 'a']);
  });

  test('keeps the listened time up to date', () async {
    final int id = await play('a', ago: Duration.zero, seconds: 30);
    await log.setListened(id, 95);

    final List<PlayEventTableData> rows = await log.watchNewest(1).first;
    expect(rows.single.listenedSeconds, 95);
  });

  test('between takes what started in the window, oldest first', () async {
    await play('old', ago: const Duration(days: 8));
    await play('a', ago: const Duration(days: 2));
    await play('b', ago: const Duration(days: 1));

    final List<PlayEventTableData> rows = await log.between(
      now.subtract(const Duration(days: 7)),
      now,
    );
    expect(rows.map((PlayEventTableData r) => r.trackId), <String>['a', 'b']);
  });

  test('pruning drops the old and anything past the newest rows', () async {
    await play('ancient', ago: const Duration(days: 100));
    for (int i = 0; i < 5; i++) {
      await play('t$i', ago: Duration(minutes: 10 - i));
    }

    await log.prune(before: now.subtract(const Duration(days: 90)), keep: 3);

    final List<PlayEventTableData> rows = await log.watchNewest(10).first;
    expect(rows.map((PlayEventTableData r) => r.trackId), <String>[
      't4',
      't3',
      't2',
    ]);
  });

  test('clear empties the log', () async {
    await play('a', ago: Duration.zero);
    await log.clear();

    expect(await log.watchNewest(10).first, isEmpty);
  });
}
