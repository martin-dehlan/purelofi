import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';

import '../../../auth/controller/welcome.controller.dart';
import '../../../auth/presentation/widgets/account_sheet.widget.dart';
import '../../controller/controls_visibility.controller.dart';
import '../../controller/scene.controller.dart';
import '../../controller/scene_touch.controller.dart';
import '../../controller/startup.controller.dart';
import '../../controller/window_mode.controller.dart';
import '../../controller/player.controller.dart';
import '../../controller/player.provider.dart';
import '../../controller/track.controller.dart';
import '../../domain/track.entity.dart';
import '../widgets/bts_modal.widget.dart';
import '../widgets/player_controls.widget.dart';
import '../widgets/library_button.widget.dart';
import '../widgets/menu_button.widget.dart';
import '../widgets/scene_background.widget.dart';
import '../../../../l10n/l10n.dart';

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

  /// In window mode a tap shows only the way out, for a few seconds (#149).
  bool _windowExitShown = false;
  Timer? _windowExitTimer;

  @override
  void dispose() {
    _windowExitTimer?.cancel();
    super.dispose();
  }

  void _showWindowExit() {
    _windowExitTimer?.cancel();
    setState(() => _windowExitShown = true);
    _windowExitTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _windowExitShown = false);
    });
  }

  /// Whether the first launch's welcome is still to come. Unknown until the
  /// stored flag is read; the music waits for the answer, and while the
  /// welcome is due or up it waits for that too, so a first launch is not
  /// sound and a sheet at once.
  bool? _welcomeDue;
  bool _welcomeShown = false;

  @override
  void initState() {
    super.initState();
    // A deep link has somewhere to be; the welcome is not offered then.
    if (widget.deepLinkTrackId != null) {
      _welcomeDue = false;
      return;
    }
    unawaited(
      ref.read(welcomeControllerProvider.notifier).claim().then((bool due) {
        if (mounted) setState(() => _welcomeDue = due);
      }),
    );
  }

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

  /// Offers the sign-in over the room; however it closes, the music starts.
  Future<void> _welcome() async {
    await showWelcomeSheet(context);
    if (mounted) setState(() => _welcomeDue = false);
  }

  @override
  Widget build(BuildContext context) {
    // The stream starts itself once the tracks are known and no welcome is
    // waiting; after that the player advances on its own as each track ends.
    final List<TrackEntity>? tracks = ref
        .watch(trackListControllerProvider)
        .value;
    if (!_started &&
        _welcomeDue == false &&
        tracks != null &&
        tracks.isNotEmpty) {
      _started = true;
      unawaited(
        Future<void>.microtask(
          ref.read(playerControllerProvider.notifier).playNext,
        ),
      );
    }

    _handleDeepLink();

    final ColorScheme cs = Theme.of(context).colorScheme;
    // The start screen stands alone: a transport over a loading bar looks
    // ready and is not. Only a drawn room waits on sprites; a video or an
    // error has nothing further to wait for once the list is in.
    final bool starting =
        !ref.watch(startupControllerProvider) &&
        (ref.watch(sceneListControllerProvider).isLoading ||
            (ref.watch(activeSceneControllerProvider)?.isLayered ?? false));
    // The transport's countdown ran while the start screen was up; give it
    // a fresh one, so the room arrives with its controls on.
    ref.listen<bool>(startupControllerProvider, (bool? was, bool done) {
      if (done && was != true) {
        ref.read(controlsVisibilityControllerProvider.notifier).reveal();
      }
    });
    // The welcome waits for the room, so it opens over the scene it
    // introduces and not over the start screen.
    if (!starting && _welcomeDue == true && !_welcomeShown) {
      _welcomeShown = true;
      unawaited(Future<void>.microtask(_welcome));
    }
    final bool windowMode = ref.watch(windowModeControllerProvider);
    final bool controlsVisible =
        !starting &&
        !windowMode &&
        ref.watch(controlsVisibilityControllerProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      // The room stays put when the keyboard comes up for a search in a
      // sheet; only the sheet makes room for it.
      resizeToAvoidBottomInset: false,
      // The whole room is the tap that brings the controls back, so it
      // needs a name for screen readers too (#153).
      body: Semantics(
        label: context.l10n.showTheControls,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (starting) return;
            // A tap that woke the cat is not a request for the transport.
            if (ref.read(sceneTouchControllerProvider.notifier).take()) return;
            // In window mode the room stays alone; a tap offers the way out.
            if (ref.read(windowModeControllerProvider)) {
              _showWindowExit();
              return;
            }

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
                  // The menu top left, the library top right, as music apps
                  // hold them; the queue stays with the controls.
                  child: const SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[MenuButton(), LibraryButton()],
                      ),
                    ),
                  ),
                ),
              ),
              // The only thing window mode shows, and only after a tap.
              if (windowMode && _windowExitShown)
                SafeArea(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.all(context.spaceL),
                      child: FilledButton.tonal(
                        onPressed: () {
                          _windowExitTimer?.cancel();
                          setState(() => _windowExitShown = false);
                          ref
                              .read(windowModeControllerProvider.notifier)
                              .leave();
                        },
                        child: Text(context.l10n.leaveWindowMode),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
