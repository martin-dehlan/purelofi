import 'package:flutter/material.dart';

/// A placeholder in the shape of what is on its way: a quiet block that
/// breathes between two surface tones until the real thing replaces it.
///
/// Under reduced motion it holds still. Its shape is the caller's: give it
/// the same size and corners as the picture or line it stands in for, so
/// nothing jumps when the content lands.
class Skeleton extends StatefulWidget {
  const Skeleton({
    required this.width,
    required this.height,
    this.borderRadius = BorderRadius.zero,
    super.key,
  });

  final double width;
  final double height;
  final BorderRadius borderRadius;

  /// One breath, in and out.
  static const Duration period = Duration(milliseconds: 1400);

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: Skeleton.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _breath.stop();
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _breath,
          builder: (BuildContext context, Widget? _) => ColoredBox(
            color: Color.lerp(
              cs.surfaceContainerHigh,
              cs.surfaceContainerHighest,
              Curves.easeInOut.transform(_breath.value),
            )!,
          ),
        ),
      ),
    );
  }
}
