import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart'
    hide AgentRequest, AgentState;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../l10n/labels.dart';
import '../document/model/document.dart';
import '../document/render/page_images.dart';
import '../storage/local_store.dart';
import '../workspace/chat_thread.dart';
import '../workspace/ui_state.dart';
import '../workspace/viewer_state.dart';
import '../workspace/workspace_state.dart';
import 'approvals.dart';
import 'attachment_files.dart';
import 'case_file_uploads.dart';
import 'chat_archive.dart';
import 'chat_cards.dart';
import 'data/http_agent_client.dart';
import 'data/mock_agent_client.dart';
import 'domain/agent_protocol.dart';
import 'domain/document_tools.dart';
import 'history.dart';
import 'navigation.dart';
import 'presentation/ui_components.dart';
import 'presentation/conversation_presentation.dart';
import 'run_stream.dart';
import 'session_state.dart';
import 'thread_tool_host.dart';
import 'tool_runner.dart';
import 'turn_tracker.dart';
import 'turn_progress.dart';
import 'whatsapp_bridge.dart';

export 'attachment_files.dart' show LeftOut;
export 'session_state.dart';

/// The self-hosted agent server (see [AgentServerConfig]). The scripted mock
/// only in tests or when asked for (`PAPERAGENT_MOCK=1`): a missing or broken
/// configuration is said, never covered by the mock's answers.
final agentClientProvider = Provider<AgentClient>((ref) {
  final env = Platform.environment;
  if (!kReleaseMode && (env['FLUTTER_TEST'] == 'true' || env['PAPERAGENT_MOCK'] == '1')) {
    return MockAgentClient();
  }
  final AgentServerConfig config;
  try {
    config = AgentServerConfig.load(ref.read(l10nProvider));
  } on AgentConfigException catch (e) {
    return UnavailableAgentClient(e.message);
  }
  final client = HttpAgentClient(config, l10n: () => ref.read(l10nProvider));
  ref.onDispose(client.close);
  return client;
});

final agentProvider = NotifierProvider<AgentController, AgentState>(
  AgentController.new,
);

final sessionProvider = Provider.family<SessionState, String>(
  (ref, id) => ref.watch(agentProvider.select((s) => s.of(id))),
);

/// Controller-side objects of one chat that are not plain state.
class _Session {
  _Session(
    String id,
    ChatClock clock,
    void Function(String status, String title) onApproval,
  ) {
    approvals = Approvals(id, chat, clock, onApproval);
  }

  final chat = ChatMessagesController();
  late final Approvals approvals;

  /// Attachments being read into the case file; a send waits for them.
  final uploads = CaseFileUploads();
  RunStream? run;
  List<AgentAttachment> runAttachments = const [];

  /// The turn running now, so a stop can close its progress card.
  RunningTurn? turn;
  TurnProgress? progress;
  StreamedReply? reply;

  /// The chat is written this long after its last change (a streamed reply changes it many times).
  Timer? save;

  void dispose() {
    save?.cancel();
    run?.stop();
    chat.dispose();
  }
}

/// Bridges the chat UI, the [AgentClient] and the document tools.
///
/// The agent only emits events. This controller runs each turn: the request, the events in order (text into the
/// chat, tool calls through [ToolRunner], components as cards), the turn's record for the Review tab. It keeps one
/// session per chat so several chats can run at once; saving, uploads, approvals and the cards are their own
/// units.
class AgentController extends Notifier<AgentState> {
  static const user = lawyer;
  static const agent = paperAgent;

  /// Session key of the new-chat screen (attachments picked before sending).
  static const draftId = '_draft';

  /// What the case file reads: documents, signed copies (.p7m) and scans.
  static final attachable = attachableTypes;

  /// How long an approval card waits for the lawyer.
  static final approvalWindow = Approvals.window;

  /// The conversation so far, oldest first, as the server reads it.
  static List<AgentTurn> historyOf(Iterable<ChatMessage> messages) =>
      conversationOf(messages);

