import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daylex/features/agent/agent_controller.dart';
import 'package:daylex/features/agent/attachment_files.dart';
import 'package:daylex/features/agent/domain/agent_protocol.dart';
import 'package:daylex/l10n/l10n.dart';
import 'package:daylex/ui/chat/file_drop.dart';

/// Dropped files and folders become the chat's attachments; what is left out is reported, by reason, not lost.
void main() {
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('pa_drop');
    addTearDown(() => dir.delete(recursive: true));
  });

  Future<File> write(String name, int size) =>
      File('${dir.path}/$name').writeAsBytes(List.filled(size, 1));

  test(
    'a dropped folder adds every readable file in it, in name order',
    () async {
      final sub = await Directory('${dir.path}/allegati').create();
      await File('${dir.path}/b_decreto.pdf').writeAsBytes([1]);
      await File('${dir.path}/a_ricorso.pdf.p7m').writeAsBytes([2]);
      await File('${sub.path}/perizia.docx').writeAsBytes([3]);
      await File('${dir.path}/archivio.rar').writeAsBytes([4]);
      final note = await File('${Directory.systemTemp.path}/pa_note.txt')
          .writeAsBytes([5]);
      addTearDown(note.delete);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final agent = container.read(agentProvider.notifier);
      final left = await agent.addFiles(AgentController.draftId, [
        XFile(dir.path),
        XFile(note.path),
      ]);

      final names = container
          .read(agentProvider)
          .of(AgentController.draftId)
          .attachments
          .map((a) => a.name);
      expect(names, [
        'a_ricorso.pdf.p7m',
        'perizia.docx',
        'b_decreto.pdf',
        'pa_note.txt',
      ]);
      expect(left.wrongType, ['archivio.rar']);
      expect(left.tooLarge, isEmpty);
      expect(left.unreadable, isEmpty);
    },
  );

  test('a file the system will not give is reported, and the others are still attached', () async {
    final good = await write('ricorso.pdf', 3);
    final gone = XFile('${dir.path}/sparito.pdf');

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final left = await container.read(agentProvider.notifier).addFiles(
      AgentController.draftId,
      [gone, XFile(good.path)],
    );

    expect(
      container
          .read(agentProvider)
          .of(AgentController.draftId)
          .attachments
          .map((a) => a.name),
      ['ricorso.pdf'],
    );
    expect(left.unreadable, ['sparito.pdf']);
  });

  test('files past the room are left out without being read, and the room is shared', () async {
    final a = await write('a.pdf', 4);
    final b = await write('b.pdf', 4);
    final c = await write('c.pdf', 2);

    final (picked, left) = await readAttachable([
      XFile(a.path),
      XFile(b.path),
      XFile(c.path),
    ], room: 7);

    expect(picked.map((x) => x.name), ['a.pdf', 'c.pdf']);
    expect(left.tooLarge, ['b.pdf']);
  });

  test(
    '100 disk documents exceeding the old aggregate limit stay lazy',
    () async {
      final files = <XFile>[];
      for (var i = 0; i < 100; i++) {
        final f = File('${dir.path}/case-$i.pdf');
        final raf = await f.open(mode: FileMode.write);
        await raf.truncate(2 * 1024 * 1024);
        await raf.close();
        files.add(XFile(f.path));
      }
      final (picked, left) = await readAttachable(files, deferBytes: true);
      expect(picked.length, 100);
      expect(left.isEmpty, isTrue);
      expect(
        picked.every((f) => f.bytes.isEmpty && f.localPath != null),
        isTrue,
      );
      final ready = picked.first.withStatus(AttachmentStatus.ready);
      expect(ready.sameSelection(picked.first), isTrue);
    },
  );

  test('a file on disk past what the chat holds in memory goes in chunks; one held in memory travels whole', () async {
    final first = await write('primo.pdf', 1);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final agent = container.read(agentProvider.notifier);
    await agent.addFiles(AgentController.draftId, [XFile(first.path)]);

    // A scanned court file larger than everything the chat may hold in memory: sent from disk, never read here.
    Future<File> sized(String name, int size) async {
      final file = File('${dir.path}/$name');
      final raf = await file.open(mode: FileMode.write);
      await raf.truncate(size);
      await raf.close();
      return file;
    }

    final big = await sized('grande.pdf', maxAttachmentBytes);
    expect((await agent.addFiles(AgentController.draftId, [XFile(big.path)])).isEmpty, isTrue);
    final held = container.read(agentProvider).of(AgentController.draftId).attachments;
    expect(held.map((a) => a.name), ['primo.pdf', 'grande.pdf']);
    expect(held.last.bytes, isEmpty);
    expect(held.last.localPath, big.path);

    // In memory (the web, a file with no path) it goes base64 inside one request, so at most maxInlineFileBytes.
    final inline = await sized('in-memoria.pdf', maxInlineFileBytes + 1);
    final (picked, left) = await readAttachable([XFile(inline.path)]);
    expect(picked, isEmpty);
    expect(left.tooLarge, ['in-memoria.pdf']);
  });

  testWidgets('what was left out is told in one message, one line per reason', (
    tester,
  ) async {
    final l = lookupAppLocalizations(const Locale('it'));
    final key = GlobalKey<ScaffoldMessengerState>();
    await tester.pumpWidget(
      MaterialApp(scaffoldMessengerKey: key, home: const Scaffold()),
    );

    showLeftOut(
      key.currentState,
      l,
      const LeftOut(wrongType: ['archivio.rar'], unreadable: ['bloccato.pdf']),
    );
    await tester.pump();

    final text = tester.widget<Text>(
      find.descendant(of: find.byType(SnackBar), matching: find.byType(Text)),
    );
    expect(text.data!.split('\n'), hasLength(2));
    expect(text.data, contains('archivio.rar'));
    expect(text.data, contains('bloccato.pdf'));
  });
}
