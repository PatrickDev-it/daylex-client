import 'dart:io';

/// The user's home folder, found one way for the whole app: `USERPROFILE` on
/// Windows (where a shell may set `HOME` to a path of its own), `HOME`
/// elsewhere. Null when the environment gives neither.
String? userHome([Map<String, String>? environment]) {
  final env = environment ?? Platform.environment;
  return Platform.isWindows ? env['USERPROFILE'] ?? env['HOME'] : env['HOME'];
}

/// The folder the app keeps its own files in on this computer (the lawyer's work in `data`, diagnostics in
/// `logs`): the platform's per-user app data folder, found one way for the whole app. [macOS] stands in for
/// the platform check, for tests.
String appDataDir([Map<String, String>? environment, bool? macOS]) {
  final env = environment ?? Platform.environment;
  final home = userHome(env) ?? '.';
  if (macOS ?? Platform.isMacOS) return '$home/Library/Application Support/PaperAgent';
  if (Platform.isWindows) return '${env['APPDATA'] ?? '$home\\AppData\\Roaming'}\\PaperAgent';
  return '${env['XDG_DATA_HOME'] ?? '$home/.local/share'}/paperagent';
}
