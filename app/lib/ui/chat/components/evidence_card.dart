import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/agent/domain/source_reference.dart';
import '../../../l10n/l10n.dart';
import 'card_expansion.dart';
import 'card_props.dart';
import 'source_link.dart';

/// The API's recorded passages. Structural traceability never becomes a legal approval badge.
class EvidenceCard extends StatelessWidget {
  const EvidenceCard({super.key, required this.props});
  final Map<String, dynamic> props;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final tokens = AppTokens.of(context);
    final pack = propMap(props['pack']);
    final claims = propMaps(props['claims']);
    final sources = {
      for (final source in propMaps(pack['sources']))
        propStr(source['source_id']): source,
    };
    final citations = {
      for (final citation in propMaps(pack['citations']))
        propStr(citation['id']): citation,
    };
    final used = claims.expand((c) => propStrings(c['source_ids'])).toSet();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: CardExpansion(
        leading: Icon(
          LucideIcons.bookOpenCheck,
          size: 18,
          color: tokens.textMuted,
        ),
        title: Text(l.evidenceTitle, style: text.labelLarge),
        subtitle: l.evidenceSummary(claims.length, used.length),
        children: [
          Text(
            l.evidenceQualification,
            style: text.bodySmall?.copyWith(
              color: tokens.textMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          if (claims.isEmpty) Text(l.evidenceNoClaims, style: text.bodySmall),
          for (final claim in claims)
            _ClaimEvidence(
              claim: claim,
              sources: sources,
              citations: citations,
            ),
        ],
      ),
    );
  }
}

class _ClaimEvidence extends StatelessWidget {
  const _ClaimEvidence({
    required this.claim,
    required this.sources,
    required this.citations,
  });
  final Map<String, dynamic> claim;
  final Map<String, Map<String, dynamic>> sources;
  final Map<String, Map<String, dynamic>> citations;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final tokens = AppTokens.of(context);
    final ids = propStrings(claim['citation_ids']);
    final sourceIds = propStrings(claim['source_ids']);
    final unresolved =
        propList(claim['unresolved_ids']).isNotEmpty ||
        sourceIds.any((id) => !sources.containsKey(id)) ||
        ids.any(
          (id) =>
              !citations.containsKey(id) ||
              citations[id]?['structural_verdict'] != 'verified' ||
              !sources.containsKey(propStr(citations[id]?['source_id'])),
        );
    final status = unresolved
        ? l.evidenceUnresolved
        : switch (propStr(claim['status'])) {
            'traceable' when ids.isNotEmpty => l.evidenceTraceable,
            'inference' => l.evidenceInference,
            'unsupported' => l.evidenceUnsupported,
            _ => l.evidenceUnknown,
          };
    return CardExpansion(
      dense: true,
      title: Text(
        propStr(claim['claim']),
        style: text.bodySmall,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: status,
      children: [
        SelectableText(propStr(claim['claim']), style: text.bodyMedium),
        for (final id in ids)
          if (citations[id] case final citation?) ...[
            const SizedBox(height: 10),
            _Passage(
              citation: citation,
              source: sources[propStr(citation['source_id'])] ?? const {},
            ),
          ],
        if (ids.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(l.evidenceNoPassage, style: text.bodySmall),
          ),
        const SizedBox(height: 8),
        Text(
          l.evidenceSemanticPending,
          style: text.bodySmall?.copyWith(color: tokens.textMuted),
        ),
      ],
    );
  }
}

class _Passage extends StatelessWidget {
  const _Passage({required this.citation, required this.source});
  final Map<String, dynamic> citation;
  final Map<String, dynamic> source;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final name = propStr(source['name']);
    final page = propInt(source['page']);
    final quote = propStr(citation['quote']);
    final stamp = DateTime.tryParse(propStr(source['effective_on']));
    final voice = switch (propStr(source['voice'])) {
      'legislatore' => l.evidenceLegislator,
      'corte' || 'giudice' => l.evidenceCourt,
      'parte' => l.evidenceParty,
      _ => '',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (source['origin'] == 'case_document' && name.isNotEmpty && page > 0)
          SourceLink(
            SourceReference(
              name,
              page,
              sourceId: propStr(source['original_sha256']),
              quote: quote,
              unit: name.toLowerCase().endsWith('.pdf') ? 'page' : 'section',
            ),
          )
        else
          Text(name.isEmpty ? l.evidenceSource : name, style: text.labelLarge),
        if (voice.isNotEmpty) Text(voice, style: text.labelMedium),
        if (stamp != null)
          Text(
            l.evidenceVersion(
              '${stamp.day.toString().padLeft(2, '0')}/${stamp.month.toString().padLeft(2, '0')}/${stamp.year}',
            ),
            style: text.labelMedium,
          ),
        if (source['uncertain_transcription'] == true)
          Text(l.evidenceUncertain, style: text.bodySmall),
        const SizedBox(height: 6),
        SelectableText(quote, style: text.bodySmall?.copyWith(height: 1.5)),
      ],
    );
  }
}
