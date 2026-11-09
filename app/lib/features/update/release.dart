import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

/// The name this computer's releases are published under (`<channel>/<platform>.json`, written by
/// paper_agent_server/scripts/release.py): null where the app does not update itself.
String? get updatePlatform => Platform.isWindows
    ? 'windows'
    : Platform.isMacOS
    ? 'macos'
    : Platform.isLinux
    ? 'linux'
    : null;

/// Why a manifest or an archive was refused: the app installs only what the release key signed.
class ReleaseRejected implements Exception {
  const ReleaseRejected(this.reason);

  final String reason;

  @override
  String toString() => 'ReleaseRejected: $reason';
}

/// A published version of the app, as its signed manifest describes it.
class Release {
  const Release({
    required this.platform,
    required this.version,
    required this.build,
    required this.file,
    required this.size,
    required this.sha256,
    this.notes = '',
    this.published,
  });

  /// The archive names release.py writes. Checked because [file] becomes a path on this computer.
  static final _fileName = RegExp(r'^daylex-(windows|macos|linux)-[0-9A-Za-z.-]+-b\d+\.zip$');
  static final _hex = RegExp(r'^[0-9a-f]{64}$');

  final String platform;

  /// What the lawyer reads ("0.2.0").
  final String version;

  /// What decides which version is newer: pubspec's `+BUILD`, which every release raises.
  final int build;

  /// The archive, next to the manifest.
  final String file;
  final int size;

  /// Lowercase hex: the archive is installed only if it hashes to this.
  final String sha256;
  final String notes;
  final DateTime? published;

  /// The release [manifest] describes, once its signature verifies with [publicKey] (raw Ed25519, base64) and
  /// it is a well-formed release for [platform]. Anything else throws [ReleaseRejected].
  static Future<Release> verify(String manifest, {required String publicKey, required String platform}) async {
    final String payload;
    final List<int> signature;
    try {
      final outer = jsonDecode(manifest) as Map<String, dynamic>;
      payload = outer['payload'] as String;
      signature = base64.decode(outer['signature'] as String);
    } catch (e) {
      throw ReleaseRejected('unreadable manifest: $e');
    }
    final key = SimplePublicKey(base64.decode(publicKey), type: KeyPairType.ed25519);
    final valid = await Ed25519().verify(utf8.encode(payload), signature: Signature(signature, publicKey: key));
    if (!valid) throw const ReleaseRejected('the signature does not verify with the release key');

    final Release release;
    try {
      final p = jsonDecode(payload) as Map<String, dynamic>;
      release = Release(
        platform: p['platform'] as String,
        version: p['version'] as String,
        build: p['build'] as int,
        file: p['file'] as String,
        size: p['size'] as int,
        sha256: p['sha256'] as String,
        notes: p['notes'] as String? ?? '',
        published: DateTime.tryParse(p['published'] as String? ?? ''),
      );
    } catch (e) {
      throw ReleaseRejected('unreadable release: $e');
    }
    if (release.platform != platform) throw ReleaseRejected('a release for ${release.platform}, not $platform');
    if (!_fileName.hasMatch(release.file) || !release.file.startsWith('daylex-$platform-')) {
      throw ReleaseRejected('unexpected archive name ${release.file}');
    }
    if (!_hex.hasMatch(release.sha256) || release.size <= 0 || release.build <= 0) {
      throw const ReleaseRejected('a release without a usable size, hash or build');
    }
    return release;
  }
}
