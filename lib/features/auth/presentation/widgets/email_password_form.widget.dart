import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/errors/app_error.dart';
import '../../../../common/utils/responsive.dart';
import '../../controller/auth.controller.dart';
import '../../domain/auth.repository.dart';
import '../../domain/password_rules.dart';
import 'auth_button.widget.dart';
import 'code_field.widget.dart';

/// Where the email form stands.
enum EmailStep {
  signIn,
  createAccount,

  /// A new address waits for the code mailed to it.
  confirm,

  /// Asking for a reset code.
  forgot,

  /// The reset code and the new password.
  reset,
}

/// Email and password, inside the sheet (#38). Confirming a new address and
/// resetting a password both run on a six-digit code typed in here — nothing
/// sends the listener out of the app to a link.
class EmailPasswordForm extends ConsumerStatefulWidget {
  const EmailPasswordForm({required this.onBack, super.key});

  /// Back to the list of ways in.
  final VoidCallback onBack;

  /// Supabase lets an address ask for a new mail once a minute.
  static const Duration resendAfter = Duration(seconds: 60);

  @override
  ConsumerState<EmailPasswordForm> createState() => _EmailPasswordFormState();
}

class _EmailPasswordFormState extends ConsumerState<EmailPasswordForm> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _code = TextEditingController();

  EmailStep _step = EmailStep.signIn;

  /// The step that asked for the code, for "Different email".
  EmailStep _codeFrom = EmailStep.signIn;
  bool _busy = false;
  String? _error;

  Timer? _countdown;
  int _secondsLeft = 0;

  @override
  void dispose() {
    _countdown?.cancel();
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  AuthController get _auth => ref.read(authControllerProvider.notifier);

  String get _address => _email.text.trim();

  bool get _emailLooksRight {
    final String value = _address;
    final int at = value.indexOf('@');

    return at > 0 && value.indexOf('.', at) > at + 1 && !value.endsWith('.');
  }

  bool get _canSubmit {
    if (_busy) return false;
    return switch (_step) {
      EmailStep.signIn => _emailLooksRight && _password.text.isNotEmpty,
      EmailStep.createAccount =>
        _emailLooksRight && PasswordRules.accepts(_password.text),
      EmailStep.confirm => _code.text.length == CodeField.length,
      EmailStep.forgot => _emailLooksRight,
      EmailStep.reset =>
        _code.text.length == CodeField.length &&
            PasswordRules.accepts(_password.text),
    };
  }

  void _goTo(EmailStep step) {
    setState(() {
      _step = step;
      _error = null;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AppError catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// A code is on its way: clear the field and hold back "Send a new code".
  void _awaitCode(EmailStep step) {
    _code.clear();
    if (step == EmailStep.reset) _password.clear();
    if (_step != step) _codeFrom = _step;
    _goTo(step);
    _countdown?.cancel();
    setState(() => _secondsLeft = EmailPasswordForm.resendAfter.inSeconds);
    _countdown = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) return timer.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  Future<void> _submit() => _run(() async {
    switch (_step) {
      case EmailStep.signIn:
        final EmailSignIn result = await _auth.signInWithPassword(
          email: _address,
          password: _password.text,
        );
        if (result == EmailSignIn.needsCode && mounted) {
          _awaitCode(EmailStep.confirm);
        }
      case EmailStep.createAccount:
        final EmailSignIn result = await _auth.createAccount(
          email: _address,
          password: _password.text,
        );
        if (result == EmailSignIn.needsCode && mounted) {
          _awaitCode(EmailStep.confirm);
        }
      case EmailStep.confirm:
        await _auth.confirmEmail(email: _address, code: _code.text);
      case EmailStep.forgot:
        await _auth.sendPasswordReset(_address);
        if (mounted) _awaitCode(EmailStep.reset);
      case EmailStep.reset:
        await _auth.resetPassword(
          email: _address,
          code: _code.text,
          newPassword: _password.text,
        );
    }
  });

  Future<void> _resend() => _run(() async {
    final EmailStep step = _step;
    await (step == EmailStep.reset
        ? _auth.sendPasswordReset(_address)
        : _auth.resendConfirmation(_address));
    if (mounted) _awaitCode(step);
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextStyle quiet = TextStyle(
      color: cs.onSurfaceVariant,
      fontSize: context.fontS,
      height: 1.4,
    );
    final bool waitingOnCode =
        _step == EmailStep.confirm || _step == EmailStep.reset;
    final bool newPassword =
        _step == EmailStep.createAccount || _step == EmailStep.reset;

    return AutofillGroup(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (waitingOnCode) ...<Widget>[
            Text('We sent a code to $_address.', style: quiet),
            SizedBox(height: context.spaceM),
            CodeField(
              controller: _code,
              enabled: !_busy,
              // Confirming has nothing else to fill in: the sixth digit is
              // the submit. A reset still needs the new password.
              onComplete: _step == EmailStep.confirm
                  ? _submit
                  : () => setState(() {}),
            ),
          ] else
            TextField(
              controller: _email,
              autofocus: true,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: _step == EmailStep.forgot
                  ? TextInputAction.send
                  : TextInputAction.next,
              autocorrect: false,
              autofillHints: const <String>[AutofillHints.email],
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) =>
                  _step == EmailStep.forgot && _canSubmit ? _submit() : null,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
          if (_step != EmailStep.confirm &&
              _step != EmailStep.forgot) ...<Widget>[
            SizedBox(height: context.spaceS),
            TextField(
              controller: _password,
              enabled: !_busy,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              autofillHints: <String>[
                newPassword
                    ? AutofillHints.newPassword
                    : AutofillHints.password,
              ],
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _canSubmit ? _submit() : null,
              decoration: InputDecoration(
                labelText: _step == EmailStep.reset
                    ? 'New password'
                    : 'Password',
                helperText: newPassword
                    ? 'At least ${PasswordRules.minLength} characters'
                    : null,
              ),
            ),
          ],
          if (_step != EmailStep.confirm) ...<Widget>[
            SizedBox(height: context.spaceM),
            AuthButton(
              label: switch (_step) {
                EmailStep.signIn => 'Sign in',
                EmailStep.createAccount => 'Create account',
                EmailStep.forgot => 'Send reset code',
                EmailStep.reset || EmailStep.confirm => 'Set password',
              },
              busy: _busy,
              onPressed: _canSubmit ? _submit : null,
            ),
          ] else if (_busy) ...<Widget>[
            SizedBox(height: context.spaceS),
            LinearProgressIndicator(color: cs.onSurfaceVariant),
          ],
          if (_error != null) ...<Widget>[
            SizedBox(height: context.spaceS),
            Text(
              _error!,
              style: TextStyle(color: cs.error, fontSize: context.fontS),
            ),
          ],
          SizedBox(height: context.spaceS),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            children: <Widget>[
              ...switch (_step) {
                EmailStep.signIn => <Widget>[
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _goTo(EmailStep.createAccount),
                    child: const Text('Create an account'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => _goTo(EmailStep.forgot),
                    child: const Text('Forgot password?'),
                  ),
                ],
                EmailStep.createAccount => <Widget>[
                  TextButton(
                    onPressed: _busy ? null : () => _goTo(EmailStep.signIn),
                    child: const Text('I have an account'),
                  ),
                ],
                EmailStep.forgot => <Widget>[
                  TextButton(
                    onPressed: _busy ? null : () => _goTo(EmailStep.signIn),
                    child: const Text('Back to sign in'),
                  ),
                ],
                EmailStep.confirm || EmailStep.reset => <Widget>[
                  TextButton(
                    onPressed: _busy ? null : () => _goTo(_codeFrom),
                    child: const Text('Different email'),
                  ),
                  TextButton(
                    onPressed: _busy || _secondsLeft > 0 ? null : _resend,
                    child: Text(
                      _secondsLeft > 0
                          ? 'Resend in ${_secondsLeft}s'
                          : 'Send a new code',
                    ),
                  ),
                ],
              },
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: _busy ? null : widget.onBack,
              child: const Text('Other ways to sign in'),
            ),
          ),
        ],
      ),
    );
  }
}
