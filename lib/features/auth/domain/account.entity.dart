import 'package:freezed_annotation/freezed_annotation.dart';

part 'account.entity.freezed.dart';

/// How a listener signed in.
enum SignInMethod {
  apple,
  google,

  /// A six-digit code sent to their address.
  email,
}

/// A signed-in listener.
///
/// Accounts are optional and additive: nothing in the app waits on one
/// (#38). [email] can be missing — Apple lets a listener hide it.
@freezed
abstract class Account with _$Account {
  const factory Account({
    required String id,
    required SignInMethod method,
    String? email,
    String? name,
  }) = _Account;
}
