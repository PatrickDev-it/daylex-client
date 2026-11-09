import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../features/document/model/document.dart';
import '../../l10n/l10n.dart';
import '../common/widgets.dart';
import 'synced_text_field.dart';

class MetricsEditor extends StatelessWidget {
  const MetricsEditor({super.key, required this.block, required this.onChanged});

  final MetricsBlock block;
  final void Function(DocBlock) onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;

    void set(int i, Metric m) => onChanged(MetricsBlock(id: block.id, items: [...block.items]..[i] = m));

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (i, m) in block.items.indexed)
          SizedBox(
            width: 150,
            child: OutlinedBox(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SyncedTextField(
                    value: m.label,
                    hint: l.editorMetricLabelHint,
                    style: text.labelSmall,
                    onCommit: (v) => set(i, Metric(label: v, value: m.value, delta: m.delta)),
                  ),
                  SyncedTextField(
                    value: m.value,
                    hint: l.editorMetricValueHint,
                    style: text.titleLarge,
                    onCommit: (v) => set(i, Metric(label: m.label, value: v, delta: m.delta)),
                  ),
                  SyncedTextField(
                    value: m.delta,
                    hint: l.editorMetricChangeHint,
                    style: text.labelSmall?.copyWith(color: tokens.success),
                    onCommit: (v) => set(i, Metric(label: m.label, value: m.value, delta: v)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class TableEditor extends StatelessWidget {
  const TableEditor({super.key, required this.block, required this.onChanged});

  final TableBlock block;
  final void Function(DocBlock) onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final width = block.columns.length;

    List<String> fit(List<String> row) => [
      ...row.take(width),
      ...List.filled((width - row.length).clamp(0, width), ''),
    ];

    Widget cell(String value, void Function(String) commit, {bool header = false}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: SyncedTextField(
        value: value,
        style: header
            ? text.labelSmall?.copyWith(fontWeight: FontWeight.w600)
            : text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface),
        onCommit: commit,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Clipped so the header row's fill follows the box's rounded corners.
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: OutlinedBox(
            child: Table(
              border: TableBorder(horizontalInside: BorderSide(color: tokens.border)),
              columnWidths: const {0: FlexColumnWidth(1.5)},
              children: [
                TableRow(
                  decoration: BoxDecoration(color: tokens.hover),
                  children: [
                    for (final (c, name) in block.columns.indexed)
                      cell(name, header: true, (v) => onChanged(block.copyWith(columns: [...block.columns]..[c] = v))),
                  ],
                ),
                for (final (r, row) in block.rows.indexed)
                  TableRow(
                    children: [
                      for (final (c, value) in fit(row).indexed)
                        cell(value, (v) {
                          final rows = [for (final x in block.rows) fit(x)];
                          rows[r][c] = v;
                          onChanged(block.copyWith(rows: rows));
                        }),
                    ],
                  ),
              ],
            ),
          ),
        ),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => onChanged(block.copyWith(rows: [...block.rows, List.filled(width, '')])),
              icon: const Icon(LucideIcons.plus, size: 13),
              label: Text(l.editorTableAddRow),
            ),
            TextButton.icon(
              onPressed: () => onChanged(
                block.copyWith(
                  columns: [...block.columns, l.editorNewTableColumn],
                  rows: [
                    for (final r in block.rows) [...fit(r), ''],
                  ],
                ),
              ),
              icon: const Icon(LucideIcons.plus, size: 13),
              label: Text(l.editorTableAddColumn),
            ),
            if (block.rows.length > 1)
              TextButton(
                onPressed: () => onChanged(block.copyWith(rows: block.rows.sublist(0, block.rows.length - 1))),
                child: Text(l.editorTableRemoveRow),
              ),
            const Spacer(),
            SizedBox(
              width: 220,
              child: SyncedTextField(
                value: block.caption,
                hint: l.editorCaptionHint,
                style: text.bodySmall,
                onCommit: (v) => onChanged(block.copyWith(caption: v)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ImageEditor extends StatelessWidget {
  const ImageEditor({super.key, required this.block, required this.onChanged});

  final ImageBlock block;
  final void Function(DocBlock) onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: block.bytes != null
              ? Image.memory(block.bytes!, height: 120, fit: BoxFit.cover)
              : Container(
                  height: 80,
                  width: 200,
                  color: tokens.hover,
                  child: Icon(LucideIcons.image, color: tokens.textFaint),
                ),
        ),
        SyncedTextField(
          value: block.caption,
          hint: context.l10n.editorCaptionHint,
          style: Theme.of(context).textTheme.bodySmall,
          onCommit: (v) => onChanged(block.copyWith(caption: v)),
        ),
      ],
    );
  }
}
