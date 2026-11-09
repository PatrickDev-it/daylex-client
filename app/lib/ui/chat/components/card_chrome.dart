import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../common/widgets.dart';

/// Shared chrome for component cards: header with icon, title and actions.
class ComponentFrame extends StatelessWidget {
  const ComponentFrame({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.footer,
    this.accent,
    this.padding = const EdgeInsets.all(12),
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;
  final Widget? footer;

  /// Tints the border, e.g. for approvals.
  final Color? accent;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    // Clipped so the ink of the rows inside stays within the rounded corners.
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: CardBox(
        borderColor: accent?.withValues(alpha: 0.45),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                children: [
                  Icon(icon, size: 15, color: accent ?? tokens.textMuted),
                  const SizedBox(width: 8),
                  // Title keeps priority; the subtitle gives way first.
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          flex: 3,
                          child: Text(
                            title,
                            style: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            flex: 2,
                            child: Text(
                              subtitle!,
                              style: text.labelSmall?.copyWith(color: tokens.textFaint),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  ...actions,
                ],
              ),
            ),
            Divider(color: tokens.border),
            Padding(padding: padding, child: child),
            if (footer != null) ...[Divider(color: tokens.border), footer!],
          ],
        ),
      ),
    );
  }
}

/// The box every chat card is drawn in: the surface, the app's border, the card radius.
class CardBox extends StatelessWidget {
  const CardBox({super.key, required this.child, this.padding, this.borderColor});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// Tints the border; the app's border colour when null.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => OutlinedBox(
    radius: AppTheme.radiusLg,
    color: Theme.of(context).colorScheme.surface,
    borderColor: borderColor,
    padding: padding,
    child: child,
  );
}

/// Lines a card up with the text column, no wider than [maxWidth].
class CardWidth extends StatelessWidget {
  const CardWidth({super.key, required this.maxWidth, required this.child});

  final double maxWidth;
  final Widget child;

  /// The widths cards grow to, by how much they show: a page thumbnail, a one-line result, a table or
  /// outline, the work of a turn, a table of changes, the case analysis with its two columns.
  static const narrow = 460.0;
  static const compact = 520.0;
  static const medium = 580.0;
  static const wide = 640.0;
  static const wider = 680.0;
  static const widest = 760.0;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// Small button used in component headers and footers.
class ComponentButton extends StatelessWidget {
  const ComponentButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
    this.danger = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primary;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final style = ButtonStyle(
      visualDensity: VisualDensity.compact,
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
      minimumSize: const WidgetStatePropertyAll(Size(0, 30)),
      textStyle: WidgetStatePropertyAll(Theme.of(context).textTheme.labelMedium),
    );
    final child = icon == null ? Text(label) : null;
    if (primary || danger) {
      final bg = danger ? tokens.danger : Theme.of(context).colorScheme.primary;
      return icon == null
          ? FilledButton(
              onPressed: onPressed,
              style: style.copyWith(backgroundColor: WidgetStatePropertyAll(bg)),
              child: child,
            )
          : FilledButton.icon(
              onPressed: onPressed,
              style: style.copyWith(backgroundColor: WidgetStatePropertyAll(bg)),
              icon: Icon(icon, size: 13),
              label: Text(label),
            );
    }
    return icon == null
        ? OutlinedButton(onPressed: onPressed, style: style, child: child)
        : OutlinedButton.icon(onPressed: onPressed, style: style, icon: Icon(icon, size: 13), label: Text(label));
  }
}
