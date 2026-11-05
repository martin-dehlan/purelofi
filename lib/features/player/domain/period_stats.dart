import 'play_event.entity.dart';

/// How long a stretch the Stats page looks at.
enum StatsSpan { week, month, year }

/// Parts of the day, for when someone mostly listens.
enum DayPart { morning, afternoon, evening, night }

/// One stretch of time: a week from Monday, a calendar month or a calendar
/// year, all in local time. [offset] counts back from the one now (0), so
/// -1 is the week, month or year before.
class StatsPeriod {
  StatsPeriod(this.span, DateTime now, {this.offset = 0})
    : start = _startOf(span, now, offset);

  final StatsSpan span;
  final int offset;

  /// Midnight local, at the first day.
  final DateTime start;

  /// The first moment after it.
  DateTime get end => switch (span) {
    StatsSpan.week => DateTime(start.year, start.month, start.day + 7),
    StatsSpan.month => DateTime(start.year, start.month + 1),
    StatsSpan.year => DateTime(start.year + 1),
  };

  /// The stretch just before, for setting this one against.
  DateTime get previousStart => switch (span) {
    StatsSpan.week => DateTime(start.year, start.month, start.day - 7),
    StatsSpan.month => DateTime(start.year, start.month - 1),
    StatsSpan.year => DateTime(start.year - 1),
  };

  /// Days in a week or month, months in a year.
  int get slotCount => switch (span) {
    StatsSpan.week => 7,
    StatsSpan.month => DateTime(start.year, start.month + 1, 0).day,
    StatsSpan.year => 12,
  };

  /// Calendar days in it, for the daily average.
  int get dayCount => _days(start, end);

  /// The slot [at] falls in.
  int slotOf(DateTime at) => switch (span) {
    StatsSpan.year => at.month - 1,
    _ => _days(start, DateTime(at.year, at.month, at.day)),
  }.clamp(0, slotCount - 1);

  /// The days of it that have begun by [now]; the whole of it once over.
  int daysSoFar(DateTime now) {
    if (!now.isBefore(end)) return dayCount;
    if (now.isBefore(start)) return 0;
    return _days(start, DateTime(now.year, now.month, now.day)) + 1;
  }

  static DateTime _startOf(StatsSpan span, DateTime now, int offset) {
    switch (span) {
      case StatsSpan.week:
        final DateTime monday = DateTime(
          now.year,
          now.month,
          now.day - (now.weekday - 1),
        );
        return DateTime(monday.year, monday.month, monday.day + 7 * offset);
      case StatsSpan.month:
        return DateTime(now.year, now.month + offset);
      case StatsSpan.year:
        return DateTime(now.year + offset);
    }
  }

  /// Counted in calendar days, so a clock change does not lose one.
  static int _days(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
}

/// What a stretch of listening holds, worked out from the log. Pure: the
/// controller hands in the plays and what they were, this only counts.
class PeriodStats {
  const PeriodStats({
    required this.period,
    required this.total,
    required this.slots,
    required this.before,
    required this.activeDays,
    required this.longestStreak,
    required this.topTracks,
    required this.topArtists,
    required this.topScenes,
    required this.tracksHeard,
    required this.artistsHeard,
    this.mostlyIn,
  });

  final StatsPeriod period;
  final Duration total;

  /// Time per day (week, month) or per month (year).
  final List<Duration> slots;

  /// What the stretch before held.
  final Duration before;

  /// Days with anything heard, and the longest run of them in a row.
  final int activeDays;
  final int longestStreak;

  /// Most first, at most [topCount]: track ids, artist names, scene ids.
  final List<(String, Duration)> topTracks;
  final List<(String, Duration)> topArtists;
  final List<(String, Duration)> topScenes;

  final int tracksHeard;
  final int artistsHeard;

  /// The part of the day most was heard in.
  final DayPart? mostlyIn;

  static const int topCount = 5;

  bool get isEmpty => total == Duration.zero;

  /// Against the stretch before, as a whole percentage; `null` when there
  /// is nothing to set it against.
  int? get change => before == Duration.zero
      ? null
      : ((total.inSeconds - before.inSeconds) * 100 / before.inSeconds).round();

  /// The time per day, over the days that have begun by [now].
  Duration averageDay(DateTime now) {
    final int days = period.daysSoFar(now);
    return days == 0 ? Duration.zero : total ~/ days;
  }

  /// [plays] counted for [period]; plays outside it, and in the stretch
  /// before it, are sorted out here. [artistOf] names a track's artist.
  factory PeriodStats.of({
    required StatsPeriod period,
    required Iterable<PlayEventEntity> plays,
    required String? Function(String trackId) artistOf,
  }) {
    final List<int> slots = List<int>.filled(period.slotCount, 0);
    final Set<int> days = <int>{};
    final List<int> parts = List<int>.filled(DayPart.values.length, 0);
    final Map<String, int> byTrack = <String, int>{};
    final Map<String, int> byArtist = <String, int>{};
    final Map<String, int> byScene = <String, int>{};
    int total = 0;
    int before = 0;

    for (final PlayEventEntity play in plays) {
      final DateTime at = play.startedAt.toLocal();
      final int seconds = play.listenedSeconds;
      if (!at.isBefore(period.previousStart) && at.isBefore(period.start)) {
        before += seconds;
        continue;
      }
      if (at.isBefore(period.start) || !at.isBefore(period.end)) continue;

      total += seconds;
      slots[period.slotOf(at)] += seconds;
      days.add(StatsPeriod._days(period.start, at));
      parts[_partOf(at.hour).index] += seconds;
      byTrack[play.trackId] = (byTrack[play.trackId] ?? 0) + seconds;
      if (artistOf(play.trackId) case final String artist) {
        byArtist[artist] = (byArtist[artist] ?? 0) + seconds;
      }
      if (play.sceneId case final String scene) {
        byScene[scene] = (byScene[scene] ?? 0) + seconds;
      }
    }

    int longest = 0;
    int run = 0;
    for (int day = 0; day < period.dayCount; day++) {
      run = days.contains(day) ? run + 1 : 0;
      if (run > longest) longest = run;
    }

    int most = 0;
    DayPart? mostlyIn;
    for (final DayPart part in DayPart.values) {
      if (parts[part.index] > most) {
        most = parts[part.index];
        mostlyIn = part;
      }
    }

    return PeriodStats(
      period: period,
      total: Duration(seconds: total),
      slots: <Duration>[for (final int s in slots) Duration(seconds: s)],
      before: Duration(seconds: before),
      activeDays: days.length,
      longestStreak: longest,
      topTracks: _top(byTrack),
      topArtists: _top(byArtist),
      topScenes: _top(byScene),
      tracksHeard: byTrack.length,
      artistsHeard: byArtist.length,
      mostlyIn: mostlyIn,
    );
  }

  static DayPart _partOf(int hour) => switch (hour) {
    >= 5 && < 12 => DayPart.morning,
    >= 12 && < 17 => DayPart.afternoon,
    >= 17 && < 22 => DayPart.evening,
    _ => DayPart.night,
  };

  static List<(String, Duration)> _top(Map<String, int> counts) =>
      (counts.entries.toList()..sort(
            (MapEntry<String, int> a, MapEntry<String, int> b) =>
                b.value.compareTo(a.value),
          ))
          .take(topCount)
          .map((MapEntry<String, int> e) => (e.key, Duration(seconds: e.value)))
          .toList();
}
