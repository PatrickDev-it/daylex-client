import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/platform/diagnostic_log.dart';
import '../../core/platform/user_dirs.dart';
import '../../l10n/l10n.dart';
import 'installer.dart';
import 'release.dart';
import 'update_channel.g.dart';
import 'update_source.dart';

export 'installer.dart' show InstallProblem, UpdateSplash;
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

/// The version the app was just restarted into, and what it improves: shown to the lawyer once.
@immutable
class WhatsNew {
  const WhatsNew({required this.version, required this.notes});

  final String version;

  /// The release's notes, as its signed manifest carried them.
  final String notes;

  List<String> get improvements => Release.improvementsOf(notes);
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
    this.launching = false,
    this.atLaunch = false,
    this.news = const [],
    this.whatsNew,
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

  /// The app has just opened and waits, [UpdateEnvironment.launchWait] at most, to learn whether a newer version
  /// exists: the update screen says it is checking.
  final bool launching;

  /// [release] was found as the app opened: it is downloaded and installed before the app is used, on the update
  /// screen. A release found later waits for the lawyer's restart from the sidebar button.
  final bool atLaunch;

  /// What [release] improves; empty when this computer was already shown the very same list.
  final List<String> news;

  /// The version the app was just restarted into, until the lawyer has read what it brought.
  final WhatsNew? whatsNew;

  /// Whether the sidebar shows the update button.
  bool get offered => const {
    UpdatePhase.downloading,
    UpdatePhase.ready,
    UpdatePhase.installing,
    UpdatePhase.blocked,
  }.contains(phase);

  /// Whether the update screen covers the app: while the opening check runs, while the update it found is
  /// downloaded and installed, and during any restart into a new version.
  bool get covering =>
      launching ||
      phase == UpdatePhase.installing ||
      (atLaunch && const {UpdatePhase.downloading, UpdatePhase.ready}.contains(phase));

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
    bool? launching,
    bool? atLaunch,
    List<String>? news,
    WhatsNew? Function()? whatsNew,
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
    launching: launching ?? this.launching,
    atLaunch: atLaunch ?? this.atLaunch,
    news: news ?? this.news,
    whatsNew: whatsNew != null ? whatsNew() : this.whatsNew,
  );
}

/// The running app's version and build, as the release that was installed declares them.
typedef InstalledVersion = ({String version, int build});

/// What the update checks need from this computer, overridden in tests.
class UpdateEnvironment {
  const UpdateEnvironment({
    required this.source,
    required this.installer,
    required this.installed,
    required this.dir,
    this.quit = _quitNow,
    this.launchWait = Duration.zero,
  });

  /// How long the opening check may take before the app opens anyway (no network, a slow server).
  static const launchCheck = Duration(seconds: 3);

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
      launchWait: launchCheck,
    );
  }

  final UpdateSource source;
  final Installer installer;
  final Future<InstalledVersion?> Function() installed;

  /// The downloads, the installer's work folder and the record of the last installation.
  final Directory dir;

  /// Ends this process once the work is saved, so the installer can replace the app and start the new one.
  final void Function() quit;

  /// How long the app, as it opens, waits for the answer to its first check. A newer version known within it is
  /// installed before the app is used; zero: never, every update waits for the lawyer's restart.
  final Duration launchWait;
}

void _quitNow() => exit(0);

final updateEnvironmentProvider = Provider<UpdateEnvironment?>((ref) {
  final env = UpdateEnvironment.forThisComputer();
  ref.onDispose(() => env?.source.close());
  return env;
});

/// Keeps the app on the newest published version. As the app opens it checks first: a newer version is downloaded
/// and installed then and there, on the update screen, and the app comes back as the new version and says what it
/// improves. Later it checks every [_interval] and when the app comes back to the foreground, downloads a newer
/// release by itself and installs it when the lawyer restarts from the update button. A release is installed only
/// if the release key signed it and its archive hashes to what the signature covers. If a restart did not take,
/// the app does not try again by itself: the lawyer is told.
class UpdateController extends Notifier<UpdateState> {
  static const _interval = Duration(minutes: 30);

  /// A return to the foreground sooner than this after a check does not check again.
  static const _resumeGap = Duration(minutes: 5);

  static final _log = DiagnosticLog.open('update.log');

