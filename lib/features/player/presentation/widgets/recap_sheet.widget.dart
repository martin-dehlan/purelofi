import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/listening_stats.dart';
import '../../domain/scene.entity.dart';
import 'recap_card.widget.dart';

/// The recap card (#151), shown only when the listener means to share it:
/// the card as it will look, and the button that sends it.
class RecapSheet extends StatefulWidget {
  const RecapSheet({required this.stats, this.room, this.topTrack, super.key});

  final ListeningStats stats;
  final SceneEntity? room;
  final String? topTrack;

  /// The recap is captured at this width: a phone screen's, sharp anywhere.
  static const double recapPixels = 1080;

  @override
  State<RecapSheet> createState() => _RecapSheetState();
}

class _RecapSheetState extends State<RecapSheet> {
  final GlobalKey _recap = GlobalKey();
  bool _sharing = false;

  Future<void> _share(double width) async {
    // Read before any await: the context may be gone after one.
    final String subject = context.l10n.myPurelofiWeek;
    setState(() => _sharing = true);
    try {
      final RenderRepaintBoundary boundary =
          _recap.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(
        pixelRatio: RecapSheet.recapPixels / width,
      );
      final ByteData? png = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (png == null) return;
      final Directory temp = await getTemporaryDirectory();
      final File file = File('${temp.path}/purelofi-week.png');
      await file.writeAsBytes(png.buffer.asUint8List(), flush: true);
      await SharePlus.instance.share(
        ShareParams(files: <XFile>[XFile(file.path)], subject: subject),
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
    final double width = context.screenWidth * 0.7;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          context.horizontalPadding,
          0,
          context.horizontalPadding,
          context.spaceM,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: RepaintBoundary(
                key: _recap,
                child: RecapCard(
                  stats: widget.stats,
                  width: width,
                  room: widget.room,
                  topTrack: widget.topTrack,
                ),
              ),
            ),
            SizedBox(height: context.spaceL),
            FilledButton.icon(
              onPressed: _sharing ? null : () => unawaited(_share(width)),
              icon: AppIcon(
                AppGlyph.share,
                size: context.fontM,
                color: _sharing ? cs.onSurfaceVariant : cs.onPrimary,
              ),
              label: Text(context.l10n.shareYourWeek),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showRecapSheet(
  BuildContext context, {
  required ListeningStats stats,
  SceneEntity? room,
  String? topTrack,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (BuildContext context) =>
      RecapSheet(stats: stats, room: room, topTrack: topTrack),
);
