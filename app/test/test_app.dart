import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:paper_agent/core/theme/app_theme.dart';
import 'package:paper_agent/l10n/l10n.dart';

/// The Italian strings, as the app starts.
final itL10n = lookupAppLocalizations(const Locale('it'));

Future<void> loadAppFonts() async {
  final font = FontLoader('Inter');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    font.addFont(rootBundle.load('assets/fonts/Inter-$weight.ttf'));
  }
  await font.load();
  final icons = FontLoader('packages/lucide_icons_flutter/Lucide')
    ..addFont(
      rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
    );
  await icons.load();
}

/// A bare app around [home] with the app's theme and its strings (Italian, as it starts), for widget tests.
Widget testApp(Widget home, {Locale locale = const Locale('it')}) =>
    MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
