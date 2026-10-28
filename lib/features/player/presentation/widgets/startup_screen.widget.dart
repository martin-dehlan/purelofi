import 'package:flutter/material.dart';

import '../../../../common/utils/app_fonts.dart';
import '../../../../common/utils/responsive.dart';

/// What the listener sees while a room is on its way: the wordmark and a
/// bar of square blocks that fills as the room arrives.
///
/// Blocks, not a smooth bar, so it fills the way the scene is drawn — in
/// whole pixels. [progress] is `null` while there is nothing to count yet;
/// a single block then walks along the track, so the screen never looks
/// frozen.
class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key, this.progress});

  final double? progress;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final double? value = progress;

    return ColoredBox(
      color: cs.surface,
      child: Center(
        child: Semantics(
          label: 'Loading',
          value: value == null ? null : '${(value * 100).round()}%',
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'PureLofi',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontFamily: AppFonts.wordmark,
                    fontSize: context.fontXxl,
                  ),
                ),
                SizedBox(height: context.spaceL),
                _BlockBar(progress: value),
                SizedBox(height: context.spaceM),
                Text(
                  'tuning in',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontFamily: AppFonts.mono,
                    fontSize: context.fontS,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of square blocks: filled up to [progress], or one walking block
/// when [progress] is `null`.
class _BlockBar extends StatefulWidget {
  const _BlockBar({required this.progress});

  final double? progress;

  /// Few enough that one block is a step you can see.
  static const int blocks = 12;

  @override
  State<_BlockBar> createState() => _BlockBarState();
}

class _BlockBarState extends State<_BlockBar>
    with SingleTickerProviderStateMixin {
  // One pass of the walking block, there and back.
  late final AnimationController _walk = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_BlockBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  /// Only the walking block needs a clock; a counted bar sits still.
  void _sync() {
    if (widget.progress == null) {
      if (!_walk.isAnimating) _walk.repeat();
    } else {
      _walk.stop();
    }
  }

  @override
  void dispose() {
    _walk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final double block = context.pixel(context.screenWidth * 0.03);
    final double gap = context.pixel(block * 0.4);

    return AnimatedBuilder(
      animation: _walk,
      builder: (BuildContext context, Widget? _) {
        final double? progress = widget.progress;
        final int filled = progress == null
            ? 0
            : (progress.clamp(0, 1) * _BlockBar.blocks).floor();
        final int walker = progress == null ? _walkerAt(_walk.value) : -1;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < _BlockBar.blocks; i++)
              Padding(
                padding: EdgeInsetsDirectional.only(
                  end: i == _BlockBar.blocks - 1 ? 0 : gap,
                ),
                child: SizedBox.square(
                  dimension: block,
                  child: ColoredBox(
                    color: i < filled || i == walker
                        ? cs.primary
                        : cs.surfaceContainerHighest,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Which block the walker is on: out to the end and back, one whole
  /// block at a time.
  static int _walkerAt(double t) {
    const int last = _BlockBar.blocks - 1;
    final int step = (t * last * 2).floor() % (last * 2);

    return step <= last ? step : last * 2 - step;
  }
}
