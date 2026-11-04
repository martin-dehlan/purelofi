import 'package:flutter/material.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';

/// "Get Pro" filled in the accent, or the plan, quiet, once it is theirs.
class ProPill extends StatelessWidget {
  const ProPill({
    required this.label,
    required this.filled,
    this.onTap,
    super.key,
  });

  final String label;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Material(
      color: filled ? cs.primary : cs.surfaceContainerHighest,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.spaceM,
            vertical: context.spaceXs * 1.5,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AppIcon(
                filled ? AppGlyph.lock : AppGlyph.check,
                size: context.fontS,
                color: filled ? cs.onPrimary : cs.primary,
              ),
              SizedBox(width: context.spaceXs * 1.5),
              Text(
                label,
                style: TextStyle(
                  color: filled ? cs.onPrimary : cs.onSurface,
                  fontSize: context.fontS,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
