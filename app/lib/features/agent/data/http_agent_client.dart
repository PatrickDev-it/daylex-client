import 'dart:async';
import 'dart:convert';
import '../../../core/platform/http_transport.dart';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../../core/platform/user_dirs.dart';
import '../../../l10n/app_localizations.dart';
import '../../access/desktop_credentials.dart';
import '../../document/model/document.dart';
import '../../document/model/document_review.dart';
import '../domain/agent_protocol.dart';
import 'server_endpoint.g.dart';

/// Where the agent server lives and how to authenticate to it.
///
/// The server is [publicServerUrl], built in from the server's deploy
/// configuration. The access key is the one the lawyer entered in the settings,
/// kept in the OS credential vault. On a developer's
/// machine `PAPERAGENT_URL` / `PAPERAGENT_TOKEN`, or a `"url"` in the legacy config,
/// name another server (a tunnel, the host's own token).
class AgentServerConfig {
  const AgentServerConfig({required this.url, required this.token});

  final Uri url;
  final String token;

  /// Optional endpoint override. Credentials belong only to DesktopCredentials.
  static File? get file {
    if (kIsWeb) return null;
    final home = userHome(Platform.environment);
    return home == null ? null : File('$home/.paperagent/server.json');
  }

  /// The configured server. Throws [AgentConfigException] with what is wrong,
  /// in words the lawyer can pass on, when there is none or it cannot be used:
  /// a lawyer must never get the offline mock's answers believing they are the
  /// agent's.
  static AgentServerConfig load(AppLocalizations l) {
    final (url, token, source) = _read(l);
    if (token == null || token.isEmpty) {
      throw AgentConfigException(l.serverKeyMissing);
    }
    return AgentServerConfig(
      url: validateAddress(url, source, l),
      token: token,
    );
  }

  /// The server the app talks to, whether or not a key was entered.
  static Uri server(AppLocalizations l) {
    final (url, _, source) = _read(l);
    return validateAddress(url, source, l);
  }

  static (String?, String?, String) _read(AppLocalizations l) {
    final env = kIsWeb ? const <String, String>{} : Platform.environment;
    var url = kIsWeb ? Uri.base.origin : kReleaseMode ? null : env['PAPERAGENT_URL'];
    var token = kReleaseMode ? null : env['PAPERAGENT_TOKEN'];
    var source = 'PAPERAGENT_URL / PAPERAGENT_TOKEN';
    final file = AgentServerConfig.file;
    if (url == null && token == null && file != null && file.existsSync()) {
      source = file.path;
      try {
        final json = jsonDecode(file.readAsStringSync());
        url = json is Map ? json['url'] as String? : null;
      } on Object {
        throw AgentConfigException(l.serverConfigUnreadable(source));
      }
    }
    return (url, token ?? DesktopCredentials.instance.key, source);
  }

  static Uri validateAddress(String? url, String source, AppLocalizations l) {
    final address = url == null || url.isEmpty ? publicServerUrl : url;
    if (address == null) {
      throw AgentConfigException(l.serverAddressMissing(source));
    }
    final uri = Uri.tryParse(address);
    if (uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https')) ||
        uri.host.isEmpty) {
      throw AgentConfigException(l.serverAddressInvalid(source, address));
    }
    final loopback =
        uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '::1';
    if (uri.isScheme('http') && !loopback) {
      throw AgentConfigException(l.serverAddressInvalid(source, address));
    }
    return uri;
  }

