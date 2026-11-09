import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/features/agent/agent_controller.dart';
import 'package:paper_agent/features/agent/data/mock_agent_client.dart';
import 'package:paper_agent/features/agent/domain/agent_protocol.dart';

import 'demo_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a new access key reaches the next run; the run already going keeps answering with its own key', () async {
    final clients = [_Server(asksTool: true), _Server(asksTool: false)];
    var built = 0;
    final container = ProviderContainer(
      overrides: [...demoOverrides, agentClientProvider.overrideWith((ref) => clients[built++])],
    );
    addTearDown(container.dispose);
    final agent = container.read(agentProvider.notifier);
    const id = demoPolishThreadId;

    final running = agent.send(id, 'Leggi il documento.');
    await clients[0].called.future;
    container.invalidate(agentClientProvider); // what the settings do once the new key is saved
    clients[0].proceed.complete();
    await running;

    expect(
      container.read(sessionProvider(id)).phase,
      isNot(AgentPhase.error),
      reason: container.read(sessionProvider(id)).error,
    );
    expect(clients[0].results, ['c1'], reason: 'the server keeps the run under the key that started it');
    expect(clients[1].results, isEmpty);

    await agent.send(id, 'E ora?');
    expect(clients[1].runs, 1, reason: 'the next run goes with the new key');
  });
}

/// The server as one key sees it: with [asksTool], it asks for one tool once the test lets it, waits for the
/// result, and finishes; without, it just finishes.
class _Server extends MockAgentClient {
  _Server({required this.asksTool}) : super(speed: 0);

  final bool asksTool;
  final called = Completer<void>();
  final proceed = Completer<void>();
  final results = <String>[];
  var runs = 0;

  @override
  Stream<AgentEvent> run(AgentRequest request) async* {
    runs++;
    if (!asksTool) {
      yield const AgentDone();
      return;
    }
    called.complete();
    await proceed.future;
    yield const AgentToolCall(id: 'c1', name: 'read_document', arguments: {});
    // A result sent elsewhere never arrives: the real server would wait for it until its own limit.
    for (var i = 0; results.isEmpty && i < 200; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    yield const AgentDone();
  }

  @override
  Future<void> submitToolResult(String sessionId, String callId, Map<String, dynamic> result) async =>
      results.add(callId);
}
