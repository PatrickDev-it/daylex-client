import 'dart:async';

import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart' hide AgentRequest;

import '../../l10n/l10n.dart';
import '../document/model/document.dart';
import 'chat_cards.dart';
import 'domain/agent_protocol.dart';
import 'presentation/ui_components.dart';

/// The approval cards of one chat waiting for the lawyer. Each ends [CardStatus.approved], [CardStatus.rejected] or [CardStatus.expired].
class Approvals {
  Approvals(this._threadId, this._chat, this._clock, this._onResolved);

  final String _threadId;
  final ChatMessagesController _chat;
  final ChatClock _clock;

  /// Called with the status and the title of each answered card.
  final void Function(String status, String title) _onResolved;
  final _pending = <String, (Completer<String>, Map<String, dynamic>, DateTime)>{};

  /// An approval lapses before the server stops waiting for it: past that, the run has moved on without the
  /// action, and a late "yes" must not run it.
  static final window = toolResultTimeout - const Duration(seconds: 30);

  List<String> get pending => [..._pending.keys];

  /// Shows the card asking to run [call] on [doc], worded in [l]; completes with the answer, or [CardStatus.expired] after
  /// [window].
  Future<String> ask(AgentToolCall call, String title, PaperDocument? doc, AppLocalizations l) {
    final id = _clock.id('ok');
    final stamp = _clock.stamp();
    final page = call.arguments['page'];
    final target = page is num && doc != null && page >= 1 && page <= doc.pages.length
        ? doc.pages[page.toInt() - 1]
        : null;
    final data = <String, dynamic>{
      'id': id,
      'threadId': _threadId,
      'tool': call.name,
      'title': title,
      'description': target == null
          ? l.approvalRunTool(title)
          : l.approvalDeletePage(page.toInt(), target.title, l.wordCount(target.wordCount)),
      'status': CardStatus.pending,
    };
    final completer = Completer<String>();
    _pending[id] = (completer, data, stamp);
    final lapse = Timer(window, () => resolve(id, approved: false, expired: true));
    unawaited(completer.future.whenComplete(lapse.cancel));
    _chat.addMessage(ChatCards.approval(id, stamp, data));
    return completer.future;
  }

  /// Answers card [id]; [expired]: nobody answered while the server still waited. A card already answered stays.
  void resolve(String id, {required bool approved, bool expired = false}) {
    final pending = _pending.remove(id);
    if (pending == null) return;
    final (completer, data, stamp) = pending;
    final status = expired ? CardStatus.expired : approved ? CardStatus.approved : CardStatus.rejected;
    _chat.updateMessage(ChatCards.approval(id, stamp, {...data, 'status': status}));
    _onResolved(status, data['title'] as String);
    if (!completer.isCompleted) completer.complete(status);
  }
}
