import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../document/model/document.dart';
import '../document/model/operations.dart';
import '../document/render/page_fit.dart';
import '../workspace/pdf_export.dart';
import '../workspace/workspace_state.dart';
import 'domain/agent_protocol.dart';
import 'domain/document_tools.dart';

/// Tool host bound to one chat: tools act on that chat's document, even
/// while the user looks at another chat.
class ThreadToolHost implements ToolHost {
  ThreadToolHost(this._ref, this.threadId, this._attachments);

  final Ref _ref;
  final String threadId;
  final List<AgentAttachment> Function() _attachments;

  @override
  PaperDocument? get activeDocument {
    final ws = _ref.read(workspaceProvider);
    final id = ws.threads[threadId]?.documentId;
    return id == null ? null : ws.documents[id];
  }

  @override
  void applyOperations(List<DocOperation> ops, {required String label}) =>
      _ref.read(workspaceProvider.notifier).apply(
        ops,
        documentId: activeDocument?.id,
        label: _ref.read(l10nProvider).agentHistoryLabel(label),
      );

  @override
  void openNewDocument(PaperDocument doc) =>
      _ref.read(workspaceProvider.notifier).addDocument(doc, threadId: threadId);

  @override
  Future<FittedDocument> fitPages(PaperDocument doc) =>
      _ref.read(pageFitProvider)(doc);

  @override
  Future<String?> exportActiveDocument() async {
    final doc = activeDocument;
    return doc == null ? null : _ref.read(exportServiceProvider).export(doc);
  }

  @override
  AgentAttachment? attachment(String name) =>
      _attachments().where((a) => a.name == name).firstOrNull;
}
