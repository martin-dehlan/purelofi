import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/common/config/env.dart';

void main() {
  group('Env.bannedIn', () {
    test('passes a .env holding only what is safe to ship', () {
      expect(
        Env.bannedIn(<String, String>{
          'SUPABASE_URL': 'https://example.supabase.co',
          'SUPABASE_ANON_KEY': 'anon',
          'POSTHOG_API_KEY': 'phc_x',
        }),
        isEmpty,
      );
    });

    test('catches the service role key, which bypasses row-level security', () {
      expect(
        Env.bannedIn(<String, String>{
          'SUPABASE_URL': 'https://example.supabase.co',
          'SUPABASE_SERVICE_ROLE_KEY': 'service',
        }),
        <String>['SUPABASE_SERVICE_ROLE_KEY'],
      );
    });

    test('catches the database password too', () {
      expect(
        Env.bannedIn(<String, String>{'SUPABASE_DB_PASSWORD': 'hunter2'}),
        <String>['SUPABASE_DB_PASSWORD'],
      );
    });

    test('an empty value is not a leaked secret', () {
      // A .env.example copied but not filled in yet should still boot.
      expect(
        Env.bannedIn(<String, String>{
          'SUPABASE_SERVICE_ROLE_KEY': '',
          'SUPABASE_DB_PASSWORD': '   ',
        }),
        isEmpty,
      );
    });

    test('the message says where the key belongs instead', () {
      final String message = Env.bannedKeyMessage(<String>[
        'SUPABASE_SERVICE_ROLE_KEY',
      ]);

      expect(message, contains('SUPABASE_SERVICE_ROLE_KEY'));
      expect(message, contains('.env.tools'));
    });
  });

  group('the repository itself', () {
    test('.env carries no key that would ship inside the app', () {
      // The real file, not a fixture: this is the check that would have
      // caught the service role key sitting in the bundle.
      final Map<String, String> values = _readEnvFile('.env');
      if (values.isEmpty) return; // CI has no .env; nothing to check.

      expect(
        Env.bannedIn(values),
        isEmpty,
        reason: Env.bannedKeyMessage(Env.bannedIn(values)),
      );
    });
  });
}

Map<String, String> _readEnvFile(String path) {
  final File file = File(path);
  if (!file.existsSync()) return <String, String>{};

  final Map<String, String> values = <String, String>{};
  for (final String line in file.readAsLinesSync()) {
    final String trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

    final int separator = trimmed.indexOf('=');
    if (separator <= 0) continue;

    values[trimmed.substring(0, separator).trim()] = trimmed
        .substring(separator + 1)
        .trim();
  }

  return values;
}
