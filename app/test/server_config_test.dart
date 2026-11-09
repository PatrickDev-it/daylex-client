import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/features/agent/data/http_agent_client.dart';
import 'package:paper_agent/l10n/l10n.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('it'));

  test('bearer key cannot be sent to a remote HTTP endpoint', () {
    expect(
      () => AgentServerConfig.validateAddress('http://example.com', 'test', l),
      throwsA(isA<AgentConfigException>()),
    );
    expect(
      AgentServerConfig.validateAddress(
        'https://example.com',
        'test',
        l,
      ).scheme,
      'https',
    );
    expect(
      AgentServerConfig.validateAddress(
        'http://127.0.0.1:8787',
        'test',
        l,
      ).host,
      '127.0.0.1',
    );
  });

  test('resetting a saved address retains the access key', () {
    final dir = Directory.systemTemp.createTempSync('daylex-config-test-');
    try {
      final file = File('${dir.path}/server.json')
        ..writeAsStringSync(
          jsonEncode({'url': 'https://obsolete.example', 'token': 'dlx_test'}),
        );
      AgentServerConfig.resetAddress(l, configFile: file);
      expect(jsonDecode(file.readAsStringSync()), {'token': 'dlx_test'});
      AgentServerConfig.resetAddress(l, configFile: file);
      expect(jsonDecode(file.readAsStringSync()), {'token': 'dlx_test'});
    } finally {
      File('${dir.path}/server.json').deleteSync();
      dir.deleteSync();
    }
  });
}
