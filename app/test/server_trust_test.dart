import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daylex/core/platform/http_transport_io.dart' show serverHttpClient, trusting;
import 'package:daylex/core/platform/server_roots.dart';

/// The app reaches its server on a computer whose system store lacks the server's roots (rfc/053).
void main() {
  test('the roots carried are ISRG Root X1 and X2, byte for byte as Let\'s Encrypt publishes them', () async {
    expect([for (final pem in serverRoots) await _sha256(pem)], [
      '96bcec06264976f37460779acf28c5a7cfe8a3c0aae11a8ffcee05c0bddf08c6',
      '69729b8e15a86efc177a57afb7171dfc64add28c2fca8cf1507e34453ccb1470',
    ]);
  });

  test('a root this computer does not hold is trusted besides the system\'s own', () async {
    final site = await _Site.start();
    addTearDown(site.close);
    await expectLater(_get(HttpClient(), site.url), throwsA(isA<HandshakeException>()), reason: 'unknown to the system');
    expect(await _get(HttpClient(context: trusting([site.root])), site.url), 'ok');
  });

  test('the server\'s client takes both roots on this computer, whether or not its store already holds them', () {
    serverHttpClient().close();
  });

  test('every client of the server comes from serverHttpClient', () {
    final others = [
      for (final file in Directory('lib').listSync(recursive: true).whereType<File>())
        if (file.path.endsWith('.dart') &&
            !file.path.contains('http_transport') &&
            RegExp(r'\bHttpClient\(').hasMatch(file.readAsStringSync()))
          file.path,
    ];
    expect(others, isEmpty, reason: 'a client built elsewhere trusts only the roots the system already holds');
  });
}

Future<String> _sha256(String pem) async {
  final body = pem.split('\n').where((line) => line.isNotEmpty && !line.startsWith('-----')).join();
  final hash = await Sha256().hash(base64.decode(body));
  return hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

Future<String> _get(HttpClient client, Uri url) async {
  try {
    final response = await (await client.getUrl(url)).close();
    return await utf8.decodeStream(response);
  } finally {
    client.close(force: true);
  }
}

/// An HTTPS site on this computer, its certificate issued by a root made for the test.
class _Site {
  _Site._(this._server, this.root) {
    _server.listen((request) => request.response
      ..write('ok')
      ..close());
  }

  final HttpServer _server;

  /// The root that issued the site's certificate, as PEM.
  final String root;

  Uri get url => Uri.parse('https://127.0.0.1:${_server.port}/');

  Future<void> close() => _server.close(force: true);

  static Future<_Site> start() async {
    final dir = await Directory.systemTemp.createTemp('daylex_trust');
    String at(String name) => '${dir.path}${Platform.pathSeparator}$name';
    File(at('openssl.cnf')).writeAsStringSync('''
[req]
distinguished_name = dn
[dn]
[root]
basicConstraints = critical,CA:TRUE
keyUsage = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
[site]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = IP:127.0.0.1
authorityKeyIdentifier = keyid
subjectKeyIdentifier = hash
''');
    final config = ['-config', at('openssl.cnf')];
    for (final args in [
      [
        ...['req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '2', '-subj', '/CN=Daylex test root', ...config],
        ...['-extensions', 'root', '-keyout', at('root.key'), '-out', at('root.pem')],
      ],
      [
        ...['req', '-new', '-newkey', 'rsa:2048', '-nodes', '-subj', '/CN=127.0.0.1', ...config],
        ...['-keyout', at('site.key'), '-out', at('site.csr')],
      ],
      [
        ...['x509', '-req', '-in', at('site.csr'), '-CA', at('root.pem'), '-CAkey', at('root.key'), '-set_serial', '2'],
        ...['-days', '1', '-sha256', '-extfile', at('openssl.cnf'), '-extensions', 'site', '-out', at('site.pem')],
      ],
    ]) {
      final made = await Process.run('openssl', args);
      if (made.exitCode != 0) fail('openssl could not make the certificates: ${made.stderr}');
    }
    final context = SecurityContext()
      ..useCertificateChain(at('site.pem'))
      ..usePrivateKey(at('site.key'));
    final server = await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, context);
    return _Site._(server, File(at('root.pem')).readAsStringSync());
  }
}
