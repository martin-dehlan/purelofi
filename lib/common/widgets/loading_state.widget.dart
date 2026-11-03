import 'package:flutter/material.dart';

import 'skeleton.widget.dart';

/// Shown while content loads: the space it will take, breathing. Never a
/// spinner. Deliberately quiet — the scene is the hero.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) =>
          Skeleton(width: box.maxWidth, height: box.maxHeight),
    );
  }
}
