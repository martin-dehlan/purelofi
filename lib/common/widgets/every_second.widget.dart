import 'dart:async';

import 'package:flutter/widgets.dart';

/// Builds again once a second, for a countdown on screen. The timers behind
/// it hold a moment, not a count; this only redraws what is left of it, and
/// stops ticking when it leaves the screen.
class EverySecond extends StatefulWidget {
  const EverySecond({required this.builder, super.key});

  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<EverySecond> createState() => _EverySecondState();
}

class _EverySecondState extends State<EverySecond> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, DateTime.now());
}
