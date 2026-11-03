import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/track.entity.dart';
import 'now_playing_bars.widget.dart';

/// A track's cover at the start of its row: a square with softened
/// corners, as artwork is made and as music apps show it. Cutting it round
/// would lose the corners, and the signature often sits there.
///
/// PureLofi's tracks show the artwork their artist made for them, the
/// listener's own files the cover from their tags. Anything without
/// artwork shows a record. Not a waveform: bars are
/// what marks the track that is playing, and a cover drawn the same way
/// would make every row look like it was. The one playing is marked on top.
class TrackCover extends StatelessWidget {
  const TrackCover({
    required this.track,
    required this.size,
    this.isCurrent = false,
    super.key,
  });

  final TrackEntity track;
  final double size;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    // A record on a sleeve: the stand-in sits on the same square, so a list
    // with and without artwork keeps one shape.
    final Widget record = ColoredBox(
      color: cs.surfaceContainerHigh,
      child: Padding(
        padding: EdgeInsets.all(size * 0.08),
        child: CustomPaint(
          painter: _RecordPainter(
            disc: cs.surfaceContainerHighest,
            grooves: cs.onSurfaceVariant.withValues(alpha: 0.25),
            label: cs.primary.withValues(alpha: 0.8),
            hole: cs.surface,
          ),
        ),
      ),
    );
    final String? path = track.coverPath;
    final String? url = track.coverUrl;
    final int pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();

    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.12),
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (path != null)
              Image.file(
                File(path),
                fit: BoxFit.cover,
                cacheWidth: pixels,
                errorBuilder: (_, _, _) => record,
              )
            else if (url != null)
              Image.network(
                url,
                fit: BoxFit.cover,
                cacheWidth: pixels,
                // The record stands in while it loads, and for good if it
                // will not.
                frameBuilder: (_, Widget child, int? frame, bool sync) =>
                    sync || frame != null ? child : record,
                errorBuilder: (_, _, _) => record,
              )
            else
              record,
            if (isCurrent)
              ColoredBox(
                color: cs.scrim.withValues(alpha: 0.6),
                child: Center(
                  child: NowPlayingBars(size: size * 0.55, color: cs.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A record seen from above: the disc, a few grooves, the label and the
/// hole. Every track without artwork gets the same one — a made-up picture
/// per track would be decoration pretending to be content.
class _RecordPainter extends CustomPainter {
  _RecordPainter({
    required this.disc,
    required this.grooves,
    required this.label,
    required this.hole,
  });

  final Color disc;
  final Color grooves;
  final Color label;
  final Color hole;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = size.center(Offset.zero);
    final double radius = size.shortestSide / 2;

    canvas.drawCircle(centre, radius, Paint()..color = disc);

    final Paint groove = Paint()
      ..color = grooves
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.03;
    for (final double ring in <double>[0.82, 0.68, 0.54]) {
      canvas.drawCircle(centre, radius * ring, groove);
    }

    canvas.drawCircle(centre, radius * 0.34, Paint()..color = label);
    canvas.drawCircle(centre, radius * 0.07, Paint()..color = hole);
  }

  @override
  bool shouldRepaint(_RecordPainter old) =>
      old.disc != disc ||
      old.grooves != grooves ||
      old.label != label ||
      old.hole != hole;
}
