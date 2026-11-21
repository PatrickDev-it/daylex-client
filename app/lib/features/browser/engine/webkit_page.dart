import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../web_address.dart';
import 'browser_page.dart';
import 'page_script.dart';
import 'scripted_page.dart';

/// WebKit on the Mac. Its default data store is persistent and shared by every tab, so a login holds in the
/// others and after a restart. WebKit has no download API (a PDF opens in the tab) and draws no dialog of its own.
class WebKitBrowser implements BrowserEngine {
  @override
  Future<BrowserSupport> support() async => BrowserSupport.embedded;

  @override
  BrowserPage create(PageOptions options) => WebKitPage._(options);

  @override
  Future<void> clearData() async {
    await WebViewCookieManager().clearCookies();
    // Local storage and caches of every site go with the data store's records.
    await WebViewController().clearLocalStorage();
  }
}

class WebKitPage extends ScriptedPage {
  WebKitPage._(PageOptions options)
    : _script = pageScript(appKeys: options.appKeys, outsideFieldKeys: options.outsideFieldKeys, post: _post) {
    final dialogs = options.dialogs;
    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(_channel, onMessageReceived: (m) => onMessage(m.message))
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _decide,
          onPageStarted: (url) => current = current.copyWith(
            url: Uri.tryParse(url),
            loading: true,
            problem: () => null,
            icon: () => null,
          ),
          // The page script has no "before the page's own" slot here: it goes in as early as the page lets it.
          onProgress: (_) => unawaited(_install()),
          onPageFinished: (_) async {
            await _install();
            current = current.copyWith(
              loading: false,
              title: await _controller.getTitle() ?? current.title,
              canGoBack: await _controller.canGoBack(),
              canGoForward: await _controller.canGoForward(),
            );
          },
          onUrlChange: (change) async {
            final uri = Uri.tryParse(change.url ?? '');
            if (uri == null) return;
            current = current.copyWith(
              url: uri,
              canGoBack: await _controller.canGoBack(),
              canGoForward: await _controller.canGoForward(),
            );
          },
          onWebResourceError: (e) {
            // Cancelled (-999), or interrupted by a policy (102): the lawyer went elsewhere, nothing failed.
            if (e.isForMainFrame == false || e.errorCode == -999 || e.errorCode == 102) return;
            current = current.copyWith(loading: false, problem: () => _problemOf(e.errorType));
          },
          onSslAuthError: (e) => e.cancel(),
        ),
      );
    if (dialogs != null) {
      _controller
        ..setOnJavaScriptAlertDialog((r) => dialogs.alert(r.message))
        ..setOnJavaScriptConfirmDialog((r) => dialogs.confirm(r.message))
        ..setOnJavaScriptTextInputDialog((r) async => await dialogs.prompt(r.message, r.defaultText) ?? '');
    }
    final platform = _controller.platform;
    if (platform is WebKitWebViewController) {
      unawaited(platform.setInspectable(false));
      unawaited(platform.setAllowsBackForwardNavigationGestures(true));
    }
  }

  static const _channel = 'DaylexPage';
  static const _post = 'window.$_channel.postMessage(JSON.stringify(m))';

  /// Camera, microphone and the rest: no site gets them here (rfc/052 §9).
  final _controller = WebViewController(onPermissionRequest: (request) => request.deny());
  final String _script;

  Future<void> _install() async {
    try {
      await _controller.runJavaScript(_script);
    } on Object {
      // A page between two documents: the next progress step installs it.
    }
  }

  /// Web pages open here; mail and phone go to the system; nothing else opens.
  NavigationDecision _decide(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    if (uri.scheme == 'about' || uri.scheme == 'blob') return NavigationDecision.navigate;
    switch (navigationFor(uri)) {
      case Navigation.web:
        return NavigationDecision.navigate;
      case Navigation.system:
        unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
        return NavigationDecision.prevent;
      case Navigation.refused:
        return NavigationDecision.prevent;
    }
  }

  static PageProblem _problemOf(WebResourceErrorType? type) => switch (type) {
    WebResourceErrorType.failedSslHandshake => PageProblem.certificate,
    WebResourceErrorType.timeout => PageProblem.timeout,
    WebResourceErrorType.connect || WebResourceErrorType.hostLookup => PageProblem.unreachable,
    _ => PageProblem.other,
  };

  @override
  Future<void> load(Uri uri) {
    current = current.copyWith(url: uri, loading: true, problem: () => null);
    return _controller.loadRequest(uri);
  }

  @override
  Future<void> back() => _controller.goBack();

  @override
  Future<void> forward() => _controller.goForward();

  @override
  Future<void> reload() {
    current = current.copyWith(problem: () => null);
    return _controller.reload();
  }

  @override
  Future<void> stop() => _controller.runJavaScript('window.stop()');

  @override
  Future<void> setZoom(double zoom) async {
    current = current.copyWith(zoom: zoom);
    await _controller.runJavaScript('document.documentElement.style.zoom = ${jsonEncode(zoom)}');
  }

  @override
  Future<void> focus() async {}

  @override
  @protected
  Future<Object?> evaluate(String script) async {
    final result = await _controller.runJavaScriptReturningResult(script);
    // WebKit hands a boolean back as 1 or 0.
    return result is num ? result != 0 : result;
  }

  @override
  Widget view() => WebViewWidget(controller: _controller);

  @override
  Future<void> dispose() async {
    await close();
    await _controller.loadRequest(Uri.parse('about:blank'));
  }
}
