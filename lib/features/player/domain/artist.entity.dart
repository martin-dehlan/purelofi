import 'package:freezed_annotation/freezed_annotation.dart';

part 'artist.entity.freezed.dart';

/// Someone whose music PureLofi plays. [linkUrl] is where to find more of
/// it: their own page, a label or a streaming profile.
@freezed
abstract class ArtistEntity with _$ArtistEntity {
  const factory ArtistEntity({
    required String id,
    required String name,
    String? bio,
    String? avatarUrl,
    String? linkUrl,
  }) = _ArtistEntity;
}
