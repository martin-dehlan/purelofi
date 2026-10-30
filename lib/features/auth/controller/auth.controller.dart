import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../common/analytics/analytics.provider.dart';
import '../../../common/analytics/analytics.service.dart';
import '../../../common/errors/app_error.dart';
import '../domain/account.entity.dart';
import '../domain/auth.repository.dart';
import 'auth.provider.dart';

part 'auth.controller.g.dart';

/// Who is signed in, if anyone. `null` is the normal case, not an error:
/// the app works the same without an account (#38).
///
/// The actions do not touch [state] themselves — every sign-in and sign-out
/// lands through the repository's stream, so there is one source for who is
/// signed in, whichever way it happened (the browser fallback included).
/// They throw `AppError` for the sheet to show.
///
/// It is also where PostHog learns who someone is (#82): identified on
/// sign-in, reset on sign-out, and the sign-in funnel counted on the way.
@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  Stream<Account?> build() async* {
    final AuthRepository auth = ref.watch(authRepositoryProvider);

    final Account? now = auth.current;
    // Already signed in from a previous run: the same person, not a new
    // sign-in.
    if (now != null) unawaited(_identify(now));
    Account? last = now;
    yield now;

    await for (final Account? account in auth.changes) {
      if (account != null && account.id != last?.id) {
        unawaited(_identify(account));
        unawaited(
          _analytics.capture(AnalyticsEvents.signInCompleted, <String, Object>{
            'method': account.method.name,
          }),
        );
      } else if (account == null && last != null) {
        unawaited(_analytics.reset());
      }
      last = account;
      yield account;
    }
  }

  AuthRepository get _auth => ref.read(authRepositoryProvider);

  AnalyticsService get _analytics => ref.read(analyticsServiceProvider);

  Future<void> _identify(Account account) => _analytics.identify(
    account.id,
    <String, Object>{'sign_in_method': account.method.name},
  );

  bool get canUseApple => _auth.canUseApple;

  bool get canUseGoogle => _auth.canUseGoogle;

  /// `false` when the listener closed Apple's sheet. A closed sheet is
  /// neither a failure nor a completion; completion is counted when the
  /// session lands (see [build]).
  Future<bool> signInWithApple() =>
      _counted(SignInMethod.apple, _auth.signInWithApple);

  /// `false` when the listener closed Google's sheet.
  Future<bool> signInWithGoogle() =>
      _counted(SignInMethod.google, _auth.signInWithGoogle);

  Future<void> sendEmailCode(String email) async {
    await _counted(SignInMethod.email, () => _auth.sendEmailCode(email));
    unawaited(_analytics.capture(AnalyticsEvents.emailCodeSent));
  }

  Future<void> verifyEmailCode({required String email, required String code}) =>
      _counted(
        SignInMethod.email,
        () => _auth.verifyEmailCode(email: email, code: code),
        started: false,
      );

  Future<void> signOut() async {
    await _auth.signOut();
    unawaited(_analytics.capture(AnalyticsEvents.signedOut));
  }

  Future<void> deleteAccount() async {
    await _auth.deleteAccount();
    unawaited(_analytics.capture(AnalyticsEvents.accountDeleted));
  }

  /// Counts the start and any failure of a sign-in step. Only the kind of
  /// failure is sent — never the message, which could carry an address.
  Future<T> _counted<T>(
    SignInMethod method,
    Future<T> Function() action, {
    bool started = true,
  }) async {
    final Map<String, Object> props = <String, Object>{'method': method.name};
    if (started) {
      unawaited(_analytics.capture(AnalyticsEvents.signInStarted, props));
    }
    try {
      return await action();
    } on AppError catch (error) {
      unawaited(
        _analytics.capture(AnalyticsEvents.signInFailed, <String, Object>{
          ...props,
          'reason': switch (error) {
            NetworkError() => 'network',
            AuthError() => 'auth',
            _ => 'unknown',
          },
        }),
      );
      rethrow;
    }
  }
}
