import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/core/platform/sandbox_migration.dart';

void main() {
  late Directory home;
  late Map<String, String> env;
  setUp(() {
    home = Directory.systemTemp.createTempSync('daylex-home');
    env = {'HOME': home.path};
  });
  tearDown(() => home.deleteSync(recursive: true));

  File file(String path) => File('${home.path}/$path');

  void write(String path, String text) => file(path)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(text);

  const support = 'Library/Application Support/PaperAgent';

  test('brings the work and the server key out of the sandbox container', () {
    write('$sandboxContainer/$support/data/threads/t1.json', 'chat');
    write('$sandboxContainer/.paperagent/server.json', 'key');
    migrateSandboxData(environment: env, macOS: true);
    expect(file('$support/data/threads/t1.json').readAsStringSync(), 'chat');
    expect(file('.paperagent/server.json').readAsStringSync(), 'key');
    expect(file('$sandboxContainer/$support/data/threads/t1.json').existsSync(), isTrue, reason: 'left as it was');
    expect(Directory('${home.path}/$support.migrating').existsSync(), isFalse);
  });

  test('never touches work that is already outside the container', () {
    write('$sandboxContainer/$support/data/threads/t1.json', 'old');
    write('$support/data/threads/t1.json', 'new');
    migrateSandboxData(environment: env, macOS: true);
    expect(file('$support/data/threads/t1.json').readAsStringSync(), 'new');
  });

  test('replaces a copy that was cut short', () {
    write('$sandboxContainer/$support/data/a.json', 'a');
    write('$support.migrating/data/stale.json', 'stale');
    migrateSandboxData(environment: env, macOS: true);
    expect(file('$support/data/a.json').readAsStringSync(), 'a');
    expect(file('$support/data/stale.json').existsSync(), isFalse);
  });

  test('does nothing elsewhere than macOS', () {
    write('$sandboxContainer/$support/data/a.json', 'a');
    migrateSandboxData(environment: env, macOS: false);
    expect(Directory('${home.path}/$support').existsSync(), isFalse);
  });
}
