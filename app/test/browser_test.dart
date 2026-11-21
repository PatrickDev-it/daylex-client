import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/app.dart';
import 'package:paper_agent/features/agent/agent_controller.dart';
import 'package:paper_agent/features/browser/browser_state.dart';
import 'package:paper_agent/features/browser/engine/engine.dart';
import 'package:paper_agent/features/browser/engine/page_script.dart' hide KeyMessage;
import 'package:paper_agent/features/browser/engine/page_script.dart' as script show KeyMessage;
import 'package:paper_agent/features/browser/engine/webkit_page.dart' show webKitProblem;
import 'package:paper_agent/features/browser/live_pages.dart';
import 'package:paper_agent/features/browser/page_file.dart';
import 'package:paper_agent/features/browser/portals.dart';
import 'package:paper_agent/features/browser/web_address.dart';
import 'package:paper_agent/features/workspace/ui_state.dart';
import 'package:paper_agent/ui/browser/address_bar.dart';
import 'package:paper_agent/ui/browser/browser_host.dart';
import 'package:paper_agent/ui/chat/composer_inputs.dart';
import 'package:paper_agent/ui/shortcuts.dart';

import 'test_app.dart';

/// The integrated browser (rfc/052): what an address becomes, the shared tabs, the keys a page hands back, the
/// page as a file for the chat, and every path through the panel with a fake engine in place of WebView2.
void main() {
  group('addresses', () {
    test('a host goes over https, a known scheme as typed, anything else to a search', () {
      expect(addressFor('normattiva.it'), Uri.parse('https://normattiva.it'));
      expect(addressFor('  www.gazzettaufficiale.it/atto  '), Uri.parse('https://www.gazzettaufficiale.it/atto'));
      expect(addressFor('http://intranet.studio.it'), Uri.parse('http://intranet.studio.it'));
      expect(addressFor('localhost:8080/x'), Uri.parse('https://localhost:8080/x'));
      expect(addressFor('normattiva.it:443/x'), Uri.parse('https://normattiva.it:443/x'));
      expect(addressFor('192.168.1.10'), Uri.parse('https://192.168.1.10'));
      final search = addressFor('art. 2043 codice civile')!;
      expect(search.host, 'www.google.com');
      expect(search.queryParameters['q'], 'art. 2043 codice civile');
      expect(addressFor('   '), isNull);
    });

    test('typedAddress takes only addresses: the portal dialog has no search to fall back on', () {
      expect(typedAddress('dejure.it'), Uri.parse('https://dejure.it'));
      expect(typedAddress('codice civile'), isNull);
      expect(typedAddress('sentenza'), isNull);
      expect(typedAddress(''), isNull);
    });

    test('only web pages open in a tab; mail and phone go to the system; the rest never opens', () {
      expect(navigationFor(Uri.parse('https://a.it')), Navigation.web);
      expect(navigationFor(Uri.parse('HTTP://a.it')), Navigation.web);
      expect(navigationFor(Uri.parse('mailto:studio@a.it')), Navigation.system);
      expect(navigationFor(Uri.parse('tel:+39061234')), Navigation.system);
      for (final refused in ['javascript:alert(1)', 'file:///C:/x.pdf', 'data:text/html,x', 'ftp://a.it', 'https:']) {
        expect(navigationFor(Uri.parse(refused)), Navigation.refused, reason: refused);
      }
      expect(navigationFor(addressFor('javascript:alert(1)')!), Navigation.refused);
    });

    test('the bar shows the host first and the rest dimmed', () {
      final uri = Uri.parse('https://www.gazzettaufficiale.it/atto/serie_generale?x=1#a');
      expect(displayHost(uri), 'gazzettaufficiale.it');
      expect(displayRest(uri), '/atto/serie_generale?x=1#a');
      expect(displayRest(Uri.parse('https://a.it/')), '');
      expect(displayHost(Uri.parse('http://localhost:8080/')), 'localhost:8080');
      expect(isSecure(uri), isTrue);
      expect(isSecure(Uri.parse('http://a.it')), isFalse);
    });

    test("a bare domain is offered on its site's www host; any other host is not guessed", () {
      expect(
        wwwAlternative(Uri.parse('https://gazzettaufficiale.it/atto?x=1')),
        Uri.parse('https://www.gazzettaufficiale.it/atto?x=1'),
      );
      for (final none in [
        'https://www.normattiva.it/',
        'https://pst.giustizia.it/',
        'http://10.0.0.1/',
        'http://localhost:8080/',
      ]) {
        expect(wwwAlternative(Uri.parse(none)), isNull, reason: none);
      }
    });

    test('a kept page is named by its title and when it was taken, without characters files refuse', () {
      final at = DateTime(2026, 11, 21, 14, 5);
      final url = Uri.parse('https://www.normattiva.it/x');
      expect(pageFileName('Art. 2043: "danno" <ingiusto>', url, at, 'html'), 'Art. 2043 danno ingiusto 2026-11-21 14.05.html');
      expect(pageFileName('  ', url, at, 'pdf'), 'normattiva.it 2026-11-21 14.05.pdf');
      expect(pageFileName('a' * 200, url, at, 'html'), '${'a' * 80} 2026-11-21 14.05.html');
      // A PDF opened in a tab is titled by its file name: the extension is not written twice.
      expect(pageFileName('Sentenza.PDF', url, at, 'pdf'), 'Sentenza 2026-11-21 14.05.pdf');
      expect(pageFileName('note.pdf', url, at, 'html'), 'note.pdf 2026-11-21 14.05.html');
    });

    test('zoom steps as a desktop browser, held at both ends', () {
      expect(zoomStep(1, 1), 1.1);
      expect(zoomStep(1, -1), 0.9);
      expect(zoomStep(1.05, 1), 1.1);
      expect(zoomStep(3, 1), 3);
      expect(zoomStep(0.5, -1), 0.5);
    });
  });

  group('tabs', () {
    late ProviderContainer container;
    late BrowserNotifier browser;
    setUp(() {
      container = ProviderContainer();
      browser = container.read(browserProvider.notifier);
    });
    tearDown(() => container.dispose());
    BrowserState state() => container.read(browserProvider);

    test('a link opened in a new tab lands right after its own; closing the active one shows the one before', () {
      final a = browser.open(url: 'https://a.it/');
      final b = browser.open(url: 'https://b.it/');
      final fromA = browser.open(url: 'https://a.it/2', after: a);
      expect(state().tabs.map((t) => t.id), [a, fromA, b]);
      expect(state().activeId, fromA);
      expect(state().inFront, isTrue);

      browser.close(fromA);
      expect(state().activeId, a);
      browser.close(a);
      expect(state().activeId, b);
      browser.close(b);
      expect(state().tabs, isEmpty);
      expect(state().activeId, isNull);
      expect(state().inFront, isFalse, reason: "with no web tab left the chat's own tab comes back");
    });

    test('closed tabs reopen last first; a tab still on its portals is not remembered', () {
      final a = browser.open(url: 'https://a.it/');
      final blank = browser.open();
      final b = browser.open(url: 'https://b.it/');
      browser
        ..close(a)
        ..close(blank)
        ..close(b);
      expect(state().closed.map((t) => t.url), ['https://a.it/', 'https://b.it/']);
      expect(browser.reopenClosed(), isTrue);
      expect(state().active?.url, 'https://b.it/');
      expect(browser.reopenClosed(), isTrue);
      expect(browser.reopenClosed(), isFalse);
    });

    test('only the last ${BrowserNotifier.closedLimit} closed tabs are kept', () {
      for (var i = 0; i < BrowserNotifier.closedLimit + 5; i++) {
        browser.close(browser.open(url: 'https://a.it/$i'));
      }
      expect(state().closed, hasLength(BrowserNotifier.closedLimit));
      expect(state().closed.first.url, 'https://a.it/5');
    });

    test('a page reporting itself unchanged changes nothing', () {
      final id = browser.open(url: 'https://a.it/');
      browser.pageChanged(id, url: 'https://a.it/', title: 'A', icon: '');
      var notified = 0;
      container.listen(browserProvider, (_, _) => notified++);
      browser.pageChanged(id, url: 'https://a.it/', title: 'A', icon: '');
      expect(notified, 0);
      browser.pageChanged(id, title: 'A2', icon: 'https://a.it/favicon.ico');
      expect(notified, 1);
      expect(state().active?.icon, 'https://a.it/favicon.ico');
      browser.pageChanged(id, icon: '');
      expect(state().active?.icon, isNull);
    });

    test('the web tab shows beside the chat when in front, or when the chat has no tab of its own', () {
      final id = browser.open(url: 'https://a.it/');
      expect(state().shownBeside(chatTab: true)?.id, id);
      browser.yieldToChat();
      expect(state().shownBeside(chatTab: true), isNull);
      expect(state().shownBeside(chatTab: false)?.id, id);
    });

    test('tabs and portals survive a restart; a removed ready portal stays removed, a new one arrives once', () {
      final a = browser.open(url: 'https://a.it/');
      browser
        ..pageChanged(a, title: 'A', icon: 'https://a.it/i.png')
        ..addPortal('Intranet', 'https://intranet.studio.it/')
        ..removePortal('sole24ore');
      final saved = jsonDecode(jsonEncode(BrowserNotifier.toJson(state()))) as Map<String, dynamic>;
      final back = BrowserNotifier.fromJson(saved);
      expect(back.tabs.single.title, 'A');
      expect(back.tabs.single.icon, 'https://a.it/i.png');
      expect(back.activeId, a);
      expect(back.inFront, isTrue);
      expect(back.portals.map((p) => p.id), isNot(contains('sole24ore')));
      expect(back.portals.last.name, 'Intranet');

      // A version that did not know OneLegale yet: the lawyer gets it, once.
      final older = {
        ...saved,
        'portals': [for (final p in saved['portals'] as List) if (p['id'] != 'onelegale') p],
        'builtIns': [for (final p in builtInPortals) if (p.id != 'onelegale') p.id],
      };
      expect(BrowserNotifier.fromJson(older).portals.where((p) => p.id == 'onelegale'), hasLength(1));
    });

    test('a saved list this version cannot read loses only what it cannot read', () {
      final back = BrowserNotifier.fromJson({
        'tabs': [
          {'id': 'x', 'url': 'https://a.it/'},
          'junk',
          {'url': 'https://no-id.it/'},
        ],
        'activeId': 'gone',
        'inFront': true,
        'portals': [
          {'id': 'p', 'name': 'P', 'url': 'https://p.it/', 'group': 'unknown'},
          {'id': 3},
        ],
      });
      expect(back.tabs.map((t) => t.id), ['x']);
      expect(back.activeId, 'x', reason: 'an active id that is gone falls back to the last tab');
      expect(back.portals.first.group, PortalGroup.mine);
      expect(back.portals.map((p) => p.id), containsAll(builtInPortals.map((p) => p.id)));
    });

    test('portals are renamed and removed by id; a blank name keeps the old one', () {
      browser.addPortal('  ', 'https://x.it/');
      final added = state().portals.last;
      expect(added.name, 'https://x.it/');
      browser.renamePortal(added.id, '  Studio  ');
      expect(state().portals.last.name, 'Studio');
      browser.renamePortal(added.id, ' ');
      expect(state().portals.last.name, 'Studio');
      browser.removePortal(added.id);
      expect(state().portals.any((p) => p.id == added.id), isFalse);
    });

    test('the ready list has no Leggi d\'Italia, and every entry opens in a tab', () {
      expect(builtInPortals.map((p) => p.name.toLowerCase()), isNot(contains(contains('leggi d'))));
      for (final p in builtInPortals) {
        expect(navigationFor(Uri.parse(p.url)), Navigation.web, reason: p.name);
        expect(p.group, isNot(PortalGroup.mine));
      }
    });
  });

  group('page keys', () {
    test('every global shortcut reaches the app from inside a page, and comes back as itself', () {
      for (final s in AppShortcut.values.where((s) => s.scope == ShortcutScope.global)) {
        for (final a in s.activators) {
          final combo = comboOf(a);
          expect(combo, isNotNull, reason: '$s ${a.trigger}');
          expect(shortcutFor(combo!), s, reason: '$s ${a.trigger}');
        }
      }
    });

    test("a page's text field keeps the keys a web editor uses (Ctrl+B is bold there); the tab keys never", () {
      final always = pageKeys(always: true), outside = pageKeys(always: false);
      expect(outside, contains(const KeyCombo('b', ctrl: true)));
      expect(outside, contains(const KeyCombo('k', ctrl: true)));
      expect(always, isNot(contains(const KeyCombo('b', ctrl: true))));
      for (final k in [
        const KeyCombo('t', ctrl: true),
        const KeyCombo('w', ctrl: true),
        const KeyCombo('Tab', ctrl: true),
        const KeyCombo('l', ctrl: true),
        const KeyCombo('F5'),
        const KeyCombo('ArrowLeft', alt: true),
      ]) {
        expect(always, contains(k), reason: k.key);
      }
      expect(always.toSet().intersection(outside.toSet()), isEmpty);
      // A page reports "T" with Shift held: the same key.
      expect(shortcutFor(const KeyCombo('T', ctrl: true, shift: true)), AppShortcut.reopenTab);
    });

    test('the page script carries each key with whether a text field keeps it', () {
      final script = pageScript(
        appKeys: const [KeyCombo('t', ctrl: true)],
        outsideFieldKeys: const [KeyCombo('b', ctrl: true)],
        post: 'post(m)',
      );
      final keys = jsonDecode(RegExp(r'var keys = (\[.*?\]);', dotAll: true).firstMatch(script)!.group(1)!) as List;
      expect(keys, [
        {...const KeyCombo('t', ctrl: true).toJson(), 'field': true},
        {...const KeyCombo('b', ctrl: true).toJson(), 'field': false},
      ]);
      expect(script, contains(r'submit)$/i'), reason: 'the regular expression ends where JavaScript expects');
      // WebView2 would open mail and other apps itself, then call the page unreachable: the app decides instead.
      expect(script, contains("send({type: 'outside', url: a.href})"));
      expect(script, contains('post(m)'));
    });

    test('what a page sends is read back, and anything else is dropped', () {
      expect((readPageMessage('{"type":"key","key":"t","ctrl":true}') as script.KeyMessage).combo, const KeyCombo('t', ctrl: true));
      expect((readPageMessage({'type': 'newTab', 'url': 'https://a.it/'}) as NewTabMessage).uri, Uri.parse('https://a.it/'));
      expect(
        (readPageMessage({'type': 'outside', 'url': 'mailto:pec@studio.it'}) as OutsideLinkMessage).uri,
        Uri.parse('mailto:pec@studio.it'),
      );
      expect((readPageMessage({'type': 'zoom', 'step': -3}) as ZoomMessage).step, -1);
      expect((readPageMessage({'type': 'meta', 'icon': 'https://a.it/i.png'}) as IconMessage).url, 'https://a.it/i.png');
      final capture = readPageMessage({'type': 'capture', 'id': 'c1', 'kind': 'html', 'data': '<p>x</p>'}) as CaptureMessage;
      expect((capture.id, capture.kind, capture.data, capture.title, capture.error), ('c1', 'html', '<p>x</p>', '', null));
      for (final junk in [null, 'not json', '[]', {'type': 'key'}, {'type': 'newTab', 'url': 3}, {'type': 'other'}]) {
        expect(readPageMessage(junk), isNull, reason: '$junk');
      }
    });
  });

  group('the page for the chat', () {
    final at = DateTime(2026, 11, 21, 9, 30);

    test('a web page becomes HTML that says where and when it was taken', () {
      final file = pageFile(
        HtmlCapture(url: Uri.parse('https://a.it/x?a=1&b=2'), title: 'Art. <2043>', body: '<p>Testo</p>'),
        at,
        note: 'Pagina acquisita il 21 novembre 2026 alle 09:30 da:',
      );
      final html = utf8.decode(file.bytes);
      expect(file.name, 'Art. 2043 2026-11-21 09.30.html');
      expect(html, contains('<title>Art. &lt;2043&gt;</title>'));
      expect(html, contains('href="https://a.it/x?a=1&amp;b=2"'));
      expect(html, contains('content="2026-11-21T09:30:00.000"'));
      expect(html, contains('Pagina acquisita il 21 novembre 2026 alle 09:30 da:'));
      expect(html, contains('<p>Testo</p>'));
    });

    test('kept pages wait on disk for the chat, and only their own folders are swept', () async {
      final temp = await Directory.systemTemp.createTemp('pa_sweep');
      addTearDown(() => temp.delete(recursive: true));
      final page = await Directory('${temp.path}/daylex-page-1').create();
      await File('${page.path}/Pagina.html').writeAsString('x');
      final other = await Directory('${temp.path}/altro').create();

      await sweepPageFiles(temp, DateTime.now().subtract(keptPagesFor));
      expect(page.existsSync(), isTrue, reason: 'a page kept today is still waiting for the chat');
      await sweepPageFiles(temp, DateTime.now().add(const Duration(minutes: 1)));
      expect(page.existsSync(), isFalse);
      expect(other.existsSync(), isTrue);
    });

    test('a PDF stays its own bytes', () {
      final bytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);
      final file = pageFile(PdfCapture(url: Uri.parse('https://a.it/s.pdf'), title: 'Sentenza', bytes: bytes), at, note: '');
      expect(file.name, 'Sentenza 2026-11-21 09.30.pdf');
      expect(file.bytes, bytes);
    });
  });

  test('WebKit: a network failure is named by its code, and a refused certificate is not a page left behind', () {
    PageProblem? url(int code, {String? at, String? refused}) =>
        webKitProblem(code, domain: 'NSURLErrorDomain', url: at == null ? null : Uri.parse(at), refusedHost: refused);
    expect(url(-1003), PageProblem.unreachable, reason: 'the name of the site is unknown');
    expect(url(-1004), PageProblem.unreachable, reason: 'the site does not answer');
    expect(url(-1009), PageProblem.unreachable, reason: 'no network');
    expect(url(-1001), PageProblem.timeout);
    expect(url(-1202), PageProblem.certificate);
    expect(url(-1201), PageProblem.certificate);
    expect(url(-1100), PageProblem.other);
    expect(url(-999, at: 'https://a.it/', refused: 'a.it'), PageProblem.certificate);
    expect(url(-999, at: 'https://a.it/', refused: 'cdn.b.it'), isNull, reason: 'another site, refused alone');
    expect(url(-999, at: 'https://a.it/'), isNull, reason: 'the lawyer went elsewhere');
    expect(webKitProblem(102, domain: 'WebKitErrorDomain'), isNull);
    expect(webKitProblem(204, domain: 'WebKitErrorDomain'), isNull);
    expect(webKitProblem(2, domain: 'WKErrorDomain'), PageProblem.other, reason: 'the page process ended');
  });

  group('live pages', () {
    test('at most [limit] pages stay, the one shown longest ago released first', () async {
      final engine = FakeEngine();
      final changed = <String>[];
      final pages = LivePages(engine, const PageOptions(), onChanged: (id, _) => changed.add(id), limit: 2);
      final a = pages.pageFor(const WebTab(id: 'a', url: 'https://a.it/'));
      pages.pageFor(const WebTab(id: 'b', url: 'https://b.it/'));
      pages.pageFor(const WebTab(id: 'a', url: 'https://a.it/'));
      pages.pageFor(const WebTab(id: 'c', url: 'https://c.it/'));
      expect(engine.pages, hasLength(3));
      expect(engine.pages[1].disposed, isTrue, reason: 'b was shown longest ago');
      expect(identical(pages.pageOf('a'), a), isTrue);
      expect(engine.pages.first.loaded, [Uri.parse('https://a.it/')], reason: 'a live page is not loaded again');
      await Future<void>.delayed(Duration.zero);
      expect(changed, containsAll(['a', 'c']));

      pages.keepOnly(['c']);
      expect(engine.pages.first.disposed, isTrue);
      expect(pages.pageOf('a'), isNull);
      await pages.clearData();
      expect(engine.cleared, 1);
      expect(engine.pages.last.reloads, 1, reason: 'an open page shows itself signed out');
      pages.dispose();
      expect(engine.pages.last.disposed, isTrue);
    });

    test('a tab on its portals starts its page without loading anything', () {
      final engine = FakeEngine();
      LivePages(engine, const PageOptions(), onChanged: (_, _) {}).pageFor(const WebTab(id: 'n'));
      expect(engine.pages.single.loaded, isEmpty);
    });
  });

  group('the panel', () {
    setUpAll(loadAppFonts);

    testWidgets('Ctrl+T opens the portals with the keyboard in the address bar; a portal opens in the tab', (
      tester,
    ) async {
      final engine = FakeEngine();
      final container = await _pumpApp(tester, engine);
      await _press(tester, LogicalKeyboardKey.keyT, ctrl: true);

      final tab = container.read(browserProvider).active!;
      expect(tab.url, isNull);
      expect(find.text(itL10n.browserPortalsOfficial), findsOneWidget);
      expect(find.text('Gazzetta Ufficiale'), findsOneWidget);
      expect(container.read(addressFocusProvider).hasFocus, isTrue);
      expect(engine.pages, isEmpty, reason: 'the portals need no browser process');

      await tester.tap(find.text('Normattiva'));
      await _pump(tester);
      expect(engine.pages.single.loaded, [Uri.parse('https://www.normattiva.it/')]);
      expect(container.read(browserProvider).active?.title, 'Pagina www.normattiva.it');
      expect(find.text('Pagina www.normattiva.it'), findsOneWidget, reason: 'the tab is named after its page');
    });

    testWidgets('«Portali» opened by the pointer resting on it stays open under the click that follows', (tester) async {
      final engine = FakeEngine();
      final container = await _pumpApp(tester, engine);
      await _press(tester, LogicalKeyboardKey.keyT, ctrl: true);
      await _go(tester, 'a.it');
      await tester.tap(find.byTooltip(itL10n.panelOpenTab));
      await _pump(tester);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      final portals = tester.getCenter(find.text(itL10n.browserPortalsMenu));
      await mouse.moveTo(portals);
      await _pump(tester);
      expect(find.text('Normattiva'), findsOneWidget);
      await mouse.down(portals);
      await mouse.up();
      await _pump(tester);
      expect(find.text('Normattiva'), findsOneWidget, reason: 'the click does not close what the pointer opened');

      await tester.tap(find.text('Normattiva'));
      await _pump(tester);
      expect(container.read(browserProvider).active?.url, 'https://www.normattiva.it/');
    });

    testWidgets('the address bar opens what is typed; back and forward walk the history', (tester) async {
      final engine = FakeEngine();
      final container = await _pumpApp(tester, engine);
      await _press(tester, LogicalKeyboardKey.keyT, ctrl: true);
      await _go(tester, 'normattiva.it');
      final page = engine.pages.single;
      await _go(tester, 'art. 2043 codice civile');
      expect(page.loaded.last.host, 'www.google.com');
      expect(container.read(addressFocusProvider).hasFocus, isFalse, reason: 'the page has the keyboard now');
      expect(page.focuses, greaterThan(0));

      await tester.tap(_tip(itL10n.browserBack));
      await _pump(tester);
      expect(page.state.value.url, Uri.parse('https://normattiva.it'));
      expect(container.read(browserProvider).active?.url, 'https://normattiva.it');
      await tester.tap(_tip(itL10n.browserForward));
      await _pump(tester);
      expect(page.state.value.url?.host, 'www.google.com');

      // A typed address that is not a web page never reaches the page.
      await _go(tester, 'javascript:alert(1)');
      expect(page.loaded.where((u) => u.scheme == 'javascript'), isEmpty);
      expect(find.text(itL10n.browserRefused), findsOneWidget);
    });

    testWidgets('a page that did not open says why; Riprova reloads it', (tester) async {
      final engine = FakeEngine();
      final container = await _pumpApp(tester, engine);
      await _press(tester, LogicalKeyboardKey.keyT, ctrl: true);
      await _go(tester, 'normattiva.it');
      final page = engine.pages.single;
      expect(find.byTooltip(itL10n.browserSecure), findsOneWidget);
      page.report(page.state.value.copyWith(problem: () => PageProblem.unreachable));
      await _pump(tester);
      expect(find.text(itL10n.browserProblemUnreachableTitle), findsOneWidget);
      expect(find.byTooltip(itL10n.browserSecure), findsNothing, reason: 'no page, no connection to call encrypted');
      await tester.tap(find.text(itL10n.browserRetry));
      await _pump(tester);
      expect(page.reloads, 1);
      expect(find.text(itL10n.browserProblemUnreachableTitle), findsNothing);

      // WebView2 titles its own error page («Errore dell'orologio»): the tab names the site instead.
      page.report(page.state.value.copyWith(problem: () => PageProblem.certificate, title: "Errore dell'orologio"));
      await _pump(tester);
      expect(find.text(itL10n.browserProblemCertificateTitle), findsOneWidget);
      expect(find.text(itL10n.browserOpenOutside), findsNothing, reason: 'an invalid certificate is not worked around');
      expect(find.text("Errore dell'orologio"), findsNothing);
      expect(container.read(browserProvider).active?.title, '', reason: 'the site, not the page before it');
      expect(find.byTooltip(itL10n.browserSecure), findsNothing, reason: 'an https address with a refused certificate');
      expect(find.byTooltip(itL10n.browserNotSecure), findsOneWidget);
      // Trying again does not bring the error page's title back while the page loads.
      await tester.tap(find.text(itL10n.browserRetry));
      await _pump(tester);
      expect(find.text("Errore dell'orologio"), findsNothing);
    });

    testWidgets('a bare domain that did not answer offers its www site first', (tester) async {
      final engine = FakeEngine();
      final container = await _pumpApp(tester, engine);
      await _press(tester, LogicalKeyboardKey.keyT, ctrl: true);
      await _go(tester, 'gazzettaufficiale.it');
      final page = engine.pages.single;
      page.report(page.state.value.copyWith(problem: () => PageProblem.unreachable));
      await _pump(tester);
      final www = find.text(itL10n.browserOpenWww('www.gazzettaufficiale.it'));
      expect(www, findsOneWidget);
      expect(find.text(itL10n.browserRetry), findsOneWidget, reason: 'trying again stays one click away');
      await tester.tap(www);
      await _pump(tester);
      expect(page.loaded.last, Uri.parse('https://www.gazzettaufficiale.it'));
      expect(container.read(browserProvider).active?.url, 'https://www.gazzettaufficiale.it');
      expect(find.text(itL10n.browserProblemUnreachableTitle), findsNothing);
    });

    testWidgets('Allega puts the page in the attachments of the chat being written', (tester) async {
      final engine = FakeEngine();
      final container = await _pumpApp(tester, engine);
      await _press(tester, LogicalKeyboardKey.keyT, ctrl: true);
      await _go(tester, 'normattiva.it');
      await tester.tap(find.text(itL10n.browserAttachShort));
      await _settleFiles(tester);
      final attached = container.read(sessionProvider(AgentController.draftId)).attachments;
      expect(attached.single.name, endsWith('.html'));
      expect(attached.single.name, startsWith('Pagina normattiva.it '));
      // Read when the chat is sent, as a dropped file: the page waits on disk.
      final path = attached.single.localPath!;
      addTearDown(() => File(path).parent.deleteSync(recursive: true));
      expect(await tester.runAsync(() => File(path).readAsString()), contains('<p>Art. 2043</p>'));
    });

    testWidgets('a page still reaches the chat when its tab closes while it is taken', (tester) async {
      final engine = FakeEngine();
      final container = await _pumpApp(tester, engine);
      await _press(tester, LogicalKeyboardKey.keyT, ctrl: true);
      await _go(tester, 'normattiva.it');
      final page = engine.pages.single..captureHeld = Completer();
      await tester.tap(find.text(itL10n.browserAttachShort));
      await _pump(tester);
      await _press(tester, LogicalKeyboardKey.keyW, ctrl: true);
      expect(container.read(browserProvider).tabs, isEmpty);

      page.captureHeld!.complete();
      await _settleFiles(tester);
      final attached = container.read(sessionProvider(AgentController.draftId)).attachments;
      addTearDown(() => File(attached.single.localPath!).parent.deleteSync(recursive: true));
      expect(attached.single.name, startsWith('Pagina normattiva.it '));
    });

    testWidgets('a page that cannot be taken says so, and nothing is attached', (tester) async {
      final engine = FakeEngine();
      final container = await _pumpApp(tester, engine);
      await _press(tester, LogicalKeyboardKey.keyT, ctrl: true);
      await _go(tester, 'normattiva.it');
      engine.pages.single.captureFails = true;
      await tester.tap(find.text(itL10n.browserAttachShort));
      await _settleFiles(tester);
      expect(find.text(itL10n.browserAttachFailed), findsOneWidget);
      expect(container.read(sessionProvider(AgentController.draftId)).attachments, isEmpty);
    });

    testWidgets('what the page asks: a new tab right after it, the app shortcuts, the zoom', (tester) async {
      final engine = FakeEngine();
      final container = await _pumpApp(tester, engine);
      await _press(tester, LogicalKeyboardKey.keyT, ctrl: true);
      await _go(tester, 'a.it');
      final first = container.read(browserProvider).active!.id;
      final page = engine.pages.single;

      page.emit(OpenInNewTab(Uri.parse('https://b.it/')));
      page.emit(OpenInNewTab(Uri.parse('file:///C:/segreto.pdf')));
      await _pump(tester);
      final tabs = container.read(browserProvider).tabs;
      expect(tabs.map((t) => t.url), ['https://a.it', 'https://b.it/']);
      expect(engine.pages.last.loaded, [Uri.parse('https://b.it/')]);

      container.read(browserProvider.notifier).activate(first);
      await _pump(tester);
      page.emit(const PageZoom(1));
      await _pump(tester);
      expect(page.state.value.zoom, 1.1);

      // A link to mail goes to the system's app; one to another app, nowhere.
      final launched = <Object?>[];
      const launcher = MethodChannel('plugins.flutter.io/url_launcher');
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(launcher, (call) async {
        launched.add((call.arguments as Map)['url']);
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(launcher, null));
      page.emit(OpenOutside(Uri.parse('mailto:pec@studio.it')));
      await _pump(tester);
      expect(launched, ['mailto:pec@studio.it']);
      expect(find.text(itL10n.browserRefused), findsNothing);
      page.emit(OpenOutside(Uri.parse('ms-word:ofe|u|https://a.it/atto.docx')));
      await _pump(tester);
      expect(launched, hasLength(1));
      expect(find.text(itL10n.browserRefused), findsOneWidget);
      expect(container.read(browserProvider).tabs, hasLength(2));

      // Ctrl+W pressed with the keyboard in the page closes the web tab, not the chat's.
      page.emit(const PageKey(KeyCombo('w', ctrl: true)));
      await _pump(tester);
      expect(container.read(browserProvider).tabs.map((t) => t.url), ['https://b.it/']);
      expect(page.disposed, isTrue, reason: "a closed tab's browser process goes");
    });

    testWidgets('Ctrl+T and Ctrl+L pressed in the page leave the keyboard in the address bar', (tester) async {
      final engine = FakeEngine();
      final container = await _pumpApp(tester, engine);
      await _press(tester, LogicalKeyboardKey.keyT, ctrl: true);
      await _go(tester, 'a.it');
      final page = engine.pages.single;
      expect(container.read(addressFocusProvider).hasFocus, isFalse);

      // The tab the page was in leaves the screen with it: what it asked still lands.
      page.emit(const PageKey(KeyCombo('t', ctrl: true)));
      await _pump(tester);
      expect(container.read(browserProvider).active?.url, isNull);
      expect(container.read(addressFocusProvider).hasFocus, isTrue);

      // A tab brought forward takes the keyboard into its page, as in a browser, not its address bar.
      final focuses = page.focuses;
      await tester.tap(find.text('Pagina a.it'));
      await _pump(tester);
      expect(container.read(addressFocusProvider).hasFocus, isFalse);
      expect(page.focuses, focuses + 1);
      page.emit(const PageKey(KeyCombo('l', ctrl: true)));
      await _pump(tester);
      expect(container.read(addressFocusProvider).hasFocus, isTrue);

      // Not while the lawyer writes to the chat: the page is read beside it.
      final composer = container.read(composerInputsProvider).focus;
      await _press(tester, LogicalKeyboardKey.keyK, ctrl: true);
      expect(composer.hasFocus, isTrue);
      await tester.tap(find.text(itL10n.browserNewTab));
      await _pump(tester);
      expect(composer.hasFocus, isTrue);
      expect(container.read(addressFocusProvider).hasFocus, isFalse);
    });

    testWidgets('page keys act on the page shown: F5 reloads, Alt+arrows walk it, Ctrl+Shift+T reopens', (
      tester,
    ) async {
      final engine = FakeEngine();
      final container = await _pumpApp(tester, engine);
      await _press(tester, LogicalKeyboardKey.keyT, ctrl: true);
      await _go(tester, 'a.it');
      await _go(tester, 'b.it');
      final page = engine.pages.single;

      await _press(tester, LogicalKeyboardKey.f5);
      expect(page.reloads, 1);
      await _press(tester, LogicalKeyboardKey.arrowLeft, alt: true);
      expect(page.state.value.url, Uri.parse('https://a.it'));
      await _press(tester, LogicalKeyboardKey.equal, ctrl: true);
      expect(page.state.value.zoom, 1.1);
      await _press(tester, LogicalKeyboardKey.digit0, ctrl: true);
      expect(page.state.value.zoom, 1);

      await _press(tester, LogicalKeyboardKey.keyW, ctrl: true);
      expect(container.read(browserProvider).tabs, isEmpty);
      await _press(tester, LogicalKeyboardKey.keyT, ctrl: true, shift: true);
      expect(container.read(browserProvider).active?.url, 'https://a.it');

      await _press(tester, LogicalKeyboardKey.keyL, ctrl: true);
      expect(container.read(addressFocusProvider).hasFocus, isTrue);
      await _press(tester, LogicalKeyboardKey.escape);
      expect(container.read(addressFocusProvider).hasFocus, isFalse);
    });

    testWidgets('closing the last web tab gives the panel back to the chat', (tester) async {
      final engine = FakeEngine();
      final container = await _pumpApp(tester, engine);
      await _press(tester, LogicalKeyboardKey.keyT, ctrl: true);
      expect(find.byType(AddressBar), findsOneWidget);
      await _press(tester, LogicalKeyboardKey.keyW, ctrl: true);
      expect(container.read(browserProvider).tabs, isEmpty);
      expect(find.byType(AddressBar), findsNothing);
      expect(find.text('Gazzetta Ufficiale'), findsNothing);
    });

    testWidgets('a portal of the lawyer is added from the page menu, renamed and removed', (tester) async {
      final engine = FakeEngine();
      final container = await _pumpApp(tester, engine);
      await _press(tester, LogicalKeyboardKey.keyT, ctrl: true);
      await _go(tester, 'intranet.studio.it');
      await tester.tap(_tip(itL10n.browserMore));
      await _pump(tester);
      await tester.tap(find.text(itL10n.browserAddPortal));
      await _pump(tester);
      // The dialog offers the page's title as the name.
      expect(find.widgetWithText(TextField, 'Pagina intranet.studio.it'), findsOneWidget);
      await tester.tap(find.text(itL10n.browserPortalAdd));
      await _pump(tester);
      final mine = container.read(browserProvider).portals.where((p) => p.group == PortalGroup.mine);
      expect(mine.single.url, 'https://intranet.studio.it');

      await _press(tester, LogicalKeyboardKey.keyT, ctrl: true);
      expect(find.text(itL10n.browserPortalsMineEmpty), findsNothing);
      // The row's menu: there for the keyboard even before the pointer reaches the row.
      Finder rowMenu() => find.descendant(
        of: find.ancestor(of: find.text('intranet.studio.it'), matching: find.byType(InkWell)).first,
        matching: _tip(itL10n.browserMore),
      );
      await tester.tap(rowMenu());
      await _pump(tester);
      await tester.tap(find.text(itL10n.rename));
      await _pump(tester);
      expect(find.text(itL10n.browserPortalRenameTitle), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Pagina intranet.studio.it'), 'Intranet dello studio');
      await tester.tap(find.text(itL10n.save));
      await _pump(tester);
      expect(find.text('Intranet dello studio'), findsOneWidget);

      await tester.tap(rowMenu());
      await _pump(tester);
      await tester.tap(find.text(itL10n.browserPortalRemove));
      await _pump(tester);
      expect(find.text('Intranet dello studio'), findsNothing);
      expect(find.text(itL10n.browserPortalsMineEmpty), findsOneWidget);
    });

    testWidgets('where pages cannot be shown, a tab says so and opens its address outside', (tester) async {
      final engine = FakeEngine(BrowserSupport.external);
      final container = await _pumpApp(tester, engine);
      await _press(tester, LogicalKeyboardKey.keyT, ctrl: true);
      expect(find.text(itL10n.browserExternalTitle), findsOneWidget);
      expect(find.text('Gazzetta Ufficiale'), findsOneWidget, reason: 'the portals are still one click away');
      container.read(browserProvider.notifier).go(container.read(browserProvider).active!.id, 'https://a.it/');
      await _pump(tester);
      expect(find.text(itL10n.browserOpenOutside), findsOneWidget);
      expect(engine.pages, isEmpty);
      // No page here ever goes back, reloads or can be attached: the bar keeps only what works.
      for (final dead in [itL10n.browserBack, itL10n.browserForward, itL10n.browserReload, itL10n.browserAttachHelp]) {
        expect(_tip(dead), findsNothing, reason: dead);
      }
      expect(_tip(itL10n.browserOpenOutsideHelp), findsOneWidget);
    });

    testWidgets('without WebView2 the tab says what to install', (tester) async {
      final engine = FakeEngine(BrowserSupport.missingRuntime);
      await _pumpApp(tester, engine);
      await _press(tester, LogicalKeyboardKey.keyT, ctrl: true);
      expect(find.text(itL10n.browserRuntimeTitle), findsOneWidget);
      expect(find.text(itL10n.browserRuntimeDownload), findsOneWidget);
      expect(_tip(itL10n.browserBack), findsOneWidget, reason: 'once WebView2 is installed, the bar works');
    });

    testWidgets('signing out of every portal asks first, then clears the browser', (tester) async {
      final engine = FakeEngine();
      await _pumpApp(tester, engine);
      await tester.tap(_tip(itL10n.settings));
      await _pump(tester);
      final button = find.widgetWithText(OutlinedButton, itL10n.settingsBrowserSignOutButton);
      await tester.ensureVisible(button);
      await _pump(tester);
      await tester.tap(button);
      await _pump(tester);
      expect(find.text(itL10n.settingsBrowserSignOutConfirmTitle), findsOneWidget);
      await tester.tap(find.text(itL10n.cancel));
      await _pump(tester);
      expect(engine.cleared, 0);

      await tester.tap(button);
      await _pump(tester);
      await tester.tap(find.widgetWithText(FilledButton, itL10n.settingsBrowserSignOutButton));
      await _pump(tester);
      expect(engine.cleared, 1);
      expect(find.text(itL10n.settingsBrowserSignedOut), findsOneWidget);
    });

    testWidgets('the full-width panel hides the chat and gives it back', (tester) async {
      final engine = FakeEngine();
      await _pumpApp(tester, engine);
      await _press(tester, LogicalKeyboardKey.keyT, ctrl: true);
      final panelWidth = tester.getSize(find.byType(AddressBar)).width;
      await tester.tap(_tip(itL10n.panelFull));
      await _pump(tester);
      expect(tester.getSize(find.byType(AddressBar)).width, greaterThan(panelWidth + 300));
      await tester.tap(_tip(itL10n.panelSplit));
      await _pump(tester);
      expect(tester.getSize(find.byType(AddressBar)).width, moreOrLessEquals(panelWidth));
    });

    testWidgets('a window with no room beside the chat shows the panel in its place, and gives the chat back', (
      tester,
    ) async {
      final engine = FakeEngine();
      await _pumpApp(tester, engine, size: const Size(900, 640));
      expect(find.text(itL10n.chatWhatToWrite), findsOneWidget);

      await _press(tester, LogicalKeyboardKey.keyT, ctrl: true);
      expect(find.text('Normattiva'), findsOneWidget, reason: 'what Ctrl+T opened is on screen');
      expect(find.text(itL10n.chatWhatToWrite), findsNothing, reason: "in the chat's place");
      expect(_tip(itL10n.panelSplit), findsNothing, reason: 'there is no room to put it beside the chat');

      await tester.tap(_tip(itL10n.panelHide));
      await _pump(tester);
      expect(find.text('Normattiva'), findsNothing);
      expect(find.text(itL10n.chatWhatToWrite), findsOneWidget);
    });

    test('without room beside the chat, the panel asked for is seen: the first press shows it', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ui = container.read(uiProvider.notifier);
      ui.setPanelFits(false);
      expect(container.read(uiProvider).panelShown, isFalse, reason: 'open, but the chat comes first');

      ui.togglePanel();
      expect(container.read(uiProvider).panelShown, isTrue);
      ui.togglePanel();
      expect(container.read(uiProvider).panelShown, isFalse);
      ui.showPanel();
      expect(container.read(uiProvider).panelShown, isTrue);

      ui.setPanelFits(true);
      ui.togglePanel();
      expect(container.read(uiProvider).panelShown, isFalse, reason: 'with room, the same press hides it');
    });
  });
}

