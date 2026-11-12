import 'dart:convert';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/features/update/installer.dart';
import 'package:paper_agent/features/update/release.dart';
import 'package:paper_agent/features/update/update_controller.dart';
import 'package:paper_agent/features/update/update_source.dart';
import 'package:paper_agent/ui/sidebar/update_button.dart';

import 'test_app.dart';

/// A release key made for the test, and manifests signed with it as release.py signs them.
class _Signer {
  _Signer._(this._pair, this.publicKey);

  static Future<_Signer> create() async {
    final pair = await Ed25519().newKeyPair();
    final public = await pair.extractPublicKey();
    return _Signer._(pair, base64.encode(public.bytes));
  }

  final SimpleKeyPair _pair;
  final String publicKey;

  Future<String> manifest(Map<String, Object?> payload) async {
    final text = jsonEncode(payload);
    final signature = await Ed25519().sign(utf8.encode(text), keyPair: _pair);
    return jsonEncode({'payload': text, 'signature': base64.encode(signature.bytes)});
  }
}

Future<String> _sha(List<int> bytes) async =>
    [for (final b in (await Sha256().hash(bytes)).bytes) b.toRadixString(16).padLeft(2, '0')].join();

Map<String, Object?> _payload({
  String platform = 'windows',
  int build = 2,
  String? file,
  required List<int> archive,
  required String sha,
}) => {
  'platform': platform,
  'version': '0.2.0',
  'build': build,
  'file': file ?? 'daylex-$platform-0.2.0-b$build.zip',
  'size': archive.length,
  'sha256': sha,
  'notes': 'Novità di prova',
  'published': '2026-10-27T10:00:00Z',
};

/// Serves a channel folder the way Caddy serves /updates.
class _Channel {
  _Channel._(this._server);

  static Future<_Channel> start() async => _Channel._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0))
    .._serve();

  final HttpServer _server;
  final files = <String, List<int>>{};
  var requests = 0;

  String get url => 'http://${_server.address.host}:${_server.port}';

  void _serve() => _server.listen((request) {
    requests++;
    final body = files[request.uri.pathSegments.last];
    request.response.statusCode = body == null ? HttpStatus.notFound : HttpStatus.ok;
    if (body != null) request.response.add(body);
    request.response.close();
  });

  Future<void> close() => _server.close(force: true);
}

class _FakeInstaller extends Installer {
  _FakeInstaller([this._problem]);

  final InstallProblem? _problem;
  _FakeProcess? started;

  @override
  String get target => 'C:\\Daylex';

  @override
  InstallProblem? problem() => _problem;

  @override
  Future<Process?> launch(File archive, {required Directory work, required File log, required String expectedSha256}) async =>
      started = _FakeProcess();
}

/// The installer script: all the app may do to it is stop it.
class _FakeProcess extends Fake implements Process {
  var killed = false;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => killed = true;
}

class _FixedUpdate extends UpdateController {
  _FixedUpdate(this._state);

  final UpdateState _state;

  @override
  UpdateState build() => _state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The test binding answers every HttpClient request with 400; these tests talk to a real local server.
  HttpOverrides.global = null;
  final archive = utf8.encode('the new version, zipped');

  group('Release.verify', () {
    late _Signer signer;
    late String sha;
    setUpAll(() async {
      signer = await _Signer.create();
      sha = await _sha(archive);
    });

    test('accepts a manifest the release key signed', () async {
      final manifest = await signer.manifest(_payload(archive: archive, sha: sha));
      final release = await Release.verify(manifest, publicKey: signer.publicKey, platform: 'windows');
      expect(release.build, 2);
      expect(release.version, '0.2.0');
      expect(release.file, 'daylex-windows-0.2.0-b2.zip');
      expect(release.notes, 'Novità di prova');
    });

    test('refuses a manifest changed after signing', () async {
      final manifest = jsonDecode(await signer.manifest(_payload(archive: archive, sha: sha))) as Map;
      final tampered = jsonEncode({
        'payload': (manifest['payload'] as String).replaceFirst('"build":2', '"build":99'),
        'signature': manifest['signature'],
      });
      expect(
        Release.verify(tampered, publicKey: signer.publicKey, platform: 'windows'),
        throwsA(isA<ReleaseRejected>()),
      );
    });

    test('refuses a manifest signed by another key', () async {
      final other = await _Signer.create();
      final manifest = await other.manifest(_payload(archive: archive, sha: sha));
      expect(
        Release.verify(manifest, publicKey: signer.publicKey, platform: 'windows'),
        throwsA(isA<ReleaseRejected>()),
      );
    });

    test("refuses another platform's release", () async {
      final manifest = await signer.manifest(_payload(platform: 'macos', archive: archive, sha: sha));
      expect(
        Release.verify(manifest, publicKey: signer.publicKey, platform: 'windows'),
        throwsA(isA<ReleaseRejected>()),
      );
    });

    test('refuses an archive name that could leave the download folder', () async {
      for (final file in ['../daylex-windows-0.2.0-b2.zip', 'daylex-windows-0.2.0-b2.exe', 'other.zip']) {
        final manifest = await signer.manifest(_payload(file: file, archive: archive, sha: sha));
        expect(
          Release.verify(manifest, publicKey: signer.publicKey, platform: 'windows'),
          throwsA(isA<ReleaseRejected>()),
          reason: file,
        );
      }
    });

    test('refuses garbage', () {
      expect(
        Release.verify('not json', publicKey: 'AAAA', platform: 'windows'),
        throwsA(isA<ReleaseRejected>()),
      );
    });
  });

