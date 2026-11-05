import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../../../common/widgets/every_second.widget.dart';
import '../../../../l10n/l10n.dart';
import '../../controller/focus_timer.controller.dart';
import '../../domain/focus_session.dart';
import 'focus_timer_card.widget.dart';
import 'room_page.widget.dart';

/// The menu, top left of the scene, as a gear: the account, the settings
/// and the rest of the app live behind it. The library sits opposite it,
/// the same size, so the two read as a pair.
///
/// While the focus timer runs, what is left of the half counts down under
/// the gear, so a glance at the room tells it; the timer lives behind it.
class MenuButton extends ConsumerWidget {
  const MenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FocusSession? focus = ref.watch(focusTimerControllerProvider);
    final double size = context.screenWidth * 0.07;

    return Semantics(
      button: true,
      label: context.l10n.menu,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(showRoomPage(context)),
        child: Padding(
          padding: EdgeInsets.all(context.spaceM),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AppIcon(AppGlyph.settings, size: size),
              if (focus != null)
                Padding(
                  padding: EdgeInsets.only(top: context.spaceXs),
                  child: EverySecond(
                    builder: (BuildContext context, DateTime now) => Text(
                      FocusTimerCard.remaining(focus, now),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface
                            .withValues(
                              alpha: focus.phase == FocusPhase.focus ? 1 : 0.6,
                            ),
                        fontSize: context.fontXs,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
