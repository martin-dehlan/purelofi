import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../common/cache/media_cache.service.dart';
import '../domain/track.entity.dart';
import 'player.provider.dart';

part 'downloads.controller.g.dart';

/// Which tracks are kept on this phone for listening offline, by audio URL,
/// and which are on their way.
class Downloads {
  const Downloads({
    this.done = const <String>{},
    this.pending = const <String>{},
  });

  final Set<String> done;
  final Set<String> pending;

  bool has(TrackEntity track) => done.contains(track.audioUrl);

  bool isLoading(TrackEntity track) => pending.contains(track.audioUrl);
}

/// The listener's downloads (Pro). Only PureLofi's tracks are downloaded —
/// the listener's own files are on the phone already.
///
/// The files themselves are the cache's, kept out of its eviction; this is
/// the list of them, and the way to add and take back.
@Riverpod(keepAlive: true)
class DownloadsController extends _$DownloadsController {
  @override
  Future<Downloads> build() async {
    final MediaCache? cache = ref.watch(mediaCacheProvider);
    if (cache == null) return const Downloads();

    return Downloads(done: await cache.downloadedUrls());
  }

  Downloads get _now => state.value ?? const Downloads();

  /// Downloads [tracks] one after another, so each shows as done when it is.
  /// A download that fails is simply not marked; it can be tried again.
  Future<void> download(Iterable<TrackEntity> tracks) async {
    final MediaCache? cache = ref.read(mediaCacheProvider);
    if (cache == null) return;
    final List<String> urls = <String>[
      for (final TrackEntity track in tracks)
        if (track.source == TrackSource.catalogue &&
            !_now.done.contains(track.audioUrl) &&
            !_now.pending.contains(track.audioUrl))
          track.audioUrl,
    ];
    if (urls.isEmpty) return;

    state = AsyncData<Downloads>(
      Downloads(done: _now.done, pending: <String>{..._now.pending, ...urls}),
    );
    for (final String url in urls) {
      final bool ok = await cache.download(url) != null;
      state = AsyncData<Downloads>(
        Downloads(
          done: ok ? <String>{..._now.done, url} : _now.done,
          pending: <String>{..._now.pending}..remove(url),
        ),
      );
    }
  }

  /// Takes [tracks] back off the list; their files go when the cache needs
  /// the room.
  Future<void> remove(Iterable<TrackEntity> tracks) async {
    final MediaCache? cache = ref.read(mediaCacheProvider);
    if (cache == null) return;
    final Set<String> urls = <String>{
      for (final TrackEntity track in tracks) track.audioUrl,
    };
    state = AsyncData<Downloads>(
      Downloads(
        done: <String>{..._now.done}..removeAll(urls),
        pending: _now.pending,
      ),
    );
    for (final String url in urls) {
      await cache.removeDownload(url);
    }
  }

  /// Takes every download back.
  Future<void> removeAll() async {
    final MediaCache? cache = ref.read(mediaCacheProvider);
    if (cache == null) return;
    final Set<String> urls = _now.done;
    state = AsyncData<Downloads>(Downloads(pending: _now.pending));
    for (final String url in urls) {
      await cache.removeDownload(url);
    }
  }
}
