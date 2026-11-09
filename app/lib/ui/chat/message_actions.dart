import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../common/copy_feedback.dart';
import '../common/time_format.dart';
import '../common/widgets.dart';

/// A message with its actions underneath, shown on hover like every chat agent: copy and when it was
/// sent. The row keeps its height while hidden, so the transcript does not jump under the pointer.
class MessageActions extends StatefulWidget {
  const MessageActions({
    super.key,
    required this.text,
    required this.time,
    required this.alignEnd,
    required this.child,
    this.enabled = true,
  });

  /// What the copy button puts on the clipboard.
  final String text;
  final DateTime time;

  /// The user's messages sit on the right, their actions too.
  final bool alignEnd;
  final Widget child;

  /// Off while the message is still streaming.
  final bool enabled;

  @override
  State<MessageActions> createState() => _MessageActionsState();
}

class _MessageActionsState extends State<MessageActions> with CopyFeedback {
  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l = context.l10n;
    final time = Tooltip(
      message: fullStamp(l, widget.time),
      child: Text(
        shortStamp(l, widget.time, DateTime.now()),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tokens.textFaint),
      ),
    );

    return HoverBuilder(
      builder: (context, hover) {
        final visible = widget.enabled && (hover || copied);
        final copyButton = IconButton(
          tooltip: copied ? l.copied : l.copy,
          onPressed: visible ? () => copy(widget.text) : null,
          style: IconButton.styleFrom(minimumSize: const Size(26, 26), fixedSize: const Size(26, 26)),
          icon: Icon(
            copied ? LucideIcons.check : LucideIcons.copy,
            size: 13,
            color: copied ? tokens.success : tokens.textMuted,
          ),
        );
        return Column(
          crossAxisAlignment: widget.alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            widget.child,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: AnimatedOpacity(
                opacity: visible ? 1 : 0,
                duration: AppTheme.fast,
                child: SizedBox(
                  height: 26,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: widget.alignEnd
                        ? [time, const SizedBox(width: 4), copyButton]
                        : [copyButton, const SizedBox(width: 4), time],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
