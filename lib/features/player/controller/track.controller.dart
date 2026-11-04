import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/content.repository.dart';
import '../domain/track.entity.dart';
import 'player.provider.dart';

part 'track.controller.g.dart';

/// Loads the active tracks from Supabase.
///
/// Kept alive: the track list is the app's content, fetched once and read
/// again on every track change. Auto-disposing it would refetch mid-stream.
///
/// A fetch too slow to wait for still counts: when it lands, the list is
/// read again from the cache.
@Riverpod(keepAlive: true)
class TrackListController extends _$TrackListController {
  @override
  Future<List<TrackEntity>> build() {
    final ContentRepository content = ref.watch(contentRepositoryProvider);
    onLateUpdate(
      ref,
      content,
      () => content.getTracks(cachedOnly: true),
      (List<TrackEntity> tracks) =>
          state = AsyncData<List<TrackEntity>>(tracks),
    );
    return content.getTracks();
  }
}

/// Reads [read] again whenever [content] says a late fetch has landed, and
/// hands the result to [apply]. A failed read keeps what is there.
void onLateUpdate<T>(
  Ref ref,
  ContentRepository content,
  Future<T> Function() read,
  void Function(T value) apply,
) {
  final StreamSubscription<void> subscription = content.updates.listen((
    _,
  ) async {
    try {
      apply(await read());
    } on Object {
      // The cache could not be read; the list on screen stays.
    }
  });
  ref.onDispose(subscription.cancel);
}
