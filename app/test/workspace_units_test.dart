import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/features/document/model/document.dart';
import 'package:paper_agent/features/workspace/chat_thread.dart';
import 'package:paper_agent/features/workspace/doc_history.dart';
import 'package:paper_agent/features/workspace/panel_tabs.dart';
import 'package:paper_agent/features/workspace/workspace_documents.dart';
import 'package:paper_agent/features/workspace/workspace_repository.dart';
import 'package:paper_agent/features/workspace/workspace_threads.dart';

import 'demo_fixture.dart';

/// The units the workspace is made of: tabs, history, chats and documents as plain transitions, and the one
/// owner of each file on disk.
void main() {
  PaperDocument titled(String title) {
    final doc = buildQ3Proposal();
    return doc.copyWith(metadata: doc.metadata.copyWith(title: title));
  }

  group('panel tabs', () {
    final chat = newChat(id: 'c1', projectId: 'p1', title: 'Chat');
    const a = PanelTab.preview('a');
    const b = PanelTab.preview('b');

    test('a tab opens once, and focusing a preview makes its document the one the agent edits', () {
      final opened = chat.opening(a).opening(PanelTab.log).opening(a);
      expect(opened.tabs, [a, PanelTab.log]);
      expect(opened.activeTab, a);
      expect(opened.documentId, 'a');
    });

    test('closing the focused tab focuses the one before it', () {
      final open = chat.opening(a).opening(b).opening(PanelTab.review);
      final closed = open.closing(PanelTab.review);
      expect(closed.tabs, [a, b]);
      expect(closed.activeTab, b);
      expect(closed.documentId, 'b');
      expect(closed.closing(PanelTab.log), same(closed));
    });

    test('a deleted document leaves every tab and chat that showed it', () {
      final forgot = chat.opening(a).opening(b).forgetting('b');
      expect(forgot.tabs, [a]);
      expect(forgot.activeTab, isNull);
      expect(forgot.documentId, isNull);
    });
  });

  group('history', () {
    test('a new step clears redo, and undo then redo come back to the same version', () {
      final v1 = titled('v1'), v2 = titled('v2'), v3 = titled('v3');
      final history = const DocHistory().pushed(v1, 'first').pushed(v2, 'second');
      final (back, label, undone) = history.undone(v3)!;
      expect((back, label), (v2, 'second'));
      final (again, _, redone) = undone.redone(back)!;
      expect(again, same(v3));
      expect(redone.undo.length, 2);
      expect(undone.pushed(v2, 'other').redo, isEmpty);
      expect(const DocHistory().undone(v1), isNull);
    });

    test('the oldest step goes past the limit', () {
      var history = const DocHistory();
      for (var i = 0; i <= DocHistory.limit; i++) {
        history = history.pushed(titled('v$i'), 'step $i');
      }
      expect(history.undo.length, DocHistory.limit);
      expect(history.undo.first.$2, 'step 1');
    });
  });

  test('deleting a document takes it out of its history and of every chat at once', () {
    final demo = demoWorkspace();
    final id = demo.threads[demoPolishThreadId]!.documentId!;
    final edited = demo.committing(demo.documents[id]!, const DocHistory().pushed(demo.documents[id]!, 'x'));
    final after = edited.removingDocument(id);
    expect(after.documents.containsKey(id), isFalse);
    expect(after.histories.containsKey(id), isFalse);
    expect(after.threads.values.where((t) => t.documentId == id || t.tabs.contains(PanelTab.preview(id))), isEmpty);
  });

  test('a document without a project lands in the project of the chat it opens in', () {
    final demo = demoWorkspace();
    final chat = demo.threads[demoOnePagerThreadId]!;
    final doc = PaperDocument.fromJson({...titled('Nuovo').toJson(), 'id': 'new', 'projectId': ''});
    final after = demo.addingDocument(doc, thread: chat);
    expect(after.documents['new']!.projectId, chat.projectId);
    expect(after.threads[chat.id]!.activeTab, const PanelTab.preview('new'));
    expect(demo.changingThread('missing', (t) => t), same(demo));
  });

  test('the index reads back as it was written', () {
    final demo = demoWorkspace().addingThread(newChat(id: 'c9', projectId: demoProjectId, title: 'Ricorso'));
    final json = WorkspaceRepository.toJson(demo);
    final docs = {for (final d in demo.documents.values) d.id: d.toJson()};
    final back = WorkspaceRepository.fromJson(json, (id) => docs[id])!;
    expect(back.documents.keys, demo.documents.keys);
    expect(back.threads.keys, demo.threads.keys);
    expect(back.activeThreadId, 'c9');
    expect(WorkspaceRepository.toJson(back), json);
  });

  test('each file on disk has one owner', () {
    // Two writers of one file is how a deleted chat comes back, or a save undoes another.
    final owners = {
      RegExp(r'\b_?store\??\.(readChat|writeChat|deleteChat)\('): 'agent/chat_archive.dart',
      RegExp(r'\b_?store\??\.(readWorkspace|writeWorkspace|readDocument|writeDocument|deleteDocument)\('):
          'workspace/workspace_repository.dart',
    };
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      final path = file.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart') || path.endsWith('storage/local_store.dart')) continue;
      final source = file.readAsStringSync();
      for (final MapEntry(key: pattern, value: owner) in owners.entries) {
        if (pattern.hasMatch(source)) expect(path, endsWith(owner), reason: '$path touches files of $owner');
      }
    }
  });
}
