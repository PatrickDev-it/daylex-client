import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:re_highlight/languages/bash.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/markdown.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../l10n/labels.dart';
import '../../../features/agent/domain/source_reference.dart';
import '../../common/copy_feedback.dart';
import '../../common/widgets.dart';
import '../../common/web_link.dart';
import 'card_chrome.dart';
import 'component_registry.dart';
import 'source_link.dart';

/// Half a period of the streaming caret's blink, the rhythm of a text cursor.
const _caretBlink = Duration(milliseconds: 530);

/// Renders agent markdown: GitHub-flavoured text and tables, highlighted
/// code, `$inline$` and `$$block$$` LaTeX, and component fences:
///
/// ````
/// ```ui:pdf_page
/// {"page": 3}
/// ```
/// ````
///
/// Works on partial text while streaming: an unfinished code fence renders
/// as code, an unfinished component fence as a placeholder.
class AgentMarkdown extends StatelessWidget {
  const AgentMarkdown(this.data, {super.key, this.streaming = false});

  final String data;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    final segments = parseSegments(data);
    final sheet = markdownStyle(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, s) in segments.indexed)
          Padding(
            // Blocks of one text sit as far apart as within a single markdown body.
            padding: EdgeInsets.only(
              top: i == 0
                  ? 0
                  : s is TextSegment && segments[i - 1] is TextSegment
                  ? sheet.blockSpacing ?? 8
                  : 8,
            ),
            child: switch (s) {
              TextSegment(:final text) => MarkdownBody(
                data: text,
                styleSheet: sheet,
                selectable: !streaming,
                extensionSet: md.ExtensionSet.gitHubFlavored,
                inlineSyntaxes: [_SourceSyntax(), _InlineMathSyntax()],
                builders: {
                  'a': _WebLinkBuilder(),
                  'source': _SourceBuilder(),
                  'math': _InlineMathBuilder(),
                },
              ),
              MathSegment(:final tex) => _BlockMath(tex),
              FenceSegment(:final info, :final body, :final closed) =>
                info.startsWith('ui:')
                    ? _ComponentFence(
                        kind: info.substring(3).trim(),
                        json: body,
                        closed: closed,
                      )
                    : CodeBlock(code: body, language: info, streaming: !closed),
            },
          ),
        if (streaming) const _Caret(),
      ],
    );
  }
}

// -- parsing ------------------------------------------------------------------

class _WebLinkBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final source = SourceReference.fromUri(element.attributes['href'] ?? '');
    if (source != null) return SourceLink(source);
    final uri = publicWebUri(element.attributes['href'] ?? '');
    final label = element.textContent;
    if (uri == null) return Text(label, style: preferredStyle);
    return Builder(
      builder: (context) => ReferenceLink(
        label: label,
        tooltip: '$label — ${uri.host}',
        onOpen: () => openWebLink(context, uri),
      ),
    );
  }
}

class _SourceSyntax extends md.InlineSyntax {
  _SourceSyntax() : super(SourceReference.pattern, caseSensitive: false);
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final source = SourceReference.fromMatch(
      match,
      before: parser.source.substring(0, match.start),
    );
    if (source == null) return false;
    final element = md.Element.text('source', source.name);
    element.attributes.addAll({
      'page': '${source.page}',
      'last': '${source.lastPage ?? ''}',
      'quote': source.quote,
    });
    parser.addNode(element);
    return true;
  }
}

class _SourceBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) =>
      SourceLink(
        SourceReference(
          element.textContent,
          int.parse(element.attributes['page']!),
          lastPage: int.tryParse(element.attributes['last'] ?? ''),
          quote: element.attributes['quote'] ?? '',
        ),
      );
}

sealed class Segment {
  const Segment();
}

class TextSegment extends Segment {
  const TextSegment(this.text);
  final String text;
}

class MathSegment extends Segment {
  const MathSegment(this.tex);
  final String tex;
}

class FenceSegment extends Segment {
  const FenceSegment(this.info, this.body, {required this.closed});
  final String info;
  final String body;
  final bool closed;
}