  /// Asks the server whether it takes [key]: [KeyCheck.unverified], with why,
  /// when it cannot say (unreachable, or off for now).
  static Future<(KeyCheck, String?)> check(
    String key,
    AppLocalizations l,
  ) async {
    final Uri url;
    try {
      url = server(l);
    } on AgentConfigException catch (e) {
      return (KeyCheck.unverified, e.message);
    }
    final http = _newHttpClient();
    try {
      final request = _authorize(
        await http.getUrl(url.resolve('/v1/tools')),
        key,
      );
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 20))) {
        bytes.addAll(chunk);
        if (bytes.length > 1024 * 1024) throw const FormatException('key check response');
      }
      final body = utf8.decode(bytes);
      return switch (response.statusCode) {
        HttpStatus.ok => (KeyCheck.accepted, null),
        HttpStatus.unauthorized ||
        HttpStatus.forbidden ||
        426 => (KeyCheck.rejected, _serverDetail(l, body, response.statusCode)),
        final status => (KeyCheck.unverified, _serverDetail(l, body, status)),
      };
    } on Object catch (e) {
      return (KeyCheck.unverified, connectionProblem(l, e, url));
    } finally {
      http.close(force: true);
    }
  }

  /// Keeps [key] as the app's access key, and a server address the file
  /// already names.
  static Future<void> saveKey(String key, AppLocalizations l) =>
      DesktopCredentials.instance.save(key, accepted: true, disclosure: true);

  /// Discards a saved server override while retaining the lawyer's access key.
  /// Environment overrides are managed by the operator, not by this setting.
  static void resetAddress(AppLocalizations l, {File? configFile}) {
    if (kIsWeb) return;
    if (Platform.environment['PAPERAGENT_URL'] case final String override
        when override.isNotEmpty) {
      throw AgentConfigException(l.serverAddressEnvironmentOverride);
    }
    final file = configFile ?? AgentServerConfig.file;
    if (file == null || !file.existsSync()) return;
    try {
      final saved = jsonDecode(file.readAsStringSync());
      if (saved is! Map<String, dynamic>) {
        throw const FormatException('server.json');
      }
      if (!saved.containsKey('url')) return;
      saved.remove('url');
      file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(saved));
    } on Object {
      throw AgentConfigException(l.serverConfigUnreadable(file.path));
    }
  }
}

HttpClient _newHttpClient() =>
    HttpClient()..connectionTimeout = const Duration(seconds: 10);

/// The token, and the protocol version: a server that speaks another one
/// refuses the request instead of misreading it.
HttpClientRequest _authorize(HttpClientRequest request, String token) {
  DesktopCredentials.instance.authorize(request);
  request.headers
    ..set(HttpHeaders.authorizationHeader, 'Bearer $token')
    ..set(protocolHeader, '$protocolVersion');
  return request;
}

/// What the server said of an access key before the app keeps it: a rejected
/// key is not activated; an unavailable service must be retried before activation.
enum KeyCheck { accepted, rejected, unverified }

/// Why the server could not be reached, in words for the lawyer. No address in
/// it: a socket error names the server's IP.
String connectionProblem(AppLocalizations l, Object e, Uri server) {
  if (e is SocketException) {
    final refused =
        e.osError?.errorCode == 10061 || e.osError?.errorCode == 111;
    final local = server.host == 'localhost' || server.host == '127.0.0.1';
    return refused && local ? l.connectionLocalOff : l.connectionUnreachable;
  }
  if (e is TlsException) return l.connectionTls;
  if (e is TimeoutException) return l.connectionTimeout;
  if (e is HttpException) return l.failureUnreachable;
  // Not a network problem: say so, so a bug is not mistaken for an outage.
  return l.failureUnexpected;
}

class AgentConfigException implements Exception {
  const AgentConfigException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// What runs when no server can be used: every request ends at once with
/// [problem], and the app says it is not connected.
class UnavailableAgentClient implements AgentClient {
  const UnavailableAgentClient(this.problem);

  @override
  final String problem;

  @override
  String get displayName => 'Non collegato';

  @override
  bool get isMock => false;

  @override
  Stream<AgentEvent> run(AgentRequest request) =>
      Stream.value(AgentFailure(problem));

  @override
  Future<void> submitToolResult(
    String sessionId,
    String callId,
    Map<String, dynamic> result,
  ) async {}

