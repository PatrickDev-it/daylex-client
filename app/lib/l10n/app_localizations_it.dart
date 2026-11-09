// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'Daylex';

  @override
  String get languageItalian => 'Italiano';

  @override
  String get languageEnglish => 'Inglese';

  @override
  String get cancel => 'Annulla';

  @override
  String get delete => 'Elimina';

  @override
  String get close => 'Chiudi';

  @override
  String get rename => 'Rinomina';

  @override
  String get save => 'Salva';

  @override
  String get untitledDocument => 'Documento senza titolo';

  @override
  String get untitledProject => 'Progetto senza nome';

  @override
  String get firstProject => 'Generale';

  @override
  String get newChat => 'Nuova conversazione';

  @override
  String get newDocument => 'Nuovo documento';

  @override
  String get exportPdf => 'Esporta PDF';

  @override
  String get settings => 'Impostazioni';

  @override
  String get whatsappTitle => 'WhatsApp';

  @override
  String get whatsappConnect => 'Collega WhatsApp';

  @override
  String get whatsappConnected => 'Collegato';

  @override
  String get whatsappWaiting => 'In attesa del collegamento';

  @override
  String get whatsappScanQr =>
      'Scansiona il QR da WhatsApp > Dispositivi collegati';

  @override
  String get whatsappUnavailable => 'WhatsApp non disponibile';

  @override
  String get whatsappHelp =>
      'Messaggi di testo e appuntamenti tramite l\'agente, con sessione salvata su questo computer.';

  @override
  String get whatsappCheckStatus => 'Verifico WhatsApp';

  @override
  String get whatsappSearchContact => 'Cerco un contatto WhatsApp';

  @override
  String get whatsappSendText => 'Invio un messaggio WhatsApp';

  @override
  String pageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pagine',
      one: '1 pagina',
    );
    return '$_temp0';
  }

  @override
  String wordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parole',
      one: '1 parola',
    );
    return '$_temp0';
  }

  @override
  String pageNumber(int page) {
    return 'Pagina $page';
  }

  @override
  String get timeNow => 'adesso';

  @override
  String timeMinutesAgo(int minutes) {
    return '$minutes min fa';
  }

  @override
  String timeHoursAgo(int hours) {
    return '$hours h fa';
  }

  @override
  String timeDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days giorni fa',
      one: 'ieri',
    );
    return '$_temp0';
  }

  @override
  String timeYesterdayAt(String time) {
    return 'ieri $time';
  }

  @override
  String get monthsShort => 'gen feb mar apr mag giu lug ago set ott nov dic';

  @override
  String dateThisYear(int day, String month) {
    return '$day $month';
  }

  @override
  String dateOtherYear(int day, String month, String year) {
    return '$day $month $year';
  }

  @override
  String dateAt(String date, String time) {
    return '$date, $time';
  }

  @override
  String get docStatusDraft => 'Bozza';

  @override
  String get docStatusReview => 'In revisione';

  @override
  String get docStatusApproved => 'Approvato';

  @override
  String get layoutCover => 'Copertina';

  @override
  String get layoutStandard => 'Classica';

  @override
  String get layoutTwoColumn => 'Due colonne';

  @override
  String get layoutPremium => 'Curata';

  @override
  String get blockHeading => 'Titolo';

  @override
  String get blockParagraph => 'Paragrafo';

  @override
  String get blockBullets => 'Elenco puntato';

  @override
  String get blockTable => 'Tabella';

  @override
  String get blockMetrics => 'Indicatori';

  @override
  String get blockQuote => 'Citazione';

  @override
  String get blockCallout => 'Riquadro';

  @override
  String get blockImage => 'Immagine';

  @override
  String get opAddPage => 'Aggiungi pagina';

  @override
  String opDeletePage(int page) {
    return 'Elimina pagina $page';
  }

  @override
  String opMovePage(int page) {
    return 'Sposta pagina $page';
  }

  @override
  String opUpdatePage(int page) {
    return 'Aggiorna pagina $page';
  }

  @override
  String opReplace(String find) {
    return 'Sostituisci «$find»';
  }

  @override
  String opInsertBlock(String kind) {
    return 'Inserisci $kind';
  }

  @override
  String opEditBlock(String kind) {
    return 'Modifica $kind';
  }

  @override
  String get opRemoveBlock => 'Rimuovi blocco';

  @override
  String get opMoveBlock => 'Sposta blocco';

  @override
  String get opChangeTheme => 'Cambia tema';

  @override
  String get opUpdateDetails => 'Aggiorna dettagli';

  @override
  String get shortcutNewChat => 'Nuova conversazione';

  @override
  String get shortcutNewDocument => 'Nuovo documento';

  @override
  String get shortcutFocusPrompt => 'Scrivi un messaggio';

  @override
  String get shortcutStopAgent => 'Ferma l\'agente';

  @override
  String get shortcutExport => 'Esporta PDF';

  @override
  String get shortcutUndo => 'Annulla la modifica';

  @override
  String get shortcutRedo => 'Ripeti la modifica';

  @override
  String get shortcutPreview => 'Anteprima del documento';

  @override
  String get shortcutEdit => 'Modifica del documento';

  @override
  String get shortcutPreviousPage => 'Pagina precedente';

  @override
  String get shortcutNextPage => 'Pagina successiva';

  @override
  String get shortcutZoomIn => 'Ingrandisci';

  @override
  String get shortcutZoomOut => 'Riduci';

  @override
  String get shortcutZoomReset => 'Dimensione al 100%';

  @override
  String get shortcutLibraryTab => 'Libreria';

  @override
  String get shortcutReviewTab => 'Revisione delle modifiche';

  @override
  String get shortcutLogTab => 'Registro dell\'agente';

  @override
  String get shortcutCloseTab => 'Chiudi il scheda';

  @override
  String get shortcutToggleSidebar => 'Mostra o nascondi la barra laterale';

  @override
  String get shortcutTogglePanel => 'Mostra o nascondi il pannello laterale';

  @override
  String get shortcutToggleTheme => 'Tema chiaro o scuro';

  @override
  String get tabPreview => 'Anteprima';

  @override
  String get tabReview => 'Revisione';

  @override
  String tabReviewCount(int count) {
    return 'Revisione · $count';
  }

  @override
  String get tabLibrary => 'Libreria';

  @override
  String get tabLog => 'Diagnostica';

  @override
  String get tabDocument => 'Documento';

  @override
  String deleteTitle(String title) {
    return 'Eliminare «$title»?';
  }

  @override
  String get deleteChatMessage =>
      'Vengono eliminati anche i suoi messaggi e i documenti letti nel suo fascicolo. L\'operazione non si può annullare.';

  @override
  String get deleteDocumentMessage =>
      'Viene eliminata anche la sua cronologia delle versioni. L\'operazione non si può annullare.';

  @override
  String documentCreated(String title) {
    return 'Creato «$title»';
  }

  @override
  String documentDeleted(String title) {
    return 'Eliminato «$title»';
  }

  @override
  String get exportNoDocument => 'Apri un documento per esportarlo.';

  @override
  String exportedTo(String path) {
    return 'Esportato in $path';
  }

  @override
  String exportFailed(String error) {
    return 'Esportazione non riuscita: $error';
  }

  @override
  String undid(String label) {
    return 'Annullato: $label';
  }

  @override
  String redid(String label) {
    return 'Ripristinato: $label';
  }

  @override
  String get templatePickerHint =>
      'Parti da un modello, oppure chiedi all\'agente di scriverne uno per te.';

  @override
  String get gotIt => 'Ho capito';

  @override
  String get toggleDarkMode => 'Tema chiaro o scuro';

  @override
  String get reviewChanges => 'Rivedi le modifiche';

  @override
  String get agentMockOffline => 'Agente simulato · senza connessione';

  @override
  String get agentNotConnected => 'Agente non collegato';

  @override
  String get sidebarHide => 'Nascondi la barra laterale';

  @override
  String get sidebarSearchChats => 'Cerca nelle conversazioni';

  @override
  String get sidebarFilterChats => 'Filtra le conversazioni';

  @override
  String get sidebarProjects => 'Progetti';

  @override
  String get sidebarNewProject => 'Nuovo progetto';

  @override
  String get sidebarNewProjectHint => 'es. Rossi S.r.l.';

  @override
  String get sidebarCreate => 'Crea';

  @override
  String get sidebarNoChats => 'Nessuna conversazione';

  @override
  String get sidebarShowMore => 'Mostra altre';

  @override
  String get sidebarShowLess => 'Mostra meno';

  @override
  String sidebarChatsRunning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conversazioni in corso',
      one: '1 conversazione in corso',
    );
    return '$_temp0';
  }

  @override
  String get sidebarAgentReady => 'Agente pronto';

  @override
  String get settingsAppearance => 'Aspetto';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get settingsThemeSystem => 'Sistema';

  @override
  String get settingsThemeLight => 'Chiaro';

  @override
  String get settingsThemeDark => 'Scuro';

  @override
  String get settingsLanguage => 'Lingua';

  @override
  String get settingsAgent => 'Agente';

  @override
  String get settingsBackend => 'Servizio';

  @override
  String get settingsBackendMockHelp =>
      'Le risposte arrivano da una simulazione locale, non dall\'agente: servono solo a provare l\'app.';

  @override
  String get settingsBackendServerHelp =>
      'L\'agente gira su un servizio ospitato in proprio.';

  @override
  String get settingsAccessKey => 'Chiave di accesso';

  @override
  String get settingsAccessKeyMissing =>
      'La chiave personale che hai ricevuto per usare l\'agente: si inserisce una volta sola.';

  @override
  String get settingsAccessKeySet =>
      'Chiave inserita. Se ne hai ricevuta una nuova, sostituiscila.';

  @override
  String get settingsAccessKeyEnter => 'Inserisci';

  @override
  String get settingsAccessKeyReplace => 'Sostituisci';

  @override
  String get settingsAccessKeyHint => 'Incolla qui la chiave (inizia con dlx_)';

  @override
  String get settingsAccessKeyChecking => 'Verifico la chiave…';

  @override
  String get settingsAccessKeySaved => 'Chiave salvata: l\'agente è collegato.';

  @override
  String get settingsResetConnection => 'Connessione Daylex';

  @override
  String get settingsResetConnectionAction => 'Ripristina';

  @override
  String get settingsResetConnectionHelp =>
      'Usa il servizio predefinito dell\'app mantenendo la chiave di accesso.';

  @override
  String get settingsResetConnectionDone =>
      'Connessione ripristinata. La chiave di accesso è stata mantenuta.';

  @override
  String get serverAddressEnvironmentOverride =>
      'L\'indirizzo del servizio è impostato dall\'ambiente PAPERAGENT_URL: chiedi all\'amministratore di aggiornarlo.';

  @override
  String settingsAccessKeyUnverified(String reason) {
    return 'Chiave salvata, ma per ora non posso verificarla. $reason';
  }

  @override
  String get settingsTools => 'Strumenti';

  @override
  String settingsToolCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count strumenti sul documento',
      one: '1 strumento sul documento',
    );
    return '$_temp0';
  }

  @override
  String settingsToolsHelp(int count, String tools) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'L\'agente modifica il documento con strumenti dedicati; $tools chiedono prima la tua approvazione.',
      one:
          'L\'agente modifica il documento con strumenti dedicati; $tools chiede prima la tua approvazione.',
      zero: 'L\'agente modifica il documento con strumenti dedicati.',
    );
    return '$_temp0';
  }

  @override
  String get settingsUiComponents => 'Componenti nella conversazione';

  @override
  String settingsUiComponentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count componenti',
      one: '1 componente',
    );
    return '$_temp0';
  }

  @override
  String settingsUiComponentsHelp(String names) {
    return 'Cosa l\'agente può mostrare nella conversazione: $names.';
  }

  @override
  String get settingsShortcuts => 'Scorciatoie da tastiera';

  @override
  String get panelHide => 'Nascondi il pannello laterale';

  @override
  String get panelOpenTab => 'Apri un scheda';

  @override
  String get panelNothingOpenTitle => 'Ancora niente di aperto';

  @override
  String get panelNothingOpenMessage =>
      'Inizia una conversazione. Il documento su cui lavora compare qui in anteprima, accanto alla revisione di ogni modifica dell\'agente.';

  @override
  String get panelNoTabsTitle => 'Nessun scheda aperto';

  @override
  String get panelNoTabsMessage =>
      'Apri l\'anteprima di un documento, rivedi cosa ha cambiato l\'agente o segui le sue chiamate agli strumenti.';

  @override
  String logEventCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count eventi',
      one: '1 evento',
    );
    return '$_temp0';
  }

  @override
  String get logCopy => 'Copia il registro';

  @override
  String get logEmptyTitle => 'Ancora nessun evento';

  @override
  String get logEmptyMessage =>
      'Qui compaiono le richieste, gli aggiornamenti di stato e le chiamate agli strumenti di questa conversazione.';

  @override
  String get libraryThisProject => 'Questo progetto';

  @override
  String get libraryNoDocuments => 'Ancora nessun documento.';

  @override
  String get libraryOtherProjects => 'Altri progetti';

  @override
  String get libraryTemplates => 'Modelli';

  @override
  String get libraryOpenPreview => 'Apri l\'anteprima';

  @override
  String get libraryDuplicate => 'Duplica';

  @override
  String get editorNewSection => 'Nuova sezione';

  @override
  String get editorAddPage => 'Aggiungi pagina';

  @override
  String get editorDetailsTitle => 'Documento';

  @override
  String get editorStatus => 'Stato';

  @override
  String get editorFieldTitle => 'Titolo';

  @override
  String get editorFieldSubtitle => 'Sottotitolo';

  @override
  String get editorFieldClient => 'Cliente';

  @override
  String get editorFieldBrand => 'Marchio';

  @override
  String get editorFieldAuthor => 'Redatto da';

  @override
  String get editorAccent => 'Colore d\'accento';

  @override
  String get editorSectionTitleHint => 'Titolo della sezione';

  @override
  String get editorLayout => 'Impaginazione';

  @override
  String get editorShowInPreview => 'Mostra nell\'anteprima';

  @override
  String get editorMoveUp => 'Sposta su';

  @override
  String get editorMoveDown => 'Sposta giù';

  @override
  String get editorDeletePage => 'Elimina pagina';

  @override
  String get editorAddBlock => 'Aggiungi blocco';

  @override
  String get editorRemoveBlock => 'Rimuovi';

  @override
  String get editorNewBulletItem => 'Primo punto';

  @override
  String get editorNewTableItem => 'Voce';

  @override
  String get editorNewTableValue => 'Valore';

  @override
  String get editorNewTableColumn => 'Colonna';

  @override
  String get editorNewMetric => 'Indicatore';

  @override
  String get editorNewCallout => 'Nota';

  @override
  String get editorParagraphHint => 'Scrivi qui…';

  @override
  String get editorBulletsHint => '• Un punto per riga';

  @override
  String get editorQuoteAuthorHint => 'Autore';

  @override
  String get editorCalloutTitleHint => 'Titolo del riquadro';

  @override
  String get editorCalloutTextHint => 'Testo del riquadro';

  @override
  String get editorMetricLabelHint => 'Etichetta';

  @override
  String get editorMetricValueHint => 'Valore';

  @override
  String get editorMetricChangeHint => 'Variazione';

  @override
  String get editorTableAddRow => 'Riga';

  @override
  String get editorTableAddColumn => 'Colonna';

  @override
  String get editorTableRemoveRow => 'Rimuovi l\'ultima riga';

  @override
  String get editorCaptionHint => 'Didascalia';

  @override
  String get previewNotFoundTitle => 'Documento non trovato';

  @override
  String get previewNotFoundMessage =>
      'Potrebbe essere stato eliminato. Chiudi questo scheda o apri un altro documento.';

  @override
  String get previewModePreview => 'Anteprima';

  @override
  String get previewModeEdit => 'Modifica';

  @override
  String previewUndoStep(String label) {
    return 'Annulla: $label';
  }

  @override
  String previewRedoStep(String label) {
    return 'Ripeti: $label';
  }

  @override
  String get previewExport => 'Esporta';

  @override
  String previewPageOf(int page, int count) {
    return 'Pagina $page di $count';
  }

  @override
  String get previewRendering => 'Aggiornamento…';

  @override
  String previewUpToDate(String time) {
    return 'Aggiornato · $time';
  }

  @override
  String get previewOutdated => 'Anteprima non aggiornata';

  @override
  String get previewRenderFailed =>
      'Impossibile generare l\'anteprima del documento';

  @override
  String get reviewEmptyTitle => 'Ancora nessuna modifica';

  @override
  String get reviewEmptyMessage =>
      'Quando l\'agente modifica un documento, qui compare ogni pagina cambiata, con il confronto prima/dopo e le differenze nel testo.';

  @override
  String get reviewPickTurn => 'Scegli una richiesta';

  @override
  String get reviewLastTurn => 'Ultima richiesta';

  @override
  String reviewLastTurnPrompt(String prompt) {
    return 'Ultima richiesta · $prompt';
  }

  @override
  String reviewTurnNumber(int number) {
    return 'Richiesta $number';
  }

  @override
  String reviewWordsUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'parole',
      one: 'parola',
    );
    return '$_temp0';
  }

  @override
  String get reviewUndoTurn => 'Annulla le modifiche';

  @override
  String get reviewTurnReverted => 'Modifiche di questa richiesta annullate';

  @override
  String get reviewNothingToCompareTitle => 'Niente da confrontare';

  @override
  String get reviewNothingToCompareMessage =>
      'Il documento di questa richiesta non è più disponibile.';

  @override
  String reviewPagesChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pagine modificate',
      one: '1 pagina modificata',
    );
    return '$_temp0';
  }

  @override
  String get reviewBefore => 'Prima';

  @override
  String get reviewAfter => 'Dopo';

  @override
  String get reviewNewPage => 'Pagina nuova';

  @override
  String get reviewDeletedPage => 'Eliminata';

  @override
  String get reviewText => 'Testo';

  @override
  String get reviewSameText =>
      'Stesso testo: sono cambiati solo l\'impaginazione o lo stile.';

  @override
  String get chatSuggestionPolishPage =>
      'Rendi più chiara la pagina 3 e riduci il testo';

  @override
  String get chatSuggestionOverview => 'Dammi una panoramica del documento';

  @override
  String get chatSuggestionShowPage => 'Mostrami la pagina 2';

  @override
  String get chatSuggestionDeleteLastPage => 'Elimina l\'ultima pagina';

  @override
  String get chatSuggestionRoi => 'Stima costi e benefici';

  @override
  String get chatSuggestionProposal =>
      'Scrivi una proposta di una pagina per un nuovo cliente';

  @override
  String get chatSuggestionTeamOnePager =>
      'Scrivi una presentazione dello studio in una pagina';

  @override
  String get chatShowSidebar => 'Mostra la barra laterale';

  @override
  String chatNewChatIn(String project) {
    return 'Nuova conversazione in $project';
  }

  @override
  String get chatShowPanel => 'Mostra il pannello laterale';

  @override
  String get chatHidePanel => 'Nascondi il pannello laterale';

  @override
  String get chatActions => 'Azioni della conversazione';

  @override
  String get chatRenameTitle => 'Rinomina la conversazione';

  @override
  String get chatClearConversation => 'Svuota la conversazione';

  @override
  String get chatDelete => 'Elimina la conversazione';

  @override
  String get chatWhatToWrite => 'Cosa scriviamo?';

  @override
  String chatWhatToDoWith(String title) {
    return 'Cosa facciamo con «$title»?';
  }

  @override
  String get chatNewProject => 'Progetto';

  @override
  String get chatNewHintNoDocument => 'Descrivi il documento che ti serve…';

  @override
  String chatNewHintDocument(String title) {
    return 'Chiedi una modifica a «$title»…';
  }

  @override
  String get chatNewCardPolish => 'Rifinisci una pagina';

  @override
  String get chatNewCardOverview => 'Panoramica';

  @override
  String get chatNewCardProposal => 'Nuova proposta';

  @override
  String get chatNewCardTeam => 'Presentazione dello studio';

  @override
  String chatDropNotAttached(int count, String files, String types) {
    return 'Documenti non allegati ($count): $files. Formati accettati: $types.';
  }

  @override
  String chatDropTooLarge(int count, String files, int megabytes) {
    return 'Documenti troppo grandi ($count): $files. Si allegano al massimo $megabytes MB per volta, contando quelli già allegati.';
  }

  @override
  String chatDropUnreadable(int count, String files) {
    return 'Documenti non letti ($count): $files. Forse sono aperti in un altro programma: chiudili e riprova.';
  }

  @override
  String get chatDropTitle =>
      'Rilascia i documenti per aggiungerli a questa conversazione';

  @override
  String get chatDropFormats =>
      'PDF, .p7m firmati, DOCX, TXT e scansioni · più documenti o un\'intera cartella';

  @override
  String get composerHint => 'Chiedi una modifica o descrivi un documento…';

  @override
  String get composerAttach => 'Allega documenti o immagini';

  @override
  String get composerSend => 'Invia  ·  Invio';

  @override
  String get composerNoDocument => 'Nessun documento';

  @override
  String composerDocumentOnPage(String title, int page) {
    return '$title · p. $page';
  }

  @override
  String get composerPickDocument => 'Documento su cui lavora l\'agente';

  @override
  String get composerNoDocumentCreate => 'Nessun documento · lo crea l\'agente';

  @override
  String get composerWorking => 'Sto lavorando';

  @override
  String composerElapsed(int seconds) {
    return '$seconds s';
  }

  @override
  String composerStopHint(String keys) {
    return '$keys per fermare';
  }

  @override
  String get copy => 'Copia';

  @override
  String get copied => 'Copiato';

  @override
  String get cardCodePlainText => 'testo';

  @override
  String cardRendering(String kind) {
    return 'Preparazione di $kind…';
  }

  @override
  String cardUnknownComponent(String kind) {
    return 'ui:$kind (componente sconosciuto)';
  }

  @override
  String get cardOpen => 'Apri';

  @override
  String get cardShowInFolder => 'Mostra nella cartella';

  @override
  String get cardApprovalNeeded => 'Approvazione richiesta';

  @override
  String get cardApproved => 'Approvata';

  @override
  String get cardExpired => 'Scaduta';

  @override
  String get cardRejected => 'Rifiutata';

  @override
  String get cardApprove => 'Approva';

  @override
  String get cardReject => 'Rifiuta';

  @override
  String cardEditedPages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Modificate $count pagine',
      one: 'Modificata 1 pagina',
    );
    return '$_temp0';
  }

  @override
  String get cardWords => 'parole';

  @override
  String get cardReverted => 'Annullato';

  @override
  String get cardUndo => 'Annulla';

  @override
  String get cardReview => 'Rivedi';

  @override
  String cardWorkedFor(String duration) {
    return 'Ha lavorato per $duration';
  }

  @override
  String cardSeconds(String seconds) {
    return '$seconds s';
  }

  @override
  String cardMinutesSeconds(int minutes, int seconds) {
    return '$minutes min $seconds s';
  }

  @override
  String cardToolCalls(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chiamate a strumenti',
      one: '1 chiamata a strumento',
    );
    return '$_temp0';
  }

  @override
  String get cardLayoutOnly => 'impaginazione';

  @override
  String get cardDocument => 'Documento';

  @override
  String get cardOpenPreview => 'Apri anteprima';

  @override
  String get cardExport => 'Esporta';

  @override
  String get cardOutline => 'Struttura';

  @override
  String get cardChart => 'Grafico';

  @override
  String get cardPageUnavailable => 'Questa pagina non è più disponibile.';

  @override
  String get cardFactLayout => 'Impaginazione';

  @override
  String get cardFactWords => 'Parole';

  @override
  String get cardFactBlocks => 'Blocchi';

  @override
  String get cardFactPage => 'Pagina';

  @override
  String cardPageOf(int page, int total) {
    return '$page di $total';
  }

  @override
  String get cardEmptyPage => 'Pagina vuota';

  @override
  String get cardNothingToCompare => 'Niente da confrontare.';

  @override
  String cardWordsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count parole',
      one: '+1 parola',
    );
    return '$_temp0';
  }

  @override
  String cardWordsRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '−$count parole',
      one: '−1 parola',
    );
    return '$_temp0';
  }

  @override
  String get cardBefore => 'Prima';

  @override
  String get cardAfter => 'Dopo';

  @override
  String get cardProgressRunning => 'Lavoro in corso';

  @override
  String get cardProgressDone => 'Lavoro svolto';

  @override
  String cardSteps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count passaggi',
      one: '1 passaggio',
    );
    return '$_temp0';
  }

  @override
  String get cardMatrixTitle => 'Matrice della sentenza';

  @override
  String cardMatrixEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voci verificate sul testo',
      one: '1 voce verificata sul testo',
    );
    return '$_temp0';
  }

  @override
  String cardMatrixPagesRead(String pages) {
    return 'pagine lette: $pages';
  }

  @override
  String get legalNormsTitle => 'Norme utilizzate';

  @override
  String legalArticles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articoli',
      one: '1 articolo',
    );
    return '$_temp0';
  }

  @override
  String get legalOfficialTextLower => 'testo ufficiale';

  @override
  String legalToVerify(int count) {
    return '$count da verificare';
  }

  @override
  String get legalWhatItSays => 'Cosa dice';

  @override
  String get legalHowItApplies => 'Come si collega al caso';

  @override
  String get legalWhyThisNorm => 'Perché questa norma';

  @override
  String get legalHowFound => 'Come è stata individuata';

  @override
  String legalInForceAt(String date) {
    return 'testo vigente al $date';
  }

  @override
  String legalDiscardedNorms(int count) {
    return 'Norme vicine considerate e scartate ($count)';
  }

  @override
  String legalDegree(int degree) {
    return '$degree° grado';
  }

  @override
  String get legalDegree1Detail => 'Riscontri diretti';

  @override
  String get legalDegree2Detail => 'Collegamenti tra fatti e norme';

  @override
  String get legalDegree3Detail => 'Tesi da approfondire';

  @override
  String get legalClient => 'Assistito';

  @override
  String get legalOpponent => 'Controparte';

  @override
  String get legalCaseAnalysis => 'Analisi del caso';

  @override
  String get legalLinks => 'Collegamenti';

  @override
  String get legalStrategies => 'Strategie';

  @override
  String get legalNorms => 'Norme';

  @override
  String get legalEffectNeutral => 'Neutro';

  @override
  String get legalEffectFavourable => 'Favorevole al nostro assistito';

  @override
  String get legalEffectUnfavourable => 'Sfavorevole al nostro assistito';

  @override
  String get legalReasoning => 'Ragionamento';

  @override
  String legalElements(int count) {
    return 'Elementi ($count)';
  }

  @override
  String get legalFromRequest => 'dalla richiesta';

  @override
  String legalDocRef(String doc, String name, String page) {
    return 'doc. $doc · $name · p. $page';
  }

  @override
  String legalOurClientNamed(String name) {
    return 'Nostro assistito · $name';
  }

  @override
  String legalOpponentNamed(String name) {
    return 'Controparte · $name';
  }

  @override
  String get legalNoStrategy => 'Nessuna strategia dimostrabile.';

  @override
  String get legalAttack => 'Attacco';

  @override
  String get legalDefence => 'Difesa';

  @override
  String get legalMove => 'Mossa';

  @override
  String get legalExpectedReply => 'Replica prevedibile della controparte';

  @override
  String get legalOurCounter => 'Nostra contromossa';

  @override
  String legalBasedOn(String links) {
    return 'Si basa su: $links';
  }

  @override
  String legalDroppedLinks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collegamenti scartati perché non dimostrabili sugli atti',
      one: '1 collegamento scartato perché non dimostrabili sugli atti',
    );
    return '$_temp0';
  }

  @override
  String get legalOfficialText => 'Testo ufficiale';

  @override
  String legalOfficialTextOf(String caption) {
    return 'Testo ufficiale · $caption';
  }

  @override
  String get legalOpenOfficialText => 'Apri il testo ufficiale';

  @override
  String get legalFitFull => 'Pertinente';

  @override
  String get legalFitUnfit => 'Non pertinente';

  @override
  String get legalFitDoubtful => 'Da verificare';

  @override
  String get legalFitUnrated => 'Non valutata';

  @override
  String get agentReadingAttachments => 'Leggo gli allegati';

  @override
  String get agentThinking => 'Esamino la richiesta';

  @override
  String get agentConsultingSources => 'Consulto le fonti';

  @override
  String get agentDraftingDocument => 'Preparo il documento';

  @override
  String get agentCheckingResult => 'Verifico il risultato';

  @override
  String get agentQueued => 'Richiesta in attesa';

  @override
  String get agentMaterialWarning => 'Materiale da verificare';

  @override
  String agentPromptTooLong(int length, int max) {
    return 'Il messaggio è troppo lungo ($length caratteri, al massimo $max): allega il testo come documento, o dividilo in più messaggi.';
  }

  @override
  String get agentStopped => 'Interrotto';

  @override
  String get agentUndoTurn => 'Modifiche della richiesta annullate';

  @override
  String agentHistoryLabel(String label) {
    return 'Agente · $label';
  }

  @override
  String get agentWaitingApproval => 'In attesa della tua approvazione';

  @override
  String get agentNoAnswer => 'Nessuna risposta in tempo';

  @override
  String get agentNotApproved => 'Non approvato';

  @override
  String approvalRunTool(String tool) {
    return 'Confermi questa operazione? $tool.';
  }

  @override
  String approvalDeletePage(int page, String title, String words) {
    return 'La pagina $page · «$title» ($words) verrà eliminata. Potrai annullare l\'operazione.';
  }

  @override
  String get attachmentTypeGroup => 'Documenti e immagini';

  @override
  String logWaitingApproval(String title) {
    return 'In attesa di approvazione: $title';
  }

  @override
  String logRemoveAttachmentFailed(String name, String error) {
    return 'Impossibile togliere «$name» dal fascicolo: $error';
  }

  @override
  String logToolCrashed(String tool, String error) {
    return 'Lo strumento $tool si è interrotto per un errore: $error';
  }

  @override
  String get logRunFinished => 'Esecuzione terminata';

  @override
  String get logStoppedByUser => 'Interrotto dall\'utente';

  @override
  String logReverted(String title) {
    return '«$title» riportato a prima della richiesta';
  }

  @override
  String logReportFailed(String error) {
    return 'Impossibile inviare il risultato dello strumento: $error';
  }

  @override
  String logUnknownComponent(String kind) {
    return 'Componente sconosciuto «$kind» ignorato';
  }

  @override
  String get serverKeyMissing =>
      'Manca la chiave di accesso: inseriscila nelle Impostazioni, alla voce «Chiave di accesso».';

  @override
  String serverConfigUnreadable(String source) {
    return 'La configurazione $source non è leggibile: va sostituita.';
  }

  @override
  String serverAddressMissing(String source) {
    return 'Nella configurazione ($source) manca l\'indirizzo del servizio.';
  }

  @override
  String serverAddressInvalid(String source, String address) {
    return 'L\'indirizzo del servizio nella configurazione ($source) non è valido: «$address».';
  }

  @override
  String get serverKeyRejected =>
      'Il servizio non riconosce questa chiave: controlla di averla copiata per intero, o chiedine una nuova.';

  @override
  String get serverUserFolderMissing =>
      'Non trovo la cartella utente in cui salvare la chiave.';

  @override
  String get connectionLocalOff =>
      'Il collegamento a PaperAgent non è attivo su questo computer: avvialo e riprova.';

  @override
  String get connectionUnreachable =>
      'Non riesco a raggiungere il servizio: controlla la connessione a internet e riprova.';

  @override
  String get connectionTls =>
      'Il collegamento sicuro con il servizio non è riuscito: controlla che data e ora del computer siano giuste, poi riprova.';

  @override
  String get connectionTimeout =>
      'Il servizio non ha risposto in tempo: riprova tra un momento.';

  @override
  String connectionFailed(String message) {
    return 'Collegamento con il servizio non riuscito: $message';
  }

  @override
  String connectionUnexpected(String type, String error) {
    return 'Errore imprevisto nel collegamento al servizio ($type): $error';
  }

  @override
  String get failureUnreachable =>
      'Non riesco a raggiungere il servizio dell\'agente.';

  @override
  String get failureTls =>
      'Il collegamento sicuro con il servizio dell\'agente non è riuscito.';

  @override
  String get failureTimeout =>
      'Il servizio dell\'agente non ha risposto in tempo.';

  @override
  String get streamSilent =>
      'Il servizio dell\'agente non dà segni di vita da qualche minuto: la richiesta è stata interrotta. Riprova.';

  @override
  String streamBroken(String error) {
    return 'Collegamento con l\'agente interrotto: $error';
  }

  @override
  String get streamEnded =>
      'Il collegamento con l\'agente si è chiuso prima della fine della risposta. Riprova.';

  @override
  String get serverUnknownError => 'Errore sconosciuto del servizio.';

  @override
  String serverRejectedRequest(String field) {
    return 'Il servizio non ha accettato la richiesta (campo «$field»). Riprova; se si ripete, segnalalo.';
  }

  @override
  String serverErrorStatus(int status) {
    return 'Il servizio dell\'agente ha risposto con un errore ($status).';
  }

  @override
  String get toolDocumentFallback => 'documento';

  @override
  String toolOnPage(String page) {
    return ' · pagina $page';
  }

  @override
  String toolCreateDocument(String title) {
    return 'Creo \"$title\"';
  }

  @override
  String get toolReadDocument => 'Leggo il documento';

  @override
  String get toolAddPage => 'Aggiungo una pagina';

  @override
  String toolDeletePage(String on) {
    return 'Elimino la pagina$on';
  }

  @override
  String toolUpdatePage(String on) {
    return 'Riscrivo la pagina$on';
  }

  @override
  String toolReplaceText(String find) {
    return 'Sostituisco \"$find\"';
  }

  @override
  String toolInsertBlock(String on) {
    return 'Inserisco un blocco$on';
  }

  @override
  String toolUpdateBlock(String block, String on) {
    return 'Modifico il blocco $block$on';
  }

  @override
  String toolRemoveBlock(String block, String on) {
    return 'Rimuovo il blocco $block$on';
  }

  @override
  String toolAddTable(String on) {
    return 'Aggiungo una tabella$on';
  }

  @override
  String toolAddImage(String on) {
    return 'Aggiungo un\'immagine$on';
  }

  @override
  String toolChangeLayout(String on) {
    return 'Cambio l’impaginazione$on';
  }

  @override
  String get toolSetTheme => 'Aggiorno il tema';

  @override
  String get toolUpdateMetadata => 'Aggiorno i dati';

  @override
  String get toolExportPdf => 'Esporto il PDF';

  @override
  String get storeNoticeNewer =>
      'Questi dati sono stati salvati da una versione più recente di PaperAgent: puoi consultarli, ma le modifiche non verranno salvate finché non aggiorni l\'app.';

  @override
  String get storeNoticeRestored =>
      'L’indice del lavoro salvato era danneggiato: ho ripristinato l’ultimo salvataggio valido. L’originale è rimasto nella cartella dati.';

  @override
  String storeNoticeSaveFailed(String reason) {
    return 'Non riesco a salvare il lavoro sul disco ($reason). Le modifiche restano aperte: riprovo alla prossima modifica.';
  }

  @override
  String storeNoticeUnreadable(String reason) {
    return 'Non riesco a leggere una parte del lavoro salvato ($reason): forse è aperta in un altro programma. Ti mostro quello che ho letto, ma non salvo le modifiche finché non riapri PaperAgent.';
  }

  @override
  String storeNoticeRecovered(int documents, int chats, String project) {
    return 'L\'indice del lavoro salvato era illeggibile: ho recuperato $documents documenti e $chats conversazioni nel progetto «$project».';
  }

  @override
  String get docErrorLastPage => 'Un documento deve avere almeno una pagina.';

  @override
  String docErrorNoPage(int page, int count) {
    return 'La pagina $page non esiste (il documento ne ha $count).';
  }

  @override
  String docErrorNoBlock(String block) {
    return 'Blocco $block non trovato.';
  }

  @override
  String get docErrorEmptySearch => 'Il testo da cercare è vuoto.';

  @override
  String get docErrorNoDocument => 'Nessun documento aperto.';

  @override
  String updateDownloading(int percent) {
    return 'Scarico l\'aggiornamento… $percent%';
  }

  @override
  String get updateReady => 'Aggiorna l\'app';

  @override
  String get updateInstalling => 'Riavvio per aggiornare…';

  @override
  String get updateBlocked => 'Aggiornamento da completare';

  @override
  String updateTooltip(String version) {
    return 'Versione $version disponibile';
  }

  @override
  String updateDialogTitle(String version) {
    return 'Versione $version';
  }

  @override
  String get updateDialogBody =>
      'La nuova versione è scaricata e verificata. L\'app si chiude, si aggiorna e si riapre da sola: il lavoro è salvato prima.';

  @override
  String updateRunningWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count conversazioni sono ancora in corso: il riavvio le interrompe.',
      one: 'Una conversazione è ancora in corso: il riavvio la interrompe.',
    );
    return '$_temp0';
  }

  @override
  String get updateNotes => 'Novità';

  @override
  String get updateLater => 'Più tardi';

  @override
  String get updateRestart => 'Riavvia e aggiorna';

  @override
  String get updateRetry => 'Riprova';

  @override
  String updateProblemNotWritable(String path) {
    return 'L\'app non può aggiornarsi da sola: la cartella $path non è modificabile. Spostala in una cartella tua e riaprila, o installa la nuova versione a mano.';
  }

  @override
  String get updateProblemNotInstalled =>
      'Sposta l\'app nella cartella Applicazioni e riaprila da lì: così potrà aggiornarsi da sola.';

  @override
  String updateInstallFailed(String log) {
    return 'L\'ultimo aggiornamento non è andato a buon fine: l\'app è rimasta alla versione precedente. Puoi riprovare; i dettagli sono in $log.';
  }

  @override
  String get settingsUpdates => 'Aggiornamenti';

  @override
  String get settingsVersion => 'Versione installata';

  @override
  String settingsVersionValue(String version, int build) {
    return '$version (revisione $build)';
  }

  @override
  String get updateCheckNow => 'Controlla ora';

  @override
  String get updateStatusOff => 'Questa versione non si aggiorna da sola.';

  @override
  String get updateStatusChecking => 'Controllo gli aggiornamenti…';

  @override
  String get updateStatusUpToDate =>
      'L\'app è aggiornata: controlla da sola ogni mezz\'ora.';

  @override
  String get updateStatusCheckFailed =>
      'Non riesco a raggiungere il servizio degli aggiornamenti: riprovo più tardi.';

  @override
  String updateStatusReady(String version) {
    return 'La versione $version è pronta: riavvia l\'app per installarla.';
  }

  @override
  String get sourceTitle => 'Fonte';

  @override
  String sourcePage(String name, int page) {
    return '$name, pagina $page';
  }

  @override
  String sourcePages(String name, int first, int last) {
    return '$name, pagine $first–$last';
  }

  @override
  String sourceOpen(String reference) {
    return 'Apri $reference';
  }

  @override
  String get sourceLoading => 'Apro il documento…';

  @override
  String get sourceUnavailable => 'Documento non disponibile';

  @override
  String get sourceMissingMessage =>
      'Il documento o la pagina non sono più disponibili in questa conversazione. Se necessario, allega nuovamente il documento.';

  @override
  String get sourceConnectionMessage =>
      'Non riesco ad aprire la fonte. Controlla la connessione e riprova.';

  @override
  String get sourceRetry => 'Riprova';

  @override
  String get sourceOriginal => 'Documento originale · sola lettura';

  @override
  String get sourceExtracted =>
      'Testo estratto · impaginazione originale non riprodotta';

  @override
  String get sourceNoText => 'Questa pagina non contiene testo leggibile.';

  @override
  String get sourcePrevious => 'Passaggio precedente';

  @override
  String get sourceNext => 'Passaggio successivo';

  @override
  String get webLinkUnavailable =>
      'Impossibile aprire il collegamento. Riprova dal navigatore.';

  @override
  String sourceSection(String name, int page) {
    return '$name, sezione $page';
  }

  @override
  String get reviewRunning => 'Verifico italiano e impaginazione…';

  @override
  String get reviewUnavailable =>
      'Verifica non completata. L’esportazione resta sospesa.';

  @override
  String get reviewClean =>
      'Controlli automatici completati: nessun rilievo rilevato.';

  @override
  String get reviewAdvisory => 'Riferimenti da rileggere';

  @override
  String get reviewRequired =>
      'Correzioni da verificare prima dell’esportazione';

  @override
  String get reviewHelp =>
      'Correggi nel testo. Conferma soltanto i passaggi che ritieni corretti.';

  @override
  String get reviewMetadata => 'Titolo e dati del documento';

  @override
  String get reviewProtected =>
      'Citazione o dato originale: verificare senza alterarne il senso.';

  @override
  String get reviewKeepTerm => 'Mantieni testo';

  @override
  String get reviewConfirmed => 'Confermato';

  @override
  String get pdfPreparedFor => 'Destinatario';

  @override
  String get pdfPreparedBy => 'Redatto da';

  @override
  String get pdfDate => 'Data';

  @override
  String get pdfMonthNames =>
      'gennaio;febbraio;marzo;aprile;maggio;giugno;luglio;agosto;settembre;ottobre;novembre;dicembre';

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
  String get operationApplied => 'Operazione eseguita';

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
    String _temp0 = intl.Intl.pluralLogic(
      claims,
      locale: localeName,
      other: '$claims affermazioni',
      one: '1 affermazione',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sources,
      locale: localeName,
      other: '$sources fonti richiamate',
      one: '1 fonte richiamata',
    );
    return '$_temp0 · $_temp1';
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
  String get accessTitle => 'Accedi a Daylex';

  @override
  String get accessHelp =>
      'Inserisci la chiave ricevuta dal tuo amministratore. Ogni chiave è associata a un solo computer.';

  @override
  String get accessInvalidKey =>
      'Inserisci una chiave Daylex completa, con prefisso dlx_.';

  @override
  String get accessVaultFailed =>
      'Impossibile aprire l’archivio protetto del computer. Sblocca il portachiavi e riprova.';

  @override
  String get accessShowKey => 'Mostra chiave';

  @override
  String get accessHideKey => 'Nascondi chiave';

  @override
  String get accessActivate => 'Attiva su questo computer';

  @override
  String get accessDisclosure =>
      'L’amministratore può vedere presenza, sezioni utilizzate, tipo, durata ed esito delle richieste. Se abilitata sul servizio, la supervisione include il testo delle richieste inviate. Bozze, digitazione e allegati non vengono copiati nelle analitiche. La conservazione è limitata dalla configurazione del servizio; i documenti restano salvati sul computer.';

  @override
  String get accessAcknowledge => 'Ho letto l’informativa sulla supervisione';

  @override
  String get serviceMaintenance => 'Daylex è in manutenzione';

  @override
  String get serviceMaintenanceHelp =>
      'Le nuove richieste sono temporaneamente sospese. Il lavoro già salvato resta disponibile sul computer.';

  @override
  String get serviceOffline => 'Connessione al servizio non disponibile';

  @override
  String get serviceOfflineHelp =>
      'Non è stato possibile verificare lo stato del servizio. Il lavoro locale resta disponibile; controlla la rete e riprova.';

  @override
  String get serviceDetails => 'Dettagli';

  @override
  String get serviceRetry => 'Riprova';

  @override
  String get operationUncertain => 'Esito da verificare';

  @override
  String get operationVerificationHint =>
      'La sessione si è interrotta prima di ricevere l’esito. Controlla il documento prima di ripetere l’operazione.';

  @override
  String get instanceUnavailable =>
      'Daylex è già aperto oppure la cartella dei dati non è accessibile. Chiudi l’altra finestra e riprova; se il problema persiste, verifica i permessi della cartella.';

  @override
  String get exitUnsavedTitle => 'Modifiche non salvate';

  @override
  String get exitUnsavedHelp =>
      'Il salvataggio non è riuscito. Mantieni aperta l’app e riprova dopo aver verificato spazio e permessi del disco. Uscendo perderai le modifiche non salvate.';

  @override
  String get exitKeepOpen => 'Mantieni aperto';

  @override
  String get exitDiscard => 'Esci senza salvare';

  @override
  String get accessKeyHint => 'dlx_…';

  @override
  String get webAccessHelp =>
      'Inserisci una chiave dedicata a questo browser, ricevuta dall’amministratore. La chiave già associata all’app desktop non si trasferisce automaticamente.';

  @override
  String get webSessionHelp =>
      'La chiave resta solo in questa sessione: dovrai reinserirla quando ricarichi o riapri Daylex. Documenti e chat rimangono in questo browser; scarica regolarmente una copia dell’archivio.';
}
