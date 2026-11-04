import 'package:freezed_annotation/freezed_annotation.dart';

import 'track.entity.dart';

part 'playlist.entity.freezed.dart';

/// One track in a playlist: PureLofi's or the listener's own.
@freezed
abstract class PlaylistItem with _$PlaylistItem {
  const factory PlaylistItem({
    required String trackId,
    @Default(TrackSource.catalogue) TrackSource source,
  }) = _PlaylistItem;
}

/// A list the listener made (#141).
@freezed
abstract class PlaylistEntity with _$PlaylistEntity {
  const factory PlaylistEntity({
    required String id,
    required String name,
    @Default(<PlaylistItem>[]) List<PlaylistItem> items,
    required DateTime updatedAt,

    /// Set when deleted, so the deletion reaches the other devices.
    DateTime? deletedAt,
  }) = _PlaylistEntity;

  const PlaylistEntity._();

  bool get isDeleted => deletedAt != null;
}

/// The listener's playlists on this device.
abstract class PlaylistRepository {
  /// Every playlist not deleted, most recently changed first.
  Stream<List<PlaylistEntity>> watchPlaylists();

  /// Makes an empty playlist; returns its id.
  Future<String> create(String name);

  Future<void> rename(String id, String name);

  Future<void> delete(String id);

  Future<void> add(String id, PlaylistItem item);

  Future<void> removeAt(String id, int index);

  /// Moves the item at [from] so it ends up at [to].
  Future<void> move(String id, int from, int to);
}
