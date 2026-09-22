import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controller/controls_visibility.controller.dart';
import '../../controller/scene_touch.controller.dart';
import '../../controller/player.controller.dart';
import '../../controller/player.provider.dart';
import '../../controller/track.controller.dart';
import '../../domain/track.entity.dart';
import '../widgets/bts_modal.widget.dart';
import '../widgets/player_controls.widget.dart';
import '../widgets/settings_button.widget.dart';
import '../widgets/scene_background.widget.dart';

/// The whole app: a looping scene with the player chrome floating over it.
///
/// The scene fills the screen and the controls float over it, kept legible by
/// a flat scrim — never a gradient (see `docs/09`).
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, this.deepLinkTrackId});

  /// Set when the app was opened through `purelofi://app/track/<id>`: that
  /// track's behind-the-scenes clip opens as soon as the track is known.
  final String? deepLinkTrackId;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  bool _started = false;
  bool _deepLinkHandled = false;

  /// Opens the BTS modal once, for the track the deep link named.
  void _handleDeepLink() {
    final String? trackId = widget.deepLinkTrackId;
    if (_deepLinkHandled || trackId == null) return;

    final TrackEntity? track = ref.watch(trackDetailProvider(trackId)).value;
    if (track == null) return;

    _deepLinkHandled = true;
    unawaited(
      Future<void>.microtask(() {
        if (mounted) return showBtsModal(context, ref, track);
        return null;
      }),
    );
  }

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

    _handleDeepLink();

    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool controlsVisible = ref.watch(
      controlsVisibilityControllerProvider,
    );

    return Scaffold(
      backgroundColor: cs.surface,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // A tap that woke the cat is not a request for the transport.
          if (ref.read(sceneTouchControllerProvider.notifier).take()) return;

          ref.read(controlsVisibilityControllerProvider.notifier).reveal();
        },
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const SceneBackground(),
            // Keeps text and icons readable over a bright video frame.
            AnimatedOpacity(
              opacity: controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: ColoredBox(color: cs.scrim.withValues(alpha: 0.3)),
            ),
            AnimatedOpacity(
              opacity: controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              // Hidden controls are not tappable: the first tap brings them
              // back, it does not pause the music by accident.
              child: IgnorePointer(
                ignoring: !controlsVisible,
                child: const Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(child: PlayerControls()),
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !controlsVisible,
                child: const Align(
                  alignment: Alignment.topRight,
                  child: SafeArea(child: SettingsButton()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
