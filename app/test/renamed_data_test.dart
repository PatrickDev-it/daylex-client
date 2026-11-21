import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:daylex/core/platform/diagnostic_log.dart';
import 'package:daylex/core/platform/instance_lock.dart';
import 'package:daylex/core/platform/renamed_data.dart';
import 'package:daylex/core/platform/user_dirs.dart';

/// An install from before the rename (up to b2901) updates to Daylex and finds the lawyer's work, logins and
/// shortcuts where it left them (rfc/054).
void main() {
  late Directory home;
  late Map<String, String> env;
  late DiagnosticLog log;
  setUp(() {
    home = Directory.systemTemp.createTempSync('daylex-home');
    env = {
      'HOME': home.path,
      'USERPROFILE': home.path,
      'APPDATA': '${home.path}${Platform.pathSeparator}Roaming',
      'XDG_DATA_HOME': '${home.path}/share',
    };
    log = DiagnosticLog(File('${home.path}/migration.log'));
  });
  tearDown(() => home.deleteSync(recursive: true));

  File file(String path) => File(path.startsWith(home.path) ? path : '${home.path}/$path');

  void write(String path, String text) => file(path)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(text);

  for (final mac in [false, true]) {
    group(mac ? 'on the Mac' : 'on Windows and Linux', () {
      String legacy() => legacyAppDataDir(env, mac);
      String current() => appDataFolder(appFolderName, env, mac);

      test('the data folder and the developer configuration move to their new names', () {
        expect(current(), isNot(legacy()));
        write('${legacy()}/data/threads/t1.json', 'chat');
        write('.paperagent/server.json', 'key');
        migrateRenamedData(environment: env, macOS: mac, log: log);
        expect(file('${current()}/data/threads/t1.json').readAsStringSync(), 'chat');
        expect(file('.daylex/server.json').readAsStringSync(), 'key');
        expect(Directory(legacy()).existsSync(), isFalse);
        expect(Directory('${home.path}/.paperagent').existsSync(), isFalse);
        expect(log.file.readAsStringSync(), contains('moved'));
      });

      test('a folder that already has the new name is never touched', () {
        write('${legacy()}/data/threads/t1.json', 'old');
        write('${current()}/data/threads/t1.json', 'new');
        migrateRenamedData(environment: env, macOS: mac, log: log);
        expect(file('${current()}/data/threads/t1.json').readAsStringSync(), 'new');
        expect(file('${legacy()}/data/threads/t1.json').readAsStringSync(), 'old');
      });

      test('until the move happens, the app works in the old folder', () {
        expect(appDataDir(env, mac), current(), reason: 'a new install');
        Directory(legacy()).createSync(recursive: true);
        expect(appDataDir(env, mac), legacy(), reason: 'not moved yet');
        Directory(current()).createSync(recursive: true);
        expect(appDataDir(env, mac), current());
      });

      test('nothing moves, nor is tried, while an older app is open on the old folder', () async {
        write('${legacy()}/data/a.json', 'a');
        addTearDown(await _openOlderApp(Directory(legacy())));
        migrateRenamedData(environment: env, macOS: mac, log: log);
        expect(file('${legacy()}/data/a.json').existsSync(), isTrue);
        expect(Directory(current()).existsSync(), isFalse);
        expect(log.file.existsSync(), isFalse, reason: 'no move attempted');
      });
    });
  }

  test('on the Mac, the browser\'s logins follow the new bundle id', () {
    write('Library/WebKit/$legacyBundleId/WebsiteData/cookies', 'session');
    write('Library/HTTPStorages/$legacyBundleId/httpstorages.sqlite', 'store');
    write('Library/HTTPStorages/$legacyBundleId.binarycookies', 'cookies');
    migrateRenamedData(environment: env, macOS: true, log: log);
    expect(file('Library/WebKit/$bundleId/WebsiteData/cookies').readAsStringSync(), 'session');
    expect(file('Library/HTTPStorages/$bundleId/httpstorages.sqlite').readAsStringSync(), 'store');
    expect(file('Library/HTTPStorages/$bundleId.binarycookies').readAsStringSync(), 'cookies');
    expect(Directory('${home.path}/Library/WebKit/$legacyBundleId').existsSync(), isFalse);
  });

  test('the Linux menu entry starts the app itself instead of its launcher', () {
    const entry = '.local/share/applications/daylex.desktop';
    write(entry, '[Desktop Entry]\nName=Daylex\nExec="/opt/d/paper_agent"\nPath=/opt/d\n');
    retargetDesktopEntry(launcher: '/opt/d/paper_agent', app: '/opt/d/daylex', environment: env);
    expect(file(entry).readAsStringSync(), '[Desktop Entry]\nName=Daylex\nExec="/opt/d/daylex"\nPath=/opt/d\n');
  });

  test('a menu entry the lawyer pointed elsewhere is left as it is', () {
    const entry = '.local/share/applications/daylex.desktop';
    write(entry, 'Exec="/home/l/bin/daylex-wrapper"\n');
    retargetDesktopEntry(launcher: '/opt/d/paper_agent', app: '/opt/d/daylex', environment: env);
    expect(file(entry).readAsStringSync(), 'Exec="/home/l/bin/daylex-wrapper"\n');
  });

  test(
    'the Windows data folder keeps its place in Roaming',
    () {
      expect(appDataFolder(appFolderName, env, false), '${home.path}\\Roaming\\Daylex');
      expect(legacyAppDataDir(env, false), '${home.path}\\Roaming\\PaperAgent');
    },
    skip: Platform.isWindows ? false : 'a Windows path',
  );
}

/// Holds the lock an app open on [dir] holds, as an older app would: from another process, since elsewhere than
/// Windows a lock belongs to the process, and this one could always take it again. Returns what lets it go.
Future<void Function()> _openOlderApp(Directory dir) async {
  if (Platform.isWindows) return InstanceLock.acquire(dir).release;
  final holder = await Process.start('python3', ['-c', _holdLock, '${dir.path}/desktop.lock']);
  await holder.stdout.first;
  return holder.kill;
}

/// The lock Dart takes (fcntl, the whole file), taken by Python.
const _holdLock = '''
import fcntl, sys
lock = open(sys.argv[1], "a")
fcntl.lockf(lock, fcntl.LOCK_EX)
print("held", flush=True)
sys.stdin.read()
''';