  /// Where the checks and the installer write what they did: the lawyer is pointed here when an update fails.
  static String get logPath => _log?.file.path ?? 'update.log';

  Timer? _timer;
  Timer? _launchTimer;
  AppLifecycleListener? _lifecycle;
  DateTime? _checkedAt;
  File? _archive;

  /// The build the last restart was meant to install, while the app is still older than it.
  int? _attempted;

  /// The notes this computer has already shown after an update (seen.json).
  String? _seen;

  /// An update just took but its record carries no notes (written by a version before they were kept): the
  /// published release, which is the one now running, says what it improves.
  bool _announce = false;

  @override
  UpdateState build() {
    final env = ref.watch(updateEnvironmentProvider);
    ref.onDispose(() {
      _timer?.cancel();
      _launchTimer?.cancel();
      _lifecycle?.dispose();
    });
    if (env == null) return const UpdateState();
    scheduleMicrotask(() => _start(env));
    return UpdateState(phase: UpdatePhase.idle, launching: env.launchWait > Duration.zero);
  }

  File _record(UpdateEnvironment env) => File('${env.dir.path}${Platform.pathSeparator}state.json');

  File _seenRecord(UpdateEnvironment env) => File('${env.dir.path}${Platform.pathSeparator}seen.json');

  Future<void> _start(UpdateEnvironment env) async {
    final installed = await env.installed();
    if (!ref.mounted) return;
    if (installed == null) {
      _log?.add('the app has no build number: it does not update itself');
      state = const UpdateState();
      return;
    }
    state = state.copyWith(version: installed.version, build: installed.build);
    _seen = _readSeen(env);
    final record = _readAttempt(env);
    _attempted = record?.build;
    if (record != null && installed.build >= record.build) {
      _log?.add('now build ${installed.build}: the update to ${record.build} took');
      final notes = record.notes.trim();
      _announce = notes.isEmpty;
      _tell(record.version ?? installed.version, notes);
      _attempted = null;
      _forgetAttempt(env);
    } else if (record != null) {
      _log?.add('still build ${installed.build} after restarting to install ${record.build}: see the installer lines');
    }
    _timer = Timer.periodic(_interval, (_) => check());
    _lifecycle = AppLifecycleListener(
      onResume: () {
        final last = _checkedAt;
        if (last == null || DateTime.now().difference(last) > _resumeGap) check();
      },
    );
    if (state.launching) {
      _launchTimer = Timer(env.launchWait, () {
        if (!ref.mounted || !state.launching) return;
        _log?.add('no answer within ${env.launchWait.inSeconds} s of opening: the app opens, the check goes on');
        state = state.copyWith(launching: false);
      });
    }
    await check();
  }

