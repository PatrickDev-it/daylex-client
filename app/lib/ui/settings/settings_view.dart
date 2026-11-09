import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../features/agent/agent_controller.dart';
import '../../features/agent/data/http_agent_client.dart';
import '../../features/agent/domain/document_tools.dart';
import '../../features/agent/presentation/ui_components.dart';
import '../../features/agent/whatsapp_bridge.dart';
import '../../features/update/update_controller.dart';
import '../../features/workspace/ui_state.dart';
import '../../l10n/labels.dart';
import '../../l10n/l10n.dart';
import '../app_actions.dart';
import '../access/access_gate.dart';
import '../common/widgets.dart';
import '../shortcuts.dart';
import '../sidebar/update_button.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final tokens = AppTokens.of(context);
    final l = context.l10n;
    final ui = ref.watch(uiProvider);
    final client = ref.watch(agentClientProvider);
    final update = ref.watch(updateProvider);
    final whatsapp = ref.watch(whatsappProvider);
    final approval = [
      for (final t in documentToolSpecs)
        if (t.requiresApproval) describeToolCall(l, t.name, const {}),
    ];

    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: text.titleSmall),
          const SizedBox(height: 10),
          OutlinedBox(
            radius: AppTheme.radiusLg,
            child: Column(children: children),
          ),
        ],
      ),
    );

    Widget row(
      String label,
      Widget trailing, {
      String? help,
      bool last = false,
    }) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.bodyMedium),
                if (help != null) Text(help, style: text.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: AppTheme.headerHeight,
          child: Row(
            children: [
              const SizedBox(width: 10),
              if (!ui.sidebarOpen)
                ToolbarButton(
                  icon: LucideIcons.panelLeftOpen,
                  tooltip: l.chatShowSidebar,
                  shortcut: AppShortcut.toggleSidebar,
                  onPressed: ref.read(uiProvider.notifier).toggleSidebar,
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l.settings, style: text.headlineSmall),
                      const SizedBox(height: 24),
                      section(l.settingsAppearance, [
                        row(
                          l.settingsTheme,
                          SegmentedButton<ThemeMode>(
                            showSelectedIcon: false,
                            segments: [
                              ButtonSegment(
                                value: ThemeMode.system,
                                icon: const Icon(LucideIcons.monitor, size: 14),
                                label: Text(l.settingsThemeSystem),
                              ),
                              ButtonSegment(
                                value: ThemeMode.light,
                                icon: const Icon(LucideIcons.sun, size: 14),
                                label: Text(l.settingsThemeLight),
                              ),
                              ButtonSegment(
                                value: ThemeMode.dark,
                                icon: const Icon(LucideIcons.moon, size: 14),
                                label: Text(l.settingsThemeDark),
                              ),
                            ],
                            selected: {ui.themeMode},
                            onSelectionChanged: (s) => ref
                                .read(uiProvider.notifier)
                                .setThemeMode(s.first),
                          ),
                        ),
                        row(
                          l.settingsLanguage,
                          Text(l.languageItalian),
                          last: true,
                        ),
                      ]),
                      section(l.settingsAgent, [
                        row(
                          l.settingsBackend,
                          Pill(
                            l.agentBackend(client),
                            icon: LucideIcons.circleDot,
                          ),
                          help:
                              client.problem ??
                              (client.isMock
                                  ? l.settingsBackendMockHelp
                                  : l.settingsBackendServerHelp),
                        ),
                        if (!client.isMock)
                          row(
                            l.settingsAccessKey,
                            OutlinedButton(
                              onPressed: () => _enterAccessKey(context, ref),
                              child: Text(
                                client.problem == null
                                    ? l.settingsAccessKeyReplace
                                    : l.settingsAccessKeyEnter,
                              ),
                            ),
                            help: client.problem == null
                                ? l.settingsAccessKeySet
                                : l.settingsAccessKeyMissing,
                          ),
                        if (!client.isMock)
                          row(
                            l.settingsResetConnection,
                            OutlinedButton(
                              onPressed: () {
                                try {
                                  AgentServerConfig.resetAddress(l);
                                  ref.invalidate(agentClientProvider);
                                  toast(l.settingsResetConnectionDone);
                                } on AgentConfigException catch (e) {
                                  toast(e.message);
                                }
                              },
                              child: Text(l.settingsResetConnectionAction),
                            ),
                            help: l.settingsResetConnectionHelp,
                          ),
                        row(
                          l.settingsTools,
                          Pill(l.settingsToolCount(appToolSpecs.length)),
                          help: l.settingsToolsHelp(
                            approval.length,
                            approval.join(', '),
                          ),
                        ),
                        row(
                          l.settingsUiComponents,
                          Pill(
                            l.settingsUiComponentCount(UiComponents.all.length),
                          ),
                          help: l.settingsUiComponentsHelp(
                            UiComponents.all.map(l.componentLabel).join(', '),
                          ),
                          last: true,
                        ),
                      ]),
                      if (!kIsWeb) ListenableBuilder(
                        listenable: whatsapp,
                        builder: (context, _) => section(l.whatsappTitle, [
                          row(
                            l.whatsappTitle,
                            whatsapp.ready
                                ? Pill(
                                    l.whatsappConnected,
                                    icon: LucideIcons.circleCheck,
                                  )
                                : OutlinedButton(
                                    onPressed: () => unawaited(
                                      whatsapp.start().catchError(
                                        (Object _) {},
                                      ),
                                    ),
                                    child: Text(l.whatsappConnect),
                                  ),
                            help: whatsapp.error ?? l.whatsappHelp,
                            last: whatsapp.qr == null,
                          ),
                          if (whatsapp.qr case final qr?)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Text(l.whatsappScanQr),
                                  const SizedBox(height: 12),
                                  QrImageView(
                                    data: qr,
                                    size: 220,
                                    backgroundColor: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                        ]),
                      ),
                      if (!kIsWeb) section(l.settingsUpdates, [
                        row(
                          l.settingsVersion,
                          _UpdateAction(update),
                          help: switch (update) {
                            UpdateState(phase: UpdatePhase.off) =>
                              l.updateStatusOff,
                            UpdateState(checking: true) =>
                              l.updateStatusChecking,
                            UpdateState(:final release?) when update.offered =>
                              l.updateStatusReady(release.version),
                            UpdateState(checkFailed: true) =>
                              l.updateStatusCheckFailed,
                            _ => l.updateStatusUpToDate,
                          },
                          last: true,
                        ),
                      ]),
                      section(l.settingsShortcuts, [
                        for (final (i, s) in AppShortcut.values.indexed)
                          row(
                            s.label(l),
                            KeyHint(s.allKeys),
                            last: i == AppShortcut.values.length - 1,
                          ),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The key the lawyer received: checked with the server, kept unless the
  /// server refuses it, and the agent reconnects with it.
  Future<void> _enterAccessKey(BuildContext context, WidgetRef ref) async {
    await showAccessDialog(context);
  }
}

/// The installed version, and what the lawyer can do about updates from here: open the waiting one, or check now.
class _UpdateAction extends ConsumerWidget {
  const _UpdateAction(this.update);

  final UpdateState update;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final version = update.version;
    final build = update.build;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (version != null && build != null)
          Pill(l.settingsVersionValue(version, build)),
        if (update.phase != UpdatePhase.off) ...[
          const SizedBox(width: 8),
          if (update.phase == UpdatePhase.ready ||
              update.phase == UpdatePhase.blocked)
            FilledButton(
              onPressed: () => showUpdateDialog(ref),
              child: Text(l.updateReady),
            )
          else
            OutlinedButton(
              onPressed: update.checking || update.phase != UpdatePhase.idle
                  ? null
                  : () => ref.read(updateProvider.notifier).check(),
              child: Text(l.updateCheckNow),
            ),
        ],
      ],
    );
  }
}
