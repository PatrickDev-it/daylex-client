import '../../document/model/document.dart';
import '../../document/service/document_diff.dart';
import '../domain/agent_protocol.dart';
import '../domain/document_tools.dart';

/// Rich components the conversation can render, keyed by name.
///
/// The same names are used by the model server (`ui` events and
/// ```` ```ui:<name> ```` fences) and by [presentToolResult]. Props are plain
/// JSON; page numbers are 1-based; `snapshot` ids point into the app's
/// snapshot store so a card keeps showing the version it was made for. The
/// cards the server sends are named, and their props shaped, in the
/// generated [ServerComponents].
abstract final class UiComponents {
  /// Compact step row for a tool call.
  /// `{tool, title, status: [CardStatus], detail, args, ms}`
  static const toolCall = 'tool_call';

  /// Thumbnail of one page. `{documentId, snapshot?, page, caption?, added?}`: `added` for a page the turn added
  /// (the card says so in the app's language).
  static const pdfPage = 'pdf_page';

  /// Before/after thumbnails of one page.
  /// `{documentId, before, after, page, title, wordsBefore, wordsAfter,
  ///   layoutBefore, layoutAfter}`
  static const pdfDiff = 'pdf_diff';

  /// A document with its cover. `{documentId, snapshot?}`
  static const documentCard = 'document_card';

  /// Page list with layouts and word counts. `{documentId, snapshot?}`
  static const documentOutline = 'document_outline';

  /// Bar chart. `{title, unit?, series: [{label, value}]}`
  static const chart = 'chart';

  /// Exported file. `{path, documentId, pages}`
  static const exportResult = 'export_result';

  /// Human-in-the-loop confirmation.
  /// `{id, tool, title, description, status: [CardStatus]}`
  static const approval = 'approval';

  /// End-of-turn summary of the changes, with Undo and Review.
  /// `{turnId, documentId, title, before, after, pages: [...], seconds, tools}`
  static const changeSummary = 'change_summary';

  /// See [ServerComponents.norms].
  static const norms = ServerComponents.norms;

  /// See [ServerComponents.caseAnalysis].
  static const caseAnalysis = ServerComponents.caseAnalysis;

  /// The work of a turn, step by step, as it happens: kept with the chat.
  /// `{steps: [{label, detail, at}], running, seconds}` (`at`: seconds from
  /// the start of the turn).
  static const progress = 'progress';

  /// The API evidence audit: claims, sources and quoted passages, without legal certification.
  static const evidence = 'evidence';

  /// See [ServerComponents.matrix].
  static const matrix = ServerComponents.matrix;

  static const all = {
    toolCall,
    pdfPage,
    pdfDiff,
    documentCard,
    documentOutline,
    chart,
    exportResult,
    approval,
    changeSummary,
    norms,
    caseAnalysis,
    progress,
    evidence,
    matrix,
  };

  /// Components that show a document and get a snapshot when the agent
  /// leaves it out.
  static const documentBound = {pdfPage, documentCard, documentOutline};
}

/// The states of the `status` prop of a [UiComponents.toolCall] and of an [UiComponents.approval] card.
abstract final class CardStatus {
  // Tool call.
  static const running = 'running';
  static const done = 'done';
  static const error = 'error';
  static const rejected = 'rejected';
  static const interrupted = 'interrupted';

  // Approval; a card also ends [rejected].
  static const pending = 'pending';
  static const approved = 'approved';
  static const expired = 'expired';
}

class UiComponent {
  const UiComponent(this.kind, this.props);
  final String kind;
  final Map<String, dynamic> props;
}

/// Default components shown after a tool call, so every change is visible in
/// the chat even when the model does not ask for a component itself.
///
/// [snapshot] stores a document version and returns its id.
List<UiComponent> presentToolResult({
  required AgentToolCall call,
  required ToolResult result,
  required PaperDocument? before,
  required PaperDocument? after,
  required String Function(PaperDocument) snapshot,
}) {
  if (!result.ok) return const [];
  switch (call.name) {
    case ToolNames.createDocument:
      if (after == null) return const [];
      return [
        UiComponent(UiComponents.documentCard, {
          'documentId': after.id,
          'snapshot': snapshot(after),
        }),
      ];
    case ToolNames.exportPdf:
      final path = result.data?['path'];
      if (path == null || after == null) return const [];
      return [
        UiComponent(UiComponents.exportResult, {
          'path': path,
          'documentId': after.id,
          'pages': after.pages.length,
        }),
      ];
    case ToolNames.addPage:
      final page = result.focusPage;
      if (page == null || after == null) return const [];
      return [
        UiComponent(UiComponents.pdfPage, {
          'documentId': after.id,
          'snapshot': snapshot(after),
          'page': page,
          'added': true,
        }),
      ];
  }

  final spec = toolSpec(call.name);
  if (spec == null || !spec.mutates || before == null || after == null) {
    return const [];
  }
  if (identical(before, after) || before.id != after.id) return const [];

  // Show the page the tool focused on, or the first page that changed.
  final changes = comparePages(before, after);
  final focus = result.focusPage;
  final change =
      changes
          .where(
            (c) =>
                c.afterIndex != null &&
                (focus == null || c.afterIndex == focus - 1),
          )
          .firstOrNull ??
      changes.where((c) => c.kind == PageChangeKind.edited).firstOrNull;
  if (change == null || change.before == null || change.after == null) {
    return const [];
  }
  return [
    UiComponent(UiComponents.pdfDiff, {
      'documentId': after.id,
      'before': snapshot(before),
      'after': snapshot(after),
      'pageBefore': change.beforeIndex! + 1,
      'page': change.afterIndex! + 1,
      'title': change.title,
      'wordsBefore': change.wordsBefore,
      'wordsAfter': change.wordsAfter,
      'layoutBefore': change.before!.layout.name,
      'layoutAfter': change.after!.layout.name,
    }),
  ];
}

/// Summary of what a whole turn changed in one document.
Map<String, dynamic> summarizeChanges({
  required String turnId,
  required PaperDocument before,
  required PaperDocument after,
  required String Function(PaperDocument) snapshot,
  required Duration elapsed,
  required int tools,
}) {
  final changes = comparePages(before, after);
  return {
    'turnId': turnId,
    'documentId': after.id,
    'title': after.title,
    'before': snapshot(before),
    'after': snapshot(after),
    'seconds': elapsed.inMilliseconds / 1000,
    'tools': tools,
    'pages': [
      for (final c in changes)
        {
          'kind': c.kind.name,
          'title': c.title,
          'page': (c.afterIndex ?? c.beforeIndex!) + 1,
          'wordsBefore': c.wordsBefore,
          'wordsAfter': c.wordsAfter,
        },
    ],
  };
}
