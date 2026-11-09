import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/document/model/document.dart';
import '../../features/workspace/document_review.dart';
import '../../l10n/l10n.dart';
import '../chat/components/card_expansion.dart';

/// One compact status, expandable into localised findings. Never hides the draft.
class DocumentReviewStrip extends ConsumerWidget {
  const DocumentReviewStrip({super.key, required this.document});
  final PaperDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final review = ref.watch(documentReviewProvider(document));
    if (review.isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(l.reviewRunning),
      );
    }
    if (review.hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(l.reviewUnavailable)),
            TextButton(
              onPressed: () => ref.invalidate(documentReviewProvider(document)),
              child: Text(l.sourceRetry),
            ),
          ],
        ),
      );
    }
    final result = review.value!;
    final confirmed = ref.watch(confirmedTermsProvider);
    if (result.issues.isEmpty && result.pdfIssues.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(l.reviewClean),
      );
    }
    return CardExpansion(
      title: Text(
        result.canExportWith(confirmed) ? l.reviewAdvisory : l.reviewRequired,
      ),
      subtitle: l.reviewHelp,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 180),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final issue in result.issues)
                ListTile(
                  dense: true,
                  title: Text(
                    '${issue.page == 0 ? l.reviewMetadata : l.pageNumber(issue.page)} · «${issue.text}»',
                  ),
                  subtitle: Text(
                    '${issue.message}${issue.protected ? ' ${l.reviewProtected}' : ''}',
                  ),
                  trailing: issue.blocking
                      ? TextButton(
                          onPressed:
                              confirmed.contains(
                                '${result.revision}:${issue.key}',
                              )
                              ? null
                              : () => ref
                                    .read(confirmedTermsProvider.notifier)
                                    .confirm(result.revision, issue.key),
                          child: Text(
                            confirmed.contains(
                                  '${result.revision}:${issue.key}',
                                )
                                ? l.reviewConfirmed
                                : l.reviewKeepTerm,
                          ),
                        )
                      : null,
                ),
              for (final issue in result.pdfIssues)
                ListTile(title: Text(issue)),
            ],
          ),
        ),
      ],
    );
  }
}
