import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../features/access/desktop_credentials.dart';
import '../../features/access/operations_contract.g.dart';
import '../../features/access/service_status.dart';
import '../../features/agent/agent_controller.dart';
import '../../features/agent/data/http_agent_client.dart';
import '../../l10n/l10n.dart';
import '../../core/theme/daylex_mark.dart';

class AccessGate extends ConsumerWidget {
  const AccessGate({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(desktopAccessEnabledProvider)) return child;
    final credentials = DesktopCredentials.instance;
    final service = ref.watch(serviceStatusProvider);
    return ListenableBuilder(
      listenable: Listenable.merge([credentials, service]),
      builder: (context, _) {
        if (!credentials.ready ||
            !credentials.validated ||
            !credentials.disclosed ||
            service.denied) {
          return Scaffold(
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: AccessForm(
                    problem: service.denied ? service.message : null,
                  ),
                ),
              ),
            ),
          );
        }
        final l = context.l10n;
        return Column(
          children: [
            if (service.maintenance || service.offline)
              MaterialBanner(
                leading: const Icon(LucideIcons.info),
                content: Text(
                  service.offline ? l.serviceOffline : l.serviceMaintenance,
                ),
                actions: [
                  TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(
                          service.offline
                              ? l.serviceOffline
                              : l.serviceMaintenance,
                        ),
                        content: Text(
                          service.offline
                              ? l.serviceOfflineHelp
                              : service.message.isEmpty
                              ? l.serviceMaintenanceHelp
                              : service.message,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(l.gotIt),
                          ),
                        ],
                      ),
                    ),
                    child: Text(l.serviceDetails),
                  ),
                  TextButton(
                    onPressed: service.checking ? null : service.check,
                    child: Text(l.serviceRetry),
                  ),
                ],
              ),
            Expanded(key: const ValueKey('workspace'), child: child),
          ],
        );
      },
    );
  }
}

/// Shared between first activation and changing the key; errors stay next to the field.
class AccessForm extends ConsumerStatefulWidget {
  const AccessForm({this.problem, this.onAccepted, super.key});
  final String? problem;
  final VoidCallback? onAccepted;
  @override
  ConsumerState<AccessForm> createState() => _AccessFormState();
}

class _AccessFormState extends ConsumerState<AccessForm> {
  late final _key = TextEditingController(
    text: DesktopCredentials.instance.key ?? '',
  );
  bool _disclosed = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final key = _key.text.trim();
    if (!_disclosed || _busy) return;
    if (!key.startsWith(accessKeyPrefix) ||
        key.length != accessKeyLength ||
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(key)) {
      setState(() => _error = l.accessInvalidKey);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!DesktopCredentials.instance.ready) {
        await DesktopCredentials.instance.initialize();
      }
      if (!DesktopCredentials.instance.ready) throw StateError('vault');
      final (verdict, reason) = await AgentServerConfig.check(key, l);
      if (verdict != KeyCheck.accepted) {
        if (mounted) setState(() => _error = reason ?? l.serverKeyRejected);
        return;
      }
      await AgentServerConfig.saveKey(key, l);
      if (!mounted) return;
      ref.invalidate(agentClientProvider);
      ref.invalidate(serviceStatusProvider);
      widget.onAccepted?.call();
    } on Object {
      if (mounted) setState(() => _error = l.accessVaultFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const DaylexMark(size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l.accessTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(kIsWeb ? l.webAccessHelp : l.accessHelp),
          if (kIsWeb) ...[const SizedBox(height: 12), Text(l.webSessionHelp)],
          const SizedBox(height: 24),
          TextField(
            controller: _key,
            autofocus: true,
            obscureText: _obscure,
            enabled: !_busy,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: l.settingsAccessKey,
              hintText: l.accessKeyHint,
              errorText:
                  _error ??
                  widget.problem ??
                  (DesktopCredentials.instance.failed
                      ? l.accessVaultFailed
                      : null),
              errorMaxLines: 4,
              suffixIcon: IconButton(
                tooltip: _obscure ? l.accessShowKey : l.accessHideKey,
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? LucideIcons.eye : LucideIcons.eyeOff),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l.accessDisclosure,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _disclosed,
            onChanged: _busy
                ? null
                : (v) => setState(() => _disclosed = v ?? false),
            title: Text(l.accessAcknowledge),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy || !_disclosed ? null : _submit,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _busy ? l.settingsAccessKeyChecking : l.accessActivate,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showAccessDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: AccessForm(onAccepted: () => Navigator.pop(dialogContext)),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dialogContext),
        child: Text(context.l10n.cancel),
      ),
    ],
  ),
);
