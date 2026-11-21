import 'dart:io';

import '../../storage/local_store.dart';
import 'browser_page.dart';
import 'webkit_page.dart';
import 'windows_page.dart';

/// WebView2 on Windows, with its profile (the lawyer's sign-ins) in `browser` beside the lawyer's work; WebKit on
/// the Mac; none on Linux. None in tests: a test that opens a page brings its own engine.
BrowserEngine platformEngine() {
  if (Platform.environment['FLUTTER_TEST'] == 'true') return const ExternalBrowser();
  if (Platform.isWindows) {
    return WindowsBrowser('${Directory(LocalStore.dataPath()).parent.path}${Platform.pathSeparator}browser');
  }
  if (Platform.isMacOS) return WebKitBrowser();
  return const ExternalBrowser();
}
