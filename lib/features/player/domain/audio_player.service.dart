import '../../../common/errors/app_error.dart';
import 'track.entity.dart';

/// Plays the audio stream. The implementation wraps `just_audio` and
/// `audio_service`; the controller only ever sees this interface, so tests
/// can substitute a fake (see `docs/10`).
abstract class AudioPlayerService {
  /// Whether audio is currently playing.
  Stream<bool> get playingStream;

  /// Emits when the player wants the next track: the current one finished, or
  /// someone pressed skip on the lock screen.
  Stream<void> get nextRequests;

  /// Playback failures, already mapped to `AppError.playback`.
  Stream<AppError> get errors;

  /// How far into the current track playback is.
  Stream<Duration> get positionStream;

  /// How long the current track is, once the player knows.
  Stream<Duration?> get durationStream;

  /// Loads [track] and starts playing it.
  Future<void> playTrack(TrackEntity track);

  /// The picture the lock screen and the notification show.
  ///
  /// Set from the scene, because that is what the listener is actually
  /// looking at. Without it both platforms draw a black rectangle where the
  /// cover belongs.
  Future<void> setArtwork(Uri? artUri);

  Future<void> play();

  Future<void> pause();

  Future<void> stop();

  /// Jumps to [position] in the current track.
  Future<void> seek(Duration position);
}
