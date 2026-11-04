import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../../../common/widgets/menu_group.widget.dart';
import '../../../../common/widgets/menu_row.widget.dart';
import '../../controller/scene.controller.dart';
import '../../controller/stats.controller.dart';
import '../../domain/listening_stats.dart';
import '../../domain/scene.entity.dart';
import 'stats_sheet.widget.dart';
import '../../../../l10n/l10n.dart';

/// "Your week" on the room page (#151): one line, and the details a tap
/// away. Nothing until something was heard this week.
class WeekLine extends ConsumerWidget {
  const WeekLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ListeningStats stats =
        ref.watch(weekStatsProvider).value ?? ListeningStats.empty;
    if (stats.isEmpty) return const SizedBox.shrink();

    final String? room =
        (ref.watch(sceneListControllerProvider).value ?? const <SceneEntity>[])
            .where((SceneEntity s) => s.id == stats.topSceneId)
            .firstOrNull
            ?.title;

    return Padding(
      padding: EdgeInsets.only(top: context.spaceM),
      child: MenuGroup(
        children: <Widget>[
          MenuRow(
            glyph: AppGlyph.timer,
            title: context.l10n.timeThisWeek(listeningTimeLabel(stats.total)),
            subtitle: room == null ? null : context.l10n.mostlyIn(room),
            onTap: () => unawaited(showStatsSheet(context)),
          ),
        ],
      ),
    );
  }
}
