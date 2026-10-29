import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../controller/favorites.controller.dart';

/// The heart that marks a track as a favourite, beside the title of the one
/// playing. Marked tracks come up more often in shuffle and have their own
/// chip in the library.
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({required this.trackId, required this.size, super.key});

  final String trackId;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched narrowly: only this track's mark, so marking another one does
    // not rebuild the bar.
    final bool isFavorite = ref.watch(
      favoritesControllerProvider.select(
        (AsyncValue<Set<String>> favorites) =>
            favorites.hasValue && favorites.value!.contains(trackId),
      ),
    );

    final ColorScheme cs = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      toggled: isFavorite,
      label: isFavorite ? 'Remove from favorites' : 'Add to favorites',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(
          ref.read(favoritesControllerProvider.notifier).toggle(trackId),
        ),
        // The target is a thumb's width whatever the heart's size: a heart
        // the size of the text beside it is too small to hit.
        child: ConstrainedBox(
          constraints: BoxConstraints.tightFor(
            width: context.screenWidth * 0.11,
            height: context.screenWidth * 0.11,
          ),
          child: Center(
            child: AppIcon(
              isFavorite ? AppGlyph.heart : AppGlyph.heartOutline,
              // A glyph leaves room above and below its cap height; the icon
              // fills its box edge to edge, so the heart is drawn a little
              // larger than [size] to sit level with the text beside it.
              size: size * 1.1,
              // Marked is the accent, filled; unmarked a plain outline. At
              // this size the two must differ by more than the hole.
              color: isFavorite ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
