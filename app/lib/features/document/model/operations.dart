import 'document.dart';

/// A typed, serialisable edit to a [PaperDocument].
///
/// Every change — from the agent, the outline editor or a toolbar button —
/// goes through one of these, so undo/redo and the agent share one path.
/// Page indices are 0-based here; agent tools expose 1-based page numbers.
///
/// What an operation is called in the history is the UI's to say (`ModelLabels.operation`).
sealed class DocOperation {
  const DocOperation();
}

class AddPage extends DocOperation {
  const AddPage(this.page, {this.index});

  final DocPage page;

  /// Insert position; appends when null.
  final int? index;
}

class DeletePage extends DocOperation {
  const DeletePage(this.pageIndex);

  final int pageIndex;
}

class MovePage extends DocOperation {
  const MovePage(this.from, this.to);

  final int from;
  final int to;
}

/// Replaces the given fields of a page, leaving the others untouched.
class UpdatePage extends DocOperation {
  const UpdatePage(this.pageIndex, {this.title, this.layout, this.blocks});

  final int pageIndex;
  final String? title;
  final PageLayout? layout;
  final List<DocBlock>? blocks;
}

class ReplaceText extends DocOperation {
  const ReplaceText(this.find, this.replace, {this.pageIndex});

  final String find;
  final String replace;

  /// Restrict to one page; whole document when null.
  final int? pageIndex;
}

class InsertBlock extends DocOperation {
  const InsertBlock(this.pageIndex, this.block, {this.index});

  final int pageIndex;
  final DocBlock block;
  final int? index;
}

/// Replaces the block with the same id, wherever it lives.
class UpdateBlock extends DocOperation {
  const UpdateBlock(this.block);

  final DocBlock block;
}

class RemoveBlock extends DocOperation {
  const RemoveBlock(this.blockId);

  final String blockId;
}

class MoveBlock extends DocOperation {
  const MoveBlock(this.blockId, this.delta);

  final String blockId;

  /// -1 moves up, +1 moves down.
  final int delta;
}

class SetTheme extends DocOperation {
  const SetTheme(this.theme);

  final DocTheme theme;
}

class UpdateMetadata extends DocOperation {
  const UpdateMetadata({this.title, this.subtitle, this.client, this.author, this.status});

  final String? title;
  final String? subtitle;
  final String? client;
  final String? author;
  final DocumentStatus? status;
}
