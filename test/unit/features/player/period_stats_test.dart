import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/features/player/domain/period_stats.dart';
import 'package:purelofi/features/player/domain/play_event.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';

void main() {
  // Thursday 5 November 2026.
  final DateTime now = DateTime(2026, 11, 5, 15);
  int id = 0;

  PlayEventEntity play(
    DateTime at,
    int minutes, {
    String track = 'a',
    String? scene = 'rainy',
  }) => PlayEventEntity(
    id: ++id,
    trackId: track,
    source: TrackSource.catalogue,
    sceneId: scene,
    startedAt: at,
    listenedSeconds: minutes * 60,
  );

  String? artistOf(String track) => switch (track) {
    'a' => 'Masso',
    'b' => 'Kiko',
    _ => null,
  };

  group('StatsPeriod', () {
    test('a week runs Monday to Monday, and steps back by seven days', () {
      final StatsPeriod week = StatsPeriod(StatsSpan.week, now);
      expect(week.start, DateTime(2026, 11, 2));
      expect(week.end, DateTime(2026, 11, 9));
      expect(week.slotCount, 7);
      expect(week.daysSoFar(now), 4);

      final StatsPeriod before = StatsPeriod(StatsSpan.week, now, offset: -1);
      expect(before.start, DateTime(2026, 10, 26));
      expect(before.daysSoFar(now), 7);
    });

    test('a month has its own number of days, a year its months', () {
      final StatsPeriod feb = StatsPeriod(
        StatsSpan.month,
        DateTime(2028, 2, 10),
      );
      expect(feb.slotCount, 29);
      expect(feb.previousStart, DateTime(2028, 1));

      final StatsPeriod lastYear = StatsPeriod(StatsSpan.year, now, offset: -1);
      expect(lastYear.start, DateTime(2025));
      expect(lastYear.slotCount, 12);
      expect(lastYear.slotOf(DateTime(2025, 10, 31)), 9);
      expect(lastYear.dayCount, 365);
    });

    test('back across the year end', () {
      final StatsPeriod jan = StatsPeriod(
        StatsSpan.month,
        DateTime(2027, 1, 3),
        offset: -1,
      );
      expect(jan.start, DateTime(2026, 12));
      expect(jan.end, DateTime(2027));
    });
  });

  group('PeriodStats', () {
    test('counts the stretch, per slot, against the one before', () {
      final StatsPeriod month = StatsPeriod(StatsSpan.month, now);
      final PeriodStats stats = PeriodStats.of(
        period: month,
        plays: <PlayEventEntity>[
          play(DateTime(2026, 11, 1, 9), 30),
          play(DateTime(2026, 11, 2, 20), 20, track: 'b', scene: 'roof'),
          play(DateTime(2026, 11, 3, 23), 10, track: 'b', scene: 'roof'),
          play(DateTime(2026, 11, 5, 21), 40, track: 'c'),
          // October: the month before.
          play(DateTime(2026, 10, 20), 50),
          // December: out.
          play(DateTime(2026, 12, 1), 99),
        ],
        artistOf: artistOf,
      );

      expect(stats.total, const Duration(minutes: 100));
      expect(stats.slots, hasLength(30));
      expect(stats.slots[0], const Duration(minutes: 30));
      expect(stats.slots[4], const Duration(minutes: 40));
      expect(stats.before, const Duration(minutes: 50));
      expect(stats.change, 100);
      expect(stats.activeDays, 4);
      expect(stats.longestStreak, 3);
      expect(stats.topTracks.first.$1, 'c');
      expect(stats.topArtists.map(((String, Duration) a) => a.$1), <String>[
        'Masso',
        'Kiko',
      ]);
      expect(stats.topScenes.first.$1, 'rainy');
      expect(stats.tracksHeard, 3);
      expect(stats.artistsHeard, 2);
      expect(stats.mostlyIn, DayPart.evening);
      // 100 minutes over the five days begun.
      expect(stats.averageDay(now), const Duration(minutes: 20));
    });

    test('nothing before is nothing to set against', () {
      final PeriodStats stats = PeriodStats.of(
        period: StatsPeriod(StatsSpan.week, now),
        plays: <PlayEventEntity>[play(DateTime(2026, 11, 3, 2), 15)],
        artistOf: artistOf,
      );
      expect(stats.change, isNull);
      expect(stats.mostlyIn, DayPart.night);
    });

    test('a year counts by month', () {
      final PeriodStats stats = PeriodStats.of(
        period: StatsPeriod(StatsSpan.year, now),
        plays: <PlayEventEntity>[
          play(DateTime(2026, 3, 4, 10), 30),
          play(DateTime(2026, 3, 20, 10), 30),
          play(DateTime(2025, 12, 31, 10), 30),
        ],
        artistOf: artistOf,
      );
      expect(stats.slots, hasLength(12));
      expect(stats.slots[2], const Duration(hours: 1));
      expect(stats.before, const Duration(minutes: 30));
      expect(stats.mostlyIn, DayPart.morning);
    });
  });
}
