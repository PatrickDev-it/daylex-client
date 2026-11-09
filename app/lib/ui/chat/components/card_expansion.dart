import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// The collapsible row the cards share: a title (and a faint subtitle) that opens onto its details.
class CardExpansion extends StatelessWidget {
  const CardExpansion({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.leading,
    this.dense = false,
  });

  final Widget title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> children;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    // Its own Material: the card's coloured frame would hide the ink otherwise.
    return Material(
      type: MaterialType.transparency,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          tilePadding: EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 0 : 2),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          minTileHeight: dense ? AppTheme.controlHeight : AppTheme.toolbarHeight,
          leading: leading,
          iconColor: tokens.textMuted,
          collapsedIconColor: tokens.textFaint,
          title: title,
          subtitle: subtitle == null || subtitle!.isEmpty
              ? null
              : Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: tokens.textMuted),
                ),
          children: children,
        ),
      ),
    );
  }
}
