import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/features/agent/data/mock_agent_client.dart';
import 'package:paper_agent/features/agent/domain/agent_protocol.dart';
import 'package:paper_agent/features/agent/domain/document_tools.dart';
import 'package:paper_agent/features/document/model/document.dart';
import 'package:paper_agent/features/document/model/operations.dart';
import 'package:paper_agent/features/document/render/page_fit.dart';
import 'package:paper_agent/features/document/service/document_service.dart';
import 'package:paper_agent/features/workspace/workspace_state.dart';

import 'demo_fixture.dart';

/// In-memory [ToolHost] that applies operations directly.
class FakeHost implements ToolHost {
  FakeHost(this.activeDocument, {this.fitter});

  /// Pages are left as they are without one.
  final PageFitter? fitter;

  @override
  PaperDocument? activeDocument;
  final labels = <String>[];

  @override
  void applyOperations(List<DocOperation> ops, {required String label}) {
    activeDocument = const DocumentService().applyAll(activeDocument!, ops);
    labels.add(label);
  }

  @override
  void openNewDocument(PaperDocument doc) => activeDocument = doc;

  @override
  Future<String?> exportActiveDocument() async => 'C:/out.pdf';

  @override
  Future<FittedDocument> fitPages(PaperDocument doc) async =>
      await fitter?.fit(doc) ?? FittedDocument(doc);

  @override
  AgentAttachment? attachment(String name) => null;
}

/// Runs [prompt] through the mock agent and executes its tool calls.
Future<(List<AgentEvent>, List<ToolResult>)> runPrompt(
  FakeHost host,
  String prompt,
) async {
  final events = await MockAgentClient(speed: 0)
      .run(
        AgentRequest(
          sessionId: 's',
          prompt: prompt,
          document: host.activeDocument,
          currentPage: 1,
        ),
      )
      .toList();
  final executor = DocumentToolExecutor(host);
  final results = [
    for (final call in events.whereType<AgentToolCall>())
      await executor.execute(call),
  ];
  return (events, results);
}

