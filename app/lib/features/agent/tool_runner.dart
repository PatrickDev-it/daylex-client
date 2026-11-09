import 'dart:convert';

import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart'
    hide AgentRequest;

import '../../l10n/l10n.dart';
import '../document/render/page_images.dart';
import 'approvals.dart';
import 'action_receipts.dart';
import 'chat_cards.dart';
import 'domain/agent_protocol.dart';
import 'domain/document_tools.dart';
import 'presentation/ui_components.dart';
import 'session_state.dart';
import 'turn_tracker.dart';
import 'whatsapp_bridge.dart';

/// What a tool call reaches of the chat it runs in.
abstract interface class ToolSurface {
  ChatMessagesController get chat;

  /// False once the user stopped the turn (or a new one began): from then on the run is gone on the server, so
  /// there is nothing to report to it and no phase to set back.
  bool get live;

  /// The strings of the app's language, for what the lawyer reads.
  AppLocalizations get l10n;

  void phase(AgentPhase phase, String activity);

  void log(String kind, String summary, [Object? payload]);

  /// Adds a rich component to the chat.
  void show(String kind, Map<String, dynamic> props);

  /// Shows [page] of [documentId] in the side panel.
  void reveal(String documentId, int page);

  /// Sends [result] back to the server, which waits for it.
  Future<void> report(AgentToolCall call, ToolResult result);
}

/// Runs the tool calls of one turn on its chat's document: the approval first when the tool asks for one, then
/// the call, its card, what it shows, and its result back to the server.
class ToolRunner {
  ToolRunner(
    this._surface,
    this._clock,
    this._host,
    this._turn,
    this._approvals,
    this._snapshots, {
    this._whatsapp,
  }) : _executor = DocumentToolExecutor(_host),
       _expectedDocument = jsonEncode(_host.activeDocument?.toJson());

  final ToolSurface _surface;
  final ChatClock _clock;
  final ToolHost _host;
  final RunningTurn _turn;
  final Approvals _approvals;
  final SnapshotStore _snapshots;
  final DocumentToolExecutor _executor;
  final WhatsappBridge? _whatsapp;
  final _receipts = ActionReceipts();
  String _expectedDocument;

  Future<void> run(AgentToolCall call) async {
    final result = await _receipts.once(call, () => _execute(call));
    if (result == null || !_surface.live) return;
    await _surface.report(call, result);
    if (_surface.live) {
      _surface.phase(AgentPhase.thinking, _surface.l10n.agentThinking);
    }
  }

  Future<ToolResult?> _execute(AgentToolCall call) async {
    final chat = _surface.chat;
    final l = _surface.l10n;
    final spec = toolSpec(call.name);
    final id = _clock.id('t');
    final stamp = _clock.stamp();
    final title = describeToolCall(l, call.name, call.arguments);
    _turn.tools++;
    ChatMessage card(String status, {String detail = '', int? ms}) =>
        ChatCards.toolCall(
          id,
          stamp,
          call,
          title,
          status,
          detail: detail,
          ms: ms,
        );

    chat.addMessage(card(CardStatus.running));
    _surface.log(LogKind.tool, title, call.arguments);

    if (spec?.requiresApproval ?? false) {
      final asked = _approvals.ask(call, title, _host.activeDocument, l);
      _surface.phase(AgentPhase.waiting, l.agentWaitingApproval);
      _surface.log(LogKind.approval, l.logWaitingApproval(title));
      final answer = await asked;
      if (answer != CardStatus.approved) {
        final expired = answer == CardStatus.expired;
        chat.updateMessage(
          card(
            CardStatus.rejected,
            detail: expired ? l.agentNoAnswer : l.agentNotApproved,
          ),
        );
        if (!_surface.live) return null;
        return ToolResult.error(
          expired
              ? "L'utente non ha risposto in tempo: l'azione non è stata eseguita. Non riproporla, chiedi se procedere."
              : "L'utente ha rifiutato questa azione.",
        );
      }
    }

    _surface.phase(
      AgentPhase.working,
      spec?.mutates == true ? l.agentDraftingDocument : l.agentCheckingResult,
    );
    // Let the running state paint before a potentially heavy operation.
    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (!_surface.live) {
      chat.updateMessage(card(CardStatus.rejected, detail: l.agentStopped));
      return null;
    }

    final before = _host.activeDocument;
    final watch = Stopwatch()..start();
    final stale =
        (spec?.mutates ?? false) &&
        jsonEncode(before?.toJson()) != _expectedDocument;
    final result = stale
        ? const ToolResult.error(
            'Il documento è cambiato dopo la richiesta. Nessuna modifica applicata: '
            'chiedi di avviare una nuova richiesta sul documento aggiornato.',
          )
        : call.name.startsWith('whatsapp_')
        ? await (_whatsapp?.execute(call) ??
              Future.value(const ToolResult.error('WhatsApp non disponibile.')))
        : await _executor.execute(call);
    final after = _host.activeDocument;
    if (result.ok && (spec?.mutates ?? false)) {
      _expectedDocument = jsonEncode(after?.toJson());
    }
    chat.updateMessage(
      card(
        result.ok ? CardStatus.done : CardStatus.error,
        detail: result.ok ? result.summary : l.operationFailureHint,
        ms: watch.elapsedMilliseconds,
      ),
    );
    _surface.log(
      result.ok ? LogKind.result : LogKind.error,
      result.ok ? result.summary : l.operationFailed,
      result.toJson(),
    );

    if (result.ok &&
        (spec?.mutates ?? false) &&
        before != null &&
        after != null &&
        before.id == after.id &&
        !identical(before, after)) {
      _turn.record(before, after);
    }

    for (final c in presentToolResult(
      call: call,
      result: result,
      before: before,
      after: after,
      snapshot: _snapshots.put,
    )) {
      _surface.show(c.kind, {
        ...c.props,
        if (c.kind == UiComponents.pdfDiff) ChatProps.workflowDetail: true,
      });
    }

    if (result.ok && result.focusPage != null && after != null) {
      _surface.reveal(after.id, result.focusPage!);
    }
    // The change above stays recorded for undo even when stopped mid-tool: it did happen.
    return result;
  }
}
