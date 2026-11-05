import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../common/utils/app_fonts.dart';
import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../../../l10n/l10n.dart';
import '../../../library/controller/library.controller.dart';
import '../../controller/scene.controller.dart';
import '../../controller/stats.controller.dart';
import '../../controller/track.controller.dart';
import '../../domain/listening_stats.dart';
import '../../domain/period_stats.dart';
import '../../domain/scene.entity.dart';
import '../../domain/track.entity.dart';
import 'recap_sheet.widget.dart';
import 'stats_line_chart.widget.dart';

/// The Stats page (#151): a week, a month or a year of listening, and any
/// of them back as far as the log goes. On top the time and how it went
/// against the stretch before; then the stretch as a pixel line; then what
/// was heard most, as a numbered list; then the rest as a receipt. Lo-fi
/// by the mono face and the pixel grid, not by boxes.
class StatsView extends ConsumerStatefulWidget {
  const StatsView({super.key});

  @override
  ConsumerState<StatsView> createState() => _StatsViewState();
}

enum _Top { tracks, artists, rooms }

class _StatsViewState extends ConsumerState<StatsView> {
  StatsSpan _span = StatsSpan.week;
  int _offset = 0;
  _Top _top = _Top.tracks;

  /// How far back each span goes: the log keeps a little over a year.
  static int _furthest(StatsSpan span) => switch (span) {
    StatsSpan.week => -52,
    StatsSpan.month => -12,
    StatsSpan.year => -1,
  };

  void _show(StatsSpan span) => setState(() {
    _span = span;
    _offset = 0;
  });

  void _step(int by) {
    unawaited(HapticFeedback.selectionClick());
    setState(() => _offset += by);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AsyncValue<PeriodStats> async = ref.watch(
      periodStatsProvider(_span, _offset),
    );
    final PeriodStats? stats = async.value;
    final StatsPeriod period =
        stats?.period ?? StatsPeriod(_span, DateTime.now(), offset: _offset);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Switch<StatsSpan>(
          values: StatsSpan.values,
          selected: _span,
          label: (StatsSpan s) => switch (s) {
            StatsSpan.week => context.l10n.week,
            StatsSpan.month => context.l10n.month,
            StatsSpan.year => context.l10n.year,
          },
          onSelected: _show,
        ),
        SizedBox(height: context.spaceS),
        Row(
          children: <Widget>[
            IconButton(
              tooltip: context.l10n.earlier,
              onPressed: _offset > _furthest(_span) ? () => _step(-1) : null,
              icon: AppIcon(
                AppGlyph.back,
                size: context.fontM,
                color: _offset > _furthest(_span)
                    ? cs.onSurface
                    : cs.onSurface.withValues(alpha: 0.25),
              ),
            ),
            Expanded(
              child: Text(
                _periodLabel(context, period),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  color: cs.onSurface,
                  fontSize: context.fontS,
                ),
              ),
            ),
            IconButton(
              tooltip: context.l10n.later,
              onPressed: _offset < 0 ? () => _step(1) : null,
              icon: AppIcon(
                AppGlyph.chevron,
                size: context.fontM,
                color: _offset < 0
                    ? cs.onSurface
                    : cs.onSurface.withValues(alpha: 0.25),
              ),
            ),
          ],
        ),
        SizedBox(height: context.spaceM),
        if (stats == null)
          SizedBox(height: context.screenWidth * 0.6)
        // An empty stretch shows the same page, at nothing: the shape
        // stays where the eye expects it as the listener steps through.
        else
          _Body(
            stats: stats,
            top: _top,
            onTop: (_Top t) => setState(() => _top = t),
          ),
      ],
    );
  }

  /// "This week" for the one now, else the dates: "3 – 9 Nov", "October
  /// 2026", "2025", in the app's language.
  static String _periodLabel(BuildContext context, StatsPeriod period) {
    final String locale = Localizations.localeOf(context).toString();
    if (period.offset == 0) {
      return switch (period.span) {
        StatsSpan.week => context.l10n.thisWeek,
        StatsSpan.month => context.l10n.thisMonth,
        StatsSpan.year => context.l10n.thisYear,
      };
    }
    return switch (period.span) {
      StatsSpan.week =>
        '${DateFormat.MMMd(locale).format(period.start)} – '
            '${DateFormat.MMMd(locale).format(period.end.subtract(const Duration(days: 1)))}',
      StatsSpan.month => DateFormat.yMMMM(locale).format(period.start),
      StatsSpan.year => DateFormat.y(locale).format(period.start),
    };
  }
}

