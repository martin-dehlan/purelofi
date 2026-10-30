import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed access to the values in `.env`.
///
/// `.env` is git-ignored — copy `.env.example` and fill it in. Keys are read
/// lazily so a missing key fails where it is used, with a message that says
/// which key is missing, rather than silently handing Supabase an empty URL.
///
/// `.env` ships **inside the app bundle**: it is listed under `assets:` in
/// `pubspec.yaml`, and an app bundle is a zip anyone can open. Only keys that
/// are safe in a stranger's hands belong in it. Anything that grants write
/// access belongs in `.env.tools`, which no build ever touches.
abstract final class Env {
  static const String supabaseUrlEnv = 'SUPABASE_URL';
  static const String supabaseAnonKeyEnv = 'SUPABASE_ANON_KEY';
  static const String posthogApiKeyEnv = 'POSTHOG_API_KEY';
  static const String posthogHostEnv = 'POSTHOG_HOST';

  /// Google OAuth client IDs for native sign-in (#38). Public by design:
  /// they name the app to Google, they unlock nothing. Optional — without
  /// them the Google button is simply not shown.
  static const String googleWebClientIdEnv = 'GOOGLE_WEB_CLIENT_ID';
  static const String googleIosClientIdEnv = 'GOOGLE_IOS_CLIENT_ID';

  /// RevenueCat's public SDK keys, one per store (#16). Public by design —
  /// never the secret API key. Without them Pro is switched off and every
  /// scene stays free.
  static const String revenueCatAppleKeyEnv = 'REVENUECAT_APPLE_KEY';
  static const String revenueCatGoogleKeyEnv = 'REVENUECAT_GOOGLE_KEY';

  /// Keys that must never reach a build.
  ///
  /// The service role key bypasses row-level security entirely, and the
  /// database password opens Postgres directly. The anon key is fine here —
  /// RLS is what protects the data, and it is meant to be public.
  static const List<String> bannedKeys = <String>[
    'SUPABASE_SERVICE_ROLE_KEY',
    'SUPABASE_DB_PASSWORD',
  ];

  /// Loads `.env` into memory. Call once, before [runApp].
  ///
  /// Refuses to start if a secret came along: a key that should not be in a
  /// bundle is worth a crash on the developer's machine, because nothing
  /// downstream would ever notice it.
  static Future<void> load() async {
    await dotenv.load();
    final List<String> found = bannedIn(dotenv.env);
    if (found.isNotEmpty) throw StateError(bannedKeyMessage(found));
  }

  /// Which of [values] must not be in a bundled `.env`.
  static List<String> bannedIn(Map<String, String> values) => bannedKeys
      .where((String key) => (values[key] ?? '').trim().isNotEmpty)
      .toList();

  /// What to tell whoever built this.
  static String bannedKeyMessage(List<String> found) =>
      '${found.join(', ')} must not be in .env — it is bundled into the app, '
      'and an app bundle is a zip anyone can open. Move these to .env.tools, '
      'which only tool/ reads.';

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
