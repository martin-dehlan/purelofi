import 'dart:async';

import 'package:purelofi/common/errors/app_error.dart';
import 'package:purelofi/features/auth/domain/account.entity.dart';
import 'package:purelofi/features/auth/domain/auth.repository.dart';

/// Accounts in memory: no Supabase, no native sheets.
///
/// Each sign-in "succeeds" by putting [nextAccount] on the stream, the way
/// the real one lands through Supabase's auth events. Set [failWith] to
/// make the next call throw.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    Account? signedIn,
    this.apple = false,
    this.google = true,
  }) : _current = signedIn;

  final bool apple;
  final bool google;

  final StreamController<Account?> _changes =
      StreamController<Account?>.broadcast();
  Account? _current;

  /// Who a sign-in signs in as.
  Account nextAccount = const Account(
    id: 'u1',
    method: SignInMethod.email,
    email: 'listener@example.com',
  );

  /// Thrown by the next call, then cleared.
  AppError? failWith;

  /// The sheet was closed: sign-ins return `false` and change nothing.
  bool cancel = false;

  /// The address never got its code: a password sign-in asks for one.
  bool unconfirmed = false;

  final List<String> calls = <String>[];

  @override
  Stream<Account?> get changes => _changes.stream;

  @override
  Account? get current => _current;

  @override
  bool get canUseApple => apple;

  @override
  bool get canUseGoogle => google;

  void _set(Account? account) {
    _current = account;
    _changes.add(account);
  }

  Future<void> _maybeFail() async {
    final AppError? failure = failWith;
    failWith = null;
    if (failure != null) throw failure;
  }

  Future<bool> _signIn(String call, SignInMethod method) async {
    calls.add(call);
    await _maybeFail();
    if (cancel) return false;
    _set(nextAccount.copyWith(method: method));
    return true;
  }

  @override
  Future<bool> signInWithApple() => _signIn('apple', SignInMethod.apple);

  @override
  Future<bool> signInWithGoogle() => _signIn('google', SignInMethod.google);

  @override
  Future<EmailSignIn> signInWithPassword({
    required String email,
    required String password,
  }) async {
    calls.add('sign in $email $password');
    await _maybeFail();
    if (unconfirmed) return EmailSignIn.needsCode;
    _signInByEmail(email);
    return EmailSignIn.signedIn;
  }

  @override
  Future<EmailSignIn> createAccount({
    required String email,
    required String password,
  }) async {
    calls.add('create $email $password');
    await _maybeFail();
    return EmailSignIn.needsCode;
  }

  @override
  Future<void> confirmEmail({
    required String email,
    required String code,
  }) async {
    calls.add('confirm $email $code');
    await _maybeFail();
    _signInByEmail(email);
  }

  @override
  Future<void> resendConfirmation(String email) async {
    calls.add('resend $email');
    await _maybeFail();
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    calls.add('forgot $email');
    await _maybeFail();
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    calls.add('reset $email $code $newPassword');
    await _maybeFail();
    _signInByEmail(email);
  }

  void _signInByEmail(String email) =>
      _set(nextAccount.copyWith(email: email, method: SignInMethod.email));

  @override
  Future<void> signOut() async {
    calls.add('sign out');
    await _maybeFail();
    _set(null);
  }

  @override
  Future<void> deleteAccount() async {
    calls.add('delete');
    await _maybeFail();
    _set(null);
  }

  Future<void> dispose() => _changes.close();
}
