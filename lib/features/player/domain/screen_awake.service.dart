/// Keeps the screen from going dark (#149): for window mode, when the room
/// is on a stand by the desk.
abstract class ScreenAwake {
  Future<void> keep(bool awake);
}
