import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';

/// Asks once before an account is deleted. `true` means go ahead.
///
/// Said plainly: it cannot be undone, and the music stays — the account was
/// never what made the app work.
Future<bool> confirmDeleteAccount(BuildContext context) async {
  final ColorScheme cs = Theme.of(context).colorScheme;

  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(context.l10n.deleteYourAccount),
      content: Text(context.l10n.deleteAccountExplain),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.keepIt),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: cs.error),
          child: Text(context.l10n.delete),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}
