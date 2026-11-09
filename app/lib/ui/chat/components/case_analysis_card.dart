import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import 'card_expansion.dart';
import 'card_props.dart';
import 'card_chrome.dart';
import 'legal_card_parts.dart';
import 'source_link.dart';
import '../../../features/agent/domain/source_reference.dart';
import 'legal_protocol.dart';
import 'norms_card.dart';

/// Below this width the two parties' strategies stack instead of standing side by side.
const _twoColumnsMinWidth = 560.0;

/// Links by degree and strategies by side, each built on quotes of the case
/// file. Props: see [UiComponents.caseAnalysis].
class CaseAnalysisCard extends StatelessWidget {
  const CaseAnalysisCard({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  Widget build(BuildContext context) {
    final links = propMaps(props['links']);
    if (links.isEmpty) return const SizedBox.shrink();
    final strategies = propMaps(props['strategies']);
    final norms = propMaps(props['norms']);
    final dropped = propStrings(props['dropped']);
    final parties = propMap(props['parties']);
    final l = context.l10n;
    final client = propStr(parties['client'], l.legalClient);
    final opponent = propStr(parties['opponent'], l.legalOpponent);
    final degrees = {
      1: l.legalDegree1Detail,
      2: l.legalDegree2Detail,
      3: l.legalDegree3Detail,
    };
    return CardWidth(
      maxWidth: CardWidth.widest,
      child: ComponentFrame(
        icon: LucideIcons.network,
        title: propStr(props['title'], l.legalCaseAnalysis),
        subtitle: '$client · $opponent',
        padding: EdgeInsets.zero,
        footer: dropped.isEmpty ? null : _Dropped(reasons: dropped),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LegalHeading(icon: LucideIcons.link, label: l.legalLinks),
            for (final MapEntry(key: degree, value: detail)
                in degrees.entries) ...[
              if (links.any((link) => link['degree'] == degree)) ...[
                LegalDegreeLabel(label: detail),
                for (final link in links.where(
                  (link) => link['degree'] == degree,
                ))
                  _LinkTile(link: link),
              ],
            ],
            if (strategies.isNotEmpty) ...[
              LegalHeading(icon: LucideIcons.swords, label: l.legalStrategies),
              LayoutBuilder(
                builder: (context, c) {
                  final ours = _PartyColumn(
                    name: client,
                    ours: true,
                    strategies: strategies
                        .where((s) => s['party'] == LegalParty.client)
                        .toList(),
                  );
                  final theirs = _PartyColumn(
                    name: opponent,
                    ours: false,
                    strategies: strategies
                        .where((s) => s['party'] == LegalParty.opponent)
                        .toList(),
                  );
                  if (c.maxWidth < _twoColumnsMinWidth) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [ours, theirs],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: ours),
                      Expanded(child: theirs),
                    ],
                  );
                },
              ),
            ],
            if (norms.isNotEmpty) ...[
              LegalHeading(icon: LucideIcons.scale, label: l.legalNorms),
              for (final n in norms) NormTile(norm: n),
            ],
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.link});

  final Map<String, dynamic> link;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final effect = propStr(link['effect'], LegalEffect.neutral);
    final color = switch (effect) {
      LegalEffect.favourable => tokens.success,
      LegalEffect.unfavourable => tokens.danger,
      _ => tokens.textFaint,
    };
    final elements = propMaps(link['elements']);
    return CardExpansion(
      leading: Tooltip(
        message: switch (effect) {
          LegalEffect.favourable => l.legalEffectFavourable,
          LegalEffect.unfavourable => l.legalEffectUnfavourable,
          _ => l.legalEffectNeutral,
        },
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${propStr(link['id'])}  ',
              style: TextStyle(color: tokens.textFaint),
            ),
            TextSpan(text: propStr(link['title'])),
          ],
        ),
        style: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: propStr(link['reasoning']),
      children: [
        LegalSection(label: l.legalReasoning, body: propStr(link['reasoning'])),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            l.legalElements(elements.length),
            style: text.labelSmall?.copyWith(color: tokens.textMuted),
          ),
        ),
        for (final e in elements) _Element(element: e),
      ],
    );
  }
}