  final _sessions = <String, _Session>{};
  final _clock = ChatClock();
  late final _cards = ChatCards(_clock);
  ChatArchive? _archive;

  AppLocalizations get _l => ref.read(l10nProvider);

  @override
  AgentState build() {
    ref.onDispose(() {
      for (final s in _sessions.values) {
        s.dispose();
      }
    });
    final store = ref.read(localStoreProvider);
    _archive = store == null ? null : ChatArchive(store);
    final restored = _restoreChats();
    return AgentState(restored);
  }

  // -- sessions -----------------------------------------------------------------

  _Session _session(String id) =>
      _sessions.putIfAbsent(id, () => _watch(id, _newSession(id)));

  _Session _newSession(String id) => _Session(
    id,
    _clock,
    (status, title) => _log(id, LogKind.approval, title, {'status': status}),
  );

  /// Saves the chat a moment after each change to its messages.
  _Session _watch(String id, _Session session) {
    if (id != draftId) session.chat.addListener(() => _scheduleSave(id));
    return session;
  }

  /// Every saved chat of the workspace, read back at start: messages into their controllers, turns
  /// (the Review tab) into the returned state.
  Map<String, SessionState> _restoreChats() {
    final archive = _archive;
    if (archive == null) return const {};
    final states = <String, SessionState>{};
    final threads = ref.read(workspaceProvider).threads.keys;
    archive.deleteDroppedDemo(threads);
    for (final id in threads) {
      final saved = archive.read(id);
      if (saved == null) continue;
      final (messages, turns) = saved;
      final session = _newSession(id);
      session.chat.setMessages(messages);
      _sessions[id] = _watch(id, session);
      for (final m in messages) {
        _clock.saw(m.createdAt);
      }
      if (turns.isNotEmpty) states[id] = SessionState(turns: turns);
    }
    return states;
  }

  void _scheduleSave(String id) {
    final session = _sessions[id];
    if (session == null || _archive == null) return;
    session.save?.cancel();
    session.save = Timer(LocalStore.saveDelay, () => _saveChat(id));
  }

  void _saveChat(String id) {
    final archive = _archive;
    final session = _sessions[id];
    session?.save?.cancel();
    // A deleted chat is not written back by a save that was still pending.
    if (archive == null ||
        session == null ||
        !ref.read(workspaceProvider).threads.containsKey(id)) {
      return;
    }
    archive.write(id, session.chat.messages, _state(id).turns);
  }

  /// Writes every chat with a save still pending: the window is closing.
  void flush() {
    for (final entry in _sessions.entries) {
      // Also retry a failed timer write: its timer is no longer active.
      _saveChat(entry.key);
    }
  }

  /// Deletes a chat: its messages here and its case file on the agent server.
  void deleteChat(String threadId) {
    cancel(threadId);
    // Not disposed: the chat view may still be listening this frame. Its pending save just never runs.
    _sessions[threadId]?.save?.cancel();
    _archive?.delete(threadId);
    ref.read(workspaceProvider.notifier).deleteThread(threadId);
    // The chat is gone, so no chat log to write to; the server drops an orphan case file at its expiry anyway.
    unawaited(
      ref
          .read(agentClientProvider)
          .deleteCaseFile(threadId)
          .catchError(
            (Object e) => debugPrint(
              'PaperAgent: could not delete case file $threadId: $e',
            ),
          ),
    );
  }

  ChatMessagesController chatFor(String threadId) => _session(threadId).chat;

  SessionState _state(String id) => state.of(id);

  void _update(String id, SessionState Function(SessionState) f) =>
      state = AgentState({...state.sessions, id: f(_state(id))});

  /// The newest entries of a chat's log that are kept.
  static const _logLimit = 500;

  void _log(String id, String kind, String summary, [Object? payload]) {
    final detail = payload == null
        ? null
        : payload is String
        ? payload
        : const JsonEncoder.withIndent('  ').convert(payload);
    _update(id, (s) {
      final log = [
        ...s.log,
        AgentLogEntry(DateTime.now(), kind, summary, detail),
      ];
      return s.copyWith(
        log: log.length > _logLimit ? log.sublist(log.length - _logLimit) : log,
      );
    });
  }