  /// Nothing to upload to: the attachment stays on the chat, sent with the
  /// run once a server is configured.
  @override
  Future<AttachmentCard?> uploadAttachment(
    String sessionId,
    AgentAttachment attachment,
  ) async => null;

  @override
  Future<void> deleteAttachment(String sessionId, String name) async {}

  @override
  Future<void> deleteCaseFile(String sessionId) async {}

  @override
  Future<SourceDocument?> readSource(
    String sessionId,
    String name,
    int page, {
    bool includeOriginal = true,
  }) async => throw HttpException(problem);
}

/// A failure of a request to the server, in words for the lawyer: the server's
/// own message (as it wrote it) without the exception's type before it.
String describeFailure(AppLocalizations l, Object e) => switch (e) {
  HttpException(:final message) => message,
  SocketException() => l.failureUnreachable,
  TlsException() => l.failureTls,
  TimeoutException() => l.failureTimeout,
  _ => l.failureUnexpected,
};

/// The longest a run's stream may stay silent. The server pings every 15 s
/// while a run waits (for a model slot, a check, a tool result) and streams
/// while the model writes; only reading a long request is quiet, for a minute
/// at worst under load. Silence this long is a connection that died without
/// closing, and the lawyer would otherwise wait forever.
const streamIdleLimit = Duration(minutes: 3);

/// [AgentClient] for the self-hosted agent server (`paper_agent_server`).
///
/// A run is one `POST /v1/agent/runs` whose response is NDJSON, one event per
/// line, kept open while the app executes tool calls. Cancelling the stream
/// drops the connection, which the server takes as "stop" and frees its slot.
class HttpAgentClient implements AgentClient, DocumentReviewer {
  /// [l10n] is read at each use, so a language change reaches the next message.
  HttpAgentClient(this.config, {required this.l10n}) : _http = _newHttpClient();

  final AgentServerConfig config;
  final AppLocalizations Function() l10n;
  final HttpClient _http;

  // The lawyer sees the product, never which model or which server runs it.
  @override
  String get displayName => 'PaperAgent';

  @override
  bool get isMock => false;

  @override
  String? get problem => null;

  @override
  Future<DocumentReview> reviewDocument(
    PaperDocument document, {
    Uint8List? pdf,
  }) async {
    final previous = _reviewTail;
    final released = Completer<void>();
    _reviewTail = released.future;
    await previous;
    _runs++;
    try {
      final request = await _post(documentReviewPath, {
        'document': document.toJson(),
        if (pdf != null) 'pdf': base64Encode(pdf),
      });
      final answer = await _answer(request)
          .timeout(const Duration(seconds: 190));
      return DocumentReview.fromJson(
        jsonDecode(answer) as Map<String, dynamic>,
      );
    } finally {
      released.complete();
      _runOver();
    }
  }

  Future<void> _reviewTail = Future<void>.value();

  /// Runs listened to and not over yet.
  var _runs = 0;
  var _closing = false;

  /// Lets the connections go once the runs already going are over: a run in progress when the settings
  /// replace this client (a new access key) keeps its stream and sends its tool results to its end.
  /// Requests already sent finish too; a new one fails.
  void close() {
    _closing = true;
    if (_runs == 0) _http.close();
  }

  void _runOver() {
    if (--_runs == 0 && _closing) _http.close();
  }

  Uri _endpoint(String path) => config.url.resolve(path);

  Future<HttpClientRequest> _post(
    String path,
    Object body, {
    bool sourceLinks = false,
  }) async {
    final request = await _http.postUrl(_endpoint(path));
    _authorize(request, config.token).headers.contentType = ContentType.json;
    if (sourceLinks) request.headers.set('X-Source-Links-Version', '1');
    request.add(utf8.encode(jsonEncode(body)));
    return request;
  }

