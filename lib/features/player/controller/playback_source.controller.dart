import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/track.entity.dart';

part 'playback_source.controller.g.dart';

/// Which music the stream draws from: PureLofi's own, or the listener's.
///
/// Always the catalogue at launch, and deliberately not remembered. The
/// recordings are what the app is for; the listener's library is something
/// they reach for, not where they land (#66).
@Riverpod(keepAlive: true)
class PlaybackSourceController extends _$PlaybackSourceController {
  @override
  TrackSource build() => TrackSource.catalogue;

  void select(TrackSource source) => state = source;
}
