import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../core/theme/app_theme.dart';
import '../../features/agent/agent_controller.dart';
import '../../features/agent/domain/agent_protocol.dart';
import '../../features/agent/domain/source_reference.dart';
import '../../l10n/l10n.dart';
import '../common/widgets.dart';
import '../chat/components/source_link.dart';

/// Read-only evidence; this viewer never touches the workspace's editable document.
class SourceTab extends ConsumerStatefulWidget {
  const SourceTab({
    super.key,
    required this.threadId,
    required this.name,
    required this.page,
    this.quote = '',
    this.sourceId = '',
  });
  final String threadId;
  final String name;
  final int page;
  final String quote;
  final String sourceId;
  @override
  ConsumerState<SourceTab> createState() => _SourceTabState();
}

class _SourceTabState extends ConsumerState<SourceTab> {
  final _viewer = PdfViewerController();
  SourceDocument? _source;
  Uint8List? _pdf;
  Object? _error;
  bool _loading = true;
  bool _pdfFailed = false;
  int _request = 0;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _load(widget.page);
  }

  @override
  void didUpdateWidget(SourceTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.threadId != widget.threadId ||
        oldWidget.name != widget.name ||
        oldWidget.sourceId != widget.sourceId) {
      _pdf = null;
      _source = null;
      _pdfFailed = false;
    }
    if (oldWidget.threadId != widget.threadId ||
        oldWidget.name != widget.name ||
        oldWidget.sourceId != widget.sourceId ||
        oldWidget.page != widget.page ||
        oldWidget.quote != widget.quote) {
      _load(widget.page);
    }
  }

  Future<void> _load(int page) async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      _page = page;
    });
    try {
      final source = await ref
          .read(agentClientProvider)
          .readSource(
            widget.threadId,
            widget.sourceId.isEmpty ? widget.name : 'sha256:${widget.sourceId}',
            page,
            includeOriginal: _pdf == null,
          );
      if (!mounted || request != _request) return;
      setState(() {
        _source = source;
        _pdf = source == null ? null : source.pdfBytes ?? _pdf;
        _loading = false;
      });
      if (_pdf != null && !_pdfFailed) _reveal();
    } catch (error) {
      if (mounted && request == _request) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  /// Only a literal passage present on the cited page may be highlighted.
  bool get _hasQuote =>
      _source?.page == _page &&
      widget.quote.trim().isNotEmpty &&
      (_source?.text.toLowerCase().contains(
            widget.quote.trim().toLowerCase(),
          ) ??
          false);

  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _viewer.pageCount < _page) return;
      _viewer.jumpToPage(_page);
      if (_hasQuote) _viewer.searchText(widget.quote.trim());
    });
  }

  @override
  void dispose() {
    _viewer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tokens = AppTokens.of(context);
    if (_loading) {
      return Center(
        child: Semantics(liveRegion: true, child: Text(l.sourceLoading)),
      );
    }
    if (_error != null || _source == null) {
      return EmptyState(
        icon: LucideIcons.fileSearch,
        title: l.sourceUnavailable,
        message: _error == null
            ? l.sourceMissingMessage
            : l.sourceConnectionMessage,
        actions: [
          OutlinedButton(
            onPressed: () => _load(_page),
            child: Text(l.sourceRetry),
          ),
        ],
      );
    }
    final source = _source!;
    final pdf = _pdf != null && !_pdfFailed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sourceLabel(
                        l,
                        SourceReference(source.name, _page, unit: source.unit),
                      ),
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      pdf ? l.sourceOriginal : l.sourceExtracted,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: tokens.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l.sourcePrevious,
                icon: const Icon(LucideIcons.chevronLeft, size: 18),
                onPressed: _page > 1
                    ? () => pdf ? _viewer.previousPage() : _load(_page - 1)
                    : null,
              ),
              IconButton(
                tooltip: l.sourceNext,
                icon: const Icon(LucideIcons.chevronRight, size: 18),
                onPressed: _page < source.pages
                    ? () => pdf ? _viewer.nextPage() : _load(_page + 1)
                    : null,
              ),
            ],
          ),
        ),
        if (_hasQuote)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              '«${widget.quote}»',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                backgroundColor: tokens.sourceLink.withValues(alpha: .12),
              ),
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: pdf
              ? SfPdfViewer.memory(
                  _pdf!,
                  key: ValueKey('${widget.threadId}/${source.name}'),
                  controller: _viewer,
                  initialPageNumber: _page,
                  canShowScrollHead: false,
                  canShowScrollStatus: false,
                  canShowPaginationDialog: false,
                  onDocumentLoaded: (_) => _reveal(),
                  onDocumentLoadFailed: (_) {
                    if (mounted) setState(() => _pdfFailed = true);
                  },
                  onPageChanged: (details) {
                    if (mounted) setState(() => _page = details.newPageNumber);
                  },
                )
              : _SourcePageText(
                  key: ValueKey(
                    '${source.name}/${source.page}/${widget.quote}',
                  ),
                  text: source.text.isEmpty ? l.sourceNoText : source.text,
                  quote: widget.quote,
                ),
        ),
      ],
    );
  }
}

class _SourcePageText extends StatefulWidget {
  const _SourcePageText({super.key, required this.text, required this.quote});
  final String text;
  final String quote;
  @override
  State<_SourcePageText> createState() => _SourcePageTextState();
}

class _SourcePageTextState extends State<_SourcePageText> {
  final _passage = GlobalKey();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _passage.currentContext;
      if (mounted && context != null) {
        Scrollable.ensureVisible(context, alignment: .15);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final quote = widget.quote.trim();
    final lines = widget.text.split('\n');
    final citedLine = quote.isEmpty
        ? -1
        : lines.indexWhere(
            (line) => line.toLowerCase().contains(quote.toLowerCase()),
          );
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.65);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: SelectionArea(
        child: DefaultTextStyle(
          style: style!,
          child: citedLine < 0
              ? Text(widget.text)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (number, line) in lines.indexed)
                      if (number != citedLine)
                        Text(line)
                      else
                        Text.rich(
                          TextSpan(
                            children: _highlight(
                              line,
                              quote,
                              AppTokens.of(context).sourceLink,
                            ),
                          ),
                          key: _passage,
                        ),
                  ],
                ),
        ),
      ),
    );
  }
}

List<TextSpan> _highlight(String text, String quote, Color color) {
  final index = text.toLowerCase().indexOf(quote.toLowerCase());
  return [
    TextSpan(text: text.substring(0, index)),
    TextSpan(
      text: text.substring(index, index + quote.length),
      style: TextStyle(
        backgroundColor: color.withValues(alpha: .16),
        fontWeight: FontWeight.w600,
      ),
    ),
    TextSpan(text: text.substring(index + quote.length)),
  ];
}
