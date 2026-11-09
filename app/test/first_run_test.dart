import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/features/agent/agent_controller.dart';
import 'package:paper_agent/features/document/model/document.dart';
import 'package:paper_agent/features/storage/local_store.dart';
import 'package:paper_agent/features/workspace/chat_thread.dart';
import 'package:paper_agent/features/workspace/legacy_demo.dart';
import 'package:paper_agent/features/workspace/workspace_repository.dart';
import 'package:paper_agent/features/workspace/workspace_state.dart';

import 'demo_fixture.dart';

/// A first launch opens on the lawyer's work only, and the demo older versions saved goes away unless it was
/// worked on (docs/adr/ADR-0002-primo-avvio.md).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('pa_first_run'));
  tearDown(() => dir.delete(recursive: true));

  ProviderContainer launch() => ProviderContainer(overrides: [
    localStoreProvider.overrideWithValue(LocalStore(dir)),
  ]);

  bool onDisk(String relative) => File('${dir.path}/$relative').existsSync();

  /// What an older version wrote on its first launch, its chats with their messages, plus [extra] changes.
  void saveLegacyDemo([WorkspaceState Function(WorkspaceState demo)? extra]) {
    final store = LocalStore(dir);
    final demo = demoWorkspace();
    WorkspaceRepository(store).save(extra == null ? demo : extra(demo));
    for (final id in demo.threads.keys) {
      store.writeChat(id, {
        'messages': [{'text': 'seed', 'createdAt': '2026-10-01T10:00:00.000', 'props': {'id': 'seed1'}}],
      });
    }
  }

  void expectEmptyFirstRun(WorkspaceState s) {
    expect(s.projects, hasLength(1));
    expect(s.projects.single.id, isNot(anyOf(demoProjectId, internalProjectId)));
    expect(s.documents, isEmpty);
    expect(s.threads, isEmpty);
    expect(s.activeThreadId, isNull);
  }

  test('a first launch opens on one empty project: no demo chats, documents or messages', () {
    final container = launch();
    expectEmptyFirstRun(container.read(workspaceProvider));
    expect(container.read(agentProvider.notifier).chatFor(demoProposalThreadId).messages, isEmpty);
    container.read(workspaceProvider.notifier).flush();
    container.dispose();

    final again = launch();
    expect(again.read(workspaceProvider).projects, hasLength(1)); // saved, not created a second time
    again.dispose();
  });

  test('without a data folder the app opens empty too', () {
    final container = ProviderContainer();
    expectEmptyFirstRun(container.read(workspaceProvider));
    container.dispose();
  });

  test('a demo saved by an older version and never touched goes away, files included', () {
    saveLegacyDemo();
    final container = launch();
    expectEmptyFirstRun(container.read(workspaceProvider));
    container.read(agentProvider); // the app starts its chats with the workspace: they own the chat files
    container.read(workspaceProvider.notifier).flush();
    container.dispose();
    for (final id in [demoProposalDocumentId, demoOnePagerDocumentId]) {
      expect(onDisk('documents/$id.json'), isFalse, reason: id);
    }
    for (final id in [demoProposalThreadId, demoPolishThreadId, demoOnePagerThreadId]) {
      expect(onDisk('chats/$id.json'), isFalse, reason: id);
    }
  });

  test('what the lawyer worked on in the demo stays, and so does all of their own work', () {
    final later = DateTime.now().add(const Duration(minutes: 5));
    saveLegacyDemo((demo) {
      final polish = demo.threads[demoPolishThreadId]!.copyWith(updatedAt: later);
      final own = ChatThread(id: 'own-chat', projectId: 'own-project', title: 'Opposizione D.I. Rossi',
          createdAt: later, updatedAt: later);
      return WorkspaceState(
        projects: [...demo.projects, const Project(id: 'own-project', name: 'Pratica Rossi')],
        documents: demo.documents,
        threads: {...demo.threads, polish.id: polish, own.id: own},
        activeThreadId: demoProposalThreadId,
      );
    });

    final container = launch();
    final s = container.read(workspaceProvider);
    expect(s.projects.map((p) => p.id), [demoProjectId, 'own-project']);
    expect(s.threads.keys, unorderedEquals([demoPolishThreadId, 'own-chat']));
    expect(s.documents.keys, [demoProposalDocumentId]); // the chat kept works on it
    expect(s.activeThreadId, isNull); // the open chat went away with the demo
    expect(container.read(agentProvider.notifier).chatFor(demoPolishThreadId).messages, isNotEmpty);
    container.read(workspaceProvider.notifier).flush();
    container.dispose();
    expect(onDisk('chats/$demoPolishThreadId.json'), isTrue);
    expect(onDisk('chats/$demoProposalThreadId.json'), isFalse);
    expect(onDisk('documents/$demoOnePagerDocumentId.json'), isFalse);
  });

  test('an edited demo document keeps its project', () {
    saveLegacyDemo((demo) {
      final onePager = demo.documents[demoOnePagerDocumentId]!;
      final edited = onePager.copyWith(
          metadata: onePager.metadata.copyWith(updatedAt: DateTime.now().add(const Duration(minutes: 1))));
      return WorkspaceState(
        projects: demo.projects,
        documents: {...demo.documents, edited.id: edited},
        threads: demo.threads,
        activeThreadId: demo.activeThreadId,
      );
    });

    final container = launch();
    final s = container.read(workspaceProvider);
    expect(s.projects.map((p) => p.id), [internalProjectId]);
    expect(s.documents.keys, [demoOnePagerDocumentId]);
    expect(s.threads, isEmpty);
    container.dispose();
  });

  test('a demo chat or project the lawyer only renamed stays', () {
    saveLegacyDemo((demo) => WorkspaceState(
      projects: [
        for (final p in demo.projects) p.id == internalProjectId ? Project(id: p.id, name: 'Studio Bianchi', color: p.color) : p,
      ],
      documents: demo.documents,
      threads: {
        ...demo.threads,
        demoProposalThreadId: demo.threads[demoProposalThreadId]!.copyWith(title: 'Bozza parere Rossi'),
      },
      activeThreadId: demo.activeThreadId,
    ));

    final container = launch();
    final s = container.read(workspaceProvider);
    expect(s.projects.map((p) => p.id), [demoProjectId, internalProjectId]);
    expect(s.threads.keys, [demoProposalThreadId]);
    expect(s.documents.keys, [demoProposalDocumentId]);
    container.dispose();
  });

  test('every id and name of the demo fixture is one the app recognises on disk', () {
    final demo = demoWorkspace();
    expect(legacyDemoProjects, {for (final p in demo.projects) p.id: p.name});
    expect(legacyDemoDocumentIds, containsAll(demo.documents.keys));
    expect(legacyDemoThreads, {for (final t in demo.threads.values) t.id: t.title});
  });
}