void main() {
  test('every tool spec is a valid object schema', () {
    final names = documentToolSpecs.map((t) => t.name).toSet();
    expect(names.length, documentToolSpecs.length);
    for (final spec in documentToolSpecs) {
      expect(spec.parameters['type'], 'object', reason: spec.name);
    }
  });

  test('WhatsApp tools are exposed without entering the document executor', () {
    final names = appToolSpecs.map((t) => t.name).toSet();
    expect(
      names,
      containsAll({
        'whatsapp_status',
        'whatsapp_find_contact',
        'whatsapp_send_message',
      }),
    );
    expect(
      documentToolSpecs.map((t) => t.name),
      isNot(contains('whatsapp_send_message')),
    );
    expect(toolSpec('whatsapp_send_message')!.mutates, isFalse);
  });

  test('executor uses 1-based pages and reports errors', () async {
    final host = FakeHost(buildQ3Proposal());
    final executor = DocumentToolExecutor(host);

    final ok = await executor.execute(
      const AgentToolCall(
        id: '1',
        name: 'change_layout',
        arguments: {'page': 3, 'layout': 'premium'},
      ),
    );
    expect(ok.ok, isTrue);
    expect(ok.focusPage, 3);
    expect(host.activeDocument!.pages[2].layout, PageLayout.premium);

    final missing = await executor.execute(
      const AgentToolCall(
        id: '2',
        name: 'delete_page',
        arguments: {'page': 42},
      ),
    );
    expect(missing.ok, isFalse);
    expect(missing.summary, contains('non esiste'));

    final unknown = await executor.execute(
      const AgentToolCall(id: '3', name: 'nope', arguments: {}),
    );
    expect(unknown.ok, isFalse);
  });

  test(
    'arguments of the wrong type come back as a tool error, not a crash',
    () async {
      final host = FakeHost(buildQ3Proposal());
      final result = await DocumentToolExecutor(host).execute(
        const AgentToolCall(
          id: '1',
          name: 'create_document',
          arguments: {'title': 42},
        ),
      );
      expect(result.ok, isFalse);
      expect(result.summary, startsWith('Argomenti non validi'));
    },
  );

  test(
    'block tools address blocks by 1-based number and keep their id',
    () async {
      final host = FakeHost(buildQ3Proposal());
      final executor = DocumentToolExecutor(host);
      final original = host.activeDocument!.pages[1].blocks;

      final updated = await executor.execute(
        const AgentToolCall(
          id: '1',
          name: 'update_block',
          arguments: {
            'page': 2,
            'block': 1,
            'content': {'type': 'paragraph', 'text': 'Nuovo testo'},
          },
        ),
      );
      expect(updated.ok, isTrue, reason: updated.summary);
      final first = host.activeDocument!.pages[1].blocks.first;
      expect(first.id, original.first.id);
      expect(first.plainText, 'Nuovo testo');

      final removed = await executor.execute(
        const AgentToolCall(
          id: '2',
          name: 'remove_block',
          arguments: {'page': 2, 'block': 1},
        ),
      );
      expect(removed.ok, isTrue);
      expect(
        host.activeDocument!.pages[1].blocks,
        hasLength(original.length - 1),
      );

      final missing = await executor.execute(
        const AgentToolCall(
          id: '3',
          name: 'remove_block',
          arguments: {'page': 2, 'block': 99},
        ),
      );
      expect(missing.ok, isFalse);
      expect(missing.summary, contains('non esiste'));
    },
  );

  test(
    'a document-wide replace also covers title, subtitle and client',
    () async {
      final host = FakeHost(buildQ3Proposal());
      final client = host.activeDocument!.metadata.client;
      expect(client, isNotEmpty);

      final result = await DocumentToolExecutor(host).execute(
        AgentToolCall(
          id: '1',
          name: 'replace_text',
          arguments: {'find': client, 'replace': '[CLIENTE]'},
        ),
      );
      expect(result.ok, isTrue);
      expect(host.activeDocument!.metadata.client, contains('[CLIENTE]'));
      expect(
        const DocumentService().countOccurrences(host.activeDocument!, client),
        0,
      );
    },
  );

  test('mock agent: "make page 3 more premium and reduce text"', () async {
    final original = buildQ3Proposal();
    final host = FakeHost(original);
    final before = original.pages[2];

    final (events, results) = await runPrompt(
      host,
      'Make page 3 more premium and reduce the amount of text',
    );

    expect(events.last, isA<AgentDone>());
    expect(results, isNotEmpty);
    expect(results.every((r) => r.ok), isTrue);
    final after = host.activeDocument!.pages[2];
    expect(after.layout, PageLayout.premium);
    expect(after.wordCount, lessThan(before.wordCount));
    for (final i in [0, 1, 3, 4, 5]) {
      expect(host.activeDocument!.pages[i], same(original.pages[i]));
    }
  });

  test('mock agent understands Italian and creates documents', () async {
    final host = FakeHost(buildQ3Proposal());
    final (events, results) = await runPrompt(
      host,
      'Crea una proposta di 4 pagine per Globex',
    );

    expect(events.whereType<AgentTextDelta>(), isNotEmpty);
    expect(results.single.ok, isTrue);
    expect(host.activeDocument!.pages.length, 4);
    expect(host.activeDocument!.metadata.client, contains('Globex'));
  });

  test('mock agent replaces text', () async {
    final host = FakeHost(buildQ3Proposal());
    await runPrompt(host, 'Replace "Acme Corp" with "Globex"');
    expect(
      const DocumentService().countOccurrences(
        host.activeDocument!,
        'Acme Corp',
      ),
      0,
    );
  });

  test('workspace undo/redo restores snapshots', () {
    final container = ProviderContainer(overrides: demoOverrides);
    addTearDown(container.dispose);
    final ws = container.read(workspaceProvider.notifier);
    final original = container.read(activeDocumentProvider)!;

    ws.apply([const UpdateMetadata(title: 'Renamed')]);
    expect(container.read(activeDocumentProvider)!.title, 'Renamed');
    expect(ws.canUndo, isTrue);

    ws.undo();
    expect(container.read(activeDocumentProvider)!.title, original.title);
    expect(ws.canRedo, isTrue);

    ws.redo();
    expect(container.read(activeDocumentProvider)!.title, 'Renamed');

    expect(
      () => ws.apply([const DeletePage(99)]),
      throwsA(isA<DocumentOperationException>()),
    );
    expect(container.read(activeDocumentProvider)!.title, 'Renamed');
  });
}
