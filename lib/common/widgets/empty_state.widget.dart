import 'package:flutter/material.dart';

import '../utils/responsive.dart';

/// Shown when a request succeeded but there is nothing to show.
///
/// Deliberately quiet — one line, no illustration, no call to action. This is
/// a screen people stare at, not a dashboard (see `docs/09`).
class EmptyState extends StatelessWidget {
  const EmptyState({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return ColoredBox(
      color: cs.surface,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: context.fontM,
            ),
          ),
        ),
      ),
    );
  }
}
