import '../features/agent/domain/agent_protocol.dart';
import '../features/agent/session_state.dart';
import '../features/agent/presentation/ui_components.dart';
import '../features/document/model/document.dart';
import '../features/document/model/operations.dart';
import 'app_localizations.dart';

/// The names the lawyer reads for the document model's values. The model keeps the wire names; what they are
/// called on screen, and in which language, is decided only here.
extension ModelLabels on AppLocalizations {
  String componentLabel(String kind) => switch (kind) {
    UiComponents.toolCall => componentTool,
    UiComponents.pdfPage => componentPage,
    UiComponents.pdfDiff => componentDiff,
    UiComponents.documentCard => componentDocument,
    UiComponents.documentOutline => componentOutline,
    UiComponents.chart => componentChart,
    UiComponents.exportResult => componentExport,
    UiComponents.approval => componentApproval,
    UiComponents.changeSummary => componentSummary,
    UiComponents.norms => componentNorms,
    UiComponents.caseAnalysis => componentCase,
    UiComponents.progress => componentProgress,
    UiComponents.evidence => evidenceTitle,
    UiComponents.matrix => componentMatrix,
    _ => componentOther,
  };

  String layoutValue(String value) => switch (value.toLowerCase()) {
    'cover' => layoutCover,
    'standard' => layoutStandard,
    'twocolumn' || 'two_column' || 'two columns' => layoutTwoColumn,
    'premium' => layoutPremium,
    _ => '',
  };

  String phaseLabel(AgentPhase phase) => switch (phase) {
    AgentPhase.idle => phaseIdle,
    AgentPhase.thinking => phaseThinking,
    AgentPhase.working => phaseWorking,
    AgentPhase.waiting => phaseWaiting,
    AgentPhase.error => phaseError,
  };

  String eventLabel(String kind) => switch (kind) {
    LogKind.request => eventRequest,
    LogKind.status => eventStatus,
    LogKind.text => eventText,
    LogKind.tool => eventTool,
    LogKind.result => eventResult,
    LogKind.ui => eventUi,
    LogKind.approval => eventApproval,
    LogKind.attachment => eventAttachment,
    LogKind.error => eventError,
    LogKind.done => eventDone,
    _ => eventOther,
  };

  /// Which agent answers: the offline mock, none (a missing or broken configuration), or the server's name.
  String agentBackend(AgentClient client) => client.isMock
      ? agentMockOffline
      : client.problem != null
      ? agentNotConnected
      : client.displayName;

  String docStatus(DocumentStatus status) => switch (status) {
    DocumentStatus.draft => docStatusDraft,
    DocumentStatus.review => docStatusReview,
    DocumentStatus.approved => docStatusApproved,
  };

  String layout(PageLayout layout) => switch (layout) {
    PageLayout.cover => layoutCover,
    PageLayout.standard => layoutStandard,
    PageLayout.twoColumn => layoutTwoColumn,
    PageLayout.premium => layoutPremium,
  };

  String blockKind(BlockKind kind) => switch (kind) {
    BlockKind.heading => blockHeading,
    BlockKind.paragraph => blockParagraph,
    BlockKind.bullets => blockBullets,
    BlockKind.table => blockTable,
    BlockKind.metrics => blockMetrics,
    BlockKind.quote => blockQuote,
    BlockKind.callout => blockCallout,
    BlockKind.image => blockImage,
  };

  /// The step's name in the document history: what undo and redo say they undid.
  String operation(DocOperation op) => switch (op) {
    AddPage() => opAddPage,
    DeletePage(:final pageIndex) => opDeletePage(pageIndex + 1),
    MovePage(:final from) => opMovePage(from + 1),
    UpdatePage(:final pageIndex) => opUpdatePage(pageIndex + 1),
    ReplaceText(:final find) => opReplace(find),
    InsertBlock(:final block) => opInsertBlock(
      blockKind(block.kind).toLowerCase(),
    ),
    UpdateBlock(:final block) => opEditBlock(
      blockKind(block.kind).toLowerCase(),
    ),
    RemoveBlock() => opRemoveBlock,
    MoveBlock() => opMoveBlock,
    SetTheme() => opChangeTheme,
    UpdateMetadata() => opUpdateDetails,
  };
}
