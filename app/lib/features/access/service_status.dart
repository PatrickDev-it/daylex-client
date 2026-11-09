import 'dart:async';
import 'dart:convert';
import '../../core/platform/http_transport.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../l10n/l10n.dart';
import '../agent/data/http_agent_client.dart';
import 'desktop_credentials.dart';
import 'operations_contract.g.dart';

final desktopAccessEnabledProvider = Provider<bool>((_) => false);
final serviceStatusProvider = Provider<ServiceStatus>((ref) {
  final status = ServiceStatus(ref.read(l10nProvider));
  ref.onDispose(status.dispose);
  status.start();
  return status;
});

/// Foreground presence and service state. Failure never becomes a healthy status.
class ServiceStatus extends ChangeNotifier {
  ServiceStatus(this.l, {this.endpoint, DesktopCredentials? credentials})
    : credentials = credentials ?? DesktopCredentials.instance;
  final AppLocalizations l;
  final Uri? endpoint;
  final DesktopCredentials credentials;
  final _http = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  bool maintenance = false;
  bool offline = false;
  bool checking = false;
  bool denied = false;
  bool _disposed = false;
  bool foreground = true;
  String message = '';
  String version = '';
  DateTime? checkedAt;

  void start() {
    _timer = Timer.periodic(
      const Duration(seconds: heartbeatSeconds),
      (_) => check(),
    );
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        foreground = state == AppLifecycleState.resumed;
        check();
      },
    );
    unawaited(
      PackageInfo.fromPlatform()
          .then((p) {
            version = '${p.version}+${p.buildNumber}';
          })
          .catchError((Object _) {}),
    );
    scheduleMicrotask(check);
  }

  Future<void> check() async {
    if (_disposed || checking) return;
    checking = true;
    notifyListeners();
    try {
      final key = credentials.key;
      final presence = key != null && credentials.validated;
      final uri = (endpoint ?? AgentServerConfig.server(l)).resolve(
        presence ? presencePath : serviceStatusPath,
      );
      final request = await _http
          .openUrl(presence ? 'POST' : 'GET', uri)
          .timeout(const Duration(seconds: 10));
      credentials.authorize(request);
      if (presence) {
        request.headers
          ..set(HttpHeaders.authorizationHeader, 'Bearer $key')
          ..contentType = ContentType.json;
        request.write(
          jsonEncode({
            'area': credentials.area,
            'version': version,
            'foreground': foreground,
            'platform': kIsWeb ? 'other' : Platform.isWindows
                ? 'windows'
                : Platform.isMacOS
                ? 'macos'
                : 'other',
          }),
        );
      }
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 10))) {
        bytes.addAll(chunk);
        if (bytes.length > 65536) {
          throw const FormatException('status response');
        }
      }
      if (_disposed) return;
      final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if ({401, 403, 426}.contains(response.statusCode)) {
        denied = true;
        message = data['detail'] as String? ?? l.serverKeyRejected;
      } else if (response.statusCode == 503) {
        maintenance = true;
        offline = false;
        message =
            data['message'] as String? ??
            data['detail'] as String? ??
            l.serviceMaintenance;
      } else if (response.statusCode == 200 &&
          data['schema'] == 1 &&
          data['maintenance'] is bool) {
        maintenance = data['maintenance'] as bool;
        message = data['message'] as String? ?? '';
        offline = false;
        denied = false;
      } else {
        throw const FormatException('unsupported service status');
      }
      checkedAt = DateTime.now();
    } on Object {
      if (!_disposed) offline = true;
    } finally {
      checking = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _lifecycle?.dispose();
    _http.close(force: true);
    super.dispose();
  }
}
