import 'package:flutter/material.dart';

import '../../../features/agent/presentation/ui_components.dart';
import 'action_cards.dart';
import 'document_cards.dart';
import 'legal_cards.dart';
import 'page_cards.dart';
import 'progress_cards.dart';
import 'tool_step.dart';
import 'evidence_card.dart';

typedef ComponentBuilder = Widget Function(
  BuildContext context,
  Map<String, dynamic> props,
);

/// The vertical component registry: component name → widget.
///
/// `flutter_gen_ai_chat_ui` renders `ChatMessage.rich` messages through
/// these builders ([componentRenderers]); [AgentMarkdown] uses the same
/// registry for ```` ```ui:<name> ```` fences inside text. Adding a
/// component is one entry here plus its name in [UiComponents].
final Map<String, ComponentBuilder> componentRegistry = {
  UiComponents.toolCall: (_, p) => ToolStep(props: p),
  UiComponents.pdfPage: (_, p) => PdfPageCard(props: p),
  UiComponents.pdfDiff: (_, p) => PdfDiffCard(props: p),
  UiComponents.documentCard: (_, p) => DocumentCardComponent(props: p),
  UiComponents.documentOutline: (_, p) => DocumentOutlineCard(props: p),
  UiComponents.chart: (_, p) => ChartCard(props: p),
  UiComponents.exportResult: (_, p) => ExportCard(props: p),
  UiComponents.approval: (_, p) => ApprovalCard(props: p),
  UiComponents.changeSummary: (_, p) => ChangeSummaryCard(props: p),
  UiComponents.norms: (_, p) => NormsCard(props: p),
  UiComponents.caseAnalysis: (_, p) => CaseAnalysisCard(props: p),
  UiComponents.progress: (_, p) => ProgressCard(props: p),
  UiComponents.matrix: (_, p) => MatrixCard(props: p),
  UiComponents.evidence: (_, p) => EvidenceCard(props: p),
};

/// Renderers for `AiChatWidget.resultRenderers`, each wrapped so rich
/// messages line up with the text column.
Map<String, Widget Function(BuildContext, Map<String, dynamic>)>
get componentRenderers => {
  for (final e in componentRegistry.entries)
    e.key: (context, props) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: e.value(context, props),
    ),
};

Widget? buildComponent(
  BuildContext context,
  String kind,
  Map<String, dynamic> props,
) => componentRegistry[kind]?.call(context, props);
