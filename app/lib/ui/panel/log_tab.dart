import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../features/agent/agent_controller.dart';
import '../../l10n/labels.dart';
import '../../l10n/l10n.dart';
import '../common/time_format.dart';
import '../common/widgets.dart';

/// Raw agent events of the chat, terminal style: what was sent to the model,
/// status updates, tool calls with their arguments and results.
class LogTab extends ConsumerStatefulWidget {
  const LogTab({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<LogTab> createState() => _LogTabState();
}

class _LogTabState extends ConsumerState<LogTab> {
  final _scroll = ScrollController();
  final _open = <int>{};

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final l = context.l10n;
    final session = ref.watch(sessionProvider(widget.threadId));
    final client = ref.watch(agentClientProvider);
    final log = session.log;

    ref.listen(sessionProvider(widget.threadId).select((s) => s.log.length), (
      _,
      _,
    ) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients && _scroll.position.extentAfter < 120) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    });

    final mono = AppText.of(context).code.copyWith(color: tokens.textMuted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelToolbar(
          color: tokens.panel,
          children: [
            const SizedBox(width: 4),
            Icon(
              LucideIcons.circleDot,
              size: 11,
              color: session.isRunning ? scheme.primary : tokens.success,
            ),
            const SizedBox(width: 8),
            Text(l.agentBackend(client), style: text.labelMedium),
            const SizedBox(width: 8),
            Text(
              '${l.phaseLabel(session.phase)} · ${l.logEventCount(log.length)}',
              style: text.labelSmall?.copyWith(color: tokens.textFaint),
            ),
            const Spacer(),
            ToolbarButton(
              icon: LucideIcons.copy,
              tooltip: l.logCopy,
              onPressed: log.isEmpty
                  ? null
                  : () {
                      Clipboard.setData(
                        ClipboardData(
                          text: [
                            for (final e in log)
                              '${clockSeconds(e.time)} ${e.kind} ${e.summary}${e.detail == null ? '' : '\n${e.detail}'}',
                          ].join('\n'),
                        ),
                      );
                    },
            ),
          ],
        ),
        const Divider(),
        Expanded(
          child: log.isEmpty
              ? EmptyState(
                  icon: LucideIcons.terminal,
                  title: l.logEmptyTitle,
                  message: l.logEmptyMessage,
                )
              : SelectionArea(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: log.length,
                    itemBuilder: (context, i) {
                      final e = log[i];
                      final open = _open.contains(i);
                      final color = switch (e.kind) {
                        LogKind.error => tokens.danger,
                        LogKind.tool => scheme.primary,
                        LogKind.result => tokens.success,
                        LogKind.request => tokens.warning,
                        _ => tokens.textFaint,
                      };
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          InkWell(
                            onTap: e.detail == null
                                ? null
                                : () => setState(
                                    () => open ? _open.remove(i) : _open.add(i),
                                  ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 2,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    clockSeconds(e.time),
                                    style: mono.copyWith(
                                      color: tokens.textFaint,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    width: 78,
                                    child: Text(
                                      l.eventLabel(e.kind),
                                      style: mono.copyWith(color: color),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      e.summary,
                                      style: mono.copyWith(
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  if (e.detail != null)
                                    Icon(
                                      open
                                          ? LucideIcons.chevronDown
                                          : LucideIcons.chevronRight,
                                      size: 13,
                                      color: tokens.textFaint,
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (open && e.detail != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(40, 4, 12, 8),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  icon: const Icon(LucideIcons.copy, size: 14),
                                  label: Text(l.logCopyDetails),
                                  onPressed: () => Clipboard.setData(
                                    ClipboardData(text: e.detail!),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
