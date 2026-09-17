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
    AppError? error,
  }) = _PlayerState;
}