/// Everything below the period, once there is something to show.
class _Body extends ConsumerWidget {
  const _Body({required this.stats, required this.top, required this.onTop});

  final PeriodStats stats;
  final _Top top;
  final ValueChanged<_Top> onTop;

  /// The time as read elsewhere, but nothing reads as nothing: "0 min".
  static String _time(Duration d) =>
      d == Duration.zero ? '0 min' : listeningTimeLabel(d);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final DateTime now = DateTime.now();
    final int? change = stats.change;
    final TextStyle small = TextStyle(
      fontFamily: AppFonts.mono,
      color: cs.onSurfaceVariant,
      fontSize: context.fontXs,
    );

    final Map<String, TrackEntity> tracks = <String, TrackEntity>{
      for (final TrackEntity t
          in ref.watch(trackListControllerProvider).value ??
              const <TrackEntity>[])
        t.id: t,
      for (final TrackEntity t
          in ref.watch(libraryControllerProvider).value ??
              const <TrackEntity>[])
        t.id: t,
    };
    final Map<String, SceneEntity> scenes = <String, SceneEntity>{
      for (final SceneEntity s
          in ref.watch(sceneListControllerProvider).value ??
              const <SceneEntity>[])
        s.id: s,
    };

    final List<_Ranked> ranked = switch (top) {
      _Top.tracks => <_Ranked>[
        for (final (String, Duration) t in stats.topTracks)
          if (tracks[t.$1] case final TrackEntity track)
            _Ranked(track.title, track.artistName, t.$2),
      ],
      _Top.artists => <_Ranked>[
        for (final (String, Duration) a in stats.topArtists)
          _Ranked(a.$1, null, a.$2),
      ],
      _Top.rooms => <_Ranked>[
        for (final (String, Duration) r in stats.topScenes)
          if (scenes[r.$1] case final SceneEntity scene)
            _Ranked(scene.title, null, r.$2),
      ],
    };

    final List<(String, String)> facts = <(String, String)>[
      (
        context.l10n.activeDays,
        '${stats.activeDays} / ${stats.period.daysSoFar(now)}',
      ),
      if (stats.longestStreak > 1)
        (
          context.l10n.longestStreak,
          context.l10n.dayCount(stats.longestStreak),
        ),
      if (stats.mostlyIn case final DayPart part)
        (
          context.l10n.mostly,
          switch (part) {
            DayPart.morning => context.l10n.inTheMorning,
            DayPart.afternoon => context.l10n.inTheAfternoon,
            DayPart.evening => context.l10n.inTheEvening,
            DayPart.night => context.l10n.atNight,
          },
        ),
      (context.l10n.tracks, '${stats.tracksHeard}'),
      (context.l10n.artists, '${stats.artistsHeard}'),
    ];

