import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/user_dirs.dart';
import '../../core/platform/browser_runtime.dart' as browser;
import '../../l10n/app_localizations.dart';

/// Something the lawyer must know about the saved work. Kept as data, not text: the banner words it in the
/// app language when it is shown.
sealed class StoreNotice {
  const StoreNotice();

  String text(AppLocalizations l);
}

/// A file from a newer app was read: shown, never written over.
class NewerDataNotice extends StoreNotice {
  const NewerDataNotice();

  @override
  String text(AppLocalizations l) => l.storeNoticeNewer;
}

/// The workspace index was damaged and the save before it took its place.
class IndexRestoredNotice extends StoreNotice {
  const IndexRestoredNotice();

  @override
  String text(AppLocalizations l) => l.storeNoticeRestored;
}

class SaveFailedNotice extends StoreNotice {
  const SaveFailedNotice(this.reason);

  final String reason;

  @override
  String text(AppLocalizations l) => l.storeNoticeSaveFailed(reason);
}

/// A file could not be read now, held by another program (an antivirus scanning it): what could be read is
/// shown, and nothing is written until the app opens again, so no file is written over without being read.
class UnreadableNotice extends StoreNotice {
  const UnreadableNotice(this.reason);

  final String reason;

  @override
  String text(AppLocalizations l) => l.storeNoticeUnreadable(reason);
}

/// The workspace index was unreadable and was rebuilt from the files on disk.
class IndexRecoveredNotice extends StoreNotice {
  const IndexRecoveredNotice({required this.documents, required this.chats, required this.project});

  final int documents;
  final int chats;
  final String project;

  @override
  String text(AppLocalizations l) => l.storeNoticeRecovered(documents, chats, project);
}

/// The lawyer's work on this computer: projects, chats, documents (see docs/adr/ADR-0001-dati-locali.md).
///
/// One JSON file per entity under [root], each written atomically (temp file, then rename), so a crash
/// mid-write never leaves half a file:
///
///     workspace.json          projects, chats without messages, the open chat
///     workspace.json.bak      the index as the save before wrote it, in case workspace.json is lost
///     documents/<id>.json     one document
///     chats/<id>.json         one chat's messages and turns
///     snapshots/<id>.json     a document version a message refers to; immutable, written once
///     preferences.json        the theme and the language the lawyer picked
class LocalStore {
  LocalStore(Directory root) : _root = root;
  LocalStore._browser() : _root = null {
    browser.onChange(() {
      final problem = browser.error;
      if (problem != null) notice.value = SaveFailedNotice(problem);
    });
  }

  /// Bumped when a file's shape changes, a new block type included: an older app would drop what it cannot
  /// read on its next save, so it meets a newer file read-only. Readers bring older files up in [_migrate].
  static const version = 1;

  /// How long a change waits before it is written: edits that follow close together become one save.
  static const saveDelay = Duration(milliseconds: 300);

  final Directory? _root;
  Directory get root => _root!;

  /// What the lawyer must know about the saved work (a file set aside, a save that failed), until dismissed.
  final notice = ValueNotifier<StoreNotice?>(null);

  /// True once a file from a newer app was read, or a file could not be read or set aside: everything is shown
  /// as far as it could be, and nothing is written over it until the app opens again.
  bool get readOnly => _newer || _held;
  var _newer = false;
  var _held = false;
  final _unsaved = <String>{};
  bool get hasUnsavedWrites => _unsaved.isNotEmpty || (kIsWeb && browser.pending);

  /// How many times a file another program holds is tried before giving up, and the pause between tries:
  /// an antivirus or an indexer holds a file for moments.
  static const _readTries = 3;
  static const _readPause = Duration(milliseconds: 50);

