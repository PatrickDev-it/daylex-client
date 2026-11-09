import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../features/document/data/doc_templates.dart';
import '../../features/document/model/document.dart';
import '../../l10n/l10n.dart';
import '../../l10n/labels.dart';
import '../shortcuts.dart';

/// Icon button with a tooltip that names its keyboard shortcut, if it has one.
class ToolbarButton extends StatelessWidget {
  const ToolbarButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.shortcut,
    this.selected = false,
    this.size,
  });

  final IconData icon;
  final String tooltip;
  final AppShortcut? shortcut;
  final VoidCallback? onPressed;
  final bool selected;

  /// A smaller (or larger) square than the theme's 32.
  final double? size;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final sized = size == null
        ? null
        : IconButton.styleFrom(minimumSize: Size.square(size!), fixedSize: Size.square(size!), iconSize: size! / 2);
    final style = selected
        ? IconButton.styleFrom(
            backgroundColor: tokens.hover,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
          ).merge(sized)
        : sized;
    return Tooltip(
      message: shortcut == null ? tooltip : '$tooltip  ·  ${shortcut!.keys}',
      child: IconButton(onPressed: onPressed, icon: Icon(icon), style: style),
    );
  }
}

/// Small rounded label, e.g. document status. [busy] puts a spinner where the icon goes.
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.color, this.icon, this.busy = false, this.outlined = false});

  final String label;
  final Color? color;
  final IconData? icon;
  final bool busy;

  /// On the surface with a border, for a pill that floats over content.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final c = color ?? tokens.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: outlined ? Theme.of(context).colorScheme.surface : c.withValues(alpha: AppTheme.tintSoft),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: outlined ? Border.all(color: tokens.border) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy) ...[
            SizedBox.square(dimension: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: c)),
            const SizedBox(width: 6),
          ] else if (icon != null) ...[
            Icon(icon, size: 11, color: c),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: c, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// A document's status, in the colour that says how far along it is.
class DocStatusPill extends StatelessWidget {
  const DocStatusPill(this.status, {super.key});

  final DocumentStatus status;

  static Color colorOf(BuildContext context, DocumentStatus status) {
    final tokens = AppTokens.of(context);
    return switch (status) {
      DocumentStatus.draft => tokens.textMuted,
      DocumentStatus.review => tokens.warning,
      DocumentStatus.approved => tokens.success,
    };
  }

  @override
  Widget build(BuildContext context) => Pill(context.l10n.docStatus(status), color: colorOf(context, status));
}

/// Keyboard key hint, e.g. `Ctrl K`.
class KeyHint extends StatelessWidget {
  const KeyHint(this.keys, {super.key});

  final String keys;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
      ),
      child: Text(keys, style: AppText.of(context).keycap),
    );
  }
}

/// A box with the app's border, for cards, lists and settings sections.
class OutlinedBox extends StatelessWidget {
  const OutlinedBox({
    super.key,
    required this.child,
    this.padding,
    this.radius = AppTheme.radius,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: borderColor ?? AppTokens.of(context).border),
      borderRadius: BorderRadius.circular(radius),
    ),
    child: child,
  );
}

/// Builds its child knowing whether the pointer is over it.
class HoverBuilder extends StatefulWidget {
  const HoverBuilder({super.key, required this.builder, this.cursor = MouseCursor.defer});

  final Widget Function(BuildContext context, bool hover) builder;
  final MouseCursor cursor;

  @override
  State<HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<HoverBuilder> {
  var _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: widget.cursor,
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: widget.builder(context, _hover),
  );
}

/// The bar on top of a side-panel tab: the same height and padding in every tab.
class PanelToolbar extends StatelessWidget {
  const PanelToolbar({super.key, required this.children, this.color});

  final List<Widget> children;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    height: AppTheme.toolbarHeight,
    color: color,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Row(children: children),
  );
}

/// A template to start a document from: its accent on a paper swatch, its name, what it holds, its pages.
class TemplateTile extends StatelessWidget {
  const TemplateTile({super.key, required this.template, required this.onTap});

  final DocTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final accent = Color(template.accent);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: onTap,
        child: OutlinedBox(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: AppTheme.tintStrong),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                  border: Border(top: BorderSide(color: accent, width: 3)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(template.name, style: text.labelLarge),
                    Text(template.description, style: text.bodySmall, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Pill(context.l10n.pageCount(template.pageCount)),
              const SizedBox(width: 6),
              Icon(LucideIcons.plus, size: 14, color: tokens.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pulsing placeholder used while content loads.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 12, this.radius = AppTheme.radiusXs});

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  /// One breath of the pulse: slower than any transition, so it reads as waiting, not as motion.
  static const _pulse = Duration(milliseconds: 1100);

  late final _controller = AnimationController(vsync: this, duration: _pulse)..repeat(reverse: true);
  late final _opacity = Tween(
    begin: 0.45,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _opacity,
    child: Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: AppTokens.of(context).border,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedBox(
              radius: AppTheme.radiusLg,
              color: Theme.of(context).colorScheme.surface,
              child: SizedBox.square(dimension: 42, child: Icon(icon, size: 20, color: tokens.textMuted)),
            ),
            const SizedBox(height: 16),
            Text(title, style: text.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              message,
              style: text.bodyMedium?.copyWith(color: tokens.textMuted),
              textAlign: TextAlign.center,
            ),
            if (actions.isNotEmpty) ...[const SizedBox(height: 20), Wrap(spacing: 8, runSpacing: 8, children: actions)],
          ],
        ),
      ),
    );
  }
}
