import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controller/player.controller.dart';

/// The three bars on the cover of the track that is playing.
///
/// They bounce while the music plays and rest when it is paused, so the
/// mark says not just which track but whether it is going. Under reduced
/// motion they always rest. The heights step on the icon grid rather than
/// gliding, so they move in whole pixels like everything else.
class NowPlayingBars extends ConsumerStatefulWidget {
  const NowPlayingBars({required this.size, required this.color, super.key});

  final double size;
  final Color color;

  /// How long one bar takes to rise and fall.
  static const Duration period = Duration(milliseconds: 900);

  @override
  ConsumerState<NowPlayingBars> createState() => _NowPlayingBarsState();
}

class _NowPlayingBarsState extends ConsumerState<NowPlayingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beat = AnimationController(
    vsync: this,
    duration: NowPlayingBars.period,
  );

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool playing = ref.watch(
      playerControllerProvider.select((state) => state.isPlaying),
    );
    final bool moving = playing && !MediaQuery.disableAnimationsOf(context);
    if (moving && !_beat.isAnimating) {
      _beat.repeat();
    } else if (!moving && _beat.isAnimating) {
      _beat.stop();
    }

    return SizedBox.square(
      dimension: widget.size,
      child: CustomPaint(
        painter: _BarsPainter(beat: _beat, moving: moving, color: widget.color),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({required this.beat, required this.moving, required this.color})
    : super(repaint: beat);

  final Animation<double> beat;
  final bool moving;
  final Color color;

  /// The resting heights, on a 24-unit grid: the still mark.
  static const List<double> _rest = <double>[6, 10, 8];

  /// Each bar runs its own part of the beat, so they never move as one.
  static const List<double> _phase = <double>[0, 0.37, 0.71];

  /// How far a bar travels, in grid units, between its lowest and highest.
  static const double _low = 5;
  static const double _high = 13;

  @override
  void paint(Canvas canvas, Size size) {
    final double unit = size.width / 24;
    final Paint paint = Paint()..color = color;

    for (int i = 0; i < 3; i++) {
      final double height = moving
          ? barHeight(beat.value, _phase[i])
          : _rest[i];
      final double x = 5 + i * 5.5;
      // Grown from a shared floor, the way a level meter reads.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x * unit,
            (17 - height) * unit,
            3 * unit,
            height * unit,
          ),
          Radius.circular(1.5 * unit),
        ),
        paint,
      );
    }
  }

  /// A bar's height at [t] through the beat, in whole grid units.
  static double barHeight(double t, double phase) {
    final double wave = 0.5 - 0.5 * math.cos(2 * math.pi * (t + phase));

    return (_low + (_high - _low) * wave).roundToDouble();
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.moving != moving || old.color != color || old.beat != beat;
}
