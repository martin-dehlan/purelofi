/// How the focus timer (#137) tells a listener who is not looking that a
/// half is over: a buzz, and a notification saying what comes now.
abstract class FocusNotifier {
  /// Asks for leave to notify, once, when a focus timer is started: the
  /// moment the listener can see why.
  Future<void> prepare();

  /// A buzz and a notification reading [text], replacing the last one.
  Future<void> announce(String text);

  /// Takes the notification away, when the timer is turned off.
  Future<void> clear();
}
