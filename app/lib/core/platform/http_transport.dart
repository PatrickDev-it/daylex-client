// Native requests retain dart:io semantics; web uses Fetch with streaming and cancellation.
export 'http_transport_io.dart' if (dart.library.js_interop) 'http_transport_web.dart';
