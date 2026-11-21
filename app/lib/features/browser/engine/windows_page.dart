import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart';

import 'browser_page.dart';
import 'page_script.dart';
import 'scripted_page.dart';

/// WebView2, drawn into a Flutter texture: the app's menus and dialogs stay above the page. Every tab shares one
/// profile in [profileDir], so a login made in one tab holds in the others and after a restart.
class WindowsBrowser implements BrowserEngine {
  WindowsBrowser(this.profileDir);

  final String profileDir;
  Future<void>? _environment;
  final _live = <WindowsPage>{};

  /// Left by [clearData]: the next start deletes the whole profile before any page opens.
  File get _resetMark => File('$profileDir.reset');

  /// The profile is set once, before the first page; it cannot change while a page is open.
  Future<void> _ready() => _environment ??= () async {
    if (_resetMark.existsSync()) await _wipe();
    try {
      await WebviewController.initializeEnvironment(userDataPath: profileDir);
    } on Object catch (e) {
      debugPrint('Daylex browser: profile not set: $e');
    }
  }();

  Future<void> _wipe() async {
    try {
      final dir = Directory(profileDir);
      if (dir.existsSync()) await dir.delete(recursive: true);
      if (_resetMark.existsSync()) await _resetMark.delete();
    } on FileSystemException catch (e) {
      debugPrint('Daylex browser: profile not deleted: $e');
    }
  }

  @override
  Future<BrowserSupport> support() async {
    try {
      return await WebviewController.getWebViewVersion() == null
          ? BrowserSupport.missingRuntime
          : BrowserSupport.embedded;
    } on Object {
      return BrowserSupport.missingRuntime;
    }
  }

  @override
  BrowserPage create(PageOptions options) => WindowsPage._(this, options);

  /// Cookies go now, from every site; storage and the rest of the profile at the next start, when no browser
  /// process holds them. Before any page opened in this session, the whole profile goes now.
  @override
  Future<void> clearData() async {
    await _resetMark.create(recursive: true);
    if (_environment == null) return _wipe();
    final page = _live.where((p) => p._controller.value.isInitialized).firstOrNull;
    if (page != null) return page._clearData();
    // No tab is open: a page of its own, for as long as it takes.
    final temporary = WindowsPage._(this, const PageOptions());
    try {
      await temporary._started;
      await temporary._clearData();
    } finally {
      await temporary.dispose();
    }
  }
}

class WindowsPage extends ScriptedPage {
  WindowsPage._(this._engine, PageOptions options) {
    _engine._live.add(this);
    _started = _start(options)..ignore();
  }

  final WindowsBrowser _engine;
  final _controller = WebviewController();
  final _subscriptions = <StreamSubscription<Object?>>[];
  late final Future<void> _started;

