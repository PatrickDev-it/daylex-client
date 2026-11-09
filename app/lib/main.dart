import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/platform/sandbox_migration.dart';
import 'core/platform/instance_lock.dart';
import 'core/platform/user_dirs.dart';
import 'features/access/desktop_credentials.dart';
import 'features/access/service_status.dart';
import 'l10n/l10n.dart';

InstanceLock? _instanceLock;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (!kIsWeb) _instanceLock ??= InstanceLock.acquire(Directory(appDataDir()));
  } on FileSystemException {
    final l = lookupAppLocalizations(const Locale('it'));
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(l.instanceUnavailable, textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );
    return;
  }
  // Before anything reads the saved work: on a Mac coming from the sandboxed app, it is still in the container.
  if (!kIsWeb) migrateSandboxData();
  await DesktopCredentials.instance.initialize();
  runApp(
    ProviderScope(
      overrides: [desktopAccessEnabledProvider.overrideWithValue(true)],
      child: const PaperAgentApp(),
    ),
  );
}
