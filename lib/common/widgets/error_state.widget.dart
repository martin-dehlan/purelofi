import 'package:flutter/material.dart';

import '../errors/app_error.dart';
import '../errors/error_mapper.dart';
import '../utils/responsive.dart';

/// Renders a failure the way the user should see it: one plain sentence from
/// `AppError.userMessage`, never raw exception text (see `docs/07`).
class ErrorState extends StatelessWidget {
  const ErrorState({required this.error, super.key, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AppError appError = ErrorMapper.fromException(error);

    return ColoredBox(
      color: cs.surface,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.error_outline, color: cs.error),
              SizedBox(height: context.spaceM),
              Text(
                appError.userMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurface, fontSize: context.fontM),
              ),
              if (onRetry != null) ...<Widget>[
                SizedBox(height: context.spaceM),
                TextButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
