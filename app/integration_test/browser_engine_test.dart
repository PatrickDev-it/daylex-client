import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:daylex/features/browser/engine/engine.dart';
import 'package:daylex/features/browser/engine/webkit_page.dart';
import 'package:daylex/features/browser/engine/windows_page.dart';

/// The integrated browser on this computer's own engine (rfc/052): WebView2 on Windows, WebKit on the Mac. The widget
/// tests take every path through the panel with a fake engine; this one checks, on pages a local server serves, that
/// each real engine does what the fake promises. Linux has no engine: its tabs open in the system browser.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Every frame on screen, as in the app: the page is a native view the window keeps drawing.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  final skip = !Platform.isWindows && !Platform.isMacOS;
  late _Site site;
  late BrowserEngine engine;

  setUpAll(() async {
    if (skip) return;
    site = await _Site.start();
    final temp = await Directory.systemTemp.createTemp('daylex_browser');
    engine = Platform.isWindows ? WindowsBrowser('${temp.path}${Platform.pathSeparator}browser') : WebKitBrowser();
    expect(await engine.support(), BrowserSupport.embedded, reason: 'this computer draws pages inside the app');
  });
  tearDownAll(() async {
    if (!skip) await site.close();
  });

  testWidgets('a page is named after itself, and back and forward move through what the tab showed', (tester) async {
    final page = await _show(tester, engine);
    await page.load(site.at('/'));
    await _until(tester, page, 'the first page', (s) => !s.loading && s.title == 'Prima pagina');
    await page.load(site.at('/seconda'));
    await _until(tester, page, 'the second page', (s) => !s.loading && s.title == 'Seconda pagina' && s.canGoBack);
    await page.back();
    await _until(tester, page, 'back', (s) => s.url?.path == '/' && s.title == 'Prima pagina' && s.canGoForward);
    await page.forward();
    await _until(tester, page, 'forward', (s) => s.url?.path == '/seconda' && s.title == 'Seconda pagina');
  }, skip: skip);

  testWidgets('a page goes to the chat without its scripts, a PDF as its own bytes', (tester) async {
    final page = await _show(tester, engine);
    await page.load(site.at('/'));
    await _until(tester, page, 'the page', (s) => !s.loading && s.title == 'Prima pagina');
    final html = await page.capture();
    expect(html, isA<HtmlCapture>());
    expect(html.title, 'Prima pagina');
    expect((html as HtmlCapture).body, contains('Testo del provvedimento'));
    expect(html.body, isNot(contains('<script')));

    await page.load(site.at('/atto.pdf'));
    await _until(tester, page, 'the PDF', (s) => !s.loading && s.url?.path == '/atto.pdf' && s.problem == null);
    final pdf = await page.capture();
    expect(pdf, isA<PdfCapture>());
    expect((pdf as PdfCapture).bytes, site.pdf);
  }, skip: skip);

  testWidgets('a link for a new window becomes a tab, mail goes to the app, and the app keeps its shortcuts', (
    tester,
  ) async {
    const newTab = KeyCombo('t', ctrl: true);
    final page = await _show(tester, engine, options: const PageOptions(appKeys: [newTab]));
    final events = <PageEvent>[];
    final listening = page.events.listen(events.add);
    addTearDown(listening.cancel);
    // The page clicks its own links and presses Ctrl+T once the page script is in.
    await page.load(site.at('/collegamenti'));
    await _eventually(
      tester,
      'a new tab, a mail link and Ctrl+T from the page',
      () => [OpenInNewTab, OpenOutside, PageKey].every((type) => events.any((e) => e.runtimeType == type)),
      () => events,
    );
    expect(events.whereType<OpenInNewTab>().first.uri, site.at('/seconda'));
    expect(events.whereType<OpenOutside>().first.uri, Uri.parse('mailto:studio@example.it'));
    expect(events.whereType<PageKey>().first.combo, newTab);
    expect(page.state.value.url?.path, '/collegamenti', reason: 'the page itself stayed where it was');
  }, skip: skip);

  testWidgets('a site that does not answer is said to be unreachable, under no title of its own', (tester) async {
    final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = closed.port;
    await closed.close();
    final page = await _show(tester, engine);
    await page.load(Uri.parse('http://127.0.0.1:$port/'));
    final state = await _until(tester, page, 'the problem', (s) => s.problem != null && !s.loading);
    expect(state.problem, PageProblem.unreachable);
    expect(state.title, isEmpty);
  }, skip: skip);

  testWidgets('a certificate that is not valid is refused and said so, never left loading', (tester) async {
    final secure = await _Site.start(secure: true);
    addTearDown(secure.close);
    final page = await _show(tester, engine);
    await page.load(secure.at('/'));
    final state = await _until(tester, page, 'the problem', (s) => s.problem != null && !s.loading);
    expect(state.problem, PageProblem.certificate);
    expect(state.title, isEmpty);
  }, skip: skip);

  testWidgets('a login holds in another tab, and signing out of every site ends it', (tester) async {
    await engine.clearData();
    final first = await _show(tester, engine);
    await first.load(site.at('/accesso'));
    await _until(tester, first, 'the login', (s) => !s.loading && s.title == 'Accesso eseguito');

    final second = await _show(tester, engine);
    await second.load(site.at('/utente'));
    await _until(tester, second, 'the other tab', (s) => !s.loading && s.title == 'Utente: attiva');

    await engine.clearData();
    await second.reload();
    await _until(tester, second, 'after signing out', (s) => !s.loading && s.title == 'Utente: nessuno');
  }, skip: skip);
}