  /// Sends [request] and returns the body of the answer. Throws the server's own words when its status is not
  /// [HttpStatus.ok] or one of [also].
  Future<String> _answer(
    HttpClientRequest request, {
    Set<int> also = const {},
  }) async {
    final response = await request.close();
    final body = await utf8.decodeStream(response);
    if (response.statusCode != HttpStatus.ok &&
        !also.contains(response.statusCode)) {
      throw HttpException(_serverDetail(l10n(), body, response.statusCode));
    }
    return body;
  }

  static String _sessionPath(String sessionId, [String rest = '']) =>
      '/v1/sessions/${Uri.encodeComponent(sessionId)}$rest';

  @override
  Stream<AgentEvent> run(AgentRequest request) {
    HttpClientRequest? pending;
    StreamSubscription<String>? lines;
    late final StreamController<AgentEvent> events;
    // Every run the server finishes ends with `done` or `error`; a stream closing before either was cut short.
    var ended = false;

    Future<void> fail(String message) async {
      if (events.isClosed) return;
      events.add(AgentFailure(message));
      await events.close();
    }

    events = StreamController<AgentEvent>(
      onListen: () async {
        _runs++;
        // Done when the run ends, as the server ended it or cut, or when it is cancelled.
        unawaited(events.done.whenComplete(_runOver));
        try {
          final http = pending = await _post(
            '/v1/agent/runs',
            request.toJson(),
            sourceLinks: true,
          );
          final response = await http.close();
          if (response.statusCode != HttpStatus.ok) {
            return await fail(
              _serverDetail(
                l10n(),
                await utf8.decodeStream(response),
                response.statusCode,
              ),
            );
          }
          lines = response
              .timeout(streamIdleLimit)
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .listen(
                (line) {
                  final AgentEvent? event;
                  try {
                    event = _parse(line);
                  } on Object catch (e) {
                    unawaited(lines?.cancel());
                    unawaited(fail(l10n().streamBroken('$e')));
                    return;
                  }
                  if (event == null || events.isClosed) return;
                  ended = event is AgentDone || event is AgentFailure;
                  events.add(event);
                },
                onError: (Object e) => fail(
                  e is TimeoutException
                      ? l10n().streamSilent
                      : l10n().streamBroken('$e'),
                ),
                onDone: () => ended ? events.close() : fail(l10n().streamEnded),
                cancelOnError: true,
              );
        } on Object catch (e) {
          await fail(connectionProblem(l10n(), e, config.url));
        }
      },
      onCancel: () async {
        pending?.abort();
        await lines?.cancel();
      },
    );
    return events.stream;
  }

  @override
  Future<void> submitToolResult(
    String sessionId,
    String callId,
    Map<String, dynamic> result,
  ) async {
    final request = await _post(
      '/v1/agent/runs/${Uri.encodeComponent(sessionId)}/tool-results',
      {'callId': callId, 'result': result},
    );
    await _answer(request);
  }

  @override
  Future<AttachmentCard?> uploadAttachment(
    String sessionId,
    AgentAttachment attachment,
  ) async {
    if (attachment.localPath != null &&
        await File(attachment.localPath!).length() > maxFileBytes) {
      throw const FileSystemException('Il file supera il limite consentito.');
    }
    final bytes = attachment.localPath == null
        ? attachment.bytes
        : await File(attachment.localPath!).readAsBytes();
    if (bytes.length > maxFileBytes) {
      throw const FileSystemException('Il file supera il limite consentito.');
    }
    final request = await _post(_sessionPath(sessionId, '/attachments'), {
      'name': attachment.name,
      'mimeType': attachment.mimeType,
      'data': base64Encode(bytes),
    });
    final body = await _answer(request);
    return AttachmentCard.fromJson(jsonDecode(body) as Map<String, dynamic>);
  }

  @override
  Future<void> deleteAttachment(String sessionId, String name) => _delete(
    _sessionPath(sessionId, '/attachments/${Uri.encodeComponent(name)}'),
  );

