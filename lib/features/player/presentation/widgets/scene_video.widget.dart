import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../common/widgets/loading_state.widget.dart';
import '../../domain/scene.entity.dart';

/// Streams one scene's looping video.
///
/// Silent by design: the scene is wallpaper, the music comes from the audio
/// player. The video fills the screen with `BoxFit.cover`, which is the one
/// place sizing is not derived from `MediaQuery` (see `docs/03`).
class SceneVideoView extends StatefulWidget {
  const SceneVideoView({required this.scene, super.key});

  final SceneEntity scene;

  @override
  State<SceneVideoView> createState() => _SceneVideoViewState();
}

class _SceneVideoViewState extends State<SceneVideoView> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    unawaited(_load(widget.scene));
  }

  @override
  void didUpdateWidget(SceneVideoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scene.videoUrl != widget.scene.videoUrl) {
      unawaited(_load(widget.scene));
    }
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    _controller = null;
    super.dispose();
  }

  Future<void> _load(SceneEntity scene) async {
    final VideoPlayerController? previous = _controller;
    final VideoPlayerController next = VideoPlayerController.networkUrl(
      Uri.parse(scene.videoUrl),
    );

    await next.initialize();
    await next.setLooping(true);
    await next.setVolume(0);

    if (!mounted) {
      await next.dispose();
      return;
    }

    setState(() => _controller = next);
    unawaited(previous?.dispose());
    await next.play();
  }

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const LoadingState();
    }

    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}
