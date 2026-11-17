import 'dart:io';

import 'package:paper_agent/features/update/installer.dart';

Future<void> main(List<String> args) async {
  final root = Directory(args[0]).absolute.path;
  final updater = await WindowsInstaller(File('$root/app/smoke.exe')).launch(
    File('$root/update.zip'),
    work: Directory('$root/work'),
    log: File('$root/install.log'),
    expectedSha256: args[1],
    // The update window too, where the update goes through.
    splash: args.length > 2 && args[2] == 'valid'
        ? const UpdateSplash(title: 'Aggiornamento in corso', message: 'Prova del programma di aggiornamento')
        : null,
  );
  if (args.length > 2 && args[2] == 'cancelled') updater?.kill();
  exit(0);
}