    // Sharing tells of a week: offered on the week now.
    final ListeningStats? week =
        stats.period.span == StatsSpan.week && stats.period.offset == 0
        ? ref.watch(weekStatsProvider).value
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          _time(stats.total),
          style: TextStyle(
            color: cs.primary,
            fontSize: context.fontXxl,
            fontFamily: AppFonts.mono,
            height: 1.1,
          ),
        ),
        Text(
          <String>[
            context.l10n.aDay(_time(stats.averageDay(now))),
            if (change != null)
              context.l10n.changeVsBefore(
                change > 0 ? '+$change%' : '$change%',
              ),
          ].join('  ·  '),
          style: small,
        ),
        SizedBox(height: context.spaceL),
        StatsLineChart(period: stats.period, slots: stats.slots),
        SizedBox(height: context.spaceXl),
        _Switch<_Top>(
          values: _Top.values,
          selected: top,
          label: (_Top t) => switch (t) {
            _Top.tracks => context.l10n.tracks,
            _Top.artists => context.l10n.artists,
            _Top.rooms => context.l10n.rooms,
          },
          onSelected: onTop,
        ),
        SizedBox(height: context.spaceS),
        if (ranked.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: context.spaceM),
            child: Text(context.l10n.nothingHeardHere, style: small),
          ),
        for (int i = 0; i < ranked.length; i++)
          _RankedLine(rank: i + 1, item: ranked[i]),
        SizedBox(height: context.spaceXl),
        for (final (String, String) fact in facts)
          _ReceiptLine(label: fact.$1, value: fact.$2),
        if (week != null && !week.isEmpty) ...<Widget>[
          SizedBox(height: context.spaceL),
          Align(
            child: OutlinedButton.icon(
              onPressed: () {
                final SceneEntity? room = scenes[week.topSceneId];
                unawaited(
                  showRecapSheet(
                    context,
                    stats: week,
                    room: room,
                    topTrack: tracks[week.topTrackId]?.title,
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.onSurface,
                side: BorderSide(color: cs.outlineVariant),
                shape: const StadiumBorder(),
                padding: EdgeInsets.symmetric(
                  horizontal: context.spaceL,
                  vertical: context.spaceS,
                ),
              ),
              icon: AppIcon(AppGlyph.share, size: context.fontM),
              label: Text(
                context.l10n.shareYourWeek,
                style: TextStyle(fontSize: context.fontS),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A row of words to pick one of, in mono capitals: the picked one bright
/// with a pixel underneath, the rest quiet. Lighter than chips.
class _Switch<T> extends StatelessWidget {
  const _Switch({
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) label;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final double dot = context.screenWidth * 0.012;

    return Row(
      children: <Widget>[
        for (final T value in values)
          Semantics(
            button: true,
            selected: value == selected,
            child: InkWell(
              onTap: value == selected ? null : () => onSelected(value),
              borderRadius: BorderRadius.circular(context.spaceS),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.spaceS,
                  vertical: context.spaceXs,
                ),
                child: Column(
                  children: <Widget>[
                    Text(
                      label(value).toUpperCase(),
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        color: value == selected
                            ? cs.onSurface
                            : cs.onSurfaceVariant.withValues(alpha: 0.7),
                        fontSize: context.fontXs,
                        letterSpacing: context.fontXs * 0.12,
                      ),
                    ),
                    SizedBox(height: dot),
                    Visibility.maintain(
                      visible: value == selected,
                      child: Container(
                        width: dot,
                        height: dot,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Ranked {
  const _Ranked(this.title, this.subtitle, this.time);

  final String title;
  final String? subtitle;
  final Duration time;
}

/// One place in the list: "01", the name (and artist), the time.
class _RankedLine extends StatelessWidget {
  const _RankedLine({required this.rank, required this.item});

  final int rank;
  final _Ranked item;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spaceS),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: context.screenWidth * 0.1,
            child: Text(
              rank.toString().padLeft(2, '0'),
              style: TextStyle(
                fontFamily: AppFonts.mono,
                color: rank == 1 ? cs.primary : cs.onSurfaceVariant,
                fontSize: context.fontS,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: context.fontS,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.subtitle case final String subtitle)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: context.fontXs,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: context.spaceS),
          Text(
            listeningTimeLabel(item.time),
            style: TextStyle(
              fontFamily: AppFonts.mono,
              color: cs.onSurfaceVariant,
              fontSize: context.fontXs,
            ),
          ),
        ],
      ),
    );
  }
}

/// One line of the receipt: the name in small capitals, dots, the value.
class _ReceiptLine extends StatelessWidget {
  const _ReceiptLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spaceXs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: AppFonts.mono,
              color: cs.onSurfaceVariant,
              fontSize: context.fontXs,
              letterSpacing: context.fontXs * 0.12,
            ),
          ),
          // The leader: dots as far as the value, the way a receipt does.
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.spaceS),
              child: Text(
                '·' * 80,
                maxLines: 1,
                overflow: TextOverflow.clip,
                softWrap: false,
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  color: cs.outlineVariant,
                  fontSize: context.fontXs,
                ),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.screenWidth * 0.55),
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: context.fontS,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
