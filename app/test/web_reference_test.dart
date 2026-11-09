import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/core/theme/app_theme.dart';
import 'package:paper_agent/ui/chat/components/agent_markdown.dart';
import 'package:paper_agent/ui/chat/components/legal_card_parts.dart';
import 'package:paper_agent/ui/chat/components/source_link.dart';
import 'package:paper_agent/ui/common/web_link.dart';

import 'test_app.dart';

void main() {
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final calls = <MethodCall>[];
  var successful = true;
  setUpAll(loadAppFonts);
  setUp(() {
    calls.clear();
    successful = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return successful;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test('agent links allow public web URLs only', () {
    for (final invalid in [
      'file:///C:/secret',
      'javascript:alert(1)',
      'mailto:test@example.org',
      'https://user:pass@example.org/',
      'http://127.0.0.1/',
      'http://[::1]/',
      'http://intranet/',
      'https://x.local/',
      'http://localhost./',
    ]) {
      expect(publicWebUri(invalid), isNull, reason: invalid);
    }
    expect(
      publicWebUri(
        'https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:legge:1990-08-07;241',
      ),
      isNotNull,
    );
  });

  testWidgets(
    'web references keep readable layouts across themes and text sizes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final dark in [false, true]) {
        for (final narrow in [false, true]) {
          tester.view.physicalSize = narrow
              ? const Size(375, 650)
              : const Size(900, 500);
          final boundary = GlobalKey();
          await tester.pumpWidget(
            testApp(
              Theme(
                data: dark ? AppTheme.dark() : AppTheme.light(),
                child: RepaintBoundary(
                  key: boundary,
                  child: Scaffold(
                    body: Builder(
                      builder: (context) => MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          textScaler: TextScaler.linear(narrow ? 2 : 1),
                          disableAnimations: true,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(24),
                          child: AgentMarkdown(
                            'La ricerca ha individuato un riferimento da consultare:\n\n'
                            '[Testo della legge sul procedimento amministrativo](https://www.normattiva.it/)\n\n'
                            'Il collegamento apre la fonte nel browser. L’estratto non sostituisce il testo della norma.',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(ReferenceLink), findsOneWidget);
          if (const String.fromEnvironment('CAPTURE_UI').isNotEmpty) {
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await render.toImage(pixelRatio: 1);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                'build/ui-review/web-${dark ? 'dark' : 'light'}-${narrow ? 'narrow' : 'wide'}.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        }
      }
    },
  );

  testWidgets(
    'web references open by click and keyboard, unsafe links stay text',
    (tester) async {
      await tester.pumpWidget(
        testApp(
          const Scaffold(
            body: AgentMarkdown(
              'Consulta [Fonte ufficiale](https://www.normattiva.it/) e [file](file:///C:/secret).',
            ),
          ),
        ),
      );
      expect(find.byType(ReferenceLink), findsOneWidget);
      await tester.tap(find.text('Fonte ufficiale'));
      await tester.pump();
      expect(calls.where((c) => c.method == 'launch'), hasLength(1));
      expect(calls.last.arguments['url'], 'https://www.normattiva.it/');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(calls.where((c) => c.method == 'launch'), hasLength(2));
      await tester.tap(find.text('file'));
      expect(calls.where((c) => c.method == 'launch'), hasLength(2));
    },
  );

  testWidgets(
    'failed browser launch gives feedback; legal cards share the guard',
    (tester) async {
      successful = false;
      await tester.pumpWidget(
        testApp(
          const Scaffold(
            body: Column(
              children: [
                AgentMarkdown('[Fonte](https://www.normattiva.it/)'),
                LegalOpenLink(url: 'file:///secret', label: 'Non disponibile'),
              ],
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Non disponibile'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Fonte'));
      await tester.pump();
      expect(find.text(itL10n.webLinkUnavailable), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
