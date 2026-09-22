import 'dart:math';

import 'package:flutter/material.dart';

/// The bars of a track's waveform, and the scrubber.
///
/// The shape is **decorative**: it is derived from the track id, not from the
/// audio. Reading real amplitudes would mean downloading and decoding the
/// file before the first note plays, which is a poor trade for a bar chart.
/// What is honest is the position — the split between played and unplayed is
/// the real playback position.
class Waveform extends StatelessWidget {
  const Waveform({
    required this.seed,
    required this.progress,
    required this.onSeek,
    required this.height,
    super.key,
  });

  /// Anything stable per track; the bars are generated from it, so the same
  /// track always looks the same.
  final String seed;

  /// 0 to 1.
  final double progress;

  /// Called with a fraction of the track when the listener taps or drags.
  final ValueChanged<double> onSeek;

  final double height;

  /// Bars per waveform. Odd, so it never lines up with a four-beat feel.
  static const int barCount = 57;

  /// The bar heights for [seed], from 0.15 to 1.
  static List<double> barsFor(String seed) {
    final Random random = Random(seed.hashCode);

    return List<double>.generate(barCount, (int i) {
      // A slow swell across the track plus per-bar noise: reads as music
      // rather than as a random fence.
      final double swell = 0.55 + 0.45 * sin(i / barCount * pi * 3);
      final double noise = random.nextDouble();

      return (0.15 + 0.85 * (swell * 0.6 + noise * 0.4)).clamp(0.15, 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        void seekTo(Offset local) {
          final double fraction = (local.dx / constraints.maxWidth).clamp(
            0.0,
            1.0,
          );
          onSeek(fraction);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (TapDownDetails details) => seekTo(details.localPosition),
          onHorizontalDragUpdate: (DragUpdateDetails details) =>
              seekTo(details.localPosition),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: CustomPaint(
              painter: _WaveformPainter(
                bars: barsFor(seed),
                progress: progress.clamp(0, 1),
                played: cs.onSurface,
                upcoming: cs.onSurfaceVariant,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.bars,
    required this.progress,
    required this.played,
    required this.upcoming,
  });

  final List<double> bars;
  final double progress;
  final Color played;
  final Color upcoming;

  @override
  void paint(Canvas canvas, Size size) {
    final double slot = size.width / bars.length;
    final double barWidth = (slot * 0.5).clamp(1.0, 4.0);
    final double centre = size.height / 2;
    final int playedBars = (bars.length * progress).round();

    final Paint paint = Paint()
      ..isAntiAlias = false
      ..style = PaintingStyle.fill;

    for (int i = 0; i < bars.length; i++) {
      final double x = i * slot + (slot - barWidth) / 2;
      final bool isPlayed = i < playedBars;
      paint.color = isPlayed ? played : upcoming.withValues(alpha: 0.45);

      final double full = bars[i] * size.height * 0.5;

      if (isPlayed) {
        canvas.drawRect(
          Rect.fromLTWH(x, centre - full, barWidth, full * 2),
          paint,
        );
        continue;
      }

      // Not yet played: the same bar, drawn as a dashed column.
      const double dash = 2;
      const double gap = 2;
      for (double y = centre - full; y < centre + full; y += dash + gap) {
        final double segment = min(dash, centre + full - y);
        canvas.drawRect(Rect.fromLTWH(x, y, barWidth, segment), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.bars != bars ||
      oldDelegate.played != played;
}
