import 'dart:math';

import 'package:flutter/material.dart';

/// The bars of a track's waveform, and the scrubber.
///
/// The shape is **decorative**: it is derived from the track id, not from the
/// audio. Reading real amplitudes would mean downloading and decoding the
/// file before the first note plays, which is a poor trade for a bar chart.
/// What is honest is the position — the split between played and unplayed is
/// the real playback position.
class Waveform extends StatefulWidget {
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

  /// Called with a fraction of the track once the listener lets go.
  final ValueChanged<double> onSeek;

  final double height;

  /// Bars per waveform. Odd, so it never lines up with a four-beat feel.
  static const int barCount = 57;

  static final Map<String, List<double>> _cache = <String, List<double>>{};

  /// The bar heights for [seed], from 0.15 to 1.
  ///
  /// Cached: the shape never changes for a given track, and rebuilding it on
  /// every position tick was showing up as stutter while scrubbing.
  static List<double> barsFor(String seed) {
    return _cache.putIfAbsent(seed, () {
      final Random random = Random(seed.hashCode);

      return List<double>.generate(barCount, (int i) {
        // A slow swell across the track plus per-bar noise: reads as music
        // rather than as a random fence.
        final double swell = 0.55 + 0.45 * sin(i / barCount * pi * 3);
        final double noise = random.nextDouble();

        return (0.15 + 0.85 * (swell * 0.6 + noise * 0.4)).clamp(0.15, 1.0);
      });
    });
  }

  @override
  State<Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<Waveform> {
  /// Where the finger is while dragging. The bar follows this immediately;
  /// the player is only told once the finger lifts, because asking
  /// `just_audio` to seek on every pointer move makes it re-buffer and
  /// stutter.
  final ValueNotifier<double?> _scrub = ValueNotifier<double?>(null);

  @override
  void dispose() {
    _scrub.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        double fractionAt(Offset local) =>
            (local.dx / constraints.maxWidth).clamp(0.0, 1.0);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (TapDownDetails details) =>
              widget.onSeek(fractionAt(details.localPosition)),
          onHorizontalDragStart: (DragStartDetails details) =>
              _scrub.value = fractionAt(details.localPosition),
          onHorizontalDragUpdate: (DragUpdateDetails details) =>
              _scrub.value = fractionAt(details.localPosition),
          onHorizontalDragEnd: (DragEndDetails details) {
            final double? target = _scrub.value;
            _scrub.value = null;
            if (target != null) widget.onSeek(target);
          },
          onHorizontalDragCancel: () => _scrub.value = null,
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: ValueListenableBuilder<double?>(
              valueListenable: _scrub,
              builder: (BuildContext context, double? scrub, _) {
                return CustomPaint(
                  painter: _WaveformPainter(
                    bars: Waveform.barsFor(widget.seed),
                    progress: (scrub ?? widget.progress).clamp(0, 1),
                    played: cs.onSurface,
                    upcoming: cs.onSurfaceVariant,
                  ),
                );
              },
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
      !identical(oldDelegate.bars, bars) ||
      oldDelegate.played != played;
}
