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

/// What a failed load of the page means to the lawyer, from what WebKit reports; null when nothing failed. WebKit
/// names a network failure only by its code in NSURLErrorDomain, and ends a load whose certificate was refused
/// ([refusedHost], the site that presented it) as cancelled (-999), as it does when the lawyer goes elsewhere.
@visibleForTesting
PageProblem? webKitProblem(int code, {String? domain, Uri? url, String? refusedHost}) {
  if (domain == 'NSURLErrorDomain') {
    return switch (code) {
      -999 => refusedHost != null && url?.host == refusedHost ? PageProblem.certificate : null,
      -1001 => PageProblem.timeout,
      // The site's name unknown, no connection to it, the connection lost, no network at all.
      -1003 || -1004 || -1005 || -1006 || -1009 => PageProblem.unreachable,
      // No secure connection: the certificate expired, untrusted, of an unknown root, not yet valid, or one of ours
      // refused or required.
      <= -1200 && >= -1206 => PageProblem.certificate,
      _ => PageProblem.other,
    };
  }
  // A policy took the load over (102, a download or the system), or a plug-in shows it (204, a PDF): nothing failed.
  if (code == 102 || code == 204) return null;
  return PageProblem.other;
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
          onPageStarted: (url) {
            _refusedHost = null;
            current = current.copyWith(url: Uri.tryParse(url), loading: true, problem: () => null, icon: () => null);
          },
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
            if (e.isForMainFrame == false) return;
            final problem = webKitProblem(
              e.errorCode,
              domain: e is WebKitWebResourceError ? e.domain : null,
              url: Uri.tryParse(e.url ?? ''),
              refusedHost: _refusedHost,
            );
            if (problem != null) current = current.copyWith(loading: false, problem: () => problem);
          },
          // A certificate that is not valid is never accepted (rfc/052 §9). WebKit reports the refused load only as
          // cancelled: the site that presented it is kept to tell the two apart.
          onSslAuthError: (e) {
            final error = e.platform;
            if (error is WebKitSslAuthError) _refusedHost = error.host;
            unawaited(e.cancel());
          },
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
      // Not inspectable is already WebKit's default; before macOS 13.3 the setting does not exist and the call fails.
      platform.setInspectable(false).ignore();
      unawaited(platform.setAllowsBackForwardNavigationGestures(true));
    }
  }

  static const _channel = 'DaylexPage';
  static const _post = 'window.$_channel.postMessage(JSON.stringify(m))';

  /// Camera, microphone and the rest: no site gets them here (rfc/052 §9).
  final _controller = WebViewController(onPermissionRequest: (request) => request.deny());
  final String _script;

  /// The site whose certificate this load refused, until the next load starts.
  String? _refusedHost;

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
