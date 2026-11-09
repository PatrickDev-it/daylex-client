import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import 'card_expansion.dart';
import 'card_props.dart';
import 'card_chrome.dart';
import 'legal_card_parts.dart';
import 'legal_protocol.dart';

/// The norms a reply relies on: one expandable row per article, with what it
/// says, how it applies to the facts, why it and not its neighbours, how it
/// was found, and the official text. Props: see [UiComponents.norms].
class NormsCard extends StatelessWidget {
  const NormsCard({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  Widget build(BuildContext context) {
    final norms = propMaps(props['norms']);
    if (norms.isEmpty) return const SizedBox.shrink();
    final discarded = propMaps(props['discarded']);
    final l = context.l10n;
    return CardWidth(
      maxWidth: CardWidth.wide,
      child: ComponentFrame(
        icon: LucideIcons.scale,
        title: propStr(props['title'], l.legalNormsTitle),
        // The text is the official one; how each norm applies is the agent's reading, and says so.
        subtitle: [
          l.legalArticles(norms.length),
          l.legalOfficialTextLower,
          if (norms
                  .where(
                    (n) =>
                        propStr(n['fit']) != LegalFit.full ||
                        propStr(n['warning']).isNotEmpty,
                  )
                  .length
              case final open when open > 0)
            l.legalToVerify(open),
        ].join(' · '),
        padding: EdgeInsets.zero,
        footer: discarded.isEmpty ? null : _DiscardedNorms(items: discarded),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final n in norms) NormTile(norm: n)],
        ),
      ),
    );
  }
}

/// One article, collapsed to its reference and summary.
class NormTile extends StatelessWidget {
  const NormTile({super.key, required this.norm});

  final Map<String, dynamic> norm;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final rubrica = propStr(norm['rubrica']);
    final warning = propStr(norm['warning']);
    final vigenza = legalDate(propStr(norm['vigenza']));
    final url = propStr(norm['url']);
    return CardExpansion(
      title: Row(
        children: [
          Flexible(
            child: Text(
              propStr(norm['ref']),
              style: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          LegalFitBadge(fit: propStr(norm['fit'])),
          if (warning.isNotEmpty) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: warning,
              child: Icon(
                LucideIcons.triangleAlert,
                size: 13,
                color: tokens.warning,
              ),
            ),
          ],
        ],
      ),
      subtitle: rubrica,
      children: [
        if (warning.isNotEmpty)
          LegalNotice(text: warning, color: tokens.warning),
        LegalSection(label: l.legalWhatItSays, body: propStr(norm['summary'])),
        LegalSection(label: l.legalHowItApplies, body: propStr(norm['link'])),
        LegalSection(label: l.legalWhyThisNorm, body: propStr(norm['why'])),
        if (propStr(norm['text']).isNotEmpty)
          LegalOfficialText(
            text: propStr(norm['text']),
            caption: [
              if (propStr(norm['act']).isNotEmpty) propStr(norm['act']),
              if (vigenza.isNotEmpty) l.legalInForceAt(vigenza),
            ].join(' · '),
            url: url,
          ),
      ],
    );
  }
}

class _DiscardedNorms extends StatelessWidget {
  const _DiscardedNorms({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    return CardExpansion(
      dense: true,
      title: Text(
        context.l10n.legalDiscardedNorms(items.length),
        style: text.labelMedium?.copyWith(color: tokens.textMuted),
      ),
      children: [
        for (final d in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: propStr(d['ref']),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (propStr(d['rubrica']).isNotEmpty)
                    TextSpan(
                      text: ' (${propStr(d['rubrica'])})',
                      style: TextStyle(color: tokens.textFaint),
                    ),
                  TextSpan(text: ': ${propStr(d['reason'])}'),
                ],
              ),
              style: text.bodySmall,
            ),
          ),
      ],
    );
  }
}
