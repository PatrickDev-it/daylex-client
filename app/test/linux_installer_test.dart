import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/features/update/installer.dart';

void main() {
  for (final scenario in ['success', 'tampered', 'invalid']) {
    test('Linux updater $scenario preserves a usable installed bundle', () async {
      final root = Directory.systemTemp.createTempSync('daylex-installer-');
      addTearDown(() => root.deleteSync(recursive: true));
      final app = Directory('${root.path}/Installed App')..createSync();
      final old = File('${app.path}/paper_agent')..writeAsStringSync('#!/bin/sh\nexit 0\n');
      await Process.run('chmod', ['+x', old.path]);
      final source = Directory('${root.path}/source')..createSync();
      final next = File('${source.path}/paper_agent')..writeAsStringSync('#!/bin/sh\n# updated\nexit 0\n');
      await Process.run('chmod', ['+x', next.path]);
      if (scenario != 'invalid') {
        Directory('${source.path}/lib').createSync();
        File('${source.path}/lib/libapp.so').writeAsStringSync('synthetic');
      }
      final archive = File('${root.path}/update.zip');
      expect((await Process.run('zip', ['-qr', archive.path, '.'], workingDirectory: source.path)).exitCode, 0);
      final hash = (await Sha256().hash(archive.readAsBytesSync())).bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final script = File('${root.path}/installer.sh')..writeAsStringSync(linuxInstallerScript);
      final result = await Process.run('bash', [script.path, '99999999', archive.path, app.path,
        '${root.path}/update.log', scenario == 'tampered' ? '0' * 64 : hash]);
      expect(old.existsSync(), true);
      if (scenario == 'success') {
        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect(old.readAsStringSync(), contains('# updated'));
      } else {
        expect(result.exitCode, isNot(0));
        expect(old.readAsStringSync(), isNot(contains('# updated')));
      }
    }, skip: !Platform.isLinux);
  }
}
