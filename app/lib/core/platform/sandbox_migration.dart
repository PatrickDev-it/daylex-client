import 'dart:io';

import 'diagnostic_log.dart';
import 'user_dirs.dart';

/// The folder the sandboxed macOS app (up to build 1) saw as its home: what it saved is under it.
const sandboxContainer = 'Library/Containers/com.daylex.paperAgent/Data';

/// Brings the lawyer's work from where the sandboxed macOS app kept it to where the app keeps it now that it
/// runs outside the sandbox (it has to, to replace itself when it updates): the app data folder and
/// `~/.paperagent`. Once, the first time the new app opens: a destination that already exists is never
/// touched, and the container is left as it was, so nothing is lost if anything goes wrong. A no-op
/// elsewhere than macOS.
void migrateSandboxData({Map<String, String>? environment, bool? macOS, DiagnosticLog? log}) {
  if (!(macOS ?? Platform.isMacOS)) return;
  final env = environment ?? Platform.environment;
  final home = userHome(env);
  if (home == null) return;
  final container = '$home/$sandboxContainer';
  if (!Directory(container).existsSync()) return;
  log ??= DiagnosticLog.open('migration.log');
  for (final (from, to) in [
    ('$container/Library/Application Support/PaperAgent', appDataDir(env, true)),
    ('$container/.paperagent', '$home/.paperagent'),
  ]) {
    if (!Directory(from).existsSync() || Directory(to).existsSync()) continue;
    // Copied beside the destination, then renamed: a copy cut short never looks like the migrated work.
    final partial = Directory('$to.migrating');
    try {
      if (partial.existsSync()) partial.deleteSync(recursive: true);
      _copyTree(Directory(from), partial);
      Directory(to).parent.createSync(recursive: true);
      partial.renameSync(to);
      log?.add('migrated $from to $to');
    } on FileSystemException catch (e) {
      // The container still holds everything: the next launch tries again.
      log?.add('could not migrate $from to $to: $e');
    }
  }
}

void _copyTree(Directory from, Directory to) {
  to.createSync(recursive: true);
  for (final entity in from.listSync(followLinks: false)) {
    final name = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
    final target = '${to.path}/$name';
    if (entity is Directory) {
      _copyTree(entity, Directory(target));
    } else if (entity is File) {
      entity.copySync(target);
    }
  }
}
