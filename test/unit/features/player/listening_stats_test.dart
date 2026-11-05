import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/features/player/domain/listening_stats.dart';
import 'package:purelofi/features/player/domain/play_event.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';

void main() {
  // Monday 2 November 2026.
  final DateTime monday = DateTime(2026, 11, 2);
  int id = 0;

  PlayEventEntity play(
    int day,
    int minutes, {
    String track = 'a',
    String? scene = 'rainy',
    int hour = 20,
  }) => PlayEventEntity(
    id: ++id,
    trackId: track,
    source: TrackSource.catalogue,
    sceneId: scene,
    startedAt: DateTime(2026, 11, 2 + day, hour),
    listenedSeconds: minutes * 60,
  );

  String? artistOf(String track) => switch (track) {
    'a' => 'Masso',
    'b' => 'Kiko',
    _ => null,
  };

  test('the week starts on Monday at midnight', () {
    expect(
      ListeningStats.weekStartOf(DateTime(2026, 11, 5, 15)),
      DateTime(2026, 11, 2),
    );
    expect(ListeningStats.weekStartOf(DateTime(2026, 11, 2)), monday);
    expect(
      ListeningStats.weekStartOf(DateTime(2026, 11, 8, 23, 59)),
      DateTime(2026, 11, 2),
    );
  });

  test(
    'counts the week, per day, and the room, artist and track at the top',
    () {
      final ListeningStats stats = ListeningStats.of(
        weekStart: monday,
        plays: <PlayEventEntity>[
          play(0, 30),
          play(0, 20, track: 'b', scene: 'roof'),
          play(2, 45, track: 'b', scene: 'roof'),
          play(6, 15),
          // Last week and next week stay out.
          play(-1, 100),
          play(7, 100),
        ],
        artistOf: artistOf,
      );

      expect(stats.total, const Duration(minutes: 110));
      expect(stats.perDay[0], const Duration(minutes: 50));
      expect(stats.perDay[2], const Duration(minutes: 45));
      expect(stats.perDay[6], const Duration(minutes: 15));
      expect(stats.topSceneId, 'roof');
      expect(stats.topArtist, 'Kiko');
      expect(stats.topTrackId, 'b');
    },
  );

  test('a streak counts back from the last day, today allowed to be empty', () {
    ListeningStats week(List<int> minutesPerDay) => ListeningStats.of(
      weekStart: monday,
      plays: <PlayEventEntity>[
        for (int d = 0; d < 7; d++)
          if (minutesPerDay[d] > 0) play(d, minutesPerDay[d]),
      ],
      artistOf: artistOf,
    );

    expect(week(<int>[30, 0, 20, 15, 12, 30, 25]).streak, 5);
    // Sunday not listened to yet: the five days before still count.
    expect(week(<int>[30, 0, 20, 15, 12, 30, 0]).streak, 4);
    // Five minutes is not a day of listening.
    expect(week(<int>[30, 30, 30, 30, 30, 5, 30]).streak, 1);
  });

  test('nothing heard is the empty week', () {
    final ListeningStats stats = ListeningStats.of(
      weekStart: monday,
      plays: const <PlayEventEntity>[],
      artistOf: artistOf,
    );

    expect(stats.isEmpty, isTrue);
    expect(stats.topSceneId, isNull);
  });

  test('time reads the way people say it', () {
    expect(
      listeningTimeLabel(const Duration(seconds: 20)),
      'less than a minute',
    );
    expect(listeningTimeLabel(const Duration(minutes: 35)), '35 min');
    expect(listeningTimeLabel(const Duration(hours: 2)), '2 h');
    expect(
      listeningTimeLabel(const Duration(hours: 4, minutes: 20)),
      '4 h 20 min',
    );
  });

  test('the hours, the rooms in order and what was heard how many times', () {
    final ListeningStats stats = ListeningStats.of(
      weekStart: monday,
      plays: <PlayEventEntity>[
        play(0, 30, hour: 8),
        play(1, 20, track: 'b', scene: 'roof', hour: 8),
        play(2, 10, track: 'c', scene: 'train', hour: 22),
        play(3, 5, scene: 'roof', hour: 22),
      ],
      artistOf: artistOf,
    );

    expect(stats.perHour, hasLength(24));
    expect(stats.perHour[8], const Duration(minutes: 50));
    expect(stats.perHour[22], const Duration(minutes: 15));
    expect(stats.topScenes.map(((String, Duration) r) => r.$1), <String>[
      'rainy',
      'roof',
      'train',
    ]);
    expect(stats.tracksHeard, 3);
    expect(stats.artistsHeard, 2);
  });

  test('against last week: up, down, and nothing to set it against', () {
    final List<PlayEventEntity> plays = <PlayEventEntity>[
      play(-3, 50),
      play(1, 70),
    ];
    final ListeningStats week = ListeningStats.of(
      weekStart: monday,
      plays: plays,
      artistOf: artistOf,
    );
    final Duration before = ListeningStats.totalBetween(
      plays,
      monday.subtract(const Duration(days: 7)),
      monday,
    );

    expect(before, const Duration(minutes: 50));
    expect(week.withLastWeek(before).changeOnLastWeek, 40);
    expect(
      week.withLastWeek(const Duration(minutes: 140)).changeOnLastWeek,
      -50,
    );
    expect(week.withLastWeek(Duration.zero).changeOnLastWeek, isNull);
    expect(week.changeOnLastWeek, isNull);
  });
}
