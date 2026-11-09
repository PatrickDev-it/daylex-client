import 'dart:io';

import 'package:paper_agent/features/update/installer.dart';

Future<void> main(List<String> args) async {
  final root = Directory(args[0]).absolute.path;
  final updater = await WindowsInstaller(File('$root/app/smoke.exe')).launch(
    File('$root/update.zip'),
    work: Directory('$root/work'),
    log: File('$root/install.log'),
    expectedSha256: args[1],
  );
  if (args.length > 2 && args[2] == 'cancelled') updater?.kill();
  exit(0);
}
