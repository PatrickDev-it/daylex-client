import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../document/model/document.dart' show newId;
import '../storage/local_store.dart';
import 'portals.dart';

/// One web tab: where it is and what the page called itself. The page itself lives in a browser engine
/// (`LivePages`); this is what survives a restart.
class WebTab {
  const WebTab({required this.id, this.url, this.title = '', this.icon});

  final String id;

  /// Null on the new-tab page, before the lawyer picks a site.
  final String? url;
  final String title;

  /// The icon the page named for itself, if any.
  final String? icon;

  WebTab copyWith({String? url, String? title, String? Function()? icon}) => WebTab(
    id: id,
    url: url ?? this.url,
    title: title ?? this.title,
    icon: icon != null ? icon() : this.icon,
  );

  Map<String, dynamic> toJson() => {'id': id, 'url': ?url, 'title': title, 'icon': ?icon};

  static WebTab? fromJson(Object? json) {
    if (json is! Map || json['id'] is! String) return null;
    final url = json['url'], title = json['title'], icon = json['icon'];
    return WebTab(
      id: json['id'] as String,
      url: url is String ? url : null,
      title: title is String ? title : '',
      icon: icon is String ? icon : null,
    );
  }
}

/// The web tabs, shared by every chat (rfc/052): a new chat, or another one, finds them where they were.
class BrowserState {
  const BrowserState({
    this.tabs = const [],
    this.activeId,
    this.inFront = false,
    this.portals = builtInPortals,
    this.closed = const [],
  });

  final List<WebTab> tabs;

  /// The web tab the panel shows when a web tab is in front.
  final String? activeId;

  /// Whether the side panel shows the active web tab rather than the chat's own tab.
  final bool inFront;
  final List<Portal> portals;

  /// Tabs closed in this session, the last one last, for "reopen".
  final List<WebTab> closed;

  WebTab? get active => tabs.where((t) => t.id == activeId).firstOrNull;

  /// The web tab the side panel shows: the active one when it is in front, or when the chat has no tab of its
  /// own to show (the new-chat screen, a chat with every tab closed).
  WebTab? shownBeside({required bool chatTab}) => inFront || !chatTab ? active : null;

  BrowserState copyWith({
    List<WebTab>? tabs,
    String? Function()? activeId,
    bool? inFront,
    List<Portal>? portals,
    List<WebTab>? closed,
  }) => BrowserState(
    tabs: tabs ?? this.tabs,
    activeId: activeId != null ? activeId() : this.activeId,
    inFront: inFront ?? this.inFront,
    portals: portals ?? this.portals,
    closed: closed ?? this.closed,
  );
}

final browserProvider = NotifierProvider<BrowserNotifier, BrowserState>(BrowserNotifier.new);

class BrowserNotifier extends Notifier<BrowserState> {
  /// How many closed tabs "reopen" remembers.
  static const closedLimit = 20;

  Timer? _saveTimer;

  @override
  BrowserState build() {
    ref.onDispose(() => _saveTimer?.cancel());
    return fromJson(ref.read(localStoreProvider)?.readBrowser());
  }

  // -- tabs ----------------------------------------------------------------------

  /// Opens a tab on [url] (the new-tab page without one), right after [after] when given (a link the page opened
  /// in a new tab), last otherwise, and brings it in front. Returns its id.
  String open({String? url, String? after}) {
    final tab = WebTab(id: newId(), url: url);
    final at = after == null ? -1 : state.tabs.indexWhere((t) => t.id == after);
    final tabs = [...state.tabs]..insert(at < 0 ? state.tabs.length : at + 1, tab);
    _set(state.copyWith(tabs: tabs, activeId: () => tab.id, inFront: true));
    return tab.id;
  }

  /// Brings [id] in front.
  void activate(String id) {
    if (!state.tabs.any((t) => t.id == id)) return;
    _set(state.copyWith(activeId: () => id, inFront: true));
  }

  /// Closes [id]; closing the active tab activates the one before it, as with the chat's own tabs. With no web
  /// tab left, the chat's tab comes back in front.
  void close(String id) {
    final index = state.tabs.indexWhere((t) => t.id == id);
    if (index < 0) return;
    final tab = state.tabs[index];
    final rest = [...state.tabs]..removeAt(index);
    final closed = [...state.closed, if (tab.url != null) tab];
    final next = state.activeId != id
        ? state.activeId
        : rest.isEmpty
        ? null
        : rest[(index - 1).clamp(0, rest.length - 1)].id;
    _set(
      state.copyWith(
        tabs: rest,
        activeId: () => next,
        inFront: rest.isNotEmpty && state.inFront,
        closed: closed.length > closedLimit ? closed.sublist(closed.length - closedLimit) : closed,
      ),
    );
  }

