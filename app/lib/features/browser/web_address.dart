/// What a browser tab accepts as an address, once for the address bar, the portals and the links a page opens.
library;

/// Where a tab goes for what the lawyer typed: [typedAddress], anything else a Google search. Null for blank input.
Uri? addressFor(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;
  return typedAddress(text) ?? Uri.https('www.google.com', '/search', {'q': text});
}

/// The address in what the lawyer typed: as written, or a bare host ("normattiva.it", "intranet:8080/x") over
/// https. Null when it is not an address.
Uri? typedAddress(String input) {
  final text = input.trim();
  if (text.isEmpty || text.contains(RegExp(r'\s'))) return null;
  final typed = Uri.tryParse(text);
  final scheme = typed?.scheme.toLowerCase() ?? '';
  // "normattiva.it:443/x" parses with "normattiva.it" as its scheme: a host, not a scheme.
  if (typed != null && _schemes.contains(scheme)) return typed;
  if (!_hostLike.hasMatch(text)) return null;
  final uri = Uri.tryParse('https://$text');
  return uri != null && uri.host.isNotEmpty ? uri : null;
}

/// What a tab does with an address.
enum Navigation {
  /// A web page: the tab opens it.
  web,

  /// Mail and phone numbers: the system's own app opens them.
  system,

  /// Files, scripts, data and every other kind: never opened.
  refused,
}

Navigation navigationFor(Uri uri) => switch (uri.scheme.toLowerCase()) {
  'http' || 'https' when uri.host.isNotEmpty => Navigation.web,
  'mailto' || 'tel' => Navigation.system,
  _ => Navigation.refused,
};

/// Whether the connection to [uri] is encrypted.
bool isSecure(Uri uri) => uri.scheme.toLowerCase() == 'https';

/// The host as the address bar shows it first: "gazzettaufficiale.it", without "www.", with a port only when it
/// is not the scheme's own.
String displayHost(Uri uri) =>
    '${uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '')}${uri.hasPort ? ':${uri.port}' : ''}';

/// The same address on its site's "www." host, for a bare domain that did not answer: "gazzettaufficiale.it" has
/// no server of its own, "www.gazzettaufficiale.it" has. Null for any other host (a subdomain such as
/// "pst.giustizia.it", an IP address, "localhost"): its "www." would be a guess.
Uri? wwwAlternative(Uri uri) {
  final labels = uri.host.split('.');
  if (labels.length != 2 || labels.any((l) => l.isEmpty)) return null;
  return uri.replace(host: 'www.${uri.host}');
}

/// The rest of the address after the host, as the address bar shows it dimmed: "/atto/serie_generale?x=1".
String displayRest(Uri uri) {
  final rest = '${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}${uri.hasFragment ? '#${uri.fragment}' : ''}';
  return rest == '/' ? '' : rest;
}

/// Schemes [addressFor] takes as written; anything else before a colon is a host with its port.
const _schemes = {'http', 'https', 'mailto', 'tel', 'file', 'data', 'javascript', 'about', 'blob', 'ftp', 'ws', 'wss'};

/// A host (with dots, or "localhost", or an IPv4 address), an optional port, then a path, query or fragment.
final _hostLike = RegExp(
  r'^(localhost|\d{1,3}(\.\d{1,3}){3}|[^\s/?#:.]+(\.[^\s/?#:.]+)*\.[^\s/?#:.\d]{2,})(:\d{1,5})?([/?#].*)?$',
  caseSensitive: false,
);

/// A file name for a page the lawyer keeps: its title (or host), then when it was taken, without the characters
/// no file system accepts. "Normattiva - Art. 2043 2026-11-21 14.05.html". A title that is already a file name
/// of that kind (a PDF's) leaves its extension to the end.
String pageFileName(String title, Uri url, DateTime at, String extension) {
  String two(int n) => n.toString().padLeft(2, '0');
  final clean = title
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceFirst(RegExp('\\.${RegExp.escape(extension)}\$', caseSensitive: false), '');
  final name = clean.isEmpty ? displayHost(url) : clean;
  final short = name.length > 80 ? name.substring(0, 80).trimRight() : name;
  return '$short ${at.year}-${two(at.month)}-${two(at.day)} ${two(at.hour)}.${two(at.minute)}.$extension';
}
