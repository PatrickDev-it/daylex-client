import 'domain/agent_protocol.dart';

enum AgentPhase { idle, thinking, working, waiting, error }

/// The kinds of line the agent log has. The log panel colours them, so the strings are shared with it.
abstract final class LogKind {
  static const request = 'request';
  static const status = 'status';
  static const text = 'text';
  static const tool = 'tool';
  static const result = 'result';
  static const ui = 'ui';
  static const approval = 'approval';
  static const attachment = 'attachment';
  static const error = 'error';
  static const done = 'done';
}

/// One line of the agent log shown in the side panel.
class AgentLogEntry {
  const AgentLogEntry(this.time, this.kind, this.summary, [this.detail]);

  final DateTime time;

  /// One of [LogKind].
  final String kind;
  final String summary;

  /// Pretty-printed JSON payload, if any.
  final String? detail;
}

/// [s] on one line, cut at [max] characters: what a log line shows of a longer text.
String clip(String s, [int max = 120]) {
  final flat = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return flat.length <= max ? flat : '${flat.substring(0, max)}…';
}

/// What one prompt changed, for the Review tab.
class TurnRecord {
  const TurnRecord({
    required this.id,
    required this.prompt,
    required this.startedAt,
    required this.endedAt,
    required this.tools,
    required this.changes,
  });

  final String id;
  final String prompt;
  final DateTime startedAt;
  final DateTime endedAt;
  final int tools;

  /// Document id → (snapshot before the turn, snapshot after it).
  final Map<String, (String, String)> changes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'prompt': prompt,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'tools': tools,
    'changes': {
      for (final e in changes.entries) e.key: [e.value.$1, e.value.$2],
    },
  };

  static TurnRecord? fromJson(Object? json) {
    if (json is! Map) return null;
    final started = DateTime.tryParse(json['startedAt'] as String? ?? '');
    if (started == null) return null;
    return TurnRecord(
      id: json['id'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      startedAt: started,
      endedAt: DateTime.tryParse(json['endedAt'] as String? ?? '') ?? started,
      tools: json['tools'] as int? ?? 0,
      changes: {
        for (final e in (json['changes'] as Map? ?? const {}).entries)
          if (e.value case [final String before, final String after])
            e.key as String: (before, after),
      },
    );
  }
}

class SessionState {
  const SessionState({
    this.phase = AgentPhase.idle,
    this.activity,
    this.activityDetail = '',
    this.attachments = const [],
    this.error,
    this.startedAt,
    this.log = const [],
    this.turns = const [],
  });

  final AgentPhase phase;

  /// What the agent is doing right now, e.g. "Rewriting page · page 3".
  final String? activity;
  final String activityDetail;
  final List<AgentAttachment> attachments;
  final String? error;
  final DateTime? startedAt;
  final List<AgentLogEntry> log;
  final List<TurnRecord> turns;

  bool get isRunning =>
      phase == AgentPhase.thinking ||
      phase == AgentPhase.working ||
      phase == AgentPhase.waiting;

  SessionState copyWith({
    AgentPhase? phase,
    String? Function()? activity,
    String? activityDetail,
    List<AgentAttachment>? attachments,
    String? Function()? error,
    DateTime? Function()? startedAt,
    List<AgentLogEntry>? log,
    List<TurnRecord>? turns,
  }) => SessionState(
    phase: phase ?? this.phase,
    activity: activity != null ? activity() : this.activity,
    activityDetail: activityDetail ?? this.activityDetail,
    attachments: attachments ?? this.attachments,
    error: error != null ? error() : this.error,
    startedAt: startedAt != null ? startedAt() : this.startedAt,
    log: log ?? this.log,
    turns: turns ?? this.turns,
  );
}

class AgentState {
  const AgentState([this.sessions = const {}]);

  /// Per chat id. The new-chat screen uses `AgentController.draftId`.
  final Map<String, SessionState> sessions;

  SessionState of(String? id) => sessions[id] ?? const SessionState();

  bool isRunning(String id) => of(id).isRunning;

  /// How many chats are working right now.
  int get running => sessions.values.where((s) => s.isRunning).length;
}
