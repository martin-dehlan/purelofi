import 'package:audio_session/audio_session.dart';

import '../domain/audio_interruption.dart';
import '../domain/audio_interruption.source.dart';

/// [AudioInterruptionSource] over `audio_session`.
///
/// `audio_service` configures the session for us; what it does not do is
/// decide what an interruption means, which is why this exists at all.
class AudioSessionInterruptions implements AudioInterruptionSource {
  const AudioSessionInterruptions(this._session);

  final AudioSession _session;

  static Future<AudioSessionInterruptions> create() async =>
      AudioSessionInterruptions(await AudioSession.instance);

  @override
  Stream<void> get becomingNoisy => _session.becomingNoisyEventStream;

  @override
  Stream<InterruptionEvent> get interruptions =>
      _session.interruptionEventStream.map(
        (AudioInterruptionEvent event) => (
          // `unknown` is treated as a stop: on Android it is what arrives
          // when another app simply takes the output, and quietly carrying on
          // over the top of it is the wrong guess.
          kind: event.type == AudioInterruptionType.duck
              ? InterruptionKind.duck
              : InterruptionKind.pause,
          beginning: event.begin,
        ),
      );
}
