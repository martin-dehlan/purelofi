import 'package:freezed_annotation/freezed_annotation.dart';

part 'account.entity.freezed.dart';

/// How a listener signed in.
enum SignInMethod {
  apple,
  google,

  /// Their address and a password.
  email,
}

/// A signed-in listener.
///
/// Accounts are optional and additive: nothing in the app waits on one
/// (#38). [email] can be missing — Apple lets a listener hide it.
/// [memberSince] is when the account was created, for the profile (#96).
@freezed
abstract class Account with _$Account {
  const factory Account({
    required String id,
    required SignInMethod method,
    String? email,
    String? name,
    DateTime? memberSince,
  }) = _Account;
}
