import 'chat_thread.dart';

/// The side-panel tabs of a chat, like browser tabs. Each change returns the chat after it.
extension PanelTabs on ChatThread {
  /// With [tab] open (once) and focused.
  ChatThread opening(PanelTab tab) => copyWith(
    tabs: tabs.contains(tab)
        ? [for (final old in tabs) old == tab ? tab : old]
        : [...tabs, tab],
  ).focusing(tab);

  /// With [tab] focused, if it is open.
  ChatThread activating(PanelTab tab) =>
      tabs.contains(tab) ? focusing(tab) : this;

  /// Without [tab]; closing the focused tab focuses the one before it.
  ChatThread closing(PanelTab tab) {
    final index = tabs.indexOf(tab);
    if (index < 0) return this;
    final rest = [...tabs]..removeAt(index);
    if (activeTab != tab) return copyWith(tabs: rest);
    final next = rest.isEmpty
        ? null
        : rest[(index - 1).clamp(0, rest.length - 1)];
    final closed = copyWith(tabs: rest, activeTab: () => null);
    return next == null ? closed : closed.focusing(next);
  }

  /// Focusing a preview makes its document the one the agent edits.
  ChatThread focusing(PanelTab tab) => copyWith(
    activeTab: () => tab,
    documentId: tab.kind == PanelTabKind.preview ? () => tab.documentId : null,
  );

  /// Without the preview of [documentId], which is gone; the agent no longer edits it here.
  ChatThread forgetting(String documentId) {
    final tab = PanelTab.preview(documentId);
    if (!tabs.contains(tab) && this.documentId != documentId) return this;
    return copyWith(
      tabs: tabs.where((x) => x != tab).toList(),
      activeTab: activeTab == tab ? () => null : null,
      documentId: this.documentId == documentId ? () => null : null,
    );
  }
}
