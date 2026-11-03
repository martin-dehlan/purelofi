import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../../../common/widgets/menu_group.widget.dart';
import '../../../../common/widgets/menu_row.widget.dart';
import '../../controller/sleep_timer.controller.dart';

/// When the music should stop: a few lengths, the end of this track, or
/// not at all. Choosing closes the sheet.
class SleepTimerSheet extends ConsumerWidget {
  const SleepTimerSheet({super.key});

  static const List<int> minutes = <int>[15, 30, 45, 60];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SleepTimerController timer = ref.read(
      sleepTimerControllerProvider.notifier,
    );
    final bool running = ref.watch(sleepTimerControllerProvider) != null;

    VoidCallback choose(void Function() action) => () {
      action();
      Navigator.of(context).pop();
    };

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: context.spaceM),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.horizontalPadding,
                0,
                context.horizontalPadding,
                context.spaceM,
              ),
              child: Text(
                'Sleep timer',
                style: TextStyle(
                  fontSize: context.fontL,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            MenuGroup(
              children: <Widget>[
                for (final int length in minutes)
                  MenuRow(
                    glyph: AppGlyph.timer,
                    title: length == 60 ? '1 hour' : '$length minutes',
                    onTap: choose(() => timer.start(Duration(minutes: length))),
                  ),
                MenuRow(
                  glyph: AppGlyph.queue,
                  title: 'End of this track',
                  onTap: choose(timer.endOfTrack),
                ),
              ],
            ),
            if (running) ...<Widget>[
              SizedBox(height: context.spaceM),
              MenuGroup(
                children: <Widget>[
                  MenuRow(
                    glyph: AppGlyph.remove,
                    title: 'Turn off',
                    onTap: choose(timer.cancel),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Opens the sleep timer.
Future<void> showSleepTimerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext context) => const SleepTimerSheet(),
  );
}
