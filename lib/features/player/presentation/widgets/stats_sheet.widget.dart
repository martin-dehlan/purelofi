import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../common/utils/app_fonts.dart';
import '../../../../common/utils/responsive.dart';
import '../../controller/scene.controller.dart';
import '../../controller/stats.controller.dart';
import '../../controller/track.controller.dart';
import '../../domain/listening_stats.dart';
import '../../domain/scene.entity.dart';
import '../../domain/track.entity.dart';
import 'recap_card.widget.dart';
import '../../../../l10n/l10n.dart';

/// The week in more detail (#151): the days as bars, the room, the artist,
/// the track, the streak, and the recap card to share.
class StatsSheet extends ConsumerStatefulWidget {
  const StatsSheet({super.key});

  /// The recap is captured at this width: a phone screen's, sharp anywhere.
  static const double recapPixels = 1080;

  @override
  ConsumerState<StatsSheet> createState() => _StatsSheetState();
}

class _StatsSheetState extends ConsumerState<StatsSheet> {
  final GlobalKey _recap = GlobalKey();
  bool _sharing = false;

  Future<void> _share(double width) async {
    setState(() => _sharing = true);
    try {
      final RenderRepaintBoundary boundary =
          _recap.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(
        pixelRatio: StatsSheet.recapPixels / width,
      );
      final ByteData? png = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (png == null) return;
      final Directory temp = await getTemporaryDirectory();
      final File file = File('${temp.path}/purelofi-week.png');
      await file.writeAsBytes(png.buffer.asUint8List(), flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path)],
          subject: 'My PureLofi week',
        ),
      );
    } on Object {
      // A share that did not happen is nothing to report.
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
    final double recapWidth = context.screenWidth * 0.6;

    TextStyle label() =>
        TextStyle(color: cs.onSurfaceVariant, fontSize: context.fontS);
    TextStyle value() => TextStyle(
      color: cs.onSurface,
      fontSize: context.fontM,
      fontWeight: FontWeight.w600,
    );

    Widget fact(String name, String? text) => text == null
        ? const SizedBox.shrink()
        : Padding(
            padding: EdgeInsets.only(bottom: context.spaceS),
            child: Row(
              children: <Widget>[
                Expanded(child: Text(name, style: label())),
                Flexible(
                  child: Text(
                    text,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: value(),
                  ),
                ),
              ],
            ),
          );

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(context.l10n.thisWeek, style: label()),
            Text(
              listeningTimeLabel(stats.total),
              style: TextStyle(
                color: cs.primary,
                fontSize: context.fontXl,
                fontFamily: AppFonts.mono,
              ),
            ),
            SizedBox(height: context.spaceM),
            _WeekBars(perDay: stats.perDay),
            SizedBox(height: context.spaceM),
            fact('Room', room?.title),
            fact('Artist', stats.topArtist),
            fact('Track', topTrack),
            fact(
              'Streak',
              stats.streak == 0
                  ? null
                  : (stats.streak == 1 ? '1 day' : '${stats.streak} days'),
            ),
            if (!stats.isEmpty) ...<Widget>[
              SizedBox(height: context.spaceM),
              Center(
                child: RepaintBoundary(
                  key: _recap,
                  child: RecapCard(
                    stats: stats,
                    width: recapWidth,
                    room: room,
                    topTrack: topTrack,
                  ),
                ),
              ),
              SizedBox(height: context.spaceM),
              FilledButton(
                onPressed: _sharing
                    ? null
                    : () => unawaited(_share(recapWidth)),
                child: Text(context.l10n.shareYourWeek),
              ),
            ],
            SizedBox(height: context.spaceL),
          ],
        ),
      ),
    );
  }
}

/// Seven bars, Monday first, as tall as the day was long against the
/// longest. Flat, in the theme's colours (`docs/09`).
class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.perDay});

  final List<Duration> perDay;

  static const List<String> days = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final int longest = perDay.fold<int>(
      0,
      (int m, Duration d) => d.inSeconds > m ? d.inSeconds : m,
    );
    final double height = context.screenHeight * 0.1;

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
                        ? 1
                        : (height * perDay[i].inSeconds / longest).clamp(
                            1,
                            height,
                          ),
                    margin: EdgeInsets.symmetric(horizontal: context.spaceXs),
                    color: perDay[i] == Duration.zero
                        ? cs.surfaceContainerHighest
                        : cs.primary,
                  ),
                  SizedBox(height: context.spaceXs),
                  Text(
                    days[i],
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: context.fontXs,
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

Future<void> showStatsSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (BuildContext context) =>
      const FractionallySizedBox(heightFactor: 0.9, child: StatsSheet()),
);
