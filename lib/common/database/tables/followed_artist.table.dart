import 'package:drift/drift.dart';

/// An artist the listener follows, or stopped following (#147). The row
/// stays after an unfollow until the account has heard about it.
@DataClassName('FollowedArtistTableData')
class FollowedArtistTable extends Table {
  @override
  String get tableName => 'followed_artists';

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{artistId};

  TextColumn get artistId => text()();
  BoolColumn get isFollowed => boolean()();

  /// Whether the account has this mark.
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
}
