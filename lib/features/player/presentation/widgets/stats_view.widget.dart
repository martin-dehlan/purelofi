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

/// The week in listening (#151), lean and lo-fi, in small sections each
/// headed in mono capitals: the time and how it went against last week,
/// the days as a short strip of pixel blocks, the hours of the day as one
/// row of cells, the rooms with a meter each, and the rest as a receipt.
/// The recap card only shows once the listener goes to share it.
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
    SceneEntity? sceneOf(String? id) =>
        scenes.where((SceneEntity s) => s.id == id).firstOrNull;
    final SceneEntity? room = sceneOf(stats.topSceneId);
    final String? topTrack = tracks
        .where((TrackEntity t) => t.id == stats.topTrackId)
        .firstOrNull
        ?.title;

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

    final int? change = stats.changeOnLastWeek;
    final List<(String, String)> facts = <(String, String)>[
      if (stats.topArtist case final String artist)
        (context.l10n.artist, artist),
      if (topTrack != null) (context.l10n.track, topTrack),
      if (stats.streak > 0)
        (context.l10n.streak, context.l10n.dayCount(stats.streak)),
      (context.l10n.tracks, '${stats.tracksHeard}'),
      if (stats.artistsHeard > 0)
        (context.l10n.artists, '${stats.artistsHeard}'),
    ];
    final List<(SceneEntity, Duration)> rooms = <(SceneEntity, Duration)>[
      for (final (String, Duration) r in stats.topScenes)
        if (sceneOf(r.$1) case final SceneEntity scene) (scene, r.$2),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Heading(context.l10n.thisWeek),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Text(
              listeningTimeLabel(stats.total),
              style: TextStyle(
                color: cs.primary,
                fontSize: context.fontXl,
                fontFamily: AppFonts.mono,
              ),
            ),
            if (change != null) ...<Widget>[
              SizedBox(width: context.spaceM),
              Flexible(
                child: Text(
                  context.l10n.changeVsLastWeek(
                    change > 0 ? '+$change%' : '$change%',
                  ),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    color: change > 0 ? cs.primary : cs.onSurfaceVariant,
                    fontSize: context.fontXs,
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: context.spaceM),
        _PixelWeek(perDay: stats.perDay),
        if (stats.perHour.length == 24) ...<Widget>[
          SizedBox(height: context.spaceL),
          _Heading(context.l10n.timeOfDay),
          _HourStrip(perHour: stats.perHour),
        ],
        if (rooms.isNotEmpty) ...<Widget>[
          SizedBox(height: context.spaceL),
          _Heading(context.l10n.rooms),
          for (final (SceneEntity, Duration) r in rooms)
            _MeterLine(label: r.$1.title, value: r.$2, of: rooms.first.$2),
        ],
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

/// A section's name in small mono capitals.
class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.spaceS),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: AppFonts.mono,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: context.fontXs,
          letterSpacing: context.fontXs * 0.12,
        ),
      ),
    );
  }
}

/// The hours of the day as one row of 24 cells, midnight first: the more
/// played in an hour, the stronger its cell. Marks at 0, 6, 12 and 18.
class _HourStrip extends StatelessWidget {
  const _HourStrip({required this.perHour});

  final List<Duration> perHour;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final int most = perHour.fold<int>(
      0,
      (int m, Duration d) => d.inSeconds > m ? d.inSeconds : m,
    );
    final double cell = context.screenWidth * 0.045;
    final double gap = context.screenWidth * 0.006;
    final TextStyle mark = TextStyle(
      fontFamily: AppFonts.mono,
      color: cs.onSurfaceVariant,
      fontSize: context.fontXs,
    );

    return Semantics(
      label: <String>[
        for (int h = 0; h < 24; h++)
          if (perHour[h] > Duration.zero)
            '$h:00 ${listeningTimeLabel(perHour[h])}',
      ].join(', '),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              for (int h = 0; h < 24; h++)
                Expanded(
                  child: Container(
                    height: cell,
                    margin: EdgeInsets.only(right: h == 23 ? 0 : gap),
                    color: most == 0 || perHour[h] == Duration.zero
                        ? cs.surfaceContainerHigh
                        : cs.primary.withValues(
                            alpha: 0.25 + 0.75 * perHour[h].inSeconds / most,
                          ),
                  ),
                ),
            ],
          ),
          SizedBox(height: gap * 2),
          Row(
            children: <Widget>[
              for (final String h in <String>['0', '6', '12', '18'])
                Expanded(child: Text(h, style: mark)),
            ],
          ),
        ],
      ),
    );
  }
}

/// A room with its time, and a short meter of blocks set against the room
/// heard most.
class _MeterLine extends StatelessWidget {
  const _MeterLine({
    required this.label,
    required this.value,
    required this.of,
  });

  final String label;
  final Duration value;
  final Duration of;

  static const int blocks = 6;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final int lit = of.inSeconds == 0
        ? 0
        : (blocks * value.inSeconds / of.inSeconds).ceil().clamp(1, blocks);
    final double block = context.screenWidth * 0.022;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spaceXs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: context.fontS,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (int i = 0; i < blocks; i++)
            Container(
              width: block,
              height: block,
              margin: EdgeInsets.only(left: block * 0.3),
              color: i < lit ? cs.primary : cs.surfaceContainerHigh,
            ),
          SizedBox(
            width: context.screenWidth * 0.3,
            child: Text(
              listeningTimeLabel(value),
              textAlign: TextAlign.end,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppFonts.mono,
                color: cs.onSurfaceVariant,
                fontSize: context.fontXs,
              ),
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

  /// Blocks in a column: enough to read, few enough to stay short.
  static const int rows = 6;

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
    final double block = context.screenWidth * 0.022;
    final double width = context.screenWidth * 0.08;
    final double gap = block * 0.35;

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
                    width: width,
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