  Future<void> _start(PageOptions options) async {
    try {
      await _engine._ready();
      await _controller.initialize();
      // Popups some logins need stay windows of their own; a link for a new window becomes a tab (page script).
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.allow);
      await _controller.setDevToolsEnabled(false);
      await _controller.setDefaultContextMenusEnabled(true);
      await _controller.addScriptToExecuteOnDocumentCreated(
        pageScript(
          appKeys: options.appKeys,
          outsideFieldKeys: options.outsideFieldKeys,
          post: 'window.chrome.webview.postMessage(m)',
        ),
      );
    } on Object catch (e) {
      debugPrint('Daylex browser: WebView2 did not start: $e');
      current = current.copyWith(loading: false, problem: () => PageProblem.engine);
      rethrow;
    }
    _subscriptions.addAll([
      _controller.url.listen((url) {
        final uri = Uri.tryParse(url);
        if (uri != null) current = current.copyWith(url: uri);
      }),
      _controller.title.listen((title) => current = current.copyWith(title: title)),
      _controller.loadingState.listen(
        (s) => current = s == LoadingState.loading
            ? current.copyWith(loading: true, problem: () => null, icon: () => null)
            : current.copyWith(loading: false),
      ),
      _controller.historyChanged.listen(
        (h) => current = current.copyWith(canGoBack: h.canGoBack, canGoForward: h.canGoForward),
      ),
      _controller.onLoadError.listen((status) {
        final problem = _problemOf(status);
        if (problem == null) return;
        debugPrint('Daylex browser: the page did not load: $status');
        current = current.copyWith(problem: () => problem);
      }),
      _controller.webMessage.listen(onMessage, onError: (Object _) {}),
      _controller.onDownloadEvent.listen((d) {
        if (d.kind == WebviewDownloadEventKind.downloadCompleted && d.resultFilePath.isNotEmpty) {
          current = current.copyWith(download: () => d.resultFilePath);
        }
      }),
    ]);
  }

  static PageProblem? _problemOf(WebErrorStatus status) => switch (status) {
    // Stopped, or left for another page: nothing went wrong. Sign-in prompts are WebView2's own.
    WebErrorStatus.operationCanceled ||
    WebErrorStatus.validAuthenticationCredentialsRequired ||
    WebErrorStatus.validProxyAuthenticationRequired => null,
    WebErrorStatus.certificateCommonNameIsIncorrect ||
    WebErrorStatus.certificateExpired ||
    WebErrorStatus.clientCertificateContainsErrors ||
    WebErrorStatus.certificateRevoked ||
    WebErrorStatus.certificateIsInvalid => PageProblem.certificate,
    WebErrorStatus.timeout => PageProblem.timeout,
    WebErrorStatus.serverUnreachable ||
    WebErrorStatus.connectionAborted ||
    WebErrorStatus.connectionReset ||
    WebErrorStatus.disconnected ||
    WebErrorStatus.cannotConnect ||
    WebErrorStatus.hostNameNotResolved => PageProblem.unreachable,
    _ => PageProblem.other,
  };

  /// Runs [action] once WebView2 is up; nothing when it could not start (the page shows why).
  Future<void> _when(Future<void> Function() action) async {
    try {
      await _started;
    } on Object {
      return;
    }
    await action();
  }

  @override
  Future<void> load(Uri uri) {
    current = current.copyWith(url: uri, loading: true, problem: () => null);
    return _when(() => _controller.loadUrl(uri.toString()));
  }

  @override
  Future<void> back() => _when(_controller.goBack);

  @override
  Future<void> forward() => _when(_controller.goForward);

  @override
  Future<void> reload() {
    current = current.copyWith(problem: () => null);
    return _when(_controller.reload);
  }

  @override
  Future<void> stop() => _when(_controller.stop);

  @override
  Future<void> setZoom(double zoom) {
    current = current.copyWith(zoom: zoom);
    return _when(() => _controller.setZoomFactor(zoom));
  }

  @override
  Future<void> focus() => _when(_controller.focus);

  @override
  @protected
  Future<Object?> evaluate(String script) async {
    await _started;
    return _controller.executeScript(script);
  }

  @override
  @protected
  Future<String?> cookiesFor(Uri url) async {
    final cookies = await _controller.getCookies(url.toString());
    return cookies.isEmpty ? null : cookies.map((c) => '${c.name}=${c.value}').join('; ');
  }

  Future<void> _clearData() async {
    await _controller.clearCookies();
    await _controller.clearCache();
  }

  @override
  Widget view() => _PageView(page: this);

  /// The keyboard back to the app, when this page holds it. WebView2 keeps it in a page taken off screen (a
  /// shortcut pressed in the page opened, closed or switched a tab), and the plugin hands it back only from the
  /// pages on screen: everything the lawyer typed next would go to a page no one sees.
  Future<void> _releaseKeyboard() async {
    if (_controller.hasNativeFocus) await WebviewController.releaseFocus();
  }

  @override
  Future<void> dispose() async {
    _engine._live.remove(this);
    await _releaseKeyboard();
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await close();
    await _controller.dispose();
  }
}

/// The page on screen; taken off screen, it gives the keyboard back.
class _PageView extends StatefulWidget {
  const _PageView({required this.page});

  final WindowsPage page;

  @override
  State<_PageView> createState() => _PageViewState();
}

class _PageViewState extends State<_PageView> {
  @override
  void dispose() {
    unawaited(widget.page._releaseKeyboard());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: widget.page._controller,
    builder: (context, value, _) => value.isInitialized
        ? Webview(widget.page._controller, permissionRequested: (_, _, _) async => WebviewPermissionDecision.deny)
        : const SizedBox.expand(),
  );
}
