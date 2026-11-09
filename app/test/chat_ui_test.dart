import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/features/agent/agent_controller.dart';
import 'package:paper_agent/features/agent/data/mock_agent_client.dart';
import 'package:paper_agent/features/agent/domain/agent_protocol.dart';
import 'package:paper_agent/features/agent/domain/document_tools.dart';
import 'package:paper_agent/features/agent/presentation/ui_components.dart';
import 'package:paper_agent/features/document/model/document.dart';
import 'package:paper_agent/features/document/model/operations.dart';
import 'package:paper_agent/features/document/service/document_diff.dart';
import 'package:paper_agent/features/document/service/document_service.dart';
import 'package:paper_agent/features/workspace/chat_thread.dart';
import 'package:paper_agent/features/workspace/workspace_state.dart';
import 'package:paper_agent/ui/chat/components/agent_markdown.dart';

import 'demo_fixture.dart';
import 'test_app.dart';

const demoDocumentId = demoProposalDocumentId;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('document diff', () {
    final before = buildQ3Proposal();

    test('reports only the pages that changed', () {
      final after = const DocumentService().applyAll(before, [
        UpdatePage(2, layout: PageLayout.premium),
        DeletePage(5),
      ]);
      final changes = comparePages(before, after);
      expect(changes.map((c) => c.kind), [PageChangeKind.edited, PageChangeKind.removed]);
      expect(changes.first.afterIndex, 2);
      expect(changes.first.layoutChanged, isTrue);
      expect(changes.last.beforeIndex, 5);
    });

    test('identical documents have no changes', () {
      expect(comparePages(before, before), isEmpty);
    });

    test('line diff keeps common lines and marks the rest', () {
      final lines = diffLines(['a', 'b', 'c'], ['a', 'x', 'c']);
      expect(lines.map((l) => l.op), [DiffOp.same, DiffOp.removed, DiffOp.added, DiffOp.same]);
    });
  });

  group('presenter', () {
    final before = buildQ3Proposal();
    final after = const DocumentService().applyAll(before, [UpdatePage(2, layout: PageLayout.premium)]);
    String snap(PaperDocument d) => '${d.id}@${d.metadata.updatedAt.microsecondsSinceEpoch}';

    test('a page edit becomes a pdf_diff of that page', () {
      final components = presentToolResult(
        call: const AgentToolCall(id: 'c', name: 'update_page', arguments: {'page': 3}),
        result: const ToolResult.ok('done', focusPage: 3),
        before: before,
        after: after,
        snapshot: snap,
      );
      expect(components.single.kind, UiComponents.pdfDiff);
      expect(components.single.props['page'], 3);
      expect(components.single.props['before'], snap(before));
      expect(components.single.props['after'], snap(after));
    });

    test('failed tools render nothing', () {
      final components = presentToolResult(
        call: const AgentToolCall(id: 'c', name: 'update_page', arguments: {}),
        result: const ToolResult.error('nope'),
        before: before,
        after: before,
        snapshot: snap,
      );
      expect(components, isEmpty);
    });

    test('summary lists changed pages with word counts', () {
      final summary = summarizeChanges(
        turnId: 't',
        before: before,
        after: after,
        snapshot: snap,
        elapsed: const Duration(seconds: 3),
        tools: 2,
      );
      final pages = summary['pages'] as List;
      expect(pages, hasLength(1));
      expect((pages.single as Map)['page'], 3);
      expect(summary['tools'], 2);
    });
  });

  group('markdown segments', () {
    test('splits text, math and fences', () {
      final segments = parseSegments('Intro\n\n\$\$x^2\$\$\n\n```json\n{"a": 1}\n```\n\nOutro');
      expect(segments.map((s) => s.runtimeType), [TextSegment, MathSegment, FenceSegment, TextSegment]);
      final fence = segments[2] as FenceSegment;
      expect(fence.info, 'json');
      expect(fence.body, '{"a": 1}');
      expect(fence.closed, isTrue);
    });

    test('an unclosed fence is still streaming', () {
      final fence = parseSegments('```ui:pdf_page\n{"page": 2').single as FenceSegment;
      expect(fence.info, 'ui:pdf_page');
      expect(fence.closed, isFalse);
    });

    test('text splits into its finished blocks, never inside a list or an indented block', () {
      final texts = [
        for (final s in parseSegments(
          '# Titolo\n\nPrimo paragrafo\nriga due.\n\n- uno\n\n- due\n\n  segue il due\n\nFine',
        ))
          (s as TextSegment).text.trim(),
      ];
      expect(texts, ['# Titolo', 'Primo paragrafo\nriga due.', '- uno\n\n- due\n\n  segue il due', 'Fine']);
    });

    test('text with a reference definition stays whole: a reference resolves across the whole text', () {
      expect(parseSegments('Vedi [Cass.][1].\n\nAltro.\n\n[1]: https://a.it'), hasLength(1));
      expect(parseSegments('Vedi la nota[^1].\n\n[^1]: Cass. 1234/2026.'), hasLength(1));
    });

    testWidgets('a streamed reply re-renders only its last block, not the ones already finished', (tester) async {
      const finished =
          '## Sulla eccezione\n\nIl ricorrente sostiene che il decreto sia stato emesso da giudice incompetente.\n\n';
      Future<void> show(String tail) => tester.pumpWidget(
        testApp(Scaffold(body: SingleChildScrollView(child: AgentMarkdown('$finished$tail', streaming: true)))),
      );
      await show('Il termine');
      final heading = tester.widget<RichText>(find.byType(RichText).first);
      await show('Il termine per opporsi');
      expect(
        identical(tester.widget<RichText>(find.byType(RichText).first), heading),
        isTrue,
        reason: 'the heading is not parsed again for every piece of the paragraph after it',
      );
      expect(find.textContaining('Il termine per opporsi', findRichText: true), findsOneWidget);
    });

    test(r'dollar signs inside fences are not math', () {
      final segments = parseSegments('```\nprice: \$\$5\$\$\n```');
      expect(segments.single, isA<FenceSegment>());
    });
  });

  group('agent controller', () {
    late ProviderContainer container;
    late AgentController agent;

    setUp(() {
      container = ProviderContainer(
        overrides: [...demoOverrides, agentClientProvider.overrideWithValue(MockAgentClient(speed: 0))],
      );
      agent = container.read(agentProvider.notifier);
    });

    tearDown(() => container.dispose());

    List<String?> kinds(String threadId) => [
      for (final m in agent.chatFor(threadId).messages) m.customProperties?['resultKind'] as String?,
    ];

    test('the demo conversation renders its tool call and document card', () {
      seedDemoChat(container);
      expect(kinds(demoProposalThreadId), containsAll([UiComponents.toolCall, UiComponents.documentCard]));
    });

    test('an edit turn renders a diff, a summary and can be undone', () async {
      const id = demoPolishThreadId;
      final original = container.read(workspaceProvider).documents[demoDocumentId]!;

      await agent.send(id, 'Make page 3 more premium and reduce the amount of text');

      expect(kinds(id), containsAll([UiComponents.toolCall, UiComponents.pdfDiff, UiComponents.changeSummary]));
      final session = container.read(sessionProvider(id));
      expect(session.isRunning, isFalse);
      final turn = session.turns.last;
      expect(turn.changes.keys, [demoDocumentId]);
      expect(container.read(workspaceProvider).documents[demoDocumentId]!.pages[2].layout, PageLayout.premium);
      expect(container.read(workspaceProvider).activeThread!.tabs, contains(PanelTab.preview(demoDocumentId)));

      agent.undoTurn(id, turn.id, demoDocumentId);
      expect(container.read(workspaceProvider).documents[demoDocumentId]!.pages[2].layout, original.pages[2].layout);
    });

    test('deleting a page waits for approval', () async {
      const id = demoPolishThreadId;
      final pages = container.read(workspaceProvider).documents[demoDocumentId]!.pages.length;

      final run = agent.send(id, 'Delete page 2');
      while (container.read(sessionProvider(id)).phase != AgentPhase.waiting) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(container.read(workspaceProvider).documents[demoDocumentId]!.pages, hasLength(pages));

      final approval = agent
          .chatFor(id)
          .messages
          .lastWhere((m) => m.customProperties?['resultKind'] == UiComponents.approval);
      agent.resolveApproval(id, approval.customProperties!['id'] as String, approved: true);
      await run;

      expect(container.read(workspaceProvider).documents[demoDocumentId]!.pages, hasLength(pages - 1));
    });

    test('rejecting leaves the document alone', () async {
      const id = demoPolishThreadId;
      final pages = container.read(workspaceProvider).documents[demoDocumentId]!.pages.length;

      final run = agent.send(id, 'Delete page 2');
      while (container.read(sessionProvider(id)).phase != AgentPhase.waiting) {
        await Future<void>.delayed(Duration.zero);
      }
      final approval = agent
          .chatFor(id)
          .messages
          .lastWhere((m) => m.customProperties?['resultKind'] == UiComponents.approval);
      agent.resolveApproval(id, approval.customProperties!['id'] as String, approved: false);
      await run;

      expect(container.read(workspaceProvider).documents[demoDocumentId]!.pages, hasLength(pages));
      final client = container.read(agentClientProvider) as MockAgentClient;
      expect(client.toolResults.last, containsPair('ok', false));
    });

    testWidgets('an approval nobody answers lapses before the server gives up, and a late yes runs nothing', (
      tester,
    ) async {
      const id = demoPolishThreadId;
      final pages = container.read(workspaceProvider).documents[demoDocumentId]!.pages.length;

      final run = agent.send(id, 'Delete page 2');
      while (container.read(sessionProvider(id)).phase != AgentPhase.waiting) {
        await tester.pump();
      }
      await tester.pump(AgentController.approvalWindow);
      for (var i = 0; i < 20; i++) {
        await tester.pump();
      }
      await run;

      final approval = agent
          .chatFor(id)
          .messages
          .lastWhere((m) => m.customProperties?['resultKind'] == UiComponents.approval);
      expect((approval.customProperties!['resultData'] as Map)['status'], 'expired');
      agent.resolveApproval(id, approval.customProperties!['id'] as String, approved: true);
      expect(container.read(workspaceProvider).documents[demoDocumentId]!.pages, hasLength(pages));
      final client = container.read(agentClientProvider) as MockAgentClient;
      expect(client.toolResults.last['summary'], contains('non ha risposto in tempo'));
    });

    test('a new chat from the draft gets its own thread', () async {
      final before = container.read(workspaceProvider).threads.length;
      await agent.startChat(projectId: demoProjectId, prompt: 'Write a team one-pager');
      final ws = container.read(workspaceProvider);
      expect(ws.threads.length, before + 1);
      expect(ws.activeThread!.title, 'Write a team one-pager');
      expect(ws.activeThread!.documentId, isNotNull);
    });
  });

  test('protocol exposes approval in the tool schema', () {
    expect(toolSpec('delete_page')!.toJson()['requiresApproval'], isTrue);
    expect(toolSpec('read_document')!.mutates, isFalse);
    expect(const AgentUiEvent('chart', {'title': 'x'}).props['title'], 'x');
  });
}
