import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'browser_page.dart';
import 'page_script.dart';

/// What every engine's page shares: the state the chrome watches, the page script's messages, the capture for the
/// chat. An engine adds how to run a script and how to draw the page.
abstract class ScriptedPage implements BrowserPage {
  /// How long a page has to hand itself over for the chat.
  static const captureWait = Duration(seconds: 30);

  final _state = ValueNotifier(const PageState());
  final _events = StreamController<PageEvent>.broadcast();
  final _captures = <String, Completer<CaptureMessage>>{};
  var _captureCount = 0;
  var _closed = false;

  @override
  ValueListenable<PageState> get state => _state;

  @override
  Stream<PageEvent> get events => _events.stream;

  PageState get current => _state.value;

  @protected
  set current(PageState value) {
    if (!_closed) _state.value = value;
  }

  @protected
  void emit(PageEvent event) {
    if (!_closed) _events.add(event);
  }

  /// Runs [script] in the page and returns its value as JSON would carry it.
  @protected
  Future<Object?> evaluate(String script);

  /// The cookies the page would send to [url], as a header, for a PDF fetched outside the page.
  @protected
  Future<String?> cookiesFor(Uri url) async => null;

  /// What the page script sent.
  @protected
  void onMessage(Object? message) {
    switch (readPageMessage(message)) {
      case KeyMessage(:final combo):
        emit(PageKey(combo));
      case NewTabMessage(:final uri):
        emit(OpenInNewTab(uri));
      case OutsideLinkMessage(:final uri):
        emit(OpenOutside(uri));
      case ZoomMessage(:final step):
        emit(PageZoom(step));
      case IconMessage(:final url):
        current = current.copyWith(icon: () => url);
      case final CaptureMessage m:
        _captures.remove(m.id)?.complete(m);
      case null:
        break;
    }
  }

  @override
  Future<PageCapture> capture() async {
    final url = current.url;
    if (url == null) throw const CaptureFailed('no page');
    if (await evaluate('!!window.__daylex') != true) return _fetchPdf(url);
    final id = 'capture-${++_captureCount}';
    final answer = _captures[id] = Completer<CaptureMessage>();
    await evaluate('window.__daylex.capture(${jsonEncode(id)})');
    final m = await answer.future.timeout(
      captureWait,
      onTimeout: () {
        _captures.remove(id);
        throw const CaptureFailed('the page did not answer');
      },
    );
    final data = m.data;
    if (m.error != null || data == null) throw CaptureFailed(m.error ?? 'empty page');
    final title = m.title.trim().isEmpty ? current.title : m.title.trim();
    return m.kind == 'pdf'
        ? PdfCapture(url: url, title: title, bytes: base64Decode(data))
        : HtmlCapture(url: url, title: title, body: data);
  }

  /// A page the script does not reach (an engine's own PDF viewer): fetched again with the page's cookies, and
  /// taken only if it is a PDF.
  Future<PageCapture> _fetchPdf(Uri url) async {
    final cookie = await cookiesFor(url);
    final http.Response response;
    try {
      response = await http.get(url, headers: {'cookie': ?cookie}).timeout(captureWait);
    } on Object catch (e) {
      throw CaptureFailed('$e');
    }
    final type = response.headers['content-type'] ?? '';
    if (response.statusCode != 200 || !type.toLowerCase().startsWith('application/pdf')) {
      throw CaptureFailed('HTTP ${response.statusCode} $type');
    }
    return PdfCapture(url: url, title: current.title, bytes: response.bodyBytes);
  }

  /// Ends what the page started: a capture still waiting fails, the chrome stops listening.
  @protected
  Future<void> close() async {
    if (_closed) return;
    for (final c in _captures.values) {
      c.completeError(const CaptureFailed('the tab was closed'));
    }
    _captures.clear();
    _closed = true;
    await _events.close();
  }
}
