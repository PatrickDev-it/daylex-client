import 'dart:async';
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
import 'package:paper_agent/features/agent/data/mock_agent_client.dart';
import 'package:paper_agent/features/agent/domain/agent_protocol.dart';
import 'package:paper_agent/features/agent/presentation/ui_components.dart';
import 'package:paper_agent/features/workspace/workspace_state.dart';
import 'package:paper_agent/l10n/l10n.dart';
import 'package:paper_agent/ui/chat/chat_view.dart';

import 'test_app.dart';

const _capture = String.fromEnvironment('CAPTURE_UI');
const _answer =
    '**Il pagamento non è documentato in modo univoco.**\n\n'
    'La quietanza attesta il saldo; l’estratto contabile riporta la stessa fattura come insoluta. '
    'I documenti danno quindi versioni discordanti.\n\n'
    '**Da verificare:** acquisire la contabile del versamento prima di procedere.\n\n'
    'Fonti: [quietanza.pdf, p. 1] · [estratto.pdf, p. 1].';

void main() {
  setUpAll(() async {
    final font = FontLoader('Inter');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      font.addFont(rootBundle.load('assets/fonts/Inter-$weight.ttf'));
    }
    await font.load();
    final icons = FontLoader('packages/lucide_icons_flutter/Lucide')
      ..addFont(
        rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
      );
    await icons.load();
    final material = FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await material.load();
  });

  testWidgets(
    'one concise activity replaces raw compaction detail and then disappears',
    (tester) async {
      final client = _WaitingClient();
      final container = ProviderContainer(
        overrides: [agentClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);
      final workspace = container.read(workspaceProvider.notifier);
      final project = workspace.createProject('Pratica Rossi');
      final thread = workspace.createThread(
        projectId: project.id,
        title: 'Verifica allegati',
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: testApp(Scaffold(body: ChatView(thread: thread))),
        ),
      );
      final running = container
          .read(agentProvider.notifier)
          .send(thread.id, 'Verifica gli allegati.');
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Esamino la richiesta'), findsOneWidget);
      expect(find.textContaining('Compatto'), findsNothing);
      expect(find.textContaining('token interni'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      client.finish.complete();
      await tester.pumpAndSettle();
      await running;
      expect(find.text('Esamino la richiesta'), findsNothing);
      expect(
        find.textContaining('Occorre verificare il pagamento.'),
        findsWidgets,
      );
    },
  );

  test('source limitations persist once alongside observed progress', () async {
    final container = ProviderContainer(
      overrides: [agentClientProvider.overrideWithValue(_WarningClient())],
    );
    addTearDown(container.dispose);
    final workspace = container.read(workspaceProvider.notifier);
    final project = workspace.createProject('Pratica Rossi');
    final thread = workspace.createThread(
      projectId: project.id,
      title: 'Verifica allegati',
    );
    final agent = container.read(agentProvider.notifier);
    await agent.send(thread.id, 'Verifica gli allegati.');
    final messages = agent.chatFor(thread.id).messages;
    expect(
      messages.where((m) => m.text.contains('Un allegato non è stato letto.')),
      hasLength(1),
    );
    expect(
      messages.where(
        (m) => m.customProperties?['resultKind'] == UiComponents.progress,
      ),
      hasLength(1),
    );
  });

  for (final (name, size, dark, scale) in [
    ('desktop', const Size(1100, 850), false, 1.0),
    ('dark', const Size(1100, 850), true, 1.0),
    ('narrow', const Size(390, 844), false, 1.3),
    ('large-text', const Size(760, 720), false, 2.0),
  ]) {
    testWidgets('legal conversation stays focused and fits $name', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final workspace = container.read(workspaceProvider.notifier);
      final project = workspace.createProject('Pratica Rossi / Edilnord');
      final thread = workspace.createThread(
        projectId: project.id,
        title: 'Verifica del pagamento',
      );
      final agent = container.read(agentProvider.notifier);
      final chat = agent.chatFor(thread.id);
      final cards = ChatCards(ChatClock());
      chat.addMessage(
        cards.prompt('La fattura 17/2026 è saldata? Verifica gli allegati.'),
      );
      chat.addMessage(
        ChatCards.progress(
          'p',
          DateTime.now(),
          [
            {
              'label': 'Compatto il contesto',
              'detail': 'Matrice e token interni',
              'at': 1,
            },
          ],
          running: false,
          seconds: 12,
          operational: false,
        ),
      );
      chat.addMessage(
        cards.component(UiComponents.toolCall, {
          'tool': 'read_document',
          'title': 'Lettura tecnica',
          'status': 'done',
          'args': {'internal': true},
          'ms': 24,
        }),
      );
      chat.addMessage(cards.note(_answer));
      if (_capture.startsWith('after')) {
        chat.addMessage(ChatCards.progress('live', DateTime.now().subtract(const Duration(seconds: 24)), [
          {'label': 'Avvio la richiesta', 'at': 0},
          {'label': 'Esamino il fascicolo', 'detail': '2 allegati disponibili', 'at': 1},
          {'label': 'Scrivo la bozza', 'detail': 'Pagina 1 · 150 parole preparate', 'at': 4},
          {'label': 'Controllo la risposta e le fonti', 'detail': 'Verifico i riferimenti ai documenti originali', 'at': 24},
        ], running: true, seconds: 24));
        chat.addMessage(cards.component(UiComponents.toolCall, {
          'title': 'Aggiorno la pagina 1', 'status': 'done', 'detail': 'Premessa aggiornata · modifica applicata al documento',
        }));
        chat.addMessage(cards.component(UiComponents.evidence, {
          'claims': [{'claim': 'La documentazione presenta versioni discordanti.', 'status': 'inference', 'source_ids': ['s1'], 'citation_ids': []}],
          'pack': {'sources': [{'source_id': 's1', 'name': 'quietanza.pdf'}], 'citations': []},
        }));
      }
      final boundary = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            locale: const Locale('it'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: RepaintBoundary(
              key: boundary,
              child: Scaffold(body: ChatView(thread: thread)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (_capture.isNotEmpty) {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await render.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/ui-review/$_capture-$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Compatto il contesto'), findsNothing);
      expect(find.textContaining('read_document'), findsNothing);
      expect(
        find.textContaining('Il pagamento non è documentato'),
        findsWidgets,
      );
    });
  }
}

class _WaitingClient extends MockAgentClient {
  final finish = Completer<void>();

  @override
  Stream<AgentEvent> run(AgentRequest request) async* {
    yield const AgentStatusEvent(
      'Compatto il contesto',
      kind: 'context_trimmed',
      detail: 'token interni',
    );
    await finish.future;
    yield const AgentTextDelta('Occorre verificare il pagamento.');
    yield const AgentDone();
  }
}

class _WarningClient extends MockAgentClient {
  @override
  Stream<AgentEvent> run(AgentRequest request) async* {
    for (var i = 0; i < 2; i++) {
      yield const AgentStatusEvent(
        'Errore interno',
        kind: 'degraded',
        detail: 'Un allegato non è stato letto.',
      );
    }
    yield const AgentTextDelta(
      'La risposta considera solo i documenti leggibili.',
    );
    yield const AgentDone();
  }
}