  group('UpdateSource', () {
    late _Signer signer;
    late _Channel channel;
    late Directory dir;
    late UpdateSource source;
    setUp(() async {
      signer = await _Signer.create();
      channel = await _Channel.start();
      dir = await Directory.systemTemp.createTemp('daylex-update-test');
      source = UpdateSource(channel: channel.url, publicKey: signer.publicKey, platform: 'windows');
    });
    tearDown(() async {
      source.close();
      await channel.close();
      await dir.delete(recursive: true);
    });

    test('refuses an archive changed after its successful download', () async {
      channel.files['windows.json'] = utf8.encode(await signer.manifest(_payload(archive: archive, sha: await _sha(archive))));
      channel.files['daylex-windows-0.2.0-b2.zip'] = archive;
      final release = await source.latest();
      final file = await source.download(release, dir);
      file.writeAsBytesSync(List.filled(archive.length, 0));
      await expectLater(source.verifyArchive(release, file), throwsA(isA<ReleaseRejected>()));
    });

    test('downloads the archive the manifest describes, and reuses it once verified', () async {
      channel.files['windows.json'] = utf8.encode(
        await signer.manifest(_payload(archive: archive, sha: await _sha(archive))),
      );
      channel.files['daylex-windows-0.2.0-b2.zip'] = archive;
      final release = await source.latest();
      final progress = <double>[];
      final file = await source.download(release, dir, onProgress: progress.add);
      expect(file.readAsBytesSync(), archive);
      expect(progress.last, 1);
      expect(File('${file.path}.part').existsSync(), isFalse);

      final served = channel.requests;
      await source.download(release, dir);
      expect(channel.requests, served, reason: 'a verified archive on disk is not downloaded again');
    });

    test('refuses an archive that does not hash to the manifest, and keeps nothing', () async {
      channel.files['windows.json'] = utf8.encode(
        await signer.manifest(_payload(archive: archive, sha: await _sha(archive))),
      );
      channel.files['daylex-windows-0.2.0-b2.zip'] = utf8.encode('the new version, zippeD');
      final release = await source.latest();
      await expectLater(source.download(release, dir), throwsA(isA<ReleaseRejected>()));
      expect(dir.listSync(), isEmpty);
    });
  });

