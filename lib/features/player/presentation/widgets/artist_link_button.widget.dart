import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_parsing/path_parsing.dart';

import '../../../../common/utils/app_links.dart';
import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../domain/artist_link.dart';
import 'artist_link_marks.dart';

/// One of an artist's channels, as a round button with the platform's mark
/// (#109), one of a row in the floating bar at the foot of their page. Its
/// own site is a globe.
class ArtistLinkButton extends StatelessWidget {
  const ArtistLinkButton({required this.url, super.key});

  final String url;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String label = artistLinkLabel(url);
    final String? mark = artistLinkMarks[label];
    final double size = context.fontL;

    return IconButton(
      tooltip: label,
      onPressed: () => unawaited(AppLinks.open(Uri.parse(url))),
      padding: EdgeInsets.all(context.spaceS),
      icon: mark == null
          ? AppIcon(AppGlyph.globe, size: size, color: cs.onSurface)
          : CustomPaint(
              size: Size.square(size),
              painter: _MarkPainter(mark, cs.onSurface),
            ),
    );
  }
}

/// Paints an SVG path drawn on a 24-unit grid, scaled to the box.
class _MarkPainter extends CustomPainter {
  _MarkPainter(this.data, this.color);

  final String data;
  final Color color;

  static final Map<String, Path> _parsed = <String, Path>{};

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = _parsed.putIfAbsent(data, () {
      final _PathBuilder builder = _PathBuilder();
      writeSvgPathDataToPath(data, builder);

      return builder.path;
    });
    canvas
      ..save()
      ..scale(size.width / 24, size.height / 24)
      ..drawPath(path, Paint()..color = color)
      ..restore();
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.data != data || old.color != color;
}

class _PathBuilder extends PathProxy {
  final Path path = Path();

  @override
  void close() => path.close();

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) => path.cubicTo(x1, y1, x2, y2, x3, y3);

  @override
  void lineTo(double x, double y) => path.lineTo(x, y);

  @override
  void moveTo(double x, double y) => path.moveTo(x, y);
}
