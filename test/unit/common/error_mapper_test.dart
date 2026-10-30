import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/common/errors/app_error.dart';
import 'package:purelofi/common/errors/error_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('ErrorMapper', () {
    test('passes an AppError through untouched', () {
      const AppError original = AppError.playback(message: 'decoder failed');

      expect(ErrorMapper.fromException(original), same(original));
    });

    test('maps PGRST116 to notFound', () {
      final AppError result = ErrorMapper.fromException(
        const PostgrestException(message: 'no rows', code: 'PGRST116'),
      );

      expect(result, isA<NotFoundError>());
    });

    test('maps any other Postgrest failure to serverError', () {
      final AppError result = ErrorMapper.fromException(
        const PostgrestException(message: 'permission denied', code: '42501'),
      );

      expect(result, isA<ServerError>());
      expect(result.userMessage, 'permission denied');
    });

    test('maps a storage failure to serverError', () {
      final AppError result = ErrorMapper.fromException(
        const StorageException('object not found'),
      );

      expect(result, isA<ServerError>());
    });

    test('maps socket and timeout failures to network', () {
      expect(
        ErrorMapper.fromException(Exception('SocketException: no route')),
        isA<NetworkError>(),
      );
      expect(
        ErrorMapper.fromException(Exception('TimeoutException after 30s')),
        isA<NetworkError>(),
      );
    });

    test('falls back to unknown and keeps the cause', () {
      final Exception cause = Exception('something odd');

      final AppError result = ErrorMapper.fromException(cause);

      expect(result, isA<UnknownError>());
      expect((result as UnknownError).cause, same(cause));
    });
  });

  group('AppErrorX.userMessage', () {
    test('never exposes raw exception text for unknown failures', () {
      final AppError result = ErrorMapper.fromException(
        Exception('PostgrestException: secret internals'),
      );

      expect(result.userMessage, 'Something went wrong. Please try again.');
    });

    test('falls back to a default message per case', () {
      expect(
        const AppError.network().userMessage,
        'Can’t reach PureLofi right now. Check your connection and try again.',
      );
      expect(
        const AppError.notFound(resource: 'Track').userMessage,
        'Track not found.',
      );
      expect(
        const AppError.serverError(statusCode: 500).userMessage,
        'Server error (500). Try again.',
      );
      expect(
        const AppError.playback(message: 'stream stalled').userMessage,
        'Playback error: stream stalled',
      );
    });
  });

  group('auth', () {
    AppError map(AuthException error) => ErrorMapper.fromException(error);

    test('known codes become plain sentences', () {
      expect(
        map(const AuthException('x', code: 'otp_expired')).userMessage,
        'That code has expired. Send a new one.',
      );
      expect(
        map(
          const AuthException('x', code: 'over_email_send_rate_limit'),
        ).userMessage,
        'Too many tries. Wait a minute, then try again.',
      );
      expect(
        map(
          const AuthException('x', code: 'email_address_invalid'),
        ).userMessage,
        'That email address does not look right.',
      );
    });

    test('password codes become plain sentences', () {
      expect(
        map(const AuthException('x', code: 'invalid_credentials')).userMessage,
        'Wrong email or password.',
      );
      expect(
        map(const AuthException('x', code: 'weak_password')).userMessage,
        'That password is too easy to guess. Pick a longer one.',
      );
      expect(
        map(const AuthException('x', code: 'user_already_exists')).userMessage,
        'There is already an account with this email. Sign in instead.',
      );
      expect(
        map(const AuthException('x', code: 'same_password')).userMessage,
        'That is your current password. Pick a new one.',
      );
    });

    test('a bad code without a code name still reads as a bad code', () {
      expect(
        map(const AuthException('Token has expired or is invalid')).userMessage,
        'That code did not work. Check it, or send a new one.',
      );
    });

    test('anything else never shows the server text', () {
      final AppError result = map(
        const AuthException('internal: provider secret mismatch'),
      );

      expect(result, isA<AuthError>());
      expect(result.userMessage, 'Signing in did not work. Please try again.');
    });

    test('a dropped connection is still a network error', () {
      expect(
        map(const AuthException('SocketException: failed host lookup')),
        isA<NetworkError>(),
      );
    });
  });
}
