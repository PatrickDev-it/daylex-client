import 'dart:io';

import 'package:flutter/foundation.dart';

import 'user_dirs.dart';

/// A small text file of what happened to the app, in the app data `logs` folder: when a lawyer reports a
/// freeze, the restart that followed has not erased it. Never larger than [maxBytes]; the file before is
/// kept as `<name>.1`. Nothing is written in tests.
class DiagnosticLog {
  DiagnosticLog(this.file);

  static const maxBytes = 256 * 1024;

  /// What the system said about the window, and what the app did when it did not say enough.
  static final window = DiagnosticLog.open('window.log');

  static DiagnosticLog? open(String name) {
    if (Platform.environment['FLUTTER_TEST'] == 'true') return null;
    final sep = Platform.pathSeparator;
    return DiagnosticLog(File('${appDataDir()}${sep}logs$sep$name'));
  }

  final File file;

  /// One timestamped line. A log that cannot be written is not worth stopping the app for.
  void add(String line) {
    debugPrint('PaperAgent: $line');
    try {
      file.parent.createSync(recursive: true);
      if (file.existsSync() && file.lengthSync() > maxBytes) file.renameSync('${file.path}.1');
      file.writeAsStringSync('${DateTime.now().toIso8601String()} $line\n', mode: FileMode.append, flush: true);
    } on FileSystemException catch (e) {
      debugPrint('PaperAgent: could not write ${file.path}: $e');
    }
  }
}
