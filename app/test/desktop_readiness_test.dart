import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/core/theme/app_theme.dart';
import 'package:paper_agent/l10n/l10n.dart';
import 'package:paper_agent/ui/access/access_gate.dart';
import 'package:paper_agent/ui/settings/settings_view.dart';
import 'package:paper_agent/ui/shell/app_shell.dart';

import 'test_app.dart';

void main() {
  for (final size in [
    const Size(1440, 900),
    const Size(800, 700),
    const Size(440, 780),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('access layout ${size.width} dark=$dark', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await loadAppFonts();
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              locale: const Locale('it'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: const AccessForm(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.widget<TextField>(find.byType(TextField)).obscureText,
          isTrue,
        );
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/readiness/access-${size.width.toInt()}-${dark ? 'dark' : 'light'}.png',
          ),
        );
      });
    }
  }
  for (final screen in [
    ('settings', const SettingsView()),
    ('workspace', const AppShell()),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('${screen.$1} at 800px with text scale $scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(800, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await loadAppFonts();
        await tester.pumpWidget(
          ProviderScope(
            child: testApp(
              MediaQuery(
                data: MediaQueryData(
                  size: const Size(800, 700),
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                ),
                child: Scaffold(body: screen.$2),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/readiness/${screen.$1}-${scale.toInt()}.png',
          ),
        );
      });
    }
  }
}
