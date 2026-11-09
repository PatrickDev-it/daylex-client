import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show AppExitResponse, AppExitType;

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/platform/diagnostic_log.dart';
import '../../core/platform/user_dirs.dart';
import 'installer.dart';
import 'release.dart';
import 'update_channel.g.dart';
import 'update_source.dart';

export 'installer.dart' show InstallProblem;
export 'release.dart' show Release;

/// Where the update stands, as the sidebar button and the settings show it.
enum UpdatePhase {
  /// This build does not update itself (no channel built in, an unsupported platform, tests).
  off,

  /// Nothing newer, or not checked yet.
  idle,

  /// A newer version is being downloaded.
  downloading,

  /// A newer version is downloaded and verified: a restart installs it.
  ready,

  /// The app is quitting so the installer can run.
  installing,

  /// A newer version exists but cannot be installed by itself (see [UpdateState.problem]) or its last
  /// installation did not take (see [UpdateState.installFailed]).
  blocked,
}

@immutable
class UpdateState {
  const UpdateState({
    this.phase = UpdatePhase.off,
    this.version,
    this.build,
    this.release,
    this.progress = 0,
    this.checking = false,
    this.checkFailed = false,
    this.problem,
    this.installFailed = false,
  });

  final UpdatePhase phase;

  /// The running app's version and build, once read.
  final String? version;
  final int? build;

  /// The newer release, from [UpdatePhase.downloading] on.
  final Release? release;

  /// Of the download, 0 to 1.
  final double progress;
  final bool checking;

  /// The last check or download did not complete: the next one tries again.
  final bool checkFailed;
  final InstallProblem? problem;

  /// The app was restarted to install [release] and is still the older version: the installer's log says why.
  final bool installFailed;

  /// Whether the sidebar shows the update button.
  bool get offered => const {
    UpdatePhase.downloading,
    UpdatePhase.ready,
    UpdatePhase.installing,
    UpdatePhase.blocked,
  }.contains(phase);

  UpdateState copyWith({
    UpdatePhase? phase,
    String? version,
    int? build,
    Release? release,
    double? progress,
    bool? checking,
    bool? checkFailed,
    InstallProblem? Function()? problem,
    bool? installFailed,
  }) => UpdateState(
    phase: phase ?? this.phase,
    version: version ?? this.version,
    build: build ?? this.build,
    release: release ?? this.release,
    progress: progress ?? this.progress,
    checking: checking ?? this.checking,
    checkFailed: checkFailed ?? this.checkFailed,
    problem: problem != null ? problem() : this.problem,
    installFailed: installFailed ?? this.installFailed,
  );
}

/// The running app's version and build, as the release that was installed declares them.
typedef InstalledVersion = ({String version, int build});

/// What the update checks need from this computer, overridden in tests.
class UpdateEnvironment {
  const UpdateEnvironment({required this.source, required this.installer, required this.installed, required this.dir});

  /// Null where this build does not update itself: no release key built in, a platform without releases, tests.
  static UpdateEnvironment? forThisComputer() {
    if (kIsWeb) return null;
    final platform = updatePlatform;
    final installer = Installer.forThisComputer();
    if (updateChannelUrl == null || releasePublicKey == null || platform == null || installer == null) return null;
    if (Platform.environment['FLUTTER_TEST'] == 'true') return null;
    return UpdateEnvironment(
      source: UpdateSource(channel: updateChannelUrl!, publicKey: releasePublicKey!, platform: platform),
      installer: installer,
      installed: () async {
        final info = await PackageInfo.fromPlatform();
        final build = int.tryParse(info.buildNumber);
        return build == null ? null : (version: info.version, build: build);
      },
      dir: Directory('${appDataDir()}${Platform.pathSeparator}updates'),
    );
  }

  final UpdateSource source;
  final Installer installer;
  final Future<InstalledVersion?> Function() installed;

  /// The downloads, the installer's work folder and the record of the last installation.
  final Directory dir;
}

final updateEnvironmentProvider = Provider<UpdateEnvironment?>((ref) {
  final env = UpdateEnvironment.forThisComputer();
  ref.onDispose(() => env?.source.close());
  return env;
});

/// Keeps the app on the newest published version: it checks at start, every [_interval] and when the app comes
/// back to the foreground; downloads a newer release by itself; and installs it when the lawyer restarts from
/// the update button. A release is installed only if the release key signed it and its archive hashes to what
/// the signature covers. If a restart did not take, the app does not try again by itself: the lawyer is told.
class UpdateController extends Notifier<UpdateState> {
  static const _interval = Duration(minutes: 30);

  /// A return to the foreground sooner than this after a check does not check again.
  static const _resumeGap = Duration(minutes: 5);

  static final _log = DiagnosticLog.open('update.log');

  /// Where the checks and the installer write what they did: the lawyer is pointed here when an update fails.
  static String get logPath => _log?.file.path ?? 'update.log';

  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  DateTime? _checkedAt;
  File? _archive;

  /// The build the last restart was meant to install, while the app is still older than it.
  int? _attempted;

  @override
  UpdateState build() {
    final env = ref.watch(updateEnvironmentProvider);
    ref.onDispose(() {
      _timer?.cancel();
      _lifecycle?.dispose();
    });
    if (env == null) return const UpdateState();
    scheduleMicrotask(() => _start(env));
    return const UpdateState(phase: UpdatePhase.idle);
  }

  File _record(UpdateEnvironment env) => File('${env.dir.path}${Platform.pathSeparator}state.json');