/// Splits markdown into text, block math and fenced blocks.
List<Segment> parseSegments(String data) {
  final out = <Segment>[];
  final text = StringBuffer();

  void addText(String value) {
    for (final block in _finishedBlocks(value)) {
      if (block.trim().isNotEmpty) out.add(TextSegment(block));
    }
  }

  void flushText() {
    final value = text.toString();
    text.clear();
    if (value.trim().isEmpty) return;
    // Block math only outside fences.
    var cursor = 0;
    for (final m in RegExp(r'\$\$([\s\S]+?)\$\$').allMatches(value)) {
      final before = value.substring(cursor, m.start);
      addText(before);
      out.add(MathSegment(m.group(1)!.trim()));
      cursor = m.end;
    }
    addText(value.substring(cursor));
  }

  final lines = const LineSplitter().convert(data);
  var i = 0;
  while (i < lines.length) {
    final line = lines[i];
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('```')) {
      flushText();
      final info = trimmed.substring(3).trim();
      final body = <String>[];
      var closed = false;
      i++;
      while (i < lines.length) {
        if (lines[i].trim() == '```') {
          closed = true;
          break;
        }
        body.add(lines[i]);
        i++;
      }
      out.add(FenceSegment(info, body.join('\n'), closed: closed));
      i++;
      continue;
    }
    text.writeln(line);
    i++;
  }
  flushText();
  return out;
}

/// A list item: after a blank line it continues the list before it, if any.
final _listItem = RegExp(r'^ {0,3}([-*+]|\d{1,9}[.)])(\s|$)');

/// An indented line: after a blank line it continues the block before it.
final _indent = RegExp(r'\s');

/// A reference or footnote definition, which resolves across the whole text.
final _definition = RegExp(r'^ {0,3}\[[^\]]+\]:', multiLine: true);

/// [text] as its markdown blocks, each rendering as it would within the whole: split at a blank line only
/// where the next line starts a block of its own, not an indented continuation or the next item of a list.
/// A streamed reply then parses again only its last block, not everything before it at every piece.
List<String> _finishedBlocks(String text) {
  if (_definition.hasMatch(text)) return [text];
  final blocks = <String>[];
  final lines = text.split('\n');
  var start = 0;
  var inList = _listItem.hasMatch(lines.first);
  for (var i = 1; i < lines.length; i++) {
    final line = lines[i];
    final item = _listItem.hasMatch(line);
    final continues = line.startsWith(_indent) || (item && inList);
    if (line.trim().isNotEmpty && lines[i - 1].trim().isEmpty && !continues) {
      blocks.add(lines.sublist(start, i).join('\n'));
      start = i;
      inList = false;
    }
    inList |= item;
  }
  return blocks..add(lines.sublist(start).join('\n'));
}

// -- style ----------------------------------------------------------------------

MarkdownStyleSheet markdownStyle(BuildContext context) {
  final theme = Theme.of(context);
  final tokens = AppTokens.of(context);
  final text = theme.textTheme;
  final appText = AppText.of(context);
  final body = appText.chat.copyWith(height: 1.6);
  final table = text.bodyMedium!.copyWith(height: 1.6);
  final dark = theme.brightness == Brightness.dark;
  return MarkdownStyleSheet(
    p: body,
    pPadding: EdgeInsets.zero,
    blockSpacing: 10,
    h1: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.3),
    h2: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.3),
    h3: text.titleSmall?.copyWith(fontWeight: FontWeight.w700, height: 1.4),
    h1Padding: const EdgeInsets.only(top: 6),
    h2Padding: const EdgeInsets.only(top: 6),
    h3Padding: const EdgeInsets.only(top: 4),
    strong: const TextStyle(fontWeight: FontWeight.w600),
    em: const TextStyle(fontStyle: FontStyle.italic),
    a: TextStyle(color: theme.colorScheme.primary),
    listBullet: body,
    listIndent: 22,
    code: appText.code.copyWith(
      color: body.color,
      backgroundColor: (dark ? Colors.white : Colors.black).withValues(
        alpha: dark ? AppTheme.tintFaint : 0.05,
      ),
    ),
    blockquote: body.copyWith(color: tokens.textMuted),
    blockquoteDecoration: BoxDecoration(
      border: Border(left: BorderSide(color: tokens.borderStrong, width: 3)),
    ),
    blockquotePadding: const EdgeInsets.only(left: 12),
    tableHead: table.copyWith(fontWeight: FontWeight.w600),
    tableBody: table,
    tableBorder: TableBorder.all(color: tokens.border, width: 1),
    tableHeadAlign: TextAlign.left,
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    tableColumnWidth: const IntrinsicColumnWidth(),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: tokens.border)),
    ),
  );
}

// -- math -------------------------------------------------------------------------

class _InlineMathSyntax extends md.InlineSyntax {
  _InlineMathSyntax() : super(r'\$([^\$\n]+?)\$');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('math', match[1]!));
    return true;
  }
}

