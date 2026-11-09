import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../document/model/document.dart';
import 'workspace_model.dart';

/// What a first launch opens on, when nothing was ever saved: one empty project for the lawyer's work, no chats,
/// no documents (docs/adr/ADR-0002-primo-avvio.md). One project is always there: a new chat goes in one.
WorkspaceState firstRunWorkspace(String projectName) => WorkspaceState(
  projects: [Project(id: newId(), name: projectName, color: kProjectPalette.first)],
  documents: const {},
);

final firstRunWorkspaceProvider = Provider<WorkspaceState>(
  (ref) => firstRunWorkspace(ref.read(l10nProvider).firstProject),
);
