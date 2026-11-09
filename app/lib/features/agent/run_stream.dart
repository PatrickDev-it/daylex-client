import 'dart:async';

import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart' hide AgentRequest;

import 'chat_cards.dart';
import 'domain/agent_protocol.dart';

/// The events of one run, handled one at a time and in order: a tool call is awaited before the next event is
/// read. Once [stop]ped nothing more is handled, an error included. A handler that throws ends the run the
/// same way a broken stream does: its error goes to `onError` and nothing after it is handled.
class RunStream {
  RunStream(Stream<AgentEvent> events, {required Future<void> Function(AgentEvent) onEvent,
      required void Function(Object error) onError}) {
    _subscription = events.listen(
      (event) => _queue = _queue.then((_) async {
        if (!_stopped) await onEvent(event);
      }).catchError((Object e) {
        if (_stopped) return;
        onError(e);
        stop();
      }),
      // With cancelOnError, onDone is not called after an error.
      onError: (Object e) => _queue = _queue.then((_) {
        if (!_stopped) onError(e);
      }).whenComplete(_finish),
      onDone: () => _queue.whenComplete(_finish),
      cancelOnError: true,
    );
  }

  late final StreamSubscription<AgentEvent> _subscription;
  var _queue = Future<void>.value();
  final _done = Completer<void>();
  var _stopped = false;

  /// Completes when the run ends, fails or is stopped.
  Future<void> get done => _done.future;

  bool get stopped => _stopped;

  void stop() {
    _stopped = true;
    unawaited(_subscription.cancel());
    _finish();
  }

  void _finish() {
    if (!_done.isCompleted) _done.complete();
  }
}

/// The agent's reply streamed into the chat: one message, rewritten as each piece arrives, closed when something
/// else (a tool call, a card, the end) comes in between. [onClosed] gets the whole text of each reply.
class StreamedReply {
  StreamedReply(this._chat, this._clock, this._onClosed);

  final ChatMessagesController _chat;
  final ChatClock _clock;
  final void Function(String text) _onClosed;
  final _text = StringBuffer();
  String? _id;
  DateTime? _at;

  void add(String piece) {
    _text.write(piece);
    final isNew = _id == null;
    final id = _id ??= _clock.id('a');
    final at = _at = isNew ? _clock.stamp() : _at!;
    final message = ChatCards.reply(id, at, _text.toString(), streaming: true);
    isNew ? _chat.addMessage(message) : _chat.updateMessage(message);
  }

  void close() {
    if (_id case final id?) {
      _chat.updateMessage(ChatCards.reply(id, _at!, _text.toString(), streaming: false));
      _chat.stopStreamingMessage(id);
      _onClosed(_text.toString());
    }
    _id = null;
    _text.clear();
  }
}
