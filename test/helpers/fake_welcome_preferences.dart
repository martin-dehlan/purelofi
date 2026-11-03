import 'package:purelofi/features/auth/domain/welcome_preferences.service.dart';

/// The first-launch flag in memory: already seen, unless a test is about
/// the first launch.
class FakeWelcomePreferences implements WelcomePreferences {
  FakeWelcomePreferences({this.seen = true});

  bool seen;

  @override
  Future<bool> loadSeen() async => seen;

  @override
  Future<void> markSeen() async => seen = true;
}
