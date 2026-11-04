import 'package:freezed_annotation/freezed_annotation.dart';

part 'artist.entity.freezed.dart';

/// Someone whose music PureLofi plays. [links] are where to find more of
/// it, every channel they are on (#109), in the order to show them.
@freezed
abstract class ArtistEntity with _$ArtistEntity {
  const factory ArtistEntity({
    required String id,
    required String name,
    String? bio,
    String? avatarUrl,
    @Default(<String>[]) List<String> links,

    /// Where to support them directly (#152): their Bandcamp, Ko-fi,
    /// Patreon. Opened outside the app; PureLofi takes nothing.
    String? supportUrl,
  }) = _ArtistEntity;
}
