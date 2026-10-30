import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Google's "G", drawn rather than loaded.
///
/// The one place the app's colours do not come from the theme, on purpose:
/// Google's sign-in branding requires its own four colours on the mark, the
/// way Apple's requires its own button. A brand mark is an asset, not
/// styling (`docs/09`).
class GoogleMark extends StatelessWidget {
  const GoogleMark({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: const CustomPaint(painter: _GooglePainter()),
  );
}

class _GooglePainter extends CustomPainter {
  const _GooglePainter();

  static const Color _blue = Color(0xFF4285F4);
  static const Color _red = Color(0xFFEA4335);
  static const Color _yellow = Color(0xFFFBBC05);
  static const Color _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final double stroke = size.width * 0.2;
    final Rect ring = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.width - stroke) / 2,
    );
    Paint arc(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    double deg(double d) => d * math.pi / 180;

    // Clockwise from the bar on the right: blue, green, yellow, red, and the
    // gap at the top right where the G opens.
    canvas
      ..drawArc(ring, deg(-10), deg(55), false, arc(_blue))
      ..drawArc(ring, deg(45), deg(90), false, arc(_green))
      ..drawArc(ring, deg(135), deg(90), false, arc(_yellow))
      ..drawArc(ring, deg(225), deg(90), false, arc(_red))
      ..drawRect(
        Rect.fromLTWH(
          size.width / 2,
          size.height / 2 - stroke / 2,
          size.width / 2,
          stroke,
        ),
        Paint()..color = _blue,
      );
  }

  @override
  bool shouldRepaint(_GooglePainter old) => false;
}
