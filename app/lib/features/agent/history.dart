import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart' hide AgentRequest;

import 'chat_cards.dart';
import 'domain/agent_protocol.dart';

/// The conversation so far, oldest first, as the server reads it.
///
/// The chat controller keeps its messages newest first. One agent reply
/// is often several messages (text, cards, more text): they become one
/// turn. Cards that carry a `digest` (norms, case analysis) add it, so a
/// follow-up ("sviluppa la strategia S2") knows what the card showed.
List<AgentTurn> conversationOf(Iterable<ChatMessage> messages) {
  final ordered = [...messages]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final turns = <AgentTurn>[];
  void add(String role, String text) {
    if (text.trim().isEmpty) return;
    if (turns.isNotEmpty && turns.last.role == role && role == 'assistant') {
      turns.last = AgentTurn(role: role, text: '${turns.last.text}\n\n$text');
    } else {
      turns.add(AgentTurn(role: role, text: text));
    }
  }

  for (final m in ordered) {
    if (m.hasError) continue;
    if (m.customProperties?['resultKind'] == null) {
      add(m.user.id == lawyer.id ? 'user' : 'assistant', m.text);
    } else if ((m.customProperties?['resultData'] as Map?)?['digest'] case final String digest) {
      add('assistant', digest);
    }
  }
  return turns;
}

/// The most recent turns the server takes: a long chat's oldest ones go (the server trims further to fit).
List<AgentTurn> recentConversation(Iterable<ChatMessage> messages) {
  final turns = conversationOf(messages);
  return turns.length <= maxHistoryTurns ? turns : turns.sublist(turns.length - maxHistoryTurns);
}
