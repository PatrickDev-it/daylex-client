import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:daylex/core/platform/sandbox_migration.dart';

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

  // What the sandboxed app kept, under the names of the time; where it goes, under today's.
  const kept = 'Library/Application Support/PaperAgent';
  const support = 'Library/Application Support/Daylex';

  test('brings the work and the server key out of the sandbox container', () {
    write('$sandboxContainer/$kept/data/threads/t1.json', 'chat');
    write('$sandboxContainer/.paperagent/server.json', 'key');
    migrateSandboxData(environment: env, macOS: true);
    expect(file('$support/data/threads/t1.json').readAsStringSync(), 'chat');
    expect(file('.daylex/server.json').readAsStringSync(), 'key');
    expect(file('$sandboxContainer/$kept/data/threads/t1.json').existsSync(), isTrue, reason: 'left as it was');
    expect(Directory('${home.path}/$support.migrating').existsSync(), isFalse);
  });

  test('never touches work that is already outside the container', () {
    write('$sandboxContainer/$kept/data/threads/t1.json', 'old');
    write('$support/data/threads/t1.json', 'new');
    migrateSandboxData(environment: env, macOS: true);
    expect(file('$support/data/threads/t1.json').readAsStringSync(), 'new');
  });

  test('replaces a copy that was cut short', () {
    write('$sandboxContainer/$kept/data/a.json', 'a');
    write('$support.migrating/data/stale.json', 'stale');
    migrateSandboxData(environment: env, macOS: true);
    expect(file('$support/data/a.json').readAsStringSync(), 'a');
    expect(file('$support/data/stale.json').existsSync(), isFalse);
  });

  test('does nothing elsewhere than macOS', () {
    write('$sandboxContainer/$kept/data/a.json', 'a');
    migrateSandboxData(environment: env, macOS: false);
    expect(Directory('${home.path}/$support').existsSync(), isFalse);
  });
}
