import 'package:flutter/material.dart';

import '../utils/responsive.dart';
import 'app_icon.widget.dart';

/// One line of a [MenuGroup]: a glyph, what it does, and what it is set to.
///
/// [onTap] `null` greys it out. Built on Material's list tile, so it reads
/// and behaves the way a phone's menus do.
class MenuRow extends StatelessWidget {
  const MenuRow({
    required this.glyph,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final AppGlyph glyph;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool enabled = onTap != null;

    return ListTile(
      enabled: enabled,
      contentPadding: EdgeInsets.symmetric(horizontal: context.spaceM),
      leading: AppIcon(
        glyph,
        size: context.fontL,
        color: enabled
            ? cs.onSurfaceVariant
            : cs.onSurfaceVariant.withValues(alpha: 0.38),
      ),
      title: Text(title, style: TextStyle(fontSize: context.fontM)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: TextStyle(fontSize: context.fontS)),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