  Future<void> _start(UpdateEnvironment env) async {
    final installed = await env.installed();
    if (!ref.mounted) return;
    if (installed == null) {
      _log?.add('the app has no build number: it does not update itself');
      state = const UpdateState();
      return;
    }
    state = state.copyWith(version: installed.version, build: installed.build);
    _attempted = _readAttempt(env);
    if (_attempted != null && installed.build >= _attempted!) {
      _log?.add('now build ${installed.build}: the update to $_attempted took');
      _attempted = null;
      _forgetAttempt(env);
    } else if (_attempted != null) {
      _log?.add('still build ${installed.build} after restarting to install $_attempted: see the installer lines');
    }
    _timer = Timer.periodic(_interval, (_) => check());
    _lifecycle = AppLifecycleListener(
      onResume: () {
        final last = _checkedAt;
        if (last == null || DateTime.now().difference(last) > _resumeGap) check();
      },
    );
    await check();
  }

  /// Looks for a newer release and, if there is one, downloads it. Quiet when offline: the next check retries.
  Future<void> check() async {
    final env = ref.read(updateEnvironmentProvider);
    final build = state.build;
    if (env == null || build == null || state.checking) return;
    if (const {UpdatePhase.downloading, UpdatePhase.installing}.contains(state.phase)) return;
    _checkedAt = DateTime.now();
    state = state.copyWith(checking: true);
    try {
      final release = await env.source.latest();
      if (!ref.mounted) return;
      if (release.build <= build) {
        state = UpdateState(phase: UpdatePhase.idle, version: state.version, build: build);
        _clean(env, keep: null);
        return;
      }
      if (state.release?.build != release.build || _archive == null || !_archive!.existsSync()) {
        state = state.copyWith(phase: UpdatePhase.downloading, release: release, progress: 0);
        _archive = await env.source.download(
          release,
          env.dir,
          onProgress: (p) {
            if (ref.mounted && state.phase == UpdatePhase.downloading) state = state.copyWith(progress: p);
          },
        );
        if (!ref.mounted) return;
        _log?.add('downloaded and verified ${release.file}');
        _clean(env, keep: release.file);
      }
      _settle(env, release);
    } catch (e) {
      _log?.add('check failed: $e');
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: state.phase == UpdatePhase.downloading ? UpdatePhase.idle : null,
        checking: false,
        checkFailed: true,
      );
    }
  }

  /// A downloaded [release]: ready to install, unless this copy of the app cannot replace itself or a restart
  /// already failed to install it.
  void _settle(UpdateEnvironment env, Release release) {
    final problem = env.installer.problem();
    final failed = _attempted != null && _attempted! >= release.build;
    state = UpdateState(
      phase: problem != null || failed ? UpdatePhase.blocked : UpdatePhase.ready,
      version: state.version,
      build: state.build,
      release: release,
      progress: 1,
      problem: problem,
      installFailed: failed,
    );
  }

  /// Quits the app and installs the downloaded release, starting the new version. The work is saved by the
  /// app's own exit path. Also the lawyer's "try again" after a failed installation.
  Future<void> install() async {
    final env = ref.read(updateEnvironmentProvider);
    final release = state.release;
    final archive = _archive;
    if (env == null || release == null || archive == null || state.phase == UpdatePhase.installing) return;
    final problem = env.installer.problem();
    if (problem != null) {
      state = state.copyWith(phase: UpdatePhase.blocked, problem: () => problem);
      return;
    }
    state = state.copyWith(phase: UpdatePhase.installing);
    Process? updater;
    try {
      await env.source.verifyArchive(release, archive);
      _writeAttempt(env, release.build);
      _log?.add('restarting to install ${release.file} over ${env.installer.target}');
      updater = await env.installer.launch(
        archive,
        work: Directory('${env.dir.path}${Platform.pathSeparator}work'),
        log: _log?.file ?? File('${env.dir.path}${Platform.pathSeparator}update.log'),
        expectedSha256: release.sha256,
      );
    } catch (e) {
      _log?.add('could not start the installer: $e');
      _forgetAttempt(env);
      _attempted = release.build;
      if (ref.mounted) _settle(env, release);
      return;
    }
    // The way the window's close button quits: everything waiting to be saved is written first.
    final response = await ServicesBinding.instance.exitApplication(AppExitType.cancelable);
    if (response == AppExitResponse.exit) exit(0);
    updater?.kill();
    _log?.add('the app did not quit: the installer gives up and the update waits');
    _forgetAttempt(env);
    if (ref.mounted) _settle(env, release);
  }

  int? _readAttempt(UpdateEnvironment env) {
    try {
      final file = _record(env);
      if (!file.existsSync()) return null;
      return (jsonDecode(file.readAsStringSync()) as Map<String, dynamic>)['attempted'] as int?;
    } catch (e) {
      _log?.add('unreadable ${_record(env).path}: $e');
      return null;
    }
  }

  void _writeAttempt(UpdateEnvironment env, int build) {
    env.dir.createSync(recursive: true);
    _record(env).writeAsStringSync(jsonEncode({'attempted': build}), flush: true);
  }

  void _forgetAttempt(UpdateEnvironment env) {
    try {
      final file = _record(env);
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException catch (e) {
      _log?.add('could not delete ${_record(env).path}: $e');
    }
  }

  /// Deletes downloaded archives other than [keep]: one release on disk at most.
  void _clean(UpdateEnvironment env, {required String? keep}) {
    if (!env.dir.existsSync()) return;
    try {
      for (final f in env.dir.listSync().whereType<File>()) {
        final name = f.uri.pathSegments.last;
        if (name.startsWith('daylex-') && name != keep) f.deleteSync();
      }
    } on FileSystemException catch (e) {
      _log?.add('could not clean ${env.dir.path}: $e');
    }
  }
}

final updateProvider = NotifierProvider<UpdateController, UpdateState>(UpdateController.new);
