// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appName => 'Valhalla';

  @override
  String get appSubtitle => 'Gestione Server e Agenti Nata per l\'IA';

  @override
  String get navAiChat => 'Chat IA';

  @override
  String get navTerminal => 'Terminale';

  @override
  String get navFiles => 'File SFTP';

  @override
  String get navCommands => 'Comandi';

  @override
  String get navSettings => 'Impostazioni';

  @override
  String get serverConnected => 'Connesso';

  @override
  String get serverOnline => 'Online';

  @override
  String get serverOffline => 'Offline';

  @override
  String get latencyMs => 'ms';

  @override
  String get reconnect => 'Riconnetti';

  @override
  String get disconnect => 'Disconnetti';

  @override
  String get quickDisconnect => 'Disconnessione rapida';

  @override
  String get newSession => 'Nuova sessione';

  @override
  String get historySessions => 'Cronologia sessioni';

  @override
  String get switchAgent => 'Cambia agente';

  @override
  String get agentClaudeCode => 'Claude CodeX';

  @override
  String get agentCodex => 'OpenAI Codex';

  @override
  String get agentOpenCode => 'OpenCode ACP';

  @override
  String get agentGemini => 'Gemini CLI';

  @override
  String get activeAgent => 'Agente attivo';

  @override
  String get inputPromptHint =>
      'Chiedi all\'Agente di diagnosticare, eseguire strumenti o scrivere comandi... (Invio per inviare)';

  @override
  String get thinking => 'Processo di riflessione';

  @override
  String get executionPlan => 'Piano di esecuzione';

  @override
  String get toolCall => 'Chiamata strumento';

  @override
  String get toolStatusPending => 'In attesa';

  @override
  String get toolStatusRunning => 'In esecuzione...';

  @override
  String get toolStatusCompleted => 'Completato';

  @override
  String get toolStatusFailed => 'Non riuscito';

  @override
  String get permissionRequired => 'Autorizzazione richiesta';

  @override
  String get permissionDescription =>
      'L\'Agente vuole eseguire questo comando sul server:';

  @override
  String get permissionReject => 'Rifiuta';

  @override
  String get permissionAllowOnce => 'Consenti una volta';

  @override
  String get permissionAllowAlways => 'Consenti sempre';

  @override
  String get quickTroubleshootCpu => 'Risolvi CPU elevata';

  @override
  String get quickDockerHealth => 'Controllo integrità Docker';

  @override
  String get quickCleanCache => 'Pulisci cache di sistema';

  @override
  String get quickNginxLogs => 'Controlla i log di errore Nginx';

  @override
  String get terminalNewTab => 'Nuova scheda';

  @override
  String get terminalCloseTab => 'Chiudi scheda';

  @override
  String get terminalClear => 'Cancella';

  @override
  String get terminalQuickCmds => 'Tavolozza dei comandi';

  @override
  String get terminalPaste => 'Incolla';

  @override
  String get sftpCurrentPath => 'Percorso corrente';

  @override
  String get sftpUpload => 'Carica';

  @override
  String get sftpNewFolder => 'Nuova cartella';

  @override
  String get sftpNewFile => 'Nuovo file';

  @override
  String get sftpRefresh => 'Aggiorna';

  @override
  String get sftpSearchHint => 'Cerca file o cartelle...';

  @override
  String get sftpEmpty => 'La directory è vuota';

  @override
  String get sftpFileName => 'Nome';

  @override
  String get sftpFileSize => 'Dimensione';

  @override
  String get sftpFilePerm => 'Permessi';

  @override
  String get sftpFileModified => 'Modificato';

  @override
  String get cmdCategoryDocker => 'STACK CONTAINER DOCKER';

  @override
  String get cmdCategorySystem => 'MANUTENZIONE SISTEMA';

  @override
  String get cmdCategoryNetwork => 'RETE & PORTE';

  @override
  String get cmdExecute => 'Esegui';

  @override
  String get cmdDangerous => 'Comando pericoloso';

  @override
  String get cmdDangerousWarning =>
      'Questa operazione è irreversibile e potrebbe causare interruzioni del servizio. Sei sicuro di voler procedere?';

  @override
  String get cmdParamRequired => 'Inserimento parametri richiesto';

  @override
  String get cmdConfirm => 'Conferma ed esegui';

  @override
  String get cmdCancel => 'Annulla';

  @override
  String get settingsAppearance => 'Aspetto e temi';

  @override
  String get settingsThemeMode => 'Modalità tema';

  @override
  String get themeSystem => 'Segui il sistema';

  @override
  String get themeSystemDesc => 'Adattivo automatico';

  @override
  String get themeLight => 'Modalità chiara';

  @override
  String get themeLightDesc => 'Carta ad alta luminosità';

  @override
  String get themeDark => 'Geek Scuro';

  @override
  String get themeDarkDesc => 'Antracite profondo';

  @override
  String get themeAmoled => 'Nero AMOLED';

  @override
  String get themeAmoledDesc => 'Nero assoluto 0x000000';

  @override
  String get settingsAccentColor => 'Colore accento del tema';

  @override
  String get accentCyberEmerald => 'Cyber Emerald';

  @override
  String get accentTechBlue => 'Tech Blue';

  @override
  String get accentElectricViolet => 'Electric Violet';

  @override
  String get accentCrimsonRed => 'Crimson Red';

  @override
  String get accentAmberOrange => 'Amber Orange';

  @override
  String get settingsLanguage => 'Lingua e impostazioni internazionali';

  @override
  String get langZh => '简体中文 (Simplified Chinese)';

  @override
  String get langEn => 'English (US)';

  @override
  String get langZhHant => '繁體中文 (Traditional Chinese)';

  @override
  String get langJa => '日本語';

  @override
  String get langKo => '한국어';

  @override
  String get langDe => 'Deutsch';

  @override
  String get langFr => 'Français';

  @override
  String get langEs => 'Español';

  @override
  String get langPt => 'Português';

  @override
  String get langRu => 'Русский';

  @override
  String get langAr => 'العربية';

  @override
  String get langHi => 'हिन्दी';

  @override
  String get langId => 'Bahasa Indonesia';

  @override
  String get langIt => 'Italiano';

  @override
  String get langTr => 'Türkçe';

  @override
  String get langVi => 'Tiếng Việt';

  @override
  String get langTh => 'ไทย';

  @override
  String get settingsAiOps => 'AI Ops e motore';

  @override
  String get settingsSecurity => 'Connessione e sicurezza';

  @override
  String get settingsKnownHosts => 'Chiavi host note';

  @override
  String get settingsClearStorage => 'Reimposta credenziali';

  @override
  String get settingsResetDefault => 'Ripristina impostazioni predefinite';

  @override
  String get settingsTerminalUseTmux => 'Sessioni persistenti (tmux)';

  @override
  String get settingsTerminalUseTmuxSubtitle =>
      'Esegui sessioni di terminale all\'interno di tmux sul server remoto';

  @override
  String get settingsTerminalUseTmuxDescription =>
      'Mantiene l\'output del terminale dopo una disconnessione. Richiede tmux sul server remoto. Le modifiche si applicano alle nuove schede del terminale aperte.';

  @override
  String get settingsTerminalFontSize => 'Dimensione carattere terminale';

  @override
  String get settingsTerminalFontSizeSubtitle =>
      'Regola la dimensione del carattere del terminale SSH e CLI';

  @override
  String get version => 'Versione';

  @override
  String get addServer => 'Aggiungi server';

  @override
  String get editServer => 'Modifica server';

  @override
  String get serverName => 'Nome server';

  @override
  String get serverHost => 'Host / IP';

  @override
  String get serverPort => 'Porta';

  @override
  String get serverUsername => 'Nome utente';

  @override
  String get serverAuthType => 'Tipo di autenticazione';

  @override
  String get serverPassword => 'Password';

  @override
  String get serverPrivateKey => 'Chiave privata';

  @override
  String get serverSave => 'Salva server';

  @override
  String get serverDelete => 'Elimina server';

  @override
  String get fileEditor => 'Editor di file';

  @override
  String get fileEditorSave => 'Salva modifiche';

  @override
  String get fileSavedSuccess => 'File salvato con successo';

  @override
  String get addCommand => 'Nuovo comando';

  @override
  String get commandTitle => 'Titolo comando';

  @override
  String get commandContent => 'Stringa di comando';

  @override
  String get commandCategory => 'Categoria';

  @override
  String get commandDescription => 'Descrizione';

  @override
  String get save => 'Salva';

  @override
  String get delete => 'Elimina';

  @override
  String get cancel => 'Annulla';

  @override
  String get confirm => 'Conferma';

  @override
  String get cmdExecutionChannel => 'Canale di esecuzione';

  @override
  String get cmdChannelTerminal => 'Diretto al terminale SSH';

  @override
  String get cmdChannelTerminalDesc =>
      'Il comando viene digitato direttamente nella sessione attiva del terminale';

  @override
  String get cmdChannelBackground => 'Esegui in sessione in background';

  @override
  String get cmdChannelBackgroundDesc =>
      'Esegue tramite shell di login SSH e cattura l\'output';

  @override
  String get cmdInjectedToTerminal => 'Comando inviato al terminale';

  @override
  String get cmdExecutionCompleted => 'Esecuzione completata';

  @override
  String get cmdExecutionFailed => 'Esecuzione non riuscita';

  @override
  String get cmdExecutingRemote => 'Esecuzione comando remoto...';

  @override
  String get cmdClose => 'Chiudi';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navDocker => 'Docker';

  @override
  String get navSystem => 'Sistema';

  @override
  String get navMore => 'Altro';

  @override
  String get dashboardTitle => 'Dashboard del server';

  @override
  String get metricsCpu => 'Utilizzo CPU';

  @override
  String get metricsMemory => 'Utilizzo memoria';

  @override
  String get metricsLoadAvg => 'Carico medio';

  @override
  String get metricsUptime => 'Tempo di attività del sistema';

  @override
  String get metricsRootDisk => 'Utilizzo disco root';

  @override
  String get quickActions => 'Navigazione rapida';

  @override
  String get activeServerStatus => 'Stato del server attivo';

  @override
  String get noServerSelected =>
      'Nessun server attualmente selezionato. Seleziona prima un server.';

  @override
  String get serverDisconnected => 'Disconnesso';

  @override
  String get serverConnecting => 'Connessione in corso...';

  @override
  String get connectNow => 'Connetti ora';

  @override
  String get serverSpecs => 'Info e specifiche server';

  @override
  String get dockerTitle => 'Container Docker';

  @override
  String get dockerSearchHint => 'Cerca container per nome o immagine...';

  @override
  String get dockerFilterAll => 'Tutti';

  @override
  String get dockerFilterRunning => 'In esecuzione';

  @override
  String get dockerFilterExited => 'Terminati';

  @override
  String get dockerFilterPaused => 'In pausa';

  @override
  String get dockerActionStart => 'Avvia';

  @override
  String get dockerActionStop => 'Arresta';

  @override
  String get dockerActionRestart => 'Riavvia';

  @override
  String get dockerActionPause => 'Metti in pausa';

  @override
  String get dockerActionUnpause => 'Riprendi';

  @override
  String get dockerActionRm => 'Rimuovi';

  @override
  String get dockerActionLogs => 'Log';

  @override
  String get dockerActionInspect => 'Ispeziona';

  @override
  String get dockerLogsTitle => 'Log del container';

  @override
  String get dockerInspectTitle => 'Ispezione container';

  @override
  String get dockerNoContainers => 'Nessun container trovato sul server';

  @override
  String get dockerEmptyRunning => 'Nessun container in esecuzione';

  @override
  String get dockerPorts => 'Porte';

  @override
  String get dockerCreated => 'Creato';

  @override
  String get dockerImage => 'Immagine';

  @override
  String get systemTitle => 'Processi e servizi';

  @override
  String get tabProcesses => 'Processi';

  @override
  String get tabServices => 'Servizi Systemd';

  @override
  String get processSearchHint => 'Cerca per nome processo o PID...';

  @override
  String get processPid => 'PID';

  @override
  String get processCpu => '% CPU';

  @override
  String get processMem => '% MEM';

  @override
  String get processStat => 'Stato';

  @override
  String get processCommand => 'Comando';

  @override
  String get processTerminate => 'Termina (SIGTERM)';

  @override
  String get processForceKill => 'Uccisione forzata (SIGKILL)';

  @override
  String get processKillForbidden =>
      'Rifiuto di terminare l\'init di sistema (PID <= 1)';

  @override
  String get serviceSearchHint => 'Cerca servizi per nome...';

  @override
  String get serviceName => 'Servizio';

  @override
  String get serviceDescription => 'Descrizione';

  @override
  String get serviceStatus => 'Stato';

  @override
  String get serviceStartup => 'Avvio';

  @override
  String get serviceActionStart => 'Avvia';

  @override
  String get serviceActionStop => 'Arresta';

  @override
  String get serviceActionRestart => 'Riavvia';

  @override
  String get serviceActionReload => 'Ricarica';

  @override
  String get serviceActionEnable => 'Abilita';

  @override
  String get serviceActionDisable => 'Disabilita';

  @override
  String get serviceNoServices => 'Nessun servizio systemd trovato';

  @override
  String get riskDangerTitle => 'Conferma operazione ad alto rischio';

  @override
  String get riskWarningTitle => 'Conferma avviso operazione';

  @override
  String get riskSafeTitle => 'Conferma azione';

  @override
  String get riskIrreversibleWarning =>
      'Questa operazione è classificata ad ALTO RISCHIO e non può essere annullata. Potrebbe causare perdita di dati o interruzione del servizio.';

  @override
  String get riskWarningDescription =>
      'Questa operazione potrebbe influire sui servizi attivi o riavviare processi. Procedi con cautela.';

  @override
  String get riskCommandPreview => 'Anteprima comando';

  @override
  String get riskConfirmButton => 'Conferma e procedi';

  @override
  String get riskCancelButton => 'Annulla';

  @override
  String get stateLoading => 'Caricamento dati remoti...';

  @override
  String get stateOffline => 'Il server è offline';

  @override
  String get stateOfflineDesc =>
      'Stabilisci una connessione SSH attiva per gestire le risorse e trasmettere le metriche.';

  @override
  String get stateError => 'Si è verificato un errore';

  @override
  String get stateRetry => 'Riprova';

  @override
  String get stateEmpty => 'Nessun elemento trovato';

  @override
  String get inspectorTitle => 'Ispettore';

  @override
  String get inspectorClose => 'Chiudi';

  @override
  String get inspectorDetails => 'Dettagli ispezione';

  @override
  String get selectServerTitle => 'Seleziona server di destinazione';

  @override
  String get sshDisconnectedSuccess => 'Connessione SSH disconnessa';

  @override
  String get trustHostFingerprintTitle =>
      'Fidarsi dell\'impronta digitale dell\'host?';

  @override
  String get trustAndConnect => 'Fidati e connetti';

  @override
  String get reject => 'Rifiuta';

  @override
  String get confirmDeleteServerTitle => 'Elimina server';

  @override
  String get noServersFound => 'Nessun server ancora configurato';

  @override
  String get agentNotReadyError =>
      'L\'agente selezionato non è pronto. Verifica l\'ambiente e la configurazione.';

  @override
  String get sshDisconnectedError =>
      'SSH è disconnesso. Connettiti a un server prima di utilizzare AI Ops.';

  @override
  String get noAgentAvailable => 'Nessun agente disponibile';

  @override
  String get noAgentAvailablePrompt =>
      'Nessun Agente attivo disponibile. Configura o prepara prima un agente.';

  @override
  String get noAgentAvailableHint =>
      'Seleziona o configura un agente disponibile per chattare...';

  @override
  String get manageAgents => 'Gestisci agenti';

  @override
  String get noReadyAgentsTitle => 'Nessun agente pronto';

  @override
  String get noReadyAgentsDesc =>
      'Nessun agente su questo server ha superato i controlli dell\'ambiente.';

  @override
  String get agentStatusReady => 'Pronto';

  @override
  String get agentStatusChecking => 'Verifica in corso...';

  @override
  String get agentStatusCliMissing => 'Installazione non rilevata';

  @override
  String get agentStatusAcpMissing => 'Componente ACP non rilevato';

  @override
  String get agentStatusNotLoggedIn => 'Accesso non effettuato';

  @override
  String get agentStatusError => 'Errore';

  @override
  String get agentStatusUnknown => 'Sconosciuto';

  @override
  String get agentActionInstall => 'Installa';

  @override
  String get agentActionLogin => 'Accedi';

  @override
  String get agentActionRefresh => 'Controlla stato';

  @override
  String get noConfiguredAgents => 'Nessun agente configurato su questo server';

  @override
  String get agentManagementTitle => 'Gestione agenti';

  @override
  String get settingsAgentManagement => 'Gestione agenti';

  @override
  String get settingsAgentManagementSubtitle =>
      'Configura, rileva e gestisci gli Agenti ACP per il server corrente';

  @override
  String get addAgentButton => 'Aggiungi agente';

  @override
  String get noServerSelectedForAgents =>
      'Nessun server selezionato. Seleziona prima un server dall\'interfaccia principale.';

  @override
  String get sshDisconnectedAgentWarning =>
      'SSH è disconnesso. Rilevamento, installazione e accesso sono disabilitati finché non viene stabilita la connessione.';

  @override
  String get noAgentsConfiguredTitle => 'Nessun agente configurato';

  @override
  String get noAgentsConfiguredDesc =>
      'Aggiungi Claude Code, Codex, OpenCode, AGY o agenti ACP personalizzati per abilitare AI Ops su questo server.';

  @override
  String get agentPresetLabel => 'Predefinito';

  @override
  String get agentPresetClaudeCode => 'Claude Code';

  @override
  String get agentPresetCodex => 'OpenAI Codex';

  @override
  String get agentPresetOpenCode => 'OpenCode ACP';

  @override
  String get agentPresetAgy => 'Antigravity AGY';

  @override
  String get agentPresetCustom => 'Personalizzato';

  @override
  String get agentNameLabel => 'Nome agente';

  @override
  String get agentNameHint => 'es. Production Codex';

  @override
  String get agentDescriptionLabel => 'Descrizione';

  @override
  String get agentDescriptionHint => 'Breve descrizione dell\'agente';

  @override
  String get agentCliCommandLabel => 'Comando di verifica CLI';

  @override
  String get agentCliCommandHint => 'es. claude, codex';

  @override
  String get agentAcpCommandLabel => 'Comando di avvio ACP';

  @override
  String get agentAcpCommandHint => 'es. codex-acp --stdio';

  @override
  String get agentInstallCommandLabel =>
      'Comando di installazione (facoltativo)';

  @override
  String get agentInstallCommandHint => 'es. npm install -g @openai/codex';

  @override
  String get agentLoginCheckCommandLabel =>
      'Comando di controllo accesso (facoltativo)';

  @override
  String get agentLoginCheckCommandHint => 'es. codex --version';

  @override
  String get agentLoginCommandLabel => 'Comando di accesso (facoltativo)';

  @override
  String get agentLoginCommandHint => 'es. codex login';

  @override
  String get agentSaveButton => 'Salva e rileva';

  @override
  String get agentCliRequired => 'Il comando di verifica CLI è obbligatorio';

  @override
  String get agentAcpRequired => 'Il comando di avvio ACP è obbligatorio';

  @override
  String get agentNameRequired => 'Il nome dell\'agente è obbligatorio';

  @override
  String get confirmInstallAgentTitle => 'Conferma installazione agente';

  @override
  String get confirmLoginAgentTitle => 'Conferma accesso agente';

  @override
  String get agentCommandRiskWarning =>
      'Questo comando verrà eseguito direttamente sul server remoto con i privilegi dell\'utente corrente. Potrebbe installare pacchetti o modificare gli ambienti di sistema.';

  @override
  String get targetServerLabel => 'Server di destinazione';

  @override
  String get commandPreviewLabel => 'Anteprima comando';

  @override
  String get executeButton => 'Esegui';

  @override
  String get deleteAgentTitle => 'Elimina agente';

  @override
  String get deleteAgentConfirm => 'Elimina';

  @override
  String get agentStatusCheckingDesc =>
      'Rilevamento dell\'ambiente sul server remoto in corso...';

  @override
  String get agentStatusInstalling =>
      'Installazione delle dipendenze sul server in corso...';

  @override
  String get agentStatusLoggingIn =>
      'Esecuzione del comando di accesso sul server in corso...';

  @override
  String get agentNoLoginCheckProvided =>
      'Nessun comando di controllo accesso specificato';

  @override
  String get agentInstallPrompt =>
      'Installazione non rilevata. Eseguire l\'installazione automatica ora?';

  @override
  String get agentActionAutoInstall => 'Installazione automatica';

  @override
  String get agentLoginPrompt => 'Accesso non effettuato. Accedere ora?';

  @override
  String get agentActionExecuteLogin => 'Accedi ora';

  @override
  String get agentNeedsInstallOrReadyPrompt =>
      'Gli agenti su questo server non sono ancora installati o pronti. Gestisci e completa la configurazione dell\'ambiente.';

  @override
  String get agentNeedsInstallOrReadyHint =>
      'Installa e prepara un agente per iniziare a chattare...';

  @override
  String get agentAcpInstallPrompt =>
      'Componente ACP non rilevato. Eseguire l\'installazione automatica ora?';

  @override
  String get agentInstallCommandAcpLabel =>
      'Comando di installazione ACP (facoltativo)';

  @override
  String get agentInstallCommandAcpHint =>
      'es. npm install -g @zed-industries/codex-acp';

  @override
  String get agentNoInstallCommand =>
      'Nessun comando di installazione configurato per questo agente';

  @override
  String get agentInstallLogTitle => 'Output di installazione';

  @override
  String get agentInstallLogEmpty => 'In attesa dell\'output di installazione…';

  @override
  String get agentInstallLogTruncated =>
      'Output troppo lungo; vengono mostrate le righe più recenti';

  @override
  String get agentAcpOptional => 'Facoltativo; lasciare vuoto solo per CLI';

  @override
  String get acpStreaming => 'Streaming ACP in corso...';

  @override
  String get aiOpsAgentTitle => 'Agente Valhalla AI Ops';

  @override
  String get aiOpsEmptySubtitle => 'Connesso tramite ACP stdio sul canale SSH';

  @override
  String get agentAuthRequiredTitle => 'Autenticazione richiesta';

  @override
  String get agentAuthRequiredDesc =>
      'L\'agente richiede l\'autenticazione prima di poter elaborare la tua richiesta.';

  @override
  String get agentAuthMethodLabel => 'Metodo di autenticazione';

  @override
  String get agentAuthNoMethodsNotice =>
      'L\'agente non ha fornito un metodo di accesso. Controlla la sua configurazione sul server.';

  @override
  String get agentAuthProceedButton => 'Accedi';

  @override
  String get agentAuthCancelButton => 'Annulla';

  @override
  String get agentAuthRetryHint =>
      'Dopo aver effettuato l\'accesso, invia nuovamente il messaggio.';

  @override
  String get agentAuthRequiredError =>
      'Autenticazione richiesta. Effettua l\'accesso per continuare.';

  @override
  String get agentLoginTerminalTitle => 'Terminale di accesso interattivo';

  @override
  String get agentLoginTerminalSubtitle =>
      'Completa i passaggi di accesso nel terminale sottostante. Segui qualsiasi URL o codice mostrato.';

  @override
  String get agentLoginTerminalRunning =>
      'Il comando di accesso è in esecuzione nel terminale...';

  @override
  String get agentLoginTerminalDisconnected =>
      'Connessione SSH persa. La sessione di accesso è stata interrotta.';

  @override
  String get agentLoginTerminalRetry => 'Riconnetti terminale';

  @override
  String get agentLoginTerminalFinish => 'Termina e verifica';

  @override
  String get agentLoginTerminalClose => 'Chiudi';

  @override
  String get agentLoginTerminalNoTtyHint =>
      'Se l\'agente richiede di incollare un codice, premi a lungo il terminale per incollare o usa il tasto INCOLLA.';

  @override
  String get agentLoginTerminalUrlLabel => 'URL di accesso rilevato';

  @override
  String get agentLoginTerminalUrlCopy => 'Copia link';

  @override
  String get agentLoginTerminalUrlCopied =>
      'URL di accesso copiato negli appunti';

  @override
  String get agentLoginTerminalCopyAll => 'Copia tutto l\'output';

  @override
  String get agentLoginTerminalCopiedAll =>
      'Output del terminale copiato negli appunti';

  @override
  String get sshStatusReconnected => 'Connessione ripristinata';

  @override
  String get sshStatusDisconnectedRetrying =>
      'Connessione persa, nuovo tentativo in corso';

  @override
  String get sshStatusDisconnectedManual => 'Disconnesso';

  @override
  String get sshStatusHostKeyChanged =>
      'Chiave host modificata — connessione rifiutata';

  @override
  String get sshKeepAliveNotificationTitle =>
      'Valhalla mantiene attive le tue sessioni';

  @override
  String get terminalTmuxMissingNotice =>
      'tmux non trovato — le sessioni non sopravviveranno a una disconnessione';

  @override
  String get terminalTmuxSessionRestored => 'Sessione terminale ripristinata';

  @override
  String get moshSectionTitle => 'Mosh';

  @override
  String get moshEnable =>
      'Abilita Mosh — un terminale in roaming che sopravvive alle disconnessioni e ai cambi di IP';

  @override
  String get moshServerPathLabel => 'Percorso mosh-server';

  @override
  String get moshPortRangeLabel => 'Intervallo porte UDP';

  @override
  String get moshNewSession => 'Nuova sessione Mosh';

  @override
  String get moshNotInstalled =>
      'mosh-server non è stato trovato sul server remoto. Installalo con: sudo apt install mosh (Debian/Ubuntu) o sudo dnf install mosh (Fedora/RHEL).';

  @override
  String moshBootstrapFailed(String detail) {
    return 'Impossibile avviare la sessione Mosh: $detail';
  }

  @override
  String get moshUdpTimeout =>
      'Connessione Mosh scaduta — verifica che il traffico UDP non sia bloccato da un firewall.';

  @override
  String get moshSessionTag => 'mosh';

  @override
  String get acpSessionRestored => 'Sessione agente ripristinata';

  @override
  String get acpSessionRestartNotice =>
      'Sessione agente riavviata — contesto precedente non disponibile';

  @override
  String get terminalTmuxInstallDialogTitle =>
      'Installare tmux sul server remoto?';

  @override
  String get terminalTmuxInstallDialogMessage =>
      'tmux è necessario per preservare le sessioni del terminale in caso di disconnessione. Vuoi installarlo ora?';

  @override
  String get terminalTmuxInstallCommandLabel => 'Comando da eseguire:';

  @override
  String get terminalTmuxInstallUnsupported =>
      'Nessun gestore di pacchetti supportato rilevato sul server remoto. Installa tmux manualmente.';

  @override
  String get terminalTmuxInstallFailed =>
      'Installazione di tmux non riuscita. Verifica i permessi del server e la rete.';

  @override
  String get terminalTmuxInstallDisconnected =>
      'Connessione SSH persa. Riconnettiti per installare tmux.';

  @override
  String get terminalTmuxInstallInstalling =>
      'Installazione di tmux in corso...';

  @override
  String get terminalTmuxInstallConfirm => 'Installa tmux';

  @override
  String get terminalTmuxInstallSkip => 'Salta (Usa shell semplice)';

  @override
  String get sftpDownload => 'Scarica';

  @override
  String get sftpOpen => 'Apri';

  @override
  String get sftpUploadFailed =>
      'Caricamento non riuscito. Controlla i permessi e riprova.';

  @override
  String get sftpDownloadFailed => 'Download non riuscito';

  @override
  String get sftpOpenUnsupported =>
      'Questo formato di file non può essere aperto.';

  @override
  String get sftpReadFailed =>
      'Impossibile leggere il file. Controlla i permessi e riprova.';

  @override
  String get sftpTransferFailed => 'Operazione sul file non riuscita. Riprova.';

  @override
  String get sftpDownloadSuccess => 'Scaricato con successo';

  @override
  String get sftpUploading => 'Caricamento in corso...';

  @override
  String get sftpDownloading => 'Download in corso...';

  @override
  String get sftpUpDirectory => 'Passa alla cartella superiore';

  @override
  String get sftpShowHiddenFiles => 'Mostra file nascosti';

  @override
  String get sftpHideHiddenFiles => 'Nascondi file nascosti';

  @override
  String get sftpHiddenPreferenceSaveFailed =>
      'Impossibile salvare la preferenza per i file nascosti';

  @override
  String get sftpSymlink => 'Collegamento simbolico';

  @override
  String get sftpLinkTargetUnavailable =>
      'La destinazione del collegamento simbolico non è valida o non è disponibile';

  @override
  String get sftpLinkTargetPermissionDenied =>
      'Permesso negato per la destinazione del collegamento simbolico';

  @override
  String get settingsAutoConnect => 'Connessione automatica all\'avvio';

  @override
  String get settingsAutoConnectFixed => 'SSH predefinito fisso';

  @override
  String get settingsAutoConnectFixedDesc =>
      'Connettiti sempre al server selezionato di seguito';

  @override
  String get settingsAutoConnectLast => 'Ricorda l\'ultima connessione';

  @override
  String get settingsAutoConnectLastDesc =>
      'Connettiti al server a cui ti sei connesso con successo l\'ultima volta';

  @override
  String get settingsAutoConnectPickServer => 'Server';

  @override
  String get settingsAutoConnectNoServer => 'Nessun server ancora selezionato';

  @override
  String get sftpSort => 'Ordina';

  @override
  String get sftpSortName => 'Nome';

  @override
  String get sftpSortSize => 'Dimensione';

  @override
  String get sftpSortDate => 'Data di modifica';

  @override
  String get sftpSortAscending => 'Crescente';

  @override
  String get sftpSortDescending => 'Decrescente';

  @override
  String get themeQuickSwitch => 'Tema';

  @override
  String get transferList => 'Trasferimenti';

  @override
  String get transferEmpty => 'Nessun trasferimento al momento';

  @override
  String get transferUpload => 'Carica';

  @override
  String get transferDownload => 'Scarica';

  @override
  String get transferStatusQueued => 'In coda';

  @override
  String get transferStatusRunning => 'In trasferimento';

  @override
  String get transferStatusPaused => 'In pausa';

  @override
  String get transferStatusCompleted => 'Completato';

  @override
  String get transferStatusFailed => 'Non riuscito';

  @override
  String get transferStatusCanceled => 'Annullato';

  @override
  String get transferPause => 'Pausa';

  @override
  String get transferResume => 'Riprendi';

  @override
  String get transferCancel => 'Annulla';

  @override
  String get transferRemove => 'Rimuovi';

  @override
  String get transferClearFinished => 'Cancella completati';

  @override
  String get transferSizeUnknown => 'Dimensione sconosciuta';

  @override
  String get transferFailedUpload => 'Caricamento non riuscito';

  @override
  String get transferFailedDownload => 'Download non riuscito';

  @override
  String get stopGeneration => 'Interrompi';

  @override
  String get chatServerBindingRequired =>
      'Questa sessione non è associata a un server. Associala al server corrente per continuare.';

  @override
  String get chatSessionUnboundNotice =>
      'Questa sessione non è associata ad alcun server.';

  @override
  String get bindServerAction => 'Associa server';

  @override
  String get bindServerDialogTitle => 'Associa sessione al server';

  @override
  String get bindServerConfirmAction => 'Conferma associazione';

  @override
  String get chatSessionIdentityMismatch =>
      'Il server o l\'agente corrente non corrisponde all\'identità associata a questa sessione. Passa al server e all\'agente corrispondenti per continuare.';

  @override
  String get deleteSessionTitle => 'Elimina sessione';

  @override
  String get deleteSessionConfirmAction => 'Elimina';

  @override
  String get shareAgentSessionsTitle => 'Condividi sessioni agente';

  @override
  String get shareAgentSessionsSubtitle =>
      'Condividi sessioni tra diversi agenti su questo server';

  @override
  String get shareAgentSessionsEnabled =>
      'Condivisione sessioni agente abilitata';

  @override
  String get shareAgentSessionsDisabled =>
      'Condivisione sessioni agente disabilitata';

  @override
  String get agentCliStatusInstalled => 'CLI: Installato';

  @override
  String get agentCliStatusMissing => 'CLI: Mancante';

  @override
  String get agentCliStatusChecking => 'CLI: Verifica in corso...';

  @override
  String get agentCliStatusUnknown => 'CLI: Sconosciuto';

  @override
  String get agentCliStatusError => 'CLI: Errore';

  @override
  String get agentAcpStatusReady => 'ACP: Pronto';

  @override
  String get agentAcpStatusMissing => 'ACP: Mancante';

  @override
  String get agentAcpStatusChecking => 'ACP: Verifica in corso...';

  @override
  String get agentAcpStatusPendingCli => 'ACP: In attesa di CLI';

  @override
  String get agentAcpStatusUnknown => 'ACP: Sconosciuto';

  @override
  String get agentAcpStatusError => 'ACP: Errore';

  @override
  String get agentAcpStatusNa => 'ACP: N/D';

  @override
  String get agentAuthStatusAuthenticated =>
      'Autenticazione: Accesso effettuato';

  @override
  String get agentAuthStatusUnauthenticated =>
      'Autenticazione: Accesso non effettuato';

  @override
  String get agentAuthStatusUnknown => 'Autenticazione: Sconosciuto';

  @override
  String get downloadNotificationsUnavailable =>
      'Le notifiche di download del sistema non sono disponibili. I download continuano in background.';

  @override
  String get downloadOpenFailed => 'Impossibile aprire il file scaricato.';

  @override
  String get dockerActionPending =>
      'Un\'azione è già in corso per questo container';

  @override
  String get dockerNoLogs => '(Nessun log)';

  @override
  String get serverReboot => 'Riavvia';

  @override
  String get serverRebootDialogTitle => 'Conferma riavvio server';

  @override
  String get serverRebootDialogMessage =>
      'Sei sicuro di voler riavviare questo server? Tutte le connessioni attive e i servizi in background verranno interrotti.';

  @override
  String get serverRebootConfirmButton => 'Riavvia ora';

  @override
  String get serverRebootPasswordTitle => 'Password Sudo richiesta';

  @override
  String get serverRebootPasswordMessage =>
      'I privilegi di root sono richiesti per riavviare il server. Inserisci la password sudo (usata una volta, non salvata):';

  @override
  String get serverRebootPasswordHint => 'Password Sudo';

  @override
  String get serverRebootSubmitting => 'Invio comando di riavvio...';

  @override
  String get serverRebootAccepted =>
      'Comando di riavvio accettato; completamento non ancora verificato. Riconnettiti quando il server sarà di nuovo online.';

  @override
  String get serverRebootVerified =>
      'Il riavvio del server è stato verificato; il sistema è di nuovo online.';

  @override
  String get serverRebootUnknown =>
      'Il risultato del riavvio è incerto. Il comando è stato inviato, ma il completamento non è stato confermato. Controlla la connessione manualmente.';

  @override
  String get serverRebootReconnect => 'Riconnetti';

  @override
  String get serverRebootServerChanged =>
      'Server di destinazione modificato, riavvio annullato';

  @override
  String get navCliChat => 'Chat CLI';

  @override
  String get cliChatTitle => 'Sessioni CLI';

  @override
  String get cliChatSubtitle => 'Sessioni Agente CLI native sul server remoto';

  @override
  String get cliSelectAgent => 'Seleziona agente';

  @override
  String get cliNoAgentsConfigured =>
      'Nessun agente aggiunto per questo server';

  @override
  String get cliAgentNeedsSetup =>
      'Ambiente agente mancante o accesso non effettuato';

  @override
  String get cliManageAgentsGuide => 'Configura in Gestione agenti';

  @override
  String get cliNewDraft => 'Nuova bozza';

  @override
  String get cliNewDraftTooltip =>
      'Crea una bozza vuota (la sessione viene creata al primo messaggio)';

  @override
  String get cliDeleteSessionTitle => 'Elimina cronologia sessione CLI remota';

  @override
  String get cliDeleteSessionMessage =>
      'Questo eliminerà definitivamente la cronologia della sessione CLI sul server remoto. Sei sicuro di voler procedere?';

  @override
  String get cliDeleteConfirmButton => 'Elimina sessione';

  @override
  String get cliCannotDeleteTooltip =>
      'Eliminazione sessione remota non supportata o disabilitata';

  @override
  String get cliSessionsHeader => 'Sessioni';

  @override
  String get cliNoSessions => 'Nessuna sessione CLI trovata';

  @override
  String get cliFilterCwdHint => 'Filtra per percorso CWD...';

  @override
  String get cliFilterCwdAction => 'Filtra';

  @override
  String get cliClearCwdAction => 'Cancella';

  @override
  String get cliLoadMoreSessions => 'Carica altre sessioni';

  @override
  String get cliRefreshSessions => 'Aggiorna';

  @override
  String get cliClaudeReadOnlyNotice =>
      'La cronologia di Claude è di sola lettura. Continua la conversazione nel terminale reale.';

  @override
  String get cliContinueInTerminal => 'Continua nel terminale';

  @override
  String get cliOpenTerminal => 'Apri terminale';

  @override
  String get cliCloseTerminal => 'Chiudi terminale';

  @override
  String get cliTerminalRunning => 'Terminale CLI interattivo';

  @override
  String get cliAgyTerminalOnlyNotice =>
      'Questo agente non supporta la sincronizzazione strutturata della cronologia. Utilizza il terminale CLI nativo per l\'interazione e la selezione della sessione.';

  @override
  String get cliInstallSdkTitle =>
      'Installa l\'SDK ufficiale della cronologia Claude';

  @override
  String get cliInstallSdkMessage =>
      'L\'SDK ufficiale della cronologia Claude Code è mancante sul server remoto. Desideri installarlo ora?';

  @override
  String get cliInstallSdkAction => 'Installa SDK ufficiale';

  @override
  String get cliApprovalsTitle => 'Approvazioni in sospeso';

  @override
  String get cliApprovalDetails => 'Dettagli';

  @override
  String get cliApprovalAllow => 'Consenti';

  @override
  String get cliApprovalDecline => 'Rifiuta';

  @override
  String get cliInputHint => 'Scrivi un messaggio all\'agente CLI...';

  @override
  String get cliSend => 'Invia';

  @override
  String get cliStop => 'Interrompi';

  @override
  String get cliBusy => 'Operazione in corso, attendere...';

  @override
  String get cliDisconnected => 'SSH non è connesso';

  @override
  String get cliServerChanged => 'Server di destinazione modificato';

  @override
  String get cliTurnFailed => 'Esecuzione turno CLI non riuscita';

  @override
  String get cliUseTerminal =>
      'Richiesta interattiva necessaria, apri il terminale per continuare';

  @override
  String get cliDeleteFailed => 'Impossibile eliminare la sessione remota';

  @override
  String get cliDeleteUnsupported =>
      'L\'eliminazione delle sessioni remote non è supportata da questa CLI';

  @override
  String get cliOperationFailed => 'Operazione CLI non riuscita';

  @override
  String get cliHistorySdkMissing =>
      'L\'SDK ufficiale della cronologia manca sul server';

  @override
  String get cliHistoryRuntimeMissing =>
      'La cronologia di Claude richiede Node.js/npm sul server. Installa Node.js manualmente; puoi comunque utilizzare la vera CLI nel terminale.';

  @override
  String get cliLoginRequired =>
      'Accesso all\'agente richiesto. Effettua l\'accesso tramite Gestione agenti.';

  @override
  String get cliNotInstalled =>
      'CLI dell\'agente non installata. Installala tramite Gestione agenti.';

  @override
  String get cliVersionUnsupported =>
      'Versione della CLI dell\'agente non supportata. Aggiorna o reinstalla tramite Gestione agenti.';

  @override
  String get settingsNavigation => 'Navigazione';

  @override
  String get settingsNavigationDesc =>
      'Configura la pagina di avvio predefinita e la barra di navigazione inferiore';

  @override
  String get settingsStartupPage => 'Pagina di avvio';

  @override
  String get settingsStartupPageDesc =>
      'Pagina visualizzata all\'apertura dell\'app';

  @override
  String get settingsBottomNav => 'Barra di navigazione inferiore';

  @override
  String get settingsBottomNavDesc =>
      'Seleziona le sezioni da visualizzare nella barra inferiore mobile (supporta da 0 a 9 elementi)';

  @override
  String get settingsResetSuccess =>
      'Tutte le impostazioni sono state ripristinate ai valori predefiniti';

  @override
  String get metricsTrendSubtitle => 'Ultimi ~3 minuti (fino a 60 campioni)';

  @override
  String get metricsCurrent => 'Attuale';

  @override
  String get metricsPeak => 'Picco';

  @override
  String get metricsValley => 'Minimo';

  @override
  String get metricsTrendWaiting => 'Raccolta dati metriche in corso...';

  @override
  String get metricsTrendStopped =>
      'Raccolta dati interrotta (SSH disconnesso)';

  @override
  String get dockerActionTerminal => 'Terminale Exec';

  @override
  String get dockerTerminalTitle => 'Terminale container';

  @override
  String get dockerTerminalNotRunning => 'Il container non è in esecuzione';

  @override
  String get setDefaultAgent => 'Imposta come predefinito';

  @override
  String get defaultBadge => 'Predefinito';

  @override
  String get isDefaultAgent => 'Agente predefinito';

  @override
  String get setAsDefaultAgent =>
      'Imposta come agente predefinito per questo server';

  @override
  String get agentGroupBasic => 'Informazioni di base';

  @override
  String get agentGroupCommands => 'Comandi';

  @override
  String get agentGroupAuth => 'Installazione e autenticazione';

  @override
  String get agentPresetTitle => 'Modello predefinito';

  @override
  String get resourceProcessList => 'Processi';

  @override
  String get resourceDiskScanning =>
      'Scansione directory root in corso, potrebbe richiedere alcuni secondi...';

  @override
  String get resourceDiskScanPartial =>
      'Alcune directory non sono state scansionate a causa di autorizzazioni o timeout';

  @override
  String get resourceDiskDirectories => 'Utilizzo directory di primo livello';

  @override
  String get resourceSortCpu => 'Ordina per CPU';

  @override
  String get resourceSortMemory => 'Ordina per memoria';

  @override
  String get resourceRss => 'Memoria RSS';

  @override
  String get resourceUsed => 'Usato';

  @override
  String get resourceAvailable => 'Disponibile';

  @override
  String get resourceTotal => 'Totale';

  @override
  String get settingsBottomNavOrderTitle =>
      'Elementi selezionati (Trascina per riordinare)';

  @override
  String get langSystem => 'Segui il sistema';

  @override
  String get serverFieldRequired => 'Obbligatorio';

  @override
  String get serverPortInvalid => 'La porta deve essere compresa tra 1 e 65535';

  @override
  String get serverTestReachability => 'Verifica raggiungibilità';

  @override
  String get serverSaveFailedGeneric =>
      'Impossibile salvare il server. Verifica la configurazione e riprova.';

  @override
  String get serverViewPrivateKey => 'Visualizza chiave privata';

  @override
  String get serverHidePrivateKey => 'Nascondi chiave privata';

  @override
  String get dockerBashFallbackNotice =>
      'Bash non disponibile nel container, passaggio a Sh';

  @override
  String get dockerShellLabel => 'Shell';

  @override
  String get dockerShellBash => 'Bash';

  @override
  String get dockerShellSh => 'Sh';

  @override
  String get cliDraftWorkingDirLabel => 'Directory di lavoro';

  @override
  String get cliDefaultWorkingDir => 'Predefinita (/)';

  @override
  String get cliPickWorkingDirTitle => 'Seleziona directory di lavoro';

  @override
  String get cliClearWorkingDir => 'Ripristina impostazione predefinita';

  @override
  String get cliBrowseWorkingDir => 'Sfoglia';

  @override
  String get cliSelectCurrentDir => 'Seleziona questa directory';

  @override
  String get cliNavigateUp => 'Vai su';

  @override
  String get chatSessionsTooltip => 'Sessioni';

  @override
  String get hardwareSpecsTitle => 'Hardware e sistema';

  @override
  String get hardwareCpu => 'CPU';

  @override
  String get hardwareMemory => 'Memoria';

  @override
  String get hardwareDisk => 'Disco root';

  @override
  String get hardwareDistribution => 'SO';

  @override
  String get hardwareKernel => 'Kernel';

  @override
  String get hardwareLoading => 'Caricamento specifiche hardware...';

  @override
  String get hardwareUnavailable => 'Specifiche hardware non disponibili';

  @override
  String get hardwareUnknown => 'Sconosciuto';

  @override
  String get systemInfoTitle => 'Informazioni di sistema';

  @override
  String get systemInfoTapHint => 'Tocca per visualizzare l\'ASCII art';

  @override
  String get systemInfoHost => 'Host';

  @override
  String get serverShutdown => 'Spegni';

  @override
  String get serverShutdownDialogTitle => 'Conferma spegnimento server';

  @override
  String get serverShutdownDialogMessage =>
      'Sei sicuro di voler spegnere questo server? Il sistema verrà spento completamente e non sarà accessibile da remoto finché non verrà acceso manualmente.';

  @override
  String get serverShutdownConfirmButton => 'Spegni ora';

  @override
  String get serverShutdownSubmitting => 'Invio comando di spegnimento...';

  @override
  String get serverShutdownAccepted =>
      'Comando di spegnimento accettato; completamento dello spegnimento non verificato.';

  @override
  String get serverShutdownUnknown =>
      'Risultato dello spegnimento sconosciuto: il comando potrebbe essere stato inviato ma non può essere confermato. Controlla manualmente; non verrà ritentato automaticamente.';

  @override
  String get serverShutdownPasswordTitle =>
      'Password Sudo richiesta per lo spegnimento';

  @override
  String get serverShutdownPasswordMessage =>
      'I privilegi di root sono richiesti per spegnere il server. Inserisci la password sudo (usata una volta, non salvata):';

  @override
  String get serverShutdownPasswordHint => 'Password Sudo';

  @override
  String get serverShutdownServerChanged =>
      'Server di destinazione modificato, spegnimento annullato';

  @override
  String get metricsNetwork => 'Velocità di rete';

  @override
  String get networkModalTitle => 'Dettagli interfacce di rete';

  @override
  String get networkDownloadRate => 'Download (RX)';

  @override
  String get networkUploadRate => 'Upload (TX)';

  @override
  String get networkTotalRx => 'Totale RX';

  @override
  String get networkTotalTx => 'Totale TX';

  @override
  String get networkPrimary => 'Route predefinita';

  @override
  String get networkRatesEmpty => 'Nessuna interfaccia di rete attiva rilevata';

  @override
  String get networkWaitingSecondSample => 'In attesa del secondo campione';

  @override
  String get networkUnavailable => 'Non disponibile';

  @override
  String get networkNoDefaultInterface => 'Nessuna route predefinita';

  @override
  String get selectThemeModeTitle => 'Seleziona modalità tema';

  @override
  String get selectLanguageTitle => 'Seleziona lingua';

  @override
  String get selectStartupPageTitle => 'Seleziona pagina di avvio';

  @override
  String get selectAutoConnectModeTitle =>
      'Seleziona modalità connessione automatica';

  @override
  String get accentColorDialogTitle => 'Personalizza colori accento';

  @override
  String get accentColorLightMode => 'Modalità chiara';

  @override
  String get accentColorDarkMode => 'Modalità scura';

  @override
  String get accentColorAmoledMode => 'AMOLED (Geek)';

  @override
  String get accentColorPresets => 'Predefiniti';

  @override
  String get accentColorHsvPicker => 'Ruota dei colori';

  @override
  String get accentColorHexCode => 'Codice colore esadecimale';

  @override
  String get accentColorPreview => 'Anteprima';

  @override
  String get accentColorSampleButton => 'Pulsante di esempio';

  @override
  String get accentColorInvalidHex =>
      'Formato esadecimale non valido (es. #10B981)';

  @override
  String get settingsDashboardQuickActions => 'Azioni rapide dashboard';

  @override
  String get settingsDashboardQuickActionsDesc =>
      'Configura le scorciatoie mostrate nella dashboard. La cancellazione nasconderà la sezione delle azioni rapide.';

  @override
  String get settingsDashboardQuickActionsEmpty =>
      'Azioni rapide nascoste (nessuna scorciatoia selezionata)';

  @override
  String get settingsDashboardQuickActionsOrderTitle =>
      'Trascina per riordinare le scorciatoie';

  @override
  String get settingsDashboardQuickActionsCandidates =>
      'Seleziona scorciatoie visibili';

  @override
  String get terminalCopySelection => 'Copia';

  @override
  String get terminalSelectionCopied => 'Selezione copiata negli appunti';

  @override
  String get editAgent => 'Modifica agente';

  @override
  String get agentExecutionTarget => 'Ambiente di esecuzione';

  @override
  String get agentExecutionHost => 'Sistema host';

  @override
  String get agentExecutionDocker => 'Container Docker';

  @override
  String get agentContainerBinding => 'Modalità associazione container';

  @override
  String get agentContainerBindingId => 'Per ID container';

  @override
  String get agentContainerBindingName => 'Per nome container';

  @override
  String get agentContainerReference => 'Container di destinazione';

  @override
  String get agentContainerReferenceHint =>
      'Seleziona o inserisci ID o nome del container';

  @override
  String get agentContainerRequired =>
      'Il container di destinazione è richiesto per l\'esecuzione di Docker';

  @override
  String get agentLoadingContainers =>
      'Interrogazione dei container sul server...';

  @override
  String get agentNoContainersFound =>
      'Nessun container trovato su questo server';

  @override
  String get agentContainerUser =>
      'Utente di esecuzione del container (facoltativo)';

  @override
  String get agentContainerUserHint => 'es. dev';

  @override
  String get agentContainerUserHelper =>
      'Lascia vuoto per utilizzare l\'utente predefinito dell\'immagine; es. dev; supporta user, UID, user:group, UID:GID';

  @override
  String get agentContainerUserSelect => 'Seleziona utente container';

  @override
  String get agentContainerUsersLoading => 'Caricamento utenti...';

  @override
  String get agentContainerUsersEmpty => 'Nessun utente passwd trovato';

  @override
  String get agentViewDiagnosticLog => 'Visualizza log di diagnostica';

  @override
  String get agentDiagnosticLogCopied =>
      'Log di diagnostica copiato negli appunti';

  @override
  String get agentDiagnosticLogCopy => 'Copia';

  @override
  String get agentDiagnosticLogClose => 'Chiudi';

  @override
  String get settingsCliHistoryPageSize => 'Dimensione pagina cronologia CLI';

  @override
  String get settingsCliHistoryPageSizeDesc =>
      'Numero di messaggi precedenti caricati per pagina durante lo scorrimento verso l\'alto (5-100)';

  @override
  String get settingsCliHistoryPageSizeTitle =>
      'Seleziona dimensione pagina cronologia CLI';

  @override
  String get cliLoadingOlderMessages => 'Caricamento messaggi precedenti...';

  @override
  String get chatLoadOlderMessages => 'Carica messaggi precedenti';

  @override
  String get chatCommandsTooltip => 'Comandi';

  @override
  String get chatAttachTooltip => 'Allega file';

  @override
  String get chatAttachImage => 'Allega immagine locale';

  @override
  String get chatAttachLocalText => 'Allega file di testo locale';

  @override
  String get chatAttachRemoteText => 'Allega file di testo remoto';

  @override
  String get chatAttachRemotePathTitle => 'Allega file di testo remoto';

  @override
  String get chatAttachRemotePathHint => '/percorso/del/file.txt';

  @override
  String get chatAttachTooLarge => 'Il file supera il limite di dimensione';

  @override
  String get chatUsageAndDiagnostics => 'Utilizzo e diagnostica';

  @override
  String get chatWorkingDirTooltip => 'Directory di lavoro bozza';

  @override
  String get chatAttachFailed => 'Impossibile allegare il file';

  @override
  String get chatInvalidRemotePath =>
      'Percorso file remoto non valido (deve iniziare con /)';

  @override
  String get chatRemoteReadFailed => 'Impossibile leggere il file remoto';

  @override
  String get chatInvalidDirPath =>
      'Percorso directory non valido (deve iniziare con /)';

  @override
  String get chatNoSubdirectories => 'Nessuna sottodirectory';

  @override
  String get chatUsageTitle => 'Utilizzo token e costi';

  @override
  String get chatUsageUsed => 'Token utilizzati';

  @override
  String get chatUsageSize => 'Dimensione contesto';

  @override
  String get chatUsageCost => 'Costo';

  @override
  String get chatDiagnosticsTitle => 'Log diagnostico';

  @override
  String get chatNoDiagnostics => 'Nessun log diagnostico disponibile';

  @override
  String get deleteSessionLocalOnlyNotice =>
      'Questo rimuove solo il record locale in Valhalla e non eliminerà la cronologia della sessione dell\'agente nativo sul server.';

  @override
  String get chatSearchSessionsHint => 'Cerca sessioni...';

  @override
  String get chatLoadMoreSessions => 'Carica altre sessioni';

  @override
  String get chatLoadingMoreSessions => 'Caricamento di altre sessioni...';

  @override
  String get chatExportSession => 'Esporta sessione (Markdown)';

  @override
  String get chatExportSuccess => 'Sessione esportata con successo';

  @override
  String get chatExportFailed => 'Impossibile esportare la sessione';

  @override
  String get chatRemoteSessions => 'Sessioni remote';

  @override
  String get chatRemoteSessionsTitle => 'Sessioni agente remoto';

  @override
  String get chatRemoteSessionsDesc =>
      'Visualizza e importa la cronologia delle sessioni native dall\'agente remoto';

  @override
  String get chatRemoteSessionsEmpty => 'Nessuna sessione remota trovata';

  @override
  String get chatRemoteImporting =>
      'Importazione cronologia sessione remota...';

  @override
  String get chatRemoteImportFailed =>
      'Impossibile importare la sessione remota';

  @override
  String get chatStatusInterrupted => 'Interrotto';

  @override
  String get chatStatusFailed => 'Non riuscito';

  @override
  String get chatStatusAwaitingAuth => 'In attesa di autenticazione ACP';

  @override
  String get chatShowFullOutput => 'Mostra output completo';

  @override
  String get chatShowLessOutput => 'Mostra meno';

  @override
  String get chatToolLocations => 'Percorsi interessati';

  @override
  String cmdParamPlaceholder(String param) {
    return 'Inserisci valore per $param';
  }

  @override
  String processTerminateSuccess(Object pid) {
    return 'Processo $pid terminato';
  }

  @override
  String serviceActionSuccess(Object action, Object service) {
    return 'Azione $action su $service completata con successo';
  }

  @override
  String riskPatternMatched(Object pattern) {
    return 'Regola attivata: $pattern';
  }

  @override
  String stateExitCode(Object code) {
    return 'Codice di uscita: $code';
  }

  @override
  String sshConnectedSuccess(Object server) {
    return 'Connessione riuscita a $server tramite SSH';
  }

  @override
  String sshConnectionFailed(Object error) {
    return 'Connessione SSH non riuscita: $error';
  }

  @override
  String trustHostFingerprintMessage(
    Object fingerprint,
    Object host,
    Object type,
  ) {
    return 'Connessione a $host ($type) per la prima volta.\n\nImpronta digitale SHA-256:\n$fingerprint\n\nFidarsi di questa impronta digitale e connettersi?';
  }

  @override
  String enterPasswordTitle(Object server) {
    return 'Inserisci password per $server';
  }

  @override
  String confirmDeleteServerMessage(Object name) {
    return 'Sei sicuro di voler eliminare il server \'$name\'? Questa azione non può essere annullata.';
  }

  @override
  String deleteAgentMessage(Object name) {
    return 'Sei sicuro di voler eliminare l\'Agente \'$name\'? Questo rimuove la sua configurazione e lo stato di runtime su questo server senza influire sulle sessioni di chat cronologiche o sulle credenziali SSH.';
  }

  @override
  String agentLastChecked(Object time) {
    return 'Ultimo controllo: $time';
  }

  @override
  String agentAuthPickerTitle(Object agent) {
    return 'Scegli come accedere a $agent';
  }

  @override
  String sshStatusReconnecting(Object n) {
    return 'Riconnessione… (tentativo $n)';
  }

  @override
  String sshKeepAliveNotificationBody(Object n) {
    return '$n sessione/i attiva/e';
  }

  @override
  String bindServerConfirmMessage(Object serverName) {
    return 'Associare questa sessione al server \"$serverName\"? Una volta associata, questa sessione sarà collegata a questo server.';
  }

  @override
  String deleteSessionConfirmMessage(Object title) {
    return 'Sei sicuro di voler eliminare la sessione \"$title\"? Questa azione non può essere annullata.';
  }

  @override
  String dockerActionSuccess(Object action, Object name) {
    return 'Azione $action sul container $name completata con successo';
  }

  @override
  String dockerActionFailed(Object error) {
    return 'Azione non riuscita: $error';
  }

  @override
  String serverRebootTarget(Object address, Object name) {
    return 'Server di destinazione: $name ($address)';
  }

  @override
  String serverRebootRunningTerminals(Object count) {
    return 'Sessioni terminale: $count';
  }

  @override
  String serverRebootRunningAgents(Object count) {
    return 'Sessioni agente: $count';
  }

  @override
  String serverRebootRunningTransfers(Object count) {
    return 'Trasferimenti attivi: $count';
  }

  @override
  String serverRebootFailed(Object error) {
    return 'Riavvio non riuscito: $error';
  }

  @override
  String cliDeleteFailedWithDetail(Object detail) {
    return 'Impossibile eliminare la sessione remota: $detail';
  }

  @override
  String metricsTrendTitle(Object metric) {
    return 'Tendenza $metric';
  }

  @override
  String metricsThresholdWarning(Object value) {
    return 'Avviso: $value';
  }

  @override
  String metricsThresholdDanger(Object value) {
    return 'Pericolo: $value';
  }

  @override
  String metricsHistoryPoints(Object count) {
    return '$count punti dati';
  }

  @override
  String resourceUsageTitle(Object metric) {
    return 'Utilizzo risorse $metric';
  }

  @override
  String serverPortReachable(Object port) {
    return 'Porta TCP $port raggiungibile';
  }

  @override
  String serverConnectionFailed(Object error) {
    return 'Connessione non riuscita: $error';
  }

  @override
  String serverSaveFailed(Object error) {
    return 'Impossibile salvare il server: $error';
  }

  @override
  String hardwareCpuCores(Object cores) {
    return '$cores Core';
  }

  @override
  String serverShutdownFailed(Object error) {
    return 'Spegnimento non riuscito: $error';
  }

  @override
  String networkInterface(Object name) {
    return 'Interfaccia: $name';
  }

  @override
  String agentContainersLoadFailed(Object error) {
    return 'Impossibile caricare i container: $error';
  }

  @override
  String agentContainerUsersFailed(Object error) {
    return 'Impossibile caricare gli utenti del container: $error';
  }

  @override
  String agentDiagnosticLogTitle(Object name) {
    return 'Log di diagnostica - $name';
  }

  @override
  String get agentDockerDetectionFailed =>
      'Rilevamento Docker/container non riuscito';

  @override
  String get chatCopiedAllMessages => 'Tutti i messaggi copiati';

  @override
  String get chatCopyAllMessages => 'Copia tutti i messaggi';

  @override
  String get cliModelAtCapacity =>
      'Il modello selezionato ha raggiunto la capacità massima. Prova un altro modello.';

  @override
  String get chatLaunchBlankDraft => 'Bozza vuota';

  @override
  String get chatLaunchFixedSession => 'Sessione fissa';

  @override
  String get chatLaunchRememberLast => 'Ricorda ultima sessione';

  @override
  String get chatPermissionAskEveryTime => 'Chiedi ogni volta';

  @override
  String get chatPermissionAutoAllowAll => 'Consenti tutto automaticamente';

  @override
  String get chatPermissionAutoAllowAllConfirmMessage =>
      'L\'agente eseguirà tutte le operazioni senza chiedere. Continuare?';

  @override
  String get chatPermissionAutoAllowAllConfirmTitle =>
      'Consentire tutte le operazioni?';

  @override
  String get chatPermissionAutoAllowSafe =>
      'Consenti automaticamente operazioni sicure';

  @override
  String get chatRunSettingsDefault => 'Predefinito';

  @override
  String get chatRunSettingsInteractiveCli => 'CLI interattiva';

  @override
  String get chatRunSettingsModel => 'Modello';

  @override
  String get chatRunSettingsPermissions => 'Permessi';

  @override
  String get chatRunSettingsReasoning => 'Livello di ragionamento';

  @override
  String get chatRunSettingsTitle => 'Impostazioni di esecuzione';

  @override
  String get cliActionInsertCommand => 'Inserisci comando';

  @override
  String get cliActionInsertFile => 'Inserisci file';

  @override
  String get cliActionInsertWorkdir => 'Inserisci directory di lavoro';

  @override
  String get cliComposerInsertAction => 'Inserisci';

  @override
  String cliOperationFailedWithDetail(String detail) {
    return 'Operazione CLI non riuscita: $detail';
  }

  @override
  String get cliSelectCommandTitle => 'Seleziona comando';

  @override
  String get defaultAgentTitle => 'Agente predefinito';

  @override
  String get insertSkills => 'Inserisci competenze';

  @override
  String get isDefaultSession => 'Sessione predefinita';

  @override
  String get sessionLaunchMode => 'Modalità di avvio sessione';

  @override
  String get setAsDefaultSession => 'Imposta come sessione predefinita';

  @override
  String get navNas => 'Media NAS';

  @override
  String get nasAddExcludePath => 'Aggiungi percorso escluso';

  @override
  String get nasAddIncludePath => 'Aggiungi percorso di scansione';

  @override
  String get nasCancelScan => 'Annulla scansione';

  @override
  String get nasClearSearch => 'Cancella ricerca';

  @override
  String get nasConfigDialogTitle => 'Impostazioni libreria multimediale';

  @override
  String get nasConfigure => 'Configura';

  @override
  String get nasConfigureScanDirs => 'Configura cartelle di scansione';

  @override
  String get nasCreatePlaylist => 'Crea playlist';

  @override
  String get nasEmptyConfigDesc =>
      'Aggiungi almeno una cartella per iniziare a costruire la tua libreria multimediale.';

  @override
  String get nasEmptyConfigTitle => 'Nessuna cartella di scansione configurata';

  @override
  String get nasExcludePaths => 'Cartelle escluse';

  @override
  String get nasExcludedBadge => 'Escluso';

  @override
  String get nasFilterImages => 'Immagini';

  @override
  String get nasFilterVideos => 'Video';

  @override
  String get nasIncludePaths => 'Cartelle di scansione';

  @override
  String nasItemCount(Object value) {
    return '$value elementi';
  }

  @override
  String nasLastScan(Object value) {
    return 'Ultima scansione: $value';
  }

  @override
  String get nasLibrarySettings => 'Impostazioni libreria';

  @override
  String nasMediaOpening(Object value) {
    return 'Apertura di $value…';
  }

  @override
  String get nasMiniPlayer => 'Mini player';

  @override
  String get nasNoExcludePaths => 'Nessuna cartella esclusa';

  @override
  String get nasNoFavorites => 'Nessun preferito al momento';

  @override
  String get nasNoIncludePaths => 'Nessuna cartella di scansione';

  @override
  String get nasNoIndexDesc =>
      'Configura le cartelle ed esegui una scansione per indicizzare i tuoi contenuti multimediali.';

  @override
  String get nasNoIndexTitle => 'La libreria multimediale è vuota';

  @override
  String get nasNoPlaylists => 'Nessuna playlist al momento';

  @override
  String get nasNoSearchResults => 'Nessun file multimediale corrispondente';

  @override
  String get nasNotScanned => 'Non ancora scansionato';

  @override
  String get nasNowPlaying => 'In riproduzione';

  @override
  String get nasOpenMethodPrompt => 'Come desideri aprire questo file?';

  @override
  String get nasOpenPolicyAsk => 'Chiedi ogni volta';

  @override
  String get nasOpenPolicyExternal => 'Apri con un\'altra app';

  @override
  String get nasOpenPolicyInApp => 'Apri nell\'app';

  @override
  String get nasOpeningPolicy => 'Metodo di apertura predefinito';

  @override
  String get nasPlaylistName => 'Nome playlist';

  @override
  String get nasQuickStats => 'Panoramica della libreria';

  @override
  String get nasScan => 'Scansiona ora';

  @override
  String get nasScanCancelled => 'Scansione annullata';

  @override
  String nasScanFailed(Object value) {
    return 'Scansione non riuscita: $value';
  }

  @override
  String get nasScanning => 'Scansione in corso…';

  @override
  String get nasScopeBadge => 'Ambito scansione';

  @override
  String get nasSearchHint => 'Cerca file multimediali';

  @override
  String get nasStatMusic => 'Musica';

  @override
  String get nasStatPhotos => 'Foto';

  @override
  String get nasStatTotal => 'Totale';

  @override
  String get nasStatVideos => 'Video';

  @override
  String get nasTabFavorites => 'Preferiti';

  @override
  String get nasTabFolders => 'Cartelle';

  @override
  String get nasTabHome => 'Home';

  @override
  String get nasTabMusic => 'Musica';

  @override
  String get nasTabPhotos => 'Foto';

  @override
  String get nasTabPlaylists => 'Playlist';

  @override
  String get nasTabVideos => 'Video';

  @override
  String get nasSources => 'Sorgenti multimediali';

  @override
  String get nasAddSource => 'Aggiungi sorgente multimediale';

  @override
  String get nasEditSource => 'Modifica sorgente multimediale';

  @override
  String get nasRemoveSource => 'Rimuovi sorgente multimediale';

  @override
  String nasRemoveSourceConfirm(Object name) {
    return 'Sei sicuro di voler rimuovere la sorgente multimediale \'$name\'? Questo rimuove la sua configurazione senza eliminare i file remoti.';
  }

  @override
  String get nasNoSources => 'Nessuna sorgente multimediale configurata';

  @override
  String get nasNoSourcesDesc =>
      'Aggiungi SFTP, SMB, WebDAV, Jellyfin o Emby per iniziare a sfogliare i contenuti multimediali.';

  @override
  String get nasSourceType => 'Tipo di sorgente';

  @override
  String get nasSourceName => 'Nome sorgente';

  @override
  String get nasProbe => 'Verifica connessione';

  @override
  String get nasProbeSuccess => 'Connessione riuscita';

  @override
  String get nasProbeFailed => 'Verifica connessione non riuscita';

  @override
  String get nasEndpoint => 'Endpoint / URL';

  @override
  String get nasRootPath => 'Percorso root';

  @override
  String get nasUsername => 'Nome utente';

  @override
  String get nasPassword => 'Password';

  @override
  String get nasDomain => 'Dominio (facoltativo)';

  @override
  String get nasAuthenticate => 'Autentica';

  @override
  String get nasAuthSuccess => 'Autenticazione riuscita';

  @override
  String get nasAuthFailed => 'Autenticazione non riuscita';

  @override
  String get nasTabDownloads => 'Download';

  @override
  String get nasNoDownloads => 'Nessuna attività di download';

  @override
  String get nasDownloadQueued => 'In coda';

  @override
  String get nasDownloadDownloading => 'Download in corso';

  @override
  String get nasDownloadCompleted => 'Completato';

  @override
  String get nasDownloadCancelled => 'Annullato';

  @override
  String get nasDownloadFailed => 'Download non riuscito';

  @override
  String get nasRetryDownload => 'Riprova';

  @override
  String get nasCancelDownload => 'Annulla';

  @override
  String get nasOpenDownloadedFile => 'Apri file';

  @override
  String get nasQueue => 'Coda di riproduzione';

  @override
  String get nasNoQueue => 'La coda è vuota';

  @override
  String get nasSpeed => 'Velocità';

  @override
  String get nasQuality => 'Qualità';

  @override
  String get nasAudioTrack => 'Traccia audio';

  @override
  String get nasSubtitleTrack => 'Sottotitoli';

  @override
  String get nasRepeatOff => 'Ripetizione disattivata';

  @override
  String get nasRepeatAll => 'Ripeti tutto';

  @override
  String get nasRepeatOne => 'Ripeti uno';

  @override
  String get nasShuffle => 'Riproduzione casuale';

  @override
  String get nasCast => 'Cast';

  @override
  String get nasCastUnavailable =>
      'Nessun dispositivo di trasmissione disponibile';

  @override
  String get nasSlideshow => 'Presentazione';

  @override
  String get nasByFolder => 'Cartelle';

  @override
  String get nasByArtist => 'Artisti';

  @override
  String get nasByAlbum => 'Album';

  @override
  String get nasAllTracks => 'Tutte le tracce';

  @override
  String get nasPlayAll => 'Riproduci tutto';

  @override
  String get nasPreviousPage => 'Precedente';

  @override
  String get nasNextPage => 'Successivo';

  @override
  String get nasClearScope => 'Torna a tutti';

  @override
  String get nasRenamePlaylist => 'Rinomina playlist';

  @override
  String get nasRemoveFromPlaylist => 'Rimuovi dalla playlist';

  @override
  String get nasMoveUp => 'Sposta su';

  @override
  String get nasMoveDown => 'Sposta giù';

  @override
  String get nasSshServer => 'Server SSH';

  @override
  String get nasSelectSshServer => 'Seleziona server SSH salvato';

  @override
  String get nasQualityOriginal => 'Originale';

  @override
  String get nasQualityAuto => 'Automatico';

  @override
  String get nasQuality4Mbps => '4 Mbps';

  @override
  String get nasQuality10Mbps => '10 Mbps';

  @override
  String get nasQuality20Mbps => '20 Mbps';

  @override
  String get nasCastDevices => 'Dispositivi DLNA disponibili';

  @override
  String get nasCastDiscovering => 'Ricerca dispositivi DLNA in corso...';

  @override
  String get nasCastRelayingNotice =>
      'Inoltro del flusso tramite app in primo piano. Mantieni Valhalla aperto.';

  @override
  String get nasCastStop => 'Interrompi trasmissione';

  @override
  String get nasCastVolume => 'Volume';

  @override
  String get nasCastRetry => 'Riprova ricerca';

  @override
  String get nasInstallTitle => 'Distribuisci server multimediale NAS';

  @override
  String get nasInstallProduct => 'Prodotto';

  @override
  String get nasInstallMediaPath => 'Directory multimediale (sola lettura)';

  @override
  String get nasInstallDataRoot => 'Directory dati e configurazione';

  @override
  String get nasInstallPort => 'Porta';

  @override
  String get nasInstallBindAddress => 'Indirizzo di binding';

  @override
  String get nasInstallWebdavUser => 'Nome utente WebDAV';

  @override
  String get nasInstallWebdavPassword =>
      'Password WebDAV (minimo 12 caratteri)';

  @override
  String get nasInstallPreparePlan => 'Rivedi piano di distribuzione';

  @override
  String get nasInstallPlanTitle => 'Revisione tecnica e conferma';

  @override
  String get nasInstallBlockersTitle => 'Blocchi della distribuzione';

  @override
  String get nasInstallConfirmDeploy => 'Conferma e installa';

  @override
  String get nasInstallDeploying => 'Distribuzione container in corso...';

  @override
  String get nasInstallSuccess => 'Distribuito con successo';

  @override
  String get nasInstallSuccessDesc =>
      'Il servizio è ora in esecuzione. Completa la configurazione iniziale del server prima di aggiungerlo come sorgente multimediale.';

  @override
  String get nasInstallContainerId => 'ID container';

  @override
  String get nasInstallEndpoint => 'Endpoint';

  @override
  String get nasUseSshTunnel => 'Usa tunnel SSH';

  @override
  String get nasUseSshTunnelDesc =>
      'Instrada il traffico attraverso un server SSH salvato (es. http://127.0.0.1:8096)';

  @override
  String get nasSshTunnelHint =>
      'L\'endpoint deve essere accessibile dal server SSH, es. http://127.0.0.1:8096';

  @override
  String get nasKeepEmptyPassword =>
      'Lascia vuoto per mantenere password / token esistenti';

  @override
  String get nasSourceNameRequired => 'Il nome della sorgente è obbligatorio';

  @override
  String get nasInvalidEndpoint => 'URL endpoint o schema non valido';

  @override
  String get nasSourceUnreachable =>
      'Impossibile raggiungere la sorgente multimediale';

  @override
  String get nasSshTunnelFailed => 'Connessione al tunnel SSH non riuscita';

  @override
  String get nasOperationFailed => 'Operazione non riuscita';

  @override
  String get nasInstallStepCreateDir => 'Crea directory privata';

  @override
  String get nasInstallStepWriteCompose =>
      'Scrivi configurazione docker-compose.json';

  @override
  String get nasInstallStepWriteCreds => 'Scrivi credenziali private';

  @override
  String get nasInstallStepPullImage => 'Scarica immagine container fissata';

  @override
  String get nasInstallStepStartService => 'Avvia servizio containerizzato';

  @override
  String get nasInstallStepCheckHttp => 'Verifica integrità HTTP del servizio';

  @override
  String get nasInstallBlockerDocker =>
      'Docker Engine è richiesto sul server di destinazione';

  @override
  String get nasInstallBlockerCompose => 'Il plugin Docker Compose è richiesto';

  @override
  String get nasInstallBlockerIdentity =>
      'Impossibile verificare l\'identità del server di destinazione';

  @override
  String get nasInstallBlockerTools =>
      'Gli strumenti richiesti (curl, ss, realpath) mancano sul server di destinazione';

  @override
  String get nasInstallBlockerMedia =>
      'La directory multimediale non esiste o non è leggibile';

  @override
  String get nasInstallBlockerParent =>
      'La directory padre della radice dei dati non è scrivibile';

  @override
  String get nasInstallBlockerOverlap =>
      'La directory multimediale e la directory dati non possono sovrapporsi';

  @override
  String get nasInstallBlockerCollision =>
      'La directory dati di destinazione esiste già o è un collegamento simbolico';

  @override
  String get nasInstallBlockerPort =>
      'La porta selezionata è già in uso sul server di destinazione';

  @override
  String get nasInstallBlockerContainer =>
      'Un container con questo nome progetto esiste già';

  @override
  String get nasInstallBlockerImage =>
      'Impossibile verificare l\'immagine del container. Controlla il nome dell\'immagine, la connettività di rete e l\'architettura del server, quindi riprova.';

  @override
  String get nasInstallGuidanceTunnel =>
      'Il binding di loopback (127.0.0.1) richiede un tunnel SSH per l\'accesso remoto';

  @override
  String get nasInstallGuidanceTls =>
      'Si consiglia di proteggere il binding pubblico dietro un reverse proxy TLS';

  @override
  String get nasInstallGuidanceSetup =>
      'Completa la configurazione iniziale dell\'account amministratore nel browser al primo avvio';

  @override
  String get nasInstallGuidanceReadOnly =>
      'La directory multimediale è montata in sola lettura per salvaguardare i tuoi file';

  @override
  String get nasInstallGuidancePreserved =>
      'La directory dati verrà conservata in caso di errore per la risoluzione dei problemi';

  @override
  String get nasDownloadCompletedWithOpenError =>
      'Scaricato (impossibile aprire esternamente)';

  @override
  String get nasRetryOpen => 'Riprova ad aprire';

  @override
  String get nasExternalOpenFailed =>
      'Impossibile aprire il file nell\'app esterna';

  @override
  String get nasTitle => 'Media NAS';

  @override
  String get nasLoadMoreGroups => 'Carica altri gruppi';

  @override
  String get nasMetadataEnriching => 'Arricchimento tag musicali in corso...';

  @override
  String nasMetadataEnrichingWithCount(int count) {
    return 'Arricchimento tag musicali ($count elaborati)...';
  }

  @override
  String nasDownloading(String value) {
    return 'Download di $value in corso…';
  }

  @override
  String get nasSubtitleNone => 'Nessuno';

  @override
  String get nasLibraryId => 'ID libreria';

  @override
  String get nasLibraryIdHint =>
      'Predefinito: tutti (/), o specifica l\'ID della libreria';

  @override
  String nasScanPathRelativeHint(String value) {
    return 'Relativo alla radice della sorgente ($value)';
  }

  @override
  String get nasSourceChangedError =>
      'Sorgente modificata durante la configurazione, salvataggio annullato';

  @override
  String get nasInvalidLibraryId => 'ID libreria non valido';

  @override
  String get startupFailed => 'Impossibile avviare l\'applicazione';

  @override
  String get startupFailedDesc =>
      'Si è verificato un errore imprevisto durante l\'avvio. Puoi riprovare o esportare i log diagnostici.';

  @override
  String get retryStartup => 'Riprova avvio';

  @override
  String get viewDiagnostics => 'Visualizza diagnostica';

  @override
  String get exportDiagnostics => 'Esporta diagnostica';

  @override
  String diagnosticsExportSuccess(String path) {
    return 'Diagnostica esportata in $path';
  }

  @override
  String get diagnosticsExportFailed => 'Impossibile esportare la diagnostica';

  @override
  String get diagnosticsTitle => 'Diagnostica app';

  @override
  String get settingsDiagnostics => 'Diagnostica e log';

  @override
  String get settingsDiagnosticsDesc =>
      'Visualizza ed esporta i log locali dell\'applicazione sanificati';

  @override
  String get diagnosticsEmpty => 'Nessun record diagnostico trovato';

  @override
  String diagnosticsStorageError(String error) {
    return 'Errore di archiviazione della diagnostica: $error';
  }

  @override
  String diagnosticsIncidentNotice(String category) {
    return 'Segnalato incidente recuperabile: $category';
  }

  @override
  String get diagnosticsRefresh => 'Aggiorna log';

  @override
  String get nasInstallTaskTitle => 'Attività di distribuzione';

  @override
  String get nasInstallStagePreflight => 'Controllo preliminare';

  @override
  String get nasInstallStageReview => 'Revisione del piano';

  @override
  String get nasInstallStageWriting => 'Scrittura della configurazione';

  @override
  String get nasInstallStagePulling => 'Download dell\'immagine';

  @override
  String get nasInstallStageStarting => 'Avvio del container';

  @override
  String get nasInstallStageHealth => 'Controllo dello stato di salute';

  @override
  String get nasInstallStageCleanup => 'Pulizia in corso';

  @override
  String get nasInstallStageSucceeded => 'Distribuzione completata';

  @override
  String get nasInstallStageFailed => 'Distribuzione non riuscita';

  @override
  String get nasInstallStageCancelled => 'Distribuzione annullata';

  @override
  String get nasInstallStageNeedsInspection => 'Richiede ispezione';

  @override
  String get nasInstallStageReconciling => 'Riconciliazione dello stato';

  @override
  String get nasInstallCancel => 'Annulla distribuzione';

  @override
  String get nasInstallReconcile => 'Riconcilia stato';

  @override
  String get nasInstallServerNotFound =>
      'Il server selezionato non è stato trovato';

  @override
  String get nasInstallPortRangeError =>
      'La porta deve essere compresa tra 1 e 65535';

  @override
  String nasInstallElapsedTime(String time) {
    return 'Trascorso: $time';
  }

  @override
  String get nasInstallLogTail => 'Log recenti';

  @override
  String get nasInstallCleanupCompleted => 'Pulizia di ripristino completata';

  @override
  String get nasInstallCleanupIncomplete => 'Pulizia di ripristino incompleta';

  @override
  String get nasInstallNewDeployment => 'Nuova distribuzione';

  @override
  String get nasInstallBackEdit => 'Indietro / Modifica modulo';

  @override
  String get nasInstallClose => 'Chiudi';

  @override
  String get nasInstallMediaPathHint =>
      'Montaggio bind in sola lettura sull\'host (es. /mnt/media)';

  @override
  String get nasInstallDataRootHint =>
      'Directory privata dati e configurazione (non deve ancora esistere)';

  @override
  String get nasInstallBindAddressHint =>
      '127.0.0.1 per il tunnel, 0.0.0.0 per la LAN';

  @override
  String get nasInstallWebdavPasswordHint => 'Richiesti almeno 12 caratteri';

  @override
  String get nasInstallTargetServer => 'Server di destinazione';

  @override
  String get nasInstallTargetImage => 'Immagine di destinazione';

  @override
  String get nasInstallContainerName => 'Nome container';

  @override
  String get nasInstallBindAndPort => 'Binding e porta';

  @override
  String get nasInstallComposePreview => 'Anteprima docker-compose.json';

  @override
  String get nasInstallPlannedSteps => 'Passaggi pianificati';

  @override
  String get nasInstallGuidanceNotes =>
      'Note e indicazioni sulla distribuzione';

  @override
  String get nasInstallNoLogsYet => 'Ancora nessun log';

  @override
  String get sftpPreviewTooLarge =>
      'Il file supera il limite di anteprima di 1 MiB. Scaricalo e aprilo esternamente.';

  @override
  String get sftpSaveFailed =>
      'Impossibile salvare il file. Controlla i permessi o la connessione di rete.';

  @override
  String get sftpSaving => 'Salvataggio in corso...';

  @override
  String get nasInstallBlockerConnectionChanged =>
      'Connessione al server di destinazione modificata; verifica lo stato remoto prima di procedere';

  @override
  String get nasInstallBlockerCancelled =>
      'La distribuzione è stata annullata dall\'utente. Rivedi le impostazioni e riprova se necessario.';

  @override
  String get nasInstallBlockerInspectFailed =>
      'Ispezione non riuscita nell\'interrogare il container remoto. Verifica la connettività del server o ispeziona manualmente.';

  @override
  String get nasInstallBlockerDeadlineExceeded =>
      'Timeout del passaggio di distribuzione. Controlla il carico del server o la connessione di rete e riprova.';

  @override
  String get nasInstallBlockerInterrupted =>
      'La distribuzione è stata interrotta; controlla lo stato remoto prima di procedere.';

  @override
  String get nasInstallBlockerHealthTimeout =>
      'Servizio avviato ma controllo integrità HTTP scaduto. Verifica i log del servizio o la disponibilità delle porte.';

  @override
  String get nasInstallBlockerReconciliationFailed =>
      'Riconciliazione non riuscita. Verifica manualmente lo stato del container remoto o avvia una nuova distribuzione.';

  @override
  String get nasInstallBlockerRemoteInspectionRequired =>
      'Lo stato del container remoto è incerto. Sono necessarie ispezione manuale e riconciliazione.';

  @override
  String get nasInstallBlockerServiceExited =>
      'Il processo del container è terminato prematuramente. Controlla i log per errori di configurazione o permessi.';

  @override
  String get nasInstallBlockerWriteFailed =>
      'Impossibile scrivere i file di distribuzione sul server di destinazione. Controlla lo spazio su disco e i permessi.';

  @override
  String get nasInstallBlockerPlanStale =>
      'Il piano di distribuzione è obsoleto. Esegui nuovamente i controlli preliminari.';

  @override
  String get nasInstallBlockerOwnershipChanged =>
      'Il container esistente non è stato creato da questa app. Ispeziona manualmente per evitare la sovrascrittura.';

  @override
  String get nasInstallBlockerSshRequired =>
      'È richiesta una connessione SSH attiva al server di destinazione.';

  @override
  String get nasInstallBlockerReconciliationRequired =>
      'Lo stato remoto differisce dallo stato locale. Riconcilia prima di procedere.';

  @override
  String get nasInstallBlockerFailed =>
      'La distribuzione ha riscontrato un errore. Controlla i log e riprova.';

  @override
  String get nasInstallBlockerBusy =>
      'Un\'attività di installazione è già in corso. Controlla l\'avanzamento dell\'attività corrente.';

  @override
  String get nasInstallBlockerStateSaveFailed =>
      'Impossibile mantenere lo stato di distribuzione. Controlla lo spazio di archiviazione locale e i permessi dei file.';

  @override
  String get nasInstallBlockerCommandResultUnknown =>
      'L\'esito del comando remoto è sconosciuto. Esegui un\'ispezione di sola lettura invece di riprovare direttamente la distribuzione.';

  @override
  String get nasInstallBlockerPreflightFailed =>
      'Controllo dell\'ambiente pre-distribuzione non riuscito. Risolvi i problemi prima di continuare.';

  @override
  String serverDeleteFailed(String error) {
    return 'Impossibile eliminare il server: $error';
  }

  @override
  String get chatRunSettingsAgentMode => 'Modalità agente';

  @override
  String get chatRunSettingsApprovalPolicy => 'Criterio di approvazione locale';

  @override
  String get chatRunSettingsExtraSettings => 'Impostazioni aggiuntive';

  @override
  String get chatPermissionAutoAllowSafeDesc =>
      'Consente automaticamente le operazioni note come sicure; chiede conferma ogni volta che la sicurezza dell\'operazione non può essere determinata.';

  @override
  String chatRunSettingsSaveFailed(String error) {
    return 'Impossibile applicare le impostazioni di esecuzione: $error';
  }

  @override
  String get chatMessageCopied => 'Messaggio copiato negli appunti';

  @override
  String get copy => 'Copia';

  @override
  String get rename => 'Rinomina';

  @override
  String get refresh => 'Aggiorna';

  @override
  String get sessionTitle => 'Titolo sessione';

  @override
  String get chatSettingsStale => 'Obsoleto';

  @override
  String get chatSettingsAvailableAfterFirstMessage =>
      'Impostazioni disponibili dopo il primo messaggio';

  @override
  String get chatReimportAsCopy => 'Reimporta come copia';

  @override
  String get chatSearchCommandsHint => 'Cerca comandi o competenze...';

  @override
  String get chatCommandsTab => 'Comandi';

  @override
  String get chatSkillsTab => 'Competenze';

  @override
  String get chatAccountAndQuotaTitle => 'Account e quota';

  @override
  String get chatAccountSectionTitle => 'Account';

  @override
  String get chatAccountNotProvided => 'Nessun dettaglio account segnalato';

  @override
  String get chatAccountKind => 'Tipo';

  @override
  String get chatAccountLabel => 'Etichetta';

  @override
  String get chatAccountPlan => 'Piano';

  @override
  String get chatAccountEmail => 'Email';

  @override
  String get chatAccountUpdatedAt => 'Aggiornato';

  @override
  String get chatQuotaSectionTitle => 'Quota e stato';

  @override
  String get chatStatusSourceNote => 'Output /status grezzo dell\'agente';

  @override
  String get chatStatusNotQueried => 'Stato non ancora interrogato';

  @override
  String get chatQueryStatusAction => 'Interroga stato (/status)';

  @override
  String get chatQueryStatusUnavailable =>
      'Interrogazione dello stato non disponibile nella sessione corrente';

  @override
  String get chatAttachmentMissing =>
      'File allegato mancante o non disponibile';

  @override
  String get chatViewModeList => 'Elenco';

  @override
  String get chatViewModeCards => 'Schede';

  @override
  String get chatViewModeGrid => 'Immagini';

  @override
  String get chatRemoteBrowserTitle => 'Area di lavoro remota';

  @override
  String get chatSelectDirectory => 'Seleziona directory';

  @override
  String chatAttachSelectedFiles(int count) {
    return 'Allega selezionati ($count)';
  }

  @override
  String get chatNoFilesFound => 'Nessun file trovato';

  @override
  String get chatRootDirectory => 'Root';

  @override
  String get chatSelectThisDirectory => 'Usa questa directory';

  @override
  String get chatAgentVersion => 'Versione agente';

  @override
  String get chatParentDirectory => 'Directory superiore';

  @override
  String get chatSearchFilesHint => 'Cerca file...';

  @override
  String get chatCommandsEmpty => 'Nessun comando slash fornito dall\'agente';

  @override
  String get chatSkillsEmpty => 'Nessuna competenza fornita dall\'agente';

  @override
  String get chatFileUnsupported =>
      'Tipo di file non supportato per l\'allegato';

  @override
  String get chatStatusNotProvided =>
      'Interrogazione dello stato non fornita dall\'agente';

  @override
  String get sessionRecoveryReconnecting => 'Riconnessione in corso...';

  @override
  String get sessionRecoverySyncing => 'Sincronizzazione output...';

  @override
  String get sessionRecoveryIncomplete =>
      'Impossibile recuperare parte dell\'output';

  @override
  String get sessionRecoveryFailed => 'Recupero non riuscito';

  @override
  String get sessionRecoveryRetry => 'Riprova';

  @override
  String get dashboardUpdatesPaused => 'Aggiornamenti in pausa';

  @override
  String get chatSettingsIndependentModelUnavailable =>
      'Il catalogo modelli CLI non è attualmente disponibile. I modelli potrebbero essere memorizzati nella cache o limitati dalla versione della CLI; puoi anche inserire manualmente il nome di un modello.';

  @override
  String get chatSettingsModelCatalogNote =>
      'I modelli vengono interrogati dal server dell\'app CLI utilizzando l\'accesso CLI esistente. Il catalogo potrebbe essere memorizzato nella cache o limitato alla versione; puoi aggiornare manualmente o passare all\'inserimento manuale.';

  @override
  String get chatModelCatalogError403 =>
      'Accesso alla query del modello CLI negato (403). Controlla l\'accesso CLI e la connettività del servizio, oppure inserisci manualmente il nome del modello.';

  @override
  String chatModelCatalogErrorGeneric(String error) {
    return 'Errore catalogo modelli: $error';
  }

  @override
  String get chatModelAuthorizeButton => 'Autorizza catalogo modelli';

  @override
  String get chatModelAuthorizeConfirmTitle => 'Autorizza catalogo modelli';

  @override
  String get chatModelAuthorizeConfirmMessage =>
      'Verrà avviata l\'autorizzazione del browser per il catalogo dei modelli sull\'host/container di destinazione. L\'accesso Codex e le sessioni del terminale esistenti rimarranno completamente intatti. Continuare?';

  @override
  String get chatModelAuthorizing =>
      'Autorizzazione tramite browser in corso...';

  @override
  String get chatModelAuthorizeCancel => 'Annulla autorizzazione';

  @override
  String get chatCommandsFirstTurnNote =>
      'I comandi slash verranno annunciati dal runtime dell\'agente non appena la sessione sarà inizializzata, senza richiedere una conversazione preliminare ordinaria; le bozze non creano automaticamente sessioni.';

  @override
  String get chatCommandsClientActionRunSettings =>
      'Impostazioni di esecuzione';

  @override
  String get chatCommandsClientActionWorkingDirectory => 'Directory di lavoro';

  @override
  String get chatCommandsClientActionsSection => 'Azioni locali';

  @override
  String get chatRunSettingsModelSourceCatalog => 'Elenco modelli';

  @override
  String get chatRunSettingsModelSourceCustom => 'Inserimento manuale';

  @override
  String get chatRunSettingsCustomModelHint => 'Inserisci ID modello';

  @override
  String get chatRunSettingsCustomModelNotice =>
      'I nomi dei modelli manuali non sono verificati e verranno inviati direttamente al runtime dell\'agente, che potrebbe rifiutare modelli non supportati.';

  @override
  String get chatRunSettingsCustomModelEmptyError =>
      'Il nome del modello non può essere vuoto';

  @override
  String get chatRunSettingsCustomModelInvalidError =>
      'Il nome del modello deve contenere al massimo 256 caratteri senza spazi o caratteri di controllo';

  @override
  String get chatCommandsDraftPreviewNotice =>
      'Comandi verificati per la versione corrente dell\'adattatore. Selezionando si inserisce il testo nella bozza; Invia inizializzerà la sessione su richiesta ed eseguirà direttamente il comando.';

  @override
  String get chatCommandsDiscoveryFailed =>
      'Impossibile rilevare comandi o competenze';

  @override
  String get chatAuthWaitingForBrowser =>
      'In attesa di autorizzazione nel browser...';

  @override
  String get chatAuthBrowserLaunchFailed =>
      'Impossibile aprire il browser esterno. Riapri o copia il link di autorizzazione sottostante.';

  @override
  String get chatAuthReopenBrowser => 'Riapri browser';

  @override
  String get chatAuthCopyLink => 'Copia link';

  @override
  String get chatAuthManualCallback => 'Callback manuale';

  @override
  String get chatAuthManualCallbackTitle =>
      'Inserisci URL di callback di autorizzazione';

  @override
  String get chatAuthManualCallbackDesc =>
      'Incolla l\'URL di reindirizzamento completo (http://127.0.0.1:PORT/...?code=...&state=...) dal browser per completare l\'autorizzazione. I codici di autorizzazione non elaborati non vengono accettati.';

  @override
  String get chatAuthCallbackInputLabel => 'URL di callback';

  @override
  String get chatAuthCallbackInputHint =>
      'http://127.0.0.1:PORT/...?code=...&state=...';

  @override
  String get chatAuthCallbackInvalidError =>
      'Formato URL di callback non valido o recapito non riuscito';

  @override
  String get agentAuthAgYNotice =>
      'Antigravity ACP richiede l\'autorizzazione ufficiale dell\'account, separata dall\'accesso CLI da terminale.';

  @override
  String get chatAuthDiscoveryPrompt =>
      'Questo turno richiede l\'autenticazione ACP. Riconnettiti e richiedi l\'autorizzazione per procedere.';

  @override
  String get chatRequestAuthButton => 'Richiedi autenticazione';

  @override
  String get agentActionAcpLogin => 'Accesso ACP';

  @override
  String get agentActionCliLogin => 'Accesso CLI';

  @override
  String get agentAgyAcpSignInRequired =>
      'Credenziali ACP mancanti (accesso ACP richiesto)';

  @override
  String get agentAgyAcpCredentialsSaved =>
      'Credenziali ACP salvate (non verificate)';

  @override
  String get chatAuthMethodUnavailable =>
      'Il metodo di autenticazione selezionato non è disponibile.';

  @override
  String get chatAuthConnectionExpired =>
      'Connessione di autenticazione scaduta. Riprova.';

  @override
  String get chatAuthCallbackDeliveryFailed =>
      'Impossibile recapitare il callback di autorizzazione al server.';

  @override
  String get agentTargetChangedNotice =>
      'Il server di destinazione è cambiato. Riapri la gestione degli agenti sul server corrente.';

  @override
  String get agentAgyAuthCheckUnavailable =>
      'Verifica autenticazione Antigravity non disponibile';

  @override
  String get agentAgyAuthCheckInvalid =>
      'Risposta alla verifica dell\'autenticazione Antigravity non valida';

  @override
  String get sftpDownloadDisconnected => 'Download disconnesso';

  @override
  String get sftpDownloadPermissionDenied => 'Autorizzazione negata';

  @override
  String get sftpDownloadNotFound => 'File remoto non trovato';

  @override
  String get sftpDownloadTimeout => 'Timeout del download';

  @override
  String get sftpDownloadLocalSpace =>
      'Spazio di archiviazione locale insufficiente';

  @override
  String get sftpDownloadLocalIo =>
      'Scrittura nella memoria locale non riuscita';

  @override
  String get sftpDownloadIncomplete => 'Download incompleto';

  @override
  String get transferStatusWaitingConnection => 'In attesa di connessione';

  @override
  String get chatAuthCallbackListenerFailed =>
      'Impossibile avviare il listener del callback di autorizzazione locale. Riprova l\'autenticazione.';

  @override
  String get settingsExperimentalFeatures => 'Funzionalità sperimentali';

  @override
  String get settingsExperimentalFeaturesDesc =>
      'Prova funzionalità in anteprima e sperimentali';

  @override
  String get settingsExperimentalCliChatTitle => 'Chat intelligente CLI';

  @override
  String get settingsExperimentalCliChatDesc =>
      'Abilita l\'interfaccia di chat dedicata per gli agenti da riga di comando';

  @override
  String get settingsExperimentalDialogClose => 'Chiudi';

  @override
  String get settingsExperimentalSaveFailed =>
      'Impossibile aggiornare le impostazioni delle funzionalità sperimentali';

  @override
  String get settingsExperimentalNasTitle => 'Media NAS';

  @override
  String get settingsExperimentalNasDesc =>
      'Abilita libreria multimediale, scansione cartelle e riproduzione audio';

  @override
  String get settingsLanguageSaveFailed =>
      'Impossibile aggiornare le impostazioni della lingua';
}
