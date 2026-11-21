import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../document/model/document.dart';
import '../storage/local_store.dart';

/// The studio's style (rfc/055): the theme every new document starts from, letterhead and logo included. The agent
/// saves it when the lawyer asks (`saveAsDefault`); until then a new document is set as DM 110 asks
/// ([DocTheme.legal]).
final studioStyleProvider = NotifierProvider<StudioStyleNotifier, DocTheme>(StudioStyleNotifier.new);

class StudioStyleNotifier extends Notifier<DocTheme> {
  @override
  DocTheme build() {
    final saved = ref.read(localStoreProvider)?.readDocumentStyle();
    return saved == null ? DocTheme.legal : DocTheme.fromJson(saved);
  }

  void save(DocTheme theme) {
    state = theme;
    final store = ref.read(localStoreProvider);
    if (store == null) return;
    try {
      store.writeDocumentStyle(theme.toJson());
    } on FileSystemException catch (e) {
      store.saveFailed(e);
    }
  }
}
