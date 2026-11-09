import 'dart:convert';
import 'dart:typed_data';

import '../../../l10n/l10n.dart';
import '../../document/model/document.dart';

part 'agent_protocol.g.dart';

/// Contract between the app and whatever runs the model.
///
/// [HttpAgentClient] talks to the self-hosted Python server; [MockAgentClient]
/// answers offline for tests and demos. The server only
/// ever *proposes* tool calls: the app validates and executes them against
/// the document model, so the model never touches UI state or PDF bytes.
abstract interface class AgentClient {
  /// Streams the agent's response to [request]. Cancelling the subscription
  /// cancels the run.
  Stream<AgentEvent> run(AgentRequest request);

  /// Name shown in the agent panel header.
  String get displayName;

  /// Whether this client talks to a real model.
  bool get isMock;

  /// Why no request can run (no server configured, a broken configuration),
  /// shown where the agent's state is; null when the agent can be asked.
  String? get problem;

  /// Reports the outcome of [AgentToolCall] `callId` so the model can continue
  /// its loop (`POST /v1/agent/runs/{sessionId}/tool-results`).
  Future<void> submitToolResult(
    String sessionId,
    String callId,
    Map<String, dynamic> result,
  );

  /// Reads [attachment] into the case file of chat [sessionId] right away
  /// (`POST /v1/sessions/{id}/attachments`), so a later run only names it and
  /// every later turn can still query it. Null when this client keeps no
  /// case file: the bytes then travel with the run.
  Future<AttachmentCard?> uploadAttachment(
    String sessionId,
    AgentAttachment attachment,
  );

  /// Takes the document [name] out of the case file of chat [sessionId].
  Future<void> deleteAttachment(String sessionId, String name);

  /// Deletes the whole case file of chat [sessionId]: the chat itself was deleted.
  Future<void> deleteCaseFile(String sessionId);

  /// Reads evidence in this conversation only. Null means it has expired or was removed.
  Future<SourceDocument?> readSource(
    String sessionId,
    String name,
    int page, {
    bool includeOriginal = true,
  });
}

class SourceDocument {
  const SourceDocument({
    required this.name,
    required this.page,
    required this.pages,
    required this.text,
    this.pdfBytes,
    this.unit = 'page',
  });
  final String name;
  final int page;
  final int pages;
  final String text;
  final Uint8List? pdfBytes;
  final String unit;
}

class AgentAttachment {
  AgentAttachment({
    required this.name,
    required this.mimeType,
    required this.bytes,
    this.status = AttachmentStatus.local,
    this.serverName,
    this.summary,
    this.localPath,
    Object? selectionId,
  }) : selectionId = selectionId ?? Object();

  final String name;
  final String mimeType;
  final Uint8List bytes;
  final String? localPath;
  final Object selectionId;
  Object get identity => selectionId;
  bool sameSelection(AgentAttachment other) =>
      identical(identity, other.identity);
  final AttachmentStatus status;

  /// The name in the case file: "atto (2).pdf" for a second file called
  /// "atto.pdf", or the earlier copy's name for the same text signed (.p7m).
  final String? serverName;

  /// What the server read ("decreto ingiuntivo · 2 pages"), or why it failed.
  final String? summary;

  bool get isImage => mimeType.startsWith('image/');

  /// Already in the case file: the run names it without sending it again.
  bool get isUploaded => status == AttachmentStatus.ready;

  AgentAttachment withStatus(
    AttachmentStatus status, {
    String? serverName,
    String? summary,
  }) => AgentAttachment(
    name: name,
    mimeType: mimeType,
    bytes: status == AttachmentStatus.ready ? Uint8List(0) : bytes,
    localPath: localPath,
    selectionId: identity,
    status: status,
    serverName: serverName ?? this.serverName,
    summary: summary ?? this.summary,
  );

  Map<String, dynamic> toJson() => {
    'name': serverName ?? name,
    'mimeType': mimeType,
    'data': isUploaded ? '' : base64Encode(bytes),
  };
}

/// Where an attachment stands in its chat's case file on the server.
enum AttachmentStatus { local, uploading, ready, failed }

