// Native requests retain dart:io semantics; web uses Fetch with streaming and cancellation.
export 'dart:io' if (dart.library.js_interop) 'http_transport_web.dart';
