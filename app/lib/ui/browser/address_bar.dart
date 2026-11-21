import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../features/browser/engine/engine.dart';
import '../../features/browser/web_address.dart';
import '../../l10n/l10n.dart';
import '../app_actions.dart';
import 'browser_host.dart';

/// Where the tab is, and where the lawyer sends it. At rest it reads like a browser's: the site, then the rest of
/// the address dimmed, a lock or «Non sicuro» before them, neither when the page did not open. A click selects the
/// whole address to type over it; Enter goes, Esc puts the address back.
class AddressBar extends ConsumerStatefulWidget {
  const AddressBar({super.key, required this.tabId, required this.url, this.problem});

  final String tabId;

  /// Where the page is now; null on the portals.
  final Uri? url;

  /// Why the page did not open, if it did not.
  final PageProblem? problem;

  @override
  ConsumerState<AddressBar> createState() => _AddressBarState();
}

class _AddressBarState extends ConsumerState<AddressBar> {
  final _controller = _AddressController();
  late final FocusNode _focus = ref.read(addressFocusProvider);

  /// A click that gave the bar the keyboard selects the whole address, as in a browser; the next click places
  /// the caret.
  var _selectOnTap = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
    _showAddress();
  }

  @override
  void didUpdateWidget(AddressBar old) {
    super.didUpdateWidget(old);
    // The page moved on: the bar follows, unless the lawyer is typing in it.
    if (old.url != widget.url && !_focus.hasFocus) _showAddress();
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _controller.dispose();
    super.dispose();
  }

  String get _full => widget.url?.toString() ?? '';

  /// The address at rest: "normattiva.it/uri-res/N2Ls?…", the site in full colour.
  void _showAddress() {
    final url = widget.url;
    if (url == null || navigationFor(url) != Navigation.web) {
      _controller
        ..host = null
        ..text = _full;
      return;
    }
    final host = displayHost(url);
    _controller
      ..host = host.length
      ..text = '$host${displayRest(url)}';
  }

  void _onFocus() {
    if (!mounted) return;
    if (!_focus.hasFocus) return setState(_showAddress);
    _controller
      ..host = null
      ..value = TextEditingValue(
        text: _full,
        selection: TextSelection(baseOffset: 0, extentOffset: _full.length),
      );
    _selectOnTap = true;
    setState(() {});
  }

  void _submit(String text) {
    if (text.trim().isEmpty) return;
    AppActions(ref).openAddress(widget.tabId, text);
    _focus.unfocus();
    ref.read(livePagesProvider).pageOf(widget.tabId)?.focus();
  }

  void _cancel() {
    _focus.unfocus();
    ref.read(livePagesProvider).pageOf(widget.tabId)?.focus();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final url = widget.url;
    final focused = _focus.hasFocus;
    final problem = widget.problem;
    // A certificate the engine refused is no encrypted connection, whatever the scheme says.
    final insecure =
        url != null &&
        navigationFor(url) == Navigation.web &&
        (!isSecure(url) || problem == PageProblem.certificate);
    final radius = BorderRadius.circular(AppTheme.radiusSm);

    final Widget lead = switch (url) {
      null => Icon(LucideIcons.search, size: 13, color: tokens.textFaint),
      _ when insecure => Tooltip(
        message: l.browserNotSecure,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.triangleAlert, size: 13, color: tokens.warning),
            const SizedBox(width: 5),
            Text(l.browserNotSecure, style: text.labelMedium?.copyWith(color: tokens.warning)),
            Container(width: 1, height: 14, margin: const EdgeInsets.only(left: 8), color: tokens.border),
          ],
        ),
      ),
      // Nothing opened: no connection to call encrypted.
      _ when problem != null => Icon(LucideIcons.globe, size: 13, color: tokens.textFaint),
      _ => Tooltip(
        message: l.browserSecure,
        child: Icon(LucideIcons.lock, size: 12, color: tokens.textFaint),
      ),
    };

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _cancel},
      child: SizedBox(
        height: 30,
        child: TextField(
          controller: _controller,
          focusNode: _focus,
          style: text.bodyMedium?.copyWith(height: 1.2),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.go,
          autocorrect: false,
          enableSuggestions: false,
          maxLines: 1,
          onTap: () {
            if (!_selectOnTap) return;
            _selectOnTap = false;
            _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
          },
          onChanged: (_) => _selectOnTap = false,
          onSubmitted: _submit,
          decoration: InputDecoration(
            isDense: true,
            hintText: l.browserAddressHint,
            filled: true,
            fillColor: focused ? scheme.surface : tokens.hover,
            hoverColor: Colors.transparent,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            prefixIcon: Padding(padding: const EdgeInsets.only(left: 10, right: 8), child: lead),
            prefixIconConstraints: const BoxConstraints(minHeight: 30),
            border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: const BorderSide(color: Colors.transparent),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: scheme.primary, width: 1.2),
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws the site in the text's own colour and the rest of the address dimmed, while the bar is at rest.
class _AddressController extends TextEditingController {
  /// How many characters at the start are the site; null while the lawyer edits.
  int? host;

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final h = host;
    if (h == null || h > text.length) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }
    return TextSpan(
      style: style,
      children: [
        TextSpan(text: text.substring(0, h)),
        TextSpan(
          text: text.substring(h),
          style: TextStyle(color: AppTokens.of(context).textFaint),
        ),
      ],
    );
  }
}
