import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/core/platform/retired_whatsapp.dart';

void main() {
  late Directory home;
  setUp(() => home = Directory.systemTemp.createTempSync('daylex-home'));
  tearDown(() => home.deleteSync(recursive: true));

  File write(String path) => File('${home.path}/$path')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync('x');

  test('removes the WhatsApp Web session under APPDATA and nothing beside it', () async {
    final env = {'APPDATA': home.path, 'HOME': '/nowhere', 'USERPROFILE': '/nowhere'};
    final session = write('Daylex/WhatsApp/session/Default/Cookies');
    final sibling = write('Daylex/other.json');
    await forgetWhatsappSession(environment: env);
    expect(session.existsSync(), isFalse);
    expect(Directory('${home.path}/Daylex/WhatsApp').existsSync(), isFalse);
    expect(sibling.existsSync(), isTrue);
  });

  test('without APPDATA it looks where the bridge did, under ~/.config', () async {
    final env = {'APPDATA': '', 'HOME': home.path, 'USERPROFILE': home.path};
    final session = write('.config/Daylex/WhatsApp/session/Default/Cookies');
    await forgetWhatsappSession(environment: env);
    expect(session.existsSync(), isFalse);
    expect(Directory('${home.path}/.config/Daylex').existsSync(), isTrue);
  });

  test('a computer that never paired WhatsApp is left as it is', () async {
    final env = {'HOME': home.path, 'USERPROFILE': home.path};
    final kept = write('.config/Daylex/kept.json');
    await forgetWhatsappSession(environment: env);
    expect(kept.existsSync(), isTrue);
    expect(whatsappSessionDir(const {}), isNull);
  });
}
