import 'package:flutter/widgets.dart';

import '../../features/access/desktop_credentials.dart';

/// Reports the section receiving interaction, never keystrokes or content.
class ActivityRegion extends StatelessWidget {
  const ActivityRegion({required this.area, required this.child, super.key});
  final String area;
  final Widget child;
  void _mark() => DesktopCredentials.instance.area = area;
  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    onFocusChange: (focused) {
      if (focused) _mark();
    },
    onKeyEvent: (_, _) {
      _mark();
      return KeyEventResult.ignored;
    },
    child: Listener(
      onPointerDown: (_) => _mark(),
      onPointerUp: (_) => _mark(),
      child: child,
    ),
  );
}
