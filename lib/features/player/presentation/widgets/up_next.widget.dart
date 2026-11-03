import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../controller/playback_mode.controller.dart';
import '../../controller/player.controller.dart';
import '../../domain/playback_mode.dart';
import '../../domain/player.state.dart';
import '../../domain/track.entity.dart';
import 'track_tile.widget.dart';

/// What is playing and what comes after it, as every player shows it: the
/// "Up next" part of the library sheet.
///
/// Three parts: the track now, the listener's own queue, and what the
/// stream will play after that on its own — the next tracks in order, or
/// the next random picks, drawn ahead so they can be shown here. Only what
/// will really play is listed: a track that comes round again is marked on
/// its own row, not listed twice. Tapping
/// any of them jumps to it; a queued one can be swiped away.
///
/// A group of slivers, so it scrolls as part of the sheet.
class UpNext extends ConsumerWidget {
  const UpNext({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlayerState state = ref.watch(playerControllerProvider);
    final PlayerController player = ref.read(playerControllerProvider.notifier);
    final TrackEntity? current = state.currentTrack;
    final PlaybackMode mode =
        ref.watch(playbackModeControllerProvider).value ?? PlaybackMode.shuffle;
    // Only what will really play is listed. When that is the track playing
    // — repeat is on, or it is the only one there is — the row up top says
    // so with the repeat mark, and there is no list of it again below.
    final bool repeating =
        current != null &&
        (mode.loops ||
            (state.upNext.isNotEmpty &&
                state.upNext.every((TrackEntity t) => t.id == current.id)));

    return SliverMainAxisGroup(
      slivers: <Widget>[
        SliverList.list(
          children: <Widget>[
            const _Heading('Now playing'),
            if (current == null)
              const _Quiet('Nothing yet.')
            else
              TrackTile(track: current, onTap: null, repeating: repeating),
            if (state.queue.isNotEmpty)
              _Heading(
                'Next in queue',
                action: TextButton(
                  onPressed: player.clearQueue,
                  child: Text(
                    'Clear',
                    style: TextStyle(fontSize: context.fontS),
                  ),
                ),
              ),
          ],
        ),
        SliverList.builder(
          itemCount: state.queue.length,
          itemBuilder: (BuildContext context, int index) {
            final TrackEntity track = state.queue[index];
            return Dismissible(
              // The index is part of the key: the same track may be queued
              // twice, and each row must still be its own.
              key: ValueKey<String>('queued-$index-${track.id}'),
              onDismissed: (_) => player.removeFromQueue(index),
              child: TrackTile(
                track: track,
                markCurrent: false,
                onTap: () => unawaited(player.skipToQueued(index)),
              ),
            );
          },
        ),
        if (!repeating && state.upNext.isNotEmpty)
          const SliverToBoxAdapter(child: _Heading('Next up')),
        SliverList.builder(
          itemCount: repeating ? 0 : state.upNext.length,
          itemBuilder: (BuildContext context, int index) => TrackTile(
            track: state.upNext[index],
            markCurrent: false,
            onTap: () => unawaited(player.skipToUpNext(index)),
          ),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, {this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: context.spaceM, bottom: context.spaceXs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: context.fontM,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _Quiet extends StatelessWidget {
  const _Quiet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: context.fontS,
      ),
    );
  }
}
