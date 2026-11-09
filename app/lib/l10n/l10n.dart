import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/workspace/ui_state.dart';
import 'app_localizations.dart';

export 'app_localizations.dart';

/// Every text the app shows lives in `app_it.arb` (the template: Italian is the primary language) and
/// `app_en.arb`; `flutter gen-l10n` turns them into [AppLocalizations].
extension L10nOf on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// The same strings for code with no [BuildContext]: the agent controller, the workspace, toasts. It follows the
/// language the widgets show, so a message made here reads like the screen around it.
final l10nProvider = Provider<AppLocalizations>(
  (ref) => lookupAppLocalizations(ref.watch(uiProvider.select((s) => s.locale))),
);
