import 'dart:io';

import 'renamed_data.dart';

/// The user's home folder, found one way for the whole app: `USERPROFILE` on
/// Windows (where a shell may set `HOME` to a path of its own), `HOME`
/// elsewhere. Null when the environment gives neither.
String? userHome([Map<String, String>? environment]) {
  final env = environment ?? Platform.environment;
  return Platform.isWindows ? env['USERPROFILE'] ?? env['HOME'] : env['HOME'];
}

/// The app's id: the Mac app's bundle id (macos/Runner/Configs/AppInfo.xcconfig), under which WebKit keeps the
/// browser's logins, and the Linux application id (linux/CMakeLists.txt), which names the Linux data folder.
const appId = 'it.daylex.desktop';

/// The app's folder name in the per-user app data folders of Windows and the Mac.
const _appFolderName = 'Daylex';

/// The developer configuration folder in the home folder.
const configDirName = '.daylex';

/// The developer configuration that names another server (`{"url": …}`); null where there is no home folder.
File? serverConfigFile([Map<String, String>? environment]) {
  final home = userHome(environment);
  return home == null ? null : File('$home/$configDirName/server.json');
}

/// The folder the app keeps its own files in on this computer (the lawyer's work in `data`, diagnostics in
/// `logs`): the platform's per-user app data folder, found one way for the whole app. Until [migrateRenamedData] could
/// move it there, the folder an app from before the rename made (rfc/054). [macOS] stands in for the platform check,
/// for tests.
String appDataDir([Map<String, String>? environment, bool? macOS]) {
  final current = currentAppDataDir(environment, macOS);
  final legacy = legacyAppDataDir(environment, macOS);
  return !Directory(current).existsSync() && Directory(legacy).existsSync() ? legacy : current;
}

/// The app data folder of Daylex itself, where [migrateRenamedData] moves the one from before the rename. On Linux it
/// is named after [appId], where Flutter puts an app's support folder: install-linux.sh installs the app itself in
/// `~/.local/share/daylex/app`, so a data folder `daylex` would exist from the first install on and the move would
/// never happen.
String currentAppDataDir([Map<String, String>? environment, bool? macOS]) {
  final xdg = !(macOS ?? Platform.isMacOS) && !Platform.isWindows;
  return appDataFolder(xdg ? appId : _appFolderName, environment, macOS);
}

/// The per-user app data folder called [name] on this platform, in lower case on Linux.
String appDataFolder(String name, [Map<String, String>? environment, bool? macOS]) {
  final env = environment ?? Platform.environment;
  final home = userHome(env) ?? '.';
  if (macOS ?? Platform.isMacOS) return '$home/Library/Application Support/$name';
  if (Platform.isWindows) return '${env['APPDATA'] ?? '$home\\AppData\\Roaming'}\\$name';
  return '${env['XDG_DATA_HOME'] ?? '$home/.local/share'}/${name.toLowerCase()}';
}
