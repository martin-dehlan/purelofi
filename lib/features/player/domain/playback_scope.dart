import 'package:freezed_annotation/freezed_annotation.dart';

part 'playback_scope.freezed.dart';

/// What kind of list the stream is held to.
enum ScopeKind { mood, playlist }

/// A list the stream plays from instead of everything (#141): a mood or a
/// playlist. `null` scope is everything on the current side, as always.
@freezed
abstract class PlaybackScope with _$PlaybackScope {
  const factory PlaybackScope({
    required ScopeKind kind,
    required String id,
    required String title,
  }) = _PlaybackScope;
}
