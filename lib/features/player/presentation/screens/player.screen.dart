import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/scene_background.widget.dart';

/// The whole app: a looping scene with the player chrome floating over it.
///
/// The chrome (play/pause, scene switcher, BTS) lands in later issues — for
/// now the screen is the scene.
class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: const Stack(
        fit: StackFit.expand,
        children: <Widget>[SceneBackground()],
      ),
    );
  }
}
