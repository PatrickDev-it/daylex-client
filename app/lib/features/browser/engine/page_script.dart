import 'dart:convert';

import 'browser_page.dart';

/// The script every page of a tab runs before its own, the same on every engine:
/// - the app's shortcuts ([appKeys]) go to the app, not to the page, and so does Ctrl with the wheel (zoom);
///   [outsideFieldKeys] only while no text field of the page has the keyboard (Ctrl+B is bold in a web editor);
/// - a link the lawyer opens in a new window (a target, Ctrl or the middle button) becomes a new tab, and only
///   right after that click;
/// - a link to what no page shows (mail, a phone number, another app) goes to the app, which decides as for an
///   address typed in the bar; WebView2 would hand it to the system itself, then call the page unreachable;
/// - `__daylex.capture(id)` answers with the page for the chat ([BrowserPage.capture]);
/// - the page's icon is reported once it is known.
/// [post] is the engine's way out for the message `m`: WebView2 and WebKit name it differently. A frame of the
/// same site sends through the top page; a frame of another site sends nothing.
String pageScript({
  required List<KeyCombo> appKeys,
  List<KeyCombo> outsideFieldKeys = const [],
  required String post,
}) =>
    '''
(function () {
  if (window.__daylex) return;
  var top = window.top === window;
  var send = top
    ? function (m) { try { $post; } catch (e) {} }
    : function (m) { try { window.top.__daylex.send(m); } catch (e) {} };
  var keys = ${jsonEncode([
      for (final k in appKeys) {...k.toJson(), 'field': true},
      for (final k in outsideFieldKeys) {...k.toJson(), 'field': false},
    ])};

  function inField(e) {
    var t = e.composedPath ? e.composedPath()[0] : e.target;
    if (!t || t.nodeType !== 1) return false;
    if (t.isContentEditable) return true;
    var tag = t.tagName;
    return tag === 'TEXTAREA' || tag === 'SELECT' ||
      (tag === 'INPUT' && !/^(button|checkbox|color|file|hidden|image|radio|range|reset|submit)\$/i.test(t.type));
  }
  window.addEventListener('keydown', function (e) {
    for (var i = 0; i < keys.length; i++) {
      var k = keys[i];
      if (typeof e.key === 'string' && e.key.toLowerCase() === k.key.toLowerCase() && e.ctrlKey === k.ctrl &&
          e.shiftKey === k.shift && e.altKey === k.alt && e.metaKey === k.meta) {
        if (!k.field && inField(e)) return;
        e.preventDefault();
        e.stopImmediatePropagation();
        send({type: 'key', key: k.key, ctrl: k.ctrl, shift: k.shift, alt: k.alt, meta: k.meta});
        return;
      }
    }
  }, true);

  // Ctrl and the wheel, or a pinch, zoom the page by the app's steps: the zoom the tab's menu shows.
  var wheel = 0;
  window.addEventListener('wheel', function (e) {
    if (!e.ctrlKey) return;
    e.preventDefault();
    wheel += e.deltaY;
    if (Math.abs(wheel) >= 100) {
      send({type: 'zoom', step: wheel < 0 ? 1 : -1});
      wheel = 0;
    }
  }, {passive: false, capture: true});

  function hasFrame(w, name) {
    for (var i = 0; i < w.frames.length; i++) {
      try { if (w.frames[i].name === name || hasFrame(w.frames[i], name)) return true; } catch (e) {}
    }
    return false;
  }
  function opensWindow(target) {
    if (!target || target === '_self' || target === '_top' || target === '_parent') return false;
    if (target === '_blank') return true;
    try { return !hasFrame(window.top, target); } catch (e) { return false; }
  }
  function onClick(e) {
    if (e.defaultPrevented || e.button > 1) return;
    var a = e.target;
    while (a && !(a.tagName === 'A' && a.href)) a = a.parentElement;
    if (!a || typeof a.href !== 'string') return;
    // The page's own scripts, files and pages are the engine's; anything else is the app's to open, or not.
    if (!/^(https?|javascript|blob|data|about):/i.test(a.href)) {
      e.preventDefault();
      send({type: 'outside', url: a.href});
      return;
    }
    if (!/^https?:/i.test(a.href)) return;
    var modified = (e.ctrlKey || e.metaKey) && e.button === 0;
    if (e.button === 1 || modified || (e.button === 0 && opensWindow((a.getAttribute('target') || '').toLowerCase()))) {
      e.preventDefault();
      send({type: 'newTab', url: a.href});
    }
  }
  window.addEventListener('click', onClick);
  window.addEventListener('auxclick', onClick);

  function base64(bytes) {
    var s = '';
    for (var i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
    return btoa(s);
  }
  function snapshot() {
    // Built in a document with no window: nothing in the copy loads, and no handler runs.
    var inert = document.implementation.createHTMLDocument('');
    var root = inert.importNode(document.documentElement, true);
    function inner(frame) {
      try { var d = frame.contentDocument; return d && d.body ? d.body.innerHTML : ''; } catch (e) { return ''; }
    }
    var live = document.querySelectorAll('iframe'), copies = root.querySelectorAll('iframe');
    for (var i = 0; i < live.length && i < copies.length; i++) {
      var box = inert.createElement('div');
      box.innerHTML = inner(live[i]);
      copies[i].parentNode.replaceChild(box, copies[i]);
    }
    var frames = document.querySelectorAll('frame');
    if (frames.length) {
      var body = inert.createElement('body');
      for (var j = 0; j < frames.length; j++) {
        var part = inert.createElement('div');
        part.innerHTML = inner(frames[j]);
        body.appendChild(part);
      }
      var old = root.querySelector('frameset') || root.querySelector('body');
      if (old) old.parentNode.replaceChild(body, old); else root.appendChild(body);
    }
    var drop = root.querySelectorAll('script,style,link,noscript,iframe,frame,frameset,object,embed,template,' +
      'canvas,video,audio,source,track,base,meta,svg');
    for (var d = 0; d < drop.length; d++) if (drop[d].parentNode) drop[d].parentNode.removeChild(drop[d]);
    var all = root.querySelectorAll('*');
    for (var n = 0; n < all.length; n++) {
      var el = all[n];
      for (var a = el.attributes.length - 1; a >= 0; a--) {
        var name = el.attributes[a].name.toLowerCase(), value = el.attributes[a].value;
        if (name.indexOf('on') === 0 || name === 'style' || name === 'srcset' || /^\\s*javascript:/i.test(value)) {
          el.removeAttribute(el.attributes[a].name);
        } else if (name === 'href' || name === 'src') {
          try { el.setAttribute(name, new URL(value, document.baseURI).href); } catch (e) {}
        }
      }
    }
    var b = root.querySelector('body');
    return b ? b.innerHTML : root.innerHTML;
  }
  function capture(id) {
    function done(m) { m.type = 'capture'; m.id = id; m.title = document.title; send(m); }
    try {
      if ((document.contentType || '') === 'application/pdf') {
        fetch(location.href, {credentials: 'include'})
          .then(function (r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.arrayBuffer(); })
          .then(function (data) { done({kind: 'pdf', data: base64(new Uint8Array(data))}); })
          .catch(function (e) { done({error: String(e)}); });
      } else {
        done({kind: 'html', data: snapshot()});
      }
    } catch (e) {
      done({error: String(e)});
    }
    return true;
  }
  function icon() {
    var link = document.querySelector('link[rel~="icon" i]');
    send({type: 'meta', icon: link && link.href ? link.href : location.origin + '/favicon.ico'});
  }

  window.__daylex = {send: send, capture: capture};
  if (top) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', icon); else icon();
  }
})();
''';

