import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/agent/presentation/ui_components.dart';
import '../../../l10n/l10n.dart';
import '../../common/elapsed_time.dart';
import 'card_props.dart';

/// Observed operations; old steps are not legal approvals.
class ProgressCard extends StatefulWidget {
  const ProgressCard({super.key, required this.props});
  final Map<String, dynamic> props;
  @override
  State<ProgressCard> createState() => _ProgressCardState();
}

class _ProgressCardState extends State<ProgressCard> {
  var _expanded = false;
  @override
  Widget build(BuildContext context) {
    final props = widget.props;
    final steps = propMaps(props['steps']);
    if (steps.isEmpty) return const SizedBox.shrink();
    final running = propBool(props['running']);
    final status = propStr(
      props['status'],
      running ? CardStatus.running : CardStatus.done,
    );
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final title = switch (status) {
      CardStatus.error => l.progressFailed,
      CardStatus.rejected => l.progressStopped,
      CardStatus.done => l.progressCompleted,
      _ => l.cardProgressRunning,
    };
    final icon = switch (status) {
      CardStatus.error => LucideIcons.circleAlert,
      CardStatus.rejected => LucideIcons.square,
      CardStatus.done => LucideIcons.check,
      _ => LucideIcons.activity,
    };
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(
                  icon,
                  size: 16,
                  color: status == CardStatus.error
                      ? tokens.danger
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              ElapsedTime(
                startedAt: DateTime.tryParse(propStr(props['startedAt'])),
                running: running,
                seconds: propInt(props['seconds']),
                style: text.labelMedium?.copyWith(color: tokens.textMuted),
              ),
            ],
          ),
          if (running) ...[
            const SizedBox(height: 10),
            Semantics(
              liveRegion: true,
              child: _ProgressStep(step: steps.last, current: true),
            ),
          ],
          if (steps.length > 1 || !running)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(
                  _expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  size: 14,
                ),
                label: Text(
                  _expanded
                      ? l.progressHideSteps
                      : l.progressShowSteps(steps.length),
                ),
              ),
            ),
          if (_expanded) ...[
            const Divider(height: 16),
            for (final step in (running ? steps.take(steps.length - 1) : steps))
              _ProgressStep(step: step, current: false),
          ],
        ],
      ),
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({required this.step, required this.current});
  final Map<String, dynamic> step;
  final bool current;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = AppTokens.of(context);
    final detail = propStr(step['detail']);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!current) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Icon(LucideIcons.circle, size: 8, color: tokens.textMuted),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(propStr(step['label']), style: text.bodyMedium),
                if (detail.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      detail,
                      style: text.bodySmall?.copyWith(
                        color: tokens.textMuted,
                        height: 1.45,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!current) ...[
            const SizedBox(width: 8),
            Text(
              elapsedLabel(propInt(step['at'])),
              style: text.labelSmall?.copyWith(color: tokens.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
