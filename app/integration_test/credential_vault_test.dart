import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:paper_agent/features/access/desktop_credentials.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'OS vault writes, reads, replaces and deletes a synthetic credential',
    (_) async {
      const vault = SystemCredentialVault();
      const channel = MethodChannel('paper_agent/window');
      final key = 'daylex.test.${DateTime.now().microsecondsSinceEpoch}';
      try {
        expect(await vault.read(key), isNull);
        await vault.write(key, 'synthetic-value');
        expect(await vault.read(key), 'synthetic-value');
        await vault.write(key, 'replacement-value');
        expect(await vault.read(key), 'replacement-value');
        await expectLater(
          vault.read('outside.namespace'),
          throwsA(isA<PlatformException>()),
        );
      } finally {
        await channel.invokeMethod<void>('deleteCredential', {'key': key});
      }
      expect(await vault.read(key), isNull);
    },
  );
}