/// What a page script sent, read back: null for anything it would not send.
PageMessage? readPageMessage(Object? message) {
  final m = message is String ? _decode(message) : message;
  if (m is! Map) return null;
  return switch (m['type']) {
    'key' => switch (KeyCombo.fromJson(m)) {
      final combo? => KeyMessage(combo),
      null => null,
    },
    'newTab' when m['url'] is String => switch (Uri.tryParse(m['url'] as String)) {
      final uri? => NewTabMessage(uri),
      null => null,
    },
    'outside' when m['url'] is String => switch (Uri.tryParse(m['url'] as String)) {
      final uri? => OutsideLinkMessage(uri),
      null => null,
    },
    'meta' when m['icon'] is String => IconMessage(m['icon'] as String),
    'zoom' when m['step'] is num => ZoomMessage((m['step'] as num) < 0 ? -1 : 1),
    'capture' when m['id'] is String => CaptureMessage(
      id: m['id'] as String,
      kind: m['kind'] is String ? m['kind'] as String : null,
      data: m['data'] is String ? m['data'] as String : null,
      title: m['title'] is String ? m['title'] as String : '',
      error: m['error'] is String ? m['error'] as String : null,
    ),
    _ => null,
  };
}

Object? _decode(String text) {
  try {
    return jsonDecode(text);
  } on FormatException {
    return null;
  }
}

sealed class PageMessage {
  const PageMessage();
}

class KeyMessage extends PageMessage {
  const KeyMessage(this.combo);

  final KeyCombo combo;
}

class NewTabMessage extends PageMessage {
  const NewTabMessage(this.uri);

  final Uri uri;
}

class OutsideLinkMessage extends PageMessage {
  const OutsideLinkMessage(this.uri);

  final Uri uri;
}

class ZoomMessage extends PageMessage {
  const ZoomMessage(this.step);

  final int step;
}

class IconMessage extends PageMessage {
  const IconMessage(this.url);

  final String url;
}

class CaptureMessage extends PageMessage {
  const CaptureMessage({required this.id, required this.kind, required this.data, required this.title, this.error});

  final String id;
  final String? kind;
  final String? data;
  final String title;
  final String? error;
}
