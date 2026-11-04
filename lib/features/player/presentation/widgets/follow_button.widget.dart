import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../controller/follows.controller.dart';
import '../../../../l10n/l10n.dart';

/// Follow or unfollow an artist (#147). Following is quiet: their new
/// tracks get the "new" mark like any other, and once push arrives (#97),
/// a note when they release one.
class FollowButton extends ConsumerWidget {
  const FollowButton({required this.artistId, super.key});

  final String artistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool following =
        ref.watch(followsControllerProvider).value?.contains(artistId) ?? false;

    return Center(
      child: OutlinedButton(
        onPressed: () => unawaited(
          ref.read(followsControllerProvider.notifier).toggle(artistId),
        ),
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          foregroundColor: following ? cs.onSurfaceVariant : cs.onSurface,
          side: BorderSide(color: following ? cs.outlineVariant : cs.onSurface),
        ),
        child: Text(
          following ? context.l10n.following : context.l10n.follow,
          style: TextStyle(
            fontSize: context.fontS,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
