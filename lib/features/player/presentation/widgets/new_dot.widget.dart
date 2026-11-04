import 'package:flutter/material.dart';

import '../../../../common/utils/responsive.dart';

/// The quiet mark on something added since the listener last looked
/// (#148): a dot in the accent, no word, no number.
class NewDot extends StatelessWidget {
  const NewDot({super.key});

  @override
  Widget build(BuildContext context) {
    final double size = context.spaceS;

    return Semantics(
      label: 'New',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
