import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../features/agent/whatsapp_bridge.dart';
import '../../l10n/l10n.dart';

class WhatsappPairingOverlay extends StatelessWidget {
  const WhatsappPairingOverlay({super.key, required this.bridge});

  final WhatsappBridge bridge;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: bridge.dismissPairing,
                      tooltip: l.close,
                      icon: const Icon(Icons.close),
                    ),
                  ),
                  Text(l.whatsappTitle, style: text.titleLarge),
                  const SizedBox(height: 12),
                  Text(l.whatsappScanQr, textAlign: TextAlign.center),
                  const SizedBox(height: 18),
                  if (bridge.qr case final qr?)
                    QrImageView(
                      data: qr,
                      size: 240,
                      backgroundColor: Colors.white,
                    )
                  else
                    const SizedBox(
                      height: 240,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    bridge.error ?? l.whatsappWaiting,
                    style: text.bodySmall?.copyWith(
                      color: AppTokens.of(context).textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
