import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/platform/user_dirs.dart';
import 'operations_contract.g.dart';

abstract interface class CredentialVault {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SystemCredentialVault implements CredentialVault {
  const SystemCredentialVault();
  static const _channel = MethodChannel('paper_agent/window');
  @override
  Future<String?> read(String key) =>
      _channel.invokeMethod<String>('readCredential', {'key': key});
  @override
  Future<void> write(String key, String value) => _channel.invokeMethod<void>(
    'writeCredential',
    {'key': key, 'value': value},
  );
}

/// The only owner of desktop credentials. No secret is stored in workspace data.
class DesktopCredentials extends ChangeNotifier {
  DesktopCredentials(this.vault);
  static final instance = DesktopCredentials(const SystemCredentialVault());
  final CredentialVault vault;
  String? key;
  String? device;
  bool disclosed = false;
  bool validated = false;
  bool ready = false;
  bool failed = false;
  String area = 'chat';

  static File? get legacyFile {
    final home = userHome();
    return home == null ? null : File('$home/.paperagent/server.json');
  }

  Future<void> initialize({File? legacy}) async {
    ready = false;
    failed = false;
    try {
      device = await vault.read('daylex.device.v1');
      if (device == null) {
        final random = Random.secure();
        final fresh = base64Url
            .encode(List.generate(32, (_) => random.nextInt(256)))
            .replaceAll('=', '');
        await _verifiedWrite('daylex.device.v1', fresh);
        device = fresh;
      }
      if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(device!)) {
        throw const FormatException('device');
      }
      final saved = await vault.read('daylex.access.v1');
      if (saved != null) {
        final record = jsonDecode(saved) as Map<String, dynamic>;
        key = record['key'] as String?;
        validated = record['validated'] == true;
        disclosed = record['disclosure'] == disclosureVersion;
      }
      final source = legacy ?? legacyFile;
      if (source != null && source.existsSync()) {
        final old =
            jsonDecode(source.readAsStringSync()) as Map<String, dynamic>;
        if (old['token'] case final String token when token.isNotEmpty) {
          if (key == null) {
            await save(token, accepted: false, disclosure: false);
          }
          // Remove plaintext only after the protected write was read back successfully.
          old.remove('token');
          final temporary = File('${source.path}.tmp');
          temporary.writeAsStringSync(jsonEncode(old), flush: true);
          temporary.renameSync(source.path);
        }
      }
      ready = true;
    } on Object {
      failed = true;
      key = null;
      validated = false;
    }
    notifyListeners();
  }

  Future<void> _verifiedWrite(String name, String value) async {
    await vault.write(name, value);
    if (await vault.read(name) != value) {
      throw const FormatException('credential write verification');
    }
  }

  Future<void> save(
    String value, {
    required bool accepted,
    required bool disclosure,
  }) async {
    await _verifiedWrite(
      'daylex.access.v1',
      jsonEncode({
        'key': value,
        'validated': accepted,
        'disclosure': disclosure ? disclosureVersion : null,
      }),
    );
    key = value;
    validated = accepted;
    disclosed = disclosure;
    notifyListeners();
  }

  void authorize(HttpClientRequest request) {
    request.followRedirects = false;
    if (device != null) request.headers.set(deviceHeader, device!);
    if (disclosed) request.headers.set(disclosureHeader, disclosureVersion);
    request.headers.set(areaHeader, area);
  }
}
