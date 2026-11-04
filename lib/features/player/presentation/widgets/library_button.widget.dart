import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../controller/new_content.controller.dart';
import 'library_sheet.widget.dart';
import 'new_dot.widget.dart';
import '../../../../l10n/l10n.dart';

/// The library, top right of the scene, opposite the menu: one place for
/// the music, the queue alone beside the controls. A dot on it when tracks
/// were added since the listener last looked (#148).
class LibraryButton extends ConsumerWidget {
  const LibraryButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool hasNew = ref.watch(newTracksProvider).isNotEmpty;

    return Semantics(
      button: true,
      label: hasNew ? context.l10n.libraryNewTracks : context.l10n.library,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(showLibrarySheet(context)),
        child: Padding(
          padding: EdgeInsets.all(context.spaceM),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              AppIcon(AppGlyph.library, size: context.screenWidth * 0.07),
              if (hasNew) const Positioned(right: 0, top: 0, child: NewDot()),
            ],
          ),
        ),
      ),
    );
  }
}