/// A page of [engine] on screen, as a tab shows it; taken off screen and closed when the test ends.
Future<BrowserPage> _show(
  WidgetTester tester,
  BrowserEngine engine, {
  PageOptions options = const PageOptions(),
}) async {
  final page = engine.create(options);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await page.dispose();
  });
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: page.view())));
  await tester.pump();
  return page;
}

/// Waits, in real time, for [page] to reach what [done] describes.
Future<PageState> _until(WidgetTester tester, BrowserPage page, String what, bool Function(PageState) done) async {
  await _eventually(tester, what, () => done(page.state.value), () {
    final s = page.state.value;
    return '${s.url} «${s.title}» loading: ${s.loading}, problem: ${s.problem}, '
        'back: ${s.canGoBack}, forward: ${s.canGoForward}';
  });
  return page.state.value;
}

/// Waits, in real time, until [done]; fails with what [got] says there is instead.
Future<void> _eventually(WidgetTester tester, String what, bool Function() done, Object? Function() got) async {
  final end = DateTime.now().add(const Duration(seconds: 30));
  while (!done()) {
    if (DateTime.now().isAfter(end)) fail('$what: after 30 s, ${got()}');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }
}

/// The pages the test opens, served on this computer only.
class _Site {
  _Site._(this._server, {required this.secure}) {
    _server.listen(_answer);
  }

  final HttpServer _server;
  final bool secure;

  /// An act as a PDF reader opens it.
  final Uint8List pdf = _pdf('Atto di prova');

  /// Over HTTPS, [secure] has a certificate made for the test that no one trusts.
  static Future<_Site> start({bool secure = false}) async {
    if (!secure) return _Site._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0), secure: false);
    final dir = await Directory.systemTemp.createTemp('daylex_certificate');
    final config = File('${dir.path}/openssl.cnf')..writeAsStringSync('[req]\ndistinguished_name = dn\n[dn]\n');
    final made = await Process.run('openssl', [
      ...['req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1', '-subj', '/CN=127.0.0.1'],
      ...['-config', config.path, '-keyout', '${dir.path}/key.pem', '-out', '${dir.path}/cert.pem'],
    ]);
    if (made.exitCode != 0) fail('openssl could not make the certificate: ${made.stderr}');
    final context = SecurityContext()
      ..useCertificateChain('${dir.path}/cert.pem')
      ..usePrivateKey('${dir.path}/key.pem');
    return _Site._(await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, context), secure: true);
  }

  Uri at(String path) => Uri.parse('${secure ? 'https' : 'http'}://127.0.0.1:${_server.port}$path');

  Future<void> close() => _server.close(force: true);

  Future<void> _answer(HttpRequest request) async {
    final r = request.response..headers.set('cache-control', 'no-store');
    switch (request.uri.path) {
      case '/':
        _html(r, 'Prima pagina', '<h1>Sentenza</h1><p>Testo del provvedimento.</p><script>var x = 1;</script>');
      case '/seconda':
        _html(r, 'Seconda pagina', '<p>Seconda.</p>');
      case '/collegamenti':
        _html(r, 'Collegamenti', '''
<a id="tab" href="/seconda" target="_blank">Nuova scheda</a> <a id="mail" href="mailto:studio@example.it">Scrivi</a>
<script>
(function go() {
  if (!window.__daylex) return setTimeout(go, 100);
  document.getElementById('tab').click();
  document.getElementById('mail').click();
  document.body.dispatchEvent(new KeyboardEvent('keydown', {key: 't', ctrlKey: true, bubbles: true}));
})();
</script>''');
      case '/atto.pdf':
        r.headers.contentType = ContentType('application', 'pdf');
        r.add(pdf);
      case '/accesso':
        r.cookies.add(
          Cookie('sessione', 'attiva')
            ..maxAge = 3600
            ..path = '/',
        );
        _html(r, 'Accesso eseguito', '<p>Benvenuto.</p>');
      case '/utente':
        final session = request.cookies.where((c) => c.name == 'sessione').firstOrNull;
        _html(r, 'Utente: ${session?.value ?? 'nessuno'}', '');
      default:
        r.statusCode = HttpStatus.notFound;
    }
    await r.close();
  }

  static void _html(HttpResponse r, String title, String body) {
    r.headers.contentType = ContentType.html;
    r.write('<!doctype html><html><head><meta charset="utf-8"><title>$title</title></head><body>$body</body></html>');
  }
}

/// A one-page PDF that says [text], with the cross-reference table a reader checks.
Uint8List _pdf(String text) {
  final content = 'BT /F1 24 Tf 72 760 Td ($text) Tj ET';
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>',
    '<< /Length ${content.length} >>\nstream\n$content\nendstream',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  final out = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(out.length);
    out.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final xref = out.length;
  out.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
  for (final offset in offsets) {
    out.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  out.write('trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n');
  return ascii.encode(out.toString());
}
