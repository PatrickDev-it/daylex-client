import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// One web page in a tab, whatever engine draws it: WebView2 on Windows, WebKit on the Mac, a fake in tests.
/// Nothing outside `features/browser/engine` imports a webview package (rfc/052).
abstract class BrowserPage {
  ValueListenable<PageState> get state;

  /// What the page asks of the app: a link for a new tab, a shortcut pressed inside it, a download.
  Stream<PageEvent> get events;

  Future<void> load(Uri uri);
  Future<void> back();
  Future<void> forward();
  Future<void> reload();
  Future<void> stop();

  /// 1 is the page's own size ([zoomSteps]).
  Future<void> setZoom(double zoom);

  /// The page as a file for the chat: a PDF as its own bytes, fetched with the page's session; anything else as
  /// its HTML without scripts, styles or frames. Throws [CaptureFailed] when the page does not answer.
  Future<PageCapture> capture();

  /// Gives the page the keyboard.
  Future<void> focus();

  Widget view();
  Future<void> dispose();
}

/// The zoom levels a page steps through, as in a desktop browser.
const zoomSteps = [0.5, 0.67, 0.75, 0.8, 0.9, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0];

/// The zoom one [step] (1 in, -1 out) from [zoom]; the nearest end past either end.
double zoomStep(double zoom, int step) {
  if (step > 0) return zoomSteps.firstWhere((z) => z > zoom + 0.001, orElse: () => zoomSteps.last);
  return zoomSteps.lastWhere((z) => z < zoom - 0.001, orElse: () => zoomSteps.first);
}

/// Why a page could not be shown, as the lawyer can act on it.
enum PageProblem {
  /// No connection, or the site's name is unknown.
  unreachable,
  timeout,

  /// The site's certificate is not valid: the page is not shown, and cannot be forced.
  certificate,

  /// The engine itself failed to start.
  engine,
  other,
}

@immutable
class PageState {
  const PageState({
    this.url,
    this.title = '',
    this.icon,
    this.loading = false,
    this.canGoBack = false,
    this.canGoForward = false,
    this.problem,
    this.zoom = 1,
    this.download,
  });

  final Uri? url;
  final String title;
  final String? icon;
  final bool loading;
  final bool canGoBack;
  final bool canGoForward;
  final PageProblem? problem;
  final double zoom;

  /// The file the page saved last, until the lawyer dismisses it.
  final String? download;

  /// A page with a [problem] has no title: the one it shows is the engine's error page («Errore dell'orologio»),
  /// and it stays out when the page tries again.
  PageState copyWith({
    Uri? url,
    String? title,
    String? Function()? icon,
    bool? loading,
    bool? canGoBack,
    bool? canGoForward,
    PageProblem? Function()? problem,
    double? zoom,
    String? Function()? download,
  }) {
    final failed = problem != null ? problem() : this.problem;
    return PageState(
      url: url ?? this.url,
      title: failed != null ? '' : title ?? this.title,
      icon: icon != null ? icon() : this.icon,
      loading: loading ?? this.loading,
      canGoBack: canGoBack ?? this.canGoBack,
      canGoForward: canGoForward ?? this.canGoForward,
      problem: failed,
      zoom: zoom ?? this.zoom,
      download: download != null ? download() : this.download,
    );
  }
}

sealed class PageEvent {
  const PageEvent();
}

/// A link the lawyer opened in a new tab: one with a target, or clicked with Ctrl or the middle button.
class OpenInNewTab extends PageEvent {
  const OpenInNewTab(this.uri);

  final Uri uri;
}

/// A link the lawyer clicked to what no tab shows: mail, a phone number, another app. The page does not follow it.
class OpenOutside extends PageEvent {
  const OpenOutside(this.uri);

  final Uri uri;
}

/// An app shortcut pressed while the page had the keyboard: the page never sees it.
class PageKey extends PageEvent {
  const PageKey(this.combo);

