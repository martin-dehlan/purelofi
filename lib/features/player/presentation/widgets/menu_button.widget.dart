import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../../auth/controller/auth.controller.dart';
import '../../../auth/domain/account.entity.dart';
import '../../../auth/presentation/widgets/profile_avatar.widget.dart';
import 'menu_sheet.widget.dart';

/// The menu, top left of the scene, shown as the listener the way music
/// apps put the profile there: their initial when signed in, a person in a
/// circle when not. The library sits opposite it.
class MenuButton extends ConsumerWidget {
  const MenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Account? account = ref.watch(authControllerProvider).value;
    final double size = context.screenWidth * 0.09;

    return Semantics(
      button: true,
      label: 'Menu',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(showMenuSheet(context)),
        child: Padding(
          padding: EdgeInsets.all(context.spaceM),
          child: account != null
              ? ProfileAvatar(account: account, size: size)
              : Container(
                  width: size,
                  height: size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: AppIcon(
                    AppGlyph.account,
                    size: size * 0.5,
                    color: cs.onSurfaceVariant,
                  ),
                ),
        ),
      ),
    );
  }
}
