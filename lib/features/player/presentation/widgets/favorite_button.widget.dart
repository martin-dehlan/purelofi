import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/app_assets.dart';
import '../../../../common/widgets/pixel_icon.widget.dart';
import '../../controller/favorites.controller.dart';

/// The heart beside the track title.
///
/// Beside the title rather than in the transport on purpose: the row of
/// controls stays at three, which is what keeps the chrome out of the way of
/// the scene (`docs/09`).
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
          padding: EdgeInsets.all(size * 0.3),
          child: PixelIcon(
            asset: isFavorite
                ? AppAssets.favoriteOnIcon
                : AppAssets.favoriteIcon,
            size: size,
          ),
        ),
      ),
    );
  }
}
