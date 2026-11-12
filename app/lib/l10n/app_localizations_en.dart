// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Daylex';

  @override
  String get languageItalian => 'Italiano';

  @override
  String get languageEnglish => 'English';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get close => 'Close';

  @override
  String get rename => 'Rename';

  @override
  String get save => 'Save';

  @override
  String get untitledDocument => 'Untitled document';

  @override
  String get untitledProject => 'Untitled project';

  @override
  String get firstProject => 'General';

  @override
  String get newChat => 'New chat';

  @override
  String get newDocument => 'New document';

  @override
  String get exportPdf => 'Export PDF';

  @override
  String get settings => 'Settings';

  @override
  String get whatsappTitle => 'WhatsApp';

  @override
  String get whatsappConnect => 'Connect WhatsApp';

  @override
  String get whatsappConnected => 'Connected';

  @override
  String get whatsappWaiting => 'Waiting for connection';

  @override
  String get whatsappScanQr => 'Scan the QR in WhatsApp > Linked devices';

  @override
  String get whatsappUnavailable => 'WhatsApp unavailable';

  @override
  String get whatsappHelp =>
      'Text messages and appointments through the agent, with the session saved on this computer.';

  @override
  String get whatsappCheckStatus => 'Checking WhatsApp';

  @override
  String get whatsappSearchContact => 'Searching WhatsApp contacts';

  @override
  String get whatsappSendText => 'Sending a WhatsApp message';

  @override
  String pageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return '$_temp0';
  }

  @override
  String wordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words',
      one: '1 word',
    );
    return '$_temp0';
  }

  @override
  String pageNumber(int page) {
    return 'Page $page';
  }

  @override
  String get timeNow => 'just now';

  @override
  String timeMinutesAgo(int minutes) {
    return '$minutes min ago';
  }

  @override
  String timeHoursAgo(int hours) {
    return '$hours h ago';
  }

  @override
  String timeDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days ago',
      one: 'yesterday',
    );
    return '$_temp0';
  }

  @override
  String timeYesterdayAt(String time) {
    return 'Yesterday $time';
  }

  @override
  String get monthsShort => 'Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec';

  @override
  String dateThisYear(int day, String month) {
    return '$month $day';
  }

  @override
  String dateOtherYear(int day, String month, String year) {
    return '$month $day $year';
  }

  @override
  String dateAt(String date, String time) {
    return '$date, $time';
  }

  @override
  String get docStatusDraft => 'Draft';

  @override
  String get docStatusReview => 'In review';

  @override
  String get docStatusApproved => 'Approved';

  @override
  String get layoutCover => 'Cover';

  @override
  String get layoutStandard => 'Standard';

  @override
  String get layoutTwoColumn => 'Two columns';

  @override
  String get layoutPremium => 'Premium';

  @override
  String get blockHeading => 'Heading';

  @override
  String get blockParagraph => 'Paragraph';

  @override
  String get blockBullets => 'Bullet list';

  @override
  String get blockTable => 'Table';

  @override
  String get blockMetrics => 'Metrics';

  @override
  String get blockQuote => 'Quote';

  @override
  String get blockCallout => 'Callout';

  @override
  String get blockImage => 'Image';

  @override
  String get opAddPage => 'Add page';

  @override
  String opDeletePage(int page) {
    return 'Delete page $page';
  }

  @override
  String opMovePage(int page) {
    return 'Move page $page';
  }

  @override
  String opUpdatePage(int page) {
    return 'Update page $page';
  }

  @override
  String opReplace(String find) {
    return 'Replace \"$find\"';
  }

  @override
  String opInsertBlock(String kind) {
    return 'Insert $kind';
  }

  @override
  String opEditBlock(String kind) {
    return 'Edit $kind';
  }

  @override
  String get opRemoveBlock => 'Remove block';

  @override
  String get opMoveBlock => 'Move block';

  @override
  String get opChangeTheme => 'Change theme';

  @override
  String get opUpdateDetails => 'Update details';

  @override
  String get shortcutNewChat => 'New chat';

  @override
  String get shortcutNewDocument => 'New document';

  @override
  String get shortcutFocusPrompt => 'Focus the prompt';

  @override
  String get shortcutStopAgent => 'Stop the agent';

  @override
  String get shortcutExport => 'Export PDF';

  @override
  String get shortcutUndo => 'Undo';

  @override
  String get shortcutRedo => 'Redo';

  @override
  String get shortcutPreview => 'Document preview';

  @override
  String get shortcutEdit => 'Edit the document';

  @override
  String get shortcutPreviousPage => 'Previous page';

  @override
  String get shortcutNextPage => 'Next page';

  @override
  String get shortcutZoomIn => 'Zoom in';

  @override
  String get shortcutZoomOut => 'Zoom out';

  @override
  String get shortcutZoomReset => 'Reset zoom';

  @override
  String get shortcutLibraryTab => 'Library';

  @override
  String get shortcutReviewTab => 'Review changes';

  @override
  String get shortcutLogTab => 'Agent log';

  @override
  String get shortcutCloseTab => 'Close tab';

  @override
  String get shortcutToggleSidebar => 'Toggle sidebar';

  @override
  String get shortcutTogglePanel => 'Toggle side panel';

  @override
  String get shortcutToggleTheme => 'Toggle dark mode';

  @override
  String get tabPreview => 'Live preview';

  @override
  String get tabReview => 'Review';

  @override
  String tabReviewCount(int count) {
    return 'Review · $count';
  }

  @override
  String get tabLibrary => 'Library';

  @override
  String get tabLog => 'Diagnostics';

  @override
  String get tabDocument => 'Document';

  @override
  String deleteTitle(String title) {
    return 'Delete \"$title\"?';
  }

  @override
  String get deleteChatMessage =>
      'Its messages and the files read into its case file are deleted too. This cannot be undone.';

  @override
  String get deleteDocumentMessage =>
      'Its version history is deleted too. This cannot be undone.';

  @override
  String documentCreated(String title) {
    return 'Created \"$title\"';
  }

  @override
  String documentDeleted(String title) {
    return 'Deleted \"$title\"';
  }

  @override
  String get exportNoDocument => 'Open a document to export it.';

  @override
  String exportedTo(String path) {
    return 'Exported to $path';
  }

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String undid(String label) {
    return 'Undid: $label';
  }

  @override
  String redid(String label) {
    return 'Redid: $label';
  }

  @override
  String get templatePickerHint =>
      'Start from a template, or ask the agent to draft one for you.';

  @override
  String get gotIt => 'Got it';

  @override
  String get toggleDarkMode => 'Toggle dark mode';

  @override
  String get reviewChanges => 'Review changes';

  @override
  String get agentMockOffline => 'Mock agent · offline';

  @override
  String get agentNotConnected => 'Agent not connected';

  @override
  String get sidebarHide => 'Hide sidebar';

  @override
  String get sidebarSearchChats => 'Search chats';

  @override
  String get sidebarFilterChats => 'Filter chats';

  @override
  String get sidebarProjects => 'Projects';

  @override
  String get sidebarNewProject => 'New project';

  @override
  String get sidebarNewProjectHint => 'e.g. Acme Corp';

  @override
  String get sidebarCreate => 'Create';

  @override
  String get sidebarNoChats => 'No chats';

  @override
  String get sidebarShowMore => 'Show more';

  @override
  String get sidebarShowLess => 'Show less';

  @override
  String sidebarChatsRunning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chats running',
      one: '1 chat running',
    );
    return '$_temp0';
  }

  @override
  String get sidebarAgentReady => 'Agent ready';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsAgent => 'Agent';

  @override
  String get settingsBackend => 'Server';

  @override
  String get settingsBackendMockHelp =>
      'Replies come from a local simulation, not from the agent: they are only for trying out the app.';

  @override
  String get settingsBackendServerHelp =>
      'The agent runs on a self-hosted server.';

  @override
  String get settingsAccessKey => 'Access key';

  @override
  String get settingsAccessKeyMissing =>
      'The personal key you received to use the agent: you enter it only once.';

  @override
  String get settingsAccessKeySet =>
      'Key entered. If you received a new one, replace it.';

  @override
  String get settingsAccessKeyEnter => 'Enter';

  @override
  String get settingsAccessKeyReplace => 'Replace';

  @override
  String get settingsAccessKeyHint =>
      'Paste the key here (it starts with dlx_)';

  @override
  String get settingsAccessKeyChecking => 'Checking the key…';

  @override
  String get settingsAccessKeySaved => 'Key saved: the agent is connected.';

  @override
  String get settingsResetConnection => 'Daylex connection';

  @override
  String get settingsResetConnectionAction => 'Reset';

  @override
  String get settingsResetConnectionHelp =>
      'Use the app\'s default server while keeping the access key.';

  @override
  String get settingsResetConnectionDone =>
      'Connection reset. The access key was kept.';

  @override
  String get serverAddressEnvironmentOverride =>
      'The server address is set by PAPERAGENT_URL: ask your administrator to update it.';

  @override
  String settingsAccessKeyUnverified(String reason) {
    return 'Key saved, but it cannot be checked for now. $reason';
  }

  @override
  String get settingsTools => 'Tools';

  @override
  String settingsToolCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count document tools',
      one: '1 document tool',
    );
    return '$_temp0';
  }

  @override
  String settingsToolsHelp(int count, String tools) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'The agent edits the document through dedicated tools; $tools ask for your approval first.',
      one:
          'The agent edits the document through dedicated tools; $tools asks for your approval first.',
      zero: 'The agent edits the document through dedicated tools.',
    );
    return '$_temp0';
  }

  @override
  String get settingsUiComponents => 'Chat components';

  @override
  String settingsUiComponentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count components',
      one: '1 component',
    );
    return '$_temp0';
  }

  @override
  String settingsUiComponentsHelp(String names) {
    return 'What the agent can show in the chat: $names.';
  }

  @override
  String get settingsShortcuts => 'Keyboard shortcuts';

  @override
  String get panelHide => 'Hide side panel';

  @override
  String get panelOpenTab => 'Open a tab';

  @override
  String get panelNothingOpenTitle => 'Nothing open yet';

  @override
  String get panelNothingOpenMessage =>
      'Start a chat. The document it works on shows up here as a live preview, next to a review of every change the agent makes.';

  @override
  String get panelNoTabsTitle => 'No tabs open';

  @override
  String get panelNoTabsMessage =>
      'Open the live preview of a document, review what the agent changed, or follow its tool calls.';

  @override
  String logEventCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '1 event',
    );
    return '$_temp0';
  }

  @override
  String get logCopy => 'Copy log';

  @override
  String get logEmptyTitle => 'No events yet';

  @override
  String get logEmptyMessage =>
      'Requests, status updates and tool calls of this chat show up here.';

  @override
  String get libraryThisProject => 'This project';

  @override
  String get libraryNoDocuments => 'No documents yet.';

  @override
  String get libraryOtherProjects => 'Other projects';

  @override
  String get libraryTemplates => 'Templates';

  @override
  String get libraryOpenPreview => 'Open preview';

  @override
  String get libraryDuplicate => 'Duplicate';

  @override
  String get editorNewSection => 'New section';

  @override
  String get editorAddPage => 'Add page';

  @override
  String get editorDetailsTitle => 'Document';

  @override
  String get editorStatus => 'Status';

  @override
  String get editorFieldTitle => 'Title';

  @override
  String get editorFieldSubtitle => 'Subtitle';

  @override
  String get editorFieldClient => 'Client';

  @override
  String get editorFieldBrand => 'Brand';

  @override
  String get editorFieldAuthor => 'Prepared by';

  @override
  String get editorAccent => 'Accent';

  @override
  String get editorSectionTitleHint => 'Section title';

  @override
  String get editorLayout => 'Layout';

  @override
  String get editorShowInPreview => 'Show in preview';

  @override
  String get editorMoveUp => 'Move up';

  @override
  String get editorMoveDown => 'Move down';

  @override
  String get editorDeletePage => 'Delete page';

  @override
  String get editorAddBlock => 'Add block';

  @override
  String get editorRemoveBlock => 'Remove';

  @override
  String get editorNewBulletItem => 'First point';

  @override
  String get editorNewTableItem => 'Item';

  @override
  String get editorNewTableValue => 'Value';

  @override
  String get editorNewTableColumn => 'Column';

  @override
  String get editorNewMetric => 'Metric';

  @override
  String get editorNewCallout => 'Note';

  @override
  String get editorParagraphHint => 'Write something…';

  @override
  String get editorBulletsHint => '• One point per line';

  @override
  String get editorQuoteAuthorHint => 'Author';

  @override
  String get editorCalloutTitleHint => 'Callout title';

  @override
  String get editorCalloutTextHint => 'Callout text';

  @override
  String get editorMetricLabelHint => 'Label';

  @override
  String get editorMetricValueHint => 'Value';

  @override
  String get editorMetricChangeHint => 'Change';

  @override
  String get editorTableAddRow => 'Row';

  @override
  String get editorTableAddColumn => 'Column';

  @override
  String get editorTableRemoveRow => 'Remove last row';

  @override
  String get editorCaptionHint => 'Caption';

  @override
  String get previewNotFoundTitle => 'Document not found';

  @override
  String get previewNotFoundMessage =>
      'It may have been deleted. Close this tab or open another document.';

  @override
  String get previewModePreview => 'Preview';

  @override
  String get previewModeEdit => 'Edit';

  @override
  String previewUndoStep(String label) {
    return 'Undo: $label';
  }

  @override
  String previewRedoStep(String label) {
    return 'Redo: $label';
  }

  @override
  String get previewExport => 'Export';

  @override
  String previewPageOf(int page, int count) {
    return 'Page $page of $count';
  }

  @override
  String get previewRendering => 'Rendering…';

  @override
  String previewUpToDate(String time) {
    return 'Up to date · $time';
  }

  @override
  String get previewOutdated => 'Preview not up to date';

  @override
  String get previewRenderFailed => 'Could not render the document';

  @override
  String pdfPageTooLong(int page) {
    return 'Page $page holds more text than fits on an A4 page.';
  }

  @override
  String get pdfSplitPages => 'Split overlong pages';

  @override
  String pdfPagesSplit(int count) {
    return 'Pages split without removing any text: the document now has $count pages.';
  }

  @override
  String get pdfBlockTooLarge =>
      'A single block is larger than an A4 page (heading, image or metrics): shorten it in the editor.';

  @override
  String get pdfFitChanged => 'The document changed meanwhile: try again.';

  @override
  String get reviewEmptyTitle => 'No changes yet';

  @override
  String get reviewEmptyMessage =>
      'When the agent edits a document, every changed page shows up here with a before/after render and a text diff.';

  @override
  String get reviewPickTurn => 'Pick a turn';

  @override
  String get reviewLastTurn => 'Last turn';

  @override
  String reviewLastTurnPrompt(String prompt) {
    return 'Last turn · $prompt';
  }

  @override
  String reviewTurnNumber(int number) {
    return 'Turn $number';
  }

  @override
  String reviewWordsUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'words',
      one: 'word',
    );
    return '$_temp0';
  }

  @override
  String get reviewUndoTurn => 'Undo turn';

  @override
  String get reviewTurnReverted => 'Reverted the changes of this turn';

  @override
  String get reviewNothingToCompareTitle => 'Nothing to compare';

  @override
  String get reviewNothingToCompareMessage =>
      'The document of this turn is no longer available.';

  @override
  String reviewPagesChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages changed',
      one: '1 page changed',
    );
    return '$_temp0';
  }

  @override
  String get reviewBefore => 'Before';

  @override
  String get reviewAfter => 'After';

  @override
  String get reviewNewPage => 'New page';

  @override
  String get reviewDeletedPage => 'Deleted';

  @override
  String get reviewText => 'Text';

  @override
  String get reviewSameText => 'Same text — only layout or styling changed.';

  @override
  String get chatSuggestionPolishPage =>
      'Make page 3 more premium and reduce the amount of text';

  @override
  String get chatSuggestionOverview => 'Give me an overview of the document';

  @override
  String get chatSuggestionShowPage => 'Show me page 2';

  @override
  String get chatSuggestionDeleteLastPage => 'Delete the last page';

  @override
  String get chatSuggestionRoi => 'Estimate the ROI';

  @override
  String get chatSuggestionProposal =>
      'Draft a one-page proposal for a new client';

  @override
  String get chatSuggestionTeamOnePager => 'Write a team one-pager';

  @override
  String get chatShowSidebar => 'Show sidebar';

  @override
  String chatNewChatIn(String project) {
    return 'New chat in $project';
  }

  @override
  String get chatShowPanel => 'Show side panel';

  @override
  String get chatHidePanel => 'Hide side panel';

  @override
  String get chatActions => 'Chat actions';

  @override
  String get chatRenameTitle => 'Rename chat';

  @override
  String get chatClearConversation => 'Clear conversation';

  @override
  String get chatDelete => 'Delete chat';

  @override
  String get chatWhatToWrite => 'What should we write?';

  @override
  String chatWhatToDoWith(String title) {
    return 'What should we do with $title?';
  }

  @override
  String get chatNewProject => 'Project';

  @override
  String get chatNewHintNoDocument => 'Describe the document you need…';

  @override
  String chatNewHintDocument(String title) {
    return 'Ask for a change to $title…';
  }

  @override
  String get chatNewCardPolish => 'Polish a page';

  @override
  String get chatNewCardOverview => 'Overview';

  @override
  String get chatNewCardProposal => 'New proposal';

  @override
  String get chatNewCardTeam => 'Team one-pager';

  @override
  String chatDropNotAttached(int count, String files, String types) {
    return 'Not attached ($count): $files. Accepted: $types.';
  }

  @override
  String chatDropTooLarge(int count, String files, int megabytes) {
    return 'Files too large ($count): $files. At most $megabytes MB can be attached at a time, counting those already attached.';
  }

  @override
  String chatDropUnreadable(int count, String files) {
    return 'Files not read ($count): $files. They may be open in another program: close them and try again.';
  }

  @override
  String get chatDropTitle => 'Drop files to add them to this chat';

  @override
  String get chatDropFormats =>
      'PDF, signed .p7m, DOCX, TXT and scans · several files or a whole folder';

  @override
  String get composerHint => 'Ask for a change, or describe a document…';

  @override
  String get composerAttach => 'Attach documents or images';

  @override
  String get composerSend => 'Send  ·  Enter';

  @override
  String get composerNoDocument => 'No document';

  @override
  String composerDocumentOnPage(String title, int page) {
    return '$title · p. $page';
  }

  @override
  String get composerPickDocument => 'Document the agent edits';

  @override
  String get composerNoDocumentCreate =>
      'No document · let the agent create one';

  @override
  String get composerWorking => 'Working';

  @override
  String composerElapsed(int seconds) {
    return '${seconds}s';
  }

  @override
  String composerStopHint(String keys) {
    return '$keys to stop';
  }

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get cardCodePlainText => 'text';

  @override
  String cardRendering(String kind) {
    return 'Rendering $kind…';
  }

  @override
  String cardUnknownComponent(String kind) {
    return 'ui:$kind (unknown component)';
  }

  @override
  String get cardOpen => 'Open';

  @override
  String get cardShowInFolder => 'Show in folder';

  @override
  String get cardApprovalNeeded => 'Approval needed';

  @override
  String get cardApproved => 'Approved';

  @override
  String get cardExpired => 'Expired';

  @override
  String get cardRejected => 'Rejected';

  @override
  String get cardApprove => 'Approve';

  @override
  String get cardReject => 'Reject';

  @override
  String cardEditedPages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Edited $count pages',
      one: 'Edited 1 page',
    );
    return '$_temp0';
  }

  @override
  String get cardWords => 'words';

  @override
  String get cardReverted => 'Reverted';

  @override
  String get cardUndo => 'Undo';

  @override
  String get cardReview => 'Review';

  @override
  String cardWorkedFor(String duration) {
    return 'Worked for $duration';
  }

  @override
  String cardSeconds(String seconds) {
    return '${seconds}s';
  }

  @override
  String cardMinutesSeconds(int minutes, int seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String cardToolCalls(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tool calls',
      one: '1 tool call',
    );
    return '$_temp0';
  }

  @override
  String get cardLayoutOnly => 'layout';

  @override
  String get cardDocument => 'Document';

  @override
  String get cardOpenPreview => 'Open preview';

  @override
  String get cardExport => 'Export';

  @override
  String get cardOutline => 'Outline';

  @override
  String get cardChart => 'Chart';

  @override
  String get cardPageUnavailable => 'This page is no longer available.';

  @override
  String get cardFactLayout => 'Layout';

  @override
  String get cardFactWords => 'Words';

  @override
  String get cardFactBlocks => 'Blocks';

  @override
  String get cardFactPage => 'Page';

  @override
  String cardPageOf(int page, int total) {
    return '$page of $total';
  }

  @override
  String get cardEmptyPage => 'Empty page';

  @override
  String get cardNothingToCompare => 'Nothing to compare.';

  @override
  String cardWordsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count words',
      one: '+1 word',
    );
    return '$_temp0';
  }

  @override
  String cardWordsRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '−$count words',
      one: '−1 word',
    );
    return '$_temp0';
  }

  @override
  String get cardBefore => 'Before';

  @override
  String get cardAfter => 'After';

  @override
  String get cardProgressRunning => 'Working';

  @override
  String get cardProgressDone => 'Work done';

  @override
  String cardSteps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count steps',
      one: '1 step',
    );
    return '$_temp0';
  }

  @override
  String get cardMatrixTitle => 'Judgment matrix';

  @override
  String cardMatrixEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries checked against the text',
      one: '1 entry checked against the text',
    );
    return '$_temp0';
  }

  @override
  String cardMatrixPagesRead(String pages) {
    return 'pages read: $pages';
  }

  @override
  String get legalNormsTitle => 'Norms relied on';

  @override
  String legalArticles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles',
      one: '1 article',
    );
    return '$_temp0';
  }

  @override
  String get legalOfficialTextLower => 'official text';

  @override
  String legalToVerify(int count) {
    return '$count to verify';
  }

  @override
  String get legalWhatItSays => 'What it says';

  @override
  String get legalHowItApplies => 'How it applies to the case';

  @override
  String get legalWhyThisNorm => 'Why this norm';

  @override
  String get legalHowFound => 'How it was found';

  @override
  String legalInForceAt(String date) {
    return 'text in force on $date';
  }

  @override
  String legalDiscardedNorms(int count) {
    return 'Related norms considered and discarded ($count)';
  }

  @override
  String legalDegree(int degree) {
    return 'Degree $degree';
  }

  @override
  String get legalDegree1Detail => 'Direct support';

  @override
  String get legalDegree2Detail => 'Links between facts and law';

  @override
  String get legalDegree3Detail => 'Arguments to examine';

  @override
  String get legalClient => 'Client';

  @override
  String get legalOpponent => 'Opposing party';

  @override
  String get legalCaseAnalysis => 'Case analysis';

  @override
  String get legalLinks => 'Links';

  @override
  String get legalStrategies => 'Strategies';

  @override
  String get legalNorms => 'Norms';

  @override
  String get legalEffectNeutral => 'Neutral';

  @override
  String get legalEffectFavourable => 'Favourable to our client';

  @override
  String get legalEffectUnfavourable => 'Unfavourable to our client';

  @override
  String get legalReasoning => 'Reasoning';

  @override
  String legalElements(int count) {
    return 'Elements ($count)';
  }

  @override
  String get legalFromRequest => 'from the request';

  @override
  String legalDocRef(String doc, String name, String page) {
    return 'doc. $doc · $name · p. $page';
  }

  @override
  String legalOurClientNamed(String name) {
    return 'Our client · $name';
  }

  @override
  String legalOpponentNamed(String name) {
    return 'Opposing party · $name';
  }

  @override
  String get legalNoStrategy => 'No strategy that can be proven.';

  @override
  String get legalAttack => 'Attack';

  @override
  String get legalDefence => 'Defence';

  @override
  String get legalMove => 'Move';

  @override
  String get legalExpectedReply => 'Likely reply from the opposing party';

  @override
  String get legalOurCounter => 'Our countermove';

  @override
  String legalBasedOn(String links) {
    return 'Based on: $links';
  }

  @override
  String legalDroppedLinks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count links dropped because they cannot be proven from the case file',
      one: '1 link dropped because it cannot be proven from the case file',
    );
    return '$_temp0';
  }

  @override
  String get legalOfficialText => 'Official text';

  @override
  String legalOfficialTextOf(String caption) {
    return 'Official text · $caption';
  }

  @override
  String get legalOpenOfficialText => 'Open the official text';

  @override
  String get legalFitFull => 'Relevant';

  @override
  String get legalFitUnfit => 'Not relevant';

  @override
  String get legalFitDoubtful => 'To verify';

  @override
  String get legalFitUnrated => 'Not assessed';

  @override
  String get agentReadingAttachments => 'Reading attachments';

  @override
  String get agentThinking => 'Reviewing your request';

  @override
  String get agentConsultingSources => 'Consulting sources';

  @override
  String get agentDraftingDocument => 'Preparing the document';

  @override
  String get agentCheckingResult => 'Checking the result';

  @override
  String get agentQueued => 'Request queued';

  @override
  String get agentMaterialWarning => 'Material to verify';

  @override
  String agentPromptTooLong(int length, int max) {
    return 'The message is too long ($length characters, at most $max): attach the text as a file, or split it into several messages.';
  }

  @override
  String get agentStopped => 'Stopped';

  @override
  String get agentUndoTurn => 'Undo agent turn';

  @override
  String agentHistoryLabel(String label) {
    return 'Agent · $label';
  }

  @override
  String get agentWaitingApproval => 'Waiting for your approval';

  @override
  String get agentNoAnswer => 'No answer in time';

  @override
  String get agentNotApproved => 'Not approved';

  @override
  String approvalRunTool(String tool) {
    return 'The agent wants to run `$tool`.';
  }

  @override
  String approvalDeletePage(int page, String title, String words) {
    return 'Page $page · “$title” ($words) will be removed. You can undo it afterwards.';
  }

  @override
  String get attachmentTypeGroup => 'Documents & images';

  @override
  String logWaitingApproval(String title) {
    return 'Waiting for approval: $title';
  }

  @override
  String logRemoveAttachmentFailed(String name, String error) {
    return 'Could not remove “$name” from the case file: $error';
  }

  @override
  String logToolCrashed(String tool, String error) {
    return 'Tool $tool crashed: $error';
  }

  @override
  String get logRunFinished => 'Run finished';

  @override
  String get logStoppedByUser => 'Stopped by user';

  @override
  String logReverted(String title) {
    return 'Reverted “$title” to before the turn';
  }

  @override
  String logReportFailed(String error) {
    return 'Could not report tool result: $error';
  }

  @override
  String logUnknownComponent(String kind) {
    return 'Unknown component “$kind” skipped';
  }

  @override
  String get serverKeyMissing =>
      'The access key is missing: enter it in Settings, under \"Access key\".';

  @override
  String serverConfigUnreadable(String source) {
    return 'The configuration file $source cannot be read: it needs to be replaced.';
  }

  @override
  String serverAddressMissing(String source) {
    return 'The configuration ($source) has no server address.';
  }

  @override
  String serverAddressInvalid(String source, String address) {
    return 'The server address in the configuration ($source) is not valid: \"$address\".';
  }

  @override
  String get serverKeyRejected =>
      'The server does not recognise this key: check that you copied all of it, or ask for a new one.';

  @override
  String get serverUserFolderMissing =>
      'Cannot find the user folder to save the key in.';

  @override
  String get connectionLocalOff =>
      'The PaperAgent connection is not running on this computer: start it and try again.';

  @override
  String get connectionUnreachable =>
      'Cannot reach the server: check your internet connection and try again.';

  @override
  String get connectionTls =>
      'The secure connection to the server failed: check that the computer\'s date and time are right, then try again.';

  @override
  String get connectionTimeout =>
      'The server did not answer in time: try again in a moment.';

  @override
  String connectionFailed(String message) {
    return 'Could not connect to the server: $message';
  }

  @override
  String connectionUnexpected(String type, String error) {
    return 'Unexpected error connecting to the server ($type): $error';
  }

  @override
  String get failureUnreachable => 'Cannot reach the agent server.';

  @override
  String get failureTls => 'The secure connection to the agent server failed.';

  @override
  String get failureTimeout => 'The agent server did not answer in time.';

  @override
  String get streamSilent =>
      'The agent server has shown no sign of life for several minutes: the request was stopped. Try again.';

  @override
  String streamBroken(String error) {
    return 'The connection to the agent was interrupted: $error';
  }

  @override
  String get streamEnded =>
      'The connection to the agent closed before the reply was finished. Try again.';

  @override
  String get serverUnknownError => 'Unknown server error.';

  @override
  String serverRejectedRequest(String field) {
    return 'The server did not accept the request (field \"$field\"). Try again; if it happens again, report it.';
  }

  @override
  String serverErrorStatus(int status) {
    return 'The agent server answered with an error ($status).';
  }

  @override
  String get toolDocumentFallback => 'document';

  @override
  String toolOnPage(String page) {
    return ' · page $page';
  }

  @override
  String toolCreateDocument(String title) {
    return 'Creating \"$title\"';
  }

  @override
  String get toolReadDocument => 'Reading the document';

  @override
  String get toolAddPage => 'Adding a page';

  @override
  String toolDeletePage(String on) {
    return 'Deleting the page$on';
  }

  @override
  String toolUpdatePage(String on) {
    return 'Rewriting the page$on';
  }

  @override
  String toolReplaceText(String find) {
    return 'Replacing \"$find\"';
  }

  @override
  String toolInsertBlock(String on) {
    return 'Inserting a block$on';
  }

  @override
  String toolUpdateBlock(String block, String on) {
    return 'Editing block $block$on';
  }

  @override
  String toolRemoveBlock(String block, String on) {
    return 'Removing block $block$on';
  }

  @override
  String toolAddTable(String on) {
    return 'Adding a table$on';
  }

  @override
  String toolAddImage(String on) {
    return 'Adding an image$on';
  }

  @override
  String toolChangeLayout(String on) {
    return 'Changing the layout$on';
  }

  @override
  String get toolSetTheme => 'Updating the theme';

  @override
  String get toolUpdateMetadata => 'Updating the details';

  @override
  String get toolExportPdf => 'Exporting the PDF';

  @override
  String get storeNoticeNewer =>
      'This data was saved by a newer version of PaperAgent: you can read it, but changes will not be saved until you update the app.';

  @override
  String get storeNoticeRestored =>
      'The saved work index was damaged: I restored the last valid save. The damaged file was left in the data folder.';

  @override
  String storeNoticeSaveFailed(String reason) {
    return 'Cannot save your work to disk ($reason). Your changes stay open: I will try again at the next change.';
  }

  @override
  String storeNoticeUnreadable(String reason) {
    return 'Cannot read part of your saved work ($reason): another program may have it open. I show what I could read, but changes are not saved until you reopen PaperAgent.';
  }

  @override
  String storeNoticeRecovered(int documents, int chats, String project) {
    return 'The saved work index was unreadable: I recovered $documents documents and $chats conversations into the project \"$project\".';
  }

  @override
  String get docErrorLastPage => 'A document must have at least one page.';

  @override
  String docErrorNoPage(int page, int count) {
    return 'Page $page does not exist (the document has $count).';
  }

  @override
  String docErrorNoBlock(String block) {
    return 'Block $block not found.';
  }

  @override
  String get docErrorEmptySearch => 'The text to search for is empty.';

  @override
  String get docErrorNoDocument => 'No document is open.';

  @override
  String updateDownloading(int percent) {
    return 'Downloading the update… $percent%';
  }

  @override
  String get updateReady => 'Update the app';

  @override
  String get updateInstalling => 'Restarting to update…';

  @override
  String get updateBlocked => 'Update needs attention';

  @override
  String updateTooltip(String version) {
    return 'Version $version available';
  }

  @override
  String updateDialogTitle(String version) {
    return 'Version $version';
  }

  @override
  String get updateDialogBody =>
      'The new version is downloaded and verified. The app closes, updates and reopens by itself: your work is saved first.';

  @override
  String updateRunningWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chats are still working: restarting stops them.',
      one: 'A chat is still working: restarting stops it.',
    );
    return '$_temp0';
  }

  @override
  String get updateNotes => 'What\'s new';

  @override
  String get updateLater => 'Later';

  @override
  String get updateRestart => 'Restart and update';

  @override
  String get updateRetry => 'Try again';

  @override
  String updateProblemNotWritable(String path) {
    return 'The app cannot update itself: the folder $path cannot be changed. Move it to a folder of your own and reopen it, or install the new version by hand.';
  }

  @override
  String get updateProblemNotInstalled =>
      'Move the app to the Applications folder and open it from there: then it can update itself.';

  @override
  String updateInstallFailed(String log) {
    return 'The last update did not complete: the app is still the previous version. You can try again; the details are in $log.';
  }

  @override
  String get settingsUpdates => 'Updates';

  @override
  String get settingsVersion => 'Installed version';

  @override
  String settingsVersionValue(String version, int build) {
    return '$version (build $build)';
  }

  @override
  String get updateCheckNow => 'Check now';

  @override
  String get updateStatusOff => 'This version does not update itself.';

  @override
  String get updateStatusChecking => 'Checking for updates…';

  @override
  String get updateStatusUpToDate =>
      'The app is up to date: it checks by itself every half hour.';

  @override
  String get updateStatusCheckFailed =>
      'Cannot reach the update server: trying again later.';

  @override
  String updateStatusReady(String version) {
    return 'Version $version is ready: restart the app to install it.';
  }

  @override
  String get sourceTitle => 'Source';

  @override
  String sourcePage(String name, int page) {
    return '$name, page $page';
  }

  @override
  String sourcePages(String name, int first, int last) {
    return '$name, pages $first–$last';
  }

  @override
  String sourceOpen(String reference) {
    return 'Open $reference';
  }

  @override
  String get sourceLoading => 'Opening the document…';

  @override
  String get sourceUnavailable => 'Document unavailable';

  @override
  String get sourceMissingMessage =>
      'This document or page is no longer available in this chat. Attach the document again if needed.';

  @override
  String get sourceConnectionMessage =>
      'Unable to open the source. Check your connection and try again.';

  @override
  String get sourceRetry => 'Try again';

  @override
  String get sourceOriginal => 'Original document · read only';

  @override
  String get sourceExtracted =>
      'Extracted text · original layout not reproduced';

  @override
  String get sourceNoText => 'This page contains no readable text.';

  @override
  String get sourcePrevious => 'Previous passage';

  @override
  String get sourceNext => 'Next passage';

  @override
  String get webLinkUnavailable =>
      'Unable to open this link. Try again in your browser.';

  @override
  String sourceSection(String name, int page) {
    return '$name, section $page';
  }

  @override
  String get reviewRunning => 'Checking Italian and layout…';

  @override
  String get reviewUnavailable => 'Review incomplete. Export remains on hold.';

  @override
  String get reviewClean => 'Automated checks completed: no issues detected.';

  @override
  String get reviewAdvisory => 'References to review';

  @override
  String get reviewRequired => 'Review corrections before export';

  @override
  String get reviewHelp =>
      'Edit the text. Confirm only passages you consider correct.';

  @override
  String get reviewMetadata => 'Document title and details';

  @override
  String get reviewProtected =>
      'Original quotation or data: review without changing its meaning.';

  @override
  String get reviewKeepTerm => 'Keep text';

  @override
  String get reviewConfirmed => 'Confirmed';

  @override
  String get pdfPreparedFor => 'Prepared for';

  @override
  String get pdfPreparedBy => 'Prepared by';

  @override
  String get pdfDate => 'Date';

  @override
  String get pdfMonthNames =>
      'January;February;March;April;May;June;July;August;September;October;November;December';

  @override
  String get progressStarting => 'Avvio della richiesta';

  @override
  String get progressFailed => 'Richiesta non completata';

  @override
  String get progressStopped => 'Richiesta interrotta';

  @override
  String get progressCompleted => 'Richiesta conclusa';

  @override
  String get progressHideSteps => 'Nascondi i passaggi';

  @override
  String progressShowSteps(int count) {
    return 'Mostra i passaggi ($count)';
  }

  @override
  String get operationApplied => 'Operazione completata';

  @override
  String get operationFailed => 'Operazione non riuscita';

  @override
  String get operationNotApplied => 'Operazione non eseguita';

  @override
  String get operationRunning => 'Operazione in corso';

  @override
  String get agentComparingDocuments => 'Confronto i documenti';

  @override
  String get evidenceTitle => 'Fonti e riscontri';

  @override
  String evidenceSummary(int claims, int sources) {
    return '$claims affermazioni · $sources fonti richiamate';
  }

  @override
  String get evidenceQualification =>
      'I collegamenti alle fonti e i passaggi citati sono distinti dalla valutazione giuridica del caso.';

  @override
  String get evidenceNoClaims =>
      'Nessuna affermazione associata a questo riscontro.';

  @override
  String get evidenceUnresolved => 'Collegamento alla fonte incompleto';

  @override
  String get evidenceTraceable => 'Passaggio della fonte disponibile';

  @override
  String get evidenceInference => 'Deduzione da valutare';

  @override
  String get evidenceUnsupported => 'Affermazione da correggere';

  @override
  String get evidenceUnknown => 'Riscontro non determinato';

  @override
  String get evidenceNoPassage =>
      'Nessun passaggio citato per questa affermazione.';

  @override
  String get evidenceSemanticPending =>
      'Il sostegno alla conclusione richiede una verifica distinta.';

  @override
  String get evidenceLegislator => 'Testo normativo';

  @override
  String get evidenceCourt => 'Voce del giudice';

  @override
  String get evidenceParty => 'Posizione di una parte';

  @override
  String get evidenceSource => 'Fonte richiamata';

  @override
  String evidenceVersion(String date) {
    return 'Versione al $date';
  }

  @override
  String get evidenceUncertain =>
      'Trascrizione incerta: confrontare con l’originale.';

  @override
  String get phaseIdle => 'Pronto';

  @override
  String get phaseThinking => 'Elaborazione';

  @override
  String get phaseWorking => 'Esecuzione';

  @override
  String get phaseWaiting => 'In attesa';

  @override
  String get phaseError => 'Errore';

  @override
  String get eventRequest => 'Richiesta';

  @override
  String get eventStatus => 'Attività';

  @override
  String get eventText => 'Risposta';

  @override
  String get eventTool => 'Operazione';

  @override
  String get eventResult => 'Risultato';

  @override
  String get eventUi => 'Scheda';

  @override
  String get eventApproval => 'Conferma';

  @override
  String get eventAttachment => 'Allegato';

  @override
  String get eventError => 'Errore';

  @override
  String get eventDone => 'Conclusione';

  @override
  String get eventOther => 'Evento';

  @override
  String get failureUnexpected =>
      'Si è verificato un errore imprevisto. Riprova; se si ripete, copia il registro delle attività per l’assistenza.';

  @override
  String get logCopyDetails => 'Copia i dettagli tecnici';

  @override
  String get logDetailsCopied => 'Dettagli copiati';

  @override
  String get logDetailsHint => 'Dettagli disponibili per l’assistenza.';

  @override
  String get requestData => 'dati della richiesta';

  @override
  String get cardUnavailable =>
      'Scheda non disponibile. Il contenuto ricevuto non è leggibile.';

  @override
  String get operationFailureHint =>
      'Operazione non riuscita. I dettagli sono disponibili nel registro delle attività.';

  @override
  String get componentTool => 'Operazione';

  @override
  String get componentPage => 'Pagina';

  @override
  String get componentDiff => 'Confronto delle modifiche';

  @override
  String get componentDocument => 'Documento';

  @override
  String get componentOutline => 'Struttura del documento';

  @override
  String get componentChart => 'Grafico';

  @override
  String get componentExport => 'Esportazione';

  @override
  String get componentApproval => 'Conferma richiesta';

  @override
  String get componentSummary => 'Riepilogo delle modifiche';

  @override
  String get componentNorms => 'Riferimenti normativi';

  @override
  String get componentCase => 'Analisi del fascicolo';

  @override
  String get componentProgress => 'Avanzamento';

  @override
  String get componentMatrix => 'Confronto documentale';

  @override
  String get componentOther => 'Scheda';

  @override
  String get accessTitle => 'Sign in to Daylex';

  @override
  String get accessHelp =>
      'Enter the key from your administrator. Each key is bound to one computer.';

  @override
  String get accessInvalidKey =>
      'Enter a complete Daylex key starting with dlx_.';

  @override
  String get accessVaultFailed =>
      'The protected credential store is unavailable. Unlock it and try again.';

  @override
  String get accessShowKey => 'Show key';

  @override
  String get accessHideKey => 'Hide key';

  @override
  String get accessActivate => 'Activate on this computer';

  @override
  String get accessDisclosure =>
      'The administrator can see presence, sections used, request type, duration and outcome. When enabled on the service, supervision includes submitted request text. Drafts, keystrokes and attachments are not copied into analytics. Retention is limited by the service configuration; documents remain saved on your computer.';

  @override
  String get accessAcknowledge => 'I have read the supervision notice';

  @override
  String get serviceMaintenance => 'Daylex is under maintenance';

  @override
  String get serviceMaintenanceHelp =>
      'New requests are temporarily suspended. Saved work remains available on this computer.';

  @override
  String get serviceOffline => 'Service connection unavailable';

  @override
  String get serviceOfflineHelp =>
      'The service status could not be verified. Local work remains available; check your connection and try again.';

  @override
  String get serviceDetails => 'Details';

  @override
  String get serviceRetry => 'Try again';

  @override
  String get operationUncertain => 'Esito da verificare';

  @override
  String get operationVerificationHint =>
      'La sessione si è interrotta prima di ricevere l’esito. Controlla il documento prima di ripetere l’operazione.';

  @override
  String get instanceUnavailable =>
      'Daylex is already open or its data folder is unavailable. Close the other window and try again; if the issue persists, check folder permissions.';

  @override
  String get exitUnsavedTitle => 'Unsaved changes';

  @override
  String get exitUnsavedHelp =>
      'Saving failed. Keep the app open and try again after checking disk space and permissions. Quitting will discard unsaved changes.';

  @override
  String get exitKeepOpen => 'Keep open';

  @override
  String get exitDiscard => 'Quit without saving';

  @override
  String get accessKeyHint => 'dlx_…';

  @override
  String get webAccessHelp =>
      'Enter a dedicated key for this browser, supplied by your administrator. A key already linked to the desktop app cannot be transferred automatically.';

  @override
  String get webSessionHelp =>
      'The key stays in memory for this session only: enter it again after reloading or reopening Daylex. Documents and chats remain in this browser; download a backup regularly.';
}
