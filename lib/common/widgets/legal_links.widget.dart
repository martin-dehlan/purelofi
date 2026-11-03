import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/app_links.dart';
import '../utils/responsive.dart';

/// Privacy, terms and imprint as three quiet links to purelofi.app.
///
/// Links only: the texts live on the website, never in the app.
class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key, this.onOpen = AppLinks.open});

  /// Opens a link; tests pass their own to see which one was tapped.
  final Future<void> Function(Uri uri) onOpen;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final ButtonStyle style = TextButton.styleFrom(
      foregroundColor: cs.onSurfaceVariant,
      textStyle: TextStyle(fontSize: context.fontS),
      padding: EdgeInsets.symmetric(horizontal: context.spaceS),
    );

    Widget link(String label, Uri uri) => TextButton(
      style: style,
      onPressed: () => unawaited(onOpen(uri)),
      child: Text(label),
    );

    return Wrap(
      alignment: WrapAlignment.center,
      children: <Widget>[
        link('Privacy', AppLinks.privacy),
        link('Terms', AppLinks.terms),
        link('Imprint', AppLinks.imprint),
      ],
    );
  }
}
