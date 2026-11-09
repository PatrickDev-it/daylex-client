import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

import 'release.dart';

/// Where the app's new versions come from: the signed manifest `<channel>/<platform>.json` and the archive it
/// names, both static files (scripts/release.py publishes them; Caddy serves them whether the agent is on or off).
class UpdateSource {
  UpdateSource({required this.channel, required this.publicKey, required this.platform})
    : _http = HttpClient()
        ..connectionTimeout = _connect
        ..idleTimeout = _connect;

  static const _connect = Duration(seconds: 15);

  /// A download that stops sending for this long has failed; the next check starts it again.
  static const _stalled = Duration(seconds: 60);

  /// More than any manifest: a larger answer is not one.
  static const _maxManifest = 64 * 1024;

  final String channel;
  final String publicKey;
  final String platform;
  final HttpClient _http;

  /// The release published for this platform, verified (see [Release.verify]). Throws on a network failure, an
  /// answer other than 200 and a manifest the release key did not sign.
  Future<Release> latest() async {
    final response = await _get(Uri.parse('$channel/$platform.json'));
    final bytes = <int>[];
    await for (final chunk in response.timeout(_stalled)) {
      bytes.addAll(chunk);
      if (bytes.length > _maxManifest) throw const ReleaseRejected('the manifest is too large');
    }
    // UTF-8, as release.py writes it: the signature covers the notes' accents byte for byte.
    return Release.verify(utf8.decode(bytes), publicKey: publicKey, platform: platform);
  }

  /// [release]'s archive in [dir], whole and hashing to the manifest's sha256: an earlier complete download is
  /// reused, a new one is written to `<file>.part` and renamed only once verified. [onProgress] gets 0 to 1.
  Future<File> download(Release release, Directory dir, {void Function(double)? onProgress}) async {
    final target = File('${dir.path}${Platform.pathSeparator}${release.file}');
    if (target.existsSync() && target.lengthSync() == release.size && await _sha256(target.openRead()) == release.sha256) {
      onProgress?.call(1);
      return target;
    }
    dir.createSync(recursive: true);
    final part = File('${target.path}.part');
    final response = await _get(Uri.parse('$channel/${release.file}'));
    final out = part.openWrite();
    final hash = Sha256().newHashSink();
    var received = 0;
    try {
      await for (final chunk in response.timeout(_stalled)) {
        received += chunk.length;
        if (received > release.size) throw const ReleaseRejected('the archive is larger than its manifest says');
        hash.add(chunk);
        out.add(chunk);
        onProgress?.call(received / release.size);
      }
      await out.flush();
    } finally {
      await out.close();
    }
    hash.close();
    final digest = _hex((await hash.hash()).bytes);
    if (received != release.size || digest != release.sha256) {
      _delete(part);
      throw const ReleaseRejected('the archive does not match its manifest');
    }
    if (target.existsSync()) target.deleteSync();
    return part.renameSync(target.path);
  }

  void close() => _http.close(force: true);

  /// A downloaded archive can change before the user clicks Install. Recheck at that boundary.
  Future<void> verifyArchive(Release release, File archive) async {
    if (!await archive.exists() || await archive.length() != release.size ||
        await _sha256(archive.openRead()) != release.sha256) {
      throw const ReleaseRejected('the downloaded archive changed before installation');
    }
  }

  Future<HttpClientResponse> _get(Uri uri) async {
    final request = await _http.getUrl(uri).timeout(_connect);
    request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    final response = await request.close().timeout(_connect);
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>().timeout(_stalled);
      throw HttpException('${response.statusCode} from $uri', uri: uri);
    }
    return response;
  }

  static Future<String> _sha256(Stream<List<int>> data) async {
    final hash = Sha256().newHashSink();
    await data.forEach(hash.add);
    hash.close();
    return _hex((await hash.hash()).bytes);
  }

  static String _hex(List<int> bytes) => [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')].join();

  static void _delete(File file) {
    try {
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException {
      // Left for the next download, which overwrites it.
    }
  }
}
