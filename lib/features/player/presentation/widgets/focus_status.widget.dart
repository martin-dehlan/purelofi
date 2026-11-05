import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../controller/focus_timer.controller.dart';
import '../../domain/focus_session.dart';
import 'focus_timer_card.widget.dart';

/// One quiet line on the player while the focus timer runs (#137): which
/// half it is in and until when. Nothing at all while it is off.
class FocusStatus extends ConsumerWidget {
  const FocusStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FocusSession? session = ref.watch(focusTimerControllerProvider);
    if (session == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: context.spaceS),
      child: Text(
        FocusTimerCard.status(context, session),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: context.fontS,
        ),
      ),
    );
  }
}
