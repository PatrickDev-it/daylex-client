import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../features/browser/browser_state.dart';
import '../../features/browser/portals.dart';
import '../../features/browser/web_address.dart';
import '../../l10n/l10n.dart';
import '../app_actions.dart';
import '../common/widgets.dart';
import 'portal_dialog.dart';

/// A tab without an address (rfc/052 §6): the sites a lawyer opens every day, in groups, and theirs. A portal
/// opens in this tab; with the middle button, in a new one.
class NewTabPage extends ConsumerWidget {
  const NewTabPage({super.key, required this.tabId, this.notice});

  final String tabId;

  /// Why pages open outside this computer's Daylex, when they do.
  final Widget? notice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final portals = ref.watch(browserProvider.select((s) => s.portals));

    Widget group(PortalGroup group, String title) {
      final members = portals.where((p) => p.group == group).toList();
      if (members.isEmpty && group != PortalGroup.mine) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 10, bottom: 6),
              child: Text(title, style: text.labelSmall),
            ),
            for (final p in members) _PortalRow(tabId: tabId, portal: p),
            if (group == PortalGroup.mine) ...[
              if (members.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
                  child: Text(l.browserPortalsMineEmpty, style: text.bodySmall),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _addPortal(context, ref),
                  icon: const Icon(LucideIcons.plus, size: 14),
                  label: Text(l.browserAddPortalButton),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (notice != null) ...[notice!, const SizedBox(height: 20)],
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(LucideIcons.keyRound, size: 14, color: tokens.textFaint),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(l.browserNewTabHint, style: text.bodySmall)),
                    ],
                  ),
                ),
                group(PortalGroup.official, l.browserPortalsOfficial),
                group(PortalGroup.databases, l.browserPortalsDatabases),
                group(PortalGroup.mine, l.browserPortalsMine),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addPortal(BuildContext context, WidgetRef ref) async {
    final browser = ref.read(browserProvider.notifier);
    final l = context.l10n;
    final portal = await showPortalDialog(context);
    if (portal == null) return;
    browser.addPortal(portal.name, portal.url);
    toast(l.browserPortalAdded(portal.name.trim().isEmpty ? portal.url : portal.name.trim()));
  }
}

class _PortalRow extends ConsumerStatefulWidget {
  const _PortalRow({required this.tabId, required this.portal});

  final String tabId;
  final Portal portal;

  @override
  ConsumerState<_PortalRow> createState() => _PortalRowState();
}

class _PortalRowState extends ConsumerState<_PortalRow> {
  /// The keyboard is on the row or its menu button: the button shows, as on hover.
  var _focused = false;
  var _menuOpen = false;

  String get tabId => widget.tabId;
  Portal get portal => widget.portal;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tokens = AppTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final actions = AppActions(ref);
    final uri = Uri.tryParse(portal.url);
    final host = uri == null ? portal.url : displayHost(uri);

    final menu = MenuAnchor(
      alignmentOffset: const Offset(-160, 0),
      onOpen: () => setState(() => _menuOpen = true),
      onClose: () => setState(() => _menuOpen = false),
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.pencil, size: 15),
          onPressed: () => _rename(context, ref),
          child: Text(l.rename),
        ),
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.trash2, size: 15),
          onPressed: () => ref.read(browserProvider.notifier).removePortal(portal.id),
          child: Text(l.browserPortalRemove),
        ),
      ],
      builder: (context, controller, _) => ToolbarButton(
        icon: LucideIcons.ellipsis,
        tooltip: l.browserMore,
        size: 28,
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: HoverBuilder(
        builder: (context, hover) => GestureDetector(
          onTertiaryTapUp: uri == null ? null : (_) => actions.openWebTab(url: uri, after: tabId),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            onTap: () => actions.openAddress(tabId, portal.url),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: AppTheme.tintSoft),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Text(
                      portal.name.characters.take(1).toString().toUpperCase(),
                      style: text.titleSmall?.copyWith(color: scheme.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(portal.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleSmall),
                        Text(
                          host,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(color: tokens.textFaint),
                        ),
                      ],
                    ),
                  ),
                  // Always there for the keyboard and a screen reader; seen on hover, with the keyboard on the
                  // row, or while its menu is open.
                  Opacity(opacity: hover || _focused || _menuOpen ? 1 : 0, child: menu),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final browser = ref.read(browserProvider.notifier);
    final renamed = await showPortalDialog(context, name: portal.name, rename: true);
    if (renamed != null) browser.renamePortal(portal.id, renamed.name);
  }
}
