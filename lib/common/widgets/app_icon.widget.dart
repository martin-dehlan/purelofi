import 'dart:typed_data';

import 'package:flutter/material.dart';

/// The shapes the app draws. Filled and compact, so they read over a moving
/// scene without the stair-stepped edges of the old pixel PNGs (#67).
enum AppGlyph {
  play,
  pause,
  previous,
  next,
  menu,
  scene,
  camera,
  nowPlaying,
  heart,
  heartOutline,
  add,
}

/// One of the app's icons, drawn as paths rather than loaded as an image.
///
/// Paths stay sharp at any size and take their colour from the theme, so
/// there is no asset per colour and no image package to carry. The shapes
/// are laid out on a 24-unit grid and scaled to [size].
class AppIcon extends StatelessWidget {
  const AppIcon(this.glyph, {required this.size, this.color, super.key});

  final AppGlyph glyph;
  final double size;

  /// Defaults to `onSurface`.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _GlyphPainter(
          glyph,
          color ?? Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.color);

  final AppGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawPath(
      _path(glyph),
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.color != color;

  static Path _path(AppGlyph glyph) {
    final Path p = Path();
    switch (glyph) {
      case AppGlyph.play:
        p.addPath(_triangle(7, 4.5, 19.5, 12, 7, 19.5), Offset.zero);
      case AppGlyph.pause:
        p
          ..addRRect(_bar(6, 5, 4, 14))
          ..addRRect(_bar(14, 5, 4, 14));
      case AppGlyph.previous:
        p
          ..addRRect(_bar(5, 5, 2.6, 14))
          ..addPath(_triangle(19, 5.5, 9, 12, 19, 18.5), Offset.zero);
      case AppGlyph.next:
        p
          ..addRRect(_bar(16.4, 5, 2.6, 14))
          ..addPath(_triangle(5, 5.5, 15, 12, 5, 18.5), Offset.zero);
      case AppGlyph.menu:
        p
          ..addRRect(_bar(4, 6, 16, 2.6))
          ..addRRect(_bar(4, 10.7, 16, 2.6))
          ..addRRect(_bar(4, 15.4, 10, 2.6));
      case AppGlyph.scene:
        // A picture in front of another: switch to the next room.
        p
          ..addRRect(_bar(3, 7, 14, 14, radius: 2.2))
          ..addRRect(_bar(7.5, 3, 13.5, 3, radius: 1.5))
          ..addRRect(_bar(18, 3, 3, 13.5, radius: 1.5));
      case AppGlyph.camera:
        p
          ..addRRect(_bar(3, 7, 12.5, 10, radius: 2))
          ..addPath(_triangle(16.5, 12, 21, 8, 21, 16), Offset.zero);
      case AppGlyph.heart:
        p.addPath(_heart(), Offset.zero);
      case AppGlyph.heartOutline:
        // The same heart with a smaller one cut out of it, so both states are
        // one shape at one weight.
        p.addPath(
          Path.combine(
            PathOperation.difference,
            _heart(),
            _heart().transform(_scaleAbout(12, 12.5, 0.62)),
          ),
          Offset.zero,
        );
      case AppGlyph.add:
        p
          ..addRRect(_bar(10.7, 4, 2.6, 16))
          ..addRRect(_bar(4, 10.7, 16, 2.6));
      case AppGlyph.nowPlaying:
        p
          ..addRRect(_bar(5, 11, 3, 6))
          ..addRRect(_bar(10.5, 7, 3, 10))
          ..addRRect(_bar(16, 9, 3, 8));
    }
    return p;
  }

  static Path _heart() => Path()
    ..moveTo(12, 20.5)
    ..cubicTo(12, 20.5, 3, 15, 3, 9)
    ..cubicTo(3, 6, 5.2, 4, 7.8, 4)
    ..cubicTo(9.6, 4, 11.1, 5, 12, 6.5)
    ..cubicTo(12.9, 5, 14.4, 4, 16.2, 4)
    ..cubicTo(18.8, 4, 21, 6, 21, 9)
    ..cubicTo(21, 15, 12, 20.5, 12, 20.5)
    ..close();

  /// Scales by [s] around ([cx], [cy]), as a column-major 4x4 matrix.
  static Float64List _scaleAbout(double cx, double cy, double s) =>
      Float64List.fromList(<double>[
        s, 0, 0, 0, //
        0, s, 0, 0,
        0, 0, 1, 0,
        cx * (1 - s), cy * (1 - s), 0, 1,
      ]);

  static RRect _bar(
    double x,
    double y,
    double w,
    double h, {
    double radius = 1.1,
  }) => RRect.fromRectAndRadius(
    Rect.fromLTWH(x, y, w, h),
    Radius.circular(radius),
  );

  static Path _triangle(
    double ax,
    double ay,
    double bx,
    double by,
    double cx,
    double cy,
  ) => Path()
    ..moveTo(ax, ay)
    ..lineTo(bx, by)
    ..lineTo(cx, cy)
    ..close();
}
