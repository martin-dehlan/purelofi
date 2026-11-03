import 'package:freezed_annotation/freezed_annotation.dart';

import '../domain/artist.entity.dart';

part 'artist.model.freezed.dart';
part 'artist.model.g.dart';

/// A row of the Supabase `artists` table.
@freezed
abstract class ArtistModel with _$ArtistModel {
  const factory ArtistModel({
    required String id,
    required String name,
    String? bio,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
    @JsonKey(name: 'link_url') String? linkUrl,
    @Default(<String>[]) List<String> links,
  }) = _ArtistModel;

  factory ArtistModel.fromJson(Map<String, dynamic> json) =>
      _$ArtistModelFromJson(json);
}

extension ArtistModelX on ArtistModel {
  ArtistEntity toEntity() => ArtistEntity(
    id: id,
    name: name,
    bio: bio,
    avatarUrl: avatarUrl,
    // Rows from before #109 have only the one link.
    links: links.isNotEmpty ? links : <String>[?linkUrl],
  );
}
