import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_error.dart';

/// Turns whatever the network or a plugin threw into an [AppError].
abstract final class ErrorMapper {
  static AppError fromException(Object error, [StackTrace? stackTrace]) {
    if (error is AppError) return error;

    if (error is PostgrestException) {
      return switch (error.code) {
        // PostgREST returns PGRST116 when .single() matched no row.
        'PGRST116' => const AppError.notFound(resource: 'Record'),
        _ => AppError.serverError(message: error.message),
      };
    }

    if (error is AuthException) return _auth(error);

    if (error is StorageException) {
      return AppError.serverError(message: error.message);
    }

    if (_looksLikeNetworkFailure(error)) return const AppError.network();

    return AppError.unknown(cause: error, stackTrace: stackTrace);
  }

  /// Supabase Auth's codes, in the listener's words. Anything unknown gets
  /// one honest sentence rather than the server's.
  static AppError _auth(AuthException error) {
    if (_looksLikeNetworkFailure(error)) return const AppError.network();

    return AppError.auth(
      message: switch (error.code) {
        'otp_expired' => 'That code has expired. Send a new one.',
        'otp_disabled' ||
        'email_provider_disabled' => 'Email sign-in is not switched on yet.',
        'over_email_send_rate_limit' || 'over_request_rate_limit' =>
          'Too many tries. Wait a minute, then try again.',
        'email_address_invalid' => 'That email address does not look right.',
        _ when error.message.toLowerCase().contains('token') =>
          'That code did not work. Check it, or send a new one.',
        _ => 'Signing in did not work. Please try again.',
      },
    );
  }

  static bool _looksLikeNetworkFailure(Object error) {
    final String text = error.toString();
    return text.contains('SocketException') ||
        text.contains('ClientException') ||
        text.contains('Connection') ||
        text.contains('timeout') ||
        text.contains('TimeoutException');
  }
}