  // -- attachments ----------------------------------------------------------------

  Future<LeftOut> pickAttachments(String threadId) async =>
      addFiles(threadId, await pickAttachable(_l.attachmentTypeGroup));

  /// Files picked or dropped on the window, folders opened: all of them read at once, as long as the chat's
  /// attachments stay within [maxAttachmentBytes] (they travel in one request, and sit in memory until sent).
  /// Returns what was left out, and why.
  Future<LeftOut> addFiles(String threadId, List<XFile> files) async {
    final held = _state(threadId).attachments
        .fold(0, (n, a) => n + a.bytes.length);
    final (picked, refused) = await readAttachable(
      files,
      room: maxAttachmentBytes - held,
      deferBytes: true,
      maxFiles: maxCaseDocuments - _state(threadId).attachments.length,
    );
    if (picked.isEmpty) return refused;
    _update(
      threadId,
      (s) => s.copyWith(attachments: [...s.attachments, ...picked]),
    );
    // An open chat reads them now, all at once, while the request is being written. The new-chat
    // screen has no chat yet: its files go with the first run, which reads them the same way.
    if (threadId == draftId) return refused;
    for (final a in picked) {
      _upload(threadId, a);
    }
    return refused;
  }

  void removeAttachment(String threadId, AgentAttachment a) {
    _session(threadId).uploads.cancel(a);
    final current =
        _state(threadId).attachments
            .where((x) => x.sameSelection(a))
            .firstOrNull ??
        a;
    final name = current.serverName;
    if (current.isUploaded &&
        name != null &&
        _session(threadId).uploads.release(name)) {
      unawaited(
        ref
            .read(agentClientProvider)
            .deleteAttachment(threadId, name)
            .catchError(
              (Object e) => _log(
                threadId,
                LogKind.error,
                _l.logRemoveAttachmentFailed(name, '$e'),
              ),
            ),
      );
    }
    _update(
      threadId,
      (s) => s.copyWith(
        attachments: s.attachments.where((x) => !x.sameSelection(a)).toList(),
      ),
    );
  }

  /// Reads [a] into the chat's case file; its chip shows what the server read.
  void _upload(String threadId, AgentAttachment a) =>
      _session(threadId).uploads.upload(
        ref.read(agentClientProvider),
        threadId,
        a,
        l10n: _l,
        show: (next) => _update(
          threadId,
          (s) => s.copyWith(
            attachments: [
              for (final x in s.attachments) x.sameSelection(a) ? next : x,
            ],
          ),
        ),
        log: (line) => _log(threadId, LogKind.attachment, line),
      );

  // -- turns --------------------------------------------------------------------

  void clearConversation(String threadId) {
    if (_state(threadId).isRunning) return;
    chatFor(threadId).clearMessages();
    _update(threadId, (s) => const SessionState());
  }

  /// Starts a chat from the new-chat screen and sends its first prompt.
  Future<void> startChat({
    required String projectId,
    required String prompt,
    String? documentId,
  }) async {
    final ws = ref.read(workspaceProvider.notifier);
    final thread = ws.createThread(
      projectId: projectId,
      title: titleFromPrompt(prompt),
      documentId: documentId,
    );
    final draft = _state(draftId).attachments;
    _update(draftId, (s) => s.copyWith(attachments: const []));
    _update(thread.id, (s) => s.copyWith(attachments: draft));
    ref.read(uiProvider.notifier).openThread(thread.id);
    for (final a in draft) {
      _upload(thread.id, a);
    }
    await send(thread.id, prompt);
  }

