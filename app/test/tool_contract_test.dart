import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/features/agent/domain/agent_protocol.dart';
import 'package:paper_agent/features/agent/domain/document_tools.dart';
import 'package:paper_agent/features/document/model/document.dart';
import 'package:paper_agent/features/document/model/operations.dart';
import 'package:paper_agent/features/document/render/page_fit.dart';
import 'package:paper_agent/features/document/service/document_service.dart';

/// The contract shared with the server: what the executor does with each
/// tool call. The server's Python twin (paperagent_server/docsim.py) runs the
/// same cases, so the two cannot drift apart unnoticed.
///
/// The app is the reference: after changing the executor on purpose, rewrite
/// the expected results with `TOOL_CASES_WRITE=1 flutter test
/// test/tool_contract_test.dart`, review the diff, then make docsim follow.
final _file = File('test/fixtures/tool_cases.json');

class _Host implements ToolHost {
  _Host(this.activeDocument);

  @override
  PaperDocument? activeDocument;

  @override
  void applyOperations(List<DocOperation> ops, {required String label}) =>
      activeDocument = const DocumentService().applyAll(activeDocument!, ops);

  @override
  void openNewDocument(PaperDocument doc) => activeDocument = doc;

  @override
  Future<String?> exportActiveDocument() async => null;

  @override
  Future<FittedDocument> fitPages(PaperDocument doc) async => FittedDocument(doc);

  @override
  AgentAttachment? attachment(String name) => null;
}

/// The document as the contract compares it: no ids, dates or images.
Map<String, dynamic>? outline(PaperDocument? doc) {
  if (doc == null) return null;
  Object? strip(Object? value) => switch (value) {
    Map() => {
      for (final e in value.entries)
        if (e.key != 'id' && e.key != 'data') e.key as String: strip(e.value),
    },
    List() => [for (final v in value) strip(v)],
    _ => value,
  };
  final json = doc.toJson();
  final meta = json['metadata'] as Map<String, dynamic>;
  return {
    'metadata': {for (final k in ['title', 'subtitle', 'client', 'author', 'status']) k: meta[k]},
    'theme': json['theme'],
    'pages': strip(json['pages']),
  };
}

Future<(Map<String, dynamic>, Map<String, dynamic>?)> run(
  Map<String, dynamic> contract,
  Map<String, dynamic> testCase,
) async {
  final source = testCase['document'] as String?;
  final document = source == null
      ? null
      : PaperDocument.fromJson((contract['documents'] as Map)[source] as Map<String, dynamic>);
  final host = _Host(document);
  final call = testCase['call'] as Map<String, dynamic>;
  final result = await DocumentToolExecutor(host).execute(AgentToolCall(
    id: 'c',
    name: call['name'] as String,
    arguments: (call['arguments'] as Map).cast<String, dynamic>(),
  ));
  final before = outline(document);
  final after = outline(host.activeDocument);
  return (
    {'ok': result.ok, 'summary': result.summary, 'focusPage': ?result.focusPage},
    jsonEncode(before) == jsonEncode(after) ? null : after,
  );
}

void main() {
  final contract = jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>;
  final cases = (contract['cases'] as List).cast<Map<String, dynamic>>();

  if (Platform.environment['TOOL_CASES_WRITE'] == '1') {
    test('write the expected results from this executor', () async {
      for (final c in cases) {
        final (result, after) = await run(contract, c);
        c['result'] = result;
        if (after == null) {
          c.remove('after');
        } else {
          c['after'] = after;
        }
      }
      _file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(contract)}\n');
    });
    return;
  }

  for (final c in cases) {
    test(c['name'], () async {
      final (result, after) = await run(contract, c);
      expect(result, c['result']);
      expect(after, c['after']);
    });
  }
}

