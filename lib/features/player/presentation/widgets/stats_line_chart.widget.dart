import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../common/utils/app_fonts.dart';
import '../../../../common/utils/responsive.dart';
import '../../domain/listening_stats.dart';
import '../../domain/period_stats.dart';

/// A stretch of listening as a line drawn on a coarse pixel grid: one flat
/// step per day (or month), the area under it dithered like an old screen,
/// the average as a dotted row. Touch or drag along it to read a day; the
/// reading sits above the line, where the finger does not cover it.
class StatsLineChart extends StatefulWidget {
  const StatsLineChart({required this.period, required this.slots, super.key});

  final StatsPeriod period;
  final List<Duration> slots;

  @override
  State<StatsLineChart> createState() => _StatsLineChartState();
}

class _StatsLineChartState extends State<StatsLineChart> {
  int? _picked;

  @override
  void didUpdateWidget(StatsLineChart old) {
    super.didUpdateWidget(old);
    if (old.period.start != widget.period.start ||
        old.period.span != widget.period.span) {
      _picked = null;
    }
  }

  void _pick(Offset at, double width) {
    final int n = widget.slots.length;
    final int slot = (at.dx / width * n).floor().clamp(0, _shown() - 1);
    if (slot < 0) return;
    if (slot == _picked) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _picked = slot);
  }

  /// What a slot is called: "Wed 4 Nov", "October".
  String _slotName(BuildContext context, int slot) {
    final String locale = Localizations.localeOf(context).toString();
    final DateTime start = widget.period.start;
    return widget.period.span == StatsSpan.year
        ? DateFormat.MMMM(locale).format(DateTime(start.year, slot + 1))
        : DateFormat.MMMEd(
            locale,
          ).format(DateTime(start.year, start.month, start.day + slot));
  }

  /// The marks along the bottom: day letters for a week, every seventh
  /// day for a month, month letters for a year.
  List<String> _marks(BuildContext context) {
    final String locale = Localizations.localeOf(context).toString();
    final int n = widget.slots.length;
    return switch (widget.period.span) {
      StatsSpan.week => () {
        final List<String> narrow = MaterialLocalizations.of(
          context,
        ).narrowWeekdays;
        return <String>[...narrow.skip(1), narrow.first];
      }(),
      StatsSpan.month => <String>[
        for (int d = 1; d <= n; d++) (d - 1) % 7 == 0 ? '$d' : '',
      ],
      StatsSpan.year => <String>[
        for (int m = 1; m <= 12; m++)
          DateFormat('MMMMM', locale).format(DateTime(2000, m)),
      ],
    };
  }

  /// The slots that have begun: the line stops at today.
  int _shown() {
    final DateTime now = DateTime.now();
    final StatsPeriod period = widget.period;
    if (!now.isBefore(period.end)) return widget.slots.length;
    if (now.isBefore(period.start)) return 0;
    return period.slotOf(now) + 1;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextStyle mono = TextStyle(
      fontFamily: AppFonts.mono,
      color: cs.onSurfaceVariant,
      fontSize: context.fontXs,
    );
    final List<String> marks = _marks(context);
    final int? picked = _picked;

    return Semantics(
      label: <String>[
        for (int i = 0; i < widget.slots.length; i++)
          if (widget.slots[i] > Duration.zero)
            '${_slotName(context, i)} ${listeningTimeLabel(widget.slots[i])}',
      ].join(', '),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // The reading, or a hint of how to get one.
          Text(
            picked == null
                ? ' '
                : '${_slotName(context, picked)}  ·  '
                      '${widget.slots[picked] == Duration.zero ? '–' : listeningTimeLabel(widget.slots[picked])}',
            style: mono.copyWith(color: cs.onSurface),
          ),
          SizedBox(height: context.spaceS),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints box) {
              final double width = box.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (TapDownDetails d) => _pick(d.localPosition, width),
                onHorizontalDragStart: (DragStartDetails d) =>
                    _pick(d.localPosition, width),
                onHorizontalDragUpdate: (DragUpdateDetails d) =>
                    _pick(d.localPosition, width),
                child: CustomPaint(
                  size: Size(width, context.screenWidth * 0.3),
                  painter: _PixelLinePainter(
                    slots: widget.slots,
                    shown: _shown(),
                    picked: picked,
                    pixel: context.screenWidth * 0.009,
                    line: cs.primary,
                    fill: cs.primary.withValues(alpha: 0.35),
                    faint: cs.outlineVariant,
                    highlight: cs.onSurface,
                  ),
                ),
              );
            },
          ),
          SizedBox(height: context.spaceS),
          Row(
            children: <Widget>[
              for (int i = 0; i < marks.length; i++)
                Expanded(
                  child: Text(
                    marks[i],
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    textAlign: widget.period.span == StatsSpan.month
                        ? TextAlign.start
                        : TextAlign.center,
                    style: mono.copyWith(
                      color: i == picked ? cs.onSurface : null,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Paints in square pixels only: the step line, the dithered fill under
/// it, the dotted average, and the picked slot brighter.
class _PixelLinePainter extends CustomPainter {
  _PixelLinePainter({
    required this.slots,
    required this.shown,
    required this.picked,
    required this.pixel,
    required this.line,
    required this.fill,
    required this.faint,
    required this.highlight,
  });

  final List<Duration> slots;

  /// How many slots, from the first, have begun; the rest stay empty.
  final int shown;
  final int? picked;
  final double pixel;
  final Color line;
  final Color fill;
  final Color faint;
  final Color highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final int cols = (size.width / pixel).floor();
    final int rows = (size.height / pixel).floor();
    if (cols == 0 || rows < 2) return;
    // Centre the grid in the space it was given.
    final double dx = (size.width - cols * pixel) / 2;
    final double dy = size.height - rows * pixel;
    final int n = slots.length;
    final int most = slots.fold<int>(
      0,
      (int m, Duration d) => math.max(m, d.inSeconds),
    );
    final int sum = slots.fold<int>(0, (int s, Duration d) => s + d.inSeconds);
    final int seen = shown.clamp(1, n);

    // Row 0 is the bottom; the line sits one row above it at nothing.
    int levelOf(int seconds) =>
        most == 0 ? 0 : (seconds / most * (rows - 2)).round();

    final Paint p = Paint()..isAntiAlias = false;
    void dot(int col, int row, Color color) {
      p.color = color;
      canvas.drawRect(
        Rect.fromLTWH(
          dx + col * pixel,
          dy + (rows - 1 - row) * pixel,
          pixel,
          pixel,
        ),
        p,
      );
    }

    int startCol(int slot) => (cols * slot / n).round();

    // The dotted average, under all else.
    if (sum > 0) {
      final int avg = levelOf(sum ~/ seen);
      for (int c = 0; c < startCol(seen); c += 3) {
        dot(c, avg, faint);
      }
    }

    int? lastLevel;
    for (int s = 0; s < math.min(shown, n); s++) {
      final int from = startCol(s);
      final int to = startCol(s + 1);
      final int level = levelOf(slots[s].inSeconds);
      final bool lit = s == picked;

      for (int c = from; c < to; c++) {
        // Dither: every other pixel, offset row by row.
        for (int r = 0; r < level; r++) {
          if ((c + r).isEven) dot(c, r, lit ? line : fill);
        }
        dot(c, level, lit ? highlight : line);
      }
      // The riser between this step and the one before.
      if (lastLevel != null && lastLevel != level) {
        final int lo = math.min(lastLevel, level);
        final int hi = math.max(lastLevel, level);
        for (int r = lo; r <= hi; r++) {
          dot(from, r, line);
        }
      }
      lastLevel = level;
    }
  }

  @override
  bool shouldRepaint(_PixelLinePainter old) =>
      old.slots != slots ||
      old.shown != shown ||
      old.picked != picked ||
      old.pixel != pixel ||
      old.line != line;
}
