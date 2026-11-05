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

/// The week in listening (#151), lean and lo-fi: the time in the mono
/// face, the days as columns of pixel blocks, what stood out as a receipt
/// of dotted lines, and a quiet way to share. The recap card itself only
/// shows once the listener goes to share it.
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

    final TextStyle mono = TextStyle(
      fontFamily: AppFonts.mono,
      color: cs.onSurfaceVariant,
      fontSize: context.fontXs,
      letterSpacing: context.fontXs * 0.12,
    );

    if (stats.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.spaceL),
        child: Text(
          context.l10n.nothingHeardThisWeek,
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: context.fontS),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(context.l10n.thisWeek.toUpperCase(), style: mono),
        Text(
          listeningTimeLabel(stats.total),
          style: TextStyle(
            color: cs.primary,
            fontSize: context.fontXxl,
            fontFamily: AppFonts.mono,
          ),
        ),
        SizedBox(height: context.spaceL),
        _PixelWeek(perDay: stats.perDay),
        SizedBox(height: context.spaceL),
        for (final (String, String) fact in facts)
          _ReceiptLine(label: fact.$1, value: fact.$2),
        SizedBox(height: context.spaceL),
        Align(
          child: OutlinedButton.icon(
            onPressed: () => unawaited(
              showRecapSheet(
                context,
                stats: stats,
                room: room,
                topTrack: topTrack,
              ),
            ),
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
          // As wide as it needs, up to a little over half the line; the
          // dots take the rest, so the value always ends at the edge.
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

/// The week as seven columns of square pixel blocks, Monday first, like a
/// level meter: a day fills as many blocks as it was long against the
/// longest. Today in full colour, the days before it quieter, the blocks
/// not reached barely there. Day letters from the phone's language.
class _PixelWeek extends StatelessWidget {
  const _PixelWeek({required this.perDay});

  final List<Duration> perDay;

  /// Blocks in a column.
  static const int rows = 10;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<String> narrow = MaterialLocalizations.of(
      context,
    ).narrowWeekdays;
    // Sunday first there; the week here starts on Monday.
    final List<String> days = <String>[...narrow.skip(1), narrow.first];
    final int today = DateTime.now().weekday - 1;
    final int longest = perDay.fold<int>(
      0,
      (int m, Duration d) => d.inSeconds > m ? d.inSeconds : m,
    );
    final double block = context.screenWidth * 0.04;
    final double gap = block * 0.25;

    int filled(Duration d) {
      if (longest == 0 || d == Duration.zero) return 0;
      return (rows * d.inSeconds / longest).ceil().clamp(1, rows);
    }

    return Semantics(
      label: <String>[
        for (int i = 0; i < 7; i++)
          '${days[i]} ${listeningTimeLabel(perDay[i])}',
      ].join(', '),
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          for (int i = 0; i < 7; i++)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (int r = rows - 1; r >= 0; r--)
                  Container(
                    width: block,
                    height: block,
                    margin: EdgeInsets.only(bottom: gap),
                    color: r < filled(perDay[i])
                        ? (i == today
                              ? cs.primary
                              : cs.primary.withValues(alpha: 0.5))
                        : cs.surfaceContainerHigh,
                  ),
                SizedBox(height: gap),
                Text(
                  days[i],
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    color: i == today ? cs.onSurface : cs.onSurfaceVariant,
                    fontSize: context.fontXs,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
