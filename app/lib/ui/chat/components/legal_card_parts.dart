import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import 'legal_protocol.dart';
import '../../common/widgets.dart';
import '../../common/web_link.dart';

// The pieces the norms card and the case analysis share.

class LegalSection extends StatelessWidget {
  const LegalSection({super.key, required this.label, required this.body});

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    if (body.isEmpty) return const SizedBox.shrink();
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: text.labelSmall?.copyWith(
              color: tokens.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(body, style: text.bodySmall?.copyWith(height: 1.4)),
        ],
      ),
    );
  }
}

class LegalOfficialText extends StatelessWidget {
  const LegalOfficialText({
    super.key,
    required this.text,
    required this.caption,
    required this.url,
  });

  final String text;
  final String caption;
  final String url;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final theme = Theme.of(context).textTheme;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: OutlinedBox(
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
        color: tokens.panel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    caption.isEmpty
                        ? l.legalOfficialText
                        : l.legalOfficialTextOf(caption),
                    style: theme.labelSmall?.copyWith(
                      color: tokens.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (url.isNotEmpty)
                  LegalOpenLink(url: url, label: 'Normattiva'),
              ],
            ),
            const SizedBox(height: 4),
            SelectableText(
              text,
              style: theme.bodySmall?.copyWith(
                height: 1.45,
                color: tokens.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LegalOpenLink extends StatelessWidget {
  const LegalOpenLink({super.key, required this.url, this.label});

  final String url;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final uri = publicWebUri(url);
    final VoidCallback? open = uri == null
        ? null
        : () => openWebLink(context, uri);
    if (label == null) {
      return IconButton(
        tooltip: context.l10n.legalOpenOfficialText,
        visualDensity: VisualDensity.compact,
        iconSize: 13,
        color: tokens.textMuted,
        onPressed: open,
        icon: const Icon(LucideIcons.externalLink),
      );
    }
    return TextButton.icon(
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: const Size(0, 26),
        textStyle: Theme.of(context).textTheme.labelSmall,
      ),
      onPressed: open,
      icon: const Icon(LucideIcons.externalLink, size: 12),
      label: Text(label!),
    );
  }
}

class LegalFitBadge extends StatelessWidget {
  const LegalFitBadge({super.key, required this.fit});

  final String fit;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l = context.l10n;
    final (label, color) = switch (fit) {
      LegalFit.full => (l.legalFitFull, tokens.success),
      LegalFit.unfit => (l.legalFitUnfit, tokens.danger),
      LegalFit.doubtful => (l.legalFitDoubtful, tokens.warning),
      // No judgement given: said, never shown as "pertinente".
      _ => (l.legalFitUnrated, tokens.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppTheme.tintStrong),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

class LegalNotice extends StatelessWidget {
  const LegalNotice({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppTheme.tintSoft),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.triangleAlert, size: 13, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class LegalHeading extends StatelessWidget {
  const LegalHeading({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          Icon(icon, size: 13, color: tokens.textMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: tokens.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class LegalDegreeLabel extends StatelessWidget {
  const LegalDegreeLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        style: text.labelMedium,
      ),
    );
  }
}

/// "2026-05-30" -> "30/05/2026".
String legalDate(String iso) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(iso);
  return m == null ? iso : '${m[3]}/${m[2]}/${m[1]}';
}
