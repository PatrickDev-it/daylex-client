import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_store.dart';
import 'workspace_state.dart';

/// What the center column shows.
enum AppSection { chat, settings }

enum EditorMode { preview, edit }

class UiState {
  const UiState({
    this.section = AppSection.chat,
    this.themeMode = ThemeMode.system,
    this.locale = defaultLocale,
    this.editorMode = EditorMode.preview,
    this.panelOpen = true,
    this.panelWidth = defaultPanelWidth,
    this.sidebarOpen = true,
    this.newChatProjectId,
  });

  final AppSection section;
  final ThemeMode themeMode;

  /// The product interface is Italian, including restored preferences from earlier versions.
  final Locale locale;
  final EditorMode editorMode;

  static const defaultLocale = Locale('it');
  static const defaultPanelWidth = 600.0;

  /// The side panel with preview/review/library/log tabs.
  final bool panelOpen;
  final double panelWidth;
  final bool sidebarOpen;

  /// Project picked on the new-chat screen.
  final String? newChatProjectId;

  UiState copyWith({
    AppSection? section,
    ThemeMode? themeMode,
    Locale? locale,
    EditorMode? editorMode,
    bool? panelOpen,
    double? panelWidth,
    bool? sidebarOpen,
    String? Function()? newChatProjectId,
  }) => UiState(
    section: section ?? this.section,
    themeMode: themeMode ?? this.themeMode,
    locale: locale ?? this.locale,
    editorMode: editorMode ?? this.editorMode,
    panelOpen: panelOpen ?? this.panelOpen,
    panelWidth: panelWidth ?? this.panelWidth,
    sidebarOpen: sidebarOpen ?? this.sidebarOpen,
    newChatProjectId: newChatProjectId != null
        ? newChatProjectId()
        : this.newChatProjectId,
  );
}

final uiProvider = NotifierProvider<UiNotifier, UiState>(UiNotifier.new);

class UiNotifier extends Notifier<UiState> {
  static const minPanelWidth = 360.0;
  static const maxPanelWidth = 1100.0;

  /// Opens with the theme and the language picked last time; a saved value this app does not know is left
  /// for the default.
  @override
  UiState build() {
    final saved = ref.read(localStoreProvider)?.readPreferences() ?? const {};
    return UiState(
      themeMode:
          ThemeMode.values.asNameMap()[saved['themeMode']] ?? ThemeMode.system,
      locale: UiState.defaultLocale,
    );
  }

  void _savePreferences() {
    final store = ref.read(localStoreProvider);
    if (store == null) return;
    try {
      store.writePreferences({
        'themeMode': state.themeMode.name,
        'locale': state.locale.languageCode,
      });
    } on FileSystemException catch (e) {
      store.saveFailed(e);
    }
  }

  void show(AppSection section) => state = state.copyWith(section: section);

  void openThread(String? threadId) {
    ref.read(workspaceProvider.notifier).selectThread(threadId);
    state = state.copyWith(section: AppSection.chat);
  }

  /// Shows the new-chat screen, optionally preselecting a project.
  void newChat({String? projectId}) {
    ref.read(workspaceProvider.notifier).selectThread(null);
    state = state.copyWith(
      section: AppSection.chat,
      newChatProjectId: projectId == null ? null : () => projectId,
    );
  }

  void setNewChatProject(String projectId) =>
      state = state.copyWith(newChatProjectId: () => projectId);

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _savePreferences();
  }

  void setLocale(Locale locale) {
    state = state.copyWith(locale: UiState.defaultLocale);
    _savePreferences();
  }

  void toggleTheme(Brightness current) => setThemeMode(
    current == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
  );

  void setEditorMode(EditorMode mode) =>
      state = state.copyWith(editorMode: mode);

  void togglePanel() => state = state.copyWith(panelOpen: !state.panelOpen);

  void showPanel() => state = state.copyWith(panelOpen: true);

  void resizePanel(double delta) => state = state.copyWith(
    panelWidth: (state.panelWidth + delta).clamp(minPanelWidth, maxPanelWidth),
  );

  void toggleSidebar() =>
      state = state.copyWith(sidebarOpen: !state.sidebarOpen);
}
