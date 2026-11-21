import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../l10n/l10n.dart';

/// Where a shortcut is bound.
enum ShortcutScope {
  /// Anywhere in the app ([AppActions.forShortcut] runs it).
  global,

  /// On the document, unless a text field has focus: the key is then the field's own undo.
  document,

  /// In the chat, while the agent works.
  chat,
}

const _ctrl = true;

/// Every keyboard shortcut, once: the bindings, the key hints in tooltips and menus, and the settings list are
/// all made from this.
enum AppShortcut {
  newChat([SingleActivator(LogicalKeyboardKey.keyN, control: _ctrl)]),
  newDocument([SingleActivator(LogicalKeyboardKey.keyN, control: _ctrl, shift: true)]),
  focusPrompt([SingleActivator(LogicalKeyboardKey.keyK, control: _ctrl)]),
  stopAgent([SingleActivator(LogicalKeyboardKey.escape)], scope: ShortcutScope.chat),
  export([SingleActivator(LogicalKeyboardKey.keyE, control: _ctrl)]),
  undo([SingleActivator(LogicalKeyboardKey.keyZ, control: _ctrl)], scope: ShortcutScope.document),
  redo([
    SingleActivator(LogicalKeyboardKey.keyZ, control: _ctrl, shift: true),
    SingleActivator(LogicalKeyboardKey.keyY, control: _ctrl),
  ], scope: ShortcutScope.document),
  preview([SingleActivator(LogicalKeyboardKey.digit1, control: _ctrl)]),
  edit([SingleActivator(LogicalKeyboardKey.digit2, control: _ctrl)]),
  previousPage([SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true)]),
  nextPage([SingleActivator(LogicalKeyboardKey.arrowRight, alt: true)]),
  zoomIn([
    SingleActivator(LogicalKeyboardKey.equal, control: _ctrl),
    SingleActivator(LogicalKeyboardKey.add, control: _ctrl),
    SingleActivator(LogicalKeyboardKey.numpadAdd, control: _ctrl),
  ]),
  zoomOut([
    SingleActivator(LogicalKeyboardKey.minus, control: _ctrl),
    SingleActivator(LogicalKeyboardKey.numpadSubtract, control: _ctrl),
  ]),
  zoomReset([SingleActivator(LogicalKeyboardKey.digit0, control: _ctrl)]),
  // Ctrl+Shift+O as Firefox's Library: Ctrl+T is a new tab, in every browser.
  libraryTab([SingleActivator(LogicalKeyboardKey.keyO, control: _ctrl, shift: true)]),
  reviewTab([SingleActivator(LogicalKeyboardKey.keyR, control: _ctrl)]),
  logTab([SingleActivator(LogicalKeyboardKey.backquote, control: _ctrl)]),
  closeTab([SingleActivator(LogicalKeyboardKey.keyW, control: _ctrl)]),
  newWebTab([SingleActivator(LogicalKeyboardKey.keyT, control: _ctrl)]),
  reopenTab([SingleActivator(LogicalKeyboardKey.keyT, control: _ctrl, shift: true)]),
  nextTab([
    SingleActivator(LogicalKeyboardKey.tab, control: _ctrl),
    SingleActivator(LogicalKeyboardKey.pageDown, control: _ctrl),
  ]),
  previousTab([
    SingleActivator(LogicalKeyboardKey.tab, control: _ctrl, shift: true),
    SingleActivator(LogicalKeyboardKey.pageUp, control: _ctrl),
  ]),
  focusAddress([SingleActivator(LogicalKeyboardKey.keyL, control: _ctrl)]),
  reload([SingleActivator(LogicalKeyboardKey.f5)]),
  toggleSidebar([SingleActivator(LogicalKeyboardKey.keyB, control: _ctrl)]),
  togglePanel([SingleActivator(LogicalKeyboardKey.keyJ, control: _ctrl)]),
  fullPanel([SingleActivator(LogicalKeyboardKey.keyJ, control: _ctrl, shift: true)]),
  toggleTheme([SingleActivator(LogicalKeyboardKey.keyL, control: _ctrl, shift: true)]);

  const AppShortcut(this.activators, {this.scope = ShortcutScope.global});

  /// The bindings; the first is the one hints show.
  final List<SingleActivator> activators;
  final ShortcutScope scope;

  SingleActivator get primary => activators.first;

  /// The hint: "Ctrl Shift N".
  String get keys => keysOf(primary);

  /// Every distinct binding, for the settings: "Ctrl Shift Z / Ctrl Y".
  String get allKeys => {for (final a in activators) keysOf(a)}.join(' / ');

  String label(AppLocalizations l) => switch (this) {
    AppShortcut.newChat => l.shortcutNewChat,
    AppShortcut.newDocument => l.shortcutNewDocument,
    AppShortcut.focusPrompt => l.shortcutFocusPrompt,
    AppShortcut.stopAgent => l.shortcutStopAgent,
    AppShortcut.export => l.shortcutExport,
    AppShortcut.undo => l.shortcutUndo,
    AppShortcut.redo => l.shortcutRedo,
    AppShortcut.preview => l.shortcutPreview,
    AppShortcut.edit => l.shortcutEdit,
    AppShortcut.previousPage => l.shortcutPreviousPage,
    AppShortcut.nextPage => l.shortcutNextPage,
    AppShortcut.zoomIn => l.shortcutZoomIn,
    AppShortcut.zoomOut => l.shortcutZoomOut,
    AppShortcut.zoomReset => l.shortcutZoomReset,
    AppShortcut.libraryTab => l.shortcutLibraryTab,
    AppShortcut.reviewTab => l.shortcutReviewTab,
    AppShortcut.logTab => l.shortcutLogTab,
    AppShortcut.closeTab => l.shortcutCloseTab,
    AppShortcut.newWebTab => l.shortcutNewWebTab,
    AppShortcut.reopenTab => l.shortcutReopenTab,
    AppShortcut.nextTab => l.shortcutNextTab,
    AppShortcut.previousTab => l.shortcutPreviousTab,
    AppShortcut.focusAddress => l.shortcutFocusAddress,
    AppShortcut.reload => l.shortcutReload,
    AppShortcut.toggleSidebar => l.shortcutToggleSidebar,
    AppShortcut.togglePanel => l.shortcutTogglePanel,
    AppShortcut.fullPanel => l.shortcutFullPanel,
    AppShortcut.toggleTheme => l.shortcutToggleTheme,
  };
}

/// How a binding is written for the lawyer: "Ctrl Shift N", "Alt ←", "Esc".
String keysOf(SingleActivator a) =>
    [if (a.control) 'Ctrl', if (a.alt) 'Alt', if (a.shift) 'Shift', if (a.meta) 'Meta', _keyName(a.trigger)].join(' ');

String _keyName(LogicalKeyboardKey key) => switch (key) {
  LogicalKeyboardKey.escape => 'Esc',
  LogicalKeyboardKey.arrowLeft => '←',
  LogicalKeyboardKey.arrowRight => '→',
  LogicalKeyboardKey.equal || LogicalKeyboardKey.add => '+',
  LogicalKeyboardKey.minus => '−',
  LogicalKeyboardKey.numpadAdd => 'Num +',
  LogicalKeyboardKey.numpadSubtract => 'Num −',
  LogicalKeyboardKey.backquote => '`',
  LogicalKeyboardKey.tab => 'Tab',
  LogicalKeyboardKey.pageUp => 'Pag ↑',
  LogicalKeyboardKey.pageDown => 'Pag ↓',
  _ => key.keyLabel.toUpperCase(),
};
