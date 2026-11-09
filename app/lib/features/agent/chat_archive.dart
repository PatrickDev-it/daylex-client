import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart'
    hide AgentRequest;

import '../storage/local_store.dart';
import '../workspace/legacy_demo.dart';
import 'chat_cards.dart';
import 'presentation/ui_components.dart';
import 'session_state.dart';

/// The saved chats: messages and turns (the Review tab) of each. The only owner of the `chats/` files of the
/// [LocalStore]: nothing else writes or deletes them.
class ChatArchive {
  ChatArchive(this._store);

  final LocalStore _store;

  /// [id] as saved; null when it never was, or when its file is not a chat this app can read (then kept for
  /// a human, and the chat opens empty: one damaged file never stops the others). The versions its cards
  /// show are read on demand.
  (List<ChatMessage>, List<TurnRecord>)? read(String id) {
    final saved = _store.readChat(id);
    if (saved == null) return null;
    try {
      return (
        [
          for (final m in saved['messages'] as List? ?? const [])
            if (m is Map) messageFromJson(m.cast<String, dynamic>()),
        ],
        [
          for (final t in saved['turns'] as List? ?? const [])
            ?TurnRecord.fromJson(t),
        ],
      );
    } on Object catch (e) {
      debugPrint('PaperAgent: chat $id unreadable: $e');
      _store.setAsideChat(id);
      return null;
    }
  }

  void write(
    String id,
    Iterable<ChatMessage> messages,
    Iterable<TurnRecord> turns,
  ) {
    try {
      _store.writeChat(id, {
        'messages': [for (final m in messages) ?messageToJson(m)],
        'turns': [for (final t in turns) t.toJson()],
      });
    } on FileSystemException catch (e) {
      _store.saveFailed(e);
    }
  }

  /// Deletes [id]'s file. One the system refuses to delete (a read-only file) is said, and the chat still goes:
  /// its file is left for a recovery to bring back, never in the way of the workspace.
  void delete(String id) {
    try {
      _store.deleteChat(id);
    } on FileSystemException catch (e) {
      _store.saveFailed(e);
    }
  }

  /// Deletes the chats of the demo an older version saved that the workspace no longer has ([kept] are its
  /// chats). Only those: any other chat without its index is work the next recovery brings back.
  void deleteDroppedDemo(Iterable<String> kept) {
    for (final id in legacyDemoThreads.keys) {
      if (!kept.contains(id)) delete(id);
    }
  }

  static Map<String, dynamic>? messageToJson(ChatMessage m) {
    if (m.customBuilder != null) {
      return null; // an inline widget: nothing to write
    }
    final props = _restorableProps(m.customProperties);
    return {
      'text': m.text,
      'user': m.user.id,
      'createdAt': m.createdAt.toIso8601String(),
      'isMarkdown': m.isMarkdown,
      if (m.hasError) 'error': m.errorMessage ?? m.text,
      'props': props,
    };
  }

  static Map<String, dynamic> _restorableProps(Map<String, dynamic>? input) {
    final props = {...?input}..remove(ChatProps.streaming);
    final data = props['resultData'];
    if (props['resultKind'] == UiComponents.progress &&
        data is Map &&
        data['running'] == true) {
      // An interrupted process cannot resume from a visual spinner after a restart.
      props['resultData'] = {
        ...data,
        'running': false,
        'status': CardStatus.rejected,
      };
    }
    if (props['resultKind'] == UiComponents.toolCall &&
        data is Map &&
        data['status'] == CardStatus.running) {
      props['resultData'] = {...data, 'status': CardStatus.interrupted};
    }
    if (props['resultKind'] == UiComponents.approval &&
        data is Map &&
        data['status'] == CardStatus.pending) {
      // The run that asked is gone after a restart: the card cannot be answered any more.
      props['resultData'] = {...data, 'status': CardStatus.expired};
    }
    return props;
  }

  static ChatMessage messageFromJson(Map<String, dynamic> json) {
    final error = json['error'] as String?;
    return ChatMessage(
      text: json['text'] as String? ?? '',
      user: json['user'] == lawyer.id ? lawyer : paperAgent,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      isMarkdown: json['isMarkdown'] as bool? ?? true,
      hasError: error != null,
      errorMessage: error,
      customProperties: _restorableProps((json['props'] as Map?)?.cast<String, dynamic>()),
    );
  }
}