  final KeyCombo combo;
}

/// Ctrl and the mouse wheel (or a pinch) over the page: one zoom step in, or out.
class PageZoom extends PageEvent {
  const PageZoom(this.step);

  /// 1 in, -1 out.
  final int step;
}

/// A key combination as a page sees it: `KeyboardEvent.key` (compared without case: "t" with Shift is "T") and the
/// modifiers. The key, not the physical position: the same as Flutter's logical keys, on any keyboard layout.
@immutable
class KeyCombo {
  const KeyCombo(this.key, {this.ctrl = false, this.shift = false, this.alt = false, this.meta = false});

  final String key;
  final bool ctrl;
  final bool shift;
  final bool alt;
  final bool meta;

  Map<String, Object> toJson() => {'key': key, 'ctrl': ctrl, 'shift': shift, 'alt': alt, 'meta': meta};

  static KeyCombo? fromJson(Object? json) => json is Map && json['key'] is String
      ? KeyCombo(
          json['key'] as String,
          ctrl: json['ctrl'] == true,
          shift: json['shift'] == true,
          alt: json['alt'] == true,
          meta: json['meta'] == true,
        )
      : null;

  @override
  bool operator ==(Object other) =>
      other is KeyCombo &&
      other.key.toLowerCase() == key.toLowerCase() &&
      other.ctrl == ctrl &&
      other.shift == shift &&
      other.alt == alt &&
      other.meta == meta;

  @override
  int get hashCode => Object.hash(key.toLowerCase(), ctrl, shift, alt, meta);
}

sealed class PageCapture {
  const PageCapture({required this.url, required this.title});

  final Uri url;
  final String title;
}

/// The page's HTML, already without scripts, styles and frames.
class HtmlCapture extends PageCapture {
  const HtmlCapture({required super.url, required super.title, required this.body});

  /// The inside of the page's body.
  final String body;
}

class PdfCapture extends PageCapture {
  const PdfCapture({required super.url, required super.title, required this.bytes});

  final Uint8List bytes;
}

class CaptureFailed implements Exception {
  const CaptureFailed(this.reason);

  final String reason;

  @override
  String toString() => 'CaptureFailed: $reason';
}

/// What a page needs from the app to ask the lawyer something (WebKit draws no dialog of its own).
abstract interface class PageDialogs {
  Future<void> alert(String message);
  Future<bool> confirm(String message);
  Future<String?> prompt(String message, String? value);
}

/// How each page is set up: the shortcuts it hands to the app, the dialogs it may show.
class PageOptions {
  const PageOptions({this.appKeys = const [], this.outsideFieldKeys = const [], this.dialogs});

  /// Shortcuts the app takes wherever the keyboard is in the page.
  final List<KeyCombo> appKeys;

  /// Shortcuts the app takes unless a text field of the page has the keyboard: there they are the page's own.
  final List<KeyCombo> outsideFieldKeys;
  final PageDialogs? dialogs;
}

/// Whether this computer can show web pages inside the app.
enum BrowserSupport {
  /// Pages open in their tab.
  embedded,

  /// Windows without the WebView2 runtime: it has to be installed first.
  missingRuntime,

  /// No engine on this platform (Linux, the web app): a tab opens its address in the system browser.
  external,
}

abstract class BrowserEngine {
  Future<BrowserSupport> support();

  BrowserPage create(PageOptions options);

  /// Signs the lawyer out of every site: cookies, storage and cache of the browser profile go.
  Future<void> clearData();
}

/// No engine: [support] says so and the tab offers the system browser instead.
class ExternalBrowser implements BrowserEngine {
  const ExternalBrowser();

  @override
  Future<BrowserSupport> support() async => BrowserSupport.external;

  @override
  BrowserPage create(PageOptions options) => throw UnsupportedError('No web engine on this platform');

  @override
  Future<void> clearData() async {}
}
