import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../agent/agent_controller.dart';
import '../document/model/document.dart';
import '../document/model/document_review.dart';
import 'pdf_export.dart';
import 'workspace_state.dart';

final confirmedTermsProvider = NotifierProvider<ConfirmedTerms, Set<String>>(
  ConfirmedTerms.new,
);

class ConfirmedTerms extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};
  void confirm(String revision, String issueKey) =>
      state = {...state, '$revision:$issueKey'};
}

final documentReviewerProvider = Provider<DocumentReviewer>((ref) {
  final client = ref.watch(agentClientProvider);
  if (client is DocumentReviewer) return client as DocumentReviewer;
  throw const DocumentReviewFailure(
    'Collega il server per verificare il documento prima dell’esportazione.',
  );
});

/// Immutable document identity is the revision: a later edit cannot reuse an earlier verdict.
final documentReviewProvider = FutureProvider.autoDispose
    .family<DocumentReview, PaperDocument>((ref, doc) async {
      final hold = ref.keepAlive();
      try {
        final reviewer = ref.watch(documentReviewerProvider);
        // At creation/edit, before rendering; PDF fidelity is checked on the actual bytes next.
        await reviewer.reviewDocument(doc);
        final bytes = await ref.watch(documentPdfBytesProvider(doc).future);
        return await reviewer.reviewDocument(doc, pdf: bytes);
      } finally {
        hold.close();
      }
    });

/// Kept alive by the shell: edits in an inactive tab are reviewed too.
final reviewAllDocumentsProvider = Provider<void>((ref) {
  final documents = ref.watch(workspaceProvider.select((s) => s.documents));
  for (final doc in documents.values) {
    ref.watch(documentReviewProvider(doc));
  }
});
