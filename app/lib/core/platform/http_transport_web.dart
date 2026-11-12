import 'dart:async';
import 'dart:convert';
import 'dart:io' show ContentType, HttpException;

import 'package:http/http.dart' as http;

export 'dart:io'
    hide HttpClient, HttpClientRequest, HttpClientResponse, HttpHeaders;

/// Small adapter for the request operations used by the shared agent protocol.
class HttpClient {
  HttpClient({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  final _pending = <Completer<void>>{};
  Duration? connectionTimeout;
  /// Unused: the browser pools Fetch connections itself. Kept so call sites stay shared with dart:io.
  Duration idleTimeout = const Duration(seconds: 15);
  bool _closed = false;
  Future<HttpClientRequest> openUrl(String method, Uri uri) async {
    if (_closed) throw const HttpException('Client closed');
    return HttpClientRequest(this, method, uri);
  }

  Future<HttpClientRequest> getUrl(Uri uri) => openUrl('GET', uri);
  Future<HttpClientRequest> postUrl(Uri uri) => openUrl('POST', uri);
  Future<HttpClientRequest> deleteUrl(Uri uri) => openUrl('DELETE', uri);
  void close({bool force = false}) {
    _closed = true;
    for (final pending in _pending) {
      if (!pending.isCompleted) pending.complete();
    }
    _pending.clear();
    _client.close();
  }
}

class HttpHeaders {
  static const authorizationHeader = 'authorization';
  final _values = <String, String>{};
  void set(String name, Object value) => _values[name] = '$value';
  set contentType(ContentType value) => set('content-type', value.toString());
}

class HttpClientRequest {
  HttpClientRequest(this._owner, this._method, this._uri);
  final HttpClient _owner;
  final String _method;
  final Uri _uri;
  final headers = HttpHeaders();
  final _bytes = <int>[];
  final _abort = Completer<void>();
  bool followRedirects = true;
  void add(List<int> bytes) => _bytes.addAll(bytes);
  void write(Object value) => add(utf8.encode('$value'));
  void abort([Object? error, StackTrace? stackTrace]) {
    if (!_abort.isCompleted) _abort.complete();
  }

  Future<HttpClientResponse> close() async {
    final request =
        http.AbortableRequest(_method, _uri, abortTrigger: _abort.future)
          ..followRedirects = followRedirects
          ..headers.addAll(headers._values)
          ..bodyBytes = _bytes;
    _owner._pending.add(_abort);
    try {
      final response = await _owner._client.send(request);
      return HttpClientResponse(response, () => _owner._pending.remove(_abort));
    } on http.ClientException {
      _owner._pending.remove(_abort);
      throw const HttpException('Network request failed');
    }
  }
}

class HttpClientResponse extends Stream<List<int>> {
  HttpClientResponse(this._response, this._finished);
  final http.StreamedResponse _response;
  final void Function() _finished;
  int get statusCode => _response.statusCode;
  Stream<List<int>> _body() async* {
    try {
      yield* _response.stream;
    } finally {
      _finished();
    }
  }

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _body().listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}
