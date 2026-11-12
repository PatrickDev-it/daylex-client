import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'agent_markdown.dart';

/// The agent's reply as if typed. The server sends it a verified sentence at a time (rfc/040), which would
/// otherwise land in jumps: what has arrived is shown a word at a time, at least [minCharsPerSecond] and fast
/// enough never to lag more than [catchUp] behind what has arrived. A reply already complete when first shown
/// (an earlier turn, a reopened chat) appears whole, and so does every reply when the system asks for less
/// motion. Nothing is ever invented ahead of the text: only what the server sent is revealed.
class TypedReply extends StatefulWidget {
  const TypedReply(this.text, {super.key, required this.streaming});

  final String text;

  /// True while the server is still sending this reply.
  final bool streaming;

  static const minCharsPerSecond = 90.0;
  static const catchUp = Duration(milliseconds: 1200);

  @override
  State<TypedReply> createState() => _TypedReplyState();
}

class _TypedReplyState extends State<TypedReply>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  late double _shown = widget.streaming ? 0 : widget.text.length.toDouble();
  Duration _last = Duration.zero;

  bool get _behind => _shown < widget.text.length;

  @override
  void initState() {
    super.initState();
    _follow();
  }

  @override
  void didUpdateWidget(TypedReply old) {
    super.didUpdateWidget(old);
    // Shown text is never taken back (rfc/040); a shorter text only clamps what is revealed.
    _shown = math.min(_shown, widget.text.length.toDouble());
    _follow();
  }

  void _follow() {
    if (_behind && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    final seconds =
        (elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond;
    _last = elapsed;
    final backlog = widget.text.length - _shown;
    final rate = math.max(
      TypedReply.minCharsPerSecond,
      backlog /
          (TypedReply.catchUp.inMicroseconds / Duration.microsecondsPerSecond),
    );
    setState(
      () => _shown = math.min(
        widget.text.length.toDouble(),
        _shown + rate * seconds,
      ),
    );
    if (!_behind) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return AgentMarkdown(widget.text, streaming: widget.streaming);
    }
    final cut = revealCut(widget.text, _shown.floor());
    return AgentMarkdown(
      widget.text.substring(0, cut),
      streaming: widget.streaming || cut < widget.text.length,
    );
  }
}

/// Spans shown whole or not at all, so a half-revealed one never flashes as raw markup: a source reference
/// `[atto, p. 3]` or a link `[testo](url)`, bold, inline code, inline math.
final _atomic = RegExp(
  r'\[[^\[\]\n]*\](?:\([^()\n]*\))?|\*\*[^*\n]+\*\*|`[^`\n]+`|\$[^$\n]+\$',
);

/// Where to cut [text] to reveal about [count] characters: at the end of the word reached, and past any
/// [_atomic] span the cut would fall inside.
int revealCut(String text, int count) {
  if (count >= text.length) return text.length;
  if (count <= 0) return 0;
  var cut = count;
  while (cut < text.length && !_isSpace(text.codeUnitAt(cut))) {
    cut++;
  }
  for (final span in _atomic.allMatches(text)) {
    if (span.start >= cut) break;
    if (span.end > cut) {
      cut = span.end;
      while (cut < text.length && !_isSpace(text.codeUnitAt(cut))) {
        cut++;
      }
    }
  }
  return cut;
}

bool _isSpace(int unit) =>
    unit == 0x20 || unit == 0x0A || unit == 0x09 || unit == 0x0D;
