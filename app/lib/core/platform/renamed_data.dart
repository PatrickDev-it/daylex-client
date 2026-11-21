import 'dart:io';

import 'diagnostic_log.dart';
import 'instance_lock.dart';
import 'user_dirs.dart';

// What the app was called before it was Daylex (rfc/054), in one place: what [migrateRenamedData] moves, what
// [retargetLegacyLaunchers] points away from, and what appDataDir still reads until the move could happen. Delete
// this file, its calls and the paper_agent launchers (windows/legacy_launcher, linux/legacy_launcher) once no install
// up to b2901 remains.

/// The app data folder's name, and the Mac app's bundle id (its sandbox container's too), before the rename.
const legacyAppName = 'PaperAgent';
const legacyBundleId = 'com.daylex.paperAgent';

/// The developer configuration folder in the home folder, before the rename.
const legacyConfigDir = '.paperagent';

/// The executable an install from before the rename starts: now a launcher of the app.
final legacyExecutable = Platform.isWindows ? 'paper_agent.exe' : 'paper_agent';

/// The app data folder an app from before the rename made.
String legacyAppDataDir([Map<String, String>? environment, bool? macOS]) =>
    appDataFolder(legacyAppName, environment, macOS);

/// Moves, once, what the app kept under its former names to where it keeps it now: the app data folder,
/// `~/.paperagent` and, on the Mac, WebKit's stores of the browser's logins, kept by bundle id. Before anything opens
/// them. A move happens only where the destination does not exist yet, and not at all while an older app is open on
/// the data folder; one that fails (a file held open) is tried again at the next start, and until then the app works
/// in the old folder.
void migrateRenamedData({Map<String, String>? environment, bool? macOS, DiagnosticLog? log}) {
  final env = environment ?? Platform.environment;
  final mac = macOS ?? Platform.isMacOS;
  final legacy = legacyAppDataDir(env, mac);
  if (Directory(legacy).existsSync() && !_free(legacy)) return;
  final home = userHome(env);
  final notes = <String>[];
  for (final (from, to) in [
    (legacy, currentAppDataDir(env, mac)),
    if (home != null) ('$home/$legacyConfigDir', '$home/$configDirName'),
    if (home != null && mac) ...[
      ('$home/Library/WebKit/$legacyBundleId', '$home/Library/WebKit/$appId'),
      ('$home/Library/HTTPStorages/$legacyBundleId', '$home/Library/HTTPStorages/$appId'),
      ('$home/Library/HTTPStorages/$legacyBundleId.binarycookies', '$home/Library/HTTPStorages/$appId.binarycookies'),
    ],
  ]) {
    final type = FileSystemEntity.typeSync(from, followLinks: false);
    if (type == FileSystemEntityType.notFound || FileSystemEntity.typeSync(to, followLinks: false) != FileSystemEntityType.notFound) {
      continue;
    }
    try {
      Directory(to).parent.createSync(recursive: true);
      type == FileSystemEntityType.directory ? Directory(from).renameSync(to) : File(from).renameSync(to);
      notes.add('moved $from to $to');
    } on FileSystemException catch (e) {
      notes.add('could not move $from to $to: $e');
    }
  }
  // Written after the moves: the log is in the folder that moved.
  if (notes.isEmpty) return;
  final out = log ?? DiagnosticLog.open('migration.log');
  for (final note in notes) {
    out?.add(note);
  }
}

/// Whether no app is open on [dir]: the lock an app holds while it runs is free.
bool _free(String dir) {
  try {
    InstanceLock.acquire(Directory(dir)).release();
    return true;
  } on FileSystemException {
    return false;
  }
}

/// Points what an installer from before the rename made at the app itself instead of its launcher: on Windows the
/// shortcuts (Start menu, desktop, taskbar) and the icon in Settings > Apps, on Linux the menu entry. Once the launcher
/// is no longer needed, nothing points at it. Nothing to do where the app has no launcher beside it.
Future<void> retargetLegacyLaunchers({String? executable, Map<String, String>? environment}) async {
  final app = File(executable ?? Platform.resolvedExecutable);
  final launcher = File('${app.parent.path}${Platform.pathSeparator}$legacyExecutable');
  if (!launcher.existsSync()) return;
  final env = environment ?? Platform.environment;
  try {
    if (Platform.isLinux) retargetDesktopEntry(launcher: launcher.path, app: app.path, environment: env);
    if (!Platform.isWindows) return;
    final done = File('${appDataDir(env)}${Platform.pathSeparator}launchers-retargeted');
    if (done.existsSync()) return;
    final result = await Process.run('powershell.exe', [
      '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', //
      '-Command', _retargetWindows,
    ], environment: {'DAYLEX_LAUNCHER': launcher.path, 'DAYLEX_APP': app.path});
    if (result.exitCode == 0) done.writeAsStringSync('${DateTime.now().toUtc().toIso8601String()}\n');
    if (result.exitCode != 0) DiagnosticLog.open('migration.log')?.add('shortcuts not retargeted: ${result.stderr}');
  } on Object catch (e) {
    DiagnosticLog.open('migration.log')?.add('shortcuts not retargeted: $e');
  }
}

/// The Linux menu entry install-linux.sh wrote (in `~/.local/share`, whatever `XDG_DATA_HOME` says), pointed at
/// [app] where it starts [launcher].
void retargetDesktopEntry({required String launcher, required String app, Map<String, String>? environment}) {
  final home = userHome(environment);
  if (home == null) return;
  final entry = File('$home/.local/share/applications/daylex.desktop');
  if (!entry.existsSync()) return;
  final text = entry.readAsStringSync();
  final pointed = text.replaceAll('Exec="$launcher"', 'Exec="$app"');
  if (pointed != text) entry.writeAsStringSync(pointed);
}

/// Shortcuts the lawyer made by hand are pointed too.
const _retargetWindows = r'''
$old, $new = $env:DAYLEX_LAUNCHER, $env:DAYLEX_APP
$shell = New-Object -ComObject WScript.Shell
$folders = @(
  [Environment]::GetFolderPath('Programs'), [Environment]::GetFolderPath('Desktop'),
  (Join-Path $env:APPDATA 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar')
)
foreach ($folder in $folders) {
  if (-not (Test-Path -LiteralPath $folder)) { continue }
  foreach ($file in Get-ChildItem -LiteralPath $folder -Filter *.lnk -Recurse -ErrorAction SilentlyContinue) {
    $link = $shell.CreateShortcut($file.FullName)
    if ($link.TargetPath -ine $old) { continue }
    $link.TargetPath = $new
    if ($link.IconLocation -like "$old,*") { $link.IconLocation = "$new,0" }
    $link.Save()
  }
}
foreach ($key in Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall' -ErrorAction SilentlyContinue) {
  if ((Get-ItemProperty -LiteralPath $key.PSPath).DisplayIcon -ieq $old) {
    Set-ItemProperty -LiteralPath $key.PSPath -Name DisplayIcon -Value $new
  }
}
''';
