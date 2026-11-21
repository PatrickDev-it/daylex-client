import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'server_roots.dart';

export 'dart:io';

/// A client for Daylex's own server: it trusts the roots the server's certificate chains to besides the system's
/// (rfc/053). Dart sees only the roots already in the system's store, and Windows fetches one there only when something
/// else asks for it: a fresh Windows has none, and the app would not reach the server at all.
HttpClient serverHttpClient() => HttpClient(context: _serverTrust);

final _serverTrust = trusting(serverRoots);

/// The system's roots and [roots] (PEM) besides: a computer whose antivirus or proxy inspects TLS keeps working.
@visibleForTesting
SecurityContext trusting(Iterable<String> roots) {
  final context = SecurityContext(withTrustedRoots: true);
  for (final pem in roots) {
    context.setTrustedCertificatesBytes(ascii.encode(pem));
  }
  return context;
}
