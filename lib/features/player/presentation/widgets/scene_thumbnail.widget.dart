import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/widgets/skeleton.widget.dart';
import '../../controller/player.provider.dart';
import '../../domain/scene.entity.dart';

/// A scene's cover, from the disk when it is there.
///
/// The covers are fetched as soon as the scene list is (see
/// `SceneListController`), so by the time the room page opens they are usually
/// on the device and draw with the titles. Until one is, its skeleton holds
/// the place, and the picture fades in over it rather than popping.
class SceneThumbnail extends ConsumerWidget {
  const SceneThumbnail({required this.scene, required this.size, super.key});

  final SceneEntity scene;

  /// Width and height: a cover is square.
  final double size;

  /// The corners of a cover [size] wide.
  static BorderRadius radiusFor(double size) =>
      BorderRadius.circular(size * 0.08);

  /// How long a picture takes to come up over its skeleton.
  static const Duration fadeIn = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String? url = scene.thumbnailUrl;
    final BorderRadius radius = radiusFor(size);
    final Widget blank = ColoredBox(color: cs.surfaceContainerHighest);
    final Widget skeleton = Skeleton(
      width: size,
      height: size,
      borderRadius: radius,
    );

    // Decoded at the size it is drawn, not as the 960 px square it is: a
    // fraction of the work, so it is ready in the same frame as the title.
    final int decodeWidth = (size * MediaQuery.devicePixelRatioOf(context))
        .round();

    Widget picture(ImageProvider<Object> image) => Image(
      image: ResizeImage(image, width: decodeWidth),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.none,
      frameBuilder:
          (
            BuildContext context,
            Widget child,
            int? frame,
            bool wasSynchronouslyLoaded,
          ) {
            if (wasSynchronouslyLoaded) return child;

            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                skeleton,
                AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: fadeIn,
                  curve: Curves.easeOut,
                  child: child,
                ),
              ],
            );
          },
      errorBuilder: (_, _, _) => blank,
    );

    final Widget content;
    if (url == null) {
      content = blank;
    } else {
      content = ref
          .watch(sceneCoverProvider(url))
          .when(
            data: (File? file) => file == null
                // No cache, or the download failed: the network may still
                // have it.
                ? picture(NetworkImage(url))
                : picture(FileImage(file)),
            loading: () => skeleton,
            error: (_, _) => picture(NetworkImage(url)),
          );
    }

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox.square(dimension: size, child: content),
    );
  }
}