class _InlineMathBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => Math.tex(
    element.textContent,
    mathStyle: MathStyle.text,
    textStyle: parentStyle ?? preferredStyle,
    onErrorFallback: (_) =>
        Text('\$${element.textContent}\$', style: parentStyle),
  );
}

class _BlockMath extends StatelessWidget {
  const _BlockMath(this.tex);

  final String tex;

  @override
  Widget build(BuildContext context) {
    final appText = AppText.of(context);
    final style = appText.math;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Math.tex(
          tex,
          mathStyle: MathStyle.display,
          textStyle: style,
          onErrorFallback: (e) =>
              Text(tex, style: appText.code.copyWith(fontSize: style.fontSize)),
        ),
      ),
    );
  }
}

// -- code -------------------------------------------------------------------------

final _highlight = Highlight()
  ..registerLanguage('json', langJson)
  ..registerLanguage('dart', langDart)
  ..registerLanguage('python', langPython)
  ..registerLanguage('yaml', langYaml)
  ..registerLanguage('bash', langBash)
  ..registerLanguage('javascript', langJavascript)
  ..registerLanguage('sql', langSql)
  ..registerLanguage('xml', langXml)
  ..registerLanguage('markdown', langMarkdown);

const _aliases = {
  'py': 'python',
  'js': 'javascript',
  'ts': 'javascript',
  'sh': 'bash',
  'shell': 'bash',
  'yml': 'yaml',
  'html': 'xml',
  'md': 'markdown',
};

/// Highlighted code with a language label and a copy button.
class CodeBlock extends StatefulWidget {
  const CodeBlock({
    super.key,
    required this.code,
    this.language = '',
    this.streaming = false,
  });

  final String code;
  final String language;
  final bool streaming;

  @override
  State<CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<CodeBlock> with CopyFeedback {
  TextSpan _highlighted(TextStyle base, bool dark) {
    final lang =
        _aliases[widget.language.toLowerCase()] ??
        widget.language.toLowerCase();
    if (lang.isEmpty || widget.streaming) {
      return TextSpan(text: widget.code, style: base);
    }
    try {
      final result = _highlight.highlight(code: widget.code, language: lang);
      final renderer = TextSpanRenderer(
        base,
        dark ? atomOneDarkTheme : atomOneLightTheme,
      );
      result.render(renderer);
      return renderer.span ?? TextSpan(text: widget.code, style: base);
    } catch (_) {
      return TextSpan(text: widget.code, style: base);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l = context.l10n;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = AppText.of(context).code;
    return OutlinedBox(
      color: tokens.codeBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 32,
            padding: const EdgeInsets.only(left: 12, right: 4),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: tokens.border)),
            ),
            child: Row(
              children: [
                Text(
                  (widget.language.isEmpty || widget.language == 'text')
                      ? l.cardCodePlainText
                      : widget.language,
                  style: AppText.of(context).codeSmall
                      .copyWith(color: tokens.textMuted),
                ),
                const Spacer(),
                ToolbarButton(
                  icon: copied ? LucideIcons.check : LucideIcons.copy,
                  tooltip: copied ? l.copied : l.copy,
                  onPressed: () => copy(widget.code),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText.rich(_highlighted(base, dark)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -- components -------------------------------------------------------------------

class _ComponentFence extends StatelessWidget {
  const _ComponentFence({
    required this.kind,
    required this.json,
    required this.closed,
  });

  final String kind;
  final String json;
  final bool closed;

  @override
  Widget build(BuildContext context) {
    if (!closed) {
      return ComponentFrame(
        icon: LucideIcons.loader2,
        title: context.l10n.cardRendering(context.l10n.componentLabel(kind)),
        child: const Skeleton(height: 60, radius: AppTheme.radiusSm),
      );
    }
    Map<String, dynamic> props;
    try {
      final decoded = json.trim().isEmpty
          ? <String, dynamic>{}
          : jsonDecode(json);
      props = (decoded as Map).cast<String, dynamic>();
    } catch (e) {
      return Text(context.l10n.cardUnavailable);
    }
    return buildComponent(context, kind, props) ??
        Text(context.l10n.cardUnavailable);
  }
}

class _Caret extends StatefulWidget {
  const _Caret();

  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: _caretBlink)
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: FadeTransition(
      opacity: _c,
      child: Container(
        width: 7,
        height: 15,
        margin: const EdgeInsets.only(top: 4),
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
      ),
    ),
  );
}
