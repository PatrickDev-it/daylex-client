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
    this.themeMode = ThemeMode.dark,
    this.locale = defaultLocale,
    this.editorMode = EditorMode.preview,
    this.panelOpen = true,
    this.panelWidth = defaultPanelWidth,
    this.panelFull = false,
    this.panelFits = true,
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

  /// The side panel with the chat's tabs and the web tabs.
  final bool panelOpen;
  final double panelWidth;

  /// The panel in the chat's place, at full width.
  final bool panelFull;

  /// The window has room for the panel beside the chat, as the shell measured it last. Without room an open
  /// panel waits behind the chat, and a panel asked for comes in the chat's place.
  final bool panelFits;

  /// On screen, beside the chat or in its place.
  bool get panelShown => panelOpen && (panelFits || panelFull);
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
    bool? panelFull,
    bool? panelFits,
    bool? sidebarOpen,
    String? Function()? newChatProjectId,
  }) => UiState(
    section: section ?? this.section,
    themeMode: themeMode ?? this.themeMode,
    locale: locale ?? this.locale,
    editorMode: editorMode ?? this.editorMode,
    panelOpen: panelOpen ?? this.panelOpen,
    panelWidth: panelWidth ?? this.panelWidth,
    panelFull: panelFull ?? this.panelFull,
    panelFits: panelFits ?? this.panelFits,
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

  /// Opens with the theme, the language and the panel width picked last time; a saved value this app does not
  /// know is left for the default.
  @override
  UiState build() {
    final saved = ref.read(localStoreProvider)?.readPreferences() ?? const {};
    final width = saved['panelWidth'];
    return UiState(
      themeMode:
          ThemeMode.values.asNameMap()[saved['themeMode']] ?? ThemeMode.dark,
      locale: UiState.defaultLocale,
      panelWidth: width is num
          ? width.toDouble().clamp(minPanelWidth, maxPanelWidth)
          : UiState.defaultPanelWidth,
    );
  }

  void _savePreferences() {
    final store = ref.read(localStoreProvider);
    if (store == null) return;
    try {
      store.writePreferences({
        'themeMode': state.themeMode.name,
        'locale': state.locale.languageCode,
        'panelWidth': state.panelWidth,
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

  /// Hides the panel when it is on screen, shows it otherwise. Hiding also leaves the full width: the chat comes
  /// back.
  void togglePanel() => state.panelShown
      ? state = state.copyWith(panelOpen: false, panelFull: false)
      : showPanel();

  /// The panel on screen: in the chat's place when there is no room beside it.
  void showPanel() => state = state.copyWith(
    panelOpen: true,
    panelFull: state.panelFull || !state.panelFits,
  );

  /// What the shell measured; see [UiState.panelFits].
  void setPanelFits(bool fits) {
    if (state.panelFits != fits) state = state.copyWith(panelFits: fits);
  }

  /// The panel in the chat's place, or back beside it.
  void toggleFullPanel() => state = state.copyWith(
    panelOpen: true,
    panelFull: !state.panelFull,
  );

  void exitFullPanel() {
    if (state.panelFull) state = state.copyWith(panelFull: false);
  }

  /// Follows the pointer; [endResize] saves the width once the drag ends.
  void resizePanel(double delta) => state = state.copyWith(
    panelWidth: (state.panelWidth + delta).clamp(minPanelWidth, maxPanelWidth),
  );

  void endResize() => _savePreferences();

  void resetPanelWidth() {
    state = state.copyWith(panelWidth: UiState.defaultPanelWidth);
    _savePreferences();
  }

  void toggleSidebar() =>
      state = state.copyWith(sidebarOpen: !state.sidebarOpen);
}
