import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed access to the values in `.env`.
///
/// `.env` is git-ignored — copy `.env.example` and fill it in. Keys are read
/// lazily so a missing key fails where it is used, with a message that says
/// which key is missing, rather than silently handing Supabase an empty URL.
abstract final class Env {
  static const String supabaseUrlEnv = 'SUPABASE_URL';
  static const String supabaseAnonKeyEnv = 'SUPABASE_ANON_KEY';
  static const String posthogApiKeyEnv = 'POSTHOG_API_KEY';
  static const String posthogHostEnv = 'POSTHOG_HOST';

  /// Loads `.env` into memory. Call once, before [runApp].
  static Future<void> load() => dotenv.load();

  static String get supabaseUrl => _require(supabaseUrlEnv);

  static String get supabaseAnonKey => _require(supabaseAnonKeyEnv);

  /// Returns the value for [key], or `null` when it is absent or blank.
  ///
  /// Use this for optional configuration (analytics, for instance) that should
  /// degrade instead of crashing the app.
  static String? maybeRead(String key) {
    // dotenv throws if .env was never loaded — in tests, for instance. An
    // unset key and an unloaded file mean the same thing here.
    try {
      final String value = dotenv.env[key]?.trim() ?? '';
      return value.isEmpty ? null : value;
    } on Object {
      return null;
    }
  }

  static String _require(String key) {
    final String? value = maybeRead(key);
    if (value == null) {
      throw StateError(
        'Missing $key. Copy .env.example to .env and fill it in.',
      );
    }
    return value;
  }
}