const _step = Duration(milliseconds: 400);

/// A frame for the change, then time for what it animates (the panel slides in).
Future<void> _pump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(_step);
}

Future<ProviderContainer> _pumpApp(WidgetTester tester, FakeEngine engine, {Size size = const Size(1480, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(overrides: [browserEngineProvider.overrideWithValue(engine)], child: const PaperAgentApp()),
  );
  await tester.pump(const Duration(seconds: 1));
  final container = ProviderScope.containerOf(tester.element(find.byType(PaperAgentApp)));
  // What the engine supports is asked once, when the first tab shows: answered here already.
  await container.read(browserSupportProvider.future);
  return container;
}

/// A button by its tooltip, which adds the button's shortcut when it has one: «Indietro  ·  Alt ←».
Finder _tip(String label) => find.byWidgetPredicate(
  (w) => w is Tooltip && (w.message == label || (w.message?.startsWith('$label  ·  ') ?? false)),
);

Future<void> _press(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool ctrl = false,
  bool shift = false,
  bool alt = false,
}) async {
  final held = [
    if (ctrl) LogicalKeyboardKey.controlLeft,
    if (shift) LogicalKeyboardKey.shiftLeft,
    if (alt) LogicalKeyboardKey.altLeft,
  ];
  for (final k in held) {
    await tester.sendKeyDownEvent(k);
  }
  await tester.sendKeyEvent(key);
  for (final k in held.reversed) {
    await tester.sendKeyUpEvent(k);
  }
  await _pump(tester);
}