  group('UpdateController', () {
    late _Signer signer;
    late _Channel channel;
    late Directory dir;
    setUp(() async {
      signer = await _Signer.create();
      channel = await _Channel.start();
      dir = await Directory.systemTemp.createTemp('daylex-update-test');
      channel.files['windows.json'] = utf8.encode(
        await signer.manifest(_payload(archive: archive, sha: await _sha(archive))),
      );
      channel.files['daylex-windows-0.2.0-b2.zip'] = archive;
    });
    tearDown(() async {
      await channel.close();
      await dir.delete(recursive: true);
    });

    Future<(ProviderContainer, UpdateState)> start(int installedBuild, {Installer? installer, void Function()? quit}) async {
      final env = UpdateEnvironment(
        source: UpdateSource(channel: channel.url, publicKey: signer.publicKey, platform: 'windows'),
        installer: installer ?? _FakeInstaller(),
        installed: () async => (version: '0.1.0', build: installedBuild),
        dir: dir,
        quit: quit ?? () => fail('the app quit'),
      );
      final container = ProviderContainer(overrides: [updateEnvironmentProvider.overrideWithValue(env)]);
      addTearDown(container.dispose);
      container.listen(updateProvider, (_, _) {});
      for (var i = 0; i < 200; i++) {
        final state = container.read(updateProvider);
        if (state.build != null && !state.checking && state.phase != UpdatePhase.downloading) return (container, state);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      fail('the check did not settle');
    }

    Future<UpdateState> settle(int installedBuild, {Installer? installer}) async =>
        (await start(installedBuild, installer: installer)).$2;

    /// Restarts to install with the app's exit handlers answering [response], as the close button's would.
    Future<({_FakeProcess installer, int quits})> restart(AppExitResponse response) async {
      final listener = AppLifecycleListener(onExitRequested: () async => response);
      addTearDown(listener.dispose);
      final installer = _FakeInstaller();
      var quits = 0;
      final (container, state) = await start(1, installer: installer, quit: () => quits++);
      expect(state.phase, UpdatePhase.ready);
      await container.read(updateProvider.notifier).install();
      return (installer: installer.started!, quits: quits);
    }

    test('quits for the installer and leaves it running when the work is saved', () async {
      final result = await restart(AppExitResponse.exit);
      expect(result.quits, 1);
      expect(result.installer.killed, isFalse);
    });

    test('stays open and stops the installer when the lawyer keeps unsaved work', () async {
      final result = await restart(AppExitResponse.cancel);
      expect(result.quits, 0);
      expect(result.installer.killed, isTrue);
    });

    test('downloads a newer release and offers the restart', () async {
      final state = await settle(1);
      expect(state.phase, UpdatePhase.ready);
      expect(state.offered, isTrue);
      expect(state.release?.version, '0.2.0');
      expect(File('${dir.path}${Platform.pathSeparator}daylex-windows-0.2.0-b2.zip').existsSync(), isTrue);
    });

    test('stays quiet when the installed version is the newest', () async {
      final state = await settle(2);
      expect(state.phase, UpdatePhase.idle);
      expect(state.offered, isFalse);
    });

    test('explains instead of offering a restart when the app cannot replace itself', () async {
      final state = await settle(1, installer: _FakeInstaller(InstallProblem.notWritable));
      expect(state.phase, UpdatePhase.blocked);
      expect(state.problem, InstallProblem.notWritable);
    });

    test('does not loop on a restart that did not install the release', () async {
      File('${dir.path}${Platform.pathSeparator}state.json').writeAsStringSync(jsonEncode({'attempted': 2}));
      final state = await settle(1);
      expect(state.phase, UpdatePhase.blocked);
      expect(state.installFailed, isTrue);
    });

    test('forgets the attempt once the new version runs', () async {
      final record = File('${dir.path}${Platform.pathSeparator}state.json')
        ..writeAsStringSync(jsonEncode({'attempted': 2}));
      await settle(2);
      expect(record.existsSync(), isFalse);
    });
  });

  group('UpdateButton', () {
    const release = Release(
      platform: 'windows',
      version: '0.2.0',
      build: 2,
      file: 'daylex-windows-0.2.0-b2.zip',
      size: 1,
      sha256: '',
    );

    // Keyed: a ProviderScope keeps its first overrides.
    Widget button(UpdateState state) => ProviderScope(
      key: ValueKey(state.phase),
      overrides: [updateProvider.overrideWith(() => _FixedUpdate(state))],
      child: testApp(const Scaffold(body: SizedBox(width: 260, child: UpdateButton()))),
    );

    testWidgets('is not there until a newer version arrives', (tester) async {
      await tester.pumpWidget(button(const UpdateState(phase: UpdatePhase.idle)));
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('shows the download, then the restart', (tester) async {
      await tester.pumpWidget(
        button(const UpdateState(phase: UpdatePhase.downloading, release: release, progress: 0.42)),
      );
      expect(find.text(itL10n.updateDownloading(42)), findsOneWidget);

      await tester.pumpWidget(button(const UpdateState(phase: UpdatePhase.ready, release: release, progress: 1)));
      expect(find.text(itL10n.updateReady), findsOneWidget);
    });

    testWidgets('says when the update needs the lawyer', (tester) async {
      await tester.pumpWidget(
        button(
          const UpdateState(phase: UpdatePhase.blocked, release: release, problem: InstallProblem.notInstalled),
        ),
      );
      expect(find.text(itL10n.updateBlocked), findsOneWidget);
    });
  });
}
