import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../common/errors/app_error.dart';
import 'track.entity.dart';

part 'player.state.freezed.dart';

/// What the player is doing right now.
///
/// Playback is not backed by the network, so this is plain synchronous state
/// held by a `Notifier` (see `docs/05`).
@freezed
abstract class PlayerState with _$PlayerState {
  const factory PlayerState({
    @Default(false) bool isPlaying,
    TrackEntity? currentTrack,
    @Default(Duration.zero) Duration position,
    Duration? duration,
    AppError? error,
  }) = _PlayerState;

  const PlayerState._();

  /// How far through the track we are, from 0 to 1. Zero while the length is
  /// still unknown, so the bar starts empty rather than jumping.
  double get progress {
    final Duration? total = duration;
    if (total == null || total <= Duration.zero) return 0;

    return (position.inMilliseconds / total.inMilliseconds).clamp(0, 1);
  }
}
