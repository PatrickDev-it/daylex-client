import 'dart:typed_data';
String? read(String name) => null;
void write(String name, String value, {bool backup = false}) => throw UnsupportedError('Browser only');
void remove(String name) => throw UnsupportedError('Browser only');
List<String> keys() => const [];
DateTime? modified(String name) => null;
bool get pending => false;
String? get error => null;
void onChange(void Function() callback) {}
void onSave(bool Function() callback) {}
Future<void> flush() async {}
void download(Uint8List bytes, String name, String type) => throw UnsupportedError('Browser only');
