import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/features/access/desktop_credentials.dart';

class MemoryVault implements CredentialVault {
  final values = <String, String>{};
  bool broken = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (broken) throw StateError('locked');
    values[key] = value;
  }
}

void main() {
  test(
    'migrates only after verified secure write and preserves device on restart',
    () async {
      final dir = Directory.systemTemp.createTempSync('daylex-vault-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final legacy = File('${dir.path}/server.json')
        ..writeAsStringSync(
          jsonEncode({'token': 'dlx_test', 'url': 'https://example.com'}),
        );
      final vault = MemoryVault();
      final first = DesktopCredentials(vault);
      await first.initialize(legacy: legacy);
      expect(first.ready, isTrue);
      expect(first.key, 'dlx_test');
      expect(first.validated, isFalse);
      expect(jsonDecode(legacy.readAsStringSync()), {
        'url': 'https://example.com',
      });
      final second = DesktopCredentials(vault);
      await second.initialize(legacy: legacy);
      expect(second.device, first.device);
      expect(second.device!.length, 43);
    },
  );
  test(
    'vault failure preserves the old key and refuses authentication',
    () async {
      final dir = Directory.systemTemp.createTempSync('daylex-vault-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final legacy = File('${dir.path}/server.json')
        ..writeAsStringSync('{"token":"keep-me"}');
      final vault = MemoryVault()..broken = true;
      final credentials = DesktopCredentials(vault);
      await credentials.initialize(legacy: legacy);
      expect(credentials.ready, isFalse);
      expect(credentials.key, isNull);
      expect(legacy.readAsStringSync(), contains('keep-me'));
    },
  );
}
