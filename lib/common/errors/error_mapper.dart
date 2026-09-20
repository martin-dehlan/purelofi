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

    if (error is StorageException) {
      return AppError.serverError(message: error.message);
    }

    if (_looksLikeNetworkFailure(error)) return const AppError.network();

    return AppError.unknown(cause: error, stackTrace: stackTrace);
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
