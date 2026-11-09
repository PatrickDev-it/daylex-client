import 'dart:ui' show AppExitResponse;

import 'package:deskify/deskify.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'core/platform/frame_recovery.dart';
import 'core/platform/browser_runtime.dart' as browser;
import 'core/theme/app_theme.dart';
import 'features/storage/local_store.dart';
import 'features/workspace/chat_thread.dart';
import 'features/workspace/ui_state.dart';
import 'l10n/l10n.dart';
import 'ui/app_actions.dart';
import 'ui/panel/panel_tab_specs.dart';
import 'ui/shell/app_shell.dart';
import 'ui/shortcuts.dart';
import 'ui/access/access_gate.dart';

class PaperAgentApp extends ConsumerWidget {
  const PaperAgentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(uiProvider.select((s) => s.themeMode));
    final locale = ref.watch(uiProvider.select((s) => s.locale));

    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('it')],
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      themeAnimationDuration: AppTheme.slow,
      builder: (context, child) => FrameRecovery(
        child: _SaveOnExit(
          child: _DesktopChrome(child: _StorageNotice(child: child!)),
        ),
      ),
      home: const AccessGate(child: AppShell()),
    );
  }
}

/// What the saved work needs the lawyer to know (a file set aside, work recovered, a save that failed, data
/// from a newer app), above everything until dismissed: a toast would be gone before it was read.
class _StorageNotice extends ConsumerWidget {
  const _StorageNotice({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(localStoreProvider);
    if (store == null) return child;
    return ValueListenableBuilder<StoreNotice?>(
      valueListenable: store.notice,
      builder: (context, notice, _) => Column(
        children: [
          if (notice != null)
            MaterialBanner(
              leading: const Icon(LucideIcons.triangleAlert),
              content: Text(notice.text(context.l10n)),
              actions: [
                TextButton(
                  onPressed: () => store.notice.value = null,
                  child: Text(context.l10n.gotIt),
                ),
              ],
            ),
          // Keyed: the app below keeps its state when the banner comes and goes.
          Expanded(key: const ValueKey('app'), child: child),
        ],
      ),
    );
  }
}

/// Writes what is still waiting to be saved when the window closes or the app goes to the background:
/// saves otherwise run a moment after each change.
class _SaveOnExit extends ConsumerStatefulWidget {
  const _SaveOnExit({required this.child});

  final Widget child;

  @override
  ConsumerState<_SaveOnExit> createState() => _SaveOnExitState();
}

class _SaveOnExitState extends ConsumerState<_SaveOnExit> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      browser.onSave(() {
        AppActions(ref).saveNow();
        return !(ref.read(localStoreProvider)?.readOnly ?? false);
      });
    }
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        if (state != AppLifecycleState.resumed) _flush();
      },
      onExitRequested: () async {
        if (AppActions(ref).saveNow()) return AppExitResponse.exit;
        final dialogContext = navigatorKey.currentContext;
        if (dialogContext == null || !dialogContext.mounted) {
          return AppExitResponse.cancel;
        }
        final l = ref.read(l10nProvider);
        final discard = await showDialog<bool>(
          context: dialogContext,
          builder: (context) => AlertDialog(
            title: Text(l.exitUnsavedTitle),
            content: Text(l.exitUnsavedHelp),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.exitKeepOpen),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.exitDiscard),
              ),
            ],
          ),
        );
        return discard == true ? AppExitResponse.exit : AppExitResponse.cancel;
      },
    );
  }

  void _flush() {
    AppActions(ref).saveNow();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Global keyboard shortcuts and right-click menu, provided by deskify.
class _DesktopChrome extends ConsumerWidget {
  const _DesktopChrome({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = AppActions(ref);
    final l = context.l10n;

    return Deskify(
      enableDevHub: false,
      showDevHubButton: false,
      globalShortcuts: {
        for (final shortcut in AppShortcut.values)
          if (actions.forShortcut(shortcut) case final run?)
            for (final activator in shortcut.activators) activator: run,
      },
      globalRightClickItems: [
        DeskContextMenuItem(
          label: l.newChat,
          icon: LucideIcons.squarePen,
          onTap: () => actions.newChat(),
        ),
        DeskContextMenuItem(
          label: l.newDocument,
          icon: LucideIcons.filePlus,
          onTap: actions.newDocument,
        ),
        DeskContextMenuItem(
          label: l.exportPdf,
          icon: LucideIcons.download,
          onTap: actions.export,
        ),
        DeskContextMenuItem.divider(),
        DeskContextMenuItem(
          label: l.reviewChanges,
          icon: PanelTabKind.review.icon,
          onTap: () => actions.openReview(),
        ),
        DeskContextMenuItem(
          label: PanelTabKind.log.name(l),
          icon: PanelTabKind.log.icon,
          onTap: () => actions.openTab(PanelTab.log),
        ),
        DeskContextMenuItem(
          label: l.toggleDarkMode,
          icon: LucideIcons.moon,
          onTap: actions.toggleTheme,
        ),
      ],
      child: Shortcuts(
        shortcuts: {
          for (final activator in AppShortcut.undo.activators)
            activator: const _DocumentUndoIntent(),
          for (final activator in AppShortcut.redo.activators)
            activator: const _DocumentRedoIntent(),
        },
        child: Actions(
          actions: {
            _DocumentUndoIntent: _UnlessEditingText<_DocumentUndoIntent>(
              actions.undo,
            ),
            _DocumentRedoIntent: _UnlessEditingText<_DocumentRedoIntent>(
              actions.redo,
            ),
          },
          // Shortcuts only fire when focus is inside Deskify; give it a home.
          child: Focus(autofocus: true, child: child),
        ),
      ),
    );
  }
}

class _DocumentUndoIntent extends Intent {
  const _DocumentUndoIntent();
}

class _DocumentRedoIntent extends Intent {
  const _DocumentRedoIntent();
}

/// Document undo/redo that steps aside while a text field has focus, so the
/// key falls through to the field's own text undo.
class _UnlessEditingText<T extends Intent> extends Action<T> {
  _UnlessEditingText(this.callback);

  final VoidCallback callback;

  @override
  bool isEnabled(T intent) =>
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<EditableText>() ==
      null;

  @override
  void invoke(T intent) => callback();
}
