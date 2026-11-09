import 'dart:async';

import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart'
    show ChatMessage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/features/agent/agent_controller.dart';
import 'package:paper_agent/features/agent/chat_archive.dart';
import 'package:paper_agent/features/agent/chat_cards.dart';
import 'package:paper_agent/features/agent/data/mock_agent_client.dart';
import 'package:paper_agent/features/agent/domain/agent_protocol.dart';
import 'package:paper_agent/features/agent/presentation/conversation_presentation.dart';
import 'package:paper_agent/features/agent/presentation/ui_components.dart';
import 'package:paper_agent/features/workspace/workspace_state.dart';

Map<String, dynamic> data(ChatMessage message) =>
    (message.customProperties!['resultData'] as Map).cast<String, dynamic>();

Future<void> until(bool Function() condition) async {
  for (var i = 0; i < 200 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(
    condition(),
    isTrue,
    reason: 'the observed event must arrive before completion',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Controlled client;
  late ProviderContainer container;
  late AgentController agent;
  late String first;
  late String second;
  setUp(() {
    client = _Controlled();
    container = ProviderContainer(
      overrides: [agentClientProvider.overrideWithValue(client)],
    );
    agent = container.read(agentProvider.notifier);
    final ws = container.read(workspaceProvider.notifier);
    final project = ws.createProject('Studio');
    first = ws.createThread(projectId: project.id, title: 'Pratica A').id;
    second = ws.createThread(projectId: project.id, title: 'Pratica B').id;
  });
  tearDown(() {
    container.dispose();
  });
  Iterable<ChatMessage> cards(String id, String kind) => agent
      .chatFor(id)
      .messages
      .where((m) => m.customProperties?['resultKind'] == kind);

  test('observed steps update one card before done and stay isolated by conversation', () async {
    final a = agent.send(first, 'Prepara la bozza');
    final b = agent.send(second, 'Verifica gli allegati');
    await until(() => client.streams.length == 2);
    client.emit(
      first,
      const AgentStatusEvent(
        'Scrivo la bozza',
        kind: 'writing',
        detail: '50 parole',
      ),
    );
    client.emit(
      second,
      const AgentStatusEvent('Leggo gli allegati', kind: 'attachments'),
    );
    await until(
      () =>
          (data(cards(first, UiComponents.progress).single)['steps'] as List)
              .length ==
          2,
    );
    client.emit(
      first,
      const AgentStatusEvent(
        'Scrivo la bozza',
        kind: 'writing',
        detail: '100 parole',
      ),
    );
    client.emit(
      first,
      const AgentStatusEvent(
        'internal reasoning',
        kind: 'thinking',
        quiet: true,
      ),
    );
    await until(
      () =>
          container.read(sessionProvider(first)).activityDetail == '100 parole',
    );
    final progress = data(cards(first, UiComponents.progress).single);
    expect(progress['running'], isTrue);
    expect(progress['steps'], hasLength(2));
    expect(progress.toString(), isNot(contains('internal reasoning')));
    expect(progress.toString(), isNot(contains('Leggo gli allegati')));
    expect(
      container.read(sessionProvider(second)).activity,
      'Leggo gli allegati',
    );
    await client.finish(first);
    await a;
    expect(
      data(cards(first, UiComponents.progress).single)['status'],
      CardStatus.done,
    );
    expect(
      data(cards(second, UiComponents.progress).single)['running'],
      isTrue,
    );
    await client.finish(second);
    await b;
  });

  test(
    'creation and page changes are visible before the final response',
    () async {
      final running = agent.send(first, 'Crea e correggi una bozza');
      await until(() => client.streams.containsKey(first));
      client.emit(
        first,
        const AgentToolCall(
          id: 'create',
          name: 'create_document',
          arguments: {
            'title': 'Bozza',
            'pages': [
              {
                'title': 'Premessa',
                'blocks': [
                  {'type': 'paragraph', 'text': 'Testo iniziale'},
                ],
              },
            ],
          },
        ),
      );
      await until(() => client.toolResults.length == 1);
      expect(cards(first, UiComponents.documentCard), hasLength(1));
      client.emit(
        first,
        const AgentToolCall(
          id: 'edit',
          name: 'update_page',
          arguments: {'page': 1, 'title': 'Premessa aggiornata'},
        ),
      );
      await until(() => client.toolResults.length == 2);
      expect(client.toolResults.last['ok'], isTrue);
      final change = cards(first, UiComponents.pdfDiff).single;
      expect(ConversationPresentation.visible(change), isTrue);
      expect(data(change)['before'], isNot(data(change)['after']));
      expect(
        data(cards(first, UiComponents.progress).single)['running'],
        isTrue,
      );
      await client.finish(first);
      await running;
    },
  );

  test('cancel closes partial text and progress; late events cannot contaminate a new turn', () async {
    final running = agent.send(first, 'Prepara una bozza');
    await until(() => client.streams.containsKey(first));
    client.emit(first, const AgentTextDelta('Testo parziale'));
    await until(
      () =>
          agent.chatFor(first).messages.any((m) => m.text == 'Testo parziale'),
    );
    agent.cancel(first);
    await running;
    expect(
      data(cards(first, UiComponents.progress).single)['status'],
      CardStatus.rejected,
    );
    expect(
      agent
          .chatFor(first)
          .messages
          .firstWhere((m) => m.text == 'Testo parziale')
          .customProperties?[ChatProps.streaming],
      isFalse,
    );
    client.emit(
      first,
      const AgentStatusEvent('Evento tardivo', kind: 'writing'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      data(cards(first, UiComponents.progress).single).toString(),
      isNot(contains('Evento tardivo')),
    );
    await client.streams[first]!.close();
  });

  test('stream failure leaves progress failed and no active turn', () async {
    final running = agent.send(first, 'Verifica');
    await until(() => client.streams.containsKey(first));
    client.streams[first]!.addError(StateError('socket closed'));
    await running;
    expect(
      data(cards(first, UiComponents.progress).single)['status'],
      CardStatus.error,
    );
    expect(container.read(sessionProvider(first)).phase, AgentPhase.error);
    expect(
      container.read(sessionProvider(first)).error,
      isNot(contains('socket closed')),
    );
    await client.streams[first]!.close();
  });

  test(
    'an unfinished receipt after restart is unknown, never falsely unapplied',
    () {
      final live = ChatCards.toolCall(
        't',
        DateTime.now(),
        const AgentToolCall(
          id: 'c',
          name: 'update_page',
          arguments: {'page': 1},
        ),
        'Aggiorno la pagina',
        CardStatus.running,
      );
      final restored = ChatArchive.messageFromJson(
        ChatArchive.messageToJson(live)!,
      );
      expect(data(restored)['status'], CardStatus.interrupted);
      expect(data(live)['status'], CardStatus.running);
    },
  );

  test('restored running progress becomes interrupted without mutating the live card', () {
    final live = ChatCards.progress(
      'p',
      DateTime.now(),
      [
        {'label': 'Scrivo'},
      ],
      running: true,
      seconds: 8,
    );
    final restored = ChatArchive.messageFromJson(
      ChatArchive.messageToJson(live)!,
    );
    expect(data(live)['running'], isTrue);
    expect(data(restored)['running'], isFalse);
    expect(data(restored)['status'], CardStatus.rejected);
    final old = ChatArchive.messageFromJson({'props': live.customProperties});
    expect(data(old)['status'], CardStatus.rejected);
  });
}

class _Controlled extends MockAgentClient {
  final streams = <String, StreamController<AgentEvent>>{};
  @override
  Stream<AgentEvent> run(AgentRequest request) {
    final controller = StreamController<AgentEvent>();
    streams[request.sessionId] = controller;
    return controller.stream;
  }

  void emit(String id, AgentEvent event) => streams[id]!.add(event);
  Future<void> finish(String id) async {
    emit(id, const AgentDone());
    await streams[id]!.close();
  }
}
