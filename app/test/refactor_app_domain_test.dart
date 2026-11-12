import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/features/agent/attachment_files.dart';
import 'package:paper_agent/features/agent/chat_cards.dart';
import 'package:paper_agent/features/agent/domain/agent_protocol.dart';
import 'package:paper_agent/features/agent/domain/document_tools.dart';
import 'package:paper_agent/features/agent/presentation/ui_components.dart';
import 'package:paper_agent/features/agent/session_state.dart';
import 'package:paper_agent/features/document/data/doc_templates.dart';
import 'package:paper_agent/features/document/model/document.dart';
import 'package:paper_agent/features/document/model/operations.dart';
import 'package:paper_agent/features/document/render/page_fit.dart';
import 'package:paper_agent/features/document/service/document_service.dart';

import 'demo_fixture.dart';

/// Guards for the app-domain refactor: the behaviour the cleanup must keep, and the rules that now live in one
/// place.
class _Host implements ToolHost {
  @override
  PaperDocument? activeDocument;

  @override
  void applyOperations(List<DocOperation> ops, {required String label}) {}

  @override
  void openNewDocument(PaperDocument doc) => activeDocument = doc;

  @override
  Future<String?> exportActiveDocument() async => null;

  @override
  Future<FittedDocument> fitPages(PaperDocument doc) async => FittedDocument(doc);

  @override
  AgentAttachment? attachment(String name) => null;
}

/// Source of every Dart file the app-domain partition owns, by path under lib/.
Map<String, String> _libSources() => {
  for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
    if (f.path.endsWith('.dart') && !f.path.contains('l10n')) f.path: f.readAsStringSync(),
};

void main() {
  group('attachment types', () {
    test('the case file reads these types, in this order', () {
      expect(attachableTypes, ['pdf', 'p7m', 'docx', 'txt', 'png', 'jpg', 'jpeg']);
    });

    test('every readable type has a mime type, the rest are octet-stream', () {
      const expected = {
        'pdf': 'application/pdf',
        'p7m': 'application/pkcs7-mime',
        'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'txt': 'text/plain',
        'png': 'image/png',
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
      };
      for (final type in attachableTypes) {
        expect(mimeFor('file.$type'), expected[type], reason: type);
        expect(mimeFor('FILE.${type.toUpperCase()}'), expected[type], reason: type);
      }
      expect(mimeFor('archive.zip'), 'application/octet-stream');
      expect(mimeFor('noextension'), 'application/octet-stream');
    });
  });

  group('a document keeps at least one page', () {
    const message = 'Un documento deve avere almeno una pagina.';

    test('deleting the last page says so', () {
      final full = buildQ3Proposal();
      final one = full.copyWith(pages: [full.pages.first]);
      expect(
        () => const DocumentService().apply(one, const DeletePage(0)),
        throwsA(isA<DocumentOperationException>().having((e) => e.message, 'message', message)),
      );
    });

    test('creating a document without pages says so', () async {
      final result = await DocumentToolExecutor(_Host())
          .execute(AgentToolCall(id: 'c', name: 'create_document', arguments: {'title': 'Nota', 'pages': []}));
      expect(result.ok, isFalse);
      expect(result.summary, contains(message));
    });

    test('the sentence is written once', () {
      final owners = [
        for (final e in _libSources().entries)
          if (e.value.contains(message)) e.key,
      ];
      expect(owners, hasLength(1), reason: owners.join(', '));
    });
  });

  group('what a tool call reports to the server', () {
    test('an answer carries the page and the data only when it has them', () {
      expect(const ToolResult.error('no').toJson(), {'ok': false, 'summary': 'no'});
      expect(const ToolResult.ok('done').toJson(), {'ok': true, 'summary': 'done'});
      expect(const ToolResult.ok('done', focusPage: 2, data: {'path': 'a.pdf'}).toJson(), {
        'ok': true,
        'summary': 'done',
        'focusPage': 2,
        'data': {'path': 'a.pdf'},
      });
    });
  });

  group('names shared with the server and the UI', () {
    test('every tool of the registry has a name and a handler, and no other does', () {
      final specs = {for (final t in documentToolSpecs) t.name};
      expect(ToolNames.all, specs);
      expect(DocumentToolExecutor(_Host()).handledTools, specs);
    });

    test('an unknown tool is told so once a document is open', () async {
      final host = _Host()..activeDocument = buildQ3Proposal();
      final result = await DocumentToolExecutor(host).execute(AgentToolCall(id: 'c', name: 'nope', arguments: {}));
      expect(result.ok, isFalse);
      expect(result.summary, 'Strumento sconosciuto "nope".');
    });

    test('log kinds and card states keep their strings', () {
      expect(
        [
          LogKind.request,
          LogKind.status,
          LogKind.text,
          LogKind.tool,
          LogKind.result,
          LogKind.ui,
          LogKind.approval,
          LogKind.attachment,
          LogKind.error,
          LogKind.done,
        ],
        ['request', 'status', 'text', 'tool', 'result', 'ui', 'approval', 'attachment', 'error', 'done'],
      );
      expect(
        [
          CardStatus.running,
          CardStatus.done,
          CardStatus.error,
          CardStatus.rejected,
          CardStatus.pending,
          CardStatus.approved,
          CardStatus.expired,
        ],
        ['running', 'done', 'error', 'rejected', 'pending', 'approved', 'expired'],
      );
    });

    test('the attachments line and the streaming flag keep their wire form', () {
      expect(AttachmentsLine.marker, '\n\n\u{1F4CE} ');
      expect(AttachmentsLine.add('Ciao', '`a.pdf` `b.txt`'), 'Ciao\n\n\u{1F4CE} `a.pdf` `b.txt`');
      expect(AttachmentsLine.add('Ciao', ''), 'Ciao');
      expect(AttachmentsLine.promptOf(AttachmentsLine.add('Ciao', '`a.pdf`')), 'Ciao');
      expect(AttachmentsLine.promptOf('Ciao'), 'Ciao');
      final reply = ChatCards.reply('r1', DateTime(2026), 'testo', streaming: true);
      expect(reply.customProperties, {'id': 'r1', ChatProps.streaming: true});
      expect(ChatProps.streaming, 'isStreaming');
    });
  });

  group('templates', () {
    test('a template announces the pages and the accent it builds', () {
      for (final t in docTemplates) {
        final doc = t.build('p');
        expect(doc.pages, hasLength(t.pageCount), reason: t.id);
        expect(doc.theme.accent, t.accent, reason: t.id);
      }
    });
  });

  group('one definition', () {
    test('the save delay is written once', () {
      // Another named delay may share its value (the preview's settle does); the save delay written out
      // where it is used, instead of named, is what is caught.
      const value = 'Duration(milliseconds: 300)';
      final named = RegExp(r'\w+ = ' + RegExp.escape(value));
      final unnamed = [
        for (final e in _libSources().entries)
          if (value.allMatches(e.value).length > named.allMatches(e.value).length) e.key,
      ];
      expect(unnamed, isEmpty, reason: unnamed.join(', '));
      final owners = [
        for (final e in _libSources().entries)
          if (e.value.contains('saveDelay = ')) e.key,
      ];
      expect(owners, hasLength(1), reason: owners.join(', '));
    });
  });
}
