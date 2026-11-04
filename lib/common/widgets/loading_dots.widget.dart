import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';

/// Three dots lighting up one after the other: the app at work, where a
/// button or a line of text waits on it. Never a spinning circle; this
/// keeps to the size of the text it stands in for.
///
/// Under reduced motion the dots hold still at half strength.
class LoadingDots extends StatefulWidget {
  const LoadingDots({required this.size, required this.color, super.key});

  /// How tall the row is, about the height of the text it replaces.
  final double size;
  final Color color;

  @override
  State<LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _wave.stop();
    } else if (!_wave.isAnimating) {
      _wave.repeat();
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double dot = widget.size * 0.3;

    return Semantics(
      label: context.l10n.loading,
      child: SizedBox(
        height: widget.size,
        child: AnimatedBuilder(
          animation: _wave,
          builder: (BuildContext context, Widget? _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int i = 0; i < 3; i++)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: dot * 0.35),
                  child: Container(
                    width: dot,
                    height: dot,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color.withValues(alpha: _strength(i)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Each dot peaks a third of the way after the one before it.
  double _strength(int i) {
    if (!_wave.isAnimating) return 0.5;
    final double t = (_wave.value - i / 3) % 1;
    final double peak = t < 0.5 ? t * 2 : (1 - t) * 2;

    return 0.25 + 0.75 * Curves.easeInOut.transform(peak);
  }
}
