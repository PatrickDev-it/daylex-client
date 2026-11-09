import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/agent_protocol.dart';
import 'domain/document_tools.dart';

final whatsappProvider = Provider<WhatsappBridge>((ref) {
  final bridge = WhatsappBridge();
  ref.onDispose(bridge.dispose);
  return bridge;
});

/// Owns the local WhatsApp Web process. Its JSON-line protocol never opens a network port.
class WhatsappBridge extends ChangeNotifier {
  Process? _process;
  Future<void>? _starting;
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  Completer<void>? _connected;
  int _nextId = 0;
  bool _disposed = false;

  String state = 'off';
  String? qr;
  String? error;
  bool showPairing = false;

  bool get ready => state == 'ready';

  Future<void> start() async {
    final current = _starting;
    if (current != null) return current;
    final starting = _start();
    _starting = starting;
    try {
      await starting;
    } catch (_) {
      _starting = null;
      rethrow;
    }
  }

  Future<void> _start() async {
    final root = File(Platform.resolvedExecutable).parent;
    final macBridge = Directory(
      '${root.parent.path}${Platform.pathSeparator}Resources${Platform.pathSeparator}whatsapp_bridge',
    );
    final packagedOnMac = Platform.isMacOS && macBridge.existsSync();
    var bridgeDir = packagedOnMac
        ? macBridge
        : Directory('whatsapp_bridge').absolute;
    if (!packagedOnMac) {
      for (
        var folder = root, depth = 0;
        depth < 7;
        folder = folder.parent, depth++
      ) {
        final candidate = Directory(
          '${folder.path}${Platform.pathSeparator}whatsapp_bridge',
        );
        if (candidate.existsSync()) {
          bridgeDir = candidate;
          break;
        }
        if (folder.parent.path == folder.path) break;
      }
    }
    final script = File('${bridgeDir.path}${Platform.pathSeparator}bridge.js');
    if (!script.existsSync()) {
      _setState('error', message: 'Collegamento WhatsApp non installato.');
      throw StateError(error!);
    }
    final bundledNode = packagedOnMac
        ? File(
            '${root.parent.path}${Platform.pathSeparator}Helpers${Platform.pathSeparator}daylex-whatsapp-node',
          )
        : File(
            '${bridgeDir.path}${Platform.pathSeparator}${Platform.isWindows ? 'node.exe' : 'node'}',
          );
    if (packagedOnMac && !bundledNode.existsSync()) {
      _setState('error', message: 'Componente WhatsApp non incluso nell’app.');
      throw StateError(error!);
    }
    final node = bundledNode.existsSync() ? bundledNode.path : 'node';
    try {
      _process = await Process.start(node, [
        script.path,
      ], workingDirectory: bridgeDir.path);
    } on ProcessException catch (e) {
      debugPrint('WhatsApp process: $e');
      _setState('error', message: 'Il componente per WhatsApp non può essere avviato.');
      throw StateError(error!);
    }
    _setState('starting');
    _process!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_readLine);
    _process!.stderr
        .transform(utf8.decoder)
        .listen((line) => debugPrint('WhatsApp bridge: $line'));
    unawaited(
      _process!.exitCode.then((code) {
        _process = null;
        _starting = null;
        if (_disposed) return;
        _setState(
          'error',
          message: 'Collegamento WhatsApp terminato (codice $code).',
        );
        _failPending(error!);
      }),
    );
  }

  void _readLine(String line) {
    try {
      final value = (jsonDecode(line) as Map).cast<String, dynamic>();
      if (value['event'] == 'status') {
        qr = value['qr'] as String?;
        _setState(
          value['state'] as String? ?? 'error',
          message: value['error'] == null ? null : 'Collegamento WhatsApp non riuscito. Riprova.',
        );
        if (state == 'error' ||
            state == 'auth_failure' ||
            state == 'disconnected') {
          _failPending(error ?? 'Collegamento WhatsApp non riuscito.');
        }
        if (ready) {
          showPairing = false;
          if (!(_connected?.isCompleted ?? true)) _connected!.complete();
          notifyListeners();
        }
        return;
      }
      final id = value['id'];
      if (id is int) _pending.remove(id)?.complete(value);
    } catch (e) {
      debugPrint('WhatsApp bridge protocol error: $e');
    }
  }

  void _setState(String next, {String? message}) {
    state = next;
    error = message;
    if (!_disposed) notifyListeners();
  }

  void _failPending(String reason) {
    for (final pending in _pending.values) {
      if (!pending.isCompleted) pending.completeError(StateError(reason));
    }
    _pending.clear();
    if (!(_connected?.isCompleted ?? true)) {
      _connected!.completeError(StateError(reason));
    }
  }

  Future<void> connect({bool displayPairing = false}) async {
    if (displayPairing && !ready) {
      showPairing = true;
      notifyListeners();
    }
    try {
      await start();
      if (ready) return;
      if (state == 'error' ||
          state == 'auth_failure' ||
          state == 'disconnected') {
        throw StateError(error ?? 'Collegamento WhatsApp non riuscito.');
      }
      if (_connected?.isCompleted ?? true) _connected = Completer<void>();
      await _connected!.future.timeout(const Duration(minutes: 3));
    } finally {
      if (!ready) {
        showPairing = false;
        _connected = null;
        notifyListeners();
      }
    }
  }

  void dismissPairing() {
    showPairing = false;
    if (!(_connected?.isCompleted ?? true)) {
      _connected!.completeError(StateError('Collegamento WhatsApp annullato.'));
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> _request(
    String method,
    Map<String, dynamic> args,
  ) async {
    final process = _process;
    if (process == null) {
      throw StateError(error ?? 'Collegamento WhatsApp non disponibile.');
    }
    final id = ++_nextId;
    final response = Completer<Map<String, dynamic>>();
    _pending[id] = response;
    process.stdin.writeln(
      jsonEncode({'id': id, 'method': method, 'args': args}),
    );
    late final Map<String, dynamic> value;
    try {
      value = await response.future.timeout(const Duration(seconds: 45));
    } finally {
      _pending.remove(id);
    }
    if (value['ok'] != true) {
      throw StateError('${value['error'] ?? 'Errore WhatsApp'}');
    }
    return (value['result'] as Map).cast<String, dynamic>();
  }

  Future<ToolResult> execute(AgentToolCall call) async {
    try {
      if (call.name == 'whatsapp_status') {
        await start();
        if (!ready && state != 'error' && state != 'auth_failure') {
          showPairing = true;
          notifyListeners();
        }
        return ToolResult.ok(
          ready
              ? 'WhatsApp collegato.'
              : 'WhatsApp non collegato. QR disponibile nell’app.',
          data: {'state': state, 'connected': ready},
        );
      }
      await connect(displayPairing: true);
      if (call.name == 'whatsapp_find_contact') {
        final result = await _request('find_contact', call.arguments);
        final contacts = result['contacts'] as List;
        return ToolResult.ok(
          '${contacts.length} contatti trovati.',
          data: result,
        );
      }
      if (call.name == 'whatsapp_send_message') {
        final result = await _request('send_message', call.arguments);
        return ToolResult.ok(
          'Messaggio inviato a ${result['recipient']}.',
          data: result,
        );
      }
      return ToolResult.error('Strumento WhatsApp sconosciuto: ${call.name}.');
    } catch (e) {
      return ToolResult.error(e is StateError ? e.message : '$e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    final process = _process;
    if (process != null) {
      unawaited(process.stdin.close());
      unawaited(Future<void>.delayed(const Duration(seconds: 3), process.kill));
    }
    _failPending('Collegamento WhatsApp chiuso.');
    super.dispose();
  }
}
