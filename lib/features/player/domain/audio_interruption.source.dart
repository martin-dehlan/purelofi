import 'audio_interruption.dart';

/// One interruption, as the platform reports it.
typedef InterruptionEvent = ({InterruptionKind kind, bool beginning});

/// What the platform says about other audio and about the headphones.
///
/// Behind an interface so the player can be tested without a phone call: the
/// rules are only worth anything if something exercises them.
abstract class AudioInterruptionSource {
  /// The headphones were pulled out, or the Bluetooth speaker walked away.
  Stream<void> get becomingNoisy;

  /// Something else wants the output, or has finished with it.
  Stream<InterruptionEvent> get interruptions;
}
