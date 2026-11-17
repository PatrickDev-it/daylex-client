import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../features/update/update_controller.dart';
import '../../l10n/l10n.dart';
import '../app_actions.dart';

/// Covers the app while it updates itself: as it opens and checks, while the update it found downloads and
/// installs, and as it restarts into a new version. The app underneath keeps its state but takes no input. Once
/// the app runs a new version, says once what that version improves.
class UpdateGate extends ConsumerStatefulWidget {
  const UpdateGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends ConsumerState<UpdateGate> {
  bool _telling = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(updateProvider, (_, update) => _tellWhatsNew(update));
    final update = ref.watch(updateProvider);
    final covering = update.covering;
    return Stack(
      children: [
        Positioned.fill(
          child: ExcludeFocus(
            excluding: covering,
            child: AbsorbPointer(absorbing: covering, child: widget.child),
          ),
        ),
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: AppTheme.normal,
            child: covering ? UpdateScreen(update: update) : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  /// The improvements of the version the app was restarted into, once the app is usable again.
  void _tellWhatsNew(UpdateState update) {
    final news = update.whatsNew;
    if (_telling || update.covering || news == null || news.improvements.isEmpty) return;
    _telling = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final context = navigatorKey.currentContext;
      if (context == null || !mounted) {
        _telling = false;
        return;
      }
      await showWhatsNew(context, news);
      if (!mounted) return;
      ref.read(updateProvider.notifier).seen();
      _telling = false;
    });
  }
}

/// The update panel: the logo, a turning ring and what is happening, with the download's progress.
class UpdateScreen extends StatelessWidget {
  const UpdateScreen({super.key, required this.update});

  final UpdateState update;

  static const _logoSize = 72.0;
  static const _ringSize = 28.0;
  static const _ringStroke = 3.0;
  static const _barWidth = 220.0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final tokens = AppTokens.of(context);
    final checking = update.launching && update.phase == UpdatePhase.idle;
    final (title, body) = switch (update.phase) {
      _ when checking => (l.updateStatusChecking, null),
      UpdatePhase.installing => (l.updateScreenTitle, l.updateScreenInstalling),
      _ => (l.updateScreenTitle, l.updateScreenNews(update.news.length)),
    };
    final downloading = update.phase == UpdatePhase.downloading;
    return Material(
      key: const ValueKey('update-screen'),
      color: tokens.canvas,
      child: Center(
        child: SizedBox(
          width: AppTheme.dialogWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/branding/daylex.png', width: _logoSize, height: _logoSize),
              const SizedBox(height: 28),
              SizedBox.square(
                dimension: _ringSize,
                child: CircularProgressIndicator(strokeWidth: _ringStroke, color: AppTheme.cyan),
              ),
              const SizedBox(height: 24),
              Text(title, style: text.titleMedium, textAlign: TextAlign.center),
              if (body != null) ...[
                const SizedBox(height: 8),
                Text(
                  body,
                  style: text.bodyMedium?.copyWith(color: tokens.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
              if (downloading) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: _barWidth,
                  child: LinearProgressIndicator(
                    value: update.progress.clamp(0, 1),
                    color: AppTheme.cyan,
                    backgroundColor: tokens.border,
                    borderRadius: BorderRadius.circular(AppTheme.radiusIndicator),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l.updateDownloading((update.progress * 100).round()),
                  style: text.bodySmall?.copyWith(color: tokens.textFaint),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// What the new version improves, as a list the lawyer closes once read.
Future<void> showWhatsNew(BuildContext context, WhatsNew news) => showDialog<void>(
  context: context,
  builder: (context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final tokens = AppTokens.of(context);
    return AlertDialog(
      title: Text(l.whatsNewTitle(news.version)),
      content: SizedBox(
        width: AppTheme.dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.whatsNewIntro, style: text.bodyMedium?.copyWith(color: tokens.textMuted)),
              const SizedBox(height: 12),
              for (final item in news.improvements)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 7, right: 10),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(color: AppTheme.cyan, shape: BoxShape.circle),
                        ),
                      ),
                      Expanded(child: Text(item, style: text.bodyMedium)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(autofocus: true, onPressed: () => Navigator.pop(context), child: Text(l.gotIt)),
      ],
    );
  },
);