  /// Looks for a newer release and, if there is one, downloads it. Quiet when offline: the next check retries.
  /// One found as the app opens is then installed at once ([UpdateState.atLaunch]).
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
        if (_announce && release.build == build) _tell(release.version, release.notes.trim());
        _announce = false;
        state = UpdateState(phase: UpdatePhase.idle, version: state.version, build: build, whatsNew: state.whatsNew);
        _clean(env, keep: null);
        return;
      }
      // Still opening, and nothing stands in the way: the lawyer gets the new version before the old one is used.
      final atLaunch = state.launching && env.installer.problem() == null && !_failed(release);
      if (atLaunch) _log?.add('build ${release.build} found as the app opened: it installs now');
      if (state.release?.build != release.build || _archive == null || !_archive!.existsSync()) {
        state = state.copyWith(
          phase: UpdatePhase.downloading,
          release: release,
          progress: 0,
          launching: false,
          atLaunch: atLaunch,
          news: _news(release),
        );
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
      _settle(env, release, atLaunch: atLaunch);
      if (state.atLaunch) await install();
    } catch (e) {
      _log?.add('check failed: $e');
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: state.phase == UpdatePhase.downloading ? UpdatePhase.idle : null,
        checking: false,
        checkFailed: true,
        launching: false,
        atLaunch: false,
      );
    }
  }

  /// Shows what the version now running improves, unless it improves nothing listed or was already shown.
  void _tell(String version, String notes) {
    if (Release.improvementsOf(notes).isEmpty || notes == _seen) return;
    state = state.copyWith(whatsNew: () => WhatsNew(version: version, notes: notes));
  }

  bool _failed(Release release) => _attempted != null && _attempted! >= release.build;

  /// What [release] improves, unless the lawyer was already shown exactly that.
  List<String> _news(Release release) => release.notes.trim() == _seen ? const [] : release.improvements;

  /// A downloaded [release]: ready to install, unless this copy of the app cannot replace itself or a restart
  /// already failed to install it. [atLaunch]: found as the app opened, it installs at once.
  void _settle(UpdateEnvironment env, Release release, {bool atLaunch = false}) {
    final problem = env.installer.problem();
    final failed = _failed(release);
    final phase = problem != null || failed ? UpdatePhase.blocked : UpdatePhase.ready;
    state = UpdateState(
      phase: phase,
      version: state.version,
      build: state.build,
      release: release,
      progress: 1,
      problem: problem,
      installFailed: failed,
      atLaunch: atLaunch && phase == UpdatePhase.ready,
      news: _news(release),
      whatsNew: state.whatsNew,
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
      state = state.copyWith(phase: UpdatePhase.blocked, problem: () => problem, atLaunch: false);
      return;
    }
    state = state.copyWith(phase: UpdatePhase.installing);
    final l = ref.read(l10nProvider);
    Process? updater;
    try {
      await env.source.verifyArchive(release, archive);
      _writeAttempt(env, release);
      _log?.add('restarting to install ${release.file} over ${env.installer.target}');
      updater = await env.installer.launch(
        archive,
        work: Directory('${env.dir.path}${Platform.pathSeparator}work'),
        log: _log?.file ?? File('${env.dir.path}${Platform.pathSeparator}update.log'),
        expectedSha256: release.sha256,
        splash: UpdateSplash(
          title: l.updateScreenTitle,
          message: state.news.isEmpty ? l.updateSplashMessage : l.updateSplashNews(state.news.length),
        ),
      );
    } catch (e) {
      _log?.add('could not start the installer: $e');
      _forgetAttempt(env);
      _attempted = release.build;
      if (ref.mounted) _settle(env, release);
      return;
    }
    // The app's own exit handlers decide, as for the window's close button: they save the work and, if it cannot
    // be saved, ask the lawyer. Not exitApplication(cancelable): the Windows engine answers "cancel" to it at once
    // and quits later by itself, so the installer it had just started was killed and the app never came back.
    final response = await WidgetsBinding.instance.handleRequestAppExit();
    if (response == AppExitResponse.exit) return env.quit();
    updater?.kill();
    _log?.add('the app did not quit: the installer gives up and the update waits');
    _forgetAttempt(env);
    if (ref.mounted) _settle(env, release);
  }

  /// The lawyer has read what the new version brought: it is not shown again, nor announced again as news.
  void seen() {
    final env = ref.read(updateEnvironmentProvider);
    final shown = state.whatsNew;
    if (env == null || shown == null) return;
    _seen = shown.notes;
    try {
      env.dir.createSync(recursive: true);
      _seenRecord(env).writeAsStringSync(jsonEncode({'notes': shown.notes}), flush: true);
    } on FileSystemException catch (e) {
      _log?.add('could not write ${_seenRecord(env).path}: $e');
    }
    state = state.copyWith(whatsNew: () => null);
  }

  String? _readSeen(UpdateEnvironment env) {
    try {
      final file = _seenRecord(env);
      if (!file.existsSync()) return null;
      return (jsonDecode(file.readAsStringSync()) as Map<String, dynamic>)['notes'] as String?;
    } catch (e) {
      _log?.add('unreadable ${_seenRecord(env).path}: $e');
      return null;
    }
  }

  ({int build, String? version, String notes})? _readAttempt(UpdateEnvironment env) {
    try {
      final file = _record(env);
      if (!file.existsSync()) return null;
      final record = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final build = record['attempted'] as int?;
      if (build == null) return null;
      return (build: build, version: record['version'] as String?, notes: record['notes'] as String? ?? '');
    } catch (e) {
      _log?.add('unreadable ${_record(env).path}: $e');
      return null;
    }
  }

  void _writeAttempt(UpdateEnvironment env, Release release) {
    env.dir.createSync(recursive: true);
    _record(env).writeAsStringSync(
      jsonEncode({'attempted': release.build, 'version': release.version, 'notes': release.notes}),
      flush: true,
    );
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