  /// Sends [text] to the agent of [threadId] with any pending attachments.
  Future<void> send(String threadId, String text) async {
    final prompt = text.trim();
    if (prompt.isEmpty || _state(threadId).isRunning) return;
    final session = _session(threadId);
    final chat = session.chat;
    ref.read(workspaceProvider.notifier).touchThread(threadId);

    if (session.uploads.busy) {
      // A long scan may still be in OCR: the run starts once every file is in the case file.
      _update(
        threadId,
        (s) => s.copyWith(activity: () => _l.agentReadingAttachments),
      );
      await session.uploads.settled();
      if (_state(threadId).isRunning) return;
    }
    final attachments = _state(threadId).attachments;
    if (attachments.any((a) => a.localPath != null && !a.isUploaded)) {
      _fail(
        threadId,
        "Uno o più allegati non sono stati caricati. Rimuovili e riprova il caricamento prima di inviare.",
      );
      return;
    }
    final names = attachments.map((a) => '`${a.name}`').join(' ');
    // Before the new message: the server gets the prompt on its own.
    final history = recentConversation(chat.messages);
    chat.addMessage(_cards.prompt(AttachmentsLine.add(prompt, names)));
    if (prompt.length > maxPromptChars) {
      // The text stays in the chat to copy from; the attachments stay for the next send.
      _fail(threadId, _l.agentPromptTooLong(prompt.length, maxPromptChars));
      return;
    }

    final host = ThreadToolHost(ref, threadId, () => session.runAttachments);
    session.runAttachments = attachments;
    final request = _requestFor(
      threadId,
      prompt,
      host.activeDocument,
      attachments,
      history,
    );

    final turn = session.turn = RunningTurn(_clock.id('turn'), prompt);
    session.progress = TurnProgress(chat, _clock, _l.progressStarting);
    _update(
      threadId,
      (s) => s.copyWith(
        phase: AgentPhase.thinking,
        activity: () => _l.agentThinking,
        attachments: const [],
        error: () => null,
        startedAt: () => turn.startedAt,
        activityDetail: '',
      ),
    );
    _log(threadId, LogKind.request, prompt, {
      'sessionId': threadId,
      'document': request.document?.title,
      'currentPage': request.currentPage,
      'attachments': [for (final a in attachments) a.name],
      'history': request.history.length,
    });

    // The run answers to the server with the key it started with, to its end: the server keeps it under that
    // key, and a key changed meanwhile in the settings applies from the next run.
    final client = ref.read(agentClientProvider);
    final tools = ToolRunner(
      _TurnSurface(this, ref, threadId, turn, client),
      _clock,
      host,
      turn,
      session.approvals,
      ref.read(snapshotStoreProvider),
      whatsapp: ref.read(whatsappProvider),
    );
    final reply = session.reply = StreamedReply(
      chat,
      _clock,
      (text) => _log(threadId, LogKind.text, clip(text), text),
    );
    final run = session.run = RunStream(
      client.run(request),
      onEvent: (event) =>
          _onEvent(threadId, event, reply, tools, host, turn, client),
      onError: (e) {
        reply.close();
        _fail(threadId, describeFailure(ref.read(l10nProvider), e));
      },
    );

    await run.done;
    if (!identical(session.turn, turn)) {
      return; // another turn or explicit cancellation owns the state
    }
    reply.close();
    session.progress?.finish(
      _state(threadId).phase == AgentPhase.error
          ? CardStatus.error
          : CardStatus.done,
    );
    session.progress = null;
    session.reply = null;
    session.turn = null;
    session.run = null;
    session.runAttachments = const [];
    _finishTurn(threadId, turn);
    if (_state(threadId).phase != AgentPhase.error) {
      _update(
        threadId,
        (s) => s.copyWith(phase: AgentPhase.idle, activity: () => null),
      );
    }
  }