class _Element extends StatelessWidget {
  const _Element({required this.element});

  final Map<String, dynamic> element;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final isNorm = element['kind'] == legalElementNorm;
    final doc = element['doc'];
    final where = isNorm
        ? propStr(element['rubrica'])
        : doc == 0
        ? l.legalFromRequest
        : l.legalDocRef('$doc', propStr(element['name']), '${element['page']}');
    final url = propStr(element['url']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              isNorm ? LucideIcons.scale : LucideIcons.fileText,
              size: 13,
              color: tokens.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  isNorm
                      ? propStr(element['ref'])
                      : '«${propStr(element['quote'])}»',
                  style: text.bodySmall?.copyWith(
                    fontStyle: isNorm ? null : FontStyle.italic,
                    fontWeight: isNorm ? FontWeight.w600 : null,
                  ),
                ),
                if (!isNorm &&
                    doc != 0 &&
                    propStr(element['name']).isNotEmpty &&
                    element['page'] is num)
                  SourceLink(
                    SourceReference(
                      propStr(element['name']),
                      (element['page'] as num).toInt(),
                      quote: propStr(element['quote']),
                    ),
                  )
                else if (where.isNotEmpty)
                  Text(
                    where,
                    style: text.labelSmall?.copyWith(color: tokens.textFaint),
                  ),
              ],
            ),
          ),
          if (isNorm && url.isNotEmpty) LegalOpenLink(url: url),
        ],
      ),
    );
  }
}

class _PartyColumn extends StatelessWidget {
  const _PartyColumn({
    required this.name,
    required this.ours,
    required this.strategies,
  });

  final String name;
  final bool ours;
  final List<Map<String, dynamic>> strategies;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
          child: Text(
            ours
                ? context.l10n.legalOurClientNamed(name)
                : context.l10n.legalOpponentNamed(name),
            style: text.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: tokens.textMuted,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (strategies.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
            child: Text(
              context.l10n.legalNoStrategy,
              style: text.bodySmall?.copyWith(color: tokens.textFaint),
            ),
          ),
        for (final kind in LegalStrategyKind.all)
          for (final s in strategies.where((s) => s['kind'] == kind))
            _StrategyTile(strategy: s, ours: ours),
      ],
    );
  }
}

class _StrategyTile extends StatelessWidget {
  const _StrategyTile({required this.strategy, required this.ours});

  final Map<String, dynamic> strategy;
  final bool ours;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final attack = strategy['kind'] == LegalStrategyKind.attack;
    final counter = propStr(strategy['counter']);
    final links = propStrings(strategy['links']);
    return CardExpansion(
      leading: Tooltip(
        message: attack ? l.legalAttack : l.legalDefence,
        child: Icon(
          attack ? LucideIcons.swords : LucideIcons.shield,
          size: 14,
          color: tokens.textMuted,
        ),
      ),
      title: Text(
        propStr(strategy['title']),
        style: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: propStr(strategy['move']),
      children: [
        LegalSection(
          label: attack ? l.legalMove : l.legalDefence,
          body: propStr(strategy['move']),
        ),
        if (counter.isNotEmpty)
          LegalSection(
            label: ours ? l.legalExpectedReply : l.legalOurCounter,
            body: counter,
          ),
        if (links.isNotEmpty)
          Text(
            l.legalBasedOn(links.join(', ')),
            style: text.labelSmall?.copyWith(color: tokens.textFaint),
          ),
      ],
    );
  }
}

class _Dropped extends StatelessWidget {
  const _Dropped({required this.reasons});

  final List<String> reasons;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    return CardExpansion(
      dense: true,
      title: Text(
        context.l10n.legalDroppedLinks(reasons.length),
        style: text.labelMedium?.copyWith(color: tokens.textMuted),
      ),
      children: [
        for (final r in reasons)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '• $r',
              style: text.bodySmall?.copyWith(color: tokens.textMuted),
            ),
          ),
      ],
    );
  }
}
