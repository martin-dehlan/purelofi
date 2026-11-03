import 'package:flutter/material.dart';

import '../utils/responsive.dart';

/// Rows that belong together, on one rounded card a shade off the sheet —
/// the way a phone's own settings group them. A flat fill, no border and no
/// shadow (`docs/09`).
class MenuGroup extends StatelessWidget {
  const MenuGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(context.cardBorderRadius * 1.5),
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}
