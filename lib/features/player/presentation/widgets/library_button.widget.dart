import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import 'library_sheet.widget.dart';

/// The library, top right of the scene, opposite the menu: one place for
/// the music, the queue alone beside the controls.
class LibraryButton extends StatelessWidget {
  const LibraryButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Library',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(showLibrarySheet(context)),
        child: Padding(
          padding: EdgeInsets.all(context.spaceM),
          child: AppIcon(AppGlyph.library, size: context.screenWidth * 0.07),
        ),
      ),
    );
  }
}
