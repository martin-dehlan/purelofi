import 'package:flutter/material.dart';

import '../../../../common/utils/responsive.dart';
import 'music_sheet.dart';
import 'up_next.widget.dart';
import '../../../../l10n/l10n.dart';

/// What plays now and next, opened from the player the way every music app
/// keeps its queue beside the controls rather than inside the library.
class QueueSheet extends StatelessWidget {
  const QueueSheet({required this.controller, super.key});

  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: controller,
      slivers: <Widget>[
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            context.horizontalPadding,
            0,
            context.horizontalPadding,
            context.spaceS,
          ),
          sliver: SliverToBoxAdapter(
            child: Text(
              context.l10n.queue,
              style: TextStyle(
                fontSize: context.fontXl,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
          sliver: const UpNext(),
        ),
        SliverToBoxAdapter(child: SizedBox(height: context.spaceXl)),
      ],
    );
  }
}

/// Opens the queue.
Future<void> showQueueSheet(BuildContext context) => showMusicSheet(
  context,
  (BuildContext context, ScrollController controller) =>
      QueueSheet(controller: controller),
);
