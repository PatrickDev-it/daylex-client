import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:daylex/features/agent/data/http_agent_client.dart';
import 'package:daylex/features/agent/domain/agent_protocol.dart';

import 'test_app.dart';

/// A case-file file goes from disk in chunks, resumed where the server says it stopped (rfc/051).
void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('chunks'));
  tearDown(() => dir.delete(recursive: true));

  Future<void> serve(
    Future<void> Function(HttpRequest request, Uint8List body) answer,
    Future<void> Function(HttpAgentClient client) use,
  ) => HttpOverrides.runWithHttpOverrides(() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      final body = await request.fold(BytesBuilder(), (b, d) => b..add(d));
      // Every request declares its length: the server keeps memory only for that much, and refuses more at the door.
      expect(request.contentLength, body.length, reason: request.uri.path);
      await answer(request, body.takeBytes());
      await request.response.close();
    });
    final client = HttpAgentClient(
      AgentServerConfig(url: Uri.parse('http://127.0.0.1:${server.port}'), token: 'test-key'),
      l10n: () => itL10n,
    );
    try {
      await use(client);
    } finally {
      client.close();
      await subscription.cancel();
      await server.close(force: true);
    }
  }, _RealNetwork());

  test('a file on disk goes in chunks, through a busy server and an answer lost on the way', () async {
    final file = File('${dir.path}/ricorso.pdf')..writeAsBytesSync(utf8.encode('%PDF-1.7 atto'));
    final received = BytesBuilder();
    final requests = <String>[];
    var busy = true;
    var lost = true;
    await serve((request, body) async {
      requests.add('${request.method} ${request.uri.path.split('/').skip(4).join('/')} ${request.uri.query}');
      void answer(int status, Map<String, Object> json) => request.response
        ..statusCode = status
        ..write(jsonEncode(json));
      switch (request.method) {
        case 'POST' when request.uri.path.endsWith('/uploads'):
          final start = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
          expect(start, {'name': 'ricorso.pdf', 'mimeType': 'application/pdf', 'size': 13});
          answer(200, {'id': 'u1', 'received': 0, 'chunkBytes': 5});
        case 'PUT':
          final offset = int.parse(request.uri.queryParameters['offset']!);
          if (busy) {
            busy = false;
            return answer(503, {'detail': 'Il server sta ricevendo molti file: riprovo tra poco.'});
          }
          if (offset != received.length) return answer(409, {'received': received.length});
          received.add(body);
          if (offset == 5 && lost) {
            lost = false; // the chunk arrived, its answer did not
            return answer(503, {'detail': 'occupato'});
          }
          answer(200, {'received': received.length});
        case 'POST' when request.uri.path.endsWith('/u1/complete'):
          answer(200, {'name': 'ricorso.pdf', 'pages': 1, 'new': true});
        default:
          answer(404, {'detail': 'Not Found'});
      }
    }, (client) async {
      final card = await client.uploadAttachment(
        's',
        AgentAttachment(name: 'ricorso.pdf', mimeType: 'application/pdf', bytes: Uint8List(0), localPath: file.path),
      );
      expect(card!.name, 'ricorso.pdf');
      expect(card.isNew, isTrue);
    });
    expect(utf8.decode(received.takeBytes()), '%PDF-1.7 atto');
    expect(requests, [
      'POST uploads ',
      'PUT uploads/u1 offset=0',
      'PUT uploads/u1 offset=0',
      'PUT uploads/u1 offset=5',
      'PUT uploads/u1 offset=5',
      'PUT uploads/u1 offset=10',
      'POST uploads/u1/complete ',
    ]);
  });

  test('a server without the chunked routes takes the file whole', () async {
    final file = File('${dir.path}/nota.txt')..writeAsStringSync('Nota di udienza');
    final paths = <String>[];
    await serve((request, body) async {
      paths.add(request.uri.path);
      if (request.uri.path.endsWith('/attachments')) {
        final sent = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
        expect(utf8.decode(base64Decode(sent['data'] as String)), 'Nota di udienza');
        request.response.write(jsonEncode({'name': 'nota.txt', 'pages': 1}));
      } else {
        request.response
          ..statusCode = 404
          ..write(jsonEncode({'detail': 'Not Found'}));
      }
    }, (client) async {
      final card = await client.uploadAttachment(
        's',
        AgentAttachment(name: 'nota.txt', mimeType: 'text/plain', bytes: Uint8List(0), localPath: file.path),
      );
      expect(card!.name, 'nota.txt');
    });
    expect(paths, ['/v1/sessions/s/uploads', '/v1/sessions/s/attachments']);
  });

  test('the waits between tries grow and stop at a minute', () {
    expect([for (var a = 1; a < uploadAttempts; a++) uploadRetryDelay(a).inSeconds], [1, 2, 4, 8, 16, 32, 60, 60]);
  });
}

class _RealNetwork extends HttpOverrides {}
