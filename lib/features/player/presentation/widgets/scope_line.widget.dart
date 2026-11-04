import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../controller/collections.controller.dart';
import '../../controller/player.controller.dart';
import '../../domain/playback_scope.dart';
import '../../../../l10n/l10n.dart';

/// While a mood or playlist plays (#141), one quiet line on the player that
/// says which, with the way back to everything. Nothing otherwise.
class ScopeLine extends ConsumerWidget {
  const ScopeLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlaybackScope? scope = ref.watch(playbackScopeControllerProvider);
    if (scope == null) return const SizedBox.shrink();

    final ColorScheme cs = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: context.l10n.playingScope(scope.title),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            unawaited(ref.read(playerControllerProvider.notifier).leaveScope()),
        child: Padding(
          padding: EdgeInsets.only(top: context.spaceS),
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: '${scope.title}  ·  ',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                TextSpan(
                  text: context.l10n.playEverything,
                  style: TextStyle(color: cs.primary),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: context.fontS),
          ),
        ),
      ),
    );
  }
}
