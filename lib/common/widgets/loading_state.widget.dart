import 'package:flutter/material.dart';

/// Shown while content loads. Deliberately quiet — the scene is the hero.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return ColoredBox(
      color: cs.surface,
      child: Center(
        child: CircularProgressIndicator(color: cs.onSurfaceVariant),
      ),
    );
  }
}
