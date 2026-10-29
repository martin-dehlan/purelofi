import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/auth.repository.dart';
import '../domain/account.entity.dart';
import 'auth.provider.dart';

part 'auth.controller.g.dart';

/// Who is signed in, if anyone. `null` is the normal case, not an error:
/// the app works the same without an account (#38).
///
/// The actions do not touch [state] themselves — every sign-in and sign-out
/// lands through the repository's stream, so there is one source for who is
/// signed in, whichever way it happened (the browser fallback included).
/// They throw `AppError` for the sheet to show.
@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  Stream<Account?> build() async* {
    final AuthRepository auth = ref.watch(authRepositoryProvider);

    yield auth.current;
    yield* auth.changes;
  }

  AuthRepository get _auth => ref.read(authRepositoryProvider);

  bool get canUseApple => _auth.canUseApple;

  bool get canUseGoogle => _auth.canUseGoogle;

  /// `false` when the listener closed Apple's sheet.
  Future<bool> signInWithApple() => _auth.signInWithApple();

  /// `false` when the listener closed Google's sheet.
  Future<bool> signInWithGoogle() => _auth.signInWithGoogle();

  Future<void> sendEmailCode(String email) => _auth.sendEmailCode(email);

  Future<void> verifyEmailCode({required String email, required String code}) =>
      _auth.verifyEmailCode(email: email, code: code);

  Future<void> signOut() => _auth.signOut();

  Future<void> deleteAccount() => _auth.deleteAccount();
}
