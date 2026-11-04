import '../../../common/errors/app_error.dart';
import 'ambient_loop.dart';
import 'playback_mode.dart';
import 'track.entity.dart';
import 'volume_layer.dart';

/// Plays the audio stream. The implementation wraps `just_audio` and
/// `audio_service`; the controller only ever sees this interface, so tests
/// can substitute a fake (see `docs/10`).
abstract class AudioPlayerService {
  /// Whether audio is currently playing.
  Stream<bool> get playingStream;

  /// Emits when the player wants the next track: the current one finished, or
  /// someone pressed skip on the lock screen.
  Stream<void> get nextRequests;

  /// Emits when the play order is changed outside the app — the
  /// notification, the lock screen, a watch or a car — with the mode the
  /// listener asked for. The controller decides; [setPlaybackMode] follows.
  Stream<PlaybackMode> get modeRequests;

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
  ///
  /// [room] is the scene's name, shown beside the track as its album.
  Future<void> setArtwork(Uri? artUri, {String? room});

  /// Loops the current track in [PlaybackMode.repeatOne], and shows the mode
  /// wherever the platform draws media controls.
  Future<void> setPlaybackMode(PlaybackMode mode);

  Future<void> play();

  Future<void> pause();

  Future<void> stop();

  /// Jumps to [position] in the current track.
  Future<void> seek(Duration position);

  /// Sets one of the reasons the music is turned down, 1 being not at all
  /// and 0 silence. The layers multiply; see [VolumeLayer].
  Future<void> setVolumeLayer(VolumeLayer layer, double level);

  /// Whether a track fades out at its end and the next one fades in (#139).
  Future<void> setSoftTransitions(bool enabled);

  /// A soft chime over the music: the focus timer moving to its next half
  /// (#137).
  Future<void> playChime();

  /// The room's sounds to loop beside the music (#136), replacing the set
  /// before. Sounds that stay keep playing; new ones fade in, gone ones fade
  /// out. They play while the music plays and pause with it.
  Future<void> setAmbience(List<AmbientLoop> loops);
}
