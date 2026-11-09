import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/features/agent/agent_controller.dart';
import 'package:paper_agent/features/agent/data/mock_agent_client.dart';
import 'package:paper_agent/features/agent/domain/agent_protocol.dart';
import 'package:paper_agent/features/workspace/workspace_state.dart';
import 'package:paper_agent/ui/chat/new_chat_view.dart';

import 'test_app.dart';

import 'demo_fixture.dart';

void main() {
  group('a new chat starts clean', () {
    testWidgets('no document of the project is attached unless the lawyer picks one', (tester) async {
      await tester.pumpWidget(ProviderScope(overrides: demoOverrides, child: testApp(const Scaffold(body: NewChatView()))));
      await tester.pump();

      final container = ProviderScope.containerOf(tester.element(find.byType(NewChatView)));
      final titles = container.read(workspaceProvider).documents.values.map((d) => d.title);
      expect(titles, isNotEmpty, reason: 'the project has documents a new chat could inherit');
      expect(find.text(itL10n.chatNewHintNoDocument), findsOneWidget);
      for (final title in titles) {
        expect(find.text(itL10n.chatNewHintDocument(title)), findsNothing);
      }
    });
    testWidgets('what a new chat sends carries no document and no turn of another chat', (tester) async {
      final client = _Recorder();
      await tester.pumpWidget(ProviderScope(
        overrides: [agentClientProvider.overrideWithValue(client)],
        child: testApp(const Scaffold(body: NewChatView())),
      ));
      await tester.pump();

      Future<void> ask(String prompt) async {
        await tester.enterText(find.byType(TextField), prompt);
        await tester.pump(); // enterText does not rebuild: the send button is still disabled
        await tester.tap(find.byTooltip(itL10n.composerSend));
        await tester.pumpAndSettle();
      }

      await ask('Chi è il cliente e quanto ci deve?');
      await ask('Riassumi i fatti della pratica.');

      expect(client.requests, hasLength(2));
      expect(client.requests.map((r) => r.sessionId).toSet(), hasLength(2), reason: 'each new chat is its own session');
      for (final r in client.requests) {
        expect(r.document, isNull, reason: 'a document of an earlier chat would bring its facts into this one');
        expect(r.history, isEmpty, reason: "the turns of the earlier chat are not this chat's history");
      }
    });
  });
}

/// The mock agent, remembering every request it was sent.
class _Recorder extends MockAgentClient {
  _Recorder() : super(speed: 0);

  final requests = <AgentRequest>[];

  @override
  Stream<AgentEvent> run(AgentRequest request) {
    requests.add(request);
    return super.run(request);
  }
}