  /// What one event of the run does: text and cards go to the chat, a tool call is executed and answered.
  Future<void> _onEvent(
    String threadId,
    AgentEvent event,
    StreamedReply reply,
    ToolRunner tools,
    ThreadToolHost host,
    RunningTurn turn,
    AgentClient client,
  ) async {
    switch (event) {
      case AgentStatusEvent(
        :final kind,
        :final label,
        :final detail,
        :final quiet,
      ):
        final operational =
            !quiet &&
            !const {'thinking', 'tool_prep', 'context_trimmed'}.contains(kind);
        _update(
          threadId,
          (s) => s.copyWith(
            activity: () => operational
                ? label
                : _state(threadId).activity ??
                      ConversationPresentation.activity(_l, kind),
            activityDetail: operational ? detail : null,
          ),
        );
        if (operational) _session(threadId).progress?.observe(event);
        _log(
          threadId,
          LogKind.status,
          operational ? label : ConversationPresentation.activity(_l, kind),
          {'label': label, 'detail': detail},
        );
        if (kind == 'degraded' &&
            detail.isNotEmpty &&
            turn.notices.add(detail)) {
          _session(threadId).chat.addMessage(
            _cards.note('**${_l.agentMaterialWarning}**\n\n$detail'),
          );
        }
      case AgentTextDelta(:final text):
        reply.add(text);
      case AgentToolCall():
        reply.close();
        _session(threadId).progress?.add(
          'operation:${event.id}',
          describeToolCall(_l, event.name, event.arguments),
        );
        try {
          await tools.run(event);
        } catch (e, stack) {
          // The server waits for every call's result: an app bug here must not leave the run hanging.
          debugPrint('PaperAgent: tool ${event.name} crashed: $e\n$stack');
          _log(threadId, LogKind.error, _l.operationFailed, {
            'tool': event.name,
            'error': '$e',
          });
          await _submit(
            client,
            threadId,
            event,
            ToolResult.error("Errore interno dell'app: $e"),
          );
        }
      case AgentUiEvent(:final component, :final props):
        reply.close();
        _addComponent(
          threadId,
          component,
          props,
          fallback: host.activeDocument,
        );
      case AgentDone():
        reply.close();
        _log(threadId, LogKind.done, _l.logRunFinished);
      case AgentEvidenceEvent(:final audit):
        reply.close();
        _addComponent(threadId, UiComponents.evidence, audit);
      case AgentFailure(:final message):
        reply.close();
        _fail(threadId, message);
    }
  }

  AgentRequest _requestFor(
    String threadId,
    String prompt,
    PaperDocument? doc,
    List<AgentAttachment> attachments,
    List<AgentTurn> history,
  ) {
    final viewer = ref.read(viewerProvider);
    final onScreen =
        doc != null && ref.read(activeDocumentProvider)?.id == doc.id;
    return AgentRequest(
      sessionId: threadId,
      prompt: prompt,
      document: doc,
      currentPage: onScreen && viewer.pageCount > 0 ? viewer.page : null,
      attachments: attachments,
      history: history,
    );
  }

  void cancel(String threadId) {
    final session = _sessions[threadId];
    final run = session?.run;
    if (session == null || run == null) return;
    run.stop();
    session.reply?.close();
    session.reply = null;
    session.progress?.finish(CardStatus.rejected);
    session.progress = null;
    if (session.turn case final turn?) _finishTurn(threadId, turn);
    session.run = null;
    for (final id in session.approvals.pending) {
      resolveApproval(threadId, id, approved: false);
    }
    session.runAttachments = const [];
    session.turn = null;
    session.chat.addMessage(_cards.note('_${_l.agentStopped}._'));
    _log(threadId, LogKind.error, _l.logStoppedByUser);
    _update(
      threadId,
      (s) => s.copyWith(phase: AgentPhase.idle, activity: () => null),
    );
  }

  /// Answers an [UiComponents.approval] card. [expired]: nobody answered while the server still waited.
  void resolveApproval(
    String threadId,
    String approvalId, {
    required bool approved,
    bool expired = false,
  }) => _sessions[threadId]?.approvals.resolve(
    approvalId,
    approved: approved,
    expired: expired,
  );