/// The server's card of a document in a chat's case file.
class AttachmentCard {
  const AttachmentCard({
    required this.name,
    required this.pages,
    this.kind = '',
    this.notes = const [],
    this.readable = true,
    this.isNew = false,
  });

  factory AttachmentCard.fromJson(Map<String, dynamic> json) => AttachmentCard(
    name: json['name'] as String? ?? '',
    pages: (json['pages'] as num?)?.toInt() ?? 0,
    kind: json['kind'] as String? ?? '',
    notes: [for (final n in json['notes'] as List? ?? const []) '$n'],
    readable: json['readable'] as bool? ?? true,
    isNew: json['new'] as bool? ?? false,
  );

  final String name;
  final int pages;

  /// "decreto ingiuntivo", "perizia / consulenza tecnica", "" when unknown.
  final String kind;

  /// "3 pagine lette con OCR (cifre e nomi da verificare)", ...
  final List<String> notes;
  final bool readable;

  /// Read by this upload, not found already in the case file.
  final bool isNew;

  /// What the chip's tooltip says, the page count in [l]'s language (kind and notes are the server's words).
  String summary(AppLocalizations l) =>
      [if (kind.isNotEmpty) kind, l.pageCount(pages), ...notes].join(' · ');
}

class AgentTurn {
  const AgentTurn({required this.role, required this.text});

  /// `user` or `assistant`.
  final String role;
  final String text;

  Map<String, dynamic> toJson() => {'role': role, 'text': text};
}

class AgentRequest {
  const AgentRequest({
    required this.sessionId,
    required this.prompt,
    this.document,
    this.currentPage,
    this.attachments = const [],
    this.history = const [],
  });

  final String sessionId;
  final String prompt;

  /// Snapshot of the document being edited, if any.
  final PaperDocument? document;

  /// 1-based page the user is looking at, used to resolve "this page".
  final int? currentPage;
  final List<AgentAttachment> attachments;
  final List<AgentTurn> history;

  /// Wire format of `POST /v1/agent/runs`.
  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'prompt': prompt,
    'document': document?.toJson(),
    'currentPage': currentPage,
    'attachments': [for (final a in attachments) a.toJson()],
    'history': [for (final t in history) t.toJson()],
  };
}

/// Events streamed back by the agent.
sealed class AgentEvent {
  const AgentEvent();
}

/// Short progress label, e.g. "Reading document", with an optional detail
/// ("pp. 57, 64: 2 ragioni della decisione"). A [quiet] status is a heartbeat
/// for the activity line, never a step of the turn's progress card: the server
/// says which is which, the app does not guess it from the label.
class AgentStatusEvent extends AgentEvent {
  const AgentStatusEvent(
    this.label, {
    this.kind = '',
    this.detail = '',
    this.quiet = false,
  });
  final String label;
  final String kind;
  final String detail;
  final bool quiet;
}

/// A chunk of assistant markdown.
class AgentTextDelta extends AgentEvent {
  const AgentTextDelta(this.text);
  final String text;
}

/// A request to run one of the document tools in `document_tools.dart`.
class AgentToolCall extends AgentEvent {
  const AgentToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  final String id;
  final String name;
  final Map<String, dynamic> arguments;
}

/// Asks the app to render a rich component in the conversation, e.g.
/// `{"type": "ui", "component": "pdf_page", "props": {"page": 3}}`.
///
/// Components are resolved through the app's component registry; unknown
/// ones are logged and skipped. The model can also embed a component in its
/// markdown as a fenced block: ```` ```ui:pdf_page {"page": 3}``` ````.
class AgentUiEvent extends AgentEvent {
  const AgentUiEvent(this.component, [this.props = const {}]);
  final String component;
  final Map<String, dynamic> props;
}

class AgentDone extends AgentEvent {
  const AgentDone();
}

/// Evidence for the reviewed reply, separate from both progress and legal qualification.
class AgentEvidenceEvent extends AgentEvent {
  const AgentEvidenceEvent(this.audit);
  final Map<String, dynamic> audit;
}

class AgentFailure extends AgentEvent {
  const AgentFailure(this.message);
  final String message;
}
