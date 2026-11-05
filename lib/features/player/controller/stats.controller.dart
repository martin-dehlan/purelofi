import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/listening_stats.dart';
import '../domain/period_stats.dart';
import '../domain/play_event.entity.dart';
import '../domain/track.entity.dart';
import '../../library/controller/library.controller.dart';
import 'play_history.controller.dart';
import 'player.provider.dart';
import 'track.controller.dart';

part 'stats.controller.g.dart';

/// This week's listening (#151), worked out again as the log grows.
@riverpod
Future<ListeningStats> weekStats(Ref ref) async {
  // Follows the log: a new play makes the week count again.
  ref.watch(recentPlaysProvider);
  final DateTime start = ListeningStats.weekStartOf(DateTime.now());
  final List<PlayEventEntity> plays;
  try {
    plays = await ref
        .read(playHistoryRepositoryProvider)
        .between(start, start.add(const Duration(days: 7)));
  } on Object {
    return ListeningStats.empty;
  }

  final Map<String, String?> artists = <String, String?>{
    for (final TrackEntity t
        in ref.watch(trackListControllerProvider).value ??
            const <TrackEntity>[])
      t.id: t.artist,
    for (final TrackEntity t
        in ref.watch(libraryControllerProvider).value ?? const <TrackEntity>[])
      t.id: t.artist,
  };

  return ListeningStats.of(
    weekStart: start,
    plays: plays,
    artistOf: (String id) => artists[id],
  );
}

/// A week, month or year of listening for the Stats page, [offset] of them
/// back from the one now; worked out again as the log grows.
@riverpod
Future<PeriodStats> periodStats(Ref ref, StatsSpan span, int offset) async {
  ref.watch(recentPlaysProvider);
  final StatsPeriod period = StatsPeriod(span, DateTime.now(), offset: offset);
  List<PlayEventEntity> plays;
  try {
    // The stretch before too, to set this one against.
    plays = await ref
        .read(playHistoryRepositoryProvider)
        .between(period.previousStart, period.end);
  } on Object {
    plays = const <PlayEventEntity>[];
  }

  final Map<String, String?> artists = <String, String?>{
    for (final TrackEntity t
        in ref.watch(trackListControllerProvider).value ??
            const <TrackEntity>[])
      t.id: t.artist,
    for (final TrackEntity t
        in ref.watch(libraryControllerProvider).value ?? const <TrackEntity>[])
      t.id: t.artist,
  };

  return PeriodStats.of(
    period: period,
    plays: plays,
    artistOf: (String id) => artists[id],
  );
}
