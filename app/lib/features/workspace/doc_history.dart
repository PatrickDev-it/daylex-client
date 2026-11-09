import '../document/model/document.dart';

/// Undo/redo stacks of one document: earlier versions, each with the label of the step that left it.
class DocHistory {
  const DocHistory({this.undo = const [], this.redo = const []});

  final List<(PaperDocument, String)> undo;
  final List<(PaperDocument, String)> redo;

  static const limit = 100;

  /// After a new step [label] from [current]: [current] can be undone back to (the oldest step goes past
  /// [limit]), and nothing can be redone any more.
  DocHistory pushed(PaperDocument current, String label) {
    final next = [...undo, (current, label)];
    return DocHistory(undo: next.length > limit ? next.sublist(1) : next);
  }

  /// One step back from [current]: the version it returns to, the step's label, and the history after it. Null
  /// with nothing to undo.
  (PaperDocument, String, DocHistory)? undone(PaperDocument current) {
    if (undo.isEmpty) return null;
    final (previous, label) = undo.last;
    return (previous, label, DocHistory(undo: undo.sublist(0, undo.length - 1), redo: [...redo, (current, label)]));
  }

  /// One step forward again from [current]; null with nothing to redo.
  (PaperDocument, String, DocHistory)? redone(PaperDocument current) {
    if (redo.isEmpty) return null;
    final (next, label) = redo.last;
    return (next, label, DocHistory(undo: [...undo, (current, label)], redo: redo.sublist(0, redo.length - 1)));
  }
}
