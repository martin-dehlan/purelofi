/// Whether the sign-in has been offered on a first launch, kept between
/// launches so it is offered once and never again.
abstract class WelcomePreferences {
  Future<bool> loadSeen();

  Future<void> markSeen();
}
