import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart'
    hide AgentRequest, AgentState;
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/features/agent/case_file_uploads.dart';
import 'package:paper_agent/features/agent/chat_archive.dart';
import 'package:paper_agent/features/agent/chat_cards.dart';
import 'package:paper_agent/features/agent/data/mock_agent_client.dart';
import 'package:paper_agent/features/agent/domain/agent_protocol.dart';
import 'package:paper_agent/features/agent/presentation/ui_components.dart';
import 'package:paper_agent/features/agent/run_stream.dart';
import 'package:paper_agent/l10n/l10n.dart';

/// The units a turn is made of: the events read in order, the streamed reply, the uploads, the saved chat.
void main() {
  test('events are handled one at a time, and nothing after a stop', () async {
    final events = StreamController<AgentEvent>();
    final seen = <String>[];
    final failures = <Object>[];
    final gate = Completer<void>();
    final run = RunStream(
      events.stream,
      onEvent: (e) async {
        if (e case AgentTextDelta(:final text)) {
          seen.add('start $text');
          if (text == 'a') {
            await gate.future; // a tool call the next event must wait for
          }
          seen.add('end $text');
        }
      },
      onError: failures.add,
    );
    events
      ..add(const AgentTextDelta('a'))
      ..add(const AgentTextDelta('b'));
    await pumpEventQueue();
    expect(seen, ['start a']);
    gate.complete();
    await pumpEventQueue();
    expect(seen, ['start a', 'end a', 'start b', 'end b']);

    run.stop();
    events.addError(StateError('late'));
    await run.done;
    await pumpEventQueue();
    expect(run.stopped, isTrue);
    expect(failures, isEmpty);
    await events.close();
  });

  test(
    'a handler that throws ends the run and reports the error, once',
    () async {
      final events = StreamController<AgentEvent>();
      final seen = <String>[];
      final failures = <Object>[];
      final run = RunStream(
        events.stream,
        onEvent: (e) async {
          if (e case AgentTextDelta(:final text)) {
            if (text == 'bad') throw StateError('card');
            seen.add(text);
          }
        },
        onError: failures.add,
      );
      events
        ..add(const AgentTextDelta('a'))
        ..add(const AgentTextDelta('bad'))
        ..add(const AgentTextDelta('c'));
      await run.done;
      await pumpEventQueue();
      expect(seen, ['a']);
      expect(failures.single, isA<StateError>());
      expect(run.stopped, isTrue);
      await events.close();
    },
  );

  test('a streamed reply is one message, finished when closed', () {
    final chat = ChatMessagesController();
    addTearDown(chat.dispose);
    final closed = <String>[];
    final reply = StreamedReply(chat, ChatClock(), closed.add)
      ..add('Il termine ')
      ..add('è scaduto.');
    expect(chat.messages.single.text, 'Il termine è scaduto.');
    expect(chat.messages.single.customProperties?['isStreaming'], isTrue);
    reply
      ..close()
      ..close();
    expect(chat.messages.single.customProperties?['isStreaming'], isFalse);
    expect(closed, ['Il termine è scaduto.']);
  });

  test('message times strictly increase, and follow what was read back', () {
    final clock = ChatClock();
    final future = DateTime.now().add(const Duration(days: 1));
    clock.saw(future);
    final a = clock.stamp(), b = clock.stamp();
    expect(a.isAfter(future) && b.isAfter(a), isTrue);
    expect(clock.id('u'), isNot(clock.id('u')));
  });

  test('an upload goes uploading then ready, and only a file it added leaves with its chip', () async {
    final uploads = CaseFileUploads();
    final shown = <AttachmentStatus>[];
    final logged = <String>[];
    final file = AgentAttachment(
      name: 'decreto.pdf',
      mimeType: 'application/pdf',
      bytes: Uint8List(1),
    );
    final client = _CaseFile({
      'decreto.pdf': const AttachmentCard(
        name: 'decreto.pdf',
        pages: 2,
        isNew: true,
      ),
      'perizia.pdf': const AttachmentCard(name: 'perizia.pdf', pages: 1),
    });
    final l10n = lookupAppLocalizations(const Locale('it'));
    uploads
      ..upload(
        client,
        's1',
        file,
        l10n: l10n,
        show: (a) => shown.add(a.status),
        log: logged.add,
      )
      ..upload(
        client,
        's1',
        AgentAttachment(
          name: 'perizia.pdf',
          mimeType: 'application/pdf',
          bytes: Uint8List(1),
        ),
        l10n: l10n,
        show: (_) {},
        log: (_) {},
      );
    expect(uploads.busy, isTrue);
    await uploads.settled();
    await pumpEventQueue();
    expect(shown, [AttachmentStatus.uploading, AttachmentStatus.ready]);
    expect(logged, ['decreto.pdf: 2 pagine']);
    expect(uploads.busy, isFalse);
    expect(
      (uploads.release('decreto.pdf'), uploads.release('perizia.pdf')),
      (true, false),
    );
  });

  test(
    'a saved chat drops what cannot be answered or redrawn after a restart',
    () {
      final pending = ChatCards.approval('ok1', DateTime(2026, 10, 6), {
        'title': 'Delete page 2',
        'status': 'pending',
      });
      final streaming = ChatCards.reply(
        'a1',
        DateTime(2026, 10, 6),
        'Testo',
        streaming: true,
      );
      final json = ChatArchive.messageToJson(pending)!;
      expect(
        (json['props'] as Map)['resultData'],
        containsPair('status', 'expired'),
      );
      expect(
        (ChatArchive.messageToJson(streaming)!['props'] as Map).containsKey(
          'isStreaming',
        ),
        isFalse,
      );
      final back = ChatArchive.messageFromJson(json);
      expect(
        (back.user.id, back.customProperties?['resultKind']),
        (paperAgent.id, UiComponents.approval),
      );
    },
  );

  test('the controller keeps no widget state', () {
    final source = File('lib/features/agent/agent_controller.dart')
        .readAsStringSync();
    expect(source, isNot(matches(RegExp(r'FocusNode|TextEditingController'))));
  });

  test('uploads across chats use at most two slots and cancelled queued files never upload', () async {
    final client = _SlowCaseFile();
    final queues = [CaseFileUploads(), CaseFileUploads(), CaseFileUploads()];
    final l = lookupAppLocalizations(const Locale('it'));
    final cancelled = AgentAttachment(
      name: 'cancelled.pdf',
      mimeType: 'application/pdf',
      bytes: Uint8List(1),
    );
    for (var n = 0; n < 3; n++) {
      queues[n].upload(
        client,
        's$n',
        AgentAttachment(
          name: '$n.pdf',
          mimeType: 'application/pdf',
          bytes: Uint8List(1),
        ),
        l10n: l,
        show: (_) {},
        log: (_) {},
      );
    }
    queues.first.upload(
      client,
      's0',
      cancelled,
      l10n: l,
      show: (_) {},
      log: (_) {},
    );
    queues.first.cancel(cancelled);
    await Future.wait(queues.map((q) => q.settled()));
    expect(client.peak, 2);
    expect(client.names, hasLength(3));
    expect(client.names, isNot(contains('cancelled.pdf')));
  });
}

class _SlowCaseFile extends MockAgentClient {
  int active = 0, peak = 0;
  final names = <String>[];
  @override
  Future<AttachmentCard?> uploadAttachment(
    String sessionId,
    AgentAttachment attachment,
  ) async {
    active++;
    if (active > peak) peak = active;
    names.add(attachment.name);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    active--;
    return AttachmentCard(name: attachment.name, pages: 1, isNew: true);
  }
}

class _CaseFile extends MockAgentClient {
  _CaseFile(this.cards);

  final Map<String, AttachmentCard> cards;

  @override
  Future<AttachmentCard?> uploadAttachment(
    String sessionId,
    AgentAttachment attachment,
  ) async => cards[attachment.name];
}
