import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/errors/app_error.dart';
import '../../../../common/utils/app_fonts.dart';
import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../controller/playback_mode.controller.dart';
import '../../controller/playback_source.controller.dart';
import '../../controller/player.controller.dart';
import '../../controller/track.controller.dart';
import '../../domain/playback_mode.dart';
import '../../domain/player.state.dart';
import '../../domain/track.entity.dart';
import 'favorite_button.widget.dart';
import 'queue_sheet.widget.dart';
import 'scope_line.widget.dart';
import 'track_actions_sheet.widget.dart';
import 'waveform.widget.dart';
import '../../../../l10n/l10n.dart';

/// The bar along the bottom: the track, its waveform, and the transport —
/// the play order on its left, the way into the music on its right.
///
/// The waveform is both the progress indicator and the scrubber, so there is
/// no separate slider competing with it.
class PlayerControls extends ConsumerWidget {
  const PlayerControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    // Watched narrowly: the position ticks several times a second, and
    // rebuilding the whole bar for it was showing up as stutter.
    final bool isPlaying = ref.watch(
      playerControllerProvider.select((PlayerState s) => s.isPlaying),
    );
    final TrackEntity? track = ref.watch(
      playerControllerProvider.select((PlayerState s) => s.currentTrack),
    );
    final AppError? error = ref.watch(
      playerControllerProvider.select((PlayerState s) => s.error),
    );
    final AsyncValue<List<TrackEntity>> tracks = ref.watch(
      trackListControllerProvider,
    );
    final PlaybackMode mode =
        ref.watch(playbackModeControllerProvider).value ?? PlaybackMode.shuffle;

    // A transport that cannot play anything is worse than none: it looks
    // broken. Say what is actually going on instead.
    final bool hasNoTracks = tracks.hasValue && tracks.value!.isEmpty;
    if (hasNoTracks) {
      return Padding(
        padding: EdgeInsets.all(context.spaceL),
        child: Text(
          context.l10n.noTracksYet,
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: context.fontM),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.horizontalPadding,
        context.spaceM,
        context.horizontalPadding,
        context.spaceXl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Progress(track: track),
          const _BackToPureLofi(),
          const ScopeLine(),
          if (error != null) ...<Widget>[
            SizedBox(height: context.spaceS),
            Text(
              error.userMessageIn(context.l10n),
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.error, fontSize: context.fontS),
            ),
          ],
          SizedBox(height: context.spaceM),
          // Settings at the ends, kept apart from the buttons that move the
          // stream: how it goes on, and where its music lives.
          Row(
            children: <Widget>[
              // The two ends take the same room, so the transport stays in
              // the middle: how it goes on at one end, what comes next at
              // the other. The library is up top, opposite the menu.
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _ModeButton(
                    mode: mode,
                    onTap: ref
                        .read(playbackModeControllerProvider.notifier)
                        .cycle,
                  ),
                ),
              ),
              _TransportButton(
                glyph: AppGlyph.previous,
                label: context.l10n.previousTrack,
                size: context.screenWidth * 0.07,
                onTap: ref.read(playerControllerProvider.notifier).previous,
              ),
              SizedBox(width: context.spaceM),
              _TransportButton(
                glyph: isPlaying ? AppGlyph.pause : AppGlyph.play,
                label: isPlaying ? context.l10n.pause : context.l10n.play,
                size: context.screenWidth * 0.13,
                onTap: ref
                    .read(playerControllerProvider.notifier)
                    .togglePlayPause,
              ),
              SizedBox(width: context.spaceM),
              _TransportButton(
                glyph: AppGlyph.next,
                label: context.l10n.nextTrack,
                size: context.screenWidth * 0.07,
                onTap: ref.read(playerControllerProvider.notifier).playNext,
              ),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: _SheetButton(
                    glyph: AppGlyph.queue,
                    label: context.l10n.queue,
                    onTap: () => showQueueSheet(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// m:ss — hours would be dishonest for a three-minute track.
  static String _clock(Duration position) {
    final int minutes = position.inMinutes;
    final int seconds = position.inSeconds % 60;

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// The clock and the waveform: the only parts that follow the position, so
/// the only parts that rebuild while a track runs.
class _Progress extends ConsumerWidget {
  const _Progress({required this.track});

  final TrackEntity? track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Duration position = ref.watch(
      playerControllerProvider.select((PlayerState s) => s.position),
    );
    final Duration? duration = ref.watch(
      playerControllerProvider.select((PlayerState s) => s.duration),
    );

    final double progress = duration == null || duration <= Duration.zero
        ? 0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            // Clock and title read at the same size: two things on one line
            // at two sizes looked like two unrelated things. The clock is only
            // dimmer, and set in the mono face so it does not jitter as the
            // digits change.
            Text(
              PlayerControls._clock(position),
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontFamily: AppFonts.mono,
                fontSize: context.fontM,
              ),
            ),
            SizedBox(width: context.spaceM),
            Expanded(
              child: Text(
                track?.title ?? '',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: cs.onSurface, fontSize: context.fontM),
              ),
            ),
            // Beside the title, as in every player. Favourites are marks on
            // PureLofi's tracks, so the listener's own carry none.
            if (track != null && track!.source == TrackSource.catalogue)
              FavoriteButton(trackId: track!.id, size: context.fontM),
            // The rest of what can be done with it — sharing it among them —
            // one tap further, as the rows in the library have it.
            if (track != null)
              Semantics(
                button: true,
                label: context.l10n.moreFor(track!.title),
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      unawaited(showTrackActionsSheet(context, track!)),
                  child: ConstrainedBox(
                    constraints: BoxConstraints.tightFor(
                      width: context.screenWidth * 0.11,
                      height: context.screenWidth * 0.11,
                    ),
                    child: Center(
                      child: AppIcon(
                        AppGlyph.more,
                        size: context.fontL,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: context.spaceS),
        Waveform(
          seed: track?.id ?? 'purelofi',
          progress: progress,
          // Read out as a slider: where it is, of how long (#153).
          semanticValueAt: duration == null
              ? null
              : (double fraction) =>
                    '${PlayerControls._clock(duration * fraction)} of '
                    '${PlayerControls._clock(duration)}',
          height: context.screenHeight * 0.06,
          onSeek: (double fraction) {
            if (duration == null) return;

            unawaited(
              ref
                  .read(playerControllerProvider.notifier)
                  .seek(duration * fraction),
            );
          },
        ),
      ],
    );
  }
}

class _TransportButton extends StatelessWidget {
  const _TransportButton({
    required this.glyph,
    required this.label,
    required this.size,
    required this.onTap,
  });

  final AppGlyph glyph;
  final String label;
  final double size;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(onTap()),
        // Never smaller than a finger, however small the icon (#153).
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: kMinInteractiveDimension,
            minHeight: kMinInteractiveDimension,
          ),
          child: Padding(
            padding: EdgeInsets.all(context.spaceS),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: AppIcon(glyph, size: size),
            ),
          ),
        ),
      ),
    );
  }
}

