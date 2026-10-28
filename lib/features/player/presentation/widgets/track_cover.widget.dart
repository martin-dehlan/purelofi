import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/track.entity.dart';
import 'now_playing_bars.widget.dart';

/// A track's round cover at the start of its row.
///
/// The listener's own files show the cover from their tags. Anything
/// without artwork — PureLofi's tracks, where the scene is the picture, and
/// files with no cover tagged — shows a record. Not a waveform: bars are
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
    final Widget record = CustomPaint(
      painter: _RecordPainter(
        disc: cs.surfaceContainerHighest,
        grooves: cs.onSurfaceVariant.withValues(alpha: 0.25),
        label: cs.primary.withValues(alpha: 0.8),
        hole: cs.surface,
      ),
    );
    final String? path = track.coverPath;

    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (path == null)
              record
            else
              Image.file(
                File(path),
                fit: BoxFit.cover,
                cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                    .round(),
                errorBuilder: (_, _, _) => record,
              ),
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
/// hole. Every PureLofi track gets the same one — they have no artwork, and
/// a made-up picture per track would be decoration pretending to be content.
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
