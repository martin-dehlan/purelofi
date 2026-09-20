import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_error.freezed.dart';

/// Every failure the app surfaces to the user.
///
/// Repositories map raw exceptions to one of these (see `error_mapper.dart`),
/// so the UI never renders a `PostgrestException` or a stack trace.
@freezed
sealed class AppError with _$AppError implements Exception {
  const factory AppError.network({String? message, int? statusCode}) =
      NetworkError;

  const factory AppError.notFound({required String resource}) = NotFoundError;

  const factory AppError.serverError({String? message, int? statusCode}) =
      ServerError;

  const factory AppError.playback({required String message}) = PlaybackError;

  const factory AppError.unknown({
    required Object cause,
    StackTrace? stackTrace,
  }) = UnknownError;
}

extension AppErrorX on AppError {
  /// The message shown to the user. Never raw exception text.
  String get userMessage => switch (this) {
    NetworkError(:final String? message) =>
      message ?? 'No internet connection. Check your network.',
    NotFoundError(:final String resource) => '$resource not found.',
    ServerError(:final String? message, :final int? statusCode) =>
      message ?? 'Server error (${statusCode ?? '?'}). Try again.',
    PlaybackError(:final String message) => 'Playback error: $message',
    UnknownError() => 'Something went wrong. Please try again.',
  };
}
