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
  libraryTab([SingleActivator(LogicalKeyboardKey.keyT, control: _ctrl)]),
  reviewTab([SingleActivator(LogicalKeyboardKey.keyR, control: _ctrl)]),
  logTab([SingleActivator(LogicalKeyboardKey.backquote, control: _ctrl)]),
  closeTab([SingleActivator(LogicalKeyboardKey.keyW, control: _ctrl)]),
  toggleSidebar([SingleActivator(LogicalKeyboardKey.keyB, control: _ctrl)]),
  togglePanel([SingleActivator(LogicalKeyboardKey.keyJ, control: _ctrl)]),
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
    AppShortcut.toggleSidebar => l.shortcutToggleSidebar,
    AppShortcut.togglePanel => l.shortcutTogglePanel,
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
  _ => key.keyLabel.toUpperCase(),
};
