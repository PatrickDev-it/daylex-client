import 'dart:io';

import 'package:paper_agent/core/platform/instance_lock.dart';

Future<void> main(List<String> args) async {
  if (args.isNotEmpty) {
    try {
      InstanceLock.acquire(Directory(args.single)).release();
      exit(0);
    } on FileSystemException {
      exit(7);
    }
  }
  final dir = Directory.systemTemp.createTempSync('daylex-lock-test-');
  try {
    final lock = InstanceLock.acquire(dir);
    final held = await Process.run(Platform.resolvedExecutable, [
      Platform.script.toFilePath(),
      dir.path,
    ]);
    lock.release();
    final released = await Process.run(Platform.resolvedExecutable, [
      Platform.script.toFilePath(),
      dir.path,
    ]);
    if (held.exitCode != 7 || released.exitCode != 0) {
      throw StateError('Lock lifecycle failed');
    }
    stdout.writeln(
      'PASS: second process refused; process can acquire after release.',
    );
  } finally {
    dir.deleteSync(recursive: true);
  }
}
