import 'dart:io';

import 'package:flutter/material.dart' show Locale, ThemeMode;
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/features/agent/agent_controller.dart';
import 'package:paper_agent/features/document/data/doc_templates.dart';
import 'package:paper_agent/features/document/render/page_images.dart';
import 'package:paper_agent/features/storage/local_store.dart';
import 'package:paper_agent/features/workspace/ui_state.dart';
import 'package:paper_agent/features/workspace/workspace_state.dart';
import 'package:paper_agent/l10n/app_localizations.dart';

import 'demo_fixture.dart';

/// What the lawyer did is still there when the app opens again (docs/adr/ADR-0001-dati-locali.md).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('pa_store'));
  tearDown(() => dir.delete(recursive: true));

  ProviderContainer launch({bool demo = false}) => ProviderContainer(
    overrides: [
      localStoreProvider.overrideWithValue(LocalStore(dir)),
      if (demo) ...demoOverrides,
    ],
  );

  test(
    'invalid stored schema version is quarantined rather than crashing startup',
    () {
      File('${dir.path}/workspace.json')
          .writeAsStringSync('{"version":"broken"}');
      final store = LocalStore(dir);
      expect(store.readWorkspace(), isNull);
      expect(File('${dir.path}/workspace.json').existsSync(), isFalse);
      expect(
        dir.listSync().whereType<File>().single.path,
        contains('.corrupt-'),
      );
    },
  );

  test(
    'failed writes stay pending after dismissing notice and clear on retry',
    () {
      final store = LocalStore(dir);
      final blocked = File('${dir.path}/documents')
        ..writeAsStringSync('block directory');
      expect(
        () => store.writeDocument('d', {'title': 'work'}),
        throwsA(isA<FileSystemException>()),
      );
      store.notice.value = null;
      expect(store.hasUnsavedWrites, isTrue);
      blocked.deleteSync();
      store.writeDocument('d', {'title': 'work'});
      expect(store.hasUnsavedWrites, isFalse);
      expect(store.readDocument('d')?['title'], 'work');
    },
  );

  test(
    'a new chat, its messages and the open chat survive a restart',
    () async {
      final first = launch();
      final ws = first.read(workspaceProvider.notifier);
      final agent = first.read(agentProvider.notifier);
      final project = ws.createProject('Pratica Rossi');
      final thread = ws.createThread(
        projectId: project.id,
        title: 'Opposizione al decreto',
      );
      agent.chatFor(thread.id)
        ..addMessage(
          ChatMessage(
            text: 'Analizza il decreto allegato',
            user: AgentController.user,
            createdAt: DateTime(2026, 10, 5, 10),
            customProperties: {'id': 'u1'},
          ),
        )
        ..addMessage(
          ChatMessage(
            text: 'Il decreto n. 1234/2026 ingiunge 27.950,00 €.',
            user: AgentController.agent,
            createdAt: DateTime(2026, 10, 5, 10, 1),
            isMarkdown: true,
            customProperties: {'id': 'a1', 'isStreaming': false},
          ),
        );
      ws.renameThread(thread.id, 'Opposizione D.I. Rossi');
      ws.flush();
      agent.flush();
      first.dispose();

      final second = launch();
      final state = second.read(workspaceProvider);
      expect(state.projects.map((p) => p.name), contains('Pratica Rossi'));
      expect(state.threads[thread.id]?.title, 'Opposizione D.I. Rossi');
      expect(state.activeThreadId, thread.id);
      final messages = second
          .read(agentProvider.notifier)
          .chatFor(thread.id)
          .messages;
      expect(messages.map((m) => m.text).toSet(), {
        'Analizza il decreto allegato',
        'Il decreto n. 1234/2026 ingiunge 27.950,00 €.',
      });
      second.dispose();
    },
  );

  test("a chat's document cards find their version after a restart", () async {
    final first = launch(demo: true);
    seedDemoChat(first);
    final ws = first.read(workspaceProvider.notifier)
      ..touchThread(demoProposalThreadId); // the lawyer wrote in it
    final agent = first.read(agentProvider.notifier);
    final demo = agent.chatFor(demoProposalThreadId).messages.length;
    expect(demo, greaterThan(0));
    ws.flush();
    await Future<void>.delayed(
      const Duration(milliseconds: 400),
    ); // the chat's own save timer
    agent.flush();
    first.dispose();

    final second = launch();
    final messages = second
        .read(agentProvider.notifier)
        .chatFor(demoProposalThreadId)
        .messages;
    expect(messages.length, demo);
    final snapshot = messages
        .map((m) => (m.customProperties?['resultData'] as Map?)?['snapshot'])
        .whereType<String>()
        .first;
    expect(second.read(snapshotStoreProvider).get(snapshot), isNotNull);
    second.dispose();
  });

  /// A first session with real work: a project, a chat with a message, a new document; saved twice, so the
  /// index has the copy the save before kept.
  ({String project, String thread, String document}) work() {
    final container = launch();
    final ws = container.read(workspaceProvider.notifier);
    final agent = container.read(agentProvider.notifier);
    final project = ws.createProject('Pratica Rossi');
    final thread = ws.createThread(
      projectId: project.id,
      title: 'Opposizione al decreto',
    );
    agent
        .chatFor(thread.id)
        .addMessage(
          ChatMessage(
            text: 'Analizza il decreto allegato',
            user: AgentController.user,
            createdAt: DateTime(2026, 10, 5, 10),
            customProperties: {'id': 'u1'},
          ),
        );
    final document = ws
        .createFromTemplate(docTemplates.first, projectId: project.id)
        .id;
    ws.flush();
    ws.renameThread(thread.id, 'Opposizione D.I. Rossi');
    ws.flush();
    agent.flush();
    container.dispose();
    return (project: project.id, thread: thread.id, document: document);
  }

  test(
    'a damaged index comes back from the save before, not as a first launch',
    () {
      final saved = work();
      File('${dir.path}/workspace.json').writeAsStringSync('{"projects": [');

      final container = launch();
      final state = container.read(workspaceProvider);
      expect(state.projects.map((p) => p.id), contains(saved.project));
      expect(state.threads, contains(saved.thread));
      expect(
        container
            .read(localStoreProvider)!
            .notice
            .value
            ?.text(lookupAppLocalizations(const Locale('it'))),
        contains('ripristinato'),
      );
      expect(
        dir.listSync().where((f) => f.path.contains('workspace.json.corrupt-')),
        hasLength(1),
      );
      container.dispose();
    },
  );

  test('with the index and its copy both lost, the documents and chats are recovered from their files', () {
    final saved = work();
    File('${dir.path}/workspace.json').writeAsStringSync('not json');
    File('${dir.path}/workspace.json.bak').deleteSync();

    final container = launch();
    final state = container.read(workspaceProvider);
    expect(state.projects.single.name, WorkspaceNotifier.recoveredProject);
    expect(state.documents, contains(saved.document));
    expect(state.threads, contains(saved.thread));
    final messages = container
        .read(agentProvider.notifier)
        .chatFor(saved.thread)
        .messages;
    expect(messages.map((m) => m.text), ['Analizza il decreto allegato']);
    expect(
      container
          .read(localStoreProvider)!
          .notice
          .value
          ?.text(lookupAppLocalizations(const Locale('it'))),
      contains('recuperato'),
    );
    container.dispose();
  });

  test('work saved by a newer app is shown but never written over', () {
    work();
    final index = File('${dir.path}/workspace.json');
    index.writeAsStringSync(
      index.readAsStringSync().replaceFirst('"version":1', '"version":99'),
    );
    final before = index.readAsStringSync();

    final container = launch();
    final store = container.read(localStoreProvider)!;
    final ws = container.read(workspaceProvider.notifier);
    expect(store.readOnly, isTrue);
    expect(
      store.notice.value?.text(lookupAppLocalizations(const Locale('it'))),
      contains('versione più recente'),
    );
    ws.createProject('Non deve finire su disco');
    ws.flush();
    expect(index.readAsStringSync(), before);
    container.dispose();
  });

  for (final (what, damaged) in [
    ('messages that are not a list', '{"version":1,"messages":{"a":1}}'),
    (
      'a message whose text is not text',
      '{"version":1,"messages":[{"text":5,"user":"lawyer"}]}',
    ),
    (
      'a turn whose tool count is not a number',
      '{"version":1,"turns":[{"startedAt":"2026-10-05T10:00:00","tools":"x"}]}',
    ),
  ]) {
    test(
      'a chat file with $what is kept for a human, and the other chats still open',
      () async {
        final first = launch();
        final ws = first.read(workspaceProvider.notifier);
        final agent = first.read(agentProvider.notifier);
        final project = ws.state.projects.first.id;
        // The damaged chat comes first, so the one after it is restored only if the damage stops at its own chat.
        final bad = ws.createThread(projectId: project, title: 'Danneggiata');
        final good = ws.createThread(projectId: project, title: 'Integra');
        for (final thread in [bad, good]) {
          agent
              .chatFor(thread.id)
              .addMessage(
                ChatMessage(
                  text: 'Messaggio di ${thread.title}',
                  user: AgentController.user,
                  createdAt: DateTime(2026, 10, 5),
                  customProperties: {'id': 'u-${thread.id}'},
                ),
              );
        }
        ws.flush();
        agent.flush();
        first.dispose();
        File('${dir.path}/chats/${bad.id}.json').writeAsStringSync(damaged);

        final second = launch();
        expect(
          () => second.read(agentProvider),
          returnsNormally,
          reason: 'one damaged chat does not stop the agent',
        );
        final restored = second.read(agentProvider.notifier);
        expect(restored.chatFor(good.id).messages.map((m) => m.text), [
          'Messaggio di Integra',
        ]);
        expect(restored.chatFor(bad.id).messages, isEmpty);
        expect(
          Directory('${dir.path}/chats')
              .listSync()
              .where((f) => f.path.contains('${bad.id}.json.corrupt-')),
          hasLength(1),
          reason: 'the damaged file is set aside, never written over',
        );
        second.dispose();
      },
    );
  }

  test('a deleted chat stays deleted', () async {
    final first = launch();
    final ws = first.read(workspaceProvider.notifier);
    final agent = first.read(agentProvider.notifier);
    final thread = ws.createThread(
      projectId: ws.state.projects.first.id,
      title: 'Da cancellare',
    );
    agent
        .chatFor(thread.id)
        .addMessage(
          ChatMessage(
            text: 'prova',
            user: AgentController.user,
            createdAt: DateTime(2026, 10, 5),
            customProperties: {'id': 'u1'},
          ),
        );
    agent.flush();
    agent.deleteChat(thread.id);
    ws.flush();
    first.dispose();

    final second = launch();
    expect(
      second.read(workspaceProvider).threads.containsKey(thread.id),
      isFalse,
    );
    expect(File('${dir.path}/chats/${thread.id}.json').existsSync(), isFalse);
    second.dispose();
  });

  /// What an antivirus or an indexer does to a file it is scanning: holds it so that reading it fails, until
  /// the returned function lets it go. Only Windows stops a read on a lock; elsewhere locks are advisory.
  void Function() hold(File file) {
    final held = file.openSync(mode: FileMode.append)
      ..lockSync(FileLock.exclusive);
    var released = false;
    void release() {
      if (released) return;
      released = true;
      held.unlockSync();
      held.closeSync();
    }

    addTearDown(release);
    return release;
  }

  final onlyWindows = Platform.isWindows
      ? false
      : 'only Windows stops a read on a lock';

  test('an index another program holds at launch is neither set aside nor written over', () {
    final saved = work();
    final index = File('${dir.path}/workspace.json');
    final before = index.readAsStringSync();
    final release = hold(index);

    final container = launch();
    final ws = container.read(workspaceProvider.notifier);
    expect(
      ws.state.projects.map((p) => p.id),
      contains(saved.project),
      reason: 'the copy the save before kept',
    );
    final store = container.read(localStoreProvider)!;
    expect(
      store.readOnly,
      isTrue,
      reason: 'nothing is written over a file that was not read',
    );
    expect(
      store.notice.value?.text(lookupAppLocalizations(const Locale('it'))),
      contains('Non riesco a leggere'),
    );
    ws.createProject('Non deve finire su disco');
    ws.flush();
    release();
    expect(index.readAsStringSync(), before);
    expect(dir.listSync().where((f) => f.path.contains('.corrupt-')), isEmpty);
    container.dispose();
  }, skip: onlyWindows);

  test('a chat another program holds at launch is neither set aside nor written over', () {
    final saved = work();
    final chat = File('${dir.path}/chats/${saved.thread}.json');
    final before = chat.readAsStringSync();
    final release = hold(chat);

    final container = launch();
    final agent = container.read(agentProvider.notifier);
    expect(agent.chatFor(saved.thread).messages, isEmpty);
    agent
        .chatFor(saved.thread)
        .addMessage(
          ChatMessage(
            text: 'scritta sopra la conversazione',
            user: AgentController.user,
            createdAt: DateTime(2026, 10, 6),
            customProperties: {'id': 'u2'},
          ),
        );
    agent.flush();
    container.read(workspaceProvider.notifier).flush();
    release();
    expect(chat.readAsStringSync(), before);
    expect(
      Directory('${dir.path}/chats')
          .listSync()
          .where((f) => f.path.contains('.corrupt-')),
      isEmpty,
    );
    container.dispose();
  }, skip: onlyWindows);

  test('a file that is not text is damage, set aside, not a file held by another program', () {
    File('${dir.path}/preferences.json')
        .writeAsBytesSync([0x7b, 0xff, 0xfe, 0x7d]);
    final container = launch();
    expect(container.read(uiProvider).themeMode, ThemeMode.dark);
    expect(container.read(localStoreProvider)!.readOnly, isFalse);
    expect(
      dir.listSync().where((f) => f.path.contains('preferences.json.corrupt-')),
      hasLength(1),
    );
    container.dispose();
  });

  test('a chat whose file cannot be deleted still leaves the workspace, and the lawyer is told', () {
    final saved = work();
    final chat = File('${dir.path}/chats/${saved.thread}.json');
    // A file the system refuses to delete: read-only on Windows, in a folder that cannot change elsewhere.
    void protect(bool on) => Platform.isWindows
        ? Process.runSync('attrib', [on ? '+R' : '-R', chat.path])
        : Process.runSync('chmod', [on ? 'a-w' : 'u+w', chat.parent.path]);
    protect(true);
    addTearDown(() => protect(false));

    final container = launch();
    final agent = container.read(agentProvider.notifier);
    agent.chatFor(saved.thread); // restored
    expect(() => agent.deleteChat(saved.thread), returnsNormally);
    expect(
      container.read(workspaceProvider).threads.containsKey(saved.thread),
      isFalse,
    );
    expect(
      container.read(localStoreProvider)!.notice.value,
      isA<SaveFailedNotice>(),
    );
    container.dispose();
  });

  test(
    'the theme survives a restart and unsupported language stays Italian',
    () {
      final first = launch();
      first.read(uiProvider.notifier)
        ..setThemeMode(ThemeMode.dark)
        ..setLocale(const Locale('en'));
      first.dispose();

      final ui = launch().read(uiProvider);
      expect(ui.themeMode, ThemeMode.dark);
      expect(ui.locale, const Locale('it'));
    },
  );

  for (final (what, text) in [
    (
      'a theme and a language this app does not know',
      '{"version":1,"themeMode":"sepia","locale":"xx"}',
    ),
    ('values that are not text', '{"version":1,"themeMode":2,"locale":["en"]}'),
    ('no JSON at all', 'tema scuro'),
  ]) {
    test('preferences with $what open on the defaults', () {
      File('${dir.path}/preferences.json').writeAsStringSync(text);
      final ui = launch().read(uiProvider);
      expect(ui.themeMode, ThemeMode.dark);
      expect(ui.locale, UiState.defaultLocale);
    });
  }
}
