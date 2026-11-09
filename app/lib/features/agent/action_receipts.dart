import 'dart:async';
import 'dart:convert';

import 'domain/agent_protocol.dart';
import 'domain/document_tools.dart';

/// Receipts live for one turn, including in-flight actions and rejected actions.
class ActionReceipts {
  final _entries = <String, (String, Future<ToolResult?>)>{};

  Future<ToolResult?> once(
    AgentToolCall call,
    Future<ToolResult?> Function() action,
  ) {
    final signature = jsonEncode([call.name, call.arguments]);
    final prior = _entries[call.id];
    if (prior != null) {
      return prior.$1 == signature
          ? prior.$2
          : Future.value(
              const ToolResult.error(
                'Identificativo di azione riutilizzato con contenuto diverso: azione non eseguita.',
              ),
            );
    }
    final receipt = Completer<ToolResult?>();
    _entries[call.id] = (signature, receipt.future);
    Future<ToolResult?>.sync(action).then(
      receipt.complete,
      onError: (Object error, StackTrace stack) {
        receipt.complete(
          const ToolResult.error(
            'Azione interrotta: verifica il documento prima di riprovare.',
          ),
        );
      },
    );
    return receipt.future;
  }
}