  /// Opens the tab closed last again, on the address it had. False when there is none.
  bool reopenClosed() {
    if (state.closed.isEmpty) return false;
    final tab = state.closed.last;
    _set(
      state.copyWith(
        tabs: [...state.tabs, tab],
        activeId: () => tab.id,
        inFront: true,
        closed: state.closed.sublist(0, state.closed.length - 1),
      ),
    );
    return true;
  }

  /// The chat's own tab comes in front; the web tabs stay as they are.
  void yieldToChat() {
    if (state.inFront) _set(state.copyWith(inFront: false));
  }

  /// [id] now shows [url]: what the lawyer typed or picked, before the page answers.
  void go(String id, String url) => _change(id, (t) => WebTab(id: t.id, url: url));

  /// What the page reports about itself while it loads and after.
  void pageChanged(String id, {String? url, String? title, String? icon}) => _change(
    id,
    (t) => t.copyWith(url: url, title: title, icon: icon == null ? null : () => icon.isEmpty ? null : icon),
  );

  /// A page reports itself many times while it loads: only a real change is kept, and saved.
  void _change(String id, WebTab Function(WebTab) change) {
    final index = state.tabs.indexWhere((t) => t.id == id);
    if (index < 0) return;
    final before = state.tabs[index], after = change(before);
    if (after.url == before.url && after.title == before.title && after.icon == before.icon) return;
    _set(state.copyWith(tabs: [...state.tabs]..[index] = after));
  }

  // -- portals ---------------------------------------------------------------------

  void addPortal(String name, String url) => _set(
    state.copyWith(
      portals: [
        ...state.portals,
        Portal(id: newId(), name: name.trim().isEmpty ? url : name.trim(), url: url),
      ],
    ),
  );

  void renamePortal(String id, String name) {
    if (name.trim().isEmpty) return;
    _set(state.copyWith(portals: [for (final p in state.portals) p.id == id ? p.named(name.trim()) : p]));
  }

  void removePortal(String id) => _set(state.copyWith(portals: state.portals.where((p) => p.id != id).toList()));

  // -- saving ----------------------------------------------------------------------

  void _set(BrowserState next) {
    state = next;
    if (ref.read(localStoreProvider) == null) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(LocalStore.saveDelay, flush);
  }

  /// Writes the tabs and the portals now: on a timer after each change, and when the window closes.
  void flush() {
    _saveTimer?.cancel();
    final store = ref.read(localStoreProvider);
    if (store == null) return;
    try {
      store.writeBrowser(toJson(state));
    } on FileSystemException catch (e) {
      store.saveFailed(e);
    }
  }

  static Map<String, dynamic> toJson(BrowserState s) => {
    'tabs': [for (final t in s.tabs) t.toJson()],
    'activeId': ?s.activeId,
    'inFront': s.inFront,
    'portals': [for (final p in s.portals) p.toJson()],
    'builtIns': [for (final p in builtInPortals) p.id],
  };

  /// The saved tabs and portals. A ready portal the saved list has never seen is added; one the lawyer removed
  /// stays removed.
  static BrowserState fromJson(Map<String, dynamic>? json) {
    if (json == null) return const BrowserState();
    final tabs = [
      for (final t in json['tabs'] is List ? json['tabs'] as List : const []) ?WebTab.fromJson(t),
    ];
    final seen = {for (final id in json['builtIns'] is List ? json['builtIns'] as List : const []) id};
    final saved = json['portals'] is List
        ? [for (final p in json['portals'] as List) ?Portal.fromJson(p)]
        : builtInPortals;
    final activeId = json['activeId'];
    final active = tabs.any((t) => t.id == activeId) ? activeId as String : tabs.lastOrNull?.id;
    return BrowserState(
      tabs: tabs,
      activeId: active,
      inFront: json['inFront'] == true && active != null,
      portals: [...saved, ...builtInPortals.where((p) => !seen.contains(p.id) && !saved.any((s) => s.id == p.id))],
    );
  }
}
