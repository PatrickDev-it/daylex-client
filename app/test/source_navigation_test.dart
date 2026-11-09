import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/core/theme/app_theme.dart';
import 'package:paper_agent/features/agent/agent_controller.dart';
import 'package:paper_agent/features/agent/chat_cards.dart';
import 'package:paper_agent/features/agent/data/http_agent_client.dart';
import 'package:paper_agent/features/agent/data/mock_agent_client.dart';
import 'package:paper_agent/features/agent/domain/agent_protocol.dart';
import 'package:paper_agent/features/agent/domain/source_reference.dart';
import 'package:paper_agent/features/workspace/chat_thread.dart';
import 'package:paper_agent/features/workspace/panel_tabs.dart';
import 'package:paper_agent/features/workspace/workspace_state.dart';
import 'package:paper_agent/ui/chat/chat_view.dart';
import 'package:paper_agent/ui/chat/components/agent_markdown.dart';
import 'package:paper_agent/ui/chat/components/source_link.dart';
import 'package:paper_agent/ui/panel/side_panel.dart';
import 'package:paper_agent/ui/panel/source_tab.dart';

import 'test_app.dart';

void main() {
  setUpAll(loadAppFonts);
  testWidgets('whole-document links do not claim a physical citation page', (
    tester,
  ) async {
    final uri = 'daylex-source://${'a' * 64}/1?name=istanza.docx&document=1';
    SourceReference? opened;
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: SourceCitationScope(
            onOpen: (source) => opened = source,
            child: AgentMarkdown('[Istanza]($uri)'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Istanza'));
    expect(opened?.wholeDocument, isTrue);
    expect(opened?.page, 1);
    expect(
      SourceReference.readable('[Istanza]($uri)', (r) => r.title),
      'Istanza',
    );
  });
  testWidgets('versioned source link keeps immutable identity on click', (
    tester,
  ) async {
    final sha = 'a' * 64;
    final uri = 'daylex-source://$sha/2?name=quietanza.pdf&last=2';
    SourceReference? opened;
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: SourceCitationScope(
            onOpen: (source) => opened = source,
            child: AgentMarkdown('[Etichetta abbreviata]($uri)'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Quietanza, pagina 2'));
    expect(opened?.sourceId, sha);
    expect(opened?.name, 'quietanza.pdf');
    final tab = PanelTab.source(
      opened!.name,
      sourcePage: opened!.page,
      sourceId: opened!.sourceId,
    );
    expect(PanelTab.fromJson(tab.toJson())?.sourceId, sha);
    expect(
      SourceReference.fromUri('https://example.com/2?name=quietanza.pdf'),
      isNull,
    );
    expect(
      SourceReference.fromUri('daylex-source://$sha/0?name=quietanza.pdf'),
      isNull,
    );
  });
  test('canonical references retain identity, page range and literal quote', () {
    const text =
        'La quietanza recita «Il pagamento e stato ricevuto» [quietanza_cliente.pdf, p. 2–3].';
    final match = SourceReference.expression.firstMatch(text)!;
    final source = SourceReference.fromMatch(
      match,
      before: text.substring(0, match.start),
    )!;
    expect(
      (source.name, source.page, source.lastPage, source.quote),
      ('quietanza_cliente.pdf', 2, 3, 'Il pagamento e stato ricevuto'),
    );
    expect(sourceLabel(itL10n, source), 'Quietanza cliente, pagine 2–3');
    expect(
      SourceReference.readable(text, (s) => sourceLabel(itL10n, s)),
      contains('Quietanza cliente, pagine 2–3'),
    );
    expect(SourceReference.expression.hasMatch('[art. 1218 c.c.]'), isFalse);
    expect(
      SourceReference.fromMatch(
        SourceReference.expression.firstMatch('[a.pdf, p. 0]')!,
      ),
      isNull,
    );
  });

  test('source tabs reuse identity and persist their target without changing the editable document', () {
    final now = DateTime.now();
    var thread = ChatThread(
      id: 's',
      projectId: 'p',
      title: 'Pratica',
      createdAt: now,
      updatedAt: now,
      documentId: 'atto',
      tabs: const [PanelTab.preview('atto')],
    );
    thread = thread.opening(
      const PanelTab.source('quietanza.pdf', sourcePage: 2),
    );
    thread = thread.opening(
      const PanelTab.source(
        'quietanza.pdf',
        sourcePage: 3,
        sourceQuote: 'saldo ricevuto',
      ),
    );
    final restored = ChatThread.fromJson(thread.toJson());
    expect(restored.documentId, 'atto');
    expect(restored.tabs.length, 2);
    expect(restored.activeTab!.sourcePage, 3);
    expect(restored.tabs.last.sourceQuote, 'saldo ricevuto');
  });

  testWidgets(
    'legacy chat citation opens the correct right panel page; repeat click reuses the source tab',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = _Sources();
      final boundary = GlobalKey();
      final container = ProviderContainer(
        overrides: [agentClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);
      final ws = container.read(workspaceProvider.notifier);
      final project = ws.createProject('Pratica Rossi');
      final thread = ws.createThread(projectId: project.id, title: 'Verifica');
      container
          .read(agentProvider.notifier)
          .chatFor(thread.id)
          .addMessage(
            ChatCards(ChatClock()).note(
              'La quietanza recita «Il pagamento e stato ricevuto» [quietanza.pdf, p. 2].\n\n'
              'Controlla anche [quietanza.pdf, p. 3].',
            ),
          );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: testApp(
            RepaintBoundary(
              key: boundary,
              child: Scaffold(
                body: Row(
                  children: [
                    Expanded(child: ChatView(thread: thread)),
                    const SizedBox(width: 470, child: SidePanel()),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final link = find.widgetWithText(TextButton, 'Quietanza, pagina 2');
      expect(link, findsOneWidget);
      expect(find.textContaining('[quietanza.pdf'), findsNothing);
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(client.calls.last, (thread.id, 'quietanza.pdf', 2));
      expect(find.byType(SourceTab), findsOneWidget);
      expect(
        find.text('Testo estratto · impaginazione originale non riprodotta'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Il pagamento e stato ricevuto'),
        findsWidgets,
      );
      if (const String.fromEnvironment('CAPTURE_UI').isNotEmpty) {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await render.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('build/ui-review/source-panel.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.widgetWithText(TextButton, 'Quietanza, pagina 3'));
      await tester.pumpAndSettle();
      expect(client.calls.last.$3, 3);
      expect(
        container
            .read(workspaceProvider)
            .activeThread!
            .tabs
            .where((t) => t.kind == PanelTabKind.source)
            .length,
        1,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'source actions can be activated by keyboard without opening external URLs',
    (tester) async {
      SourceReference? opened;
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: SourceCitationScope(
              onOpen: (s) => opened = s,
              child: const AgentMarkdown('Fonte: [quietanza.pdf, p. 4].'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect((opened?.name, opened?.page), ('quietanza.pdf', 4));
    },
  );

  testWidgets('unavailable sources explain the next step and can be retried', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        agentClientProvider.overrideWithValue(_Sources(missing: true)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: testApp(
          const Scaffold(
            body: SourceTab(threadId: 's', name: 'a.pdf', page: 1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Documento non disponibile'), findsOneWidget);
    expect(find.textContaining('allega nuovamente'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Riprova'), findsOneWidget);
  });

  test('source link contrast is legible in both themes', () {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
    }

    expect(
      contrast(AppTokens.light.sourceLink, Colors.white),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(AppTokens.dark.sourceLink, AppTokens.dark.panel),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('HTTP source reads authenticate metadata and bytes and encode names as query values', () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final paths = <String>[];
      final subscription = server.listen((request) async {
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer test-key',
        );
        expect(request.uri.queryParameters['name'], 'quietanza #1 & copia.pdf');
        paths.add(request.uri.path);
        if (request.uri.path.endsWith('/file')) {
          request.response.add(utf8.encode('%PDF-test'));
        } else {
          expect(request.uri.queryParameters['page'], '2');
          request.response.write(
            jsonEncode({
              'name': 'quietanza #1 & copia.pdf',
              'page': 2,
              'pages': 3,
              'text': 'Pagina seconda',
              'hasOriginal': true,
            }),
          );
        }
        await request.response.close();
      });
      final client = HttpAgentClient(
        AgentServerConfig(
          url: Uri.parse('http://127.0.0.1:${server.port}'),
          token: 'test-key',
        ),
        l10n: () => itL10n,
      );
      try {
        final source = await client.readSource(
          's',
          'quietanza #1 & copia.pdf',
          2,
        );
        expect(source!.page, 2);
        expect(utf8.decode(source.pdfBytes!), '%PDF-test');
        expect(paths, ['/v1/sessions/s/source', '/v1/sessions/s/source/file']);
      } finally {
        client.close();
        await subscription.cancel();
        await server.close(force: true);
      }
    }, _RealNetwork());
  });
}

class _RealNetwork extends HttpOverrides {}

class _Sources extends MockAgentClient {
  _Sources({this.missing = false});
  final bool missing;
  final calls = <(String, String, int)>[];
  @override
  Future<SourceDocument?> readSource(
    String sessionId,
    String name,
    int page, {
    bool includeOriginal = true,
  }) async {
    calls.add((sessionId, name, page));
    return missing
        ? null
        : SourceDocument(
            name: name,
            page: page,
            pages: 3,
            text:
                'Pagina $page. Il pagamento e stato ricevuto. La quietanza conferma il versamento del cliente.',
          );
  }
}