  /// The platform's per-user app data folder, or `PAPERAGENT_DATA`. None in tests: they start from an empty
  /// first launch, or their own fixture, and write nothing.
  static LocalStore? open() {
    if (kIsWeb) return LocalStore._browser();
    final env = Platform.environment;
    if (env['FLUTTER_TEST'] == 'true') return null;
    final custom = env['PAPERAGENT_DATA'];
    final path = custom != null && custom.isNotEmpty ? custom : '${appDataDir(env)}${Platform.pathSeparator}data';
    return LocalStore(Directory(path));
  }

  File _file(String relative) => File('${root.path}${Platform.pathSeparator}$relative');
  bool _exists(String relative) => kIsWeb ? browser.read('data/$relative') != null : _file(relative).existsSync();

  /// File names from ids: an id never escapes its folder.
  static String _safe(String id) => id.replaceAll(RegExp(r'[^A-Za-z0-9_.@-]'), '_');

  Map<String, dynamic>? _read(String relative) {
    if (!_exists(relative)) return null;
    final List<int> bytes;
    try {
      bytes = kIsWeb ? utf8.encode(browser.read('data/$relative')!) : _bytes(_file(relative));
    } on FileSystemException catch (e) {
      // The system's refusal, not the content's fault: the file stays as it is, and is not written over.
      if (_exists(relative)) _hold(relative, e);
      return null;
    }
    final Map<String, dynamic> json;
    try {
      json = (jsonDecode(utf8.decode(bytes)) as Map).cast<String, dynamic>();
    } on Object {
      // Not text, not JSON, or JSON that is not an object: damaged.
      setAside(relative);
      return null;
    }
    final rawVersion = json['version'];
    if (rawVersion != null && (rawVersion is! int || rawVersion < 1)) {
      setAside(relative);
      return null;
    }
    final written = rawVersion as int? ?? 1;
    if (written > version && !_newer) {
      _newer = true;
      notice.value = const NewerDataNotice();
    }
    return _migrate(json, written);
  }

  /// The bytes of [file], tried again while another program holds it. Bytes, not text: text that does not
  /// decode is damage, and the read error would hide it.
  static List<int> _bytes(File file) {
    for (var tried = 1; ; tried++) {
      try {
        return file.readAsBytesSync();
      } on FileSystemException {
        if (tried == _readTries) rethrow;
        sleep(_readPause);
      }
    }
  }

  /// [relative] could not be read, or set aside, for [e]: nothing more is written, so it is never written over.
  void _hold(String relative, FileSystemException e) {
    debugPrint('PaperAgent: cannot read $relative now: $e');
    _held = true;
    notice.value = UnreadableNotice(e.osError?.message ?? e.message);
  }

  /// An older file in the current shape. Version 1 is the first one: nothing to bring up yet.
  static Map<String, dynamic> _migrate(Map<String, dynamic> json, int from) => json;

  /// Keeps a file that cannot be read for a human, never overwritten silently.
  void setAside(String relative) {
    if (kIsWeb) {
      final content = browser.read('data/$relative');
      if (content != null) {
        browser.write('data/$relative.corrupt-${DateTime.now().millisecondsSinceEpoch}', content);
        browser.remove('data/$relative');
      }
      return;
    }
    final file = _file(relative);
    if (!file.existsSync()) return;
    try {
      file.renameSync('${file.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}');
    } on FileSystemException catch (e) {
      // Not kept aside: then not written over either.
      _hold(relative, e);
    }
  }

  void _write(String relative, Map<String, dynamic> json, {bool keepPrevious = false}) {
    _unsaved.add(relative);
    _writeFile(relative, json, keepPrevious: keepPrevious);
    if (!readOnly) _unsaved.remove(relative);
  }

  void _writeFile(String relative, Map<String, dynamic> json, {bool keepPrevious = false}) {
    if (readOnly) return;
    // A component prop that is not JSON (a DateTime) is kept as text rather than losing the whole chat.
    final text = jsonEncode({
      'version': version,
      ...json,
    }, toEncodable: (o) => o is DateTime ? o.toIso8601String() : o.toString());
    if (kIsWeb) {
      browser.write('data/$relative', text, backup: keepPrevious);
      return;
    }
    final file = _file(relative);
    file.parent.createSync(recursive: true);
    final temp = File('${file.path}.tmp');
    temp.writeAsStringSync(text, flush: true);
    if (keepPrevious && file.existsSync()) file.copySync('${file.path}.bak');
    temp.renameSync(file.path);
  }