/// Types [input] in the address bar and presses Enter.
Future<void> _go(WidgetTester tester, String input) async {
  await tester.tap(find.byType(AddressBar));
  await _pump(tester);
  await tester.enterText(find.descendant(of: find.byType(AddressBar), matching: find.byType(EditableText)), input);
  await tester.testTextInput.receiveAction(TextInputAction.go);
  await _pump(tester);
}

/// Lets the files a page became be written and read: real disk work, which a widget test's clock does not run.
Future<void> _settleFiles(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class FakeEngine implements BrowserEngine {
  FakeEngine([this.supportAs = BrowserSupport.embedded]);

  final BrowserSupport supportAs;
  final pages = <FakePage>[];
  var cleared = 0;

  @override
  Future<BrowserSupport> support() async => supportAs;

  @override
  BrowserPage create(PageOptions options) {
    final page = FakePage();
    pages.add(page);
    return page;
  }

  @override
  Future<void> clearData() async => cleared++;
}

/// A page with a history and nothing on the network: an address loads at once, titled after its host.
class FakePage implements BrowserPage {
  final _state = ValueNotifier(const PageState());
  final _events = StreamController<PageEvent>.broadcast();
  final loaded = <Uri>[];
  final _history = <Uri>[];
  var _at = -1;
  var reloads = 0;
  var focuses = 0;
  var disposed = false;
  var captureFails = false;

  /// While set, the page is taken only once it completes.
  Completer<void>? captureHeld;

  void report(PageState state) => _state.value = state;

  void emit(PageEvent event) => _events.add(event);

  void _show() {
    final uri = _history[_at];
    _state.value = _state.value.copyWith(
      url: uri,
      title: 'Pagina ${uri.host}',
      loading: false,
      canGoBack: _at > 0,
      canGoForward: _at < _history.length - 1,
      problem: () => null,
    );
  }

  @override
  ValueListenable<PageState> get state => _state;

  @override
  Stream<PageEvent> get events => _events.stream;

  @override
  Future<void> load(Uri uri) async {
    loaded.add(uri);
    _history
      ..removeRange(_at + 1, _history.length)
      ..add(uri);
    _at = _history.length - 1;
    _show();
  }

  @override
  Future<void> back() async {
    if (_at > 0) _at--;
    _show();
  }

  @override
  Future<void> forward() async {
    if (_at < _history.length - 1) _at++;
    _show();
  }

  @override
  Future<void> reload() async {
    reloads++;
    _state.value = _state.value.copyWith(problem: () => null);
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> setZoom(double zoom) async => _state.value = _state.value.copyWith(zoom: zoom);

  @override
  Future<PageCapture> capture() async {
    await captureHeld?.future;
    if (captureFails) throw const CaptureFailed('the page did not answer');
    final s = _state.value;
    return HtmlCapture(url: s.url!, title: s.title, body: '<p>Art. 2043</p>');
  }

  @override
  Future<void> focus() async => focuses++;

  @override
  Widget view() => const SizedBox.expand(key: ValueKey('page'));

  @override
  Future<void> dispose() async {
    disposed = true;
    await _events.close();
  }
}
