import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../common/utils/app_fonts.dart';
import '../../../../common/utils/responsive.dart';

/// The six digits from a PureLofi mail, in mono and spaced out like the
/// mail shows them.
class CodeField extends StatelessWidget {
  const CodeField({
    required this.controller,
    required this.enabled,
    this.autofocus = true,
    this.onComplete,
    super.key,
  });

  static const int length = 6;

  final TextEditingController controller;
  final bool enabled;
  final bool autofocus;

  /// Called on the sixth digit, where that digit is the submit.
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      enabled: enabled,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: length,
      autofillHints: const <String>[AutofillHints.oneTimeCode],
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ],
      onChanged: (String value) {
        if (value.length == length) onComplete?.call();
      },
      style: TextStyle(
        fontFamily: AppFonts.mono,
        fontSize: context.fontXl,
        letterSpacing: context.fontXl * 0.5,
      ),
      decoration: const InputDecoration(labelText: 'Code', counterText: ''),
    );
  }
}
