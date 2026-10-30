/// What the app asks of a password before Supabase does. Kept in step with
/// Authentication → Providers → Email → "Minimum password length".
abstract final class PasswordRules {
  static const int minLength = 8;

  static bool accepts(String password) => password.length >= minLength;
}