/// The play order, as one button that steps on through its three states:
/// shuffle, repeat track, in order. The first two are tinted and carry a dot
/// under them, as a setting that is on; in order is the plain one. The dot's
/// room is kept throughout, so stepping does not nudge the icon.
class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.mode, required this.onTap});

  final PlaybackMode mode;
  final Future<void> Function() onTap;

  static (AppGlyph, String) _looks(BuildContext context, PlaybackMode mode) =>
      switch (mode) {
        PlaybackMode.shuffle => (AppGlyph.shuffle, context.l10n.shuffle),
        PlaybackMode.repeatOne => (
          AppGlyph.repeatOne,
          context.l10n.repeatTrack,
        ),
        PlaybackMode.inOrder => (AppGlyph.inOrder, context.l10n.inOrder),
      };

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final double size = context.screenWidth * 0.055;
    final double dot = size * 0.18;
    final bool marked = mode != PlaybackMode.inOrder;
    final (AppGlyph glyph, String name) = _looks(context, mode);

    return Semantics(
      button: true,
      label: context.l10n.playOrder,
      value: name,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(onTap()),
        child: Padding(
          padding: EdgeInsets.all(context.spaceS),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(height: dot * 2),
              AppIcon(
                glyph,
                size: size,
                color: marked ? cs.primary : cs.onSurfaceVariant,
              ),
              SizedBox(height: dot),
              SizedBox.square(
                dimension: dot,
                child: marked
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The way into the music — library and what plays next, in one sheet. As
/// quiet as the play order opposite it, and the same size.
class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.glyph,
    required this.label,
    required this.onTap,
  });

  final AppGlyph glyph;
  final String label;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(onTap()),
        child: Padding(
          padding: EdgeInsets.all(context.spaceS),
          child: AppIcon(
            glyph,
            size: context.screenWidth * 0.055,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// While the listener's own music plays, a quiet way back to PureLofi's
/// (#66). Nothing at all while the recordings play, so the chrome is
/// unchanged for everyone who never opens their library.
class _BackToPureLofi extends ConsumerWidget {
  const _BackToPureLofi();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TrackSource source = ref.watch(playbackSourceControllerProvider);
    if (source != TrackSource.local) return const SizedBox.shrink();

    final ColorScheme cs = Theme.of(context).colorScheme;

    // One label, not the label and the line read out after it.
    return Semantics(
      button: true,
      label: context.l10n.backToPurelofi,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(
          ref
              .read(playerControllerProvider.notifier)
              .useSource(TrackSource.catalogue),
        ),
        child: Padding(
          padding: EdgeInsets.only(top: context.spaceS),
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: context.l10n.yourMusicPrefix,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                TextSpan(
                  text: context.l10n.backToPurelofi,
                  style: TextStyle(color: cs.primary),
                ),
              ],
            ),
            style: TextStyle(fontSize: context.fontS),
          ),
        ),
      ),
    );
  }
}
