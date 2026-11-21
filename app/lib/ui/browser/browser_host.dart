import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../features/browser/browser_state.dart';
import '../../features/browser/engine/engine.dart';
import '../../features/browser/live_pages.dart';
import '../../features/browser/web_address.dart';
import '../../features/workspace/ui_state.dart';
import '../../features/workspace/workspace_state.dart';
import '../../l10n/l10n.dart';
import '../app_actions.dart';
import '../shortcuts.dart';

/// The pages of the web tabs, for as long as the app runs. A page reports its address, title and icon to its tab;
/// a closed tab's page goes.
final livePagesProvider = Provider<LivePages>((ref) {
  final browser = ref.read(browserProvider.notifier);
  final pages = LivePages(
    ref.watch(browserEngineProvider),
    PageOptions(appKeys: pageKeys(always: true), outsideFieldKeys: pageKeys(always: false), dialogs: _Dialogs()),
    onChanged: (id, page) => browser.pageChanged(
      id,
      // A page between two documents is about:blank for a moment: the tab keeps the address it had.
      url: page.url != null && navigationFor(page.url!) == Navigation.web ? page.url.toString() : null,
      // A page that did not open has no title: the tab names the site, not the page before it.
      title: page.problem != null ? '' : (page.title.isEmpty ? null : page.title),
      icon: page.icon ?? '',
    ),
  );
  ref.listen(browserProvider.select((s) => s.tabs), (_, tabs) => pages.keepOnly(tabs.map((t) => t.id)));
  ref.onDispose(pages.dispose);
  return pages;
});

/// The web tab the side panel shows, if it shows one.
final shownWebTabProvider = Provider<WebTab?>((ref) {
  final chatTab = ref.watch(activeThreadProvider.select((t) => t?.activeTab != null));
  return ref.watch(browserProvider).shownBeside(chatTab: chatTab);
});

/// The web tab in front of the lawyer: shown in a panel that is on screen.
final visibleWebTabProvider = Provider<WebTab?>((ref) {
  final ui = ref.watch(uiProvider);
  if (!ui.panelShown || ui.section != AppSection.chat) return null;
  return ref.watch(shownWebTabProvider);
});

/// The address bar's keyboard focus: one bar is on screen at a time, and Ctrl+L reaches it from anywhere.
final addressFocusProvider = Provider<FocusNode>((ref) {
  final node = FocusNode(debugLabel: 'address');
  ref.onDispose(node.dispose);
  return node;
});

/// Shortcuts a web editor uses for itself (bold, a link, a heading, a list): a text field of the page keeps them.
/// Every other global shortcut reaches the app wherever the keyboard is in the page, as a browser's own keys do.
const _fieldShortcuts = {
  AppShortcut.focusPrompt,
  AppShortcut.export,
  AppShortcut.preview,
  AppShortcut.edit,
  AppShortcut.toggleSidebar,
  AppShortcut.toggleTheme,
};

/// The global shortcuts a page hands to the app: those that act [always], or only outside a text field.
List<KeyCombo> pageKeys({required bool always}) => [
  for (final s in AppShortcut.values)
    if (s.scope == ShortcutScope.global && _fieldShortcuts.contains(s) != always)
      for (final a in s.activators) ?comboOf(a),
];

/// The global shortcut a key pressed in a page stands for.
AppShortcut? shortcutFor(KeyCombo combo) {
  for (final s in AppShortcut.values) {
    if (s.scope == ShortcutScope.global && s.activators.any((a) => comboOf(a) == combo)) return s;
  }
  return null;
}

/// [activator] as a page sees it (`KeyboardEvent.key`), or null for a key no page reports the same way.
KeyCombo? comboOf(SingleActivator activator) {
  final trigger = activator.trigger;
  final key = _pageKeys[trigger] ?? (trigger.keyLabel.length == 1 ? trigger.keyLabel.toLowerCase() : null);
  if (key == null) return null;
  return KeyCombo(
    key,
    ctrl: activator.control,
    shift: activator.shift,
    alt: activator.alt,
    meta: activator.meta,
  );
}

/// The keys a page names otherwise than Flutter's label.
final _pageKeys = {
  LogicalKeyboardKey.arrowLeft: 'ArrowLeft',
  LogicalKeyboardKey.arrowRight: 'ArrowRight',
  LogicalKeyboardKey.escape: 'Escape',
  LogicalKeyboardKey.tab: 'Tab',
  LogicalKeyboardKey.pageUp: 'PageUp',
  LogicalKeyboardKey.pageDown: 'PageDown',
  LogicalKeyboardKey.f5: 'F5',
  LogicalKeyboardKey.numpadAdd: '+',
  LogicalKeyboardKey.numpadSubtract: '-',
};

/// What a page asks the lawyer, in the app's own dialogs (WebKit draws none).
class _Dialogs implements PageDialogs {
  @override
  Future<void> alert(String message) => _ask<void>(message, (context) => [_button(context, null, primary: true)]);

  @override
  Future<bool> confirm(String message) async =>
      await _ask<bool>(
        message,
        (context) => [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.cancel)),
          _button(context, true, primary: true),
        ],
      ) ??
      false;

  @override
  Future<String?> prompt(String message, String? value) async {
    final controller = TextEditingController(text: value);
    try {
      return await _ask<String>(
        message,
        (context) => [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(context.l10n.browserDialogOk),
          ),
        ],
        field: controller,
      );
    } finally {
      controller.dispose();
    }
  }

  static Widget _button(BuildContext context, Object? value, {bool primary = false}) =>
      FilledButton(
        autofocus: primary,
        onPressed: () => Navigator.pop(context, value),
        child: Text(context.l10n.browserDialogOk),
      );

  static Future<T?> _ask<T>(
    String message,
    List<Widget> Function(BuildContext) actions, {
    TextEditingController? field,
  }) async {
    final context = navigatorKey.currentContext;
    if (context == null) return null;
    return showDialog<T>(
      context: context,
      builder: (context) => AlertDialog(
        content: SizedBox(
          width: AppTheme.dialogWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(message),
              if (field != null) ...[
                const SizedBox(height: 12),
                TextField(controller: field, autofocus: true, onSubmitted: (v) => Navigator.pop(context, v)),
              ],
            ],
          ),
        ),
        actions: actions(context),
      ),
    );
  }
}
