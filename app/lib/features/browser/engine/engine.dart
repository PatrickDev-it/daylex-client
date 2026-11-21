import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'browser_page.dart';
import 'platform_engine_none.dart' if (dart.library.io) 'platform_engine_io.dart';

export 'browser_page.dart';

/// The engine this computer draws web tabs with; tests put a fake in its place.
final browserEngineProvider = Provider<BrowserEngine>((_) => platformEngine());

final browserSupportProvider = FutureProvider<BrowserSupport>((ref) => ref.watch(browserEngineProvider).support());