  void _delete(String relative) {
    _unsaved.add(relative);
    if (readOnly) return;
    if (kIsWeb) {
      browser.remove('data/$relative');
      _unsaved.remove(relative);
      return;
    }
    final file = _file(relative);
    if (file.existsSync()) file.deleteSync();
    _unsaved.remove(relative);
  }

  /// Ids of the files in [folder], for rebuilding a lost index.
  List<String> _ids(String folder) {
    if (kIsWeb) {
      final prefix = 'data/$folder/';
      return [for (final key in browser.keys())
        if (key.startsWith(prefix) && key.endsWith('.json')) key.substring(prefix.length, key.length - 5)]..sort();
    }
    final dir = Directory('${root.path}${Platform.pathSeparator}$folder');
    if (!dir.existsSync()) return const [];
    return [
      for (final f in dir.listSync().whereType<File>())
        if (f.uri.pathSegments.last case final name when name.endsWith('.json'))
          name.substring(0, name.length - '.json'.length),
    ]..sort();
  }

  /// The workspace index. One that cannot be read is set aside, and the copy the save before kept takes
  /// its place: at most the last few seconds of reorganising are lost, never the work.
  Map<String, dynamic>? readWorkspace() {
    final existed = _exists('workspace.json');
    if (_read('workspace.json') case final json?) return json;
    final backup = _read('workspace.json.bak');
    // Restored only if it was damaged and set aside: one held by another program is still there, and said so.
    if (backup != null && existed && !_exists('workspace.json')) {
      notice.value = const IndexRestoredNotice();
    }
    return backup;
  }

  void writeWorkspace(Map<String, dynamic> json) => _write('workspace.json', json, keepPrevious: true);

  Map<String, dynamic>? readDocument(String id) => _read('documents/${_safe(id)}.json');
  void writeDocument(String id, Map<String, dynamic> json) => _write('documents/${_safe(id)}.json', json);
  void deleteDocument(String id) => _delete('documents/${_safe(id)}.json');
  List<String> documentIds() => _ids('documents');

  Map<String, dynamic>? readChat(String id) => _read('chats/${_safe(id)}.json');
  void writeChat(String id, Map<String, dynamic> json) => _write('chats/${_safe(id)}.json', json);
  void deleteChat(String id) => _delete('chats/${_safe(id)}.json');
  void setAsideChat(String id) => setAside('chats/${_safe(id)}.json');
  List<String> chatIds() => _ids('chats');

  /// When the chat file was last written, for a chat rebuilt without its index.
  DateTime? chatSavedAt(String id) {
    if (kIsWeb) return browser.modified('data/chats/${_safe(id)}.json');
    final file = _file('chats/${_safe(id)}.json');
    return file.existsSync() ? file.lastModifiedSync() : null;
  }

  Map<String, dynamic>? readSnapshot(String id) => _read('snapshots/${_safe(id)}.json');
  bool hasSnapshot(String id) => _exists('snapshots/${_safe(id)}.json');
  void writeSnapshot(String id, Map<String, dynamic> json) => _write('snapshots/${_safe(id)}.json', json);

  Map<String, dynamic>? readPreferences() => _read('preferences.json');
  void writePreferences(Map<String, dynamic> json) => _write('preferences.json', json);

  /// A save that failed: the lawyer hears of it once, not at every keystroke.
  void saveFailed(FileSystemException e) {
    debugPrint('PaperAgent: could not save: $e');
    notice.value = SaveFailedNotice(e.osError?.message ?? e.message);
  }
}

final localStoreProvider = Provider<LocalStore?>((_) => LocalStore.open());
