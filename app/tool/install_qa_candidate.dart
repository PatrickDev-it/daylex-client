// Launches the production updater against an explicitly selected QA installation.
import 'dart:io';

import 'package:paper_agent/features/update/installer.dart';

Future<void> main(List<String> args) async {
  if (args.length != 4) {
    throw ArgumentError(
      'Expected executable, archive, work directory and SHA256',
    );
  }
  final executable = File(args[0]).absolute;
  if (!executable.parent.uri.pathSegments.any(
    (s) => s.startsWith('Daylex-QA-'),
  )) {
    throw ArgumentError(
      'Only an explicitly named Daylex-QA- installation is allowed',
    );
  }
  final work = Directory(args[2]).absolute;
  await WindowsInstaller(executable).launch(
    File(args[1]).absolute,
    work: work,
    log: File('${work.path}/install.log'),
    expectedSha256: args[3],
  );
  exit(0); // The installer intentionally waits for its parent to exit.
}
