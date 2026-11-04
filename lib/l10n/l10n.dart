import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// `context.l10n.play` instead of `AppLocalizations.of(context).play`
/// (#140).
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
