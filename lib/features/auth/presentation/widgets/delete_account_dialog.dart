import 'package:flutter/material.dart';

/// Asks once before an account is deleted. `true` means go ahead.
///
/// Said plainly: it cannot be undone, and the music stays — the account was
/// never what made the app work.
Future<bool> confirmDeleteAccount(BuildContext context) async {
  final ColorScheme cs = Theme.of(context).colorScheme;

  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: const Text('Delete your account?'),
      content: const Text(
        'This removes your account and everything tied to it for good. '
        'PureLofi keeps playing — you just will not be signed in.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep it'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: cs.error),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}
