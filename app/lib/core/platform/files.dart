import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

/// Opens [path] in the system's default app, through the system's own call
/// (ShellExecute, NSWorkspace, xdg-open) rather than spawning `cmd` or `open`.
Future<void> openFile(String path) async {
  await launchUrl(Uri.file(path));
}

/// Shows [path] in the file manager: selected in Explorer on Windows, its
/// folder elsewhere.
Future<void> revealFile(String path) async {
  if (Platform.isWindows) {
    await Process.run('explorer', ['/select,', path]);
  } else {
    await launchUrl(Uri.directory(File(path).parent.path));
  }
}
