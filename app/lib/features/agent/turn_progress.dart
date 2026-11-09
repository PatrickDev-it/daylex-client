import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart'
    show ChatMessagesController;

import 'chat_cards.dart';
import 'domain/agent_protocol.dart';
import 'presentation/ui_components.dart';

/// One mutable projection of observed work, owned by one turn and persisted as one message.
class TurnProgress {
  TurnProgress(this.chat, ChatClock clock, String label)
    : id = clock.id('progress'),
      at = clock.stamp() {
    add('initializing', label);
  }

  final ChatMessagesController chat;
  final String id;
  final DateTime at;
  final _steps = <Map<String, dynamic>>[];
  var _inserted = false;
  var _status = CardStatus.running;

  void observe(AgentStatusEvent event) {
    if (event.quiet) return;
    add(event.kind, event.label, event.detail);
  }

  void add(String kind, String label, [String detail = '']) {
    if (_status != CardStatus.running || label.trim().isEmpty) return;
    final step = {
      'kind': kind,
      'label': label,
      'detail': detail,
      'at': _seconds,
    };
    if (_steps.isNotEmpty &&
        _steps.last['kind'] == kind &&
        _steps.last['label'] == label) {
      step['at'] = _steps.last['at']!;
      _steps[_steps.length - 1] = step;
    } else {
      _steps.add(step);
    }
    _publish();
  }

  int get _seconds => DateTime.now().difference(at).inSeconds.clamp(0, 86400);

  void finish(String status) {
    if (_status != CardStatus.running) return;
    _status = status;
    _publish();
  }

  void _publish() {
    final message = ChatCards.progress(
      id,
      at,
      _steps,
      running: _status == CardStatus.running,
      seconds: _seconds,
      status: _status,
    );
    if (_inserted) {
      chat.updateMessage(message);
    } else {
      chat.addMessage(message);
      _inserted = true;
    }
  }
}
