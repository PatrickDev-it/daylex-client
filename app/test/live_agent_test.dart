// Against the real agent server. Skipped unless PAPERAGENT_LIVE=1 and the app's own server
// configuration loads (see README.md; e.g. through `ssh -N -L 8787:127.0.0.1:8787 gpu`):
//
//   $env:PAPERAGENT_LIVE=1; flutter test test/live_agent_test.dart
import 'dart:io';
import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/l10n/app_localizations.dart';
import 'package:paper_agent/features/agent/agent_controller.dart';
import 'package:paper_agent/features/agent/data/http_agent_client.dart';
import 'package:paper_agent/features/document/model/document.dart';
import 'package:paper_agent/features/workspace/workspace_state.dart';

import 'demo_fixture.dart';

const demoDocumentId = demoProposalDocumentId;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The test binding answers every HTTP request with 400; this test needs the network.
  HttpOverrides.global = null;

  // The configuration the app itself reads, never a second reading of server.json.
  AgentServerConfig? config;
  String? problem;
  try {
    config = AgentServerConfig.load(lookupAppLocalizations(const Locale('it')));
  } on AgentConfigException catch (e) {
    problem = e.message;
  }
  final live = Platform.environment['PAPERAGENT_LIVE'] == '1' && config != null;

  test(
    'the real agent edits the demo document end to end',
    () async {
      final client = HttpAgentClient(
        config!,
        l10n: () => lookupAppLocalizations(const Locale('it')),
      );
      final container = ProviderContainer(
        overrides: [
          ...demoOverrides,
          agentClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(() {
        container.dispose();
        client.close();
      });
      final agent = container.read(agentProvider.notifier);
      const id = demoPolishThreadId;
      final template = container
          .read(workspaceProvider)
          .documents[demoDocumentId]!;
      final before = template.copyWith(
        metadata: template.metadata.copyWith(
          title: 'Bozza memoria difensiva',
          subtitle: 'Documento sintetico di collaudo',
          client: 'Parte di prova',
        ),
        pages: [
          for (var i = 0; i < 3; i++)
            DocPage(
              id: 'legal-$i',
              title: 'Sezione ${i + 1}',
              blocks: [
                ParagraphBlock(
                  id: 'paragraph-$i',
                  text: 'La documentazione del pagamento deve essere verificata prima di formulare le conclusioni difensive.',
                ),
              ],
            ),
        ],
      );
      container
          .read(workspaceProvider.notifier)
          .addDocument(before, threadId: id);
      expect(before.pages[2].layout, isNot(PageLayout.premium));

      final watch = Stopwatch()..start();
      final observed = <Map<String, dynamic>>[];
      final seen = <String>{};
      final chat = agent.chatFor(id);
      chat.addListener(() {
        for (final message in chat.messages) {
          final kind = message.customProperties?['resultKind'];
          final data = message.customProperties?['resultData'];
          if (data is! Map) continue;
          final identity =
              '$kind:${data['status']}:${data['title']}:${data['steps']}';
          if (!seen.add(identity)) continue;
          observed.add({
            'ms': watch.elapsedMilliseconds,
            'kind': kind,
            'status': data['status'],
            'title': data['title'],
            'steps': data['steps'],
          });
        }
      });
      await agent.send(
        id,
        'Usa un’impaginazione curata per la pagina 3 e aggiungi un riquadro con il messaggio chiave.',
      );
      final elapsed = watch.elapsedMilliseconds;
      final receipts = observed
          .where((e) => e['kind'] == 'tool_call' && e['status'] == 'done')
          .toList();

      final evidence = File('build/ui-review/live-progress.json');
      evidence.parent.createSync(recursive: true);
      evidence.writeAsStringSync(
        const JsonEncoder.withIndent('  ')
            .convert({'elapsed_ms': elapsed, 'observed': observed}),
      );

      final session = container.read(sessionProvider(id));
      for (final entry in session.log) {
        // ignore: avoid_print
        print('${entry.kind.padRight(8)} ${entry.summary}');
      }
      expect(session.phase, isNot(AgentPhase.error), reason: session.error);
      // ignore: avoid_print
      print(chat.messages.map((m) => m.text).join('\n'));
      final response = chat.messages
          .where(
            (m) =>
                m.user.id == 'agent' &&
                m.customProperties?['resultKind'] == null,
          )
          .map((m) => m.text)
          .join(' ');
      expect(
        RegExp(
          r'\b(layout|premium|callout)\b',
          caseSensitive: false,
        ).hasMatch(response),
        isFalse,
      );
      expect(receipts.length, greaterThanOrEqualTo(2));
      expect(receipts.first['ms'] as int, lessThan(elapsed));
      expect(
        observed.any(
          (e) => e['kind'] == 'pdf_diff' && (e['ms'] as int) < elapsed,
        ),
        isTrue,
      );
      expect(observed.any((e) => e['kind'] == 'evidence'), isTrue);
      final after = container
          .read(workspaceProvider)
          .documents[demoDocumentId]!;
      expect(after.pages[2].layout, PageLayout.premium);
      expect(
        after.pages[2].blocks.length,
        greaterThan(before.pages[2].blocks.length),
      );
    },
    skip: live
        ? false
        : 'set PAPERAGENT_LIVE=1 and configure the server${problem == null ? '' : ': $problem'}',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
