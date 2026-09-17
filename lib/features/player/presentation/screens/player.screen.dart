import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controller/player.controller.dart';
import '../../controller/track.controller.dart';
import '../../domain/track.entity.dart';
import '../widgets/scene_background.widget.dart';

/// The whole app: a looping scene with the player chrome floating over it.
///
/// The chrome (play/pause, scene switcher, BTS) lands in later issues — for
/// now the screen is the scene, and the audio starts as soon as the tracks
/// are known.
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  bool _started = false;

  @override
  Widget build(BuildContext context) {
    // The stream starts itself once the tracks are known; after that the
    // player advances on its own as each track ends.
    final List<TrackEntity>? tracks = ref
        .watch(trackListControllerProvider)
        .value;
    if (!_started && tracks != null && tracks.isNotEmpty) {
      _started = true;
      unawaited(
        Future<void>.microtask(
          ref.read(playerControllerProvider.notifier).playNext,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: const Stack(
        fit: StackFit.expand,
        children: <Widget>[SceneBackground()],
      ),
    );
  }
}
