import 'package:daylex/features/access/desktop_credentials.dart';
import 'package:daylex/features/access/service_status.dart';
import 'package:daylex/l10n/app_localizations_it.dart';
import 'package:daylex/l10n/l10n.dart';
import 'package:daylex/ui/access/access_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Status extends ServiceStatus {
  _Status() : super(AppLocalizationsIt());
  int retries = 0;

  void publish(bool blocked) {
    maintenance = blocked;
    message = blocked ? 'Rientro mercoledì alle 10:00.' : '';
    checkedAt = DateTime(2026, 11, 24);
    notifyListeners();
  }

  @override
  Future<void> check() async {
    retries++;
  }
}

void main() {
  late _Status status;
  setUp(() {
    DesktopCredentials.instance
      ..ready = true
      ..validated = true
      ..disclosed = true;
    status = _Status();
  });
  tearDown(() {
    status.dispose();
    DesktopCredentials.instance
      ..ready = false
      ..validated = false
      ..disclosed = false;
  });

  Widget app(Widget home) => ProviderScope(
    overrides: [
      desktopAccessEnabledProvider.overrideWithValue(true),
      serviceStatusProvider.overrideWithValue(status),
    ],
    child: MaterialApp(
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => AccessGate(child: child!),
      home: home,
    ),
  );

  testWidgets('maintenance blocks the workspace and restores the same draft', (
    tester,
  ) async {
    status.publish(false);
    final draft = TextEditingController(text: 'Bozza privata');
    addTearDown(draft.dispose);
    await tester.pumpWidget(app(Scaffold(body: TextField(controller: draft))));
    await tester.tap(find.byType(TextField));
    status.publish(true);
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Rientro mercoledì alle 10:00.'), findsOneWidget);
    expect(
      FocusManager.instance.primaryFocus?.context?.widget,
      isNot(isA<EditableText>()),
    );
    await tester.tap(find.text(AppLocalizationsIt().serviceRetry));
    expect(status.retries, 1);
    status.publish(false);
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    expect(draft.text, 'Bozza privata');
  });

  testWidgets('workspace stays blocked until the first authenticated status', (
    tester,
  ) async {
    await tester.pumpWidget(app(const Scaffold(body: Text('workspace'))));
    expect(find.text('workspace'), findsNothing);
    status.publish(false);
    await tester.pump();
    expect(find.text('workspace'), findsOneWidget);
  });

  testWidgets(
    'maintenance also covers an open dialog and preserves its route',
    (tester) async {
      status.publish(false);
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      const AlertDialog(content: Text('Documento aperto')),
                ),
                child: const Text('Apri'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Apri'));
      await tester.pumpAndSettle();
      expect(find.text('Documento aperto'), findsOneWidget);
      status.publish(true);
      await tester.pump();
      expect(find.text('Documento aperto'), findsNothing);
      status.publish(false);
      await tester.pump();
      expect(find.text('Documento aperto'), findsOneWidget);
    },
  );
}
