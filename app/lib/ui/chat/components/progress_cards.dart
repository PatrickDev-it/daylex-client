import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

export 'progress_timeline.dart';
import '../../../l10n/l10n.dart';
import 'card_expansion.dart';
import 'card_props.dart';
import 'card_chrome.dart';

/// The matrix of an attached decision, built before the writing: what it
/// proves, decides and why, what the parties argued, each with its page.
/// Props: see [UiComponents.matrix].
class MatrixCard extends StatelessWidget {
  const MatrixCard({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  Widget build(BuildContext context) {
    final sections = propMaps(props['sections']);
    if (sections.isEmpty) return const SizedBox.shrink();
    final pages = propStrings(props['pages']);
    final entries = sections.fold<int>(
      0,
      (n, s) => n + propList(s['items']).length,
    );
    final l = context.l10n;
    return CardWidth(
      maxWidth: CardWidth.wide,
      child: ComponentFrame(
        icon: LucideIcons.tableProperties,
        title: propStr(props['title'], l.cardMatrixTitle),
        subtitle: [
          l.cardMatrixEntries(entries),
          if (pages.isNotEmpty) l.cardMatrixPagesRead(pages.join(', ')),
        ].join(' · '),
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final s in sections) _MatrixSection(section: s)],
        ),
      ),
    );
  }
}

class _MatrixSection extends StatelessWidget {
  const _MatrixSection({required this.section});

  final Map<String, dynamic> section;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final items = propStrings(section['items']);
    return CardExpansion(
      dense: true,
      title: Text(
        '${propStr(section['title'])} (${items.length})',
        style: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: SelectableText(
              '• $item',
              style: text.bodySmall?.copyWith(height: 1.4),
            ),
          ),
      ],
    );
  }
}
