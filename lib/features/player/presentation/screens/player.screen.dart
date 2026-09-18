import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controller/player.controller.dart';
import '../../controller/track.controller.dart';
import '../../domain/track.entity.dart';
import '../widgets/player_controls.widget.dart';
import '../widgets/scene_background.widget.dart';

/// The whole app: a looping scene with the player chrome floating over it.
///
/// The scene fills the screen and the controls float over it, kept legible by
/// a flat scrim — never a gradient (see `docs/09`).
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

    final ColorScheme cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const SceneBackground(),
          // Keeps text and icons readable over a bright video frame.
          ColoredBox(color: cs.scrim.withValues(alpha: 0.3)),
          const Center(child: PlayerControls()),
        ],
      ),
    );
  }
}
