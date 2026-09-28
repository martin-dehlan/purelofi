import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import 'settings_sheet.widget.dart';

/// The one button that is not about playback, top right of the scene.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Menu',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(showSettingsSheet(context)),
        child: Padding(
          padding: EdgeInsets.all(context.spaceM),
          child: AppIcon(AppGlyph.menu, size: context.screenWidth * 0.07),
        ),
      ),
    );
  }
}
