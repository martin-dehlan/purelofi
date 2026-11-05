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
    );
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
