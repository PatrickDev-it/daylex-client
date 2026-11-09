import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart'
    show ChatMessage;

import '../../../l10n/l10n.dart';
import '../domain/agent_protocol.dart';
import 'ui_components.dart';

/// Operational progress is visible; legacy/internal payloads remain in diagnostics.
abstract final class ConversationPresentation {
  static bool visible(ChatMessage message) {
    final properties = message.customProperties;
    final data = properties?['resultData'];
    if (properties?['resultKind'] == UiComponents.progress) {
      return data is Map && data['operational'] == true;
    }
    return true;
  }

  static String activity(AppLocalizations l, String kind) =>
      switch (statusActivities[kind]) {
        'reading' => l.agentReadingAttachments,
        'comparing' => l.agentComparingDocuments,
        'sources' => l.agentConsultingSources,
        'drafting' => l.agentDraftingDocument,
        'checking' => l.agentCheckingResult,
        'waiting' => l.agentQueued,
        'warning' => l.agentMaterialWarning,
        _ => l.agentThinking,
      };
}
