import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../features/agent/agent_controller.dart';
import '../../features/agent/domain/agent_protocol.dart';
import '../../features/workspace/ui_state.dart';
import '../../features/workspace/workspace_state.dart';
import '../../l10n/l10n.dart';

/// Files and folders dropped anywhere on the window join the open chat (or the new chat being
/// written), exactly as if picked with the + button.
class FileDrop extends ConsumerStatefulWidget {
  const FileDrop({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FileDrop> createState() => _FileDropState();
}

class _FileDropState extends ConsumerState<FileDrop> {
  var _over = false;

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(uiProvider);
    final thread = ref.watch(activeThreadProvider);
    final target = ui.section == AppSection.chat ? thread?.id ?? AgentController.draftId : null;

    return DropTarget(
      enable: target != null,
      onDragEntered: (_) => setState(() => _over = true),
      onDragExited: (_) => setState(() => _over = false),
      onDragDone: (details) async {
        setState(() => _over = false);
        final messenger = ScaffoldMessenger.maybeOf(context);
        final l = context.l10n;
        showLeftOut(messenger, l, await ref.read(agentProvider.notifier).addFiles(target!, details.files));
      },
      child: Stack(
        children: [
          widget.child,
          if (_over) const Positioned.fill(child: IgnorePointer(child: _DropOverlay())),
        ],
      ),
    );
  }
}

/// Tells the lawyer which files picked or dropped were not attached, and why: one line per reason.
void showLeftOut(ScaffoldMessengerState? messenger, AppLocalizations l, LeftOut left) {
  if (left.isEmpty) return;
  String names(List<String> files) => '${files.take(3).join(', ')}${files.length > 3 ? '…' : ''}';
  final lines = [
    if (left.wrongType.isNotEmpty)
      l.chatDropNotAttached(left.wrongType.length, names(left.wrongType), AgentController.attachable.join(', ')),
    if (left.tooLarge.isNotEmpty)
      l.chatDropTooLarge(left.tooLarge.length, names(left.tooLarge), maxAttachmentBytes ~/ (1024 * 1024)),
    if (left.unreadable.isNotEmpty) l.chatDropUnreadable(left.unreadable.length, names(left.unreadable)),
  ];
  messenger?.showSnackBar(SnackBar(content: Text(lines.join('\n'))));
}

class _DropOverlay extends StatelessWidget {
  const _DropOverlay();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final l = context.l10n;
    return ColoredBox(
      color: theme.colorScheme.surface.withValues(alpha: 0.85),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: accent, width: 2),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.fileUp, size: 32, color: accent),
                const SizedBox(height: 12),
                Text(l.chatDropTitle, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(l.chatDropFormats, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
