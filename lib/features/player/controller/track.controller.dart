import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/track.entity.dart';
import 'player.provider.dart';

part 'track.controller.g.dart';

/// Loads the active tracks from Supabase.
///
/// Kept alive: the track list is the app's content, fetched once and read
/// again on every track change. Auto-disposing it would refetch mid-stream.
@Riverpod(keepAlive: true)
class TrackListController extends _$TrackListController {
  @override
  Future<List<TrackEntity>> build() {
    return ref.watch(contentRepositoryProvider).getTracks();
  }
}
