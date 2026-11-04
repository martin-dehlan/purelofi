import 'package:freezed_annotation/freezed_annotation.dart';
import '../../l10n/l10n.dart';

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

  /// Signing in failed. [message] is already a sentence for the listener.
  const factory AppError.auth({required String message}) = AuthError;

  /// Buying or restoring Pro failed. [message] is already a sentence.
  const factory AppError.purchase({required String message}) = PurchaseError;

  const factory AppError.unknown({
    required Object cause,
    StackTrace? stackTrace,
  }) = UnknownError;
}

extension AppErrorX on AppError {
  /// The message shown to the user. Never raw exception text.
  String get userMessage => switch (this) {
    NetworkError(:final String? message) =>
      message ??
          'Can’t reach PureLofi right now. Check your connection and try again.',
    NotFoundError(:final String resource) => '$resource not found.',
    ServerError(:final String? message, :final int? statusCode) =>
      message ?? 'Server error (${statusCode ?? '?'}). Try again.',
    PlaybackError(:final String message) => 'Playback error: $message',
    AuthError(:final String message) => message,
    PurchaseError(:final String message) => message,
    UnknownError() => 'Something went wrong. Please try again.',
  };
}

/// [AppErrorX.userMessage] in the listener's language (#140). A message the
/// mapper wrote itself — what the auth server said, say — is passed through;
/// the general ones are translated.
extension AppErrorL10n on AppError {
  String userMessageIn(AppLocalizations l10n) => switch (this) {
    NetworkError(:final String? message) => message ?? l10n.errorNetwork,
    NotFoundError(:final String resource) => l10n.errorNotFound(resource),
    ServerError(:final String? message, :final int? statusCode) =>
      message ?? l10n.errorServer(statusCode?.toString() ?? '?'),
    PlaybackError(:final String message) => l10n.errorPlayback(message),
    AuthError(:final String message) => message,
    PurchaseError(:final String message) => message,
    UnknownError() => l10n.errorUnknown,
  };
}
