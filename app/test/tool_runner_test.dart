import 'package:flutter/widgets.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart'
    hide AgentRequest;
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/features/agent/approvals.dart';
import 'package:paper_agent/features/agent/chat_cards.dart';
import 'package:paper_agent/features/agent/domain/agent_protocol.dart';
import 'package:paper_agent/features/agent/domain/document_tools.dart';
import 'package:paper_agent/features/agent/session_state.dart';
import 'package:paper_agent/features/agent/tool_runner.dart';
import 'package:paper_agent/features/agent/turn_tracker.dart';
import 'package:paper_agent/features/document/render/page_images.dart';
import 'package:paper_agent/l10n/l10n.dart';

import 'agent_test.dart' show FakeHost;
import 'demo_fixture.dart';

class Surface implements ToolSurface {
  @override
  final chat = ChatMessagesController();
  @override
  bool live = true;
  @override
  final l10n = lookupAppLocalizations(const Locale('it'));
  final results = <ToolResult>[];
  @override
  void phase(AgentPhase phase, String activity) {}
  @override
  void log(String kind, String summary, [Object? payload]) {}
  @override
  void show(String kind, Map<String, dynamic> props) {}
  @override
  void reveal(String documentId, int page) {}
  @override
  Future<void> report(AgentToolCall call, ToolResult result) async {
    results.add(result);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('manual edits after admission stop an obsolete mutation', () async {
    final surface = Surface();
    addTearDown(surface.chat.dispose);
    final host = FakeHost(buildQ3Proposal());
    final clock = ChatClock();
    final runner = ToolRunner(
      surface,
      clock,
      host,
      RunningTurn('t', 'modifica'),
      Approvals('s', surface.chat, clock, (_, _) {}),
      SnapshotStore(),
    );
    host.activeDocument = host.activeDocument!.copyWith(
      metadata: host.activeDocument!.metadata.copyWith(
        title: 'Titolo modificato manualmente',
      ),
    );
    await runner.run(
      const AgentToolCall(
        id: 'a',
        name: 'insert_block',
        arguments: {
          'page': 1,
          'block': 1,
          'content': {'type': 'paragraph', 'text': 'Testo da non applicare'},
        },
      ),
    );
    expect(surface.results.single.ok, isFalse);
    expect(host.labels, isEmpty);
    expect(
      host.activeDocument!.metadata.title,
      'Titolo modificato manualmente',
    );
  });
}
