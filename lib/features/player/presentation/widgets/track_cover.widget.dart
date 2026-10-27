import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../common/widgets/app_icon.widget.dart';
import '../../domain/track.entity.dart';
import 'waveform.widget.dart';

/// A track's round cover at the start of its row.
///
/// The listener's own files show the cover from their tags. PureLofi's
/// tracks have no artwork — the scene is the picture — so they show a slice
/// of their own waveform: the same bars as the player draws for them, so a
/// track looks like itself everywhere. The one playing is marked on top.
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
    final Widget bars = ColoredBox(
      color: cs.surfaceContainerHighest,
      child: CustomPaint(painter: _BarsPainter(track.id, cs.onSurfaceVariant)),
    );
    final String? path = track.coverPath;

    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (path == null)
              bars
            else
              Image.file(
                File(path),
                fit: BoxFit.cover,
                cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                    .round(),
                errorBuilder: (_, _, _) => bars,
              ),
            if (isCurrent)
              ColoredBox(
                color: cs.scrim.withValues(alpha: 0.6),
                child: Center(
                  child: AppIcon(
                    AppGlyph.nowPlaying,
                    size: size * 0.55,
                    color: cs.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Five bars from the waveform, spread across the cover.
class _BarsPainter extends CustomPainter {
  _BarsPainter(this.seed, this.color);

  final String seed;
  final Color color;

  static const int _shown = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final List<double> bars = Waveform.barsFor(seed);
    final Paint paint = Paint()..color = color;
    // Inside the middle of the circle, so the outer bars are not clipped.
    final double slot = size.width * 0.56 / (_shown * 2 - 1);
    for (int i = 0; i < _shown; i++) {
      final double bar = bars[(i * bars.length / _shown).floor()];
      final double height = size.height * 0.5 * bar;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * 0.22 + slot * i * 2,
            (size.height - height) / 2,
            slot,
            height,
          ),
          Radius.circular(slot / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.color != color || old.seed != seed;
}
