import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/features/agent/domain/agent_protocol.dart';
import 'package:paper_agent/features/agent/domain/document_tools.dart';
import 'package:paper_agent/features/agent/presentation/ui_components.dart';
import 'package:paper_agent/features/document/data/doc_templates.dart';
import 'package:paper_agent/features/document/export/document_export.dart';
import 'package:paper_agent/features/document/model/document.dart';
import 'package:paper_agent/features/document/model/operations.dart';
import 'package:paper_agent/features/document/render/page_fit.dart';
import 'package:paper_agent/ui/chat/components/action_cards.dart';

import 'test_app.dart';

/// `export_file` (rfc/051): the app writes every format the server's tool names, says so in each run, and saves the
/// open document in the one a call asks for.
void main() {
  test('every run declares the formats of export_file, which are exactly those the server names', () {
    final format = (toolSpec(ToolNames.exportFile)!.parameters['properties'] as Map)['format'] as Map;
    expect(exportFileFormats.keys.toSet(), (format['enum'] as List).toSet());
    expect(exportFileFormats.values, isNot(contains(ExportFormat.pdf)));
    expect(
      const AgentRequest(sessionId: 's', prompt: 'p').toJson()['exportFormats'],
      exportFileFormats.keys.toList(),
    );
  });

  test('a call saves the open document in the format it names; an unknown one or a cancel saves nothing', () async {
    final host = _Host(docTemplates.first.build('p'));
    final tools = DocumentToolExecutor(host);
    Future<ToolResult> call(Map<String, dynamic> args) =>
        tools.execute(AgentToolCall(id: 'c', name: ToolNames.exportFile, arguments: args));

    final saved = await call({'format': 'docx'});
    expect(saved.ok, isTrue);
    expect(saved.summary, 'Salvato in C:/atti/atto.docx');
    expect(saved.data, {'path': 'C:/atti/atto.docx'});
    expect((await call({'format': 'pages'})).ok, isFalse);
    host.cancel = true;
    expect((await call({'format': 'xlsx'})).summary, 'Esportazione annullata.');
    expect(host.asked, [ExportFormat.docx, ExportFormat.xlsx]);
  });

  test('its card names the format, and leaves the pages to the PDF', () {
    final doc = docTemplates.first.build('p');
    List<UiComponent> present(String name, Map<String, dynamic> args) => presentToolResult(
      call: AgentToolCall(id: 'c', name: name, arguments: args),
      result: const ToolResult.ok('Salvato', data: {'path': 'C:/atti/atto.docx'}),
      before: doc,
      after: doc,
      snapshot: (_) => 'v1',
    );
    final file = present(ToolNames.exportFile, {'format': 'docx'}).single.props;
    expect(file, {'path': 'C:/atti/atto.docx', 'documentId': doc.id, 'format': 'docx'});
    final pdf = present(ToolNames.exportPdf, {}).single.props;
    expect(pdf['format'], 'pdf');
    expect(pdf['pages'], doc.pages.length);
  });

  testWidgets('the card shows the format it saved', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: testApp(const Scaffold(body: ExportCard(props: {'path': 'C:/atti/atto.xlsx', 'format': 'xlsx'}))),
      ),
    );
    expect(find.text('XLSX'), findsOneWidget);
    expect(find.text('atto.xlsx'), findsOneWidget);
  });

  test('the step names the format in the lawyer’s words', () {
    expect(describeToolCall(itL10n, ToolNames.exportFile, {'format': 'docx'}), 'Esporto in Word (.docx)');
  });
}

class _Host implements ToolHost {
  _Host(this.activeDocument);

  @override
  PaperDocument? activeDocument;
  final asked = <ExportFormat>[];
  var cancel = false;

  @override
  Future<String?> exportActiveDocument({ExportFormat format = ExportFormat.pdf}) async {
    asked.add(format);
    return cancel ? null : 'C:/atti/atto.${format.extension}';
  }

  @override
  void applyOperations(List<DocOperation> ops, {required String label}) {}

  @override
  void openNewDocument(PaperDocument doc) {}

  @override
  Future<FittedDocument> fitPages(PaperDocument doc) async => FittedDocument(doc);

  @override
  AgentAttachment? attachment(String name) => null;
}
