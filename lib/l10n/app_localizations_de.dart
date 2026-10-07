// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'Valhalla';

  @override
  String get appSubtitle => 'KI-native Server- & Agentenverwaltung';

  @override
  String get navAiChat => 'KI-Ops';

  @override
  String get navTerminal => 'Terminal';

  @override
  String get navFiles => 'SFTP-Dateien';

  @override
  String get navCommands => 'Befehle';

  @override
  String get navSettings => 'Einstellungen';

  @override
  String get serverConnected => 'Verbunden';

  @override
  String get serverOnline => 'Online';

  @override
  String get serverOffline => 'Offline';

  @override
  String get latencyMs => 'ms';

  @override
  String get reconnect => 'Neu verbinden';

  @override
  String get disconnect => 'Trennen';

  @override
  String get quickDisconnect => 'Schnelltrennung';

  @override
  String get newSession => 'Neue Sitzung';

  @override
  String get historySessions => 'Sitzungsverlauf';

  @override
  String get switchAgent => 'Agent wechseln';

  @override
  String get agentClaudeCode => 'Claude CodeX';

  @override
  String get agentCodex => 'OpenAI Codex';

  @override
  String get agentOpenCode => 'OpenCode ACP';

  @override
  String get agentGemini => 'Gemini CLI';

  @override
  String get activeAgent => 'Aktiver Agent';

  @override
  String get inputPromptHint =>
      'Agenten bitten, Diagnosen durchzuführen, Tools auszuführen oder Befehle zu schreiben... (Eingabe zum Senden)';

  @override
  String get thinking => 'Denkprozess';

  @override
  String get executionPlan => 'Ausführungsplan';

  @override
  String get toolCall => 'Tool-Aufruf';

  @override
  String get toolStatusPending => 'Ausstehend';

  @override
  String get toolStatusRunning => 'Wird ausgeführt...';

  @override
  String get toolStatusCompleted => 'Abgeschlossen';

  @override
  String get toolStatusFailed => 'Fehlgeschlagen';

  @override
  String get permissionRequired => 'Berechtigung erforderlich';

  @override
  String get permissionDescription =>
      'Agent möchte diesen Befehl auf dem Server ausführen:';

  @override
  String get permissionReject => 'Ablehnen';

  @override
  String get permissionAllowOnce => 'Einmalig erlauben';

  @override
  String get permissionAllowAlways => 'Immer erlauben';

  @override
  String get quickTroubleshootCpu => 'Hohe CPU-Auslastung analysieren';

  @override
  String get quickDockerHealth => 'Docker-Zustandsprüfung';

  @override
  String get quickCleanCache => 'System-Cache bereinigen';

  @override
  String get quickNginxLogs => 'Nginx-Fehlerprotokolle prüfen';

  @override
  String get terminalNewTab => 'Neuer Tab';

  @override
  String get terminalCloseTab => 'Tab schließen';

  @override
  String get terminalClear => 'Leeren';

  @override
  String get terminalQuickCmds => 'Befehlspalette';

  @override
  String get terminalPaste => 'Einfügen';

  @override
  String get sftpCurrentPath => 'Aktueller Pfad';

  @override
  String get sftpUpload => 'Hochladen';

  @override
  String get sftpNewFolder => 'Neuer Ordner';

  @override
  String get sftpNewFile => 'Neue Datei';

  @override
  String get sftpRefresh => 'Aktualisieren';

  @override
  String get sftpSearchHint => 'Dateien oder Ordner suchen...';

  @override
  String get sftpEmpty => 'Verzeichnis ist leer';

  @override
  String get sftpFileName => 'Name';

  @override
  String get sftpFileSize => 'Größe';

  @override
  String get sftpFilePerm => 'Berechtigungen';

  @override
  String get sftpFileModified => 'Geändert';

  @override
  String get cmdCategoryDocker => 'DOCKER-CONTAINER-STAPEL';

  @override
  String get cmdCategorySystem => 'SYSTEMWARTUNG';

  @override
  String get cmdCategoryNetwork => 'NETZWERK & PORTS';

  @override
  String get cmdExecute => 'Ausführen';

  @override
  String get cmdDangerous => 'Gefährlicher Befehl';

  @override
  String get cmdDangerousWarning =>
      'Dieser Vorgang ist unumkehrbar und kann zu Dienstunterbrechungen führen. Möchten Sie wirklich fortfahren?';

  @override
  String get cmdParamRequired => 'Parametereingabe erforderlich';

  @override
  String get cmdConfirm => 'Bestätigen & Ausführen';

  @override
  String get cmdCancel => 'Abbrechen';

  @override
  String get settingsAppearance => 'Erscheinungsbild & Designs';

  @override
  String get settingsThemeMode => 'Designmodus';

  @override
  String get themeSystem => 'Systemstandard';

  @override
  String get themeSystemDesc => 'Automatisch anpassen';

  @override
  String get themeLight => 'Heller Modus';

  @override
  String get themeLightDesc => 'Klares Weiß';

  @override
  String get themeDark => 'Geek Dunkel';

  @override
  String get themeDarkDesc => 'Tiefes Anthrazit';

  @override
  String get themeAmoled => 'AMOLED Schwarz';

  @override
  String get themeAmoledDesc => 'Echtes Schwarz 0x000000';

  @override
  String get settingsAccentColor => 'Akzentfarbe des Designs';

  @override
  String get accentCyberEmerald => 'Cyber-Smaragd';

  @override
  String get accentTechBlue => 'Tech-Blau';

  @override
  String get accentElectricViolet => 'Elektrisches Violett';

  @override
  String get accentCrimsonRed => 'Karmesinrot';

  @override
  String get accentAmberOrange => 'Bernstein-Orange';

  @override
  String get settingsLanguage => 'Sprache & Region';

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
  String get settingsAiOps => 'KI-Ops & Engine';

  @override
  String get settingsSecurity => 'Verbindung & Sicherheit';

  @override
  String get settingsKnownHosts => 'Bekannte Host-Schlüssel';

  @override
  String get settingsClearStorage => 'Zugangsdaten zurücksetzen';

  @override
  String get settingsResetDefault => 'Auf Standard zurücksetzen';

  @override
  String get settingsTerminalUseTmux => 'Persistente Sitzungen (tmux)';

  @override
  String get settingsTerminalUseTmuxSubtitle =>
      'Terminal-Sitzungen in tmux auf dem Remote-Server ausführen';

  @override
  String get settingsTerminalUseTmuxDescription =>
      'Behält Ihre Terminal-Ausgabe nach einem Verbindungsabbruch bei. Erfordert tmux auf dem Remote-Server. Änderungen gelten für neu geöffnete Terminal-Tabs.';

  @override
  String get settingsTerminalFontSize => 'Terminal-Schriftgröße';

  @override
  String get settingsTerminalFontSizeSubtitle =>
      'Passt die SSH- und CLI-Terminal-Schriftgröße an';

  @override
  String get version => 'Version';

  @override
  String get addServer => 'Server hinzufügen';

  @override
  String get editServer => 'Server bearbeiten';

  @override
  String get serverName => 'Servername';

  @override
  String get serverHost => 'Host / IP';

  @override
  String get serverPort => 'Port';

  @override
  String get serverUsername => 'Benutzername';

  @override
  String get serverAuthType => 'Authentifizierungstyp';

  @override
  String get serverPassword => 'Passwort';

  @override
  String get serverPrivateKey => 'Privater Schlüssel';

  @override
  String get serverSave => 'Server speichern';

  @override
  String get serverDelete => 'Server löschen';

  @override
  String get fileEditor => 'Datei-Editor';

  @override
  String get fileEditorSave => 'Änderungen speichern';

  @override
  String get fileSavedSuccess => 'Datei erfolgreich gespeichert';

  @override
  String get addCommand => 'Neuer Befehl';

  @override
  String get commandTitle => 'Befehlstitel';

  @override
  String get commandContent => 'Befehlszeichenfolge';

  @override
  String get commandCategory => 'Kategorie';

  @override
  String get commandDescription => 'Beschreibung';

  @override
  String get save => 'Speichern';

  @override
  String get delete => 'Löschen';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get confirm => 'Bestätigen';

  @override
  String get cmdExecutionChannel => 'Ausführungskanal';

  @override
  String get cmdChannelTerminal => 'Direkt im SSH-Terminal';

  @override
  String get cmdChannelTerminalDesc =>
      'Befehl wird direkt in die aktive Terminal-Sitzung eingegeben';

  @override
  String get cmdChannelBackground => 'In Hintergrundsitzung ausführen';

  @override
  String get cmdChannelBackgroundDesc =>
      'Wird über SSH-Login-Shell ausgeführt und erfasst die Ausgabe';

  @override
  String get cmdInjectedToTerminal => 'Befehl an Terminal gesendet';

  @override
  String get cmdExecutionCompleted => 'Ausführung abgeschlossen';

  @override
  String get cmdExecutionFailed => 'Ausführung fehlgeschlagen';

  @override
  String get cmdExecutingRemote => 'Remote-Befehl wird ausgeführt...';

  @override
  String get cmdClose => 'Schließen';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navDocker => 'Docker';

  @override
  String get navSystem => 'System';

  @override
  String get navMore => 'Mehr';

  @override
  String get dashboardTitle => 'Server-Dashboard';

  @override
  String get metricsCpu => 'CPU-Auslastung';

  @override
  String get metricsMemory => 'Speicherauslastung';

  @override
  String get metricsLoadAvg => 'Lastdurchschnitt';

  @override
  String get metricsUptime => 'System-Betriebszeit';

  @override
  String get metricsRootDisk => 'Root-Festplattenbelegung';

  @override
  String get quickActions => 'Schnellnavigation';

  @override
  String get activeServerStatus => 'Status des aktiven Servers';

  @override
  String get noServerSelected =>
      'Derzeit ist kein Server ausgewählt. Bitte wählen Sie zuerst einen Server aus.';

  @override
  String get serverDisconnected => 'Getrennt';

  @override
  String get serverConnecting => 'Verbindung wird hergestellt...';

  @override
  String get connectNow => 'Jetzt verbinden';

  @override
  String get serverSpecs => 'Server-Info & Spezifikationen';

  @override
  String get dockerTitle => 'Docker-Container';

  @override
  String get dockerSearchHint => 'Container nach Name oder Image suchen...';

  @override
  String get dockerFilterAll => 'Alle';

  @override
  String get dockerFilterRunning => 'Aktiv';

  @override
  String get dockerFilterExited => 'Beendet';

  @override
  String get dockerFilterPaused => 'Pausiert';

  @override
  String get dockerActionStart => 'Starten';

  @override
  String get dockerActionStop => 'Stoppen';

  @override
  String get dockerActionRestart => 'Neu starten';

  @override
  String get dockerActionPause => 'Pausieren';

  @override
  String get dockerActionUnpause => 'Fortsetzen';

  @override
  String get dockerActionRm => 'Entfernen';

  @override
  String get dockerActionLogs => 'Protokolle';

  @override
  String get dockerActionInspect => 'Untersuchen';

  @override
  String get dockerLogsTitle => 'Container-Protokolle';

  @override
  String get dockerInspectTitle => 'Container-Details';

  @override
  String get dockerNoContainers => 'Keine Container auf dem Server gefunden';

  @override
  String get dockerEmptyRunning => 'Keine laufenden Container';

  @override
  String get dockerPorts => 'Ports';

  @override
  String get dockerCreated => 'Erstellt';

  @override
  String get dockerImage => 'Image';

  @override
  String get systemTitle => 'Prozesse & Dienste';

  @override
  String get tabProcesses => 'Prozesse';

  @override
  String get tabServices => 'Systemd-Dienste';

  @override
  String get processSearchHint => 'Nach Prozessname oder PID suchen...';

  @override
  String get processPid => 'PID';

  @override
  String get processCpu => 'CPU %';

  @override
  String get processMem => 'SPEICHER %';

  @override
  String get processStat => 'Status';

  @override
  String get processCommand => 'Befehl';

  @override
  String get processTerminate => 'Beenden (SIGTERM)';

  @override
  String get processForceKill => 'Sofort beenden (SIGKILL)';

  @override
  String get processKillForbidden =>
      'Beenden des System-Init-Prozesses verweigert (PID <= 1)';

  @override
  String get serviceSearchHint => 'Dienste nach Namen suchen...';

  @override
  String get serviceName => 'Dienst';

  @override
  String get serviceDescription => 'Beschreibung';

  @override
  String get serviceStatus => 'Status';

  @override
  String get serviceStartup => 'Autostart';

  @override
  String get serviceActionStart => 'Starten';

  @override
  String get serviceActionStop => 'Stoppen';

  @override
  String get serviceActionRestart => 'Neu starten';

  @override
  String get serviceActionReload => 'Neu laden';

  @override
  String get serviceActionEnable => 'Aktivieren';

  @override
  String get serviceActionDisable => 'Deaktivieren';

  @override
  String get serviceNoServices => 'Keine Systemd-Dienste gefunden';

  @override
  String get riskDangerTitle => 'Bestätigung für risikoreichen Vorgang';

  @override
  String get riskWarningTitle => 'Warnung vor Vorgang bestätigen';

  @override
  String get riskSafeTitle => 'Aktion bestätigen';

  @override
  String get riskIrreversibleWarning =>
      'Dieser Vorgang ist als HOHES RISIKO eingestuft und kann nicht rückgängig gemacht werden. Er kann zu Datenverlust oder Dienstunterbrechungen führen.';

  @override
  String get riskWarningDescription =>
      'Dieser Vorgang kann aktive Dienste beeinträchtigen oder Prozesse neu starten. Bitte mit Vorsicht fortfahren.';

  @override
  String get riskCommandPreview => 'Befehlsvorschau';

  @override
  String get riskConfirmButton => 'Bestätigen & Fortfahren';

  @override
  String get riskCancelButton => 'Abbrechen';

  @override
  String get stateLoading => 'Remote-Daten werden geladen...';

  @override
  String get stateOffline => 'Server ist offline';

  @override
  String get stateOfflineDesc =>
      'Stellen Sie eine aktive SSH-Verbindung her, um Ressourcen zu verwalten und Metriken zu streamen.';

  @override
  String get stateError => 'Ein Fehler ist aufgetreten';

  @override
  String get stateRetry => 'Wiederholen';

  @override
  String get stateEmpty => 'Keine Elemente gefunden';

  @override
  String get inspectorTitle => 'Inspektor';

  @override
  String get inspectorClose => 'Schließen';

  @override
  String get inspectorDetails => 'Details untersuchen';

  @override
  String get selectServerTitle => 'Zielserver auswählen';

  @override
  String get sshDisconnectedSuccess => 'SSH-Verbindung getrennt';

  @override
  String get trustHostFingerprintTitle => 'Host-Fingerabdruck vertrauen?';

  @override
  String get trustAndConnect => 'Vertrauen & Verbinden';

  @override
  String get reject => 'Ablehnen';

  @override
  String get confirmDeleteServerTitle => 'Server löschen';

  @override
  String get noServersFound => 'Noch keine Server konfiguriert';

  @override
  String get agentNotReadyError =>
      'Ausgewählter Agent ist nicht bereit. Bitte überprüfen Sie Umgebung und Konfiguration.';

  @override
  String get sshDisconnectedError =>
      'SSH ist getrennt. Bitte verbinden Sie sich mit einem Server, bevor Sie KI-Ops verwenden.';

  @override
  String get noAgentAvailable => 'Kein Agent verfügbar';

  @override
  String get noAgentAvailablePrompt =>
      'Kein aktiver Agent verfügbar. Bitte konfigurieren oder bereiten Sie zuerst einen Agenten vor.';

  @override
  String get noAgentAvailableHint =>
      'Wählen oder konfigurieren Sie einen verfügbaren Agenten, um zu chatten...';

  @override
  String get manageAgents => 'Agenten verwalten';

  @override
  String get noReadyAgentsTitle => 'Keine bereiten Agenten';

  @override
  String get noReadyAgentsDesc =>
      'Kein Agent auf diesem Server hat die Umgebungsprüfung bestanden.';

  @override
  String get agentStatusReady => 'Bereit';

  @override
  String get agentStatusChecking => 'Wird geprüft...';

  @override
  String get agentStatusCliMissing => 'Installation nicht erkannt';

  @override
  String get agentStatusAcpMissing => 'ACP-Komponente nicht erkannt';

  @override
  String get agentStatusNotLoggedIn => 'Nicht angemeldet';

  @override
  String get agentStatusError => 'Fehler';

  @override
  String get agentStatusUnknown => 'Unbekannt';

  @override
  String get agentActionInstall => 'Installieren';

  @override
  String get agentActionLogin => 'Anmelden';

  @override
  String get agentActionRefresh => 'Status prüfen';

  @override
  String get noConfiguredAgents =>
      'Keine Agenten auf diesem Server konfiguriert';

  @override
  String get agentManagementTitle => 'Agenten-Verwaltung';

  @override
  String get settingsAgentManagement => 'Agenten-Verwaltung';

  @override
  String get settingsAgentManagementSubtitle =>
      'ACP-Agenten für den aktuellen Server konfigurieren, erkennen und verwalten';

  @override
  String get addAgentButton => 'Agent hinzufügen';

  @override
  String get noServerSelectedForAgents =>
      'Kein Server ausgewählt. Bitte wählen Sie zuerst einen Server in der Hauptansicht aus.';

  @override
  String get sshDisconnectedAgentWarning =>
      'SSH ist getrennt. Erkennung, Installation und Anmeldung sind deaktiviert, bis eine Verbindung besteht.';

  @override
  String get noAgentsConfiguredTitle => 'Keine Agenten konfiguriert';

  @override
  String get noAgentsConfiguredDesc =>
      'Fügen Sie Claude Code, Codex, OpenCode, AGY oder benutzerdefinierte ACP-Agenten hinzu, um KI-Ops auf diesem Server zu aktivieren.';

  @override
  String get agentPresetLabel => 'Vorlage';

  @override
  String get agentPresetClaudeCode => 'Claude Code';

  @override
  String get agentPresetCodex => 'OpenAI Codex';

  @override
  String get agentPresetOpenCode => 'OpenCode ACP';

  @override
  String get agentPresetAgy => 'Antigravity AGY';

  @override
  String get agentPresetCustom => 'Benutzerdefiniert';

  @override
  String get agentNameLabel => 'Agentenname';

  @override
  String get agentNameHint => 'z. B. Produktions-Codex';

  @override
  String get agentDescriptionLabel => 'Beschreibung';

  @override
  String get agentDescriptionHint => 'Kurze Beschreibung des Agenten';

  @override
  String get agentCliCommandLabel => 'CLI-Prüfbefehl';

  @override
  String get agentCliCommandHint => 'z. B. claude, codex';

  @override
  String get agentAcpCommandLabel => 'ACP-Startbefehl';

  @override
  String get agentAcpCommandHint => 'z. B. codex-acp --stdio';

  @override
  String get agentInstallCommandLabel => 'Installationsbefehl (Optional)';

  @override
  String get agentInstallCommandHint => 'z. B. npm install -g @openai/codex';

  @override
  String get agentLoginCheckCommandLabel => 'Anmeldeprüfbefehl (Optional)';

  @override
  String get agentLoginCheckCommandHint => 'z. B. codex --version';

  @override
  String get agentLoginCommandLabel => 'Anmeldebefehl (Optional)';

  @override
  String get agentLoginCommandHint => 'z. B. codex login';

  @override
  String get agentSaveButton => 'Speichern & Erkennen';

  @override
  String get agentCliRequired => 'CLI-Prüfbefehl ist erforderlich';

  @override
  String get agentAcpRequired => 'ACP-Startbefehl ist erforderlich';

  @override
  String get agentNameRequired => 'Agentenname ist erforderlich';

  @override
  String get confirmInstallAgentTitle => 'Agenten-Installation bestätigen';

  @override
  String get confirmLoginAgentTitle => 'Agenten-Anmeldung bestätigen';

  @override
  String get agentCommandRiskWarning =>
      'Dieser Befehl wird direkt auf dem Remote-Server mit den aktuellen Benutzerberechtigungen ausgeführt. Er kann Pakete installieren oder Systemumgebungen verändern.';

  @override
  String get targetServerLabel => 'Zielserver';

  @override
  String get commandPreviewLabel => 'Befehlsvorschau';

  @override
  String get executeButton => 'Ausführen';

  @override
  String get deleteAgentTitle => 'Agent löschen';

  @override
  String get deleteAgentConfirm => 'Löschen';

  @override
  String get agentStatusCheckingDesc =>
      'Umgebung auf Remote-Server wird erkannt...';

  @override
  String get agentStatusInstalling =>
      'Abhängigkeiten werden auf dem Server installiert...';

  @override
  String get agentStatusLoggingIn =>
      'Anmeldebefehl wird auf dem Server ausgeführt...';

  @override
  String get agentNoLoginCheckProvided => 'Kein Anmeldeprüfbefehl angegeben';

  @override
  String get agentInstallPrompt =>
      'Installation nicht erkannt. Jetzt automatisch installieren?';

  @override
  String get agentActionAutoInstall => 'Auto-Installation';

  @override
  String get agentLoginPrompt => 'Nicht angemeldet. Jetzt anmelden?';

  @override
  String get agentActionExecuteLogin => 'Jetzt anmelden';

  @override
  String get agentNeedsInstallOrReadyPrompt =>
      'Agenten auf diesem Server sind noch nicht installiert oder bereit. Bitte verwalten und vervollständigen Sie die Einrichtung.';

  @override
  String get agentNeedsInstallOrReadyHint =>
      'Installieren und bereiten Sie einen Agenten vor, um den Chat zu starten...';

  @override
  String get agentAcpInstallPrompt =>
      'ACP-Komponente nicht erkannt. Jetzt automatisch installieren?';

  @override
  String get agentInstallCommandAcpLabel =>
      'ACP-Installationsbefehl (Optional)';

  @override
  String get agentInstallCommandAcpHint =>
      'z. B. npm install -g @zed-industries/codex-acp';

  @override
  String get agentNoInstallCommand =>
      'Kein Installationsbefehl für diesen Agenten konfiguriert';

  @override
  String get agentInstallLogTitle => 'Installationsausgabe';

  @override
  String get agentInstallLogEmpty => 'Warten auf Installationsausgabe…';

  @override
  String get agentInstallLogTruncated =>
      'Ausgabe zu lang; die neuesten Zeilen werden angezeigt';

  @override
  String get agentAcpOptional => 'Optional; für reines CLI leer lassen';

  @override
  String get acpStreaming => 'ACP-Streaming...';

  @override
  String get aiOpsAgentTitle => 'Valhalla KI-Ops-Agent';

  @override
  String get aiOpsEmptySubtitle => 'Verbunden über ACP stdio über SSH-Kanal';

  @override
  String get agentAuthRequiredTitle => 'Authentifizierung erforderlich';

  @override
  String get agentAuthRequiredDesc =>
      'Der Agent erfordert eine Authentifizierung, bevor er Ihre Anfrage verarbeiten kann.';

  @override
  String get agentAuthMethodLabel => 'Authentifizierungsmethode';

  @override
  String get agentAuthNoMethodsNotice =>
      'Der Agent hat keine Anmeldemethode bereitgestellt. Bitte prüfen Sie dessen Konfiguration auf dem Server.';

  @override
  String get agentAuthProceedButton => 'Anmelden';

  @override
  String get agentAuthCancelButton => 'Abbrechen';

  @override
  String get agentAuthRetryHint =>
      'Nach der Anmeldung senden Sie Ihre Nachricht bitte erneut.';

  @override
  String get agentAuthRequiredError =>
      'Authentifizierung erforderlich. Bitte melden Sie sich an, um fortzufahren.';

  @override
  String get agentLoginTerminalTitle => 'Interaktives Anmeldeterminal';

  @override
  String get agentLoginTerminalSubtitle =>
      'Führen Sie die Anmeldeschritte im folgenden Terminal aus. Folgen Sie allen angezeigten URLs oder Code-Aufforderungen.';

  @override
  String get agentLoginTerminalRunning =>
      'Anmeldebefehl wird im Terminal ausgeführt...';

  @override
  String get agentLoginTerminalDisconnected =>
      'SSH-Verbindung unterbrochen. Die Anmeldesitzung wurde abgebrochen.';

  @override
  String get agentLoginTerminalRetry => 'Terminal neu verbinden';

  @override
  String get agentLoginTerminalFinish => 'Fertigstellen & Prüfen';

  @override
  String get agentLoginTerminalClose => 'Schließen';

  @override
  String get agentLoginTerminalNoTtyHint =>
      'Wenn der Agent das Einfügen eines Codes erfordert, drücken Sie lange auf das Terminal oder verwenden Sie die Taste EINFÜGEN.';

  @override
  String get agentLoginTerminalUrlLabel => 'Anmelde-URL erkannt';

  @override
  String get agentLoginTerminalUrlCopy => 'Link kopieren';

  @override
  String get agentLoginTerminalUrlCopied =>
      'Anmelde-URL in Zwischenablage kopiert';

  @override
  String get agentLoginTerminalCopyAll => 'Gesamte Ausgabe kopieren';

  @override
  String get agentLoginTerminalCopiedAll =>
      'Terminalausgabe in Zwischenablage kopiert';

  @override
  String get sshStatusReconnected => 'Verbindung wiederhergestellt';

  @override
  String get sshStatusDisconnectedRetrying =>
      'Verbindung verloren, neuer Versuch';

  @override
  String get sshStatusDisconnectedManual => 'Getrennt';

  @override
  String get sshStatusHostKeyChanged =>
      'Host-Schlüssel geändert – Verbindung verweigert';

  @override
  String get sshKeepAliveNotificationTitle =>
      'Valhalla hält Ihre Sitzungen aktiv';

  @override
  String get terminalTmuxMissingNotice =>
      'tmux nicht gefunden – Sitzungen überstehen keinen Verbindungsabbruch';

  @override
  String get terminalTmuxSessionRestored =>
      'Terminal-Sitzung wiederhergestellt';

  @override
  String get moshSectionTitle => 'Mosh';

  @override
  String get moshEnable =>
      'Mosh aktivieren – ein Roaming-Terminal, das Verbindungsabbrüche und IP-Wechsel übersteht';

  @override
  String get moshServerPathLabel => 'mosh-server Pfad';

  @override
  String get moshPortRangeLabel => 'UDP-Portbereich';

  @override
  String get moshNewSession => 'Neue Mosh-Sitzung';

  @override
  String get moshNotInstalled =>
      'mosh-server wurde auf dem Remote-Server nicht gefunden. Installieren Sie es mit: sudo apt install mosh (Debian/Ubuntu) oder sudo dnf install mosh (Fedora/RHEL).';

  @override
  String moshBootstrapFailed(String detail) {
    return 'Mosh-Sitzung konnte nicht gestartet werden: $detail';
  }

  @override
  String get moshUdpTimeout =>
      'Mosh-Verbindung zeitüberschritten – prüfen Sie, ob UDP-Verkehr nicht durch eine Firewall blockiert wird.';

  @override
  String get moshSessionTag => 'mosh';

  @override
  String get acpSessionRestored => 'Agenten-Sitzung wiederhergestellt';

  @override
  String get acpSessionRestartNotice =>
      'Agenten-Sitzung neu gestartet – vorheriger Kontext nicht verfügbar';

  @override
  String get terminalTmuxInstallDialogTitle =>
      'tmux auf Remote-Server installieren?';

  @override
  String get terminalTmuxInstallDialogMessage =>
      'tmux ist erforderlich, um Terminal-Sitzungen bei Verbindungsabbrüchen beizubehalten. Möchten Sie es jetzt installieren?';

  @override
  String get terminalTmuxInstallCommandLabel => 'Auszuführender Befehl:';

  @override
  String get terminalTmuxInstallUnsupported =>
      'Kein unterstützter Paketmanager auf dem Remote-Server erkannt. Bitte installieren Sie tmux manuell.';

  @override
  String get terminalTmuxInstallFailed =>
      'tmux-Installation fehlgeschlagen. Bitte Serverberechtigungen und Netzwerk überprüfen.';

  @override
  String get terminalTmuxInstallDisconnected =>
      'SSH-Verbindung unterbrochen. Bitte neu verbinden, um tmux zu installieren.';

  @override
  String get terminalTmuxInstallInstalling => 'tmux wird installiert...';

  @override
  String get terminalTmuxInstallConfirm => 'tmux installieren';

  @override
  String get terminalTmuxInstallSkip => 'Überspringen (Einfache Shell nutzen)';

  @override
  String get sftpDownload => 'Herunterladen';

  @override
  String get sftpOpen => 'Öffnen';

  @override
  String get sftpUploadFailed =>
      'Upload fehlgeschlagen. Berechtigungen prüfen und erneut versuchen.';

  @override
  String get sftpDownloadFailed => 'Download fehlgeschlagen';

  @override
  String get sftpOpenUnsupported =>
      'Dieses Dateiformat kann nicht geöffnet werden.';

  @override
  String get sftpReadFailed =>
      'Datei konnte nicht gelesen werden. Berechtigungen prüfen und erneut versuchen.';

  @override
  String get sftpTransferFailed =>
      'Dateivorgang fehlgeschlagen. Bitte erneut versuchen.';

  @override
  String get sftpDownloadSuccess => 'Erfolgreich heruntergeladen';

  @override
  String get sftpUploading => 'Wird hochgeladen...';

  @override
  String get sftpDownloading => 'Wird heruntergeladen...';

  @override
  String get sftpUpDirectory => 'In übergeordneten Ordner wechseln';

  @override
  String get sftpShowHiddenFiles => 'Versteckte Dateien anzeigen';

  @override
  String get sftpHideHiddenFiles => 'Versteckte Dateien ausblenden';

  @override
  String get sftpHiddenPreferenceSaveFailed =>
      'Einstellung für versteckte Dateien konnte nicht gespeichert werden';

  @override
  String get sftpSymlink => 'Symlink';

  @override
  String get sftpLinkTargetUnavailable =>
      'Symlink-Ziel ist ungültig oder nicht verfügbar';

  @override
  String get sftpLinkTargetPermissionDenied =>
      'Zugriff auf Symlink-Ziel verweigert';

  @override
  String get settingsAutoConnect => 'Beim Start automatisch verbinden';

  @override
  String get settingsAutoConnectFixed => 'Fester Standard-SSH-Server';

  @override
  String get settingsAutoConnectFixedDesc =>
      'Immer mit dem unten ausgewählten Server verbinden';

  @override
  String get settingsAutoConnectLast => 'Letzte Verbindung merken';

  @override
  String get settingsAutoConnectLastDesc =>
      'Mit dem Server verbinden, der zuletzt erfolgreich verbunden war';

  @override
  String get settingsAutoConnectPickServer => 'Server';

  @override
  String get settingsAutoConnectNoServer => 'Noch kein Server ausgewählt';

  @override
  String get sftpSort => 'Sortieren';

  @override
  String get sftpSortName => 'Name';

  @override
  String get sftpSortSize => 'Größe';

  @override
  String get sftpSortDate => 'Änderungsdatum';

  @override
  String get sftpSortAscending => 'Aufsteigend';

  @override
  String get sftpSortDescending => 'Absteigend';

  @override
  String get themeQuickSwitch => 'Design';

  @override
  String get transferList => 'Übertragungen';

  @override
  String get transferEmpty => 'Noch keine Übertragungen';

  @override
  String get transferUpload => 'Upload';

  @override
  String get transferDownload => 'Download';

  @override
  String get transferStatusQueued => 'In Warteschlange';

  @override
  String get transferStatusRunning => 'Wird übertragen';

  @override
  String get transferStatusPaused => 'Pausiert';

  @override
  String get transferStatusCompleted => 'Abgeschlossen';

  @override
  String get transferStatusFailed => 'Fehlgeschlagen';

  @override
  String get transferStatusCanceled => 'Abgebrochen';

  @override
  String get transferPause => 'Pausieren';

  @override
  String get transferResume => 'Fortsetzen';

  @override
  String get transferCancel => 'Abbrechen';

  @override
  String get transferRemove => 'Entfernen';

  @override
  String get transferClearFinished => 'Abgeschlossene leeren';

  @override
  String get transferSizeUnknown => 'Größe unbekannt';

  @override
  String get transferFailedUpload => 'Upload fehlgeschlagen';

  @override
  String get transferFailedDownload => 'Download fehlgeschlagen';

  @override
  String get stopGeneration => 'Stoppen';

  @override
  String get chatServerBindingRequired =>
      'Diese Sitzung ist an keinen Server gebunden. Bitte binden Sie sie an den aktuellen Server, um fortzufahren.';

  @override
  String get chatSessionUnboundNotice =>
      'Diese Sitzung ist an keinen Server gebunden.';

  @override
  String get bindServerAction => 'Server binden';

  @override
  String get bindServerDialogTitle => 'Sitzung an Server binden';

  @override
  String get bindServerConfirmAction => 'Bindung bestätigen';

  @override
  String get chatSessionIdentityMismatch =>
      'Aktueller Server oder Agent stimmt nicht mit der gebundenen Identität dieser Sitzung überein. Wechseln Sie zum passenden Server und Agenten, um fortzufahren.';

  @override
  String get deleteSessionTitle => 'Sitzung löschen';

  @override
  String get deleteSessionConfirmAction => 'Löschen';

  @override
  String get shareAgentSessionsTitle => 'Agenten-Sitzungen teilen';

  @override
  String get shareAgentSessionsSubtitle =>
      'Sitzungen über verschiedene Agenten auf diesem Server hinweg teilen';

  @override
  String get shareAgentSessionsEnabled =>
      'Teilen von Agenten-Sitzungen aktiviert';

  @override
  String get shareAgentSessionsDisabled =>
      'Teilen von Agenten-Sitzungen deaktiviert';

  @override
  String get agentCliStatusInstalled => 'CLI: Installiert';

  @override
  String get agentCliStatusMissing => 'CLI: Fehlt';

  @override
  String get agentCliStatusChecking => 'CLI: Wird geprüft...';

  @override
  String get agentCliStatusUnknown => 'CLI: Unbekannt';

  @override
  String get agentCliStatusError => 'CLI: Fehler';

  @override
  String get agentAcpStatusReady => 'ACP: Bereit';

  @override
  String get agentAcpStatusMissing => 'ACP: Fehlt';

  @override
  String get agentAcpStatusChecking => 'ACP: Wird geprüft...';

  @override
  String get agentAcpStatusPendingCli => 'ACP: Wartet auf CLI';

  @override
  String get agentAcpStatusUnknown => 'ACP: Unbekannt';

  @override
  String get agentAcpStatusError => 'ACP: Fehler';

  @override
  String get agentAcpStatusNa => 'ACP: N/A';

  @override
  String get agentAuthStatusAuthenticated => 'Auth: Angemeldet';

  @override
  String get agentAuthStatusUnauthenticated => 'Auth: Nicht angemeldet';

  @override
  String get agentAuthStatusUnknown => 'Auth: Unbekannt';

  @override
  String get downloadNotificationsUnavailable =>
      'System-Download-Benachrichtigungen sind nicht verfügbar. Downloads werden im Hintergrund fortgesetzt.';

  @override
  String get downloadOpenFailed =>
      'Heruntergeladene Datei konnte nicht geöffnet werden.';

  @override
  String get dockerActionPending =>
      'Für diesen Container läuft bereits eine Aktion';

  @override
  String get dockerNoLogs => '(Keine Protokolle)';

  @override
  String get serverReboot => 'Neu starten';

  @override
  String get serverRebootDialogTitle => 'Server-Neustart bestätigen';

  @override
  String get serverRebootDialogMessage =>
      'Möchten Sie diesen Server wirklich neu starten? Alle aktiven Verbindungen und Hintergrunddienste werden beendet.';

  @override
  String get serverRebootConfirmButton => 'Jetzt neu starten';

  @override
  String get serverRebootPasswordTitle => 'Sudo-Passwort erforderlich';

  @override
  String get serverRebootPasswordMessage =>
      'Root-Rechte sind zum Neustarten des Servers erforderlich. Bitte geben Sie das Sudo-Passwort ein (wird einmalig verwendet, nicht gespeichert):';

  @override
  String get serverRebootPasswordHint => 'Sudo-Passwort';

  @override
  String get serverRebootSubmitting => 'Neustartbefehl wird gesendet...';

  @override
  String get serverRebootAccepted =>
      'Neustartbefehl akzeptiert; Abschluss noch nicht verifiziert. Bitte neu verbinden, sobald der Server wieder online ist.';

  @override
  String get serverRebootVerified =>
      'Server-Neustart wurde verifiziert; das System ist wieder online.';

  @override
  String get serverRebootUnknown =>
      'Neustartergebnis ist unbestimmt. Der Befehl wurde abgesetzt, aber der Abschluss konnte nicht bestätigt werden. Bitte Verbindung manuell prüfen.';

  @override
  String get serverRebootReconnect => 'Neu verbinden';

  @override
  String get serverRebootServerChanged =>
      'Zielserver geändert, Neustart abgebrochen';

  @override
  String get navCliChat => 'CLI-Chat';

  @override
  String get cliChatTitle => 'CLI-Sitzungen';

  @override
  String get cliChatSubtitle =>
      'Native CLI-Agenten-Sitzungen auf dem Remote-Server';

  @override
  String get cliSelectAgent => 'Agent auswählen';

  @override
  String get cliNoAgentsConfigured =>
      'Keine Agenten für diesen Server hinzugefügt';

  @override
  String get cliAgentNeedsSetup =>
      'Agenten-Umgebung fehlt oder nicht angemeldet';

  @override
  String get cliManageAgentsGuide => 'In der Agenten-Verwaltung konfigurieren';

  @override
  String get cliNewDraft => 'Neuer Entwurf';

  @override
  String get cliNewDraftTooltip =>
      'Leeren Entwurf erstellen (Sitzung wird bei erster Nachricht erstellt)';

  @override
  String get cliDeleteSessionTitle => 'Remote-CLI-Sitzungsverlauf löschen';

  @override
  String get cliDeleteSessionMessage =>
      'Dadurch wird der CLI-Sitzungsverlauf auf dem Remote-Server dauerhaft gelöscht. Möchten Sie wirklich fortfahren?';

  @override
  String get cliDeleteConfirmButton => 'Sitzung löschen';

  @override
  String get cliCannotDeleteTooltip =>
      'Löschen von Remote-Sitzungen nicht unterstützt oder deaktiviert';

  @override
  String get cliSessionsHeader => 'Sitzungen';

  @override
  String get cliNoSessions => 'Keine CLI-Sitzungen gefunden';

  @override
  String get cliFilterCwdHint => 'Nach Arbeitsverzeichnis (CWD) filtern...';

  @override
  String get cliFilterCwdAction => 'Filtern';

  @override
  String get cliClearCwdAction => 'Leeren';

  @override
  String get cliLoadMoreSessions => 'Weitere Sitzungen laden';

  @override
  String get cliRefreshSessions => 'Aktualisieren';

  @override
  String get cliClaudeReadOnlyNotice =>
      'Claude-Verlauf ist schreibgeschützt. Setzen Sie die Unterhaltung im echten Terminal fort.';

  @override
  String get cliContinueInTerminal => 'Im Terminal fortsetzen';

  @override
  String get cliOpenTerminal => 'Terminal öffnen';

  @override
  String get cliCloseTerminal => 'Terminal schließen';

  @override
  String get cliTerminalRunning => 'Interaktives CLI-Terminal';

  @override
  String get cliAgyTerminalOnlyNotice =>
      'Dieser Agent unterstützt keine strukturierte Verlaufssynchronisierung. Bitte nutzen Sie das native CLI-Terminal für Interaktion und Sitzungsauswahl.';

  @override
  String get cliInstallSdkTitle =>
      'Offizielles Claude History SDK installieren';

  @override
  String get cliInstallSdkMessage =>
      'Das offizielle Claude Code History SDK fehlt auf dem Remote-Server. Möchten Sie es jetzt installieren?';

  @override
  String get cliInstallSdkAction => 'Offizielles SDK installieren';

  @override
  String get cliApprovalsTitle => 'Ausstehende Genehmigungen';

  @override
  String get cliApprovalDetails => 'Details';

  @override
  String get cliApprovalAllow => 'Erlauben';

  @override
  String get cliApprovalDecline => 'Ablehnen';

  @override
  String get cliInputHint => 'Nachricht an den CLI-Agenten eingeben...';

  @override
  String get cliSend => 'Senden';

  @override
  String get cliStop => 'Stoppen';

  @override
  String get cliBusy => 'Vorgang läuft, bitte warten...';

  @override
  String get cliDisconnected => 'SSH ist nicht verbunden';

  @override
  String get cliServerChanged => 'Zielserver geändert';

  @override
  String get cliTurnFailed => 'Ausführung des CLI-Zuges fehlgeschlagen';

  @override
  String get cliUseTerminal =>
      'Interaktive Eingabe erforderlich, bitte Terminal zum Fortfahren öffnen';

  @override
  String get cliDeleteFailed => 'Remote-Sitzung konnte nicht gelöscht werden';

  @override
  String get cliDeleteUnsupported =>
      'Löschen von Remote-Sitzungen wird von diesem CLI nicht unterstützt';

  @override
  String get cliOperationFailed => 'CLI-Vorgang fehlgeschlagen';

  @override
  String get cliHistorySdkMissing =>
      'Offizielles History-SDK fehlt auf dem Server';

  @override
  String get cliHistoryRuntimeMissing =>
      'Claude-Verlauf erfordert Node.js/npm auf dem Server. Bitte installieren Sie Node.js manuell; Sie können weiterhin das echte CLI im Terminal nutzen.';

  @override
  String get cliLoginRequired =>
      'Agenten-Anmeldung erforderlich. Bitte über die Agenten-Verwaltung anmelden.';

  @override
  String get cliNotInstalled =>
      'Agenten-CLI nicht installiert. Bitte über die Agenten-Verwaltung installieren.';

  @override
  String get cliVersionUnsupported =>
      'Agenten-CLI-Version wird nicht unterstützt. Bitte über die Agenten-Verwaltung aktualisieren oder neu installieren.';

  @override
  String get settingsNavigation => 'Navigation';

  @override
  String get settingsNavigationDesc =>
      'Standard-Startseite und untere Navigationsleiste konfigurieren';

  @override
  String get settingsStartupPage => 'Startseite';

  @override
  String get settingsStartupPageDesc =>
      'Seite, die beim Öffnen der App angezeigt wird';

  @override
  String get settingsBottomNav => 'Untere Navigationsleiste';

  @override
  String get settingsBottomNavDesc =>
      'Bereiche auswählen, die in der mobilen unteren Leiste angezeigt werden (unterstützt 0 bis 9 Elemente)';

  @override
  String get settingsResetSuccess =>
      'Alle Einstellungen auf Standardwerte zurückgesetzt';

  @override
  String get metricsTrendSubtitle => 'Letzte ~3 Minuten (bis zu 60 Messpunkte)';

  @override
  String get metricsCurrent => 'Aktuell';

  @override
  String get metricsPeak => 'Spitze';

  @override
  String get metricsValley => 'Tiefstwert';

  @override
  String get metricsTrendWaiting => 'Metrikdaten werden gesammelt...';

  @override
  String get metricsTrendStopped => 'Datenerfassung gestoppt (SSH getrennt)';

  @override
  String get dockerActionTerminal => 'Exec-Terminal';

  @override
  String get dockerTerminalTitle => 'Container-Terminal';

  @override
  String get dockerTerminalNotRunning => 'Container läuft nicht';

  @override
  String get setDefaultAgent => 'Als Standard festlegen';

  @override
  String get defaultBadge => 'Standard';

  @override
  String get isDefaultAgent => 'Standard-Agent';

  @override
  String get setAsDefaultAgent =>
      'Als Standard-Agent für diesen Server festlegen';

  @override
  String get agentGroupBasic => 'Grundlegende Informationen';

  @override
  String get agentGroupCommands => 'Befehle';

  @override
  String get agentGroupAuth => 'Installation & Authentifizierung';

  @override
  String get agentPresetTitle => 'Vordefinierte Vorlage';

  @override
  String get resourceProcessList => 'Prozesse';

  @override
  String get resourceDiskScanning =>
      'Root-Verzeichnisse werden gescannt, dies kann einige Sekunden dauern...';

  @override
  String get resourceDiskScanPartial =>
      'Einige Verzeichnisse konnten aufgrund von Berechtigungen oder Zeitüberschreitung nicht gescannt werden';

  @override
  String get resourceDiskDirectories =>
      'Belegung der Verzeichnisse oberster Ebene';

  @override
  String get resourceSortCpu => 'Nach CPU sortieren';

  @override
  String get resourceSortMemory => 'Nach Speicher sortieren';

  @override
  String get resourceRss => 'RSS-Speicher';

  @override
  String get resourceUsed => 'Belegt';

  @override
  String get resourceAvailable => 'Verfügbar';

  @override
  String get resourceTotal => 'Gesamt';

  @override
  String get settingsBottomNavOrderTitle =>
      'Ausgewählte Elemente (Zum Neuanordnen ziehen)';

  @override
  String get langSystem => 'Systemstandard';

  @override
  String get serverFieldRequired => 'Erforderlich';

  @override
  String get serverPortInvalid => 'Port muss zwischen 1 und 65535 liegen';

  @override
  String get serverTestReachability => 'Erreichbarkeit testen';

  @override
  String get serverSaveFailedGeneric =>
      'Server konnte nicht gespeichert werden. Konfiguration prüfen und erneut versuchen.';

  @override
  String get serverViewPrivateKey => 'Privaten Schlüssel anzeigen';

  @override
  String get serverHidePrivateKey => 'Privaten Schlüssel verbergen';

  @override
  String get dockerBashFallbackNotice =>
      'Bash ist im Container nicht verfügbar, Fallback auf Sh';

  @override
  String get dockerShellLabel => 'Shell';

  @override
  String get dockerShellBash => 'Bash';

  @override
  String get dockerShellSh => 'Sh';

  @override
  String get cliDraftWorkingDirLabel => 'Arbeitsverzeichnis';

  @override
  String get cliDefaultWorkingDir => 'Standard (/)';

  @override
  String get cliPickWorkingDirTitle => 'Arbeitsverzeichnis auswählen';

  @override
  String get cliClearWorkingDir => 'Auf Standard zurücksetzen';

  @override
  String get cliBrowseWorkingDir => 'Durchsuchen';

  @override
  String get cliSelectCurrentDir => 'Dieses Verzeichnis auswählen';

  @override
  String get cliNavigateUp => 'Nach oben';

  @override
  String get chatSessionsTooltip => 'Sitzungen';

  @override
  String get hardwareSpecsTitle => 'Hardware & System';

  @override
  String get hardwareCpu => 'CPU';

  @override
  String get hardwareMemory => 'Speicher';

  @override
  String get hardwareDisk => 'Root-Festplatte';

  @override
  String get hardwareDistribution => 'Betriebssystem';

  @override
  String get hardwareKernel => 'Kernel';

  @override
  String get hardwareLoading => 'Hardware-Spezifikationen werden geladen...';

  @override
  String get hardwareUnavailable => 'Hardware-Spezifikationen nicht verfügbar';

  @override
  String get hardwareUnknown => 'Unbekannt';

  @override
  String get systemInfoTitle => 'Systeminformationen';

  @override
  String get systemInfoTapHint => 'Tippen, um ASCII-Art anzuzeigen';

  @override
  String get systemInfoHost => 'Host';

  @override
  String get serverShutdown => 'Herunterfahren';

  @override
  String get serverShutdownDialogTitle => 'Server-Herunterfahren bestätigen';

  @override
  String get serverShutdownDialogMessage =>
      'Möchten Sie diesen Server wirklich herunterfahren? Das System wird vollständig ausgeschaltet und kann remote nicht erreicht werden, bis es manuell eingeschaltet wird.';

  @override
  String get serverShutdownConfirmButton => 'Jetzt herunterfahren';

  @override
  String get serverShutdownSubmitting =>
      'Befehl zum Herunterfahren wird gesendet...';

  @override
  String get serverShutdownAccepted =>
      'Befehl zum Herunterfahren akzeptiert; Abschluss des Herunterfahrens wurde nicht verifiziert.';

  @override
  String get serverShutdownUnknown =>
      'Ergebnis des Herunterfahrens unbekannt: Der Befehl wurde möglicherweise gesendet, konnte aber nicht bestätigt werden. Bitte manuell prüfen; es erfolgt kein automatischer Neuversuch.';

  @override
  String get serverShutdownPasswordTitle =>
      'Sudo-Passwort zum Herunterfahren erforderlich';

  @override
  String get serverShutdownPasswordMessage =>
      'Root-Rechte sind zum Herunterfahren des Servers erforderlich. Bitte geben Sie das Sudo-Passwort ein (wird einmalig verwendet, nicht gespeichert):';

  @override
  String get serverShutdownPasswordHint => 'Sudo-Passwort';

  @override
  String get serverShutdownServerChanged =>
      'Zielserver geändert, Herunterfahren abgebrochen';

  @override
  String get metricsNetwork => 'Netzwerkrate';

  @override
  String get networkModalTitle => 'Details der Netzwerkschnittstellen';

  @override
  String get networkDownloadRate => 'Download (RX)';

  @override
  String get networkUploadRate => 'Upload (TX)';

  @override
  String get networkTotalRx => 'Gesamt RX';

  @override
  String get networkTotalTx => 'Gesamt TX';

  @override
  String get networkPrimary => 'Standardroute';

  @override
  String get networkRatesEmpty =>
      'Keine aktiven Netzwerkschnittstellen erkannt';

  @override
  String get networkWaitingSecondSample => 'Warten auf zweite Messung';

  @override
  String get networkUnavailable => 'Nicht verfügbar';

  @override
  String get networkNoDefaultInterface => 'Keine Standardroute';

  @override
  String get selectThemeModeTitle => 'Designmodus auswählen';

  @override
  String get selectLanguageTitle => 'Sprache auswählen';

  @override
  String get selectStartupPageTitle => 'Startseite auswählen';

  @override
  String get selectAutoConnectModeTitle =>
      'Modus für automatisches Verbinden auswählen';

  @override
  String get accentColorDialogTitle => 'Akzentfarben anpassen';

  @override
  String get accentColorLightMode => 'Heller Modus';

  @override
  String get accentColorDarkMode => 'Dunkler Modus';

  @override
  String get accentColorAmoledMode => 'AMOLED (Geek)';

  @override
  String get accentColorPresets => 'Voreinstellungen';

  @override
  String get accentColorHsvPicker => 'Farbrad';

  @override
  String get accentColorHexCode => 'Hex-Farbwert';

  @override
  String get accentColorPreview => 'Vorschau';

  @override
  String get accentColorSampleButton => 'Akzent-Schaltfläche';

  @override
  String get accentColorInvalidHex => 'Ungültiges Hex-Format (z. B. #10B981)';

  @override
  String get settingsDashboardQuickActions => 'Dashboard-Schnellaktionen';

  @override
  String get settingsDashboardQuickActionsDesc =>
      'Schnellzugriffselemente auf dem Dashboard konfigurieren. Durch Leeren wird der Bereich für Schnellaktionen ausgeblendet.';

  @override
  String get settingsDashboardQuickActionsEmpty =>
      'Schnellaktionen ausgeblendet (keine Verknüpfungen ausgewählt)';

  @override
  String get settingsDashboardQuickActionsOrderTitle =>
      'Verknüpfungen zum Neuanordnen ziehen';

  @override
  String get settingsDashboardQuickActionsCandidates =>
      'Sichtbare Verknüpfungen auswählen';

  @override
  String get terminalCopySelection => 'Kopieren';

  @override
  String get terminalSelectionCopied => 'Auswahl in die Zwischenablage kopiert';

  @override
  String get editAgent => 'Agent bearbeiten';

  @override
  String get agentExecutionTarget => 'Ausführungsumgebung';

  @override
  String get agentExecutionHost => 'Host-System';

  @override
  String get agentExecutionDocker => 'Docker-Container';

  @override
  String get agentContainerBinding => 'Container-Bindungsmodus';

  @override
  String get agentContainerBindingId => 'Nach Container-ID';

  @override
  String get agentContainerBindingName => 'Nach Container-Name';

  @override
  String get agentContainerReference => 'Zielcontainer';

  @override
  String get agentContainerReferenceHint =>
      'Container-ID oder -Name auswählen oder eingeben';

  @override
  String get agentContainerRequired =>
      'Zielcontainer ist für Docker-Ausführung erforderlich';

  @override
  String get agentLoadingContainers =>
      'Container auf Server werden abgefragt...';

  @override
  String get agentNoContainersFound =>
      'Keine Container auf diesem Server gefunden';

  @override
  String get agentContainerUser => 'Container-Ausführungsbenutzer (Optional)';

  @override
  String get agentContainerUserHint => 'z. B. dev';

  @override
  String get agentContainerUserHelper =>
      'Leer lassen, um den Standardbenutzer des Images zu verwenden; z. B. dev; unterstützt user, UID, user:group, UID:GID';

  @override
  String get agentContainerUserSelect => 'Container-Benutzer auswählen';

  @override
  String get agentContainerUsersLoading => 'Benutzer werden geladen...';

  @override
  String get agentContainerUsersEmpty => 'Keine Passwd-Benutzer gefunden';

  @override
  String get agentViewDiagnosticLog => 'Diagnoseprotokoll anzeigen';

  @override
  String get agentDiagnosticLogCopied =>
      'Diagnoseprotokoll in Zwischenablage kopiert';

  @override
  String get agentDiagnosticLogCopy => 'Kopieren';

  @override
  String get agentDiagnosticLogClose => 'Schließen';

  @override
  String get settingsCliHistoryPageSize => 'CLI-Verlauf Seitengröße';

  @override
  String get settingsCliHistoryPageSizeDesc =>
      'Anzahl älterer Nachrichten, die beim Nach-oben-Scrollen pro Seite geladen werden (5-100)';

  @override
  String get settingsCliHistoryPageSizeTitle =>
      'CLI-Verlauf Seitengröße auswählen';

  @override
  String get cliLoadingOlderMessages => 'Ältere Nachrichten werden geladen...';

  @override
  String get chatLoadOlderMessages => 'Frühere Nachrichten laden';

  @override
  String get chatCommandsTooltip => 'Befehle';

  @override
  String get chatAttachTooltip => 'Datei anhängen';

  @override
  String get chatAttachImage => 'Lokales Bild anhängen';

  @override
  String get chatAttachLocalText => 'Lokale Textdatei anhängen';

  @override
  String get chatAttachRemoteText => 'Remote-Textdatei anhängen';

  @override
  String get chatAttachRemotePathTitle => 'Remote-Textdatei anhängen';

  @override
  String get chatAttachRemotePathHint => '/pfad/zur/datei.txt';

  @override
  String get chatAttachTooLarge => 'Datei überschreitet die Größenbeschränkung';

  @override
  String get chatUsageAndDiagnostics => 'Nutzung & Diagnose';

  @override
  String get chatWorkingDirTooltip => 'Arbeitsverzeichnis des Entwurfs';

  @override
  String get chatAttachFailed => 'Datei konnte nicht angehängt werden';

  @override
  String get chatInvalidRemotePath =>
      'Ungültiger Remote-Dateipfad (muss mit / beginnen)';

  @override
  String get chatRemoteReadFailed => 'Remote-Datei konnte nicht gelesen werden';

  @override
  String get chatInvalidDirPath =>
      'Ungültiger Verzeichnispfad (muss mit / beginnen)';

  @override
  String get chatNoSubdirectories => 'Keine Unterverzeichnisse';

  @override
  String get chatUsageTitle => 'Token- & Kostenverbrauch';

  @override
  String get chatUsageUsed => 'Verwendete Tokens';

  @override
  String get chatUsageSize => 'Kontextgröße';

  @override
  String get chatUsageCost => 'Kosten';

  @override
  String get chatDiagnosticsTitle => 'Diagnoseprotokoll';

  @override
  String get chatNoDiagnostics => 'Keine Diagnoseprotokolle verfügbar';

  @override
  String get deleteSessionLocalOnlyNotice =>
      'Dies entfernt nur den lokalen Eintrag in Valhalla und löscht nicht den nativen Agenten-Sitzungsverlauf auf dem Server.';

  @override
  String get chatSearchSessionsHint => 'Sitzungen suchen...';

  @override
  String get chatLoadMoreSessions => 'Weitere Sitzungen laden';

  @override
  String get chatLoadingMoreSessions => 'Weitere Sitzungen werden geladen...';

  @override
  String get chatExportSession => 'Sitzung exportieren (Markdown)';

  @override
  String get chatExportSuccess => 'Sitzung erfolgreich exportiert';

  @override
  String get chatExportFailed => 'Sitzung konnte nicht exportiert werden';

  @override
  String get chatRemoteSessions => 'Remote-Sitzungen';

  @override
  String get chatRemoteSessionsTitle => 'Remote-Agenten-Sitzungen';

  @override
  String get chatRemoteSessionsDesc =>
      'Natives Sitzungsprotokoll des Remote-Agenten anzeigen und importieren';

  @override
  String get chatRemoteSessionsEmpty => 'Keine Remote-Sitzungen gefunden';

  @override
  String get chatRemoteImporting => 'Remote-Sitzungsverlauf wird importiert...';

  @override
  String get chatRemoteImportFailed =>
      'Remote-Sitzung konnte nicht importiert werden';

  @override
  String get chatStatusInterrupted => 'Unterbrochen';

  @override
  String get chatStatusFailed => 'Fehlgeschlagen';

  @override
  String get chatStatusAwaitingAuth => 'Wartet auf ACP-Authentifizierung';

  @override
  String get chatShowFullOutput => 'Vollständige Ausgabe anzeigen';

  @override
  String get chatShowLessOutput => 'Weniger anzeigen';

  @override
  String get chatToolLocations => 'Betroffene Pfade';

  @override
  String cmdParamPlaceholder(String param) {
    return 'Wert für $param eingeben';
  }

  @override
  String processTerminateSuccess(Object pid) {
    return 'Prozess $pid beendet';
  }

  @override
  String serviceActionSuccess(Object action, Object service) {
    return 'Aktion $action auf $service erfolgreich';
  }

  @override
  String riskPatternMatched(Object pattern) {
    return 'Ausgelöste Regel: $pattern';
  }

  @override
  String stateExitCode(Object code) {
    return 'Exit-Code: $code';
  }

  @override
  String sshConnectedSuccess(Object server) {
    return 'Erfolgreich mit $server über SSH verbunden';
  }

  @override
  String sshConnectionFailed(Object error) {
    return 'SSH-Verbindung fehlgeschlagen: $error';
  }

  @override
  String trustHostFingerprintMessage(
    Object fingerprint,
    Object host,
    Object type,
  ) {
    return 'Verbindung mit $host ($type) zum ersten Mal.\n\nSHA-256 Fingerabdruck:\n$fingerprint\n\nDiesem Fingerabdruck vertrauen und verbinden?';
  }

  @override
  String enterPasswordTitle(Object server) {
    return 'Passwort für $server eingeben';
  }

  @override
  String confirmDeleteServerMessage(Object name) {
    return 'Möchten Sie den Server \'$name\' wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.';
  }

  @override
  String deleteAgentMessage(Object name) {
    return 'Möchten Sie den Agenten \'$name\' wirklich löschen? Dies entfernt seine Konfiguration und seinen Laufzeitstatus auf diesem Server, ohne historische Chat-Sitzungen oder SSH-Zugangsdaten zu beeinträchtigen.';
  }

  @override
  String agentLastChecked(Object time) {
    return 'Zuletzt geprüft: $time';
  }

  @override
  String agentAuthPickerTitle(Object agent) {
    return 'Anmeldemethode für $agent auswählen';
  }

  @override
  String sshStatusReconnecting(Object n) {
    return 'Verbindung wird wiederhergestellt… (Versuch $n)';
  }

  @override
  String sshKeepAliveNotificationBody(Object n) {
    return '$n aktive Sitzung(en)';
  }

  @override
  String bindServerConfirmMessage(Object serverName) {
    return 'Diese Sitzung an Server \\\"$serverName\\\" binden? Nach dem Binden wird diese Sitzung diesem Server zugeordnet.';
  }

  @override
  String deleteSessionConfirmMessage(Object title) {
    return 'Möchten Sie die Sitzung \\\"$title\\\" wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.';
  }

  @override
  String dockerActionSuccess(Object action, Object name) {
    return 'Container $name $action erfolgreich';
  }

  @override
  String dockerActionFailed(Object error) {
    return 'Aktion fehlgeschlagen: $error';
  }

  @override
  String serverRebootTarget(Object address, Object name) {
    return 'Zielserver: $name ($address)';
  }

  @override
  String serverRebootRunningTerminals(Object count) {
    return 'Terminal-Sitzungen: $count';
  }

  @override
  String serverRebootRunningAgents(Object count) {
    return 'Agenten-Sitzungen: $count';
  }

  @override
  String serverRebootRunningTransfers(Object count) {
    return 'Aktive Übertragungen: $count';
  }

  @override
  String serverRebootFailed(Object error) {
    return 'Neustart fehlgeschlagen: $error';
  }

  @override
  String cliDeleteFailedWithDetail(Object detail) {
    return 'Löschen der Remote-Sitzung fehlgeschlagen: $detail';
  }

  @override
  String metricsTrendTitle(Object metric) {
    return '$metric-Trend';
  }

  @override
  String metricsThresholdWarning(Object value) {
    return 'Warnung: $value';
  }

  @override
  String metricsThresholdDanger(Object value) {
    return 'Gefahr: $value';
  }

  @override
  String metricsHistoryPoints(Object count) {
    return '$count Messpunkte';
  }

  @override
  String resourceUsageTitle(Object metric) {
    return '$metric-Ressourcennutzung';
  }

  @override
  String serverPortReachable(Object port) {
    return 'TCP-Port $port erreichbar';
  }

  @override
  String serverConnectionFailed(Object error) {
    return 'Verbindung fehlgeschlagen: $error';
  }

  @override
  String serverSaveFailed(Object error) {
    return 'Server konnte nicht gespeichert werden: $error';
  }

  @override
  String hardwareCpuCores(Object cores) {
    return '$cores Kerne';
  }

  @override
  String serverShutdownFailed(Object error) {
    return 'Herunterfahren fehlgeschlagen: $error';
  }

  @override
  String networkInterface(Object name) {
    return 'Schnittstelle: $name';
  }

  @override
  String agentContainersLoadFailed(Object error) {
    return 'Container konnten nicht geladen werden: $error';
  }

  @override
  String agentContainerUsersFailed(Object error) {
    return 'Container-Benutzer konnten nicht geladen werden: $error';
  }

  @override
  String agentDiagnosticLogTitle(Object name) {
    return 'Diagnoseprotokoll - $name';
  }

  @override
  String get agentDockerDetectionFailed =>
      'Docker-/Container-Erkennung fehlgeschlagen';

  @override
  String get chatCopiedAllMessages => 'Alle Nachrichten kopiert';

  @override
  String get chatCopyAllMessages => 'Alle Nachrichten kopieren';

  @override
  String get cliModelAtCapacity =>
      'Das ausgewählte Modell ist ausgelastet. Versuchen Sie ein anderes Modell.';

  @override
  String get chatLaunchBlankDraft => 'Leerer Entwurf';

  @override
  String get chatLaunchFixedSession => 'Feste Sitzung';

  @override
  String get chatLaunchRememberLast => 'Letzte Sitzung merken';

  @override
  String get chatPermissionAskEveryTime => 'Jedes Mal nachfragen';

  @override
  String get chatPermissionAutoAllowAll => 'Alle automatisch erlauben';

  @override
  String get chatPermissionAutoAllowAllConfirmMessage =>
      'Der Agent führt alle Operationen ohne Nachfragen aus. Fortfahren?';

  @override
  String get chatPermissionAutoAllowAllConfirmTitle =>
      'Alle Operationen erlauben?';

  @override
  String get chatPermissionAutoAllowSafe =>
      'Sichere Operationen automatisch erlauben';

  @override
  String get chatRunSettingsDefault => 'Standard';

  @override
  String get chatRunSettingsInteractiveCli => 'Interaktives CLI';

  @override
  String get chatRunSettingsModel => 'Modell';

  @override
  String get chatRunSettingsPermissions => 'Berechtigungen';

  @override
  String get chatRunSettingsReasoning => 'Reasoning-Stufe';

  @override
  String get chatRunSettingsTitle => 'Ausführungseinstellungen';

  @override
  String get cliActionInsertCommand => 'Befehl einfügen';

  @override
  String get cliActionInsertFile => 'Datei einfügen';

  @override
  String get cliActionInsertWorkdir => 'Arbeitsverzeichnis einfügen';

  @override
  String get cliComposerInsertAction => 'Einfügen';

  @override
  String cliOperationFailedWithDetail(String detail) {
    return 'CLI-Vorgang fehlgeschlagen: $detail';
  }

  @override
  String get cliSelectCommandTitle => 'Befehl auswählen';

  @override
  String get defaultAgentTitle => 'Standard-Agent';

  @override
  String get insertSkills => 'Skills einfügen';

  @override
  String get isDefaultSession => 'Standard-Sitzung';

  @override
  String get sessionLaunchMode => 'Sitzungsstartmodus';

  @override
  String get setAsDefaultSession => 'Als Standard-Sitzung festlegen';

  @override
  String get navNas => 'NAS-Medien';

  @override
  String get nasAddExcludePath => 'Ausgeschlossenen Pfad hinzufügen';

  @override
  String get nasAddIncludePath => 'Scan-Pfad hinzufügen';

  @override
  String get nasCancelScan => 'Scan abbrechen';

  @override
  String get nasClearSearch => 'Suche leeren';

  @override
  String get nasConfigDialogTitle => 'Medienbibliothek-Einstellungen';

  @override
  String get nasConfigure => 'Konfigurieren';

  @override
  String get nasConfigureScanDirs => 'Scan-Ordner konfigurieren';

  @override
  String get nasCreatePlaylist => 'Wiedergabeliste erstellen';

  @override
  String get nasEmptyConfigDesc =>
      'Fügen Sie mindestens einen Ordner hinzu, um Ihre Medienbibliothek aufzubauen.';

  @override
  String get nasEmptyConfigTitle => 'Keine Scan-Ordner konfiguriert';

  @override
  String get nasExcludePaths => 'Ausgeschlossene Ordner';

  @override
  String get nasExcludedBadge => 'Ausgeschlossen';

  @override
  String get nasFilterImages => 'Bilder';

  @override
  String get nasFilterVideos => 'Videos';

  @override
  String get nasIncludePaths => 'Scan-Ordner';

  @override
  String nasItemCount(Object value) {
    return '$value Elemente';
  }

  @override
  String nasLastScan(Object value) {
    return 'Letzter Scan: $value';
  }

  @override
  String get nasLibrarySettings => 'Bibliothekseinstellungen';

  @override
  String nasMediaOpening(Object value) {
    return '$value wird geöffnet…';
  }

  @override
  String get nasMiniPlayer => 'Mini-Player';

  @override
  String get nasNoExcludePaths => 'Keine ausgeschlossenen Ordner';

  @override
  String get nasNoFavorites => 'Noch keine Favoriten';

  @override
  String get nasNoIncludePaths => 'Keine Scan-Ordner';

  @override
  String get nasNoIndexDesc =>
      'Konfigurieren Sie Ordner und führen Sie einen Scan aus, um Medien zu indexieren.';

  @override
  String get nasNoIndexTitle => 'Medienbibliothek ist leer';

  @override
  String get nasNoPlaylists => 'Noch keine Wiedergabelisten';

  @override
  String get nasNoSearchResults => 'Keine passenden Medien';

  @override
  String get nasNotScanned => 'Noch nicht gescannt';

  @override
  String get nasNowPlaying => 'Aktuelle Wiedergabe';

  @override
  String get nasOpenMethodPrompt => 'Wie möchten Sie diese Datei öffnen?';

  @override
  String get nasOpenPolicyAsk => 'Jedes Mal nachfragen';

  @override
  String get nasOpenPolicyExternal => 'Mit externer App öffnen';

  @override
  String get nasOpenPolicyInApp => 'In App öffnen';

  @override
  String get nasOpeningPolicy => 'Standard-Öffnungsmethode';

  @override
  String get nasPlaylistName => 'Name der Wiedergabeliste';

  @override
  String get nasQuickStats => 'Bibliotheksübersicht';

  @override
  String get nasScan => 'Jetzt scannen';

  @override
  String get nasScanCancelled => 'Scan abgebrochen';

  @override
  String nasScanFailed(Object value) {
    return 'Scan fehlgeschlagen: $value';
  }

  @override
  String get nasScanning => 'Scan läuft…';

  @override
  String get nasScopeBadge => 'Scan-Bereich';

  @override
  String get nasSearchHint => 'Medien suchen';

  @override
  String get nasStatMusic => 'Musik';

  @override
  String get nasStatPhotos => 'Fotos';

  @override
  String get nasStatTotal => 'Gesamt';

  @override
  String get nasStatVideos => 'Videos';

  @override
  String get nasTabFavorites => 'Favoriten';

  @override
  String get nasTabFolders => 'Ordner';

  @override
  String get nasTabHome => 'Startseite';

  @override
  String get nasTabMusic => 'Musik';

  @override
  String get nasTabPhotos => 'Fotos';

  @override
  String get nasTabPlaylists => 'Wiedergabelisten';

  @override
  String get nasTabVideos => 'Videos';

  @override
  String get nasSources => 'Medienquellen';

  @override
  String get nasAddSource => 'Medienquelle hinzufügen';

  @override
  String get nasEditSource => 'Medienquelle bearbeiten';

  @override
  String get nasRemoveSource => 'Medienquelle entfernen';

  @override
  String nasRemoveSourceConfirm(Object name) {
    return 'Möchten Sie die Medienquelle \'$name\' wirklich entfernen? Dies entfernt deren Konfiguration, ohne Remote-Dateien zu löschen.';
  }

  @override
  String get nasNoSources => 'Keine Medienquellen konfiguriert';

  @override
  String get nasNoSourcesDesc =>
      'Fügen Sie SFTP, SMB, WebDAV, Jellyfin oder Emby hinzu, um Medien zu durchsuchen.';

  @override
  String get nasSourceType => 'Quellentyp';

  @override
  String get nasSourceName => 'Quellenname';

  @override
  String get nasProbe => 'Verbindung testen';

  @override
  String get nasProbeSuccess => 'Verbindung erfolgreich';

  @override
  String get nasProbeFailed => 'Verbindungstest fehlgeschlagen';

  @override
  String get nasEndpoint => 'Endpunkt / URL';

  @override
  String get nasRootPath => 'Root-Pfad';

  @override
  String get nasUsername => 'Benutzername';

  @override
  String get nasPassword => 'Passwort';

  @override
  String get nasDomain => 'Domain (optional)';

  @override
  String get nasAuthenticate => 'Authentifizieren';

  @override
  String get nasAuthSuccess => 'Authentifizierung erfolgreich';

  @override
  String get nasAuthFailed => 'Authentifizierung fehlgeschlagen';

  @override
  String get nasTabDownloads => 'Downloads';

  @override
  String get nasNoDownloads => 'Keine Download-Aufgaben';

  @override
  String get nasDownloadQueued => 'In Warteschlange';

  @override
  String get nasDownloadDownloading => 'Wird heruntergeladen';

  @override
  String get nasDownloadCompleted => 'Abgeschlossen';

  @override
  String get nasDownloadCancelled => 'Abgebrochen';

  @override
  String get nasDownloadFailed => 'Download fehlgeschlagen';

  @override
  String get nasRetryDownload => 'Wiederholen';

  @override
  String get nasCancelDownload => 'Abbrechen';

  @override
  String get nasOpenDownloadedFile => 'Datei öffnen';

  @override
  String get nasQueue => 'Wiedergabewarteschlange';

  @override
  String get nasNoQueue => 'Warteschlange ist leer';

  @override
  String get nasSpeed => 'Geschwindigkeit';

  @override
  String get nasQuality => 'Qualität';

  @override
  String get nasAudioTrack => 'Tonspur';

  @override
  String get nasSubtitleTrack => 'Untertitel';

  @override
  String get nasRepeatOff => 'Wiederholung aus';

  @override
  String get nasRepeatAll => 'Alle wiederholen';

  @override
  String get nasRepeatOne => 'Titel wiederholen';

  @override
  String get nasShuffle => 'Zufallswiedergabe';

  @override
  String get nasCast => 'Streaming (Cast)';

  @override
  String get nasCastUnavailable => 'Keine Streaming-Geräte verfügbar';

  @override
  String get nasSlideshow => 'Diashow';

  @override
  String get nasByFolder => 'Ordner';

  @override
  String get nasByArtist => 'Künstler';

  @override
  String get nasByAlbum => 'Alben';

  @override
  String get nasAllTracks => 'Alle Titel';

  @override
  String get nasPlayAll => 'Alle abspielen';

  @override
  String get nasPreviousPage => 'Zurück';

  @override
  String get nasNextPage => 'Weiter';

  @override
  String get nasClearScope => 'Zurück zu allen';

  @override
  String get nasRenamePlaylist => 'Wiedergabeliste umbenennen';

  @override
  String get nasRemoveFromPlaylist => 'Aus Wiedergabeliste entfernen';

  @override
  String get nasMoveUp => 'Nach oben verschieben';

  @override
  String get nasMoveDown => 'Nach unten verschieben';

  @override
  String get nasSshServer => 'SSH-Server';

  @override
  String get nasSelectSshServer => 'Gespeicherten SSH-Server auswählen';

  @override
  String get nasQualityOriginal => 'Original';

  @override
  String get nasQualityAuto => 'Automatisch';

  @override
  String get nasQuality4Mbps => '4 Mbps';

  @override
  String get nasQuality10Mbps => '10 Mbps';

  @override
  String get nasQuality20Mbps => '20 Mbps';

  @override
  String get nasCastDevices => 'Verfügbare DLNA-Geräte';

  @override
  String get nasCastDiscovering => 'DLNA-Geräte werden gesucht...';

  @override
  String get nasCastRelayingNotice =>
      'Stream wird über Vordergrund-App weitergeleitet. Valhalla geöffnet lassen.';

  @override
  String get nasCastStop => 'Streaming stoppen';

  @override
  String get nasCastVolume => 'Lautstärke';

  @override
  String get nasCastRetry => 'Suche wiederholen';

  @override
  String get nasInstallTitle => 'NAS-Medienserver bereitstellen';

  @override
  String get nasInstallProduct => 'Produkt';

  @override
  String get nasInstallMediaPath => 'Medienverzeichnis (Schreibgeschützt)';

  @override
  String get nasInstallDataRoot => 'Daten- & Konfigurationsverzeichnis';

  @override
  String get nasInstallPort => 'Port';

  @override
  String get nasInstallBindAddress => 'Bind-Adresse';

  @override
  String get nasInstallWebdavUser => 'WebDAV-Benutzername';

  @override
  String get nasInstallWebdavPassword => 'WebDAV-Passwort (mind. 12 Zeichen)';

  @override
  String get nasInstallPreparePlan => 'Bereitstellungsplan prüfen';

  @override
  String get nasInstallPlanTitle => 'Technische Prüfung & Bestätigung';

  @override
  String get nasInstallBlockersTitle => 'Bereitstellungsblocker';

  @override
  String get nasInstallConfirmDeploy => 'Bestätigen & Installieren';

  @override
  String get nasInstallDeploying => 'Container wird bereitgestellt...';

  @override
  String get nasInstallSuccess => 'Erfolgreich bereitgestellt';

  @override
  String get nasInstallSuccessDesc =>
      'Dienst läuft jetzt. Schließen Sie die Ersteinrichtung des Servers ab, bevor Sie ihn als Medienquelle hinzufügen.';

  @override
  String get nasInstallContainerId => 'Container-ID';

  @override
  String get nasInstallEndpoint => 'Endpunkt';

  @override
  String get nasUseSshTunnel => 'SSH-Tunnel verwenden';

  @override
  String get nasUseSshTunnelDesc =>
      'Datenverkehr über einen gespeicherten SSH-Server leiten (z. B. http://127.0.0.1:8096)';

  @override
  String get nasSshTunnelHint =>
      'Endpunkt sollte vom SSH-Server erreichbar sein, z. B. http://127.0.0.1:8096';

  @override
  String get nasKeepEmptyPassword =>
      'Leer lassen, um bestehendes Passwort / Token beizubehalten';

  @override
  String get nasSourceNameRequired => 'Quellenname ist erforderlich';

  @override
  String get nasInvalidEndpoint =>
      'Ungültige Endpunkt-URL oder Protokollschema';

  @override
  String get nasSourceUnreachable => 'Medienquelle kann nicht erreicht werden';

  @override
  String get nasSshTunnelFailed => 'SSH-Tunnelverbindung fehlgeschlagen';

  @override
  String get nasOperationFailed => 'Vorgang fehlgeschlagen';

  @override
  String get nasInstallStepCreateDir => 'Privates Verzeichnis erstellen';

  @override
  String get nasInstallStepWriteCompose =>
      'docker-compose.json-Konfiguration schreiben';

  @override
  String get nasInstallStepWriteCreds => 'Private Zugangsdaten schreiben';

  @override
  String get nasInstallStepPullImage =>
      'Gepinntes Container-Image herunterladen';

  @override
  String get nasInstallStepStartService => 'Containerisierten Dienst starten';

  @override
  String get nasInstallStepCheckHttp => 'HTTP-Zustand des Dienstes prüfen';

  @override
  String get nasInstallBlockerDocker =>
      'Docker Engine ist auf dem Zielserver erforderlich';

  @override
  String get nasInstallBlockerCompose =>
      'Docker Compose-Plugin ist erforderlich';

  @override
  String get nasInstallBlockerIdentity =>
      'Identität des Zielservers konnte nicht verifiziert werden';

  @override
  String get nasInstallBlockerTools =>
      'Erforderliche Tools (curl, ss, realpath) fehlen auf dem Zielserver';

  @override
  String get nasInstallBlockerMedia =>
      'Medienverzeichnis existiert nicht oder ist nicht lesbar';

  @override
  String get nasInstallBlockerParent =>
      'Übergeordnetes Datenstammverzeichnis ist nicht beschreibbar';

  @override
  String get nasInstallBlockerOverlap =>
      'Medien- und Datenverzeichnis dürfen sich nicht überschneiden';

  @override
  String get nasInstallBlockerCollision =>
      'Zieldatenverzeichnis existiert bereits oder ist ein Symlink';

  @override
  String get nasInstallBlockerPort =>
      'Ausgewählter Port wird auf dem Zielserver bereits verwendet';

  @override
  String get nasInstallBlockerContainer =>
      'Ein Container mit diesem Projektnamen existiert bereits';

  @override
  String get nasInstallBlockerImage =>
      'Container-Image konnte nicht verifiziert werden. Image-Name, Netzwerkverbindung und Serverarchitektur prüfen, dann erneut versuchen.';

  @override
  String get nasInstallGuidanceTunnel =>
      'Loopback-Bindung (127.0.0.1) erfordert einen SSH-Tunnel für Remote-Zugriff';

  @override
  String get nasInstallGuidanceTls =>
      'Öffentliche Bindung sollte hinter einem TLS-Reverse-Proxy abgesichert werden';

  @override
  String get nasInstallGuidanceSetup =>
      'Ersteinrichtung des Administratorkontos beim ersten Start im Browser abschließen';

  @override
  String get nasInstallGuidanceReadOnly =>
      'Medienverzeichnis wird schreibgeschützt eingebunden, um Ihre Dateien zu schützen';

  @override
  String get nasInstallGuidancePreserved =>
      'Datenverzeichnis bleibt bei Fehlern zur Fehlerbehebung erhalten';

  @override
  String get nasDownloadCompletedWithOpenError =>
      'Heruntergeladen (Konnte extern nicht geöffnet werden)';

  @override
  String get nasRetryOpen => 'Öffnen wiederholen';

  @override
  String get nasExternalOpenFailed =>
      'Datei konnte in externer App nicht geöffnet werden';

  @override
  String get nasTitle => 'NAS-Medien';

  @override
  String get nasLoadMoreGroups => 'Weitere Gruppen laden';

  @override
  String get nasMetadataEnriching => 'Musik-Tags werden angereichert...';

  @override
  String nasMetadataEnrichingWithCount(int count) {
    return 'Musik-Tags werden angereichert ($count verarbeitet)...';
  }

  @override
  String nasDownloading(String value) {
    return '$value wird heruntergeladen…';
  }

  @override
  String get nasSubtitleNone => 'Keine';

  @override
  String get nasLibraryId => 'Bibliotheks-ID';

  @override
  String get nasLibraryIdHint =>
      'Standard: alle (/), oder Bibliotheks-ID angeben';

  @override
  String nasScanPathRelativeHint(String value) {
    return 'Relativ zum Quellstammverzeichnis ($value)';
  }

  @override
  String get nasSourceChangedError =>
      'Quelle während der Konfiguration geändert, Speichern abgebrochen';

  @override
  String get nasInvalidLibraryId => 'Ungültige Bibliotheks-ID';

  @override
  String get startupFailed => 'Anwendung konnte nicht gestartet werden';

  @override
  String get startupFailedDesc =>
      'Beim Start ist ein unerwarteter Fehler aufgetreten. Sie können es erneut versuchen oder Diagnoseprotokolle exportieren.';

  @override
  String get retryStartup => 'Start wiederholen';

  @override
  String get viewDiagnostics => 'Diagnose anzeigen';

  @override
  String get exportDiagnostics => 'Diagnose exportieren';

  @override
  String diagnosticsExportSuccess(String path) {
    return 'Diagnose exportiert nach $path';
  }

  @override
  String get diagnosticsExportFailed =>
      'Diagnose konnte nicht exportiert werden';

  @override
  String get diagnosticsTitle => 'App-Diagnose';

  @override
  String get settingsDiagnostics => 'Diagnose & Protokolle';

  @override
  String get settingsDiagnosticsDesc =>
      'Lokale bereinigte Anwendungsprotokolle anzeigen und exportieren';

  @override
  String get diagnosticsEmpty => 'Keine Datensätze gefunden';

  @override
  String diagnosticsStorageError(String error) {
    return 'Diagnosespeicherfehler: $error';
  }

  @override
  String diagnosticsIncidentNotice(String category) {
    return 'Behebbarer Vorfall gemeldet: $category';
  }

  @override
  String get diagnosticsRefresh => 'Protokolle aktualisieren';

  @override
  String get nasInstallTaskTitle => 'Bereitstellungsaufgabe';

  @override
  String get nasInstallStagePreflight => 'Vorabprüfung';

  @override
  String get nasInstallStageReview => 'Planprüfung';

  @override
  String get nasInstallStageWriting => 'Konfiguration schreiben';

  @override
  String get nasInstallStagePulling => 'Image herunterladen';

  @override
  String get nasInstallStageStarting => 'Container starten';

  @override
  String get nasInstallStageHealth => 'Zustandsprüfung';

  @override
  String get nasInstallStageCleanup => 'Bereinigung';

  @override
  String get nasInstallStageSucceeded => 'Bereitstellung erfolgreich';

  @override
  String get nasInstallStageFailed => 'Bereitstellung fehlgeschlagen';

  @override
  String get nasInstallStageCancelled => 'Bereitstellung abgebrochen';

  @override
  String get nasInstallStageNeedsInspection => 'Erfordert Überprüfung';

  @override
  String get nasInstallStageReconciling => 'Statusabgleich';

  @override
  String get nasInstallCancel => 'Bereitstellung abbrechen';

  @override
  String get nasInstallReconcile => 'Status abgleichen';

  @override
  String get nasInstallServerNotFound =>
      'Ausgewählter Server wurde nicht gefunden';

  @override
  String get nasInstallPortRangeError =>
      'Port muss zwischen 1 und 65535 liegen';

  @override
  String nasInstallElapsedTime(String time) {
    return 'Verstrichen: $time';
  }

  @override
  String get nasInstallLogTail => 'Aktuelle Protokolle';

  @override
  String get nasInstallCleanupCompleted => 'Rollback-Bereinigung abgeschlossen';

  @override
  String get nasInstallCleanupIncomplete =>
      'Rollback-Bereinigung unvollständig';

  @override
  String get nasInstallNewDeployment => 'Neue Bereitstellung';

  @override
  String get nasInstallBackEdit => 'Zurück / Formular bearbeiten';

  @override
  String get nasInstallClose => 'Schließen';

  @override
  String get nasInstallMediaPathHint =>
      'Schreibgeschützte Bind-Einbindung auf Host (z. B. /mnt/media)';

  @override
  String get nasInstallDataRootHint =>
      'Privates Daten- & Konfigurationsverzeichnis (darf noch nicht existieren)';

  @override
  String get nasInstallBindAddressHint =>
      '127.0.0.1 für Tunnel, 0.0.0.0 für LAN';

  @override
  String get nasInstallWebdavPasswordHint =>
      'Mindestens 12 Zeichen erforderlich';

  @override
  String get nasInstallTargetServer => 'Zielserver';

  @override
  String get nasInstallTargetImage => 'Ziel-Image';

  @override
  String get nasInstallContainerName => 'Container-Name';

  @override
  String get nasInstallBindAndPort => 'Bindung & Port';

  @override
  String get nasInstallComposePreview => 'Vorschau auf docker-compose.json';

  @override
  String get nasInstallPlannedSteps => 'Geplante Schritte';

  @override
  String get nasInstallGuidanceNotes => 'Bereitstellungshinweise & Leitfaden';

  @override
  String get nasInstallNoLogsYet => 'Noch keine Protokolle';

  @override
  String get sftpPreviewTooLarge =>
      'Datei überschreitet Vorschau-Grenze von 1 MiB. Bitte herunterladen und extern öffnen.';

  @override
  String get sftpSaveFailed =>
      'Datei konnte nicht gespeichert werden. Berechtigungen oder Netzwerkverbindung prüfen.';

  @override
  String get sftpSaving => 'Wird gespeichert...';

  @override
  String get nasInstallBlockerConnectionChanged =>
      'Zielserververbindung geändert; Remote-Status vor dem Fortfahren überprüfen';

  @override
  String get nasInstallBlockerCancelled =>
      'Bereitstellung wurde vom Benutzer abgebrochen. Einstellungen überprüfen und bei Bedarf wiederholen.';

  @override
  String get nasInstallBlockerInspectFailed =>
      'Überprüfung konnte Remote-Container nicht abfragen. Serververbindung prüfen oder manuell untersuchen.';

  @override
  String get nasInstallBlockerDeadlineExceeded =>
      'Bereitstellungsschritt hat das Zeitlimit überschritten. Serverauslastung oder Netzwerk prüfen und erneut versuchen.';

  @override
  String get nasInstallBlockerInterrupted =>
      'Bereitstellung wurde unterbrochen; Remote-Status vor dem Fortfahren überprüfen.';

  @override
  String get nasInstallBlockerHealthTimeout =>
      'Dienst gestartet, aber HTTP-Zustandsprüfung hat das Zeitlimit überschritten. Dienstprotokolle oder Portverfügbarkeit prüfen.';

  @override
  String get nasInstallBlockerReconciliationFailed =>
      'Abgleich fehlgeschlagen. Remote-Container-Status manuell prüfen oder neue Bereitstellung starten.';

  @override
  String get nasInstallBlockerRemoteInspectionRequired =>
      'Remote-Container-Status ist unbestimmt. Manuelle Überprüfung und Abgleich erforderlich.';

  @override
  String get nasInstallBlockerServiceExited =>
      'Container-Prozess vorzeitig beendet. Protokolle auf Konfigurations- oder Berechtigungsfehler prüfen.';

  @override
  String get nasInstallBlockerWriteFailed =>
      'Bereitstellungsdateien konnten auf Zielserver nicht geschrieben werden. Speicherplatz und Berechtigungen prüfen.';

  @override
  String get nasInstallBlockerPlanStale =>
      'Bereitstellungsplan ist veraltet. Bitte Vorabprüfung erneut ausführen.';

  @override
  String get nasInstallBlockerOwnershipChanged =>
      'Bestehender Container wurde nicht von dieser App erstellt. Manuell prüfen, um Überschreiben zu verhindern.';

  @override
  String get nasInstallBlockerSshRequired =>
      'Aktive SSH-Verbindung zum Zielserver ist erforderlich.';

  @override
  String get nasInstallBlockerReconciliationRequired =>
      'Remote-Status unterscheidet sich vom lokalen Status. Bitte vor dem Fortfahren abgleichen.';

  @override
  String get nasInstallBlockerFailed =>
      'Bei der Bereitstellung ist ein Fehler aufgetreten. Protokolle prüfen und erneut versuchen.';

  @override
  String get nasInstallBlockerBusy =>
      'Eine Installationsaufgabe wird bereits ausgeführt. Bitte aktuellen Aufgabenfortschritt prüfen.';

  @override
  String get nasInstallBlockerStateSaveFailed =>
      'Bereitstellungsstatus konnte nicht persistent gespeichert werden. Lokalen Speicherplatz und Dateiberechtigungen prüfen.';

  @override
  String get nasInstallBlockerCommandResultUnknown =>
      'Ergebnis des Remote-Befehls unbekannt. Bitte schreibgeschützte Überprüfung durchführen, statt Bereitstellung direkt zu wiederholen.';

  @override
  String get nasInstallBlockerPreflightFailed =>
      'Umgebungsprüfung vor Bereitstellung fehlgeschlagen. Bitte Blocker beheben, bevor Sie fortfahren.';

  @override
  String serverDeleteFailed(String error) {
    return 'Server konnte nicht gelöscht werden: $error';
  }

  @override
  String get chatRunSettingsAgentMode => 'Agentenmodus';

  @override
  String get chatRunSettingsApprovalPolicy => 'Lokale Genehmigungsrichtlinie';

  @override
  String get chatRunSettingsExtraSettings => 'Zusätzliche Einstellungen';

  @override
  String get chatPermissionAutoAllowSafeDesc =>
      'Erlaubt bekannte sichere Vorgänge automatisch; fragt nach, wenn die Sicherheit eines Vorgangs nicht bestimmt werden kann.';

  @override
  String chatRunSettingsSaveFailed(String error) {
    return 'Ausführungseinstellungen konnten nicht übernommen werden: $error';
  }

  @override
  String get chatMessageCopied => 'Nachricht in Zwischenablage kopiert';

  @override
  String get copy => 'Kopieren';

  @override
  String get rename => 'Umbenennen';

  @override
  String get refresh => 'Aktualisieren';

  @override
  String get sessionTitle => 'Sitzungstitel';

  @override
  String get chatSettingsStale => 'Veraltet';

  @override
  String get chatSettingsAvailableAfterFirstMessage =>
      'Einstellungen nach erster Nachricht verfügbar';

  @override
  String get chatReimportAsCopy => 'Als Kopie erneut importieren';

  @override
  String get chatSearchCommandsHint => 'Befehle oder Skills suchen...';

  @override
  String get chatCommandsTab => 'Befehle';

  @override
  String get chatSkillsTab => 'Skills';

  @override
  String get chatAccountAndQuotaTitle => 'Konto & Kontingent';

  @override
  String get chatAccountSectionTitle => 'Konto';

  @override
  String get chatAccountNotProvided => 'Keine Kontodetails gemeldet';

  @override
  String get chatAccountKind => 'Typ';

  @override
  String get chatAccountLabel => 'Bezeichnung';

  @override
  String get chatAccountPlan => 'Tarif';

  @override
  String get chatAccountEmail => 'E-Mail';

  @override
  String get chatAccountUpdatedAt => 'Aktualisiert';

  @override
  String get chatQuotaSectionTitle => 'Kontingent & Status';

  @override
  String get chatStatusSourceNote => 'Rohe Agenten-/status-Ausgabe';

  @override
  String get chatStatusNotQueried => 'Status noch nicht abgefragt';

  @override
  String get chatQueryStatusAction => 'Status abfragen (/status)';

  @override
  String get chatQueryStatusUnavailable =>
      'Statusabfrage in aktueller Sitzung nicht verfügbar';

  @override
  String get chatAttachmentMissing => 'Anhangdatei fehlt oder nicht verfügbar';

  @override
  String get chatViewModeList => 'Liste';

  @override
  String get chatViewModeCards => 'Karten';

  @override
  String get chatViewModeGrid => 'Bilder';

  @override
  String get chatRemoteBrowserTitle => 'Remote-Arbeitsbereich';

  @override
  String get chatSelectDirectory => 'Verzeichnis auswählen';

  @override
  String chatAttachSelectedFiles(int count) {
    return 'Ausgewählte anhängen ($count)';
  }

  @override
  String get chatNoFilesFound => 'Keine Dateien gefunden';

  @override
  String get chatRootDirectory => 'Root';

  @override
  String get chatSelectThisDirectory => 'Dieses Verzeichnis verwenden';

  @override
  String get chatAgentVersion => 'Agentenversion';

  @override
  String get chatParentDirectory => 'Übergeordnetes Verzeichnis';

  @override
  String get chatSearchFilesHint => 'Dateien suchen...';

  @override
  String get chatCommandsEmpty =>
      'Keine Slash-Befehle vom Agenten bereitgestellt';

  @override
  String get chatSkillsEmpty => 'Keine Skills vom Agenten bereitgestellt';

  @override
  String get chatFileUnsupported => 'Dateityp für Anhang nicht unterstützt';

  @override
  String get chatStatusNotProvided =>
      'Statusabfrage vom Agenten nicht bereitgestellt';

  @override
  String get sessionRecoveryReconnecting =>
      'Verbindung wird wiederhergestellt...';

  @override
  String get sessionRecoverySyncing => 'Ausgabe wird synchronisiert...';

  @override
  String get sessionRecoveryIncomplete =>
      'Einige Ausgaben konnten nicht wiederhergestellt werden';

  @override
  String get sessionRecoveryFailed => 'Wiederherstellung fehlgeschlagen';

  @override
  String get sessionRecoveryRetry => 'Wiederholen';

  @override
  String get dashboardUpdatesPaused => 'Aktualisierungen pausiert';

  @override
  String get chatSettingsIndependentModelUnavailable =>
      'CLI-Modellkatalog ist derzeit nicht verfügbar. Modelle können zwischengespeichert oder durch die CLI-Version begrenzt sein; Sie können auch einen Modellnamen manuell eingeben.';

  @override
  String get chatSettingsModelCatalogNote =>
      'Modelle werden vom CLI-App-Server unter Verwendung Ihres bestehenden CLI-Logins abgefragt. Der Katalog kann zwischengespeichert oder versionsbeschränkt sein; Sie können manuell aktualisieren oder zur manuellen Eingabe wechseln.';

  @override
  String get chatModelCatalogError403 =>
      'Zugriff auf CLI-Modellabfrage verweigert (403). Prüfen Sie CLI-Login und Dienstkonnektivität oder geben Sie einen Modellnamen manuell ein.';

  @override
  String chatModelCatalogErrorGeneric(String error) {
    return 'Modellkatalog-Fehler: $error';
  }

  @override
  String get chatModelAuthorizeButton => 'Modellkatalog autorisieren';

  @override
  String get chatModelAuthorizeConfirmTitle => 'Modellkatalog autorisieren';

  @override
  String get chatModelAuthorizeConfirmMessage =>
      'Dies startet die Browser-Autorisierung für den Modellkatalog auf dem Ziel-Host/-Container. Ihr bestehender Codex-Login und Ihre Terminal-Sitzungen bleiben vollständig unberührt. Fortfahren?';

  @override
  String get chatModelAuthorizing => 'Autorisierung über Browser...';

  @override
  String get chatModelAuthorizeCancel => 'Autorisierung abbrechen';

  @override
  String get chatCommandsFirstTurnNote =>
      'Slash-Befehle werden von der Agenten-Laufzeitumgebung nach der Sitzungsinitialisierung gemeldet, ohne dass eine vorherige normale Unterhaltung erforderlich ist; Entwürfe erstellen nicht automatisch Sitzungen.';

  @override
  String get chatCommandsClientActionRunSettings => 'Ausführungseinstellungen';

  @override
  String get chatCommandsClientActionWorkingDirectory => 'Arbeitsverzeichnis';

  @override
  String get chatCommandsClientActionsSection => 'Lokale Aktionen';

  @override
  String get chatRunSettingsModelSourceCatalog => 'Modellliste';

  @override
  String get chatRunSettingsModelSourceCustom => 'Manuelle Eingabe';

  @override
  String get chatRunSettingsCustomModelHint => 'Modell-ID eingeben';

  @override
  String get chatRunSettingsCustomModelNotice =>
      'Manuelle Modellnamen sind ungeprüft und werden direkt an die Agenten-Laufzeitumgebung gesendet, die nicht unterstützte Modelle ablehnen kann.';

  @override
  String get chatRunSettingsCustomModelEmptyError =>
      'Modellname darf nicht leer sein';

  @override
  String get chatRunSettingsCustomModelInvalidError =>
      'Modellname darf maximal 256 Zeichen lang sein und keine Leerzeichen oder Steuerzeichen enthalten';

  @override
  String get chatCommandsDraftPreviewNotice =>
      'Befehle für die aktuelle Adapterversion verifiziert. Durch Auswählen wird Text in den Entwurf eingefügt; Senden initialisiert die Sitzung bei Bedarf und führt den Befehl direkt aus.';

  @override
  String get chatCommandsDiscoveryFailed =>
      'Befehle oder Skills konnten nicht ermittelt werden';

  @override
  String get chatAuthWaitingForBrowser =>
      'Warten auf Autorisierung im Browser...';

  @override
  String get chatAuthBrowserLaunchFailed =>
      'Externer Browser konnte nicht geöffnet werden. Bitte erneut öffnen oder Autorisierungslink unten kopieren.';

  @override
  String get chatAuthReopenBrowser => 'Browser erneut öffnen';

  @override
  String get chatAuthCopyLink => 'Link kopieren';

  @override
  String get chatAuthManualCallback => 'Manueller Callback';

  @override
  String get chatAuthManualCallbackTitle =>
      'Autorisierungs-Callback-URL eingeben';

  @override
  String get chatAuthManualCallbackDesc =>
      'Fügen Sie die vollständige Weiterleitungs-URL (http://127.0.0.1:PORT/...?code=...&state=...) aus dem Browser ein, um die Autorisierung abzuschließen. Reine Autorisierungscodes werden nicht akzeptiert.';

  @override
  String get chatAuthCallbackInputLabel => 'Callback-URL';

  @override
  String get chatAuthCallbackInputHint =>
      'http://127.0.0.1:PORT/...?code=...&state=...';

  @override
  String get chatAuthCallbackInvalidError =>
      'Ungültiges Callback-URL-Format oder Übermittlung fehlgeschlagen';

  @override
  String get agentAuthAgYNotice =>
      'Antigravity ACP erfordert eine offizielle Kontoautorisierung, getrennt vom Terminal-CLI-Login.';

  @override
  String get chatAuthDiscoveryPrompt =>
      'Dieser Schritt erfordert eine ACP-Authentifizierung. Neu verbinden und Autorisierung anfordern, um fortzufahren.';

  @override
  String get chatRequestAuthButton => 'Authentifizierung anfordern';

  @override
  String get agentActionAcpLogin => 'ACP-Anmeldung';

  @override
  String get agentActionCliLogin => 'CLI-Anmeldung';

  @override
  String get agentAgyAcpSignInRequired =>
      'ACP-Zugangsdaten fehlen (ACP-Anmeldung erforderlich)';

  @override
  String get agentAgyAcpCredentialsSaved =>
      'ACP-Zugangsdaten gespeichert (ungeprüft)';

  @override
  String get chatAuthMethodUnavailable =>
      'Die ausgewählte Authentifizierungsmethode ist nicht verfügbar.';

  @override
  String get chatAuthConnectionExpired =>
      'Authentifizierungsverbindung abgelaufen. Bitte erneut versuchen.';

  @override
  String get chatAuthCallbackDeliveryFailed =>
      'Übermittlung des Autorisierungs-Callbacks an den Server fehlgeschlagen.';

  @override
  String get agentTargetChangedNotice =>
      'Zielserver hat sich geändert. Bitte Agenten-Verwaltung auf dem aktuellen Server erneut öffnen.';

  @override
  String get agentAgyAuthCheckUnavailable =>
      'Antigravity-Authentifizierungsprüfung nicht verfügbar';

  @override
  String get agentAgyAuthCheckInvalid =>
      'Antwort der Antigravity-Authentifizierungsprüfung ungültig';

  @override
  String get sftpDownloadDisconnected => 'Download getrennt';

  @override
  String get sftpDownloadPermissionDenied => 'Berechtigung verweigert';

  @override
  String get sftpDownloadNotFound => 'Remote-Datei nicht gefunden';

  @override
  String get sftpDownloadTimeout => 'Download-Zeitüberschreitung';

  @override
  String get sftpDownloadLocalSpace => 'Unzureichender lokaler Speicherplatz';

  @override
  String get sftpDownloadLocalIo =>
      'Schreiben auf lokalen Speicher fehlgeschlagen';

  @override
  String get sftpDownloadIncomplete => 'Unvollständiger Download';

  @override
  String get transferStatusWaitingConnection => 'Warten auf Verbindung';

  @override
  String get chatAuthCallbackListenerFailed =>
      'Lokaler Autorisierungs-Callback-Listener konnte nicht gestartet werden. Bitte Authentifizierung wiederholen.';

  @override
  String get settingsExperimentalFeatures => 'Experimentelle Funktionen';

  @override
  String get settingsExperimentalFeaturesDesc =>
      'Vorschau- und experimentelle Funktionen ausprobieren';

  @override
  String get settingsExperimentalCliChatTitle => 'CLI-Smart-Chat';

  @override
  String get settingsExperimentalCliChatDesc =>
      'Dedizierte Befehlszeilen-Agenten-Chat-Oberfläche aktivieren';

  @override
  String get settingsExperimentalDialogClose => 'Schließen';

  @override
  String get settingsExperimentalSaveFailed =>
      'Aktualisierung der experimentellen Funktionseinstellungen fehlgeschlagen';

  @override
  String get settingsExperimentalNasTitle => 'NAS-Medien';

  @override
  String get settingsExperimentalNasDesc =>
      'Medienbibliothek, Scan-Ordner und Audiowiedergabe aktivieren';

  @override
  String get settingsLanguageSaveFailed =>
      'Aktualisierung der Spracheinstellungen fehlgeschlagen';

  @override
  String get settingsAboutPrivacy => 'Über & Datenschutz';

  @override
  String get privacyPolicyTitle => 'Datenschutzerklärung';

  @override
  String get privacyPolicyDescription => 'Datennutzung und Ihre Möglichkeiten';

  @override
  String get privacyContactTitle => 'Datenschutzkontakt';

  @override
  String get privacyCopyEmail => 'E-Mail-Adresse kopieren';

  @override
  String get privacyEmailCopied => 'E-Mail-Adresse kopiert';

  @override
  String get privacyOnlineVersion => 'Online-Version anzeigen';

  @override
  String get privacyLinkFailed =>
      'Link konnte nicht geöffnet werden. Die E-Mail-Adresse kann kopiert werden.';

  @override
  String get privacyLoadFailed =>
      'Datenschutzerklärung konnte nicht geladen werden. Bitte die Online-Version öffnen.';

  @override
  String get privacyVersionUnknown => 'Version nicht verfügbar';

  @override
  String get aboutWebsite => 'Offizielle Website';

  @override
  String get aboutLicense => 'Anwendungslizenz';

  @override
  String get aboutThirdPartyLicenses =>
      'Open-Source-Lizenzen von Drittanbietern';

  @override
  String get aboutLicenseSummary =>
      'Originalmaterial von Valhalla steht unter PolyForm Noncommercial 1.0.0 für nichtkommerzielle Nutzung. Kommerzielle Nutzung außerhalb der erlaubten Lizenzbedingungen erfordert eine gesonderte Genehmigung. Drittanbieterkomponenten behalten ihre eigenen Lizenzen. Maßgeblich sind die vollständigen Bedingungen unten.';

  @override
  String get aboutCopyrightNotice => 'Urheberrechtshinweise';

  @override
  String get aboutLicenseLoadFailed =>
      'Die Lizenz konnte nicht geladen werden. Kontaktieren Sie norns.soft@gmail.com.';

  @override
  String get aboutLinkFailed =>
      'Der Link konnte nicht geöffnet werden. Öffnen Sie https://norns.cc.cd in Ihrem Browser.';
}
