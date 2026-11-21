import 'dart:async';

import 'package:flutter/foundation.dart';

import 'browser_state.dart';
import 'engine/engine.dart';

/// The web tabs that have a page in the engine. Each live page is a browser process (100-200 MB): at most [limit]
/// stay, the one shown longest ago released first; a released tab loads its address again when shown.
class LivePages {
  LivePages(this._engine, this._options, {required this.onChanged, this.limit = 6});

  final BrowserEngine _engine;
  final PageOptions _options;
  final int limit;

  /// What a page reports about itself, for its tab: called after the frame that changed it, never inside a build.
  final void Function(String id, PageState state) onChanged;

  /// Least recently shown first.
  final _pages = <String, BrowserPage>{};
  final _listeners = <String, VoidCallback>{};

  BrowserPage? pageOf(String id) => _pages[id];

  /// The page of [tab], started on its address if it was not live.
  BrowserPage pageFor(WebTab tab) {
    final live = _pages.remove(tab.id);
    if (live != null) return _pages[tab.id] = live;
    final page = _pages[tab.id] = _engine.create(_options);
    void listener() => scheduleMicrotask(() {
      if (identical(_pages[tab.id], page)) onChanged(tab.id, page.state.value);
    });
    page.state.addListener(listener);
    _listeners[tab.id] = listener;
    final url = Uri.tryParse(tab.url ?? '');
    if (url != null && url.hasScheme) unawaited(page.load(url));
    while (_pages.length > limit) {
      release(_pages.keys.first);
    }
    return page;
  }

  void release(String id) {
    final page = _pages.remove(id);
    if (page == null) return;
    page.state.removeListener(_listeners.remove(id)!);
    unawaited(page.dispose());
  }

  /// Releases the pages of tabs that are gone.
  void keepOnly(Iterable<String> ids) {
    final keep = ids.toSet();
    for (final id in _pages.keys.where((id) => !keep.contains(id)).toList()) {
      release(id);
    }
  }

  /// Signs out of every site and shows each open page as it now is.
  Future<void> clearData() async {
    await _engine.clearData();
    for (final page in _pages.values) {
      unawaited(page.reload());
    }
  }

  void dispose() {
    for (final id in _pages.keys.toList()) {
      release(id);
    }
  }
}
