import 'package:flutter/material.dart';

import '../utils/responsive.dart';
import 'app_icon.widget.dart';

/// One line of a [MenuGroup]: a glyph, what it does, and what it is set to.
///
/// [onTap] `null` greys it out; [danger] sets it in the error colour, for a
/// row that reports or removes something. Built on Material's list tile, so it reads
/// and behaves the way a phone's menus do.
class MenuRow extends StatelessWidget {
  const MenuRow({
    required this.glyph,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.danger = false,
    super.key,
  });

  final AppGlyph glyph;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool enabled = onTap != null;
    final Color tint = danger ? cs.error : cs.onSurfaceVariant;

    return ListTile(
      enabled: enabled,
      contentPadding: EdgeInsets.symmetric(horizontal: context.spaceM),
      leading: AppIcon(
        glyph,
        size: context.fontL,
        color: enabled ? tint : tint.withValues(alpha: 0.38),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: context.fontM,
          color: danger ? cs.error : null,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: TextStyle(fontSize: context.fontS)),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