  @override
  Future<void> deleteCaseFile(String sessionId) =>
      _delete(_sessionPath(sessionId, '/attachments'));

  @override
  Future<SourceDocument?> readSource(
    String sessionId,
    String name,
    int page, {
    bool includeOriginal = true,
  }) async {
    final uri = _endpoint(_sessionPath(sessionId, '/source'))
        .replace(queryParameters: {'name': name, 'page': '$page'});
    final request = _authorize(await _http.getUrl(uri), config.token);
    final response = await request.close().timeout(const Duration(seconds: 30));
    final body = await utf8
        .decodeStream(response)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == HttpStatus.notFound) return null;
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(_serverDetail(l10n(), body, response.statusCode));
    }
    final data = jsonDecode(body) as Map<String, dynamic>;
    Uint8List? pdf;
    if (includeOriginal && data['hasOriginal'] == true) {
      try {
        final fileUri = _endpoint(_sessionPath(sessionId, '/source/file'))
            .replace(queryParameters: {'name': name});
        final fileRequest = _authorize(
          await _http.getUrl(fileUri),
          config.token,
        );
        final file = await fileRequest.close().timeout(
          const Duration(seconds: 30),
        );
        final bytes = await file
            .fold(
              BytesBuilder(copy: false),
              (buffer, bytes) => buffer..add(bytes),
            )
            .timeout(const Duration(seconds: 30));
        if (file.statusCode == HttpStatus.ok) pdf = bytes.takeBytes();
      } on Exception {
        // Keep the page's actual extracted text usable when the original cannot be downloaded.
      }
    }
    return SourceDocument(
      name: data['name'] as String,
      page: (data['page'] as num).toInt(),
      pages: (data['pages'] as num).toInt(),
      text: data['text'] as String? ?? '',
      pdfBytes: pdf,
      unit: data['unit'] == 'section' ? 'section' : 'page',
    );
  }

  /// Throws when the server did not delete. A 404 counts as done: what had to
  /// go is not there (never read, or already expired).
  Future<void> _delete(String path) async {
    final request = _authorize(
      await _http.deleteUrl(_endpoint(path)),
      config.token,
    );
    await _answer(request, also: const {HttpStatus.notFound});
  }

  AgentEvent? _parse(String line) {
    if (line.trim().isEmpty) return null;
    final json = jsonDecode(line) as Map<String, dynamic>;
    Map<String, dynamic> map(Object? value) =>
        value is Map ? value.cast<String, dynamic>() : const {};
    return switch (json['type']) {
      'status' => AgentStatusEvent(
        json['label'] as String? ?? '',
        kind: json['kind'] as String? ?? '',
        detail: json['detail'] as String? ?? '',
        quiet: json['quiet'] as bool? ?? false,
      ),
      'text' => AgentTextDelta(json['text'] as String? ?? ''),
      'tool_call' => AgentToolCall(
        id: json['id'] as String,
        name: json['name'] as String,
        arguments: map(json['arguments']),
      ),
      'ui' => AgentUiEvent(json['component'] as String, map(json['props'])),
      'evidence' => AgentEvidenceEvent(map(json['audit'])),
      'done' => const AgentDone(),
      'error' => AgentFailure(
        json['message'] as String? ?? l10n().serverUnknownError,
      ),
      _ => null, // heartbeats and event types this app version does not know
    };
  }
}

/// The server's own words for a failed request (its `detail`), or a generic line when it gave none.
String _serverDetail(AppLocalizations l, String body, int status) {
  try {
    final detail = (jsonDecode(body) as Map<String, dynamic>)['detail'];
    if (detail is String) return detail;
    // A request the server will not take (422): which field, not a generic error.
    if (detail case [{'loc': List()}, ...]) {
      return l.serverRejectedRequest(l.requestData);
    }
  } on FormatException {
    // not JSON; fall through
  }
  return l.serverErrorStatus(status);
}
