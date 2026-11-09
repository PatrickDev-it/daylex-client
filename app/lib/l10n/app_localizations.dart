import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('it'),
  ];

  /// The product name
  ///
  /// In it, this message translates to:
  /// **'Daylex'**
  String get appTitle;

  /// No description provided for @languageItalian.
  ///
  /// In it, this message translates to:
  /// **'Italiano'**
  String get languageItalian;

  /// No description provided for @languageEnglish.
  ///
  /// In it, this message translates to:
  /// **'Inglese'**
  String get languageEnglish;

  /// Button that dismisses a dialog
  ///
  /// In it, this message translates to:
  /// **'Annulla'**
  String get cancel;

  /// Button that deletes something
  ///
  /// In it, this message translates to:
  /// **'Elimina'**
  String get delete;

  /// No description provided for @close.
  ///
  /// In it, this message translates to:
  /// **'Chiudi'**
  String get close;

  /// No description provided for @rename.
  ///
  /// In it, this message translates to:
  /// **'Rinomina'**
  String get rename;

  /// No description provided for @save.
  ///
  /// In it, this message translates to:
  /// **'Salva'**
  String get save;

  /// No description provided for @untitledDocument.
  ///
  /// In it, this message translates to:
  /// **'Documento senza titolo'**
  String get untitledDocument;

  /// No description provided for @untitledProject.
  ///
  /// In it, this message translates to:
  /// **'Progetto senza nome'**
  String get untitledProject;

  /// Name of the empty project a first launch opens on
  ///
  /// In it, this message translates to:
  /// **'Generale'**
  String get firstProject;

  /// No description provided for @newChat.
  ///
  /// In it, this message translates to:
  /// **'Nuova conversazione'**
  String get newChat;

  /// No description provided for @newDocument.
  ///
  /// In it, this message translates to:
  /// **'Nuovo documento'**
  String get newDocument;

  /// No description provided for @exportPdf.
  ///
  /// In it, this message translates to:
  /// **'Esporta PDF'**
  String get exportPdf;

  /// No description provided for @settings.
  ///
  /// In it, this message translates to:
  /// **'Impostazioni'**
  String get settings;

  /// No description provided for @whatsappTitle.
  ///
  /// In it, this message translates to:
  /// **'WhatsApp'**
  String get whatsappTitle;

  /// No description provided for @whatsappConnect.
  ///
  /// In it, this message translates to:
  /// **'Collega WhatsApp'**
  String get whatsappConnect;

  /// No description provided for @whatsappConnected.
  ///
  /// In it, this message translates to:
  /// **'Collegato'**
  String get whatsappConnected;

  /// No description provided for @whatsappWaiting.
  ///
  /// In it, this message translates to:
  /// **'In attesa del collegamento'**
  String get whatsappWaiting;

  /// No description provided for @whatsappScanQr.
  ///
  /// In it, this message translates to:
  /// **'Scansiona il QR da WhatsApp > Dispositivi collegati'**
  String get whatsappScanQr;

  /// No description provided for @whatsappUnavailable.
  ///
  /// In it, this message translates to:
  /// **'WhatsApp non disponibile'**
  String get whatsappUnavailable;

  /// No description provided for @whatsappHelp.
  ///
  /// In it, this message translates to:
  /// **'Messaggi di testo e appuntamenti tramite l\'agente, con sessione salvata su questo computer.'**
  String get whatsappHelp;

  /// No description provided for @whatsappCheckStatus.
  ///
  /// In it, this message translates to:
  /// **'Verifico WhatsApp'**
  String get whatsappCheckStatus;

  /// No description provided for @whatsappSearchContact.
  ///
  /// In it, this message translates to:
  /// **'Cerco un contatto WhatsApp'**
  String get whatsappSearchContact;

  /// No description provided for @whatsappSendText.
  ///
  /// In it, this message translates to:
  /// **'Invio un messaggio WhatsApp'**
  String get whatsappSendText;

  /// No description provided for @pageCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 pagina} other{{count} pagine}}'**
  String pageCount(int count);

  /// No description provided for @wordCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 parola} other{{count} parole}}'**
  String wordCount(int count);

  /// No description provided for @pageNumber.
  ///
  /// In it, this message translates to:
  /// **'Pagina {page}'**
  String pageNumber(int page);

  /// Relative time under a minute
  ///
  /// In it, this message translates to:
  /// **'adesso'**
  String get timeNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In it, this message translates to:
  /// **'{minutes} min fa'**
  String timeMinutesAgo(int minutes);

  /// No description provided for @timeHoursAgo.
  ///
  /// In it, this message translates to:
  /// **'{hours} h fa'**
  String timeHoursAgo(int hours);

  /// No description provided for @timeDaysAgo.
  ///
  /// In it, this message translates to:
  /// **'{days, plural, =1{ieri} other{{days} giorni fa}}'**
  String timeDaysAgo(int days);

  /// No description provided for @timeYesterdayAt.
  ///
  /// In it, this message translates to:
  /// **'ieri {time}'**
  String timeYesterdayAt(String time);

  /// The twelve month abbreviations, separated by one space
  ///
  /// In it, this message translates to:
  /// **'gen feb mar apr mag giu lug ago set ott nov dic'**
  String get monthsShort;

  /// No description provided for @dateThisYear.
  ///
  /// In it, this message translates to:
  /// **'{day} {month}'**
  String dateThisYear(int day, String month);

  /// No description provided for @dateOtherYear.
  ///
  /// In it, this message translates to:
  /// **'{day} {month} {year}'**
  String dateOtherYear(int day, String month, String year);

  /// No description provided for @dateAt.
  ///
  /// In it, this message translates to:
  /// **'{date}, {time}'**
  String dateAt(String date, String time);

  /// No description provided for @docStatusDraft.
  ///
  /// In it, this message translates to:
  /// **'Bozza'**
  String get docStatusDraft;

  /// No description provided for @docStatusReview.
  ///
  /// In it, this message translates to:
  /// **'In revisione'**
  String get docStatusReview;

  /// No description provided for @docStatusApproved.
  ///
  /// In it, this message translates to:
  /// **'Approvato'**
  String get docStatusApproved;

  /// No description provided for @layoutCover.
  ///
  /// In it, this message translates to:
  /// **'Copertina'**
  String get layoutCover;

  /// No description provided for @layoutStandard.
  ///
  /// In it, this message translates to:
  /// **'Classica'**
  String get layoutStandard;

  /// No description provided for @layoutTwoColumn.
  ///
  /// In it, this message translates to:
  /// **'Due colonne'**
  String get layoutTwoColumn;

  /// No description provided for @layoutPremium.
  ///
  /// In it, this message translates to:
  /// **'Curata'**
  String get layoutPremium;

  /// No description provided for @blockHeading.
  ///
  /// In it, this message translates to:
  /// **'Titolo'**
  String get blockHeading;

  /// No description provided for @blockParagraph.
  ///
  /// In it, this message translates to:
  /// **'Paragrafo'**
  String get blockParagraph;

  /// No description provided for @blockBullets.
  ///
  /// In it, this message translates to:
  /// **'Elenco puntato'**
  String get blockBullets;

  /// No description provided for @blockTable.
  ///
  /// In it, this message translates to:
  /// **'Tabella'**
  String get blockTable;

  /// No description provided for @blockMetrics.
  ///
  /// In it, this message translates to:
  /// **'Indicatori'**
  String get blockMetrics;

  /// No description provided for @blockQuote.
  ///
  /// In it, this message translates to:
  /// **'Citazione'**
  String get blockQuote;

  /// No description provided for @blockCallout.
  ///
  /// In it, this message translates to:
  /// **'Riquadro'**
  String get blockCallout;

  /// No description provided for @blockImage.
  ///
  /// In it, this message translates to:
  /// **'Immagine'**
  String get blockImage;

  /// A step in the document history
  ///
  /// In it, this message translates to:
  /// **'Aggiungi pagina'**
  String get opAddPage;

  /// No description provided for @opDeletePage.
  ///
  /// In it, this message translates to:
  /// **'Elimina pagina {page}'**
  String opDeletePage(int page);

  /// No description provided for @opMovePage.
  ///
  /// In it, this message translates to:
  /// **'Sposta pagina {page}'**
  String opMovePage(int page);

  /// No description provided for @opUpdatePage.
  ///
  /// In it, this message translates to:
  /// **'Aggiorna pagina {page}'**
  String opUpdatePage(int page);

  /// No description provided for @opReplace.
  ///
  /// In it, this message translates to:
  /// **'Sostituisci «{find}»'**
  String opReplace(String find);

  /// kind is a block kind, lowercase
  ///
  /// In it, this message translates to:
  /// **'Inserisci {kind}'**
  String opInsertBlock(String kind);

  /// No description provided for @opEditBlock.
  ///
  /// In it, this message translates to:
  /// **'Modifica {kind}'**
  String opEditBlock(String kind);

  /// No description provided for @opRemoveBlock.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi blocco'**
  String get opRemoveBlock;

  /// No description provided for @opMoveBlock.
  ///
  /// In it, this message translates to:
  /// **'Sposta blocco'**
  String get opMoveBlock;

  /// No description provided for @opChangeTheme.
  ///
  /// In it, this message translates to:
  /// **'Cambia tema'**
  String get opChangeTheme;

  /// No description provided for @opUpdateDetails.
  ///
  /// In it, this message translates to:
  /// **'Aggiorna dettagli'**
  String get opUpdateDetails;

  /// No description provided for @shortcutNewChat.
  ///
  /// In it, this message translates to:
  /// **'Nuova conversazione'**
  String get shortcutNewChat;

  /// No description provided for @shortcutNewDocument.
  ///
  /// In it, this message translates to:
  /// **'Nuovo documento'**
  String get shortcutNewDocument;

  /// No description provided for @shortcutFocusPrompt.
  ///
  /// In it, this message translates to:
  /// **'Scrivi un messaggio'**
  String get shortcutFocusPrompt;

  /// No description provided for @shortcutStopAgent.
  ///
  /// In it, this message translates to:
  /// **'Ferma l\'agente'**
  String get shortcutStopAgent;

  /// No description provided for @shortcutExport.
  ///
  /// In it, this message translates to:
  /// **'Esporta PDF'**
  String get shortcutExport;

  /// No description provided for @shortcutUndo.
  ///
  /// In it, this message translates to:
  /// **'Annulla la modifica'**
  String get shortcutUndo;

  /// No description provided for @shortcutRedo.
  ///
  /// In it, this message translates to:
  /// **'Ripeti la modifica'**
  String get shortcutRedo;

  /// No description provided for @shortcutPreview.
  ///
  /// In it, this message translates to:
  /// **'Anteprima del documento'**
  String get shortcutPreview;

  /// No description provided for @shortcutEdit.
  ///
  /// In it, this message translates to:
  /// **'Modifica del documento'**
  String get shortcutEdit;

  /// No description provided for @shortcutPreviousPage.
  ///
  /// In it, this message translates to:
  /// **'Pagina precedente'**
  String get shortcutPreviousPage;

  /// No description provided for @shortcutNextPage.
  ///
  /// In it, this message translates to:
  /// **'Pagina successiva'**
  String get shortcutNextPage;

  /// No description provided for @shortcutZoomIn.
  ///
  /// In it, this message translates to:
  /// **'Ingrandisci'**
  String get shortcutZoomIn;

  /// No description provided for @shortcutZoomOut.
  ///
  /// In it, this message translates to:
  /// **'Riduci'**
  String get shortcutZoomOut;

  /// No description provided for @shortcutZoomReset.
  ///
  /// In it, this message translates to:
  /// **'Dimensione al 100%'**
  String get shortcutZoomReset;

  /// No description provided for @shortcutLibraryTab.
  ///
  /// In it, this message translates to:
  /// **'Libreria'**
  String get shortcutLibraryTab;

  /// No description provided for @shortcutReviewTab.
  ///
  /// In it, this message translates to:
  /// **'Revisione delle modifiche'**
  String get shortcutReviewTab;

  /// No description provided for @shortcutLogTab.
  ///
  /// In it, this message translates to:
  /// **'Registro dell\'agente'**
  String get shortcutLogTab;

  /// No description provided for @shortcutCloseTab.
  ///
  /// In it, this message translates to:
  /// **'Chiudi il scheda'**
  String get shortcutCloseTab;

  /// No description provided for @shortcutToggleSidebar.
  ///
  /// In it, this message translates to:
  /// **'Mostra o nascondi la barra laterale'**
  String get shortcutToggleSidebar;

  /// No description provided for @shortcutTogglePanel.
  ///
  /// In it, this message translates to:
  /// **'Mostra o nascondi il pannello laterale'**
  String get shortcutTogglePanel;

  /// No description provided for @shortcutToggleTheme.
  ///
  /// In it, this message translates to:
  /// **'Tema chiaro o scuro'**
  String get shortcutToggleTheme;

  /// Side-panel tab
  ///
  /// In it, this message translates to:
  /// **'Anteprima'**
  String get tabPreview;

  /// No description provided for @tabReview.
  ///
  /// In it, this message translates to:
  /// **'Revisione'**
  String get tabReview;

  /// No description provided for @tabReviewCount.
  ///
  /// In it, this message translates to:
  /// **'Revisione · {count}'**
  String tabReviewCount(int count);

  /// No description provided for @tabLibrary.
  ///
  /// In it, this message translates to:
  /// **'Libreria'**
  String get tabLibrary;

  /// No description provided for @tabLog.
  ///
  /// In it, this message translates to:
  /// **'Diagnostica'**
  String get tabLog;

  /// A preview tab whose document is gone
  ///
  /// In it, this message translates to:
  /// **'Documento'**
  String get tabDocument;

  /// No description provided for @deleteTitle.
  ///
  /// In it, this message translates to:
  /// **'Eliminare «{title}»?'**
  String deleteTitle(String title);

  /// No description provided for @deleteChatMessage.
  ///
  /// In it, this message translates to:
  /// **'Vengono eliminati anche i suoi messaggi e i documenti letti nel suo fascicolo. L\'operazione non si può annullare.'**
  String get deleteChatMessage;

  /// No description provided for @deleteDocumentMessage.
  ///
  /// In it, this message translates to:
  /// **'Viene eliminata anche la sua cronologia delle versioni. L\'operazione non si può annullare.'**
  String get deleteDocumentMessage;

  /// No description provided for @documentCreated.
  ///
  /// In it, this message translates to:
  /// **'Creato «{title}»'**
  String documentCreated(String title);

  /// No description provided for @documentDeleted.
  ///
  /// In it, this message translates to:
  /// **'Eliminato «{title}»'**
  String documentDeleted(String title);

  /// No description provided for @exportNoDocument.
  ///
  /// In it, this message translates to:
  /// **'Apri un documento per esportarlo.'**
  String get exportNoDocument;

  /// No description provided for @exportedTo.
  ///
  /// In it, this message translates to:
  /// **'Esportato in {path}'**
  String exportedTo(String path);

  /// No description provided for @exportFailed.
  ///
  /// In it, this message translates to:
  /// **'Esportazione non riuscita: {error}'**
  String exportFailed(String error);

  /// Toast after undo; label is the history step
  ///
  /// In it, this message translates to:
  /// **'Annullato: {label}'**
  String undid(String label);

  /// No description provided for @redid.
  ///
  /// In it, this message translates to:
  /// **'Ripristinato: {label}'**
  String redid(String label);

  /// No description provided for @templatePickerHint.
  ///
  /// In it, this message translates to:
  /// **'Parti da un modello, oppure chiedi all\'agente di scriverne uno per te.'**
  String get templatePickerHint;

  /// No description provided for @gotIt.
  ///
  /// In it, this message translates to:
  /// **'Ho capito'**
  String get gotIt;

  /// No description provided for @toggleDarkMode.
  ///
  /// In it, this message translates to:
  /// **'Tema chiaro o scuro'**
  String get toggleDarkMode;

  /// No description provided for @reviewChanges.
  ///
  /// In it, this message translates to:
  /// **'Rivedi le modifiche'**
  String get reviewChanges;

  /// The agent client is the local rule-based mock, not the real model.
  ///
  /// In it, this message translates to:
  /// **'Agente simulato · senza connessione'**
  String get agentMockOffline;

  /// No description provided for @agentNotConnected.
  ///
  /// In it, this message translates to:
  /// **'Agente non collegato'**
  String get agentNotConnected;

  /// No description provided for @sidebarHide.
  ///
  /// In it, this message translates to:
  /// **'Nascondi la barra laterale'**
  String get sidebarHide;

  /// No description provided for @sidebarSearchChats.
  ///
  /// In it, this message translates to:
  /// **'Cerca nelle conversazioni'**
  String get sidebarSearchChats;

  /// No description provided for @sidebarFilterChats.
  ///
  /// In it, this message translates to:
  /// **'Filtra le conversazioni'**
  String get sidebarFilterChats;

  /// No description provided for @sidebarProjects.
  ///
  /// In it, this message translates to:
  /// **'Progetti'**
  String get sidebarProjects;

  /// No description provided for @sidebarNewProject.
  ///
  /// In it, this message translates to:
  /// **'Nuovo progetto'**
  String get sidebarNewProject;

  /// No description provided for @sidebarNewProjectHint.
  ///
  /// In it, this message translates to:
  /// **'es. Rossi S.r.l.'**
  String get sidebarNewProjectHint;

  /// No description provided for @sidebarCreate.
  ///
  /// In it, this message translates to:
  /// **'Crea'**
  String get sidebarCreate;

  /// No description provided for @sidebarNoChats.
  ///
  /// In it, this message translates to:
  /// **'Nessuna conversazione'**
  String get sidebarNoChats;

  /// No description provided for @sidebarShowMore.
  ///
  /// In it, this message translates to:
  /// **'Mostra altre'**
  String get sidebarShowMore;

  /// No description provided for @sidebarShowLess.
  ///
  /// In it, this message translates to:
  /// **'Mostra meno'**
  String get sidebarShowLess;

  /// No description provided for @sidebarChatsRunning.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 conversazione in corso} other{{count} conversazioni in corso}}'**
  String sidebarChatsRunning(int count);

  /// No description provided for @sidebarAgentReady.
  ///
  /// In it, this message translates to:
  /// **'Agente pronto'**
  String get sidebarAgentReady;

  /// No description provided for @settingsAppearance.
  ///
  /// In it, this message translates to:
  /// **'Aspetto'**
  String get settingsAppearance;

  /// No description provided for @settingsTheme.
  ///
  /// In it, this message translates to:
  /// **'Tema'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In it, this message translates to:
  /// **'Sistema'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In it, this message translates to:
  /// **'Chiaro'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In it, this message translates to:
  /// **'Scuro'**
  String get settingsThemeDark;

  /// No description provided for @settingsLanguage.
  ///
  /// In it, this message translates to:
  /// **'Lingua'**
  String get settingsLanguage;

  /// No description provided for @settingsAgent.
  ///
  /// In it, this message translates to:
  /// **'Agente'**
  String get settingsAgent;

  /// No description provided for @settingsBackend.
  ///
  /// In it, this message translates to:
  /// **'Servizio'**
  String get settingsBackend;

  /// No description provided for @settingsBackendMockHelp.
  ///
  /// In it, this message translates to:
  /// **'Le risposte arrivano da una simulazione locale, non dall\'agente: servono solo a provare l\'app.'**
  String get settingsBackendMockHelp;

  /// No description provided for @settingsBackendServerHelp.
  ///
  /// In it, this message translates to:
  /// **'L\'agente gira su un servizio ospitato in proprio.'**
  String get settingsBackendServerHelp;

  /// No description provided for @settingsAccessKey.
  ///
  /// In it, this message translates to:
  /// **'Chiave di accesso'**
  String get settingsAccessKey;

  /// No description provided for @settingsAccessKeyMissing.
  ///
  /// In it, this message translates to:
  /// **'La chiave personale che hai ricevuto per usare l\'agente: si inserisce una volta sola.'**
  String get settingsAccessKeyMissing;

  /// No description provided for @settingsAccessKeySet.
  ///
  /// In it, this message translates to:
  /// **'Chiave inserita. Se ne hai ricevuta una nuova, sostituiscila.'**
  String get settingsAccessKeySet;

  /// No description provided for @settingsAccessKeyEnter.
  ///
  /// In it, this message translates to:
  /// **'Inserisci'**
  String get settingsAccessKeyEnter;

  /// No description provided for @settingsAccessKeyReplace.
  ///
  /// In it, this message translates to:
  /// **'Sostituisci'**
  String get settingsAccessKeyReplace;

  /// No description provided for @settingsAccessKeyHint.
  ///
  /// In it, this message translates to:
  /// **'Incolla qui la chiave (inizia con dlx_)'**
  String get settingsAccessKeyHint;

  /// No description provided for @settingsAccessKeyChecking.
  ///
  /// In it, this message translates to:
  /// **'Verifico la chiave…'**
  String get settingsAccessKeyChecking;

  /// No description provided for @settingsAccessKeySaved.
  ///
  /// In it, this message translates to:
  /// **'Chiave salvata: l\'agente è collegato.'**
  String get settingsAccessKeySaved;

  /// No description provided for @settingsResetConnection.
  ///
  /// In it, this message translates to:
  /// **'Connessione Daylex'**
  String get settingsResetConnection;

  /// No description provided for @settingsResetConnectionAction.
  ///
  /// In it, this message translates to:
  /// **'Ripristina'**
  String get settingsResetConnectionAction;

  /// No description provided for @settingsResetConnectionHelp.
  ///
  /// In it, this message translates to:
  /// **'Usa il servizio predefinito dell\'app mantenendo la chiave di accesso.'**
  String get settingsResetConnectionHelp;

  /// No description provided for @settingsResetConnectionDone.
  ///
  /// In it, this message translates to:
  /// **'Connessione ripristinata. La chiave di accesso è stata mantenuta.'**
  String get settingsResetConnectionDone;

  /// No description provided for @serverAddressEnvironmentOverride.
  ///
  /// In it, this message translates to:
  /// **'L\'indirizzo del servizio è impostato dall\'ambiente PAPERAGENT_URL: chiedi all\'amministratore di aggiornarlo.'**
  String get serverAddressEnvironmentOverride;

  /// No description provided for @settingsAccessKeyUnverified.
  ///
  /// In it, this message translates to:
  /// **'Chiave salvata, ma per ora non posso verificarla. {reason}'**
  String settingsAccessKeyUnverified(String reason);

  /// No description provided for @settingsTools.
  ///
  /// In it, this message translates to:
  /// **'Strumenti'**
  String get settingsTools;

  /// No description provided for @settingsToolCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 strumento sul documento} other{{count} strumenti sul documento}}'**
  String settingsToolCount(int count);

  /// count = how many tools need approval; tools = their names, comma-separated.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =0{L\'agente modifica il documento con strumenti dedicati.} =1{L\'agente modifica il documento con strumenti dedicati; {tools} chiede prima la tua approvazione.} other{L\'agente modifica il documento con strumenti dedicati; {tools} chiedono prima la tua approvazione.}}'**
  String settingsToolsHelp(int count, String tools);

  /// No description provided for @settingsUiComponents.
  ///
  /// In it, this message translates to:
  /// **'Componenti nella conversazione'**
  String get settingsUiComponents;

  /// No description provided for @settingsUiComponentCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 componente} other{{count} componenti}}'**
  String settingsUiComponentCount(int count);

  /// No description provided for @settingsUiComponentsHelp.
  ///
  /// In it, this message translates to:
  /// **'Cosa l\'agente può mostrare nella conversazione: {names}.'**
  String settingsUiComponentsHelp(String names);

  /// No description provided for @settingsShortcuts.
  ///
  /// In it, this message translates to:
  /// **'Scorciatoie da tastiera'**
  String get settingsShortcuts;

  /// No description provided for @panelHide.
  ///
  /// In it, this message translates to:
  /// **'Nascondi il pannello laterale'**
  String get panelHide;

  /// No description provided for @panelOpenTab.
  ///
  /// In it, this message translates to:
  /// **'Apri un scheda'**
  String get panelOpenTab;

  /// No description provided for @panelNothingOpenTitle.
  ///
  /// In it, this message translates to:
  /// **'Ancora niente di aperto'**
  String get panelNothingOpenTitle;

  /// No description provided for @panelNothingOpenMessage.
  ///
  /// In it, this message translates to:
  /// **'Inizia una conversazione. Il documento su cui lavora compare qui in anteprima, accanto alla revisione di ogni modifica dell\'agente.'**
  String get panelNothingOpenMessage;

  /// No description provided for @panelNoTabsTitle.
  ///
  /// In it, this message translates to:
  /// **'Nessun scheda aperto'**
  String get panelNoTabsTitle;

  /// No description provided for @panelNoTabsMessage.
  ///
  /// In it, this message translates to:
  /// **'Apri l\'anteprima di un documento, rivedi cosa ha cambiato l\'agente o segui le sue chiamate agli strumenti.'**
  String get panelNoTabsMessage;

  /// No description provided for @logEventCount.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 evento} other{{count} eventi}}'**
  String logEventCount(int count);

  /// No description provided for @logCopy.
  ///
  /// In it, this message translates to:
  /// **'Copia il registro'**
  String get logCopy;

  /// No description provided for @logEmptyTitle.
  ///
  /// In it, this message translates to:
  /// **'Ancora nessun evento'**
  String get logEmptyTitle;

  /// No description provided for @logEmptyMessage.
  ///
  /// In it, this message translates to:
  /// **'Qui compaiono le richieste, gli aggiornamenti di stato e le chiamate agli strumenti di questa conversazione.'**
  String get logEmptyMessage;

  /// No description provided for @libraryThisProject.
  ///
  /// In it, this message translates to:
  /// **'Questo progetto'**
  String get libraryThisProject;

  /// No description provided for @libraryNoDocuments.
  ///
  /// In it, this message translates to:
  /// **'Ancora nessun documento.'**
  String get libraryNoDocuments;

  /// No description provided for @libraryOtherProjects.
  ///
  /// In it, this message translates to:
  /// **'Altri progetti'**
  String get libraryOtherProjects;

  /// No description provided for @libraryTemplates.
  ///
  /// In it, this message translates to:
  /// **'Modelli'**
  String get libraryTemplates;

  /// No description provided for @libraryOpenPreview.
  ///
  /// In it, this message translates to:
  /// **'Apri l\'anteprima'**
  String get libraryOpenPreview;

  /// No description provided for @libraryDuplicate.
  ///
  /// In it, this message translates to:
  /// **'Duplica'**
  String get libraryDuplicate;

  /// Title and heading of a page added from the outline editor
  ///
  /// In it, this message translates to:
  /// **'Nuova sezione'**
  String get editorNewSection;

  /// Button under the last page in the outline editor
  ///
  /// In it, this message translates to:
  /// **'Aggiungi pagina'**
  String get editorAddPage;

  /// Heading of the document details card in the outline editor
  ///
  /// In it, this message translates to:
  /// **'Documento'**
  String get editorDetailsTitle;

  /// Tooltip of the document status menu
  ///
  /// In it, this message translates to:
  /// **'Stato'**
  String get editorStatus;

  /// No description provided for @editorFieldTitle.
  ///
  /// In it, this message translates to:
  /// **'Titolo'**
  String get editorFieldTitle;

  /// No description provided for @editorFieldSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Sottotitolo'**
  String get editorFieldSubtitle;

  /// No description provided for @editorFieldClient.
  ///
  /// In it, this message translates to:
  /// **'Cliente'**
  String get editorFieldClient;

  /// The firm or brand name printed on the document
  ///
  /// In it, this message translates to:
  /// **'Marchio'**
  String get editorFieldBrand;

  /// Shown on the cover as the author
  ///
  /// In it, this message translates to:
  /// **'Redatto da'**
  String get editorFieldAuthor;

  /// No description provided for @editorAccent.
  ///
  /// In it, this message translates to:
  /// **'Colore d\'accento'**
  String get editorAccent;

  /// No description provided for @editorSectionTitleHint.
  ///
  /// In it, this message translates to:
  /// **'Titolo della sezione'**
  String get editorSectionTitleHint;

  /// Tooltip of a page's layout menu
  ///
  /// In it, this message translates to:
  /// **'Impaginazione'**
  String get editorLayout;

  /// No description provided for @editorShowInPreview.
  ///
  /// In it, this message translates to:
  /// **'Mostra nell\'anteprima'**
  String get editorShowInPreview;

  /// No description provided for @editorMoveUp.
  ///
  /// In it, this message translates to:
  /// **'Sposta su'**
  String get editorMoveUp;

  /// No description provided for @editorMoveDown.
  ///
  /// In it, this message translates to:
  /// **'Sposta giù'**
  String get editorMoveDown;

  /// No description provided for @editorDeletePage.
  ///
  /// In it, this message translates to:
  /// **'Elimina pagina'**
  String get editorDeletePage;

  /// No description provided for @editorAddBlock.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi blocco'**
  String get editorAddBlock;

  /// Tooltip of the button that removes a block
  ///
  /// In it, this message translates to:
  /// **'Rimuovi'**
  String get editorRemoveBlock;

  /// The first item of a new bullet list
  ///
  /// In it, this message translates to:
  /// **'Primo punto'**
  String get editorNewBulletItem;

  /// First column header of a new table
  ///
  /// In it, this message translates to:
  /// **'Voce'**
  String get editorNewTableItem;

  /// Second column header of a new table
  ///
  /// In it, this message translates to:
  /// **'Valore'**
  String get editorNewTableValue;

  /// Header of a column added to a table
  ///
  /// In it, this message translates to:
  /// **'Colonna'**
  String get editorNewTableColumn;

  /// Label of each metric in a new metrics block
  ///
  /// In it, this message translates to:
  /// **'Indicatore'**
  String get editorNewMetric;

  /// Title of a new callout block
  ///
  /// In it, this message translates to:
  /// **'Nota'**
  String get editorNewCallout;

  /// No description provided for @editorParagraphHint.
  ///
  /// In it, this message translates to:
  /// **'Scrivi qui…'**
  String get editorParagraphHint;

  /// No description provided for @editorBulletsHint.
  ///
  /// In it, this message translates to:
  /// **'• Un punto per riga'**
  String get editorBulletsHint;

  /// No description provided for @editorQuoteAuthorHint.
  ///
  /// In it, this message translates to:
  /// **'Autore'**
  String get editorQuoteAuthorHint;

  /// No description provided for @editorCalloutTitleHint.
  ///
  /// In it, this message translates to:
  /// **'Titolo del riquadro'**
  String get editorCalloutTitleHint;

  /// No description provided for @editorCalloutTextHint.
  ///
  /// In it, this message translates to:
  /// **'Testo del riquadro'**
  String get editorCalloutTextHint;

  /// No description provided for @editorMetricLabelHint.
  ///
  /// In it, this message translates to:
  /// **'Etichetta'**
  String get editorMetricLabelHint;

  /// No description provided for @editorMetricValueHint.
  ///
  /// In it, this message translates to:
  /// **'Valore'**
  String get editorMetricValueHint;

  /// No description provided for @editorMetricChangeHint.
  ///
  /// In it, this message translates to:
  /// **'Variazione'**
  String get editorMetricChangeHint;

  /// Button that adds a table row
  ///
  /// In it, this message translates to:
  /// **'Riga'**
  String get editorTableAddRow;

  /// Button that adds a table column
  ///
  /// In it, this message translates to:
  /// **'Colonna'**
  String get editorTableAddColumn;

  /// No description provided for @editorTableRemoveRow.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi l\'ultima riga'**
  String get editorTableRemoveRow;

  /// No description provided for @editorCaptionHint.
  ///
  /// In it, this message translates to:
  /// **'Didascalia'**
  String get editorCaptionHint;

  /// No description provided for @previewNotFoundTitle.
  ///
  /// In it, this message translates to:
  /// **'Documento non trovato'**
  String get previewNotFoundTitle;

  /// No description provided for @previewNotFoundMessage.
  ///
  /// In it, this message translates to:
  /// **'Potrebbe essere stato eliminato. Chiudi questo scheda o apri un altro documento.'**
  String get previewNotFoundMessage;

  /// Segment that shows the rendered PDF
  ///
  /// In it, this message translates to:
  /// **'Anteprima'**
  String get previewModePreview;

  /// Segment that shows the outline editor
  ///
  /// In it, this message translates to:
  /// **'Modifica'**
  String get previewModeEdit;

  /// Undo tooltip; label is the history step
  ///
  /// In it, this message translates to:
  /// **'Annulla: {label}'**
  String previewUndoStep(String label);

  /// Redo tooltip; label is the history step
  ///
  /// In it, this message translates to:
  /// **'Ripeti: {label}'**
  String previewRedoStep(String label);

  /// Short label of the export button
  ///
  /// In it, this message translates to:
  /// **'Esporta'**
  String get previewExport;

  /// No description provided for @previewPageOf.
  ///
  /// In it, this message translates to:
  /// **'Pagina {page} di {count}'**
  String previewPageOf(int page, int count);

  /// The PDF preview is being rendered again
  ///
  /// In it, this message translates to:
  /// **'Aggiornamento…'**
  String get previewRendering;

  /// time is a relative time, e.g. 5 min fa
  ///
  /// In it, this message translates to:
  /// **'Aggiornato · {time}'**
  String previewUpToDate(String time);

  /// The last render failed: the preview shows the document as it was before
  ///
  /// In it, this message translates to:
  /// **'Anteprima non aggiornata'**
  String get previewOutdated;

  /// No description provided for @previewRenderFailed.
  ///
  /// In it, this message translates to:
  /// **'Impossibile generare l\'anteprima del documento'**
  String get previewRenderFailed;

  /// No description provided for @reviewEmptyTitle.
  ///
  /// In it, this message translates to:
  /// **'Ancora nessuna modifica'**
  String get reviewEmptyTitle;

  /// No description provided for @reviewEmptyMessage.
  ///
  /// In it, this message translates to:
  /// **'Quando l\'agente modifica un documento, qui compare ogni pagina cambiata, con il confronto prima/dopo e le differenze nel testo.'**
  String get reviewEmptyMessage;

  /// Tooltip of the menu of the agent turns that changed the document
  ///
  /// In it, this message translates to:
  /// **'Scegli una richiesta'**
  String get reviewPickTurn;

  /// No description provided for @reviewLastTurn.
  ///
  /// In it, this message translates to:
  /// **'Ultima richiesta'**
  String get reviewLastTurn;

  /// No description provided for @reviewLastTurnPrompt.
  ///
  /// In it, this message translates to:
  /// **'Ultima richiesta · {prompt}'**
  String reviewLastTurnPrompt(String prompt);

  /// No description provided for @reviewTurnNumber.
  ///
  /// In it, this message translates to:
  /// **'Richiesta {number}'**
  String reviewTurnNumber(int number);

  /// Unit after the added and removed word counts; count is their sum
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{parola} other{parole}}'**
  String reviewWordsUnit(int count);

  /// Button that reverts every change of the selected agent turn
  ///
  /// In it, this message translates to:
  /// **'Annulla le modifiche'**
  String get reviewUndoTurn;

  /// No description provided for @reviewTurnReverted.
  ///
  /// In it, this message translates to:
  /// **'Modifiche di questa richiesta annullate'**
  String get reviewTurnReverted;

  /// No description provided for @reviewNothingToCompareTitle.
  ///
  /// In it, this message translates to:
  /// **'Niente da confrontare'**
  String get reviewNothingToCompareTitle;

  /// No description provided for @reviewNothingToCompareMessage.
  ///
  /// In it, this message translates to:
  /// **'Il documento di questa richiesta non è più disponibile.'**
  String get reviewNothingToCompareMessage;

  /// No description provided for @reviewPagesChanged.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 pagina modificata} other{{count} pagine modificate}}'**
  String reviewPagesChanged(int count);

  /// No description provided for @reviewBefore.
  ///
  /// In it, this message translates to:
  /// **'Prima'**
  String get reviewBefore;

  /// No description provided for @reviewAfter.
  ///
  /// In it, this message translates to:
  /// **'Dopo'**
  String get reviewAfter;

  /// In place of the before render of a page the turn added
  ///
  /// In it, this message translates to:
  /// **'Pagina nuova'**
  String get reviewNewPage;

  /// In place of the after render of a page the turn deleted
  ///
  /// In it, this message translates to:
  /// **'Eliminata'**
  String get reviewDeletedPage;

  /// Heading of the text diff
  ///
  /// In it, this message translates to:
  /// **'Testo'**
  String get reviewText;

  /// No description provided for @reviewSameText.
  ///
  /// In it, this message translates to:
  /// **'Stesso testo: sono cambiati solo l\'impaginazione o lo stile.'**
  String get reviewSameText;

  /// A prompt suggestion sent to the agent as written
  ///
  /// In it, this message translates to:
  /// **'Rendi più chiara la pagina 3 e riduci il testo'**
  String get chatSuggestionPolishPage;

  /// No description provided for @chatSuggestionOverview.
  ///
  /// In it, this message translates to:
  /// **'Dammi una panoramica del documento'**
  String get chatSuggestionOverview;

  /// No description provided for @chatSuggestionShowPage.
  ///
  /// In it, this message translates to:
  /// **'Mostrami la pagina 2'**
  String get chatSuggestionShowPage;

  /// No description provided for @chatSuggestionDeleteLastPage.
  ///
  /// In it, this message translates to:
  /// **'Elimina l\'ultima pagina'**
  String get chatSuggestionDeleteLastPage;

  /// No description provided for @chatSuggestionRoi.
  ///
  /// In it, this message translates to:
  /// **'Stima costi e benefici'**
  String get chatSuggestionRoi;

  /// No description provided for @chatSuggestionProposal.
  ///
  /// In it, this message translates to:
  /// **'Scrivi una proposta di una pagina per un nuovo cliente'**
  String get chatSuggestionProposal;

  /// No description provided for @chatSuggestionTeamOnePager.
  ///
  /// In it, this message translates to:
  /// **'Scrivi una presentazione dello studio in una pagina'**
  String get chatSuggestionTeamOnePager;

  /// No description provided for @chatShowSidebar.
  ///
  /// In it, this message translates to:
  /// **'Mostra la barra laterale'**
  String get chatShowSidebar;

  /// No description provided for @chatNewChatIn.
  ///
  /// In it, this message translates to:
  /// **'Nuova conversazione in {project}'**
  String chatNewChatIn(String project);

  /// No description provided for @chatShowPanel.
  ///
  /// In it, this message translates to:
  /// **'Mostra il pannello laterale'**
  String get chatShowPanel;

  /// No description provided for @chatHidePanel.
  ///
  /// In it, this message translates to:
  /// **'Nascondi il pannello laterale'**
  String get chatHidePanel;

  /// No description provided for @chatActions.
  ///
  /// In it, this message translates to:
  /// **'Azioni della conversazione'**
  String get chatActions;

  /// No description provided for @chatRenameTitle.
  ///
  /// In it, this message translates to:
  /// **'Rinomina la conversazione'**
  String get chatRenameTitle;

  /// No description provided for @chatClearConversation.
  ///
  /// In it, this message translates to:
  /// **'Svuota la conversazione'**
  String get chatClearConversation;

  /// No description provided for @chatDelete.
  ///
  /// In it, this message translates to:
  /// **'Elimina la conversazione'**
  String get chatDelete;

  /// No description provided for @chatWhatToWrite.
  ///
  /// In it, this message translates to:
  /// **'Cosa scriviamo?'**
  String get chatWhatToWrite;

  /// No description provided for @chatWhatToDoWith.
  ///
  /// In it, this message translates to:
  /// **'Cosa facciamo con «{title}»?'**
  String chatWhatToDoWith(String title);

  /// Tooltip of the project picker on the new-chat screen
  ///
  /// In it, this message translates to:
  /// **'Progetto'**
  String get chatNewProject;

  /// No description provided for @chatNewHintNoDocument.
  ///
  /// In it, this message translates to:
  /// **'Descrivi il documento che ti serve…'**
  String get chatNewHintNoDocument;

  /// No description provided for @chatNewHintDocument.
  ///
  /// In it, this message translates to:
  /// **'Chiedi una modifica a «{title}»…'**
  String chatNewHintDocument(String title);

  /// No description provided for @chatNewCardPolish.
  ///
  /// In it, this message translates to:
  /// **'Rifinisci una pagina'**
  String get chatNewCardPolish;

  /// No description provided for @chatNewCardOverview.
  ///
  /// In it, this message translates to:
  /// **'Panoramica'**
  String get chatNewCardOverview;

  /// No description provided for @chatNewCardProposal.
  ///
  /// In it, this message translates to:
  /// **'Nuova proposta'**
  String get chatNewCardProposal;

  /// No description provided for @chatNewCardTeam.
  ///
  /// In it, this message translates to:
  /// **'Presentazione dello studio'**
  String get chatNewCardTeam;

  /// No description provided for @chatDropNotAttached.
  ///
  /// In it, this message translates to:
  /// **'Documenti non allegati ({count}): {files}. Formati accettati: {types}.'**
  String chatDropNotAttached(int count, String files, String types);

  /// No description provided for @chatDropTooLarge.
  ///
  /// In it, this message translates to:
  /// **'Documenti troppo grandi ({count}): {files}. Si allegano al massimo {megabytes} MB per volta, contando quelli già allegati.'**
  String chatDropTooLarge(int count, String files, int megabytes);

  /// No description provided for @chatDropUnreadable.
  ///
  /// In it, this message translates to:
  /// **'Documenti non letti ({count}): {files}. Forse sono aperti in un altro programma: chiudili e riprova.'**
  String chatDropUnreadable(int count, String files);

  /// No description provided for @chatDropTitle.
  ///
  /// In it, this message translates to:
  /// **'Rilascia i documenti per aggiungerli a questa conversazione'**
  String get chatDropTitle;

  /// No description provided for @chatDropFormats.
  ///
  /// In it, this message translates to:
  /// **'PDF, .p7m firmati, DOCX, TXT e scansioni · più documenti o un\'intera cartella'**
  String get chatDropFormats;

  /// No description provided for @composerHint.
  ///
  /// In it, this message translates to:
  /// **'Chiedi una modifica o descrivi un documento…'**
  String get composerHint;

  /// No description provided for @composerAttach.
  ///
  /// In it, this message translates to:
  /// **'Allega documenti o immagini'**
  String get composerAttach;

  /// Tooltip of the send button, with its key
  ///
  /// In it, this message translates to:
  /// **'Invia  ·  Invio'**
  String get composerSend;

  /// No description provided for @composerNoDocument.
  ///
  /// In it, this message translates to:
  /// **'Nessun documento'**
  String get composerNoDocument;

  /// No description provided for @composerDocumentOnPage.
  ///
  /// In it, this message translates to:
  /// **'{title} · p. {page}'**
  String composerDocumentOnPage(String title, int page);

  /// No description provided for @composerPickDocument.
  ///
  /// In it, this message translates to:
  /// **'Documento su cui lavora l\'agente'**
  String get composerPickDocument;

  /// No description provided for @composerNoDocumentCreate.
  ///
  /// In it, this message translates to:
  /// **'Nessun documento · lo crea l\'agente'**
  String get composerNoDocumentCreate;

  /// Shown while the agent runs, before it names a step
  ///
  /// In it, this message translates to:
  /// **'Sto lavorando'**
  String get composerWorking;

  /// No description provided for @composerElapsed.
  ///
  /// In it, this message translates to:
  /// **'{seconds} s'**
  String composerElapsed(int seconds);

  /// No description provided for @composerStopHint.
  ///
  /// In it, this message translates to:
  /// **'{keys} per fermare'**
  String composerStopHint(String keys);

  /// No description provided for @copy.
  ///
  /// In it, this message translates to:
  /// **'Copia'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In it, this message translates to:
  /// **'Copiato'**
  String get copied;

  /// Language label of a code block with no language
  ///
  /// In it, this message translates to:
  /// **'testo'**
  String get cardCodePlainText;

  /// A component the agent is still writing; kind is its technical name
  ///
  /// In it, this message translates to:
  /// **'Preparazione di {kind}…'**
  String cardRendering(String kind);

  /// No description provided for @cardUnknownComponent.
  ///
  /// In it, this message translates to:
  /// **'ui:{kind} (componente sconosciuto)'**
  String cardUnknownComponent(String kind);

  /// No description provided for @cardOpen.
  ///
  /// In it, this message translates to:
  /// **'Apri'**
  String get cardOpen;

  /// No description provided for @cardShowInFolder.
  ///
  /// In it, this message translates to:
  /// **'Mostra nella cartella'**
  String get cardShowInFolder;

  /// No description provided for @cardApprovalNeeded.
  ///
  /// In it, this message translates to:
  /// **'Approvazione richiesta'**
  String get cardApprovalNeeded;

  /// No description provided for @cardApproved.
  ///
  /// In it, this message translates to:
  /// **'Approvata'**
  String get cardApproved;

  /// No description provided for @cardExpired.
  ///
  /// In it, this message translates to:
  /// **'Scaduta'**
  String get cardExpired;

  /// No description provided for @cardRejected.
  ///
  /// In it, this message translates to:
  /// **'Rifiutata'**
  String get cardRejected;

  /// No description provided for @cardApprove.
  ///
  /// In it, this message translates to:
  /// **'Approva'**
  String get cardApprove;

  /// No description provided for @cardReject.
  ///
  /// In it, this message translates to:
  /// **'Rifiuta'**
  String get cardReject;

  /// No description provided for @cardEditedPages.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{Modificata 1 pagina} other{Modificate {count} pagine}}'**
  String cardEditedPages(int count);

  /// After the words added and removed, e.g. +12 −3 words
  ///
  /// In it, this message translates to:
  /// **'parole'**
  String get cardWords;

  /// No description provided for @cardReverted.
  ///
  /// In it, this message translates to:
  /// **'Annullato'**
  String get cardReverted;

  /// No description provided for @cardUndo.
  ///
  /// In it, this message translates to:
  /// **'Annulla'**
  String get cardUndo;

  /// No description provided for @cardReview.
  ///
  /// In it, this message translates to:
  /// **'Rivedi'**
  String get cardReview;

  /// No description provided for @cardWorkedFor.
  ///
  /// In it, this message translates to:
  /// **'Ha lavorato per {duration}'**
  String cardWorkedFor(String duration);

  /// No description provided for @cardSeconds.
  ///
  /// In it, this message translates to:
  /// **'{seconds} s'**
  String cardSeconds(String seconds);

  /// No description provided for @cardMinutesSeconds.
  ///
  /// In it, this message translates to:
  /// **'{minutes} min {seconds} s'**
  String cardMinutesSeconds(int minutes, int seconds);

  /// No description provided for @cardToolCalls.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 chiamata a strumento} other{{count} chiamate a strumenti}}'**
  String cardToolCalls(int count);

  /// A page whose words did not change: only its layout did
  ///
  /// In it, this message translates to:
  /// **'impaginazione'**
  String get cardLayoutOnly;

  /// No description provided for @cardDocument.
  ///
  /// In it, this message translates to:
  /// **'Documento'**
  String get cardDocument;

  /// No description provided for @cardOpenPreview.
  ///
  /// In it, this message translates to:
  /// **'Apri anteprima'**
  String get cardOpenPreview;

  /// No description provided for @cardExport.
  ///
  /// In it, this message translates to:
  /// **'Esporta'**
  String get cardExport;

  /// No description provided for @cardOutline.
  ///
  /// In it, this message translates to:
  /// **'Struttura'**
  String get cardOutline;

  /// No description provided for @cardChart.
  ///
  /// In it, this message translates to:
  /// **'Grafico'**
  String get cardChart;

  /// No description provided for @cardPageUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Questa pagina non è più disponibile.'**
  String get cardPageUnavailable;

  /// No description provided for @cardFactLayout.
  ///
  /// In it, this message translates to:
  /// **'Impaginazione'**
  String get cardFactLayout;

  /// No description provided for @cardFactWords.
  ///
  /// In it, this message translates to:
  /// **'Parole'**
  String get cardFactWords;

  /// No description provided for @cardFactBlocks.
  ///
  /// In it, this message translates to:
  /// **'Blocchi'**
  String get cardFactBlocks;

  /// No description provided for @cardFactPage.
  ///
  /// In it, this message translates to:
  /// **'Pagina'**
  String get cardFactPage;

  /// No description provided for @cardPageOf.
  ///
  /// In it, this message translates to:
  /// **'{page} di {total}'**
  String cardPageOf(int page, int total);

  /// No description provided for @cardEmptyPage.
  ///
  /// In it, this message translates to:
  /// **'Pagina vuota'**
  String get cardEmptyPage;

  /// No description provided for @cardNothingToCompare.
  ///
  /// In it, this message translates to:
  /// **'Niente da confrontare.'**
  String get cardNothingToCompare;

  /// No description provided for @cardWordsAdded.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{+1 parola} other{+{count} parole}}'**
  String cardWordsAdded(int count);

  /// No description provided for @cardWordsRemoved.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{−1 parola} other{−{count} parole}}'**
  String cardWordsRemoved(int count);

  /// No description provided for @cardBefore.
  ///
  /// In it, this message translates to:
  /// **'Prima'**
  String get cardBefore;

  /// No description provided for @cardAfter.
  ///
  /// In it, this message translates to:
  /// **'Dopo'**
  String get cardAfter;

  /// No description provided for @cardProgressRunning.
  ///
  /// In it, this message translates to:
  /// **'Lavoro in corso'**
  String get cardProgressRunning;

  /// No description provided for @cardProgressDone.
  ///
  /// In it, this message translates to:
  /// **'Lavoro svolto'**
  String get cardProgressDone;

  /// No description provided for @cardSteps.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 passaggio} other{{count} passaggi}}'**
  String cardSteps(int count);

  /// No description provided for @cardMatrixTitle.
  ///
  /// In it, this message translates to:
  /// **'Matrice della sentenza'**
  String get cardMatrixTitle;

  /// No description provided for @cardMatrixEntries.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 voce verificata sul testo} other{{count} voci verificate sul testo}}'**
  String cardMatrixEntries(int count);

  /// No description provided for @cardMatrixPagesRead.
  ///
  /// In it, this message translates to:
  /// **'pagine lette: {pages}'**
  String cardMatrixPagesRead(String pages);

  /// No description provided for @legalNormsTitle.
  ///
  /// In it, this message translates to:
  /// **'Norme utilizzate'**
  String get legalNormsTitle;

  /// No description provided for @legalArticles.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 articolo} other{{count} articoli}}'**
  String legalArticles(int count);

  /// In the norms card subtitle, after the article count
  ///
  /// In it, this message translates to:
  /// **'testo ufficiale'**
  String get legalOfficialTextLower;

  /// No description provided for @legalToVerify.
  ///
  /// In it, this message translates to:
  /// **'{count} da verificare'**
  String legalToVerify(int count);

  /// No description provided for @legalWhatItSays.
  ///
  /// In it, this message translates to:
  /// **'Cosa dice'**
  String get legalWhatItSays;

  /// No description provided for @legalHowItApplies.
  ///
  /// In it, this message translates to:
  /// **'Come si collega al caso'**
  String get legalHowItApplies;

  /// No description provided for @legalWhyThisNorm.
  ///
  /// In it, this message translates to:
  /// **'Perché questa norma'**
  String get legalWhyThisNorm;

  /// No description provided for @legalHowFound.
  ///
  /// In it, this message translates to:
  /// **'Come è stata individuata'**
  String get legalHowFound;

  /// No description provided for @legalInForceAt.
  ///
  /// In it, this message translates to:
  /// **'testo vigente al {date}'**
  String legalInForceAt(String date);

  /// No description provided for @legalDiscardedNorms.
  ///
  /// In it, this message translates to:
  /// **'Norme vicine considerate e scartate ({count})'**
  String legalDiscardedNorms(int count);

  /// No description provided for @legalDegree.
  ///
  /// In it, this message translates to:
  /// **'{degree}° grado'**
  String legalDegree(int degree);

  /// No description provided for @legalDegree1Detail.
  ///
  /// In it, this message translates to:
  /// **'Riscontri diretti'**
  String get legalDegree1Detail;

  /// No description provided for @legalDegree2Detail.
  ///
  /// In it, this message translates to:
  /// **'Collegamenti tra fatti e norme'**
  String get legalDegree2Detail;

  /// No description provided for @legalDegree3Detail.
  ///
  /// In it, this message translates to:
  /// **'Tesi da approfondire'**
  String get legalDegree3Detail;

  /// No description provided for @legalClient.
  ///
  /// In it, this message translates to:
  /// **'Assistito'**
  String get legalClient;

  /// No description provided for @legalOpponent.
  ///
  /// In it, this message translates to:
  /// **'Controparte'**
  String get legalOpponent;

  /// No description provided for @legalCaseAnalysis.
  ///
  /// In it, this message translates to:
  /// **'Analisi del caso'**
  String get legalCaseAnalysis;

  /// No description provided for @legalLinks.
  ///
  /// In it, this message translates to:
  /// **'Collegamenti'**
  String get legalLinks;

  /// No description provided for @legalStrategies.
  ///
  /// In it, this message translates to:
  /// **'Strategie'**
  String get legalStrategies;

  /// No description provided for @legalNorms.
  ///
  /// In it, this message translates to:
  /// **'Norme'**
  String get legalNorms;

  /// No description provided for @legalEffectNeutral.
  ///
  /// In it, this message translates to:
  /// **'Neutro'**
  String get legalEffectNeutral;

  /// No description provided for @legalEffectFavourable.
  ///
  /// In it, this message translates to:
  /// **'Favorevole al nostro assistito'**
  String get legalEffectFavourable;

  /// No description provided for @legalEffectUnfavourable.
  ///
  /// In it, this message translates to:
  /// **'Sfavorevole al nostro assistito'**
  String get legalEffectUnfavourable;

  /// No description provided for @legalReasoning.
  ///
  /// In it, this message translates to:
  /// **'Ragionamento'**
  String get legalReasoning;

  /// No description provided for @legalElements.
  ///
  /// In it, this message translates to:
  /// **'Elementi ({count})'**
  String legalElements(int count);

  /// No description provided for @legalFromRequest.
  ///
  /// In it, this message translates to:
  /// **'dalla richiesta'**
  String get legalFromRequest;

  /// No description provided for @legalDocRef.
  ///
  /// In it, this message translates to:
  /// **'doc. {doc} · {name} · p. {page}'**
  String legalDocRef(String doc, String name, String page);

  /// No description provided for @legalOurClientNamed.
  ///
  /// In it, this message translates to:
  /// **'Nostro assistito · {name}'**
  String legalOurClientNamed(String name);

  /// No description provided for @legalOpponentNamed.
  ///
  /// In it, this message translates to:
  /// **'Controparte · {name}'**
  String legalOpponentNamed(String name);

  /// No description provided for @legalNoStrategy.
  ///
  /// In it, this message translates to:
  /// **'Nessuna strategia dimostrabile.'**
  String get legalNoStrategy;

  /// No description provided for @legalAttack.
  ///
  /// In it, this message translates to:
  /// **'Attacco'**
  String get legalAttack;

  /// No description provided for @legalDefence.
  ///
  /// In it, this message translates to:
  /// **'Difesa'**
  String get legalDefence;

  /// No description provided for @legalMove.
  ///
  /// In it, this message translates to:
  /// **'Mossa'**
  String get legalMove;

  /// No description provided for @legalExpectedReply.
  ///
  /// In it, this message translates to:
  /// **'Replica prevedibile della controparte'**
  String get legalExpectedReply;

  /// No description provided for @legalOurCounter.
  ///
  /// In it, this message translates to:
  /// **'Nostra contromossa'**
  String get legalOurCounter;

  /// No description provided for @legalBasedOn.
  ///
  /// In it, this message translates to:
  /// **'Si basa su: {links}'**
  String legalBasedOn(String links);

  /// No description provided for @legalDroppedLinks.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 collegamento scartato perché non dimostrabili sugli atti} other{{count} collegamenti scartati perché non dimostrabili sugli atti}}'**
  String legalDroppedLinks(int count);

  /// No description provided for @legalOfficialText.
  ///
  /// In it, this message translates to:
  /// **'Testo ufficiale'**
  String get legalOfficialText;

  /// No description provided for @legalOfficialTextOf.
  ///
  /// In it, this message translates to:
  /// **'Testo ufficiale · {caption}'**
  String legalOfficialTextOf(String caption);

  /// No description provided for @legalOpenOfficialText.
  ///
  /// In it, this message translates to:
  /// **'Apri il testo ufficiale'**
  String get legalOpenOfficialText;

  /// No description provided for @legalFitFull.
  ///
  /// In it, this message translates to:
  /// **'Pertinente'**
  String get legalFitFull;

  /// No description provided for @legalFitUnfit.
  ///
  /// In it, this message translates to:
  /// **'Non pertinente'**
  String get legalFitUnfit;

  /// No description provided for @legalFitDoubtful.
  ///
  /// In it, this message translates to:
  /// **'Da verificare'**
  String get legalFitDoubtful;

  /// No description provided for @legalFitUnrated.
  ///
  /// In it, this message translates to:
  /// **'Non valutata'**
  String get legalFitUnrated;

  /// Agent activity while attachments are still being read into the case file
  ///
  /// In it, this message translates to:
  /// **'Leggo gli allegati'**
  String get agentReadingAttachments;

  /// Agent activity between steps
  ///
  /// In it, this message translates to:
  /// **'Esamino la richiesta'**
  String get agentThinking;

  /// No description provided for @agentConsultingSources.
  ///
  /// In it, this message translates to:
  /// **'Consulto le fonti'**
  String get agentConsultingSources;

  /// No description provided for @agentDraftingDocument.
  ///
  /// In it, this message translates to:
  /// **'Preparo il documento'**
  String get agentDraftingDocument;

  /// No description provided for @agentCheckingResult.
  ///
  /// In it, this message translates to:
  /// **'Verifico il risultato'**
  String get agentCheckingResult;

  /// No description provided for @agentQueued.
  ///
  /// In it, this message translates to:
  /// **'Richiesta in attesa'**
  String get agentQueued;

  /// No description provided for @agentMaterialWarning.
  ///
  /// In it, this message translates to:
  /// **'Materiale da verificare'**
  String get agentMaterialWarning;

  /// No description provided for @agentPromptTooLong.
  ///
  /// In it, this message translates to:
  /// **'Il messaggio è troppo lungo ({length} caratteri, al massimo {max}): allega il testo come documento, o dividilo in più messaggi.'**
  String agentPromptTooLong(int length, int max);

  /// A turn or a tool call the lawyer stopped
  ///
  /// In it, this message translates to:
  /// **'Interrotto'**
  String get agentStopped;

  /// History entry of reverting what an agent turn changed
  ///
  /// In it, this message translates to:
  /// **'Modifiche della richiesta annullate'**
  String get agentUndoTurn;

  /// History entry of a change the agent made
  ///
  /// In it, this message translates to:
  /// **'Agente · {label}'**
  String agentHistoryLabel(String label);

  /// No description provided for @agentWaitingApproval.
  ///
  /// In it, this message translates to:
  /// **'In attesa della tua approvazione'**
  String get agentWaitingApproval;

  /// No description provided for @agentNoAnswer.
  ///
  /// In it, this message translates to:
  /// **'Nessuna risposta in tempo'**
  String get agentNoAnswer;

  /// No description provided for @agentNotApproved.
  ///
  /// In it, this message translates to:
  /// **'Non approvato'**
  String get agentNotApproved;

  /// No description provided for @approvalRunTool.
  ///
  /// In it, this message translates to:
  /// **'Confermi questa operazione? {tool}.'**
  String approvalRunTool(String tool);

  /// No description provided for @approvalDeletePage.
  ///
  /// In it, this message translates to:
  /// **'La pagina {page} · «{title}» ({words}) verrà eliminata. Potrai annullare l\'operazione.'**
  String approvalDeletePage(int page, String title, String words);

  /// File picker filter for attachments
  ///
  /// In it, this message translates to:
  /// **'Documenti e immagini'**
  String get attachmentTypeGroup;

  /// No description provided for @logWaitingApproval.
  ///
  /// In it, this message translates to:
  /// **'In attesa di approvazione: {title}'**
  String logWaitingApproval(String title);

  /// No description provided for @logRemoveAttachmentFailed.
  ///
  /// In it, this message translates to:
  /// **'Impossibile togliere «{name}» dal fascicolo: {error}'**
  String logRemoveAttachmentFailed(String name, String error);

  /// No description provided for @logToolCrashed.
  ///
  /// In it, this message translates to:
  /// **'Lo strumento {tool} si è interrotto per un errore: {error}'**
  String logToolCrashed(String tool, String error);

  /// No description provided for @logRunFinished.
  ///
  /// In it, this message translates to:
  /// **'Esecuzione terminata'**
  String get logRunFinished;

  /// No description provided for @logStoppedByUser.
  ///
  /// In it, this message translates to:
  /// **'Interrotto dall\'utente'**
  String get logStoppedByUser;

  /// No description provided for @logReverted.
  ///
  /// In it, this message translates to:
  /// **'«{title}» riportato a prima della richiesta'**
  String logReverted(String title);

  /// No description provided for @logReportFailed.
  ///
  /// In it, this message translates to:
  /// **'Impossibile inviare il risultato dello strumento: {error}'**
  String logReportFailed(String error);

  /// No description provided for @logUnknownComponent.
  ///
  /// In it, this message translates to:
  /// **'Componente sconosciuto «{kind}» ignorato'**
  String logUnknownComponent(String kind);

  /// No description provided for @serverKeyMissing.
  ///
  /// In it, this message translates to:
  /// **'Manca la chiave di accesso: inseriscila nelle Impostazioni, alla voce «Chiave di accesso».'**
  String get serverKeyMissing;

  /// No description provided for @serverConfigUnreadable.
  ///
  /// In it, this message translates to:
  /// **'La configurazione {source} non è leggibile: va sostituita.'**
  String serverConfigUnreadable(String source);

  /// No description provided for @serverAddressMissing.
  ///
  /// In it, this message translates to:
  /// **'Nella configurazione ({source}) manca l\'indirizzo del servizio.'**
  String serverAddressMissing(String source);

  /// No description provided for @serverAddressInvalid.
  ///
  /// In it, this message translates to:
  /// **'L\'indirizzo del servizio nella configurazione ({source}) non è valido: «{address}».'**
  String serverAddressInvalid(String source, String address);

  /// No description provided for @serverKeyRejected.
  ///
  /// In it, this message translates to:
  /// **'Il servizio non riconosce questa chiave: controlla di averla copiata per intero, o chiedine una nuova.'**
  String get serverKeyRejected;

  /// No description provided for @serverUserFolderMissing.
  ///
  /// In it, this message translates to:
  /// **'Non trovo la cartella utente in cui salvare la chiave.'**
  String get serverUserFolderMissing;

  /// No description provided for @connectionLocalOff.
  ///
  /// In it, this message translates to:
  /// **'Il collegamento a PaperAgent non è attivo su questo computer: avvialo e riprova.'**
  String get connectionLocalOff;

  /// No description provided for @connectionUnreachable.
  ///
  /// In it, this message translates to:
  /// **'Non riesco a raggiungere il servizio: controlla la connessione a internet e riprova.'**
  String get connectionUnreachable;

  /// No description provided for @connectionTls.
  ///
  /// In it, this message translates to:
  /// **'Il collegamento sicuro con il servizio non è riuscito: controlla che data e ora del computer siano giuste, poi riprova.'**
  String get connectionTls;

  /// No description provided for @connectionTimeout.
  ///
  /// In it, this message translates to:
  /// **'Il servizio non ha risposto in tempo: riprova tra un momento.'**
  String get connectionTimeout;

  /// No description provided for @connectionFailed.
  ///
  /// In it, this message translates to:
  /// **'Collegamento con il servizio non riuscito: {message}'**
  String connectionFailed(String message);

  /// No description provided for @connectionUnexpected.
  ///
  /// In it, this message translates to:
  /// **'Errore imprevisto nel collegamento al servizio ({type}): {error}'**
  String connectionUnexpected(String type, String error);

  /// No description provided for @failureUnreachable.
  ///
  /// In it, this message translates to:
  /// **'Non riesco a raggiungere il servizio dell\'agente.'**
  String get failureUnreachable;

  /// No description provided for @failureTls.
  ///
  /// In it, this message translates to:
  /// **'Il collegamento sicuro con il servizio dell\'agente non è riuscito.'**
  String get failureTls;

  /// No description provided for @failureTimeout.
  ///
  /// In it, this message translates to:
  /// **'Il servizio dell\'agente non ha risposto in tempo.'**
  String get failureTimeout;

  /// No description provided for @streamSilent.
  ///
  /// In it, this message translates to:
  /// **'Il servizio dell\'agente non dà segni di vita da qualche minuto: la richiesta è stata interrotta. Riprova.'**
  String get streamSilent;

  /// No description provided for @streamBroken.
  ///
  /// In it, this message translates to:
  /// **'Collegamento con l\'agente interrotto: {error}'**
  String streamBroken(String error);

  /// No description provided for @streamEnded.
  ///
  /// In it, this message translates to:
  /// **'Il collegamento con l\'agente si è chiuso prima della fine della risposta. Riprova.'**
  String get streamEnded;

  /// No description provided for @serverUnknownError.
  ///
  /// In it, this message translates to:
  /// **'Errore sconosciuto del servizio.'**
  String get serverUnknownError;

  /// No description provided for @serverRejectedRequest.
  ///
  /// In it, this message translates to:
  /// **'Il servizio non ha accettato la richiesta (campo «{field}»). Riprova; se si ripete, segnalalo.'**
  String serverRejectedRequest(String field);

  /// No description provided for @serverErrorStatus.
  ///
  /// In it, this message translates to:
  /// **'Il servizio dell\'agente ha risposto con un errore ({status}).'**
  String serverErrorStatus(int status);

  /// No description provided for @toolDocumentFallback.
  ///
  /// In it, this message translates to:
  /// **'documento'**
  String get toolDocumentFallback;

  /// No description provided for @toolOnPage.
  ///
  /// In it, this message translates to:
  /// **' · pagina {page}'**
  String toolOnPage(String page);

  /// No description provided for @toolCreateDocument.
  ///
  /// In it, this message translates to:
  /// **'Creo \"{title}\"'**
  String toolCreateDocument(String title);

  /// No description provided for @toolReadDocument.
  ///
  /// In it, this message translates to:
  /// **'Leggo il documento'**
  String get toolReadDocument;

  /// No description provided for @toolAddPage.
  ///
  /// In it, this message translates to:
  /// **'Aggiungo una pagina'**
  String get toolAddPage;

  /// No description provided for @toolDeletePage.
  ///
  /// In it, this message translates to:
  /// **'Elimino la pagina{on}'**
  String toolDeletePage(String on);

  /// No description provided for @toolUpdatePage.
  ///
  /// In it, this message translates to:
  /// **'Riscrivo la pagina{on}'**
  String toolUpdatePage(String on);

  /// No description provided for @toolReplaceText.
  ///
  /// In it, this message translates to:
  /// **'Sostituisco \"{find}\"'**
  String toolReplaceText(String find);

  /// No description provided for @toolInsertBlock.
  ///
  /// In it, this message translates to:
  /// **'Inserisco un blocco{on}'**
  String toolInsertBlock(String on);

  /// No description provided for @toolUpdateBlock.
  ///
  /// In it, this message translates to:
  /// **'Modifico il blocco {block}{on}'**
  String toolUpdateBlock(String block, String on);

  /// No description provided for @toolRemoveBlock.
  ///
  /// In it, this message translates to:
  /// **'Rimuovo il blocco {block}{on}'**
  String toolRemoveBlock(String block, String on);

  /// No description provided for @toolAddTable.
  ///
  /// In it, this message translates to:
  /// **'Aggiungo una tabella{on}'**
  String toolAddTable(String on);

  /// No description provided for @toolAddImage.
  ///
  /// In it, this message translates to:
  /// **'Aggiungo un\'immagine{on}'**
  String toolAddImage(String on);

  /// No description provided for @toolChangeLayout.
  ///
  /// In it, this message translates to:
  /// **'Cambio l’impaginazione{on}'**
  String toolChangeLayout(String on);

  /// No description provided for @toolSetTheme.
  ///
  /// In it, this message translates to:
  /// **'Aggiorno il tema'**
  String get toolSetTheme;

  /// No description provided for @toolUpdateMetadata.
  ///
  /// In it, this message translates to:
  /// **'Aggiorno i dati'**
  String get toolUpdateMetadata;

  /// No description provided for @toolExportPdf.
  ///
  /// In it, this message translates to:
  /// **'Esporto il PDF'**
  String get toolExportPdf;

  /// No description provided for @storeNoticeNewer.
  ///
  /// In it, this message translates to:
  /// **'Questi dati sono stati salvati da una versione più recente di PaperAgent: puoi consultarli, ma le modifiche non verranno salvate finché non aggiorni l\'app.'**
  String get storeNoticeNewer;

  /// No description provided for @storeNoticeRestored.
  ///
  /// In it, this message translates to:
  /// **'L’indice del lavoro salvato era danneggiato: ho ripristinato l’ultimo salvataggio valido. L’originale è rimasto nella cartella dati.'**
  String get storeNoticeRestored;

  /// No description provided for @storeNoticeSaveFailed.
  ///
  /// In it, this message translates to:
  /// **'Non riesco a salvare il lavoro sul disco ({reason}). Le modifiche restano aperte: riprovo alla prossima modifica.'**
  String storeNoticeSaveFailed(String reason);

  /// No description provided for @storeNoticeUnreadable.
  ///
  /// In it, this message translates to:
  /// **'Non riesco a leggere una parte del lavoro salvato ({reason}): forse è aperta in un altro programma. Ti mostro quello che ho letto, ma non salvo le modifiche finché non riapri PaperAgent.'**
  String storeNoticeUnreadable(String reason);

  /// No description provided for @storeNoticeRecovered.
  ///
  /// In it, this message translates to:
  /// **'L\'indice del lavoro salvato era illeggibile: ho recuperato {documents} documenti e {chats} conversazioni nel progetto «{project}».'**
  String storeNoticeRecovered(int documents, int chats, String project);

  /// No description provided for @docErrorLastPage.
  ///
  /// In it, this message translates to:
  /// **'Un documento deve avere almeno una pagina.'**
  String get docErrorLastPage;

  /// No description provided for @docErrorNoPage.
  ///
  /// In it, this message translates to:
  /// **'La pagina {page} non esiste (il documento ne ha {count}).'**
  String docErrorNoPage(int page, int count);

  /// No description provided for @docErrorNoBlock.
  ///
  /// In it, this message translates to:
  /// **'Blocco {block} non trovato.'**
  String docErrorNoBlock(String block);

  /// No description provided for @docErrorEmptySearch.
  ///
  /// In it, this message translates to:
  /// **'Il testo da cercare è vuoto.'**
  String get docErrorEmptySearch;

  /// No description provided for @docErrorNoDocument.
  ///
  /// In it, this message translates to:
  /// **'Nessun documento aperto.'**
  String get docErrorNoDocument;

  /// Sidebar update button while the new version downloads
  ///
  /// In it, this message translates to:
  /// **'Scarico l\'aggiornamento… {percent}%'**
  String updateDownloading(int percent);

  /// Sidebar update button once the new version is downloaded: restarts the app into it
  ///
  /// In it, this message translates to:
  /// **'Aggiorna l\'app'**
  String get updateReady;

  /// No description provided for @updateInstalling.
  ///
  /// In it, this message translates to:
  /// **'Riavvio per aggiornare…'**
  String get updateInstalling;

  /// Sidebar update button when the update cannot install by itself
  ///
  /// In it, this message translates to:
  /// **'Aggiornamento da completare'**
  String get updateBlocked;

  /// No description provided for @updateTooltip.
  ///
  /// In it, this message translates to:
  /// **'Versione {version} disponibile'**
  String updateTooltip(String version);

  /// No description provided for @updateDialogTitle.
  ///
  /// In it, this message translates to:
  /// **'Versione {version}'**
  String updateDialogTitle(String version);

  /// No description provided for @updateDialogBody.
  ///
  /// In it, this message translates to:
  /// **'La nuova versione è scaricata e verificata. L\'app si chiude, si aggiorna e si riapre da sola: il lavoro è salvato prima.'**
  String get updateDialogBody;

  /// No description provided for @updateRunningWarning.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{Una conversazione è ancora in corso: il riavvio la interrompe.} other{{count} conversazioni sono ancora in corso: il riavvio le interrompe.}}'**
  String updateRunningWarning(int count);

  /// No description provided for @updateNotes.
  ///
  /// In it, this message translates to:
  /// **'Novità'**
  String get updateNotes;

  /// No description provided for @updateLater.
  ///
  /// In it, this message translates to:
  /// **'Più tardi'**
  String get updateLater;

  /// No description provided for @updateRestart.
  ///
  /// In it, this message translates to:
  /// **'Riavvia e aggiorna'**
  String get updateRestart;

  /// No description provided for @updateRetry.
  ///
  /// In it, this message translates to:
  /// **'Riprova'**
  String get updateRetry;

  /// No description provided for @updateProblemNotWritable.
  ///
  /// In it, this message translates to:
  /// **'L\'app non può aggiornarsi da sola: la cartella {path} non è modificabile. Spostala in una cartella tua e riaprila, o installa la nuova versione a mano.'**
  String updateProblemNotWritable(String path);

  /// macOS: the app runs from the download folder or the disk image
  ///
  /// In it, this message translates to:
  /// **'Sposta l\'app nella cartella Applicazioni e riaprila da lì: così potrà aggiornarsi da sola.'**
  String get updateProblemNotInstalled;

  /// No description provided for @updateInstallFailed.
  ///
  /// In it, this message translates to:
  /// **'L\'ultimo aggiornamento non è andato a buon fine: l\'app è rimasta alla versione precedente. Puoi riprovare; i dettagli sono in {log}.'**
  String updateInstallFailed(String log);

  /// No description provided for @settingsUpdates.
  ///
  /// In it, this message translates to:
  /// **'Aggiornamenti'**
  String get settingsUpdates;

  /// No description provided for @settingsVersion.
  ///
  /// In it, this message translates to:
  /// **'Versione installata'**
  String get settingsVersion;

  /// No description provided for @settingsVersionValue.
  ///
  /// In it, this message translates to:
  /// **'{version} (revisione {build})'**
  String settingsVersionValue(String version, int build);

  /// No description provided for @updateCheckNow.
  ///
  /// In it, this message translates to:
  /// **'Controlla ora'**
  String get updateCheckNow;

  /// No description provided for @updateStatusOff.
  ///
  /// In it, this message translates to:
  /// **'Questa versione non si aggiorna da sola.'**
  String get updateStatusOff;

  /// No description provided for @updateStatusChecking.
  ///
  /// In it, this message translates to:
  /// **'Controllo gli aggiornamenti…'**
  String get updateStatusChecking;

  /// No description provided for @updateStatusUpToDate.
  ///
  /// In it, this message translates to:
  /// **'L\'app è aggiornata: controlla da sola ogni mezz\'ora.'**
  String get updateStatusUpToDate;

  /// No description provided for @updateStatusCheckFailed.
  ///
  /// In it, this message translates to:
  /// **'Non riesco a raggiungere il servizio degli aggiornamenti: riprovo più tardi.'**
  String get updateStatusCheckFailed;

  /// No description provided for @updateStatusReady.
  ///
  /// In it, this message translates to:
  /// **'La versione {version} è pronta: riavvia l\'app per installarla.'**
  String updateStatusReady(String version);

  /// No description provided for @sourceTitle.
  ///
  /// In it, this message translates to:
  /// **'Fonte'**
  String get sourceTitle;

  /// No description provided for @sourcePage.
  ///
  /// In it, this message translates to:
  /// **'{name}, pagina {page}'**
  String sourcePage(String name, int page);

  /// No description provided for @sourcePages.
  ///
  /// In it, this message translates to:
  /// **'{name}, pagine {first}–{last}'**
  String sourcePages(String name, int first, int last);

  /// No description provided for @sourceOpen.
  ///
  /// In it, this message translates to:
  /// **'Apri {reference}'**
  String sourceOpen(String reference);

  /// No description provided for @sourceLoading.
  ///
  /// In it, this message translates to:
  /// **'Apro il documento…'**
  String get sourceLoading;

  /// No description provided for @sourceUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Documento non disponibile'**
  String get sourceUnavailable;

  /// No description provided for @sourceMissingMessage.
  ///
  /// In it, this message translates to:
  /// **'Il documento o la pagina non sono più disponibili in questa conversazione. Se necessario, allega nuovamente il documento.'**
  String get sourceMissingMessage;

  /// No description provided for @sourceConnectionMessage.
  ///
  /// In it, this message translates to:
  /// **'Non riesco ad aprire la fonte. Controlla la connessione e riprova.'**
  String get sourceConnectionMessage;

  /// No description provided for @sourceRetry.
  ///
  /// In it, this message translates to:
  /// **'Riprova'**
  String get sourceRetry;

  /// No description provided for @sourceOriginal.
  ///
  /// In it, this message translates to:
  /// **'Documento originale · sola lettura'**
  String get sourceOriginal;

  /// No description provided for @sourceExtracted.
  ///
  /// In it, this message translates to:
  /// **'Testo estratto · impaginazione originale non riprodotta'**
  String get sourceExtracted;

  /// No description provided for @sourceNoText.
  ///
  /// In it, this message translates to:
  /// **'Questa pagina non contiene testo leggibile.'**
  String get sourceNoText;

  /// No description provided for @sourcePrevious.
  ///
  /// In it, this message translates to:
  /// **'Passaggio precedente'**
  String get sourcePrevious;

  /// No description provided for @sourceNext.
  ///
  /// In it, this message translates to:
  /// **'Passaggio successivo'**
  String get sourceNext;

  /// No description provided for @webLinkUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Impossibile aprire il collegamento. Riprova dal navigatore.'**
  String get webLinkUnavailable;

  /// No description provided for @sourceSection.
  ///
  /// In it, this message translates to:
  /// **'{name}, sezione {page}'**
  String sourceSection(String name, int page);

  /// No description provided for @reviewRunning.
  ///
  /// In it, this message translates to:
  /// **'Verifico italiano e impaginazione…'**
  String get reviewRunning;

  /// No description provided for @reviewUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Verifica non completata. L’esportazione resta sospesa.'**
  String get reviewUnavailable;

  /// No description provided for @reviewClean.
  ///
  /// In it, this message translates to:
  /// **'Controlli automatici completati: nessun rilievo rilevato.'**
  String get reviewClean;

  /// No description provided for @reviewAdvisory.
  ///
  /// In it, this message translates to:
  /// **'Riferimenti da rileggere'**
  String get reviewAdvisory;

  /// No description provided for @reviewRequired.
  ///
  /// In it, this message translates to:
  /// **'Correzioni da verificare prima dell’esportazione'**
  String get reviewRequired;

  /// No description provided for @reviewHelp.
  ///
  /// In it, this message translates to:
  /// **'Correggi nel testo. Conferma soltanto i passaggi che ritieni corretti.'**
  String get reviewHelp;

  /// No description provided for @reviewMetadata.
  ///
  /// In it, this message translates to:
  /// **'Titolo e dati del documento'**
  String get reviewMetadata;

  /// No description provided for @reviewProtected.
  ///
  /// In it, this message translates to:
  /// **'Citazione o dato originale: verificare senza alterarne il senso.'**
  String get reviewProtected;

  /// No description provided for @reviewKeepTerm.
  ///
  /// In it, this message translates to:
  /// **'Mantieni testo'**
  String get reviewKeepTerm;

  /// No description provided for @reviewConfirmed.
  ///
  /// In it, this message translates to:
  /// **'Confermato'**
  String get reviewConfirmed;

  /// No description provided for @pdfPreparedFor.
  ///
  /// In it, this message translates to:
  /// **'Destinatario'**
  String get pdfPreparedFor;

  /// No description provided for @pdfPreparedBy.
  ///
  /// In it, this message translates to:
  /// **'Redatto da'**
  String get pdfPreparedBy;

  /// No description provided for @pdfDate.
  ///
  /// In it, this message translates to:
  /// **'Data'**
  String get pdfDate;

  /// No description provided for @pdfMonthNames.
  ///
  /// In it, this message translates to:
  /// **'gennaio;febbraio;marzo;aprile;maggio;giugno;luglio;agosto;settembre;ottobre;novembre;dicembre'**
  String get pdfMonthNames;

  /// No description provided for @progressStarting.
  ///
  /// In it, this message translates to:
  /// **'Avvio della richiesta'**
  String get progressStarting;

  /// No description provided for @progressFailed.
  ///
  /// In it, this message translates to:
  /// **'Richiesta non completata'**
  String get progressFailed;

  /// No description provided for @progressStopped.
  ///
  /// In it, this message translates to:
  /// **'Richiesta interrotta'**
  String get progressStopped;

  /// No description provided for @progressCompleted.
  ///
  /// In it, this message translates to:
  /// **'Richiesta conclusa'**
  String get progressCompleted;

  /// No description provided for @progressHideSteps.
  ///
  /// In it, this message translates to:
  /// **'Nascondi i passaggi'**
  String get progressHideSteps;

  /// No description provided for @progressShowSteps.
  ///
  /// In it, this message translates to:
  /// **'Mostra i passaggi ({count})'**
  String progressShowSteps(int count);

  /// No description provided for @operationApplied.
  ///
  /// In it, this message translates to:
  /// **'Operazione eseguita'**
  String get operationApplied;

  /// No description provided for @operationFailed.
  ///
  /// In it, this message translates to:
  /// **'Operazione non riuscita'**
  String get operationFailed;

  /// No description provided for @operationNotApplied.
  ///
  /// In it, this message translates to:
  /// **'Operazione non eseguita'**
  String get operationNotApplied;

  /// No description provided for @operationRunning.
  ///
  /// In it, this message translates to:
  /// **'Operazione in corso'**
  String get operationRunning;

  /// No description provided for @agentComparingDocuments.
  ///
  /// In it, this message translates to:
  /// **'Confronto i documenti'**
  String get agentComparingDocuments;

  /// No description provided for @evidenceTitle.
  ///
  /// In it, this message translates to:
  /// **'Fonti e riscontri'**
  String get evidenceTitle;

  /// No description provided for @evidenceSummary.
  ///
  /// In it, this message translates to:
  /// **'{claims, plural, =1{1 affermazione} other{{claims} affermazioni}} · {sources, plural, =1{1 fonte richiamata} other{{sources} fonti richiamate}}'**
  String evidenceSummary(int claims, int sources);

  /// No description provided for @evidenceQualification.
  ///
  /// In it, this message translates to:
  /// **'I collegamenti alle fonti e i passaggi citati sono distinti dalla valutazione giuridica del caso.'**
  String get evidenceQualification;

  /// No description provided for @evidenceNoClaims.
  ///
  /// In it, this message translates to:
  /// **'Nessuna affermazione associata a questo riscontro.'**
  String get evidenceNoClaims;

  /// No description provided for @evidenceUnresolved.
  ///
  /// In it, this message translates to:
  /// **'Collegamento alla fonte incompleto'**
  String get evidenceUnresolved;

  /// No description provided for @evidenceTraceable.
  ///
  /// In it, this message translates to:
  /// **'Passaggio della fonte disponibile'**
  String get evidenceTraceable;

  /// No description provided for @evidenceInference.
  ///
  /// In it, this message translates to:
  /// **'Deduzione da valutare'**
  String get evidenceInference;

  /// No description provided for @evidenceUnsupported.
  ///
  /// In it, this message translates to:
  /// **'Affermazione da correggere'**
  String get evidenceUnsupported;

  /// No description provided for @evidenceUnknown.
  ///
  /// In it, this message translates to:
  /// **'Riscontro non determinato'**
  String get evidenceUnknown;

  /// No description provided for @evidenceNoPassage.
  ///
  /// In it, this message translates to:
  /// **'Nessun passaggio citato per questa affermazione.'**
  String get evidenceNoPassage;

  /// No description provided for @evidenceSemanticPending.
  ///
  /// In it, this message translates to:
  /// **'Il sostegno alla conclusione richiede una verifica distinta.'**
  String get evidenceSemanticPending;

  /// No description provided for @evidenceLegislator.
  ///
  /// In it, this message translates to:
  /// **'Testo normativo'**
  String get evidenceLegislator;

  /// No description provided for @evidenceCourt.
  ///
  /// In it, this message translates to:
  /// **'Voce del giudice'**
  String get evidenceCourt;

  /// No description provided for @evidenceParty.
  ///
  /// In it, this message translates to:
  /// **'Posizione di una parte'**
  String get evidenceParty;

  /// No description provided for @evidenceSource.
  ///
  /// In it, this message translates to:
  /// **'Fonte richiamata'**
  String get evidenceSource;

  /// No description provided for @evidenceVersion.
  ///
  /// In it, this message translates to:
  /// **'Versione al {date}'**
  String evidenceVersion(String date);

  /// No description provided for @evidenceUncertain.
  ///
  /// In it, this message translates to:
  /// **'Trascrizione incerta: confrontare con l’originale.'**
  String get evidenceUncertain;

  /// No description provided for @phaseIdle.
  ///
  /// In it, this message translates to:
  /// **'Pronto'**
  String get phaseIdle;

  /// No description provided for @phaseThinking.
  ///
  /// In it, this message translates to:
  /// **'Elaborazione'**
  String get phaseThinking;

  /// No description provided for @phaseWorking.
  ///
  /// In it, this message translates to:
  /// **'Esecuzione'**
  String get phaseWorking;

  /// No description provided for @phaseWaiting.
  ///
  /// In it, this message translates to:
  /// **'In attesa'**
  String get phaseWaiting;

  /// No description provided for @phaseError.
  ///
  /// In it, this message translates to:
  /// **'Errore'**
  String get phaseError;

  /// No description provided for @eventRequest.
  ///
  /// In it, this message translates to:
  /// **'Richiesta'**
  String get eventRequest;

  /// No description provided for @eventStatus.
  ///
  /// In it, this message translates to:
  /// **'Attività'**
  String get eventStatus;

  /// No description provided for @eventText.
  ///
  /// In it, this message translates to:
  /// **'Risposta'**
  String get eventText;

  /// No description provided for @eventTool.
  ///
  /// In it, this message translates to:
  /// **'Operazione'**
  String get eventTool;

  /// No description provided for @eventResult.
  ///
  /// In it, this message translates to:
  /// **'Risultato'**
  String get eventResult;

  /// No description provided for @eventUi.
  ///
  /// In it, this message translates to:
  /// **'Scheda'**
  String get eventUi;

  /// No description provided for @eventApproval.
  ///
  /// In it, this message translates to:
  /// **'Conferma'**
  String get eventApproval;

  /// No description provided for @eventAttachment.
  ///
  /// In it, this message translates to:
  /// **'Allegato'**
  String get eventAttachment;

  /// No description provided for @eventError.
  ///
  /// In it, this message translates to:
  /// **'Errore'**
  String get eventError;

  /// No description provided for @eventDone.
  ///
  /// In it, this message translates to:
  /// **'Conclusione'**
  String get eventDone;

  /// No description provided for @eventOther.
  ///
  /// In it, this message translates to:
  /// **'Evento'**
  String get eventOther;

  /// No description provided for @failureUnexpected.
  ///
  /// In it, this message translates to:
  /// **'Si è verificato un errore imprevisto. Riprova; se si ripete, copia il registro delle attività per l’assistenza.'**
  String get failureUnexpected;

  /// No description provided for @logCopyDetails.
  ///
  /// In it, this message translates to:
  /// **'Copia i dettagli tecnici'**
  String get logCopyDetails;

  /// No description provided for @logDetailsCopied.
  ///
  /// In it, this message translates to:
  /// **'Dettagli copiati'**
  String get logDetailsCopied;

  /// No description provided for @logDetailsHint.
  ///
  /// In it, this message translates to:
  /// **'Dettagli disponibili per l’assistenza.'**
  String get logDetailsHint;

  /// No description provided for @requestData.
  ///
  /// In it, this message translates to:
  /// **'dati della richiesta'**
  String get requestData;

  /// No description provided for @cardUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Scheda non disponibile. Il contenuto ricevuto non è leggibile.'**
  String get cardUnavailable;

  /// No description provided for @operationFailureHint.
  ///
  /// In it, this message translates to:
  /// **'Operazione non riuscita. I dettagli sono disponibili nel registro delle attività.'**
  String get operationFailureHint;

  /// No description provided for @componentTool.
  ///
  /// In it, this message translates to:
  /// **'Operazione'**
  String get componentTool;

  /// No description provided for @componentPage.
  ///
  /// In it, this message translates to:
  /// **'Pagina'**
  String get componentPage;

  /// No description provided for @componentDiff.
  ///
  /// In it, this message translates to:
  /// **'Confronto delle modifiche'**
  String get componentDiff;

  /// No description provided for @componentDocument.
  ///
  /// In it, this message translates to:
  /// **'Documento'**
  String get componentDocument;

  /// No description provided for @componentOutline.
  ///
  /// In it, this message translates to:
  /// **'Struttura del documento'**
  String get componentOutline;

  /// No description provided for @componentChart.
  ///
  /// In it, this message translates to:
  /// **'Grafico'**
  String get componentChart;

  /// No description provided for @componentExport.
  ///
  /// In it, this message translates to:
  /// **'Esportazione'**
  String get componentExport;

  /// No description provided for @componentApproval.
  ///
  /// In it, this message translates to:
  /// **'Conferma richiesta'**
  String get componentApproval;

  /// No description provided for @componentSummary.
  ///
  /// In it, this message translates to:
  /// **'Riepilogo delle modifiche'**
  String get componentSummary;

  /// No description provided for @componentNorms.
  ///
  /// In it, this message translates to:
  /// **'Riferimenti normativi'**
  String get componentNorms;

  /// No description provided for @componentCase.
  ///
  /// In it, this message translates to:
  /// **'Analisi del fascicolo'**
  String get componentCase;

  /// No description provided for @componentProgress.
  ///
  /// In it, this message translates to:
  /// **'Avanzamento'**
  String get componentProgress;

  /// No description provided for @componentMatrix.
  ///
  /// In it, this message translates to:
  /// **'Confronto documentale'**
  String get componentMatrix;

  /// No description provided for @componentOther.
  ///
  /// In it, this message translates to:
  /// **'Scheda'**
  String get componentOther;

  /// No description provided for @accessTitle.
  ///
  /// In it, this message translates to:
  /// **'Accedi a Daylex'**
  String get accessTitle;

  /// No description provided for @accessHelp.
  ///
  /// In it, this message translates to:
  /// **'Inserisci la chiave ricevuta dal tuo amministratore. Ogni chiave è associata a un solo computer.'**
  String get accessHelp;

  /// No description provided for @accessInvalidKey.
  ///
  /// In it, this message translates to:
  /// **'Inserisci una chiave Daylex completa, con prefisso dlx_.'**
  String get accessInvalidKey;

  /// No description provided for @accessVaultFailed.
  ///
  /// In it, this message translates to:
  /// **'Impossibile aprire l’archivio protetto del computer. Sblocca il portachiavi e riprova.'**
  String get accessVaultFailed;

  /// No description provided for @accessShowKey.
  ///
  /// In it, this message translates to:
  /// **'Mostra chiave'**
  String get accessShowKey;

  /// No description provided for @accessHideKey.
  ///
  /// In it, this message translates to:
  /// **'Nascondi chiave'**
  String get accessHideKey;

  /// No description provided for @accessActivate.
  ///
  /// In it, this message translates to:
  /// **'Attiva su questo computer'**
  String get accessActivate;

  /// No description provided for @accessDisclosure.
  ///
  /// In it, this message translates to:
  /// **'L’amministratore può vedere presenza, sezioni utilizzate, tipo, durata ed esito delle richieste. Se abilitata sul servizio, la supervisione include il testo delle richieste inviate. Bozze, digitazione e allegati non vengono copiati nelle analitiche. La conservazione è limitata dalla configurazione del servizio; i documenti restano salvati sul computer.'**
  String get accessDisclosure;

  /// No description provided for @accessAcknowledge.
  ///
  /// In it, this message translates to:
  /// **'Ho letto l’informativa sulla supervisione'**
  String get accessAcknowledge;

  /// No description provided for @serviceMaintenance.
  ///
  /// In it, this message translates to:
  /// **'Daylex è in manutenzione'**
  String get serviceMaintenance;

  /// No description provided for @serviceMaintenanceHelp.
  ///
  /// In it, this message translates to:
  /// **'Le nuove richieste sono temporaneamente sospese. Il lavoro già salvato resta disponibile sul computer.'**
  String get serviceMaintenanceHelp;

  /// No description provided for @serviceOffline.
  ///
  /// In it, this message translates to:
  /// **'Connessione al servizio non disponibile'**
  String get serviceOffline;

  /// No description provided for @serviceOfflineHelp.
  ///
  /// In it, this message translates to:
  /// **'Non è stato possibile verificare lo stato del servizio. Il lavoro locale resta disponibile; controlla la rete e riprova.'**
  String get serviceOfflineHelp;

  /// No description provided for @serviceDetails.
  ///
  /// In it, this message translates to:
  /// **'Dettagli'**
  String get serviceDetails;

  /// No description provided for @serviceRetry.
  ///
  /// In it, this message translates to:
  /// **'Riprova'**
  String get serviceRetry;

  /// No description provided for @operationUncertain.
  ///
  /// In it, this message translates to:
  /// **'Esito da verificare'**
  String get operationUncertain;

  /// No description provided for @operationVerificationHint.
  ///
  /// In it, this message translates to:
  /// **'La sessione si è interrotta prima di ricevere l’esito. Controlla il documento prima di ripetere l’operazione.'**
  String get operationVerificationHint;

  /// No description provided for @instanceUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Daylex è già aperto oppure la cartella dei dati non è accessibile. Chiudi l’altra finestra e riprova; se il problema persiste, verifica i permessi della cartella.'**
  String get instanceUnavailable;

  /// No description provided for @exitUnsavedTitle.
  ///
  /// In it, this message translates to:
  /// **'Modifiche non salvate'**
  String get exitUnsavedTitle;

  /// No description provided for @exitUnsavedHelp.
  ///
  /// In it, this message translates to:
  /// **'Il salvataggio non è riuscito. Mantieni aperta l’app e riprova dopo aver verificato spazio e permessi del disco. Uscendo perderai le modifiche non salvate.'**
  String get exitUnsavedHelp;

  /// No description provided for @exitKeepOpen.
  ///
  /// In it, this message translates to:
  /// **'Mantieni aperto'**
  String get exitKeepOpen;

  /// No description provided for @exitDiscard.
  ///
  /// In it, this message translates to:
  /// **'Esci senza salvare'**
  String get exitDiscard;

  /// No description provided for @accessKeyHint.
  ///
  /// In it, this message translates to:
  /// **'dlx_…'**
  String get accessKeyHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
