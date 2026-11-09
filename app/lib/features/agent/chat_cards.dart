import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart'
    hide AgentRequest;

import 'domain/agent_protocol.dart';
import 'presentation/ui_components.dart';

/// The lawyer's side of every chat.
const lawyer = ChatUser(id: 'user', name: 'Tu');

/// The agent's side of every chat.
const paperAgent = ChatUser(id: 'agent', name: 'PaperAgent');

/// Keys of a chat message's `customProperties` that the app reads back.
abstract final class ChatProps {
  /// True while the agent's reply is still being streamed; never saved.
  static const streaming = 'isStreaming';

  /// Intermediate output retained for review/history, not another item in the conversation.
  static const workflowDetail = 'workflowDetail';
}

/// The line of file names the app appends to a prompt it sends with attachments: the app's, not the lawyer's text.
abstract final class AttachmentsLine {
  static const marker = '\n\n📎 ';

  /// [prompt] followed by the line naming [names].
  static String add(String prompt, String names) =>
      names.isEmpty ? prompt : '$prompt$marker$names';

  /// [text] as the lawyer wrote it, without the line [add] appended.
  static String promptOf(String text) => text.split(marker).first;
}

/// Ids and times of the chat messages. Ids are unique across launches too: a saved chat keeps the ids of the
/// previous one. Times strictly increase: the chat controller orders messages by time.
class ChatClock {
  var _seq = DateTime.now().millisecondsSinceEpoch;
  var _last = DateTime.fromMillisecondsSinceEpoch(0);

  String id(String prefix) => '$prefix${_seq++}';

  DateTime stamp() {
    var now = DateTime.now();
    if (!now.isAfter(_last)) now = _last.add(const Duration(milliseconds: 1));
    return _last = now;
  }

  /// A message read back or seeded at [at]: the next ones come after it.
  void saw(DateTime at) {
    if (at.isAfter(_last)) _last = at;
  }
}

/// The messages of a chat: what each side writes and the cards the agent shows.
class ChatCards {
  ChatCards(this.clock);

  final ChatClock clock;

  /// A markdown message of [who], with [props] besides its id.
  static ChatMessage say(
    ChatUser who,
    String text, {
    required String id,
    required DateTime at,
    Map<String, dynamic> props = const {},
  }) => ChatMessage(
    text: text,
    user: who,
    createdAt: at,
    isMarkdown: true,
    customProperties: {'id': id, ...props},
  );

  ChatMessage prompt(String text) =>
      say(lawyer, text, id: clock.id('u'), at: clock.stamp());

  /// A short line of the app's own, e.g. "_Stopped._".
  ChatMessage note(String text) =>
      say(paperAgent, text, id: clock.id('a'), at: clock.stamp());

  ChatMessage failure(String message) => ChatMessage(
    text: message,
    user: paperAgent,
    createdAt: clock.stamp(),
    hasError: true,
    errorMessage: message,
    customProperties: {'id': clock.id('e')},
  );

  /// A rich component the agent sent or a tool result shows.
  ChatMessage component(String kind, Map<String, dynamic> data) =>
      rich(kind, clock.id('c'), clock.stamp(), text: kind, data: data);

  /// The agent's reply as streamed so far; [streaming] false once it is complete.
  static ChatMessage reply(
    String id,
    DateTime at,
    String text, {
    required bool streaming,
  }) => say(
    paperAgent,
    text,
    id: id,
    at: at,
    props: {ChatProps.streaming: streaming},
  );

  /// A tool call: running, then done, error or rejected, with how long it took.
  static ChatMessage toolCall(
    String id,
    DateTime at,
    AgentToolCall call,
    String title,
    String status, {
    String detail = '',
    int? ms,
  }) => rich(
    UiComponents.toolCall,
    id,
    at,
    text: title,
    data: {
      'tool': call.name,
      'title': title,
      'status': status,
      'detail': detail,
      'args': call.arguments,
      'ms': ?ms,
    },
  );

  /// A question to the lawyer; [data] carries its status (pending, approved, rejected, expired).
  static ChatMessage approval(
    String id,
    DateTime at,
    Map<String, dynamic> data,
  ) => rich(
    UiComponents.approval,
    id,
    at,
    text: data['title'] as String,
    data: data,
  );

  /// The steps of a turn, updated in place while it runs.
  static ChatMessage progress(
    String id,
    DateTime at,
    List<Map<String, dynamic>> steps, {
    required bool running,
    required int seconds,
    String? status,
    bool operational = true,
  }) => rich(
    UiComponents.progress,
    id,
    at,
    text: UiComponents.progress,
    data: {
      'steps': [...steps],
      'running': running,
      'seconds': seconds,
      'status': status ?? (running ? CardStatus.running : CardStatus.done),
      'startedAt': at.toIso8601String(),
      'operational': operational,
    },
  );

  static ChatMessage rich(
    String kind,
    String id,
    DateTime at, {
    required String text,
    required Map<String, dynamic> data,
  }) => ChatMessage.rich(
    user: paperAgent,
    resultKind: kind,
    id: id,
    createdAt: at,
    text: text,
    data: data,
  );
}
