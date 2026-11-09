import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/agent/domain/source_reference.dart';
import '../../../l10n/l10n.dart';

class SourceCitationScope extends InheritedWidget {
  const SourceCitationScope({
    super.key,
    required this.onOpen,
    required super.child,
  });
  final ValueChanged<SourceReference> onOpen;
  static SourceCitationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SourceCitationScope>();
  @override
  bool updateShouldNotify(SourceCitationScope oldWidget) =>
      onOpen != oldWidget.onOpen;
}

String sourceLabel(AppLocalizations l, SourceReference source) =>
    source.wholeDocument
    ? source.title
    : source.unit == 'section'
    ? l.sourceSection(source.title, source.page)
    : source.lastPage != null && source.lastPage! > source.page
    ? l.sourcePages(source.title, source.page, source.lastPage!)
    : l.sourcePage(source.title, source.page);

/// One keyboard-accessible action, shared by prose and structured evidence cards.
class SourceLink extends StatelessWidget {
  const SourceLink(this.source, {super.key});
  final SourceReference source;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final label = sourceLabel(l, source);
    final open = SourceCitationScope.maybeOf(context)?.onOpen;
    if (open == null) return Text(label);
    return ReferenceLink(
      label: label,
      tooltip: l.sourceOpen(label),
      onOpen: () => open(source),
    );
  }
}

/// Shared visual and keyboard behavior for case citations and web references.
class ReferenceLink extends StatelessWidget {
  const ReferenceLink({
    super.key,
    required this.label,
    required this.tooltip,
    required this.onOpen,
  });
  final String label;
  final String tooltip;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final color = AppTokens.of(context).sourceLink;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        link: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 290),
          child: TextButton(
            onPressed: onOpen,
            style: TextButton.styleFrom(
              foregroundColor: color,
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: AppText.of(context).chat.copyWith(
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
                decorationColor: color,
                decorationStyle: TextDecorationStyle.solid,
              ),
            ),
            child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ),
      ),
    );
  }
}
