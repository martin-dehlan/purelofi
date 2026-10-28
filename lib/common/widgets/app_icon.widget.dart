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
  heart,
  heartOutline,
  add,
  shuffle,
  repeatOne,
  inOrder,
  sort,
  search,
  check,
  dropDown,
  queue,
  more,
  account,
  remove,
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

  /// Glyphs that are lines rather than shapes, drawn with a round stroke of
  /// the same weight as the bars of the filled ones.
  static const Set<AppGlyph> _stroked = <AppGlyph>{
    AppGlyph.shuffle,
    AppGlyph.repeatOne,
    AppGlyph.inOrder,
    AppGlyph.search,
    AppGlyph.check,
    AppGlyph.heartOutline,
  };

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final Paint paint = Paint()
      ..color = color
      ..isAntiAlias = true;
    if (_stroked.contains(glyph)) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
    }
    canvas.drawPath(_path(glyph), paint);
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
      // A bare triangle each way, no bar: smaller than play beside them, so
      // the three still read apart.
      case AppGlyph.previous:
        p.addPath(_triangle(17, 5.5, 6, 12, 17, 18.5), Offset.zero);
      case AppGlyph.next:
        p.addPath(_triangle(7, 5.5, 18, 12, 7, 18.5), Offset.zero);
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
        // The same heart as a line, at the weight of the other line glyphs.
        p.addPath(_heart().transform(_scaleAbout(12, 12.5, 0.88)), Offset.zero);
      case AppGlyph.add:
        p
          ..addRRect(_bar(10.7, 4, 2.6, 16))
          ..addRRect(_bar(4, 10.7, 16, 2.6));
      case AppGlyph.shuffle:
        // Two paths that cross on their way to the right.
        p
          ..moveTo(4, 7)
          ..lineTo(7.5, 7)
          ..cubicTo(12, 7, 12, 17, 16.5, 17)
          ..lineTo(19.5, 17)
          ..moveTo(4, 17)
          ..lineTo(7.5, 17)
          ..cubicTo(12, 17, 12, 7, 16.5, 7)
          ..lineTo(19.5, 7)
          ..moveTo(17, 4.5)
          ..lineTo(19.5, 7)
          ..lineTo(17, 9.5)
          ..moveTo(17, 14.5)
          ..lineTo(19.5, 17)
          ..lineTo(17, 19.5);
      case AppGlyph.inOrder:
        // Two arrows side by side, both straight on: one after the other.
        p
          ..moveTo(4, 8)
          ..lineTo(18.5, 8)
          ..moveTo(15.5, 5)
          ..lineTo(18.5, 8)
          ..lineTo(15.5, 11)
          ..moveTo(4, 16)
          ..lineTo(18.5, 16)
          ..moveTo(15.5, 13)
          ..lineTo(18.5, 16)
          ..lineTo(15.5, 19);
      case AppGlyph.repeatOne:
        // The loop with a one inside it: this track, again.
        p
          ..addPath(_loop(), Offset.zero)
          ..moveTo(10.8, 10.6)
          ..lineTo(12.2, 9.8)
          ..lineTo(12.2, 14.2);
      case AppGlyph.sort:
        p
          ..addRRect(_bar(4, 6, 16, 2.6))
          ..addRRect(_bar(4, 10.7, 11, 2.6))
          ..addRRect(_bar(4, 15.4, 6, 2.6));
      case AppGlyph.search:
        p
          ..addOval(
            Rect.fromCircle(center: const Offset(10.5, 10.5), radius: 6),
          )
          ..moveTo(15, 15)
          ..lineTo(20, 20);
      case AppGlyph.check:
        p
          ..moveTo(5, 12.5)
          ..lineTo(10, 17.5)
          ..lineTo(19, 7);
      case AppGlyph.dropDown:
        p.addPath(_triangle(7, 10, 17, 10, 12, 15), Offset.zero);
      case AppGlyph.queue:
        // A list with the one that plays next marked.
        p
          ..addRRect(_bar(4, 5, 16, 2.6))
          ..addRRect(_bar(4, 10.2, 16, 2.6))
          ..addRRect(_bar(4, 15.4, 8, 2.6))
          ..addPath(_triangle(15, 14, 20.5, 17.2, 15, 20.4), Offset.zero);
      case AppGlyph.more:
        for (final double x in <double>[5.5, 12, 18.5]) {
          p.addOval(Rect.fromCircle(center: Offset(x, 12), radius: 2));
        }
      case AppGlyph.account:
        p
          ..addOval(Rect.fromCircle(center: const Offset(12, 8), radius: 4))
          ..moveTo(4, 21)
          ..cubicTo(4, 16.5, 7.6, 14, 12, 14)
          ..cubicTo(16.4, 14, 20, 16.5, 20, 21)
          ..close();
      case AppGlyph.remove:
        p.addRRect(_bar(4, 10.7, 16, 2.6));
    }
    return p;
  }

  /// Two arrows chasing each other round a rounded box.
  static Path _loop() => Path()
    ..moveTo(4, 13)
    ..lineTo(4, 10)
    ..quadraticBezierTo(4, 7, 7, 7)
    ..lineTo(19, 7)
    ..moveTo(16.5, 4.5)
    ..lineTo(19, 7)
    ..lineTo(16.5, 9.5)
    ..moveTo(20, 11)
    ..lineTo(20, 14)
    ..quadraticBezierTo(20, 17, 17, 17)
    ..lineTo(5, 17)
    ..moveTo(7.5, 14.5)
    ..lineTo(5, 17)
    ..lineTo(7.5, 19.5);

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
