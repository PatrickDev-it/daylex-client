import 'dart:io';

import 'diagnostic_log.dart';
import 'user_dirs.dart';

/// Where the WhatsApp connector, removed after the security review of 20 November 2026, kept its WhatsApp Web
/// session: the folder its Node bridge chose, under `APPDATA` when set, else under `~/.config`.
String? whatsappSessionDir([Map<String, String>? environment]) {
  final env = environment ?? Platform.environment;
  final appData = env['APPDATA'] ?? '';
  final home = userHome(env);
  final base = appData.isNotEmpty ? appData : home == null ? null : '$home/.config';
  return base == null ? null : '$base/Daylex/WhatsApp';
}

/// Deletes the session the removed connector left on this computer: a logged-in WhatsApp Web profile nothing
/// reads any more is a credential lying on disk. Only that folder; a file still held is logged and the next
/// launch tries again.
Future<void> forgetWhatsappSession({Map<String, String>? environment, DiagnosticLog? log}) async {
  final path = whatsappSessionDir(environment);
  if (path == null) return;
  final folder = Directory(path);
  if (!folder.existsSync()) return;
  log ??= DiagnosticLog.open('migration.log');
  try {
    await folder.delete(recursive: true);
    log?.add('removed the retired WhatsApp session in $path');
  } on FileSystemException catch (e) {
    log?.add('could not remove the retired WhatsApp session in $path: $e');
  }
}
