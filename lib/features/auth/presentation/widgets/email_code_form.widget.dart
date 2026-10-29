import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/errors/app_error.dart';
import '../../../../common/utils/app_fonts.dart';
import '../../../../common/utils/responsive.dart';
import '../../controller/auth.controller.dart';
import 'auth_button.widget.dart';

/// Email sign-in in two steps, inside the sheet: the address, then the
/// six-digit code that was sent to it. No password and no link to follow
/// out of the app (#38).
class EmailCodeForm extends ConsumerStatefulWidget {
  const EmailCodeForm({required this.onBack, super.key});

  /// Back to the list of ways in.
  final VoidCallback onBack;

  /// Supabase lets an address ask for a new code once a minute.
  static const Duration resendAfter = Duration(seconds: 60);

  static const int codeLength = 6;

  @override
  ConsumerState<EmailCodeForm> createState() => _EmailCodeFormState();
}

class _EmailCodeFormState extends ConsumerState<EmailCodeForm> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _code = TextEditingController();

  /// The address the code went to; `null` until one was sent.
  String? _sentTo;
  bool _busy = false;
  String? _error;

  Timer? _countdown;
  int _secondsLeft = 0;

  @override
  void dispose() {
    _countdown?.cancel();
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  bool get _emailLooksRight {
    final String value = _email.text.trim();
    final int at = value.indexOf('@');

    return at > 0 && value.indexOf('.', at) > at + 1 && !value.endsWith('.');
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

  Future<void> _send() => _run(() async {
    final String email = _email.text.trim();
    await ref.read(authControllerProvider.notifier).sendEmailCode(email);
    if (!mounted) return;
    setState(() => _sentTo = email);
    _code.clear();
    _startCountdown();
  });

  Future<void> _verify() => _run(
    () => ref
        .read(authControllerProvider.notifier)
        .verifyEmailCode(email: _sentTo!, code: _code.text),
  );

  void _startCountdown() {
    _countdown?.cancel();
    setState(() => _secondsLeft = EmailCodeForm.resendAfter.inSeconds);
    _countdown = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) return timer.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String? sentTo = _sentTo;
    final TextStyle quiet = TextStyle(
      color: cs.onSurfaceVariant,
      fontSize: context.fontS,
      height: 1.4,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (sentTo == null) ...<Widget>[
          TextField(
            controller: _email,
            autofocus: true,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.send,
            autocorrect: false,
            autofillHints: const <String>[AutofillHints.email],
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _emailLooksRight ? _send() : null,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          SizedBox(height: context.spaceM),
          AuthButton(
            label: 'Send code',
            busy: _busy,
            onPressed: _emailLooksRight && !_busy ? _send : null,
          ),
        ] else ...<Widget>[
          Text('We sent a code to $sentTo.', style: quiet),
          SizedBox(height: context.spaceM),
          TextField(
            controller: _code,
            autofocus: true,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: EmailCodeForm.codeLength,
            autofillHints: const <String>[AutofillHints.oneTimeCode],
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            // The sixth digit is the submit: nothing left to press.
            onChanged: (String value) {
              if (value.length == EmailCodeForm.codeLength) _verify();
            },
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: context.fontXl,
              letterSpacing: context.fontXl * 0.5,
            ),
            decoration: const InputDecoration(
              labelText: 'Code',
              counterText: '',
            ),
          ),
          if (_busy) ...<Widget>[
            SizedBox(height: context.spaceS),
            LinearProgressIndicator(color: cs.onSurfaceVariant),
          ],
          SizedBox(height: context.spaceS),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _sentTo = null;
                        _error = null;
                      }),
                child: const Text('Different email'),
              ),
              TextButton(
                onPressed: _busy || _secondsLeft > 0 ? null : _send,
                child: Text(
                  _secondsLeft > 0
                      ? 'Resend in ${_secondsLeft}s'
                      : 'Send a new code',
                ),
              ),
            ],
          ),
        ],
        if (_error != null) ...<Widget>[
          SizedBox(height: context.spaceS),
          Text(
            _error!,
            style: TextStyle(color: cs.error, fontSize: context.fontS),
          ),
        ],
        SizedBox(height: context.spaceS),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: _busy ? null : widget.onBack,
            child: const Text('Other ways to sign in'),
          ),
        ),
      ],
    );
  }
}
