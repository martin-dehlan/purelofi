import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/skeleton.widget.dart';
import '../../../player/controller/player.provider.dart';
import '../../../player/domain/scene.entity.dart';

/// The rooms Pro opens, as a row of their covers — what is being bought,
/// shown rather than described. The covers are already on the disk
/// (`sceneCoverProvider`), so the row draws at once.
class LockedRoomsStrip extends StatelessWidget {
  const LockedRoomsStrip({required this.scenes, super.key});

  final List<SceneEntity> scenes;

  /// Enough to show there are more rooms, few enough to stay one row.
  static const int shown = 4;

  @override
  Widget build(BuildContext context) {
    final double size =
        (context.screenWidth - context.horizontalPadding * 2) / shown -
        context.spaceS;

    return Row(
      children: <Widget>[
        for (final SceneEntity scene in scenes.take(shown))
          Padding(
            padding: EdgeInsetsDirectional.only(end: context.spaceS),
            child: _Cover(scene: scene, size: size),
          ),
      ],
    );
  }
}

class _Cover extends ConsumerWidget {
  const _Cover({required this.scene, required this.size});

  final SceneEntity scene;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final BorderRadius radius = BorderRadius.circular(context.cardBorderRadius);
    final String? url = scene.thumbnailUrl;
    final File? file = url == null
        ? null
        : ref.watch(sceneCoverProvider(url)).value;
    final int decodeWidth = (size * MediaQuery.devicePixelRatioOf(context))
        .round();

    return Semantics(
      label: scene.title,
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox.square(
          dimension: size,
          child: switch ((url, file)) {
            (null, _) => ColoredBox(color: cs.surfaceContainerHighest),
            (_, final File f) => Image(
              image: ResizeImage(FileImage(f), width: decodeWidth),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.none,
            ),
            (final String u, null) => Image(
              image: ResizeImage(NetworkImage(u), width: decodeWidth),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.none,
              frameBuilder: (_, Widget child, int? frame, bool sync) =>
                  frame == null && !sync
                  ? Skeleton(width: size, height: size, borderRadius: radius)
                  : child,
              errorBuilder: (_, _, _) =>
                  ColoredBox(color: cs.surfaceContainerHighest),
            ),
          },
        ),
      ),
    );
  }
}
