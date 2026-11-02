import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import 'menu_sheet.widget.dart';

/// The menu, top left of the scene, as a gear: the account, the settings
/// and the rest of the app live behind it. The library sits opposite it,
/// the same size, so the two read as a pair.
class MenuButton extends StatelessWidget {
  const MenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Menu',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(showMenuSheet(context)),
        child: Padding(
          padding: EdgeInsets.all(context.spaceM),
          child: AppIcon(AppGlyph.settings, size: context.screenWidth * 0.07),
        ),
      ),
    );
  }
}
