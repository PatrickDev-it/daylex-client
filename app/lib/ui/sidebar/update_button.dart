import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../features/agent/agent_controller.dart';
import '../../features/update/update_controller.dart';
import '../../l10n/l10n.dart';
import '../app_actions.dart';

/// The blue button at the bottom of the sidebar that says a newer version has arrived: it fills while the
/// version downloads, then restarts the app into it, after a word of confirmation.
class UpdateButton extends ConsumerWidget {
  const UpdateButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(updateProvider);
    if (!update.offered) return const SizedBox.shrink();
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final blocked = update.phase == UpdatePhase.blocked;
    final (icon, label) = switch (update.phase) {
      UpdatePhase.downloading => (
        LucideIcons.arrowDownToLine,
        l.updateDownloading((update.progress * 100).round()),
      ),
      UpdatePhase.installing => (LucideIcons.rotateCw, l.updateInstalling),
      UpdatePhase.blocked => (LucideIcons.triangleAlert, l.updateBlocked),
      _ => (LucideIcons.circleArrowDown, l.updateReady),
    };
    final background = blocked ? scheme.errorContainer : scheme.primary;
    final foreground = blocked ? scheme.onErrorContainer : scheme.onPrimary;
    final clickable = update.phase == UpdatePhase.ready || blocked;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Tooltip(
        message: l.updateTooltip(update.release?.version ?? ''),
        child: Material(
          color: background.withValues(
            alpha: clickable ? 1 : AppTheme.hoverFade,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: clickable ? () => showUpdateDialog(ref) : null,
            child: Stack(
              children: [
                // The download fills the button from the left, like a progress bar.
                if (update.phase == UpdatePhase.downloading)
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: update.progress.clamp(0, 1),
                      child: ColoredBox(color: scheme.primary),
                    ),
                  ),
                SizedBox(
                  height: AppTheme.controlHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(icon, size: 16, color: foreground),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            label,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: foreground),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What the new version is, why it cannot install by itself if it cannot, and the restart that installs it.
/// The work is saved before the app quits.
Future<void> showUpdateDialog(WidgetRef ref) async {
  final context = navigatorKey.currentContext;
  final update = ref.read(updateProvider);
  final release = update.release;
  if (context == null || release == null) return;
  final target = ref.read(updateEnvironmentProvider)?.installer.target ?? '';
  final running = ref.read(agentProvider).running;
  final restart = await showDialog<bool>(
    context: context,
    builder: (context) {
      final l = context.l10n;
      final text = Theme.of(context).textTheme;
      final scheme = Theme.of(context).colorScheme;
      final problem = switch (update.problem) {
        InstallProblem.notWritable => l.updateProblemNotWritable(target),
        InstallProblem.notInstalled => l.updateProblemNotInstalled,
        null =>
          update.installFailed
              ? l.updateInstallFailed(UpdateController.logPath)
              : null,
      };
      final canInstall = update.problem == null;
      return AlertDialog(
        title: Text(l.updateDialogTitle(release.version)),
        content: SizedBox(
          width: AppTheme.dialogWidth,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(problem ?? l.updateDialogBody),
                if (release.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(l.updateNotes, style: text.titleSmall),
                  const SizedBox(height: 4),
                  SelectableText(release.notes.trim(), style: text.bodySmall),
                ],
                if (canInstall && running > 0) ...[
                  const SizedBox(height: 16),
                  Text(
                    l.updateRunningWarning(running),
                    style: text.bodyMedium?.copyWith(color: scheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.updateLater),
          ),
          if (canInstall)
            FilledButton(
              autofocus: true,
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                update.installFailed ? l.updateRetry : l.updateRestart,
              ),
            ),
        ],
      );
    },
  );
  if (restart != true) return;
  if (!AppActions(ref).saveNow()) {
    toast(ref.read(l10nProvider).exitUnsavedHelp);
    return;
  }
  await ref.read(updateProvider.notifier).install();
}