  /// Reverts the changes a turn made to [documentId], as an undoable step.
  void undoTurn(String threadId, String turnId, String documentId) {
    final turn = _state(threadId).turns
        .where((t) => t.id == turnId)
        .firstOrNull;
    final snapshot = turn?.changes[documentId];
    final doc = snapshot == null
        ? null
        : ref.read(snapshotStoreProvider).get(snapshot.$1);
    if (doc == null) return;
    ref.read(workspaceProvider.notifier).restore(doc, label: _l.agentUndoTurn);
    _log(threadId, LogKind.result, _l.logReverted(doc.title));
  }

  // -- what a turn shows ----------------------------------------------------------

  Future<void> _submit(
    AgentClient client,
    String threadId,
    AgentToolCall call,
    ToolResult result,
  ) async {
    try {
      await client.submitToolResult(threadId, call.id, result.toJson());
    } catch (e) {
      _log(
        threadId,
        LogKind.error,
        _l.logReportFailed(_l.failureUnexpected),
        '$e',
      );
    }
  }

  /// Adds a rich component, snapshotting the document it shows if needed.
  void _addComponent(
    String threadId,
    String kind,
    Map<String, dynamic> props, {
    PaperDocument? fallback,
  }) {
    if (!UiComponents.all.contains(kind)) {
      _log(threadId, LogKind.error, _l.logUnknownComponent(kind), props);
      return;
    }
    var data = props;
    if (UiComponents.documentBound.contains(kind) &&
        props['snapshot'] == null) {
      final docId = props['documentId'] is String
          ? props['documentId'] as String
          : null;
      final doc = docId == null
          ? fallback
          : ref.read(workspaceProvider).documents[docId];
      if (doc != null) {
        data = {
          ...props,
          'documentId': doc.id,
          'snapshot': ref.read(snapshotStoreProvider).put(doc),
        };
      }
    }
    _session(threadId).chat.addMessage(_cards.component(kind, data));
    _log(threadId, LogKind.ui, _l.componentLabel(kind), props);
  }

  void _finishTurn(String threadId, RunningTurn turn) {
    final closed = turn.close(ref.read(snapshotStoreProvider).put);
    if (closed == null) return;
    final (record, summaries) = closed;
    for (final summary in summaries) {
      _addComponent(threadId, UiComponents.changeSummary, {
        ...summary,
        'threadId': threadId,
      });
    }
    _update(threadId, (s) => s.copyWith(turns: [...s.turns, record]));
    _scheduleSave(threadId);
  }

  void _fail(String threadId, String message) {
    _session(threadId).chat.addMessage(_cards.failure(message));
    _log(threadId, LogKind.error, message);
    _update(
      threadId,
      (s) => s.copyWith(
        phase: AgentPhase.error,
        activity: () => null,
        error: () => message,
      ),
    );
  }
}

/// What the tool calls of one turn reach of their chat.
class _TurnSurface implements ToolSurface {
  _TurnSurface(
    this._agent,
    this._ref,
    this._threadId,
    this._turn,
    this._client,
  );

  final AgentController _agent;
  final Ref _ref;
  final String _threadId;
  final RunningTurn _turn;
  final AgentClient _client;

  @override
  ChatMessagesController get chat => _agent._session(_threadId).chat;

  @override
  bool get live => identical(_agent._sessions[_threadId]?.turn, _turn);

  @override
  AppLocalizations get l10n => _ref.read(l10nProvider);

  @override
  void phase(AgentPhase phase, String activity) => _agent._update(
    _threadId,
    (s) =>
        s.copyWith(phase: phase, activity: () => activity, activityDetail: ''),
  );

  @override
  void log(String kind, String summary, [Object? payload]) =>
      _agent._log(_threadId, kind, summary, payload);

  @override
  void show(String kind, Map<String, dynamic> props) =>
      _agent._addComponent(_threadId, kind, props);

  @override
  void reveal(String documentId, int page) =>
      revealPage(_ref, _threadId, documentId, page);

  @override
  Future<void> report(AgentToolCall call, ToolResult result) =>
      _agent._submit(_client, _threadId, call, result);
}
