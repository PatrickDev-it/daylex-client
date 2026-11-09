/// What a side-panel tab shows.
enum PanelTabKind {
  /// Live PDF preview (and editor) of one document.
  preview,
  source,

  /// Before/after of the changes made by the agent in this chat.
  review,

  /// Documents and templates to open.
  library,

  /// Raw agent events: status, tool calls, results.
  log,
}

/// A tab in the side panel, like a browser tab. Preview tabs carry the id of
/// the document they show; the other kinds exist at most once per chat.
class PanelTab {
  const PanelTab(this.kind, [this.documentId])
    : sourcePage = 1,
      sourceId = '',
      sourceQuote = '';

  const PanelTab.preview(String this.documentId)
    : kind = PanelTabKind.preview,
      sourcePage = 1,
      sourceId = '',
      sourceQuote = '';
  const PanelTab.source(
    String name, {
    this.sourcePage = 1,
    this.sourceQuote = '',
    this.sourceId = '',
  }) : kind = PanelTabKind.source,
       documentId = name;

  static const review = PanelTab(PanelTabKind.review);
  static const library = PanelTab(PanelTabKind.library);
  static const log = PanelTab(PanelTabKind.log);

  final PanelTabKind kind;
  final String? documentId;
  final int sourcePage;
  final String sourceQuote;
  final String sourceId;

  @override
  bool operator ==(Object other) =>
      other is PanelTab &&
      other.kind == kind &&
      other.documentId == documentId &&
      other.sourceId == sourceId;

  @override
  int get hashCode => Object.hash(kind, documentId, sourceId);

  @override
  String toString() =>
      documentId == null ? kind.name : '${kind.name}:$documentId';

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'documentId': ?documentId,
    if (kind == PanelTabKind.source) 'sourcePage': sourcePage,
    if (kind == PanelTabKind.source && sourceId.isNotEmpty)
      'sourceId': sourceId,
    if (kind == PanelTabKind.source && sourceQuote.isNotEmpty)
      'sourceQuote': sourceQuote,
  };

  static PanelTab? fromJson(Object? json) {
    if (json is! Map) return null;
    final kind = PanelTabKind.values
        .where((k) => k.name == json['kind'])
        .firstOrNull;
    if (kind == null) return null;
    final doc = json['documentId'] as String?;
    if (kind == PanelTabKind.preview) {
      return doc == null ? null : PanelTab.preview(doc);
    }
    if (kind == PanelTabKind.source) {
      return doc == null
          ? null
          : PanelTab.source(
              doc,
              sourcePage: ((json['sourcePage'] as num?)?.toInt() ?? 1).clamp(
                1,
                99999,
              ),
              sourceQuote: json['sourceQuote'] as String? ?? '',
              sourceId: json['sourceId'] as String? ?? '',
            );
    }
    return PanelTab(kind);
  }
}

/// One agent conversation. Chats live in a project; each keeps the document
/// it works on and its own set of side-panel tabs.
class ChatThread {
  const ChatThread({
    required this.id,
    required this.projectId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.documentId,
    this.tabs = const [],
    this.activeTab,
  });

  final String id;
  final String projectId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// The document the agent edits in this chat.
  final String? documentId;
  final List<PanelTab> tabs;
  final PanelTab? activeTab;

  ChatThread copyWith({
    String? projectId,
    String? title,
    DateTime? updatedAt,
    String? Function()? documentId,
    List<PanelTab>? tabs,
    PanelTab? Function()? activeTab,
  }) => ChatThread(
    id: id,
    projectId: projectId ?? this.projectId,
    title: title ?? this.title,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    documentId: documentId != null ? documentId() : this.documentId,
    tabs: tabs ?? this.tabs,
    activeTab: activeTab != null ? activeTab() : this.activeTab,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectId': projectId,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'documentId': ?documentId,
    'tabs': [for (final t in tabs) t.toJson()],
    'activeTab': ?activeTab?.toJson(),
  };

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    final created =
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now();
    return ChatThread(
      id: json['id'] as String,
      projectId: json['projectId'] as String,
      title: json['title'] as String? ?? 'New chat',
      createdAt: created,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? created,
      documentId: json['documentId'] as String?,
      tabs: [
        for (final t in json['tabs'] as List? ?? const [])
          ?PanelTab.fromJson(t),
      ],
      activeTab: PanelTab.fromJson(json['activeTab']),
    );
  }
}

/// Chat title from the first prompt: first line, trimmed to a few words; null for a blank prompt.
String? titleFromPrompt(String prompt) {
  final line = prompt.trim().split('\n').first;
  final words = line.split(RegExp(r'\s+'));
  final short = words.take(7).join(' ');
  final title = words.length > 7 ? '$short…' : short;
  return title.isEmpty ? null : title[0].toUpperCase() + title.substring(1);
}
