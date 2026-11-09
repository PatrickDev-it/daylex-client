@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:paper_agent/core/platform/http_transport_web.dart' as transport;
import 'package:paper_agent/features/access/desktop_credentials.dart';
import 'package:paper_agent/features/agent/agent_controller.dart';
import 'package:paper_agent/features/agent/data/http_agent_client.dart';
import 'package:paper_agent/features/document/data/doc_templates.dart';
import 'package:paper_agent/features/document/render/pdf_renderer.dart';
import 'package:paper_agent/features/storage/local_store.dart';
import 'package:paper_agent/ui/settings/settings_view.dart';

import 'test_app.dart';

@JS('daylex')
external set runtime(JSObject value);

class _StreamingClient extends http.BaseClient {
  _StreamingClient(this.handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final records = <String, String>{};
  setUp(() {
    records.clear();
    final value = JSObject();
    value.setProperty(
      'read'.toJS,
      ((JSString key) => records[key.toDart]?.toJS).toJS,
    );
    value.setProperty(
      'write'.toJS,
      ((JSString key, JSString content, JSBoolean backup) {
        if (backup.toDart && records.containsKey(key.toDart)) {
          records['${key.toDart}.bak'] = records[key.toDart]!;
        }
        records[key.toDart] = content.toDart;
      }).toJS,
    );
    value.setProperty(
      'remove'.toJS,
      ((JSString key) {
        records.remove(key.toDart);
      }).toJS,
    );
    value.setProperty(
      'keys'.toJS,
      (() => jsonEncode(records.keys.toList()).toJS).toJS,
    );
    value.setProperty('pending'.toJS, false.toJS);
    value.setProperty('error'.toJS, null);
    value.setProperty(
      'flush'.toJS,
      (() => Future<JSAny?>.value(null).toJS).toJS,
    );
    runtime = value;
  });

  test('browser storage retains backup and protects data written by newer versions', () {
    final store = LocalStore.open()!;
    store.writeWorkspace({'title': 'old'});
    store.writeWorkspace({'title': 'new'});
    expect(store.readWorkspace()?['title'], 'new');
    expect(jsonDecode(records['data/workspace.json.bak']!)['title'], 'old');
    store.writeDocument('safe', {'version': 2, 'title': 'future'});
    expect(store.readDocument('safe')?['title'], 'future');
    expect(store.readOnly, isTrue);
    store.writeDocument('safe', {'title': 'must not overwrite'});
    expect(store.readDocument('safe')?['title'], 'future');
  });

  test(
    'web access key is session-only while device identity persists',
    () async {
      final vault = BrowserCredentialVault();
      await vault.write('daylex.device.v1', 'test-device');
      await vault.write('daylex.access.v1', 'test-secret');
      expect(await vault.read('daylex.access.v1'), 'test-secret');
      expect(await BrowserCredentialVault().read('daylex.access.v1'), isNull);
      expect(
        await BrowserCredentialVault().read('daylex.device.v1'),
        'test-device',
      );
      expect(records.values, isNot(contains('test-secret')));
    },
  );

  test('PDF renderer works in browser without native isolates', () async {
    // Browser widget tests do not install Flutter's native asset-channel mock.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', (message) async {
      final name = utf8.decode(
        message!.buffer.asUint8List(
          message.offsetInBytes,
          message.lengthInBytes,
        ),
      );
      final response = await http.get(Uri.base.resolve('/assets/$name'));
      expect(response.statusCode, 200, reason: name);
      return ByteData.sublistView(response.bodyBytes);
    });
    addTearDown(() => messenger.setMockMessageHandler('flutter/assets', null));
    final fonts = await PdfFontSet.load().timeout(const Duration(seconds: 10));
    final bytes = await PdfRenderer(fonts)
        .renderInBackground(docTemplates.first.build('test'));
    expect(utf8.decode(bytes.take(4).toList()), '%PDF');
    expect(bytes.length, greaterThan(1000));
  });

  test('HTTP response streams before completion and supports abort', () async {
    final body = StreamController<List<int>>();
    final aborted = Completer<void>();
    final client = transport.HttpClient(
      client: _StreamingClient((request) async {
        expect(request.followRedirects, isFalse);
        expect(request.headers['X-Daylex-Device'], 'test-device');
        (request as http.AbortableRequest).abortTrigger!.then(
          (_) => aborted.complete(),
        );
        return http.StreamedResponse(body.stream, 200);
      }),
    );
    final request = await client.postUrl(
      Uri.parse('https://example.test/v1/agent/runs'),
    );
    request.followRedirects = false;
    request.headers.set('X-Daylex-Device', 'test-device');
    final response = await request.close();
    final received = Completer<void>();
    final subscription = response.listen((bytes) {
      if (!received.isCompleted) received.complete();
    });
    body.add(utf8.encode('{"type":"delta"}\n'));
    await received.future.timeout(const Duration(seconds: 2));
    request.abort();
    await aborted.future.timeout(const Duration(seconds: 2));
    await subscription.cancel();
    await body.close();
    client.close();
  });

  for (final width in [1440.0, 1024.0]) {
    testWidgets('settings at $width px exclude desktop-only features', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStoreProvider.overrideWithValue(null),
            agentClientProvider.overrideWithValue(
              const UnavailableAgentClient('Non collegato'),
            ),
          ],
          child: testApp(const SettingsView()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('WhatsApp'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
