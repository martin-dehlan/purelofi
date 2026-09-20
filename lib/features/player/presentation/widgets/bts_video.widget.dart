import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../common/widgets/loading_state.widget.dart';

/// Plays a behind-the-scenes clip with its sound: the point of the footage is
/// hearing the track actually being played.
class BtsVideoView extends StatefulWidget {
  const BtsVideoView({required this.videoUrl, super.key});

  final String videoUrl;

  @override
  State<BtsVideoView> createState() => _BtsVideoViewState();
}

class _BtsVideoViewState extends State<BtsVideoView> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    _controller = null;
    super.dispose();
  }

  Future<void> _load() async {
    final VideoPlayerController controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );
    await controller.initialize();

    if (!mounted) {
      await controller.dispose();
      return;
    }

    setState(() => _controller = controller);
    await controller.play();
  }

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const AspectRatio(aspectRatio: 16 / 9, child: LoadingState());
    }

    return AspectRatio(
      aspectRatio: controller.value.aspectRatio,
      child: VideoPlayer(controller),
    );
  }
}
