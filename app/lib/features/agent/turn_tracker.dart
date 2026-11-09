import '../document/model/document.dart';
import 'presentation/ui_components.dart';
import 'session_state.dart';

/// The turn running now: its progress steps, its tool calls, and per document the version before the turn and the
/// latest one.
class RunningTurn {
  RunningTurn(this.id, this.prompt) : startedAt = DateTime.now();

  final String id;
  final String prompt;
  final DateTime startedAt;
  var tools = 0;

  /// Material limitations shown once, even when the server repeats the status.
  final notices = <String>{};
  final before = <String, PaperDocument>{};
  final after = <String, PaperDocument>{};

  int get seconds => DateTime.now().difference(startedAt).inSeconds;

  /// A change a tool made: the first "before" and the latest "after" of each document are kept.
  void record(PaperDocument from, PaperDocument to) {
    before.putIfAbsent(from.id, () => from);
    after[to.id] = to;
  }

  /// The turn as the Review tab keeps it, and the change summaries to show (one per document whose pages
  /// changed); null when it changed no document. [snapshot] stores a version and returns its id.
  (TurnRecord, List<Map<String, dynamic>>)? close(
    String Function(PaperDocument) snapshot,
  ) {
    if (before.isEmpty) return null;
    final elapsed = DateTime.now().difference(startedAt);
    final changes = <String, (String, String)>{};
    final shown = <Map<String, dynamic>>[];
    for (final entry in before.entries) {
      final summary = summarizeChanges(
        turnId: id,
        before: entry.value,
        after: after[entry.key]!,
        snapshot: snapshot,
        elapsed: elapsed,
        tools: tools,
      );
      changes[entry.key] = (
        summary['before'] as String,
        summary['after'] as String,
      );
      if ((summary['pages'] as List).isNotEmpty) shown.add(summary);
    }
    final record = TurnRecord(
      id: id,
      prompt: prompt,
      startedAt: startedAt,
      endedAt: DateTime.now(),
      tools: tools,
      changes: changes,
    );
    return (record, shown);
  }
}
