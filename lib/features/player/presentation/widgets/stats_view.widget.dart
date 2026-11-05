import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/app_fonts.dart';
import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../../../l10n/l10n.dart';
import '../../controller/scene.controller.dart';
import '../../controller/stats.controller.dart';
import '../../controller/track.controller.dart';
import '../../domain/listening_stats.dart';
import '../../domain/scene.entity.dart';
import '../../domain/track.entity.dart';
import 'recap_sheet.widget.dart';

/// The week in listening (#151): the time large, the days as bars on a
/// card, what stood out as four tiles, and a way to share it. The recap
/// card itself only shows once the listener goes to share it.
class StatsView extends ConsumerWidget {
  const StatsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final ListeningStats stats =
        ref.watch(weekStatsProvider).value ?? ListeningStats.empty;
    final List<SceneEntity> scenes =
        ref.watch(sceneListControllerProvider).value ?? const <SceneEntity>[];
    final List<TrackEntity> tracks =
        ref.watch(trackListControllerProvider).value ?? const <TrackEntity>[];
    final SceneEntity? room = scenes
        .where((SceneEntity s) => s.id == stats.topSceneId)
        .firstOrNull;
    final String? topTrack = tracks
        .where((TrackEntity t) => t.id == stats.topTrackId)
        .firstOrNull
        ?.title;

    final TextStyle label = TextStyle(
      color: cs.onSurfaceVariant,
      fontSize: context.fontS,
    );

    if (stats.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.spaceL),
        child: Text(
          context.l10n.nothingHeardThisWeek,
          textAlign: TextAlign.center,
          style: label,
        ),
      );
    }

    final List<(String, String)> facts = <(String, String)>[
      if (room != null) (context.l10n.room, room.title),
      if (stats.topArtist case final String artist)
        (context.l10n.artist, artist),
      if (topTrack != null) (context.l10n.track, topTrack),
      if (stats.streak > 0)
        (context.l10n.streak, context.l10n.dayCount(stats.streak)),
    ];

    BoxDecoration card() => BoxDecoration(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(context.cardBorderRadius * 1.5),
    );

    Widget tile((String, String) fact) => Container(
      padding: EdgeInsets.all(context.spaceM),
      decoration: card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(fact.$1, style: label),
          SizedBox(height: context.spaceXs),
          Text(
            fact.$2,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: context.fontM,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(context.l10n.thisWeek, style: label),
        Text(
          listeningTimeLabel(stats.total),
          style: TextStyle(
            color: cs.primary,
            fontSize: context.fontXxl,
            fontFamily: AppFonts.mono,
          ),
        ),
        SizedBox(height: context.spaceM),
        Container(
          padding: EdgeInsets.all(context.spaceM),
          decoration: card(),
          child: _WeekBars(perDay: stats.perDay),
        ),
        SizedBox(height: context.spaceS),
        // Two to a row, so the four read at a glance.
        for (int i = 0; i < facts.length; i += 2)
          Padding(
            padding: EdgeInsets.only(top: context.spaceS),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(child: tile(facts[i])),
                  SizedBox(width: context.spaceS),
                  Expanded(
                    child: i + 1 < facts.length
                        ? tile(facts[i + 1])
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        SizedBox(height: context.spaceL),
        FilledButton.icon(
          onPressed: () => unawaited(
            showRecapSheet(
              context,
              stats: stats,
              room: room,
              topTrack: topTrack,
            ),
          ),
          icon: AppIcon(
            AppGlyph.share,
            size: context.fontM,
            color: cs.onPrimary,
          ),
          label: Text(context.l10n.shareYourWeek),
        ),
      ],
    );
  }
}

/// Seven bars, Monday first, as tall as the day was long against the
/// longest, today in full colour and the days before it quieter. The
/// day letters come from the phone's language. Flat, in the theme's
/// colours (`docs/09`).
class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.perDay});

  final List<Duration> perDay;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    // Sunday first there; the week here starts on Monday.
    final List<String> narrow = MaterialLocalizations.of(
      context,
    ).narrowWeekdays;
    final List<String> days = <String>[...narrow.skip(1), narrow.first];
    final int today = DateTime.now().weekday - 1;
    final int longest = perDay.fold<int>(
      0,
      (int m, Duration d) => d.inSeconds > m ? d.inSeconds : m,
    );
    final double height = context.screenHeight * 0.12;
    final Radius corner = Radius.circular(context.spaceXs * 1.5);

    return Semantics(
      label: <String>[
        for (int i = 0; i < 7; i++)
          '${days[i]} ${listeningTimeLabel(perDay[i])}',
      ].join(', '),
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (int i = 0; i < 7; i++)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    height: longest == 0
                        ? context.spaceXs
                        : (height * perDay[i].inSeconds / longest).clamp(
                            context.spaceXs,
                            height,
                          ),
                    margin: EdgeInsets.symmetric(horizontal: context.spaceXs),
                    decoration: BoxDecoration(
                      color: perDay[i] == Duration.zero
                          ? cs.surfaceContainerHighest
                          : i == today
                          ? cs.primary
                          : cs.primary.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.vertical(top: corner),
                    ),
                  ),
                  SizedBox(height: context.spaceS),
                  Text(
                    days[i],
                    style: TextStyle(
                      color: i == today ? cs.onSurface : cs.onSurfaceVariant,
                      fontSize: context.fontXs,
                      fontWeight: i == today ? FontWeight.w700 : null,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
