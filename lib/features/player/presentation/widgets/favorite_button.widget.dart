import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/widgets/app_icon.widget.dart';
import '../../controller/favorites.controller.dart';

/// The heart that marks a track as a favourite.
///
/// Not shown anywhere since #67: with a handful of tracks there is nothing to
/// choose between. Kept, with its sheet and repository, for when the
/// catalogue is big enough — it goes back beside the title, not into the
/// transport, so the row of controls stays at three (`docs/09`).
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

    return Semantics(
      button: true,
      toggled: isFavorite,
      label: isFavorite ? 'Remove from favorites' : 'Add to favorites',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(
          ref.read(favoritesControllerProvider.notifier).toggle(trackId),
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.4),
          child: AppIcon(
            isFavorite ? AppGlyph.heart : AppGlyph.heartOutline,
            // [size] is a font size. A glyph leaves room above and below its
            // cap height; the icon fills its box edge to edge, so matching
            // the numbers would make the heart look bigger than the text it
            // sits beside.
            size: size * 0.85,
          ),
        ),
      ),
    );
  }
}
