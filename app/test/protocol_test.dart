import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/l10n/app_localizations.dart';
import 'package:paper_agent/features/agent/data/http_agent_client.dart';
import 'package:paper_agent/features/agent/domain/agent_protocol.dart';
import 'package:paper_agent/features/agent/presentation/ui_components.dart';
import 'package:paper_agent/ui/chat/components/component_registry.dart';

void main() {
  test('every card the server sends has a builder', () {
    expect(UiComponents.all, containsAll(ServerComponents.all));
    expect(componentRegistry.keys, containsAll(ServerComponents.all));
  });

  test('the app sends its protocol version and shows a refusal', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final versions = <String?>[];
    final sourceLinkVersions = <String?>[];
    final payloads = <Map<String, dynamic>>[];
    server.listen((request) async {
      versions.add(request.headers.value(protocolHeader));
      sourceLinkVersions.add(request.headers.value('X-Source-Links-Version'));
      payloads.add(
        jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>,
      );
      request.response
        ..statusCode = HttpStatus.conflict
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'detail': 'Questa versione dell\'app non è compatibile con il server: aggiornala.',
          }),
        );
      await request.response.close();
    });
    final client = HttpAgentClient(
      AgentServerConfig(
        url: Uri.parse('http://127.0.0.1:${server.port}'),
        token: 'test',
      ),
      l10n: () => lookupAppLocalizations(const Locale('it')),
    );
    addTearDown(client.close);

    final events = await client
        .run(const AgentRequest(sessionId: 's1', prompt: 'ciao'))
        .toList();

    expect(versions, ['$protocolVersion']);
    expect(sourceLinkVersions, ['1']);
    expect(payloads.single.containsKey('sourceLinksVersion'), isFalse);
    expect(
      events.single,
      isA<AgentFailure>().having(
        (e) => e.message,
        'message',
        contains('aggiornala'),
      ),
    );
  });

  /// Serves [body] as the run's event stream and returns what the app makes of it.
  Future<List<AgentEvent>> runAgainst(String body) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      await request.drain<void>();
      request.response.write(body);
      await request.response.close();
    });
    final client = HttpAgentClient(
      AgentServerConfig(
        url: Uri.parse('http://127.0.0.1:${server.port}'),
        token: 'test',
      ),
      l10n: () => lookupAppLocalizations(const Locale('it')),
    );
    addTearDown(client.close);
    return client
        .run(const AgentRequest(sessionId: 's1', prompt: 'ciao'))
        .toList();
  }

  final it = lookupAppLocalizations(const Locale('it'));

  test('evidence audit survives HTTP parsing before completion', () async {
    final audit = {
      'claims': [
        {'claim': 'Un fatto', 'status': 'traceable'},
      ],
      'pack': {'sources': []},
    };
    final events = await runAgainst(
      '${jsonEncode({'type': 'evidence', 'audit': audit})}\n{"type":"done"}\n',
    );
    expect(
      events.first,
      isA<AgentEvidenceEvent>().having((e) => e.audit, 'audit', audit),
    );
    expect(events.last, isA<AgentDone>());
  });

  test('a run that ends with done is a success', () async {
    final events = await runAgainst(
      '{"type":"text","text":"ok"}\n{"type":"done"}\n',
    );
    expect(events.last, isA<AgentDone>());
  });

  test(
    'a stream cut short before done is a failure, not a finished reply',
    () async {
      final events = await runAgainst('{"type":"text","text":"a metà"}\n');
      expect(events.first, isA<AgentTextDelta>());
      expect(
        events.last,
        isA<AgentFailure>().having((e) => e.message, 'message', it.streamEnded),
      );
    },
  );

  test('a line the app cannot read ends the run with a failure', () async {
    final events = await runAgainst(
      '{"type":"tool_call","name":"x"}\n{"type":"done"}\n',
    );
    expect(
      events.single,
      isA<AgentFailure>().having(
        (e) => e.message,
        'message',
        startsWith('Collegamento'),
      ),
    );
  });

  test('a client closed mid-run (a new access key) lets that run finish, tool results included', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final answered = Completer<void>();
    server.listen((request) async {
      await request.drain<void>();
      if (request.uri.path.endsWith('/tool-results')) {
        request.response.write('{"accepted":true}');
        await request.response.close();
        answered.complete();
        return;
      }
      request.response
        ..bufferOutput = false
        ..write(
          '{"type":"tool_call","id":"c1","name":"read_document","arguments":{}}\n',
        );
      await request.response.flush();
      await answered.future;
      request.response.write('{"type":"done"}\n');
      await request.response.close();
    });
    final client = HttpAgentClient(
      AgentServerConfig(
        url: Uri.parse('http://127.0.0.1:${server.port}'),
        token: 'test',
      ),
      l10n: () => lookupAppLocalizations(const Locale('it')),
    );

    final events = <AgentEvent>[];
    final done = Completer<void>();
    client.run(const AgentRequest(sessionId: 's1', prompt: 'ciao')).listen((
      event,
    ) async {
      events.add(event);
      if (event is AgentToolCall) {
        client.close(); // what the settings do on a new key, while this run waits for its tool's result
        await client.submitToolResult('s1', event.id, const {'ok': true});
      }
    }, onDone: done.complete);
    await done.future;

    expect(
      events.last,
      isA<AgentDone>(),
      reason: 'the run ends as the server ended it, not cut by the close',
    );
    await expectLater(
      client.submitToolResult('s1', 'c2', const {}),
      throwsA(anything),
      reason:
          'once its last run is over, the closed client takes no more requests',
    );
  });
}
