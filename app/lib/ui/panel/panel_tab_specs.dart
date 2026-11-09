import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../features/workspace/chat_thread.dart';
import '../../l10n/l10n.dart';
import '../shortcuts.dart';

/// What the UI knows about each kind of side-panel tab. The tab strip, the "open a tab" menu, the empty panel
/// and the shortcuts read it from here; a new kind is a case in each switch, and the compiler finds them.
extension PanelTabKindUi on PanelTabKind {
  IconData get icon => switch (this) {
    PanelTabKind.preview => LucideIcons.fileText,
    PanelTabKind.source => LucideIcons.bookOpen,
    PanelTabKind.review => LucideIcons.gitCompare,
    PanelTabKind.library => LucideIcons.library,
    PanelTabKind.log => LucideIcons.terminal,
  };

  /// The shortcut that opens it. The menu runs the same command, so the two cannot drift apart.
  AppShortcut? get shortcut => switch (this) {
    PanelTabKind.source => null,
    PanelTabKind.preview => AppShortcut.preview,
    PanelTabKind.review => AppShortcut.reviewTab,
    PanelTabKind.library => AppShortcut.libraryTab,
    PanelTabKind.log => AppShortcut.logTab,
  };

  String name(AppLocalizations l) => switch (this) {
    PanelTabKind.preview => l.tabPreview,
    PanelTabKind.source => l.sourceTitle,
    PanelTabKind.review => l.tabReview,
    PanelTabKind.library => l.tabLibrary,
    PanelTabKind.log => l.tabLog,
  };
}
