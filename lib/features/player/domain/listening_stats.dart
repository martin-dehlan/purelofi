import 'play_event.entity.dart';

/// A week of listening, worked out from the log (#151). Pure: the controller
/// hands in the plays and what they were, this only counts.
class ListeningStats {
  const ListeningStats({
    required this.total,
    required this.perDay,
    required this.streak,
    this.topSceneId,
    this.topArtist,
    this.topTrackId,
    this.perHour = const <Duration>[],
    this.topScenes = const <(String, Duration)>[],
    this.tracksHeard = 0,
    this.artistsHeard = 0,
    this.lastWeek,
  });

  /// Nothing heard at all.
  static const ListeningStats empty = ListeningStats(
    total: Duration.zero,
    perDay: <Duration>[
      Duration.zero,
      Duration.zero,
      Duration.zero,
      Duration.zero,
      Duration.zero,
      Duration.zero,
      Duration.zero,
    ],
    streak: 0,
  );

  final Duration total;

  /// Monday first, seven days.
  final List<Duration> perDay;

  /// Days in a row up to the last day of the week with at least
  /// [streakMinimum] heard.
  final int streak;

  /// The room most listened in, by time.
  final String? topSceneId;

  /// The artist most listened to, by time, as the track names them.
  final String? topArtist;

  final String? topTrackId;

  /// The time heard in each hour of the day, midnight first, 24 of them
  /// (empty when nothing was counted).
  final List<Duration> perHour;

  /// The rooms most listened in, most first, at most three.
  final List<(String, Duration)> topScenes;

  /// Different tracks and artists heard this week.
  final int tracksHeard;
  final int artistsHeard;

  /// What the week before held, when it was looked at.
  final Duration? lastWeek;

  /// This week against the last, as a whole percentage: `null` when there
  /// is nothing to set it against.
  int? get changeOnLastWeek {
    final Duration? before = lastWeek;
    if (before == null || before == Duration.zero) return null;
    return ((total.inSeconds - before.inSeconds) * 100 / before.inSeconds)
        .round();
  }

  /// This week's stats with what the week before held.
  ListeningStats withLastWeek(Duration before) => ListeningStats(
    total: total,
    perDay: perDay,
    streak: streak,
    topSceneId: topSceneId,
    topArtist: topArtist,
    topTrackId: topTrackId,
    perHour: perHour,
    topScenes: topScenes,
    tracksHeard: tracksHeard,
    artistsHeard: artistsHeard,
    lastWeek: before,
  );

  /// What a day must hold to keep a streak going.
  static const Duration streakMinimum = Duration(minutes: 10);

  bool get isEmpty => total == Duration.zero;

  /// The stats of the week starting [weekStart] (a Monday, midnight local)
  /// from [plays]. [artistOf] names a track's artist, or `null`.
  factory ListeningStats.of({
    required DateTime weekStart,
    required Iterable<PlayEventEntity> plays,
    required String? Function(String trackId) artistOf,
  }) {
    final DateTime weekEnd = weekStart.add(const Duration(days: 7));
    final List<int> perDay = List<int>.filled(7, 0);
    final List<int> perHour = List<int>.filled(24, 0);
    final Map<String, int> byScene = <String, int>{};
    final Map<String, int> byArtist = <String, int>{};
    final Map<String, int> byTrack = <String, int>{};
    int total = 0;

    for (final PlayEventEntity play in plays) {
      final DateTime at = play.startedAt.toLocal();
      if (at.isBefore(weekStart) || !at.isBefore(weekEnd)) continue;

      final int seconds = play.listenedSeconds;
      total += seconds;
      perDay[_dayIndex(weekStart, at)] += seconds;
      perHour[at.hour] += seconds;
      if (play.sceneId case final String scene) {
        byScene[scene] = (byScene[scene] ?? 0) + seconds;
      }
      if (artistOf(play.trackId) case final String artist) {
        byArtist[artist] = (byArtist[artist] ?? 0) + seconds;
      }
      byTrack[play.trackId] = (byTrack[play.trackId] ?? 0) + seconds;
    }

    int streak = 0;
    for (int day = 6; day >= 0; day--) {
      if (perDay[day] < streakMinimum.inSeconds) {
        // Today not yet listened to does not break yesterday's streak.
        if (streak == 0 && day == 6) continue;
        break;
      }
      streak++;
    }

    return ListeningStats(
      total: Duration(seconds: total),
      perDay: <Duration>[for (final int s in perDay) Duration(seconds: s)],
      streak: streak,
      topSceneId: _top(byScene),
      topArtist: _top(byArtist),
      topTrackId: _top(byTrack),
      perHour: <Duration>[for (final int s in perHour) Duration(seconds: s)],
      topScenes: <(String, Duration)>[
        for (final MapEntry<String, int> e
            in (byScene.entries.toList()..sort(
                  (MapEntry<String, int> a, MapEntry<String, int> b) =>
                      b.value.compareTo(a.value),
                ))
                .take(3))
          (e.key, Duration(seconds: e.value)),
      ],
      tracksHeard: byTrack.length,
      artistsHeard: byArtist.length,
    );
  }

  /// All that [plays] held between [from] and [to].
  static Duration totalBetween(
    Iterable<PlayEventEntity> plays,
    DateTime from,
    DateTime to,
  ) {
    int seconds = 0;
    for (final PlayEventEntity play in plays) {
      final DateTime at = play.startedAt.toLocal();
      if (at.isBefore(from) || !at.isBefore(to)) continue;
      seconds += play.listenedSeconds;
    }
    return Duration(seconds: seconds);
  }

  /// The Monday at midnight that starts the week [now] is in.
  static DateTime weekStartOf(DateTime now) {
    final DateTime day = DateTime(now.year, now.month, now.day);
    return DateTime(day.year, day.month, day.day - (day.weekday - 1));
  }

  /// Counted in calendar days, not 24-hour blocks: a week with a clock
  /// change still has seven days.
  static int _dayIndex(DateTime weekStart, DateTime at) {
    final DateTime day = DateTime(at.year, at.month, at.day);
    final int index = DateTime.utc(day.year, day.month, day.day)
        .difference(
          DateTime.utc(weekStart.year, weekStart.month, weekStart.day),
        )
        .inDays;
    return index.clamp(0, 6);
  }

  static String? _top(Map<String, int> counts) {
    String? best;
    int most = 0;
    for (final MapEntry<String, int> e in counts.entries) {
      if (e.value > most) {
        best = e.key;
        most = e.value;
      }
    }
    return best;
  }
}

/// "4 h 20 min", "35 min", "less than a minute".
String listeningTimeLabel(Duration d) {
  if (d.inMinutes < 1) return 'less than a minute';
  final int hours = d.inHours;
  final int minutes = d.inMinutes % 60;
  if (hours == 0) return '$minutes min';
  return minutes == 0 ? '$hours h' : '$hours h $minutes min';
}
