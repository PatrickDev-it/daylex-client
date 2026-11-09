import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:paper_agent/features/agent/presentation/ui_components.dart';
import 'package:paper_agent/ui/chat/components/agent_markdown.dart';
import 'package:paper_agent/ui/common/copy_feedback.dart';
import 'package:paper_agent/ui/chat/components/component_registry.dart';
import 'package:paper_agent/features/agent/attachment_files.dart';

import 'package:paper_agent/features/agent/data/http_agent_client.dart';
import 'package:paper_agent/features/agent/domain/document_tools.dart';
import 'package:paper_agent/features/document/service/document_service.dart';
import 'package:paper_agent/features/storage/local_store.dart';
import 'package:paper_agent/l10n/app_localizations.dart';

import 'test_app.dart';

void main() {
  group('C1 mimeFor', () {
    test('a name with no dot has no extension', () {
      expect(mimeFor('pdf'), 'application/octet-stream');
      expect(mimeFor('relazione'), 'application/octet-stream');
      expect(mimeFor('PDF'), 'application/octet-stream');
    });
    test('the last extension decides, case-insensitive', () {
      expect(mimeFor('a.PDF'), 'application/pdf');
      expect(mimeFor('a.pdf.p7m'), 'application/pkcs7-mime');
      expect(mimeFor('a.xyz'), 'application/octet-stream');
    });
  });

  group('C2 cards with wrong-typed scalar props', () {
    // Every scalar prop any card reads; each pass fills all of them with one wrong type.
    const keys = [
      'path', 'pages', 'status', 'threadId', 'id', 'tool', 'title', 'description', 'turnId', 'documentId', 'snapshot',
      'page', 'caption', 'added', 'before', 'after', 'pageBefore', 'wordsBefore', 'wordsAfter', 'layoutBefore',
      'layoutAfter', 'unit', 'detail', 'ms', 'running', 'seconds', 'tools', 'kind', 'label', 'value',
    ];
    final wrongs = <String, Object?>{'number': 42, 'text': 'x', 'flag': true, 'null': null, 'map': {'a': 1}};
    for (final kind in componentRegistry.keys) {
      for (final w in wrongs.entries) {
        testWidgets('$kind renders with every scalar prop as ${w.key}', (tester) async {
          // Lists the card also reads stay lists of wrong things: keys above are scalars only.
          final props = {for (final k in keys) k: w.value};
          if (!UiComponents.all.contains(kind)) fail('unknown $kind');
          await tester.pumpWidget(
            ProviderScope(
              child: testApp(
                Scaffold(
                  body: SingleChildScrollView(child: Builder(builder: (c) => buildComponent(c, kind, props)!)),
                ),
              ),
            ),
          );
          // A test-font overflow is layout, not the prop reads under test: only a failed cast or lookup counts.
          expect(tester.takeException(), isNot(anyOf(isA<TypeError>(), isA<StateError>(), isA<NoSuchMethodError>())));
        });
      }
    }
  });

  testWidgets('C3 the code block shows "copied" for the same time as every copy button', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(testApp(const Scaffold(body: CodeBlock(code: 'x = 1', language: 'python'))));
    await tester.tap(find.byIcon(LucideIcons.copy));
    await tester.pump();
    expect(find.byIcon(LucideIcons.check), findsOneWidget);
    await tester.pump(copiedFor + const Duration(milliseconds: 10));
    expect(find.byIcon(LucideIcons.check), findsNothing);
  });

  group('C4 user-facing text is worded by the ARB, in the app language', () {
    final it = lookupAppLocalizations(const Locale('it'));
    final en = lookupAppLocalizations(const Locale('en'));

    test('tool titles: Italian as before, English on request', () {
      expect(describeToolCall(it, ToolNames.deletePage, {'page': 3}), 'Elimino la pagina · pagina 3');
      expect(describeToolCall(en, ToolNames.deletePage, {'page': 3}), 'Deleting the page · page 3');
      expect(describeToolCall(it, ToolNames.createDocument, {}), 'Creo "documento"');
      expect(describeToolCall(en, ToolNames.createDocument, {}), 'Creating "document"');
    });

    test('store notices are data, worded when shown', () {
      const notice = IndexRecoveredNotice(documents: 2, chats: 1, project: 'Lavoro recuperato');
      expect(
        notice.text(it),
        "L'indice del lavoro salvato era illeggibile: ho recuperato 2 documenti e 1 conversazioni "
        'nel progetto «Lavoro recuperato».',
      );
      expect(notice.text(en), contains('recovered 2 documents and 1 conversations'));
      expect(const SaveFailedNotice('disk full').text(en), contains('disk full'));
    });

    test('connection problems and failures follow the language', () {
      final server = Uri.parse('https://example.org');
      expect(connectionProblem(it, TimeoutException('x'), server), 'Il servizio non ha risposto in tempo: riprova tra un momento.');
      expect(connectionProblem(en, TimeoutException('x'), server), 'The server did not answer in time: try again in a moment.');
      expect(describeFailure(en, const SocketException('x')), 'Cannot reach the agent server.');
      expect(describeFailure(it, const SocketException('x')), "Non riesco a raggiungere il servizio dell'agente.");
    });

    test('a refused operation tells the model in Italian and the lawyer in their language', () {
      const e = DocumentOperationException.lastPage();
      expect(e.message, 'Un documento deve avere almeno una pagina.');
      expect(e.localized(en), 'A document must have at least one page.');
      final page = DocumentOperationException.noPage(5, 3);
      expect(page.message, 'La pagina 5 non esiste (il documento ne ha 3).');
      expect(page.localized(en), 'Page 5 does not exist (the document has 3).');
    });
  });
}

