import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/features/access/desktop_credentials.dart';
import 'package:paper_agent/features/access/service_status.dart';
import 'package:paper_agent/l10n/app_localizations_it.dart';

class _Vault implements CredentialVault {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  test(
    'presence handles maintenance, revocation, recovery and a network outage',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final credentials = DesktopCredentials(_Vault())..device = 'd' * 43;
      await credentials.save('test-key', accepted: true, disclosure: true);
      var status = 200;
      var data = <String, dynamic>{'schema': 1, 'maintenance': false};
      var requests = 0;
      server.listen((request) async {
        expect(request.uri.path, '/v1/client/presence');
        expect(request.headers.value('X-Daylex-Device'), 'd' * 43);
        expect(request.headers.value('X-Daylex-Disclosure'), '1');
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        expect(body['area'], 'chat');
        requests++;
        request.response
          ..statusCode = status
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(data));
        await request.response.close();
      });
      final service = ServiceStatus(
        AppLocalizationsIt(),
        endpoint: Uri.parse('http://127.0.0.1:${server.port}'),
        credentials: credentials,
      );
      try {
        await service.check();
        expect(service.offline, isFalse);
        status = 503;
        data = {'schema': 1, 'maintenance': true, 'message': 'Rientro alle 18'};
        await service.check();
        expect(service.maintenance, isTrue);
        expect(service.message, 'Rientro alle 18');
        status = 401;
        data = {'detail': 'Revocata'};
        await service.check();
        expect(service.denied, isTrue);
        status = 200;
        data = {'schema': 1, 'maintenance': false};
        await service.check();
        expect(service.denied, isFalse);
        expect(service.maintenance, isFalse);
        await server.close(force: true);
        await service.check();
        expect(service.offline, isTrue);
        expect(credentials.validated, isTrue);
        expect(requests, 4);
      } finally {
        service.dispose();
        await server.close(force: true);
      }
    },
  );
}
