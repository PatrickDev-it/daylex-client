import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/agent/presentation/ui_components.dart';
import '../../../l10n/l10n.dart';
import 'card_props.dart';

/// Actual receipt; protocol names and arguments stay out of the conversation.
class ToolStep extends StatelessWidget {
  const ToolStep({super.key, required this.props});
  final Map<String, dynamic> props;
  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final status = propStr(props['status'], CardStatus.running);
    final (icon, label, color) = switch (status) {
      CardStatus.done => (
        LucideIcons.check,
        l.operationApplied,
        tokens.success,
      ),
      CardStatus.error => (
        LucideIcons.circleAlert,
        l.operationFailed,
        tokens.danger,
      ),
      CardStatus.interrupted => (
        LucideIcons.circleAlert,
        l.operationUncertain,
        tokens.textMuted,
      ),
      CardStatus.rejected => (
        LucideIcons.ban,
        l.operationNotApplied,
        tokens.textMuted,
      ),
      _ => (
        LucideIcons.activity,
        l.operationRunning,
        Theme.of(context).colorScheme.primary,
      ),
    };
    final detail = status == CardStatus.interrupted
        ? l.operationVerificationHint
        : propStr(props['detail']);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  propStr(props['title']),
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(label, style: text.labelSmall?.copyWith(color: color)),
                if (detail.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: SelectableText(
                      detail,
                      style: text.bodySmall?.copyWith(color: tokens.textMuted),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
