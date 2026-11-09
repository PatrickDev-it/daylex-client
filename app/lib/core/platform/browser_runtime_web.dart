import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

@JS('daylex.read')
external JSString? _read(JSString name);
@JS('daylex.write')
external void _write(JSString name, JSString value, JSBoolean backup);
@JS('daylex.remove')
external void _remove(JSString name);
@JS('daylex.keys')
external JSString _keys();
@JS('daylex.modified')
external JSNumber? _modified(JSString name);
@JS('daylex.pending')
external JSBoolean get _pending;
@JS('daylex.error')
external JSString? get _error;
@JS('daylex.onChange')
external set _onChange(JSFunction callback);
@JS('daylex.onSave')
external set _onSave(JSFunction callback);
@JS('daylex.flush')
external JSPromise<JSAny?> _flush();
@JS('daylex.download')
external void _download(JSUint8Array bytes, JSString name, JSString type);

String? read(String name) => _read(name.toJS)?.toDart;
void write(String name, String value, {bool backup = false}) =>
    _write(name.toJS, value.toJS, backup.toJS);
void remove(String name) => _remove(name.toJS);
List<String> keys() => (jsonDecode(_keys().toDart) as List).cast<String>();
DateTime? modified(String name) {
  final value = _modified(name.toJS)?.toDartInt;
  return value == null ? null : DateTime.fromMillisecondsSinceEpoch(value);
}

bool get pending => _pending.toDart;
String? get error => _error?.toDart;
void onChange(void Function() callback) => _onChange = callback.toJS;
void onSave(bool Function() callback) => _onSave = callback.toJS;
Future<void> flush() async => await _flush().toDart;
void download(Uint8List bytes, String name, String type) =>
    _download(bytes.toJS, name.toJS, type.toJS);
