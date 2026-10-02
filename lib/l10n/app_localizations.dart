import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

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
    Locale('zh'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Valhalla'**
  String get appName;

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **'AI-Native Server & Agent Management'**
  String get appSubtitle;

  /// No description provided for @navAiChat.
  ///
  /// In en, this message translates to:
  /// **'AI Ops'**
  String get navAiChat;

  /// No description provided for @navTerminal.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get navTerminal;

  /// No description provided for @navFiles.
  ///
  /// In en, this message translates to:
  /// **'SFTP Files'**
  String get navFiles;

  /// No description provided for @navCommands.
  ///
  /// In en, this message translates to:
  /// **'Commands'**
  String get navCommands;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @serverConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get serverConnected;

  /// No description provided for @serverOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get serverOnline;

  /// No description provided for @serverOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get serverOffline;

  /// No description provided for @latencyMs.
  ///
  /// In en, this message translates to:
  /// **'ms'**
  String get latencyMs;

  /// No description provided for @reconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get reconnect;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @quickDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Quick Disconnect'**
  String get quickDisconnect;

  /// No description provided for @newSession.
  ///
  /// In en, this message translates to:
  /// **'New Session'**
  String get newSession;

  /// No description provided for @historySessions.
  ///
  /// In en, this message translates to:
  /// **'History Sessions'**
  String get historySessions;

  /// No description provided for @switchAgent.
  ///
  /// In en, this message translates to:
  /// **'Switch Agent'**
  String get switchAgent;

  /// No description provided for @agentClaudeCode.
  ///
  /// In en, this message translates to:
  /// **'Claude CodeX'**
  String get agentClaudeCode;

  /// No description provided for @agentCodex.
  ///
  /// In en, this message translates to:
  /// **'OpenAI Codex'**
  String get agentCodex;

  /// No description provided for @agentOpenCode.
  ///
  /// In en, this message translates to:
  /// **'OpenCode ACP'**
  String get agentOpenCode;

  /// No description provided for @agentGemini.
  ///
  /// In en, this message translates to:
  /// **'Gemini CLI'**
  String get agentGemini;

  /// No description provided for @activeAgent.
  ///
  /// In en, this message translates to:
  /// **'Active Agent'**
  String get activeAgent;

  /// No description provided for @inputPromptHint.
  ///
  /// In en, this message translates to:
  /// **'Ask Agent to diagnose, run tools or write commands... (Enter to send)'**
  String get inputPromptHint;

  /// No description provided for @thinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking Process'**
  String get thinking;

  /// No description provided for @executionPlan.
  ///
  /// In en, this message translates to:
  /// **'Execution Plan'**
  String get executionPlan;

  /// No description provided for @toolCall.
  ///
  /// In en, this message translates to:
  /// **'Tool Call'**
  String get toolCall;

  /// No description provided for @toolStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get toolStatusPending;

  /// No description provided for @toolStatusRunning.
  ///
  /// In en, this message translates to:
  /// **'Running...'**
  String get toolStatusRunning;

  /// No description provided for @toolStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get toolStatusCompleted;

  /// No description provided for @toolStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get toolStatusFailed;

  /// No description provided for @permissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Permission Required'**
  String get permissionRequired;

  /// No description provided for @permissionDescription.
  ///
  /// In en, this message translates to:
  /// **'Agent wants to execute this command on the server:'**
  String get permissionDescription;

  /// No description provided for @permissionReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get permissionReject;

  /// No description provided for @permissionAllowOnce.
  ///
  /// In en, this message translates to:
  /// **'Allow Once'**
  String get permissionAllowOnce;

  /// No description provided for @permissionAllowAlways.
  ///
  /// In en, this message translates to:
  /// **'Always Allow'**
  String get permissionAllowAlways;

  /// No description provided for @quickTroubleshootCpu.
  ///
  /// In en, this message translates to:
  /// **'Troubleshoot High CPU'**
  String get quickTroubleshootCpu;

  /// No description provided for @quickDockerHealth.
  ///
  /// In en, this message translates to:
  /// **'Docker Health Check'**
  String get quickDockerHealth;

  /// No description provided for @quickCleanCache.
  ///
  /// In en, this message translates to:
  /// **'Clean System Cache'**
  String get quickCleanCache;

  /// No description provided for @quickNginxLogs.
  ///
  /// In en, this message translates to:
  /// **'Check Nginx Error Logs'**
  String get quickNginxLogs;

  /// No description provided for @terminalNewTab.
  ///
  /// In en, this message translates to:
  /// **'New Tab'**
  String get terminalNewTab;

  /// No description provided for @terminalCloseTab.
  ///
  /// In en, this message translates to:
  /// **'Close Tab'**
  String get terminalCloseTab;

  /// No description provided for @terminalClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get terminalClear;

  /// No description provided for @terminalQuickCmds.
  ///
  /// In en, this message translates to:
  /// **'Command Palette'**
  String get terminalQuickCmds;

  /// No description provided for @terminalPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get terminalPaste;

  /// No description provided for @sftpCurrentPath.
  ///
  /// In en, this message translates to:
  /// **'Current Path'**
  String get sftpCurrentPath;

  /// No description provided for @sftpUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get sftpUpload;

  /// No description provided for @sftpNewFolder.
  ///
  /// In en, this message translates to:
  /// **'New Folder'**
  String get sftpNewFolder;

  /// No description provided for @sftpNewFile.
  ///
  /// In en, this message translates to:
  /// **'New File'**
  String get sftpNewFile;

  /// No description provided for @sftpRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get sftpRefresh;

  /// No description provided for @sftpSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search files or folders...'**
  String get sftpSearchHint;

  /// No description provided for @sftpEmpty.
  ///
  /// In en, this message translates to:
  /// **'Directory is empty'**
  String get sftpEmpty;

  /// No description provided for @sftpFileName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sftpFileName;

  /// No description provided for @sftpFileSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get sftpFileSize;

  /// No description provided for @sftpFilePerm.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get sftpFilePerm;

  /// No description provided for @sftpFileModified.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get sftpFileModified;

  /// No description provided for @cmdCategoryDocker.
  ///
  /// In en, this message translates to:
  /// **'DOCKER CONTAINER STACK'**
  String get cmdCategoryDocker;

  /// No description provided for @cmdCategorySystem.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM MAINTENANCE'**
  String get cmdCategorySystem;

  /// No description provided for @cmdCategoryNetwork.
  ///
  /// In en, this message translates to:
  /// **'NETWORK & PORTS'**
  String get cmdCategoryNetwork;

  /// No description provided for @cmdExecute.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get cmdExecute;

  /// No description provided for @cmdDangerous.
  ///
  /// In en, this message translates to:
  /// **'Dangerous Command'**
  String get cmdDangerous;

  /// No description provided for @cmdDangerousWarning.
  ///
  /// In en, this message translates to:
  /// **'This operation is irreversible and may cause service interruption. Are you sure you want to proceed?'**
  String get cmdDangerousWarning;

  /// No description provided for @cmdParamRequired.
  ///
  /// In en, this message translates to:
  /// **'Parameter Input Required'**
  String get cmdParamRequired;

  /// No description provided for @cmdConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Run'**
  String get cmdConfirm;

  /// No description provided for @cmdCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cmdCancel;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance & Theming'**
  String get settingsAppearance;

  /// No description provided for @settingsThemeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme Mode'**
  String get settingsThemeMode;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get themeSystem;

  /// No description provided for @themeSystemDesc.
  ///
  /// In en, this message translates to:
  /// **'Auto Adaptive'**
  String get themeSystemDesc;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get themeLight;

  /// No description provided for @themeLightDesc.
  ///
  /// In en, this message translates to:
  /// **'Paper High-Key'**
  String get themeLightDesc;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Geek Dark'**
  String get themeDark;

  /// No description provided for @themeDarkDesc.
  ///
  /// In en, this message translates to:
  /// **'Deep Charcoal'**
  String get themeDarkDesc;

  /// No description provided for @themeAmoled.
  ///
  /// In en, this message translates to:
  /// **'AMOLED Black'**
  String get themeAmoled;

  /// No description provided for @themeAmoledDesc.
  ///
  /// In en, this message translates to:
  /// **'True Black 0x000000'**
  String get themeAmoledDesc;

  /// No description provided for @settingsAccentColor.
  ///
  /// In en, this message translates to:
  /// **'Theme Accent Color'**
  String get settingsAccentColor;

  /// No description provided for @accentCyberEmerald.
  ///
  /// In en, this message translates to:
  /// **'Cyber Emerald'**
  String get accentCyberEmerald;

  /// No description provided for @accentTechBlue.
  ///
  /// In en, this message translates to:
  /// **'Tech Blue'**
  String get accentTechBlue;

  /// No description provided for @accentElectricViolet.
  ///
  /// In en, this message translates to:
  /// **'Electric Violet'**
  String get accentElectricViolet;

  /// No description provided for @accentCrimsonRed.
  ///
  /// In en, this message translates to:
  /// **'Crimson Red'**
  String get accentCrimsonRed;

  /// No description provided for @accentAmberOrange.
  ///
  /// In en, this message translates to:
  /// **'Amber Orange'**
  String get accentAmberOrange;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language & Locale'**
  String get settingsLanguage;

  /// No description provided for @langZh.
  ///
  /// In en, this message translates to:
  /// **'简体中文 (Simplified Chinese)'**
  String get langZh;

  /// No description provided for @langEn.
  ///
  /// In en, this message translates to:
  /// **'English (US)'**
  String get langEn;

  /// No description provided for @settingsAiOps.
  ///
  /// In en, this message translates to:
  /// **'AI Ops & Engine'**
  String get settingsAiOps;

  /// No description provided for @settingsSecurity.
  ///
  /// In en, this message translates to:
  /// **'Connection & Security'**
  String get settingsSecurity;

  /// No description provided for @settingsKnownHosts.
  ///
  /// In en, this message translates to:
  /// **'Known Host Keys'**
  String get settingsKnownHosts;

  /// No description provided for @settingsClearStorage.
  ///
  /// In en, this message translates to:
  /// **'Reset Credentials'**
  String get settingsClearStorage;

  /// No description provided for @settingsResetDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset Defaults'**
  String get settingsResetDefault;

  /// No description provided for @settingsTerminalUseTmux.
  ///
  /// In en, this message translates to:
  /// **'Persistent Sessions (tmux)'**
  String get settingsTerminalUseTmux;

  /// No description provided for @settingsTerminalUseTmuxSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Run terminal sessions inside tmux on the remote server'**
  String get settingsTerminalUseTmuxSubtitle;

  /// No description provided for @settingsTerminalUseTmuxDescription.
  ///
  /// In en, this message translates to:
  /// **'Keeps your terminal output after a disconnect. Requires tmux on the remote server. Changes apply to newly opened terminal tabs.'**
  String get settingsTerminalUseTmuxDescription;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @addServer.
  ///
  /// In en, this message translates to:
  /// **'Add Server'**
  String get addServer;

  /// No description provided for @editServer.
  ///
  /// In en, this message translates to:
  /// **'Edit Server'**
  String get editServer;

  /// No description provided for @serverName.
  ///
  /// In en, this message translates to:
  /// **'Server Name'**
  String get serverName;

  /// No description provided for @serverHost.
  ///
  /// In en, this message translates to:
  /// **'Host / IP'**
  String get serverHost;

  /// No description provided for @serverPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get serverPort;

  /// No description provided for @serverUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get serverUsername;

  /// No description provided for @serverAuthType.
  ///
  /// In en, this message translates to:
  /// **'Authentication Type'**
  String get serverAuthType;

  /// No description provided for @serverPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get serverPassword;

  /// No description provided for @serverPrivateKey.
  ///
  /// In en, this message translates to:
  /// **'Private Key'**
  String get serverPrivateKey;

  /// No description provided for @serverSave.
  ///
  /// In en, this message translates to:
  /// **'Save Server'**
  String get serverSave;

  /// No description provided for @serverDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Server'**
  String get serverDelete;

  /// No description provided for @fileEditor.
  ///
  /// In en, this message translates to:
  /// **'File Editor'**
  String get fileEditor;

  /// No description provided for @fileEditorSave.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get fileEditorSave;

  /// No description provided for @fileSavedSuccess.
  ///
  /// In en, this message translates to:
  /// **'File saved successfully'**
  String get fileSavedSuccess;

  /// No description provided for @addCommand.
  ///
  /// In en, this message translates to:
  /// **'New Command'**
  String get addCommand;

  /// No description provided for @commandTitle.
  ///
  /// In en, this message translates to:
  /// **'Command Title'**
  String get commandTitle;

  /// No description provided for @commandContent.
  ///
  /// In en, this message translates to:
  /// **'Command String'**
  String get commandContent;

  /// No description provided for @commandCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get commandCategory;

  /// No description provided for @commandDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get commandDescription;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @cmdExecutionChannel.
  ///
  /// In en, this message translates to:
  /// **'Execution Channel'**
  String get cmdExecutionChannel;

  /// No description provided for @cmdChannelTerminal.
  ///
  /// In en, this message translates to:
  /// **'Direct to SSH Terminal'**
  String get cmdChannelTerminal;

  /// No description provided for @cmdChannelTerminalDesc.
  ///
  /// In en, this message translates to:
  /// **'Command is typed directly into active terminal session'**
  String get cmdChannelTerminalDesc;

  /// No description provided for @cmdChannelBackground.
  ///
  /// In en, this message translates to:
  /// **'Run in Background Session'**
  String get cmdChannelBackground;

  /// No description provided for @cmdChannelBackgroundDesc.
  ///
  /// In en, this message translates to:
  /// **'Executes via SSH login shell and captures output'**
  String get cmdChannelBackgroundDesc;

  /// No description provided for @cmdInjectedToTerminal.
  ///
  /// In en, this message translates to:
  /// **'Command sent to terminal'**
  String get cmdInjectedToTerminal;

  /// No description provided for @cmdExecutionCompleted.
  ///
  /// In en, this message translates to:
  /// **'Execution Completed'**
  String get cmdExecutionCompleted;

  /// No description provided for @cmdExecutionFailed.
  ///
  /// In en, this message translates to:
  /// **'Execution Failed'**
  String get cmdExecutionFailed;

  /// No description provided for @cmdExecutingRemote.
  ///
  /// In en, this message translates to:
  /// **'Executing remote command...'**
  String get cmdExecutingRemote;

  /// No description provided for @cmdClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get cmdClose;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navDocker.
  ///
  /// In en, this message translates to:
  /// **'Docker'**
  String get navDocker;

  /// No description provided for @navSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get navSystem;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Server Dashboard'**
  String get dashboardTitle;

  /// No description provided for @metricsCpu.
  ///
  /// In en, this message translates to:
  /// **'CPU Usage'**
  String get metricsCpu;

  /// No description provided for @metricsMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory Usage'**
  String get metricsMemory;

  /// No description provided for @metricsLoadAvg.
  ///
  /// In en, this message translates to:
  /// **'Load Average'**
  String get metricsLoadAvg;

  /// No description provided for @metricsUptime.
  ///
  /// In en, this message translates to:
  /// **'System Uptime'**
  String get metricsUptime;

  /// No description provided for @metricsRootDisk.
  ///
  /// In en, this message translates to:
  /// **'Root Disk Usage'**
  String get metricsRootDisk;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Navigation'**
  String get quickActions;

  /// No description provided for @activeServerStatus.
  ///
  /// In en, this message translates to:
  /// **'Active Server Status'**
  String get activeServerStatus;

  /// No description provided for @noServerSelected.
  ///
  /// In en, this message translates to:
  /// **'No server currently selected. Please select a server first.'**
  String get noServerSelected;

  /// No description provided for @serverDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get serverDisconnected;

  /// No description provided for @serverConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get serverConnecting;

  /// No description provided for @connectNow.
  ///
  /// In en, this message translates to:
  /// **'Connect Now'**
  String get connectNow;

  /// No description provided for @serverSpecs.
  ///
  /// In en, this message translates to:
  /// **'Server Info & Specs'**
  String get serverSpecs;

  /// No description provided for @dockerTitle.
  ///
  /// In en, this message translates to:
  /// **'Docker Containers'**
  String get dockerTitle;

  /// No description provided for @dockerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search containers by name or image...'**
  String get dockerSearchHint;

  /// No description provided for @dockerFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get dockerFilterAll;

  /// No description provided for @dockerFilterRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get dockerFilterRunning;

  /// No description provided for @dockerFilterExited.
  ///
  /// In en, this message translates to:
  /// **'Exited'**
  String get dockerFilterExited;

  /// No description provided for @dockerFilterPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get dockerFilterPaused;

  /// No description provided for @dockerActionStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get dockerActionStart;

  /// No description provided for @dockerActionStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get dockerActionStop;

  /// No description provided for @dockerActionRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get dockerActionRestart;

  /// No description provided for @dockerActionPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get dockerActionPause;

  /// No description provided for @dockerActionUnpause.
  ///
  /// In en, this message translates to:
  /// **'Unpause'**
  String get dockerActionUnpause;

  /// No description provided for @dockerActionRm.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get dockerActionRm;

  /// No description provided for @dockerActionLogs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get dockerActionLogs;

  /// No description provided for @dockerActionInspect.
  ///
  /// In en, this message translates to:
  /// **'Inspect'**
  String get dockerActionInspect;

  /// No description provided for @dockerLogsTitle.
  ///
  /// In en, this message translates to:
  /// **'Container Logs'**
  String get dockerLogsTitle;

  /// No description provided for @dockerInspectTitle.
  ///
  /// In en, this message translates to:
  /// **'Container Inspect'**
  String get dockerInspectTitle;

  /// No description provided for @dockerNoContainers.
  ///
  /// In en, this message translates to:
  /// **'No containers found on server'**
  String get dockerNoContainers;

  /// No description provided for @dockerEmptyRunning.
  ///
  /// In en, this message translates to:
  /// **'No running containers'**
  String get dockerEmptyRunning;

  /// No description provided for @dockerPorts.
  ///
  /// In en, this message translates to:
  /// **'Ports'**
  String get dockerPorts;

  /// No description provided for @dockerCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get dockerCreated;

  /// No description provided for @dockerImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get dockerImage;

  /// No description provided for @systemTitle.
  ///
  /// In en, this message translates to:
  /// **'Processes & Services'**
  String get systemTitle;

  /// No description provided for @tabProcesses.
  ///
  /// In en, this message translates to:
  /// **'Processes'**
  String get tabProcesses;

  /// No description provided for @tabServices.
  ///
  /// In en, this message translates to:
  /// **'Systemd Services'**
  String get tabServices;

  /// No description provided for @processSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by process name or PID...'**
  String get processSearchHint;

  /// No description provided for @processPid.
  ///
  /// In en, this message translates to:
  /// **'PID'**
  String get processPid;

  /// No description provided for @processCpu.
  ///
  /// In en, this message translates to:
  /// **'CPU %'**
  String get processCpu;

  /// No description provided for @processMem.
  ///
  /// In en, this message translates to:
  /// **'MEM %'**
  String get processMem;

  /// No description provided for @processStat.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get processStat;

  /// No description provided for @processCommand.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get processCommand;

  /// No description provided for @processTerminate.
  ///
  /// In en, this message translates to:
  /// **'Terminate (SIGTERM)'**
  String get processTerminate;

  /// No description provided for @processForceKill.
  ///
  /// In en, this message translates to:
  /// **'Force Kill (SIGKILL)'**
  String get processForceKill;

  /// No description provided for @processKillForbidden.
  ///
  /// In en, this message translates to:
  /// **'Refusing to terminate system init (PID <= 1)'**
  String get processKillForbidden;

  /// No description provided for @serviceSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search services by name...'**
  String get serviceSearchHint;

  /// No description provided for @serviceName.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get serviceName;

  /// No description provided for @serviceDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get serviceDescription;

  /// No description provided for @serviceStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get serviceStatus;

  /// No description provided for @serviceStartup.
  ///
  /// In en, this message translates to:
  /// **'Startup'**
  String get serviceStartup;

  /// No description provided for @serviceActionStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get serviceActionStart;

  /// No description provided for @serviceActionStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get serviceActionStop;

  /// No description provided for @serviceActionRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get serviceActionRestart;

  /// No description provided for @serviceActionReload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get serviceActionReload;

  /// No description provided for @serviceActionEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get serviceActionEnable;

  /// No description provided for @serviceActionDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get serviceActionDisable;

  /// No description provided for @serviceNoServices.
  ///
  /// In en, this message translates to:
  /// **'No systemd services found'**
  String get serviceNoServices;

  /// No description provided for @riskDangerTitle.
  ///
  /// In en, this message translates to:
  /// **'High Risk Operation Confirmation'**
  String get riskDangerTitle;

  /// No description provided for @riskWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Operation Warning Confirmation'**
  String get riskWarningTitle;

  /// No description provided for @riskSafeTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Action'**
  String get riskSafeTitle;

  /// No description provided for @riskIrreversibleWarning.
  ///
  /// In en, this message translates to:
  /// **'This operation is classified as HIGH RISK and cannot be undone. It may cause data loss or service disruption.'**
  String get riskIrreversibleWarning;

  /// No description provided for @riskWarningDescription.
  ///
  /// In en, this message translates to:
  /// **'This operation may affect active services or restart processes. Proceed with caution.'**
  String get riskWarningDescription;

  /// No description provided for @riskCommandPreview.
  ///
  /// In en, this message translates to:
  /// **'Command Preview'**
  String get riskCommandPreview;

  /// No description provided for @riskConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Proceed'**
  String get riskConfirmButton;

  /// No description provided for @riskCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get riskCancelButton;

  /// No description provided for @stateLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading remote data...'**
  String get stateLoading;

  /// No description provided for @stateOffline.
  ///
  /// In en, this message translates to:
  /// **'Server is offline'**
  String get stateOffline;

  /// No description provided for @stateOfflineDesc.
  ///
  /// In en, this message translates to:
  /// **'Establish an active SSH connection to manage resources and stream metrics.'**
  String get stateOfflineDesc;

  /// No description provided for @stateError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get stateError;

  /// No description provided for @stateRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get stateRetry;

  /// No description provided for @stateEmpty.
  ///
  /// In en, this message translates to:
  /// **'No items found'**
  String get stateEmpty;

  /// No description provided for @inspectorTitle.
  ///
  /// In en, this message translates to:
  /// **'Inspector'**
  String get inspectorTitle;

  /// No description provided for @inspectorClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get inspectorClose;

  /// No description provided for @inspectorDetails.
  ///
  /// In en, this message translates to:
  /// **'Inspect Details'**
  String get inspectorDetails;

  /// No description provided for @selectServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Target Server'**
  String get selectServerTitle;

  /// No description provided for @sshDisconnectedSuccess.
  ///
  /// In en, this message translates to:
  /// **'SSH connection disconnected'**
  String get sshDisconnectedSuccess;

  /// No description provided for @trustHostFingerprintTitle.
  ///
  /// In en, this message translates to:
  /// **'Trust Host Fingerprint?'**
  String get trustHostFingerprintTitle;

  /// No description provided for @trustAndConnect.
  ///
  /// In en, this message translates to:
  /// **'Trust & Connect'**
  String get trustAndConnect;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @confirmDeleteServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Server'**
  String get confirmDeleteServerTitle;

  /// No description provided for @noServersFound.
  ///
  /// In en, this message translates to:
  /// **'No servers configured yet'**
  String get noServersFound;

  /// No description provided for @agentNotReadyError.
  ///
  /// In en, this message translates to:
  /// **'Selected agent is not ready. Please verify its environment and configuration.'**
  String get agentNotReadyError;

  /// No description provided for @sshDisconnectedError.
  ///
  /// In en, this message translates to:
  /// **'SSH is disconnected. Please connect to a server before using AI Ops.'**
  String get sshDisconnectedError;

  /// No description provided for @noAgentAvailable.
  ///
  /// In en, this message translates to:
  /// **'No Agent Available'**
  String get noAgentAvailable;

  /// No description provided for @noAgentAvailablePrompt.
  ///
  /// In en, this message translates to:
  /// **'No active Agent available. Please configure or ready an agent first.'**
  String get noAgentAvailablePrompt;

  /// No description provided for @noAgentAvailableHint.
  ///
  /// In en, this message translates to:
  /// **'Select or configure an available agent to chat...'**
  String get noAgentAvailableHint;

  /// No description provided for @manageAgents.
  ///
  /// In en, this message translates to:
  /// **'Manage Agents'**
  String get manageAgents;

  /// No description provided for @noReadyAgentsTitle.
  ///
  /// In en, this message translates to:
  /// **'No Ready Agents'**
  String get noReadyAgentsTitle;

  /// No description provided for @noReadyAgentsDesc.
  ///
  /// In en, this message translates to:
  /// **'No agents on this server have passed environment checks.'**
  String get noReadyAgentsDesc;

  /// No description provided for @agentStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get agentStatusReady;

  /// No description provided for @agentStatusChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get agentStatusChecking;

  /// No description provided for @agentStatusCliMissing.
  ///
  /// In en, this message translates to:
  /// **'Installation not detected'**
  String get agentStatusCliMissing;

  /// No description provided for @agentStatusAcpMissing.
  ///
  /// In en, this message translates to:
  /// **'ACP component not detected'**
  String get agentStatusAcpMissing;

  /// No description provided for @agentStatusNotLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Not Logged In'**
  String get agentStatusNotLoggedIn;

  /// No description provided for @agentStatusError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get agentStatusError;

  /// No description provided for @agentStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get agentStatusUnknown;

  /// No description provided for @agentActionInstall.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get agentActionInstall;

  /// No description provided for @agentActionLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get agentActionLogin;

  /// No description provided for @agentActionRefresh.
  ///
  /// In en, this message translates to:
  /// **'Check Status'**
  String get agentActionRefresh;

  /// No description provided for @noConfiguredAgents.
  ///
  /// In en, this message translates to:
  /// **'No agents configured on this server'**
  String get noConfiguredAgents;

  /// No description provided for @agentManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'Agent Management'**
  String get agentManagementTitle;

  /// No description provided for @settingsAgentManagement.
  ///
  /// In en, this message translates to:
  /// **'Agent Management'**
  String get settingsAgentManagement;

  /// No description provided for @settingsAgentManagementSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure, detect and manage ACP Agents for current server'**
  String get settingsAgentManagementSubtitle;

  /// No description provided for @addAgentButton.
  ///
  /// In en, this message translates to:
  /// **'Add Agent'**
  String get addAgentButton;

  /// No description provided for @noServerSelectedForAgents.
  ///
  /// In en, this message translates to:
  /// **'No server selected. Please select a server from the main interface first.'**
  String get noServerSelectedForAgents;

  /// No description provided for @sshDisconnectedAgentWarning.
  ///
  /// In en, this message translates to:
  /// **'SSH is disconnected. Detection, installation, and login are disabled until connection is established.'**
  String get sshDisconnectedAgentWarning;

  /// No description provided for @noAgentsConfiguredTitle.
  ///
  /// In en, this message translates to:
  /// **'No Agents Configured'**
  String get noAgentsConfiguredTitle;

  /// No description provided for @noAgentsConfiguredDesc.
  ///
  /// In en, this message translates to:
  /// **'Add Claude Code, Codex, OpenCode, AGY or custom ACP agents to enable AI Ops on this server.'**
  String get noAgentsConfiguredDesc;

  /// No description provided for @agentPresetLabel.
  ///
  /// In en, this message translates to:
  /// **'Preset'**
  String get agentPresetLabel;

  /// No description provided for @agentPresetClaudeCode.
  ///
  /// In en, this message translates to:
  /// **'Claude Code'**
  String get agentPresetClaudeCode;

  /// No description provided for @agentPresetCodex.
  ///
  /// In en, this message translates to:
  /// **'OpenAI Codex'**
  String get agentPresetCodex;

  /// No description provided for @agentPresetOpenCode.
  ///
  /// In en, this message translates to:
  /// **'OpenCode ACP'**
  String get agentPresetOpenCode;

  /// No description provided for @agentPresetAgy.
  ///
  /// In en, this message translates to:
  /// **'Antigravity AGY'**
  String get agentPresetAgy;

  /// No description provided for @agentPresetCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get agentPresetCustom;

  /// No description provided for @agentNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Agent Name'**
  String get agentNameLabel;

  /// No description provided for @agentNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Production Codex'**
  String get agentNameHint;

  /// No description provided for @agentDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get agentDescriptionLabel;

  /// No description provided for @agentDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Brief description of the agent'**
  String get agentDescriptionHint;

  /// No description provided for @agentCliCommandLabel.
  ///
  /// In en, this message translates to:
  /// **'CLI Probe Command'**
  String get agentCliCommandLabel;

  /// No description provided for @agentCliCommandHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. claude, codex'**
  String get agentCliCommandHint;

  /// No description provided for @agentAcpCommandLabel.
  ///
  /// In en, this message translates to:
  /// **'ACP Launch Command'**
  String get agentAcpCommandLabel;

  /// No description provided for @agentAcpCommandHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. codex-acp --stdio'**
  String get agentAcpCommandHint;

  /// No description provided for @agentInstallCommandLabel.
  ///
  /// In en, this message translates to:
  /// **'Install Command (Optional)'**
  String get agentInstallCommandLabel;

  /// No description provided for @agentInstallCommandHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. npm install -g @openai/codex'**
  String get agentInstallCommandHint;

  /// No description provided for @agentLoginCheckCommandLabel.
  ///
  /// In en, this message translates to:
  /// **'Login Check Command (Optional)'**
  String get agentLoginCheckCommandLabel;

  /// No description provided for @agentLoginCheckCommandHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. codex --version'**
  String get agentLoginCheckCommandHint;

  /// No description provided for @agentLoginCommandLabel.
  ///
  /// In en, this message translates to:
  /// **'Login Command (Optional)'**
  String get agentLoginCommandLabel;

  /// No description provided for @agentLoginCommandHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. codex login'**
  String get agentLoginCommandHint;

  /// No description provided for @agentSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save & Detect'**
  String get agentSaveButton;

  /// No description provided for @agentCliRequired.
  ///
  /// In en, this message translates to:
  /// **'CLI probe command is required'**
  String get agentCliRequired;

  /// No description provided for @agentAcpRequired.
  ///
  /// In en, this message translates to:
  /// **'ACP launch command is required'**
  String get agentAcpRequired;

  /// No description provided for @agentNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Agent name is required'**
  String get agentNameRequired;

  /// No description provided for @confirmInstallAgentTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Agent Installation'**
  String get confirmInstallAgentTitle;

  /// No description provided for @confirmLoginAgentTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Agent Login'**
  String get confirmLoginAgentTitle;

  /// No description provided for @agentCommandRiskWarning.
  ///
  /// In en, this message translates to:
  /// **'This command will be executed directly on the remote server with current user privileges. It may install packages or modify system environments.'**
  String get agentCommandRiskWarning;

  /// No description provided for @targetServerLabel.
  ///
  /// In en, this message translates to:
  /// **'Target Server'**
  String get targetServerLabel;

  /// No description provided for @commandPreviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Command Preview'**
  String get commandPreviewLabel;

  /// No description provided for @executeButton.
  ///
  /// In en, this message translates to:
  /// **'Execute'**
  String get executeButton;

  /// No description provided for @deleteAgentTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Agent'**
  String get deleteAgentTitle;

  /// No description provided for @deleteAgentConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAgentConfirm;

  /// No description provided for @agentStatusCheckingDesc.
  ///
  /// In en, this message translates to:
  /// **'Detecting environment on remote server...'**
  String get agentStatusCheckingDesc;

  /// No description provided for @agentStatusInstalling.
  ///
  /// In en, this message translates to:
  /// **'Installing dependencies on server...'**
  String get agentStatusInstalling;

  /// No description provided for @agentStatusLoggingIn.
  ///
  /// In en, this message translates to:
  /// **'Executing login command on server...'**
  String get agentStatusLoggingIn;

  /// No description provided for @agentNoLoginCheckProvided.
  ///
  /// In en, this message translates to:
  /// **'No login check command specified'**
  String get agentNoLoginCheckProvided;

  /// No description provided for @agentInstallPrompt.
  ///
  /// In en, this message translates to:
  /// **'Installation not detected. Auto-install now?'**
  String get agentInstallPrompt;

  /// No description provided for @agentActionAutoInstall.
  ///
  /// In en, this message translates to:
  /// **'Auto Install'**
  String get agentActionAutoInstall;

  /// No description provided for @agentLoginPrompt.
  ///
  /// In en, this message translates to:
  /// **'Not logged in. Log in now?'**
  String get agentLoginPrompt;

  /// No description provided for @agentActionExecuteLogin.
  ///
  /// In en, this message translates to:
  /// **'Log In Now'**
  String get agentActionExecuteLogin;

  /// No description provided for @agentNeedsInstallOrReadyPrompt.
  ///
  /// In en, this message translates to:
  /// **'Agents on this server are not installed or ready yet. Please manage and complete environment setup.'**
  String get agentNeedsInstallOrReadyPrompt;

  /// No description provided for @agentNeedsInstallOrReadyHint.
  ///
  /// In en, this message translates to:
  /// **'Install and ready an agent to start chatting...'**
  String get agentNeedsInstallOrReadyHint;

  /// No description provided for @agentAcpInstallPrompt.
  ///
  /// In en, this message translates to:
  /// **'ACP component not detected. Auto-install now?'**
  String get agentAcpInstallPrompt;

  /// No description provided for @agentInstallCommandAcpLabel.
  ///
  /// In en, this message translates to:
  /// **'ACP Install Command (Optional)'**
  String get agentInstallCommandAcpLabel;

  /// No description provided for @agentInstallCommandAcpHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. npm install -g @zed-industries/codex-acp'**
  String get agentInstallCommandAcpHint;

  /// No description provided for @agentNoInstallCommand.
  ///
  /// In en, this message translates to:
  /// **'No install command configured for this agent'**
  String get agentNoInstallCommand;

  /// No description provided for @agentInstallLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Install output'**
  String get agentInstallLogTitle;

  /// No description provided for @agentInstallLogEmpty.
  ///
  /// In en, this message translates to:
  /// **'Waiting for install output…'**
  String get agentInstallLogEmpty;

  /// No description provided for @agentInstallLogTruncated.
  ///
  /// In en, this message translates to:
  /// **'Output too long; showing the most recent lines'**
  String get agentInstallLogTruncated;

  /// No description provided for @agentAcpOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional; leave empty for CLI-only'**
  String get agentAcpOptional;

  /// No description provided for @acpStreaming.
  ///
  /// In en, this message translates to:
  /// **'ACP Streaming...'**
  String get acpStreaming;

  /// No description provided for @aiOpsAgentTitle.
  ///
  /// In en, this message translates to:
  /// **'Valhalla AI Ops Agent'**
  String get aiOpsAgentTitle;

  /// No description provided for @aiOpsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connected via ACP stdio over SSH Channel'**
  String get aiOpsEmptySubtitle;

  /// No description provided for @agentAuthRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Authentication Required'**
  String get agentAuthRequiredTitle;

  /// No description provided for @agentAuthRequiredDesc.
  ///
  /// In en, this message translates to:
  /// **'The agent requires authentication before it can process your request.'**
  String get agentAuthRequiredDesc;

  /// No description provided for @agentAuthMethodLabel.
  ///
  /// In en, this message translates to:
  /// **'Authentication Method'**
  String get agentAuthMethodLabel;

  /// No description provided for @agentAuthNoMethodsNotice.
  ///
  /// In en, this message translates to:
  /// **'The agent did not provide a login method. Please check its configuration on the server.'**
  String get agentAuthNoMethodsNotice;

  /// No description provided for @agentAuthProceedButton.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get agentAuthProceedButton;

  /// No description provided for @agentAuthCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get agentAuthCancelButton;

  /// No description provided for @agentAuthRetryHint.
  ///
  /// In en, this message translates to:
  /// **'After logging in, send your message again.'**
  String get agentAuthRetryHint;

  /// No description provided for @agentAuthRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Authentication required. Please log in to continue.'**
  String get agentAuthRequiredError;

  /// No description provided for @agentLoginTerminalTitle.
  ///
  /// In en, this message translates to:
  /// **'Interactive Login Terminal'**
  String get agentLoginTerminalTitle;

  /// No description provided for @agentLoginTerminalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Complete the login steps in the terminal below. Follow any URL or code prompt shown.'**
  String get agentLoginTerminalSubtitle;

  /// No description provided for @agentLoginTerminalRunning.
  ///
  /// In en, this message translates to:
  /// **'Login command is running in the terminal...'**
  String get agentLoginTerminalRunning;

  /// No description provided for @agentLoginTerminalDisconnected.
  ///
  /// In en, this message translates to:
  /// **'SSH connection lost. The login session was interrupted.'**
  String get agentLoginTerminalDisconnected;

  /// No description provided for @agentLoginTerminalRetry.
  ///
  /// In en, this message translates to:
  /// **'Reconnect Terminal'**
  String get agentLoginTerminalRetry;

  /// No description provided for @agentLoginTerminalFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish & Verify'**
  String get agentLoginTerminalFinish;

  /// No description provided for @agentLoginTerminalClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get agentLoginTerminalClose;

  /// No description provided for @agentLoginTerminalNoTtyHint.
  ///
  /// In en, this message translates to:
  /// **'If the agent requires pasting a code, long-press the terminal to paste or use the PASTE key.'**
  String get agentLoginTerminalNoTtyHint;

  /// No description provided for @agentLoginTerminalUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Login URL detected'**
  String get agentLoginTerminalUrlLabel;

  /// No description provided for @agentLoginTerminalUrlCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get agentLoginTerminalUrlCopy;

  /// No description provided for @agentLoginTerminalUrlCopied.
  ///
  /// In en, this message translates to:
  /// **'Login URL copied to clipboard'**
  String get agentLoginTerminalUrlCopied;

  /// No description provided for @agentLoginTerminalCopyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy all output'**
  String get agentLoginTerminalCopyAll;

  /// No description provided for @agentLoginTerminalCopiedAll.
  ///
  /// In en, this message translates to:
  /// **'Terminal output copied to clipboard'**
  String get agentLoginTerminalCopiedAll;

  /// No description provided for @sshStatusReconnected.
  ///
  /// In en, this message translates to:
  /// **'Connection restored'**
  String get sshStatusReconnected;

  /// No description provided for @sshStatusDisconnectedRetrying.
  ///
  /// In en, this message translates to:
  /// **'Connection lost, retrying'**
  String get sshStatusDisconnectedRetrying;

  /// No description provided for @sshStatusDisconnectedManual.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get sshStatusDisconnectedManual;

  /// No description provided for @sshStatusHostKeyChanged.
  ///
  /// In en, this message translates to:
  /// **'Host key changed — connection refused'**
  String get sshStatusHostKeyChanged;

  /// No description provided for @sshKeepAliveNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Valhalla is keeping your sessions alive'**
  String get sshKeepAliveNotificationTitle;

  /// No description provided for @terminalTmuxMissingNotice.
  ///
  /// In en, this message translates to:
  /// **'tmux not found — sessions won\'t survive a drop'**
  String get terminalTmuxMissingNotice;

  /// No description provided for @terminalTmuxSessionRestored.
  ///
  /// In en, this message translates to:
  /// **'Terminal session restored'**
  String get terminalTmuxSessionRestored;

  /// No description provided for @moshSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Mosh'**
  String get moshSectionTitle;

  /// No description provided for @moshEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable Mosh — a roaming terminal that survives connection drops and IP changes'**
  String get moshEnable;

  /// No description provided for @moshServerPathLabel.
  ///
  /// In en, this message translates to:
  /// **'mosh-server path'**
  String get moshServerPathLabel;

  /// No description provided for @moshPortRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'UDP port range'**
  String get moshPortRangeLabel;

  /// No description provided for @moshNewSession.
  ///
  /// In en, this message translates to:
  /// **'New Mosh Session'**
  String get moshNewSession;

  /// No description provided for @moshNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'mosh-server was not found on the remote server. Install it with: sudo apt install mosh (Debian/Ubuntu) or sudo dnf install mosh (Fedora/RHEL).'**
  String get moshNotInstalled;

  /// No description provided for @moshBootstrapFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to start Mosh session: {detail}'**
  String moshBootstrapFailed(String detail);

  /// No description provided for @moshUdpTimeout.
  ///
  /// In en, this message translates to:
  /// **'Mosh connection timed out — check that UDP traffic is not blocked by a firewall.'**
  String get moshUdpTimeout;

  /// No description provided for @moshSessionTag.
  ///
  /// In en, this message translates to:
  /// **'mosh'**
  String get moshSessionTag;

  /// No description provided for @acpSessionRestored.
  ///
  /// In en, this message translates to:
  /// **'Agent session restored'**
  String get acpSessionRestored;

  /// No description provided for @acpSessionRestartNotice.
  ///
  /// In en, this message translates to:
  /// **'Agent session restarted — previous context unavailable'**
  String get acpSessionRestartNotice;

  /// No description provided for @terminalTmuxInstallDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Install tmux on Remote Server?'**
  String get terminalTmuxInstallDialogTitle;

  /// No description provided for @terminalTmuxInstallDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'tmux is required to preserve terminal sessions across disconnections. Would you like to install it now?'**
  String get terminalTmuxInstallDialogMessage;

  /// No description provided for @terminalTmuxInstallCommandLabel.
  ///
  /// In en, this message translates to:
  /// **'Command to execute:'**
  String get terminalTmuxInstallCommandLabel;

  /// No description provided for @terminalTmuxInstallUnsupported.
  ///
  /// In en, this message translates to:
  /// **'No supported package manager detected on remote server. Please install tmux manually.'**
  String get terminalTmuxInstallUnsupported;

  /// No description provided for @terminalTmuxInstallFailed.
  ///
  /// In en, this message translates to:
  /// **'tmux installation failed. Please verify server permissions and network.'**
  String get terminalTmuxInstallFailed;

  /// No description provided for @terminalTmuxInstallDisconnected.
  ///
  /// In en, this message translates to:
  /// **'SSH connection lost. Please reconnect to install tmux.'**
  String get terminalTmuxInstallDisconnected;

  /// No description provided for @terminalTmuxInstallInstalling.
  ///
  /// In en, this message translates to:
  /// **'Installing tmux...'**
  String get terminalTmuxInstallInstalling;

  /// No description provided for @terminalTmuxInstallConfirm.
  ///
  /// In en, this message translates to:
  /// **'Install tmux'**
  String get terminalTmuxInstallConfirm;

  /// No description provided for @terminalTmuxInstallSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip (Use Plain Shell)'**
  String get terminalTmuxInstallSkip;

  /// No description provided for @sftpDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get sftpDownload;

  /// No description provided for @sftpOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get sftpOpen;

  /// No description provided for @sftpUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed. Check permissions and try again.'**
  String get sftpUploadFailed;

  /// No description provided for @sftpDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed. Check permissions and local storage.'**
  String get sftpDownloadFailed;

  /// No description provided for @sftpOpenUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This file format cannot be opened.'**
  String get sftpOpenUnsupported;

  /// No description provided for @sftpReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to read the file. Check permissions and try again.'**
  String get sftpReadFailed;

  /// No description provided for @sftpTransferFailed.
  ///
  /// In en, this message translates to:
  /// **'File operation failed. Please try again.'**
  String get sftpTransferFailed;

  /// No description provided for @sftpDownloadSuccess.
  ///
  /// In en, this message translates to:
  /// **'Downloaded successfully'**
  String get sftpDownloadSuccess;

  /// No description provided for @sftpUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get sftpUploading;

  /// No description provided for @sftpDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get sftpDownloading;

  /// No description provided for @settingsAutoConnect.
  ///
  /// In en, this message translates to:
  /// **'Auto connect on launch'**
  String get settingsAutoConnect;

  /// No description provided for @settingsAutoConnectFixed.
  ///
  /// In en, this message translates to:
  /// **'Fixed default SSH'**
  String get settingsAutoConnectFixed;

  /// No description provided for @settingsAutoConnectFixedDesc.
  ///
  /// In en, this message translates to:
  /// **'Always connect to the server you pick below'**
  String get settingsAutoConnectFixedDesc;

  /// No description provided for @settingsAutoConnectLast.
  ///
  /// In en, this message translates to:
  /// **'Remember last connection'**
  String get settingsAutoConnectLast;

  /// No description provided for @settingsAutoConnectLastDesc.
  ///
  /// In en, this message translates to:
  /// **'Connect to the server that was last connected successfully'**
  String get settingsAutoConnectLastDesc;

  /// No description provided for @settingsAutoConnectPickServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get settingsAutoConnectPickServer;

  /// No description provided for @settingsAutoConnectNoServer.
  ///
  /// In en, this message translates to:
  /// **'No server selected yet'**
  String get settingsAutoConnectNoServer;

  /// No description provided for @sftpSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sftpSort;

  /// No description provided for @sftpSortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sftpSortName;

  /// No description provided for @sftpSortSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get sftpSortSize;

  /// No description provided for @sftpSortDate.
  ///
  /// In en, this message translates to:
  /// **'Date modified'**
  String get sftpSortDate;

  /// No description provided for @sftpSortAscending.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get sftpSortAscending;

  /// No description provided for @sftpSortDescending.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get sftpSortDescending;

  /// No description provided for @themeQuickSwitch.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeQuickSwitch;

  /// No description provided for @transferList.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get transferList;

  /// No description provided for @transferEmpty.
  ///
  /// In en, this message translates to:
  /// **'No transfers yet'**
  String get transferEmpty;

  /// No description provided for @transferUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get transferUpload;

  /// No description provided for @transferDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get transferDownload;

  /// No description provided for @transferStatusQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get transferStatusQueued;

  /// No description provided for @transferStatusRunning.
  ///
  /// In en, this message translates to:
  /// **'Transferring'**
  String get transferStatusRunning;

  /// No description provided for @transferStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get transferStatusPaused;

  /// No description provided for @transferStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get transferStatusCompleted;

  /// No description provided for @transferStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get transferStatusFailed;

  /// No description provided for @transferStatusCanceled.
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get transferStatusCanceled;

  /// No description provided for @transferPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get transferPause;

  /// No description provided for @transferResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get transferResume;

  /// No description provided for @transferCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get transferCancel;

  /// No description provided for @transferRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get transferRemove;

  /// No description provided for @transferClearFinished.
  ///
  /// In en, this message translates to:
  /// **'Clear finished'**
  String get transferClearFinished;

  /// No description provided for @transferSizeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Size unknown'**
  String get transferSizeUnknown;

  /// No description provided for @transferFailedUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get transferFailedUpload;

  /// No description provided for @transferFailedDownload.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get transferFailedDownload;

  /// No description provided for @stopGeneration.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopGeneration;

  /// No description provided for @chatServerBindingRequired.
  ///
  /// In en, this message translates to:
  /// **'This session is not bound to a server. Please bind it to the current server to continue.'**
  String get chatServerBindingRequired;

  /// No description provided for @chatSessionUnboundNotice.
  ///
  /// In en, this message translates to:
  /// **'This session is not bound to any server.'**
  String get chatSessionUnboundNotice;

  /// No description provided for @bindServerAction.
  ///
  /// In en, this message translates to:
  /// **'Bind Server'**
  String get bindServerAction;

  /// No description provided for @bindServerDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Bind Session to Server'**
  String get bindServerDialogTitle;

  /// No description provided for @bindServerConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm Bind'**
  String get bindServerConfirmAction;

  /// No description provided for @chatSessionIdentityMismatch.
  ///
  /// In en, this message translates to:
  /// **'Current server or agent does not match this session\'s bound identity. Switch to the matching server and agent to continue.'**
  String get chatSessionIdentityMismatch;

  /// No description provided for @deleteSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Session'**
  String get deleteSessionTitle;

  /// No description provided for @deleteSessionConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteSessionConfirmAction;

  /// No description provided for @shareAgentSessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Share Agent Sessions'**
  String get shareAgentSessionsTitle;

  /// No description provided for @shareAgentSessionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share sessions across different agents on this server'**
  String get shareAgentSessionsSubtitle;

  /// No description provided for @shareAgentSessionsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Agent session sharing enabled'**
  String get shareAgentSessionsEnabled;

  /// No description provided for @shareAgentSessionsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Agent session sharing disabled'**
  String get shareAgentSessionsDisabled;

  /// No description provided for @agentCliStatusInstalled.
  ///
  /// In en, this message translates to:
  /// **'CLI: Installed'**
  String get agentCliStatusInstalled;

  /// No description provided for @agentCliStatusMissing.
  ///
  /// In en, this message translates to:
  /// **'CLI: Missing'**
  String get agentCliStatusMissing;

  /// No description provided for @agentCliStatusChecking.
  ///
  /// In en, this message translates to:
  /// **'CLI: Checking...'**
  String get agentCliStatusChecking;

  /// No description provided for @agentCliStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'CLI: Unknown'**
  String get agentCliStatusUnknown;

  /// No description provided for @agentCliStatusError.
  ///
  /// In en, this message translates to:
  /// **'CLI: Error'**
  String get agentCliStatusError;

  /// No description provided for @agentAcpStatusReady.
  ///
  /// In en, this message translates to:
  /// **'ACP: Ready'**
  String get agentAcpStatusReady;

  /// No description provided for @agentAcpStatusMissing.
  ///
  /// In en, this message translates to:
  /// **'ACP: Missing'**
  String get agentAcpStatusMissing;

  /// No description provided for @agentAcpStatusChecking.
  ///
  /// In en, this message translates to:
  /// **'ACP: Checking...'**
  String get agentAcpStatusChecking;

  /// No description provided for @agentAcpStatusPendingCli.
  ///
  /// In en, this message translates to:
  /// **'ACP: Pending CLI'**
  String get agentAcpStatusPendingCli;

  /// No description provided for @agentAcpStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'ACP: Unknown'**
  String get agentAcpStatusUnknown;

  /// No description provided for @agentAcpStatusError.
  ///
  /// In en, this message translates to:
  /// **'ACP: Error'**
  String get agentAcpStatusError;

  /// No description provided for @agentAcpStatusNa.
  ///
  /// In en, this message translates to:
  /// **'ACP: N/A'**
  String get agentAcpStatusNa;

  /// No description provided for @agentAuthStatusAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'Auth: Logged In'**
  String get agentAuthStatusAuthenticated;

  /// No description provided for @agentAuthStatusUnauthenticated.
  ///
  /// In en, this message translates to:
  /// **'Auth: Not Logged In'**
  String get agentAuthStatusUnauthenticated;

  /// No description provided for @agentAuthStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Auth: Unknown'**
  String get agentAuthStatusUnknown;

  /// No description provided for @downloadNotificationsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'System download notifications are unavailable. Downloads continue in background.'**
  String get downloadNotificationsUnavailable;

  /// No description provided for @downloadOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open downloaded file.'**
  String get downloadOpenFailed;

  /// No description provided for @dockerActionPending.
  ///
  /// In en, this message translates to:
  /// **'An action is already in progress for this container'**
  String get dockerActionPending;

  /// No description provided for @dockerNoLogs.
  ///
  /// In en, this message translates to:
  /// **'(No logs)'**
  String get dockerNoLogs;

  /// No description provided for @serverReboot.
  ///
  /// In en, this message translates to:
  /// **'Reboot'**
  String get serverReboot;

  /// No description provided for @serverRebootDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Server Reboot'**
  String get serverRebootDialogTitle;

  /// No description provided for @serverRebootDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reboot this server? All active connections and background services will be terminated.'**
  String get serverRebootDialogMessage;

  /// No description provided for @serverRebootConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Reboot Now'**
  String get serverRebootConfirmButton;

  /// No description provided for @serverRebootPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Sudo Password Required'**
  String get serverRebootPasswordTitle;

  /// No description provided for @serverRebootPasswordMessage.
  ///
  /// In en, this message translates to:
  /// **'Root privileges are required to reboot the server. Please enter the sudo password (used once, not saved):'**
  String get serverRebootPasswordMessage;

  /// No description provided for @serverRebootPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Sudo Password'**
  String get serverRebootPasswordHint;

  /// No description provided for @serverRebootSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Sending reboot command...'**
  String get serverRebootSubmitting;

  /// No description provided for @serverRebootAccepted.
  ///
  /// In en, this message translates to:
  /// **'Reboot command accepted; completion not yet verified. Please reconnect when the server is back online.'**
  String get serverRebootAccepted;

  /// No description provided for @serverRebootVerified.
  ///
  /// In en, this message translates to:
  /// **'Server reboot has been verified; the system is back online.'**
  String get serverRebootVerified;

  /// No description provided for @serverRebootUnknown.
  ///
  /// In en, this message translates to:
  /// **'Reboot result is uncertain. The command was dispatched, but completion could not be confirmed. Please check the connection manually.'**
  String get serverRebootUnknown;

  /// No description provided for @serverRebootReconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get serverRebootReconnect;

  /// No description provided for @serverRebootServerChanged.
  ///
  /// In en, this message translates to:
  /// **'Target server changed, reboot cancelled'**
  String get serverRebootServerChanged;

  /// No description provided for @navCliChat.
  ///
  /// In en, this message translates to:
  /// **'CLI Chat'**
  String get navCliChat;

  /// No description provided for @cliChatTitle.
  ///
  /// In en, this message translates to:
  /// **'CLI Sessions'**
  String get cliChatTitle;

  /// No description provided for @cliChatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Native CLI Agent sessions on remote server'**
  String get cliChatSubtitle;

  /// No description provided for @cliSelectAgent.
  ///
  /// In en, this message translates to:
  /// **'Select Agent'**
  String get cliSelectAgent;

  /// No description provided for @cliNoAgentsConfigured.
  ///
  /// In en, this message translates to:
  /// **'No agents added for this server'**
  String get cliNoAgentsConfigured;

  /// No description provided for @cliAgentNeedsSetup.
  ///
  /// In en, this message translates to:
  /// **'Agent environment missing or not logged in'**
  String get cliAgentNeedsSetup;

  /// No description provided for @cliManageAgentsGuide.
  ///
  /// In en, this message translates to:
  /// **'Configure in Agent Management'**
  String get cliManageAgentsGuide;

  /// No description provided for @cliNewDraft.
  ///
  /// In en, this message translates to:
  /// **'New Draft'**
  String get cliNewDraft;

  /// No description provided for @cliNewDraftTooltip.
  ///
  /// In en, this message translates to:
  /// **'Create a blank draft (session created on first message)'**
  String get cliNewDraftTooltip;

  /// No description provided for @cliDeleteSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Remote CLI Session History'**
  String get cliDeleteSessionTitle;

  /// No description provided for @cliDeleteSessionMessage.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete the CLI session history on the remote server. Are you sure you want to proceed?'**
  String get cliDeleteSessionMessage;

  /// No description provided for @cliDeleteConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Delete Session'**
  String get cliDeleteConfirmButton;

  /// No description provided for @cliCannotDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remote session deletion not supported or disabled'**
  String get cliCannotDeleteTooltip;

  /// No description provided for @cliSessionsHeader.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get cliSessionsHeader;

  /// No description provided for @cliNoSessions.
  ///
  /// In en, this message translates to:
  /// **'No CLI sessions found'**
  String get cliNoSessions;

  /// No description provided for @cliFilterCwdHint.
  ///
  /// In en, this message translates to:
  /// **'Filter by CWD path...'**
  String get cliFilterCwdHint;

  /// No description provided for @cliFilterCwdAction.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get cliFilterCwdAction;

  /// No description provided for @cliClearCwdAction.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get cliClearCwdAction;

  /// No description provided for @cliLoadMoreSessions.
  ///
  /// In en, this message translates to:
  /// **'Load More Sessions'**
  String get cliLoadMoreSessions;

  /// No description provided for @cliRefreshSessions.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get cliRefreshSessions;

  /// No description provided for @cliClaudeReadOnlyNotice.
  ///
  /// In en, this message translates to:
  /// **'Claude history is read-only. Continue the conversation in real terminal.'**
  String get cliClaudeReadOnlyNotice;

  /// No description provided for @cliContinueInTerminal.
  ///
  /// In en, this message translates to:
  /// **'Continue in Terminal'**
  String get cliContinueInTerminal;

  /// No description provided for @cliOpenTerminal.
  ///
  /// In en, this message translates to:
  /// **'Open Terminal'**
  String get cliOpenTerminal;

  /// No description provided for @cliCloseTerminal.
  ///
  /// In en, this message translates to:
  /// **'Close Terminal'**
  String get cliCloseTerminal;

  /// No description provided for @cliTerminalRunning.
  ///
  /// In en, this message translates to:
  /// **'Interactive CLI Terminal'**
  String get cliTerminalRunning;

  /// No description provided for @cliAgyTerminalOnlyNotice.
  ///
  /// In en, this message translates to:
  /// **'This agent does not support structured history synchronization. Please use the native CLI terminal for interaction and session selection.'**
  String get cliAgyTerminalOnlyNotice;

  /// No description provided for @cliInstallSdkTitle.
  ///
  /// In en, this message translates to:
  /// **'Install Official Claude History SDK'**
  String get cliInstallSdkTitle;

  /// No description provided for @cliInstallSdkMessage.
  ///
  /// In en, this message translates to:
  /// **'The official Claude Code History SDK is missing on the remote server. Would you like to install it now?'**
  String get cliInstallSdkMessage;

  /// No description provided for @cliInstallSdkAction.
  ///
  /// In en, this message translates to:
  /// **'Install Official SDK'**
  String get cliInstallSdkAction;

  /// No description provided for @cliApprovalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Pending Approvals'**
  String get cliApprovalsTitle;

  /// No description provided for @cliApprovalDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get cliApprovalDetails;

  /// No description provided for @cliApprovalAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get cliApprovalAllow;

  /// No description provided for @cliApprovalDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get cliApprovalDecline;

  /// No description provided for @cliInputHint.
  ///
  /// In en, this message translates to:
  /// **'Type a message to the CLI agent...'**
  String get cliInputHint;

  /// No description provided for @cliSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get cliSend;

  /// No description provided for @cliStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get cliStop;

  /// No description provided for @cliBusy.
  ///
  /// In en, this message translates to:
  /// **'Operation is in progress, please wait...'**
  String get cliBusy;

  /// No description provided for @cliDisconnected.
  ///
  /// In en, this message translates to:
  /// **'SSH is not connected'**
  String get cliDisconnected;

  /// No description provided for @cliServerChanged.
  ///
  /// In en, this message translates to:
  /// **'Target server changed'**
  String get cliServerChanged;

  /// No description provided for @cliTurnFailed.
  ///
  /// In en, this message translates to:
  /// **'CLI turn execution failed'**
  String get cliTurnFailed;

  /// No description provided for @cliUseTerminal.
  ///
  /// In en, this message translates to:
  /// **'Interactive prompt required, please open terminal to continue'**
  String get cliUseTerminal;

  /// No description provided for @cliDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete remote session'**
  String get cliDeleteFailed;

  /// No description provided for @cliDeleteUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Deleting remote sessions is not supported by this CLI'**
  String get cliDeleteUnsupported;

  /// No description provided for @cliOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'CLI operation failed'**
  String get cliOperationFailed;

  /// No description provided for @cliHistorySdkMissing.
  ///
  /// In en, this message translates to:
  /// **'Official History SDK is missing on the server'**
  String get cliHistorySdkMissing;

  /// No description provided for @cliHistoryRuntimeMissing.
  ///
  /// In en, this message translates to:
  /// **'Claude history requires Node.js/npm on the server. Please install Node.js manually; you can still use the real CLI in terminal.'**
  String get cliHistoryRuntimeMissing;

  /// No description provided for @cliLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Agent login required. Please log in via Agent Management.'**
  String get cliLoginRequired;

  /// No description provided for @cliNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'Agent CLI not installed. Please install it via Agent Management.'**
  String get cliNotInstalled;

  /// No description provided for @cliVersionUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Agent CLI version is unsupported. Please upgrade or reinstall via Agent Management.'**
  String get cliVersionUnsupported;

  /// No description provided for @settingsNavigation.
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get settingsNavigation;

  /// No description provided for @settingsNavigationDesc.
  ///
  /// In en, this message translates to:
  /// **'Configure default startup page and bottom navigation bar'**
  String get settingsNavigationDesc;

  /// No description provided for @settingsStartupPage.
  ///
  /// In en, this message translates to:
  /// **'Startup Page'**
  String get settingsStartupPage;

  /// No description provided for @settingsStartupPageDesc.
  ///
  /// In en, this message translates to:
  /// **'Page displayed when app opens'**
  String get settingsStartupPageDesc;

  /// No description provided for @settingsBottomNav.
  ///
  /// In en, this message translates to:
  /// **'Bottom Navigation Bar'**
  String get settingsBottomNav;

  /// No description provided for @settingsBottomNavDesc.
  ///
  /// In en, this message translates to:
  /// **'Select sections to display in mobile bottom bar (supports 0 to 9 items)'**
  String get settingsBottomNavDesc;

  /// No description provided for @settingsResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'All settings restored to defaults'**
  String get settingsResetSuccess;

  /// No description provided for @metricsTrendSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Last ~3 minutes (up to 60 samples)'**
  String get metricsTrendSubtitle;

  /// No description provided for @metricsCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get metricsCurrent;

  /// No description provided for @metricsPeak.
  ///
  /// In en, this message translates to:
  /// **'Peak'**
  String get metricsPeak;

  /// No description provided for @metricsValley.
  ///
  /// In en, this message translates to:
  /// **'Valley'**
  String get metricsValley;

  /// No description provided for @metricsTrendWaiting.
  ///
  /// In en, this message translates to:
  /// **'Collecting metrics data...'**
  String get metricsTrendWaiting;

  /// No description provided for @metricsTrendStopped.
  ///
  /// In en, this message translates to:
  /// **'Data collection stopped (SSH disconnected)'**
  String get metricsTrendStopped;

  /// No description provided for @dockerActionTerminal.
  ///
  /// In en, this message translates to:
  /// **'Exec Terminal'**
  String get dockerActionTerminal;

  /// No description provided for @dockerTerminalTitle.
  ///
  /// In en, this message translates to:
  /// **'Container Terminal'**
  String get dockerTerminalTitle;

  /// No description provided for @dockerTerminalNotRunning.
  ///
  /// In en, this message translates to:
  /// **'Container is not running'**
  String get dockerTerminalNotRunning;

  /// No description provided for @setDefaultAgent.
  ///
  /// In en, this message translates to:
  /// **'Set as default'**
  String get setDefaultAgent;

  /// No description provided for @defaultBadge.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultBadge;

  /// No description provided for @isDefaultAgent.
  ///
  /// In en, this message translates to:
  /// **'Default Agent'**
  String get isDefaultAgent;

  /// No description provided for @setAsDefaultAgent.
  ///
  /// In en, this message translates to:
  /// **'Set as default agent for this server'**
  String get setAsDefaultAgent;

  /// No description provided for @agentGroupBasic.
  ///
  /// In en, this message translates to:
  /// **'Basic Information'**
  String get agentGroupBasic;

  /// No description provided for @agentGroupCommands.
  ///
  /// In en, this message translates to:
  /// **'Commands'**
  String get agentGroupCommands;

  /// No description provided for @agentGroupAuth.
  ///
  /// In en, this message translates to:
  /// **'Install & Authentication'**
  String get agentGroupAuth;

  /// No description provided for @agentPresetTitle.
  ///
  /// In en, this message translates to:
  /// **'Preset Template'**
  String get agentPresetTitle;

  /// No description provided for @resourceProcessList.
  ///
  /// In en, this message translates to:
  /// **'Processes'**
  String get resourceProcessList;

  /// No description provided for @resourceDiskScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning root directories, this may take a few seconds...'**
  String get resourceDiskScanning;

  /// No description provided for @resourceDiskScanPartial.
  ///
  /// In en, this message translates to:
  /// **'Some directories could not be scanned due to permissions or timeout'**
  String get resourceDiskScanPartial;

  /// No description provided for @resourceDiskDirectories.
  ///
  /// In en, this message translates to:
  /// **'Top-level Directory Usage'**
  String get resourceDiskDirectories;

  /// No description provided for @resourceSortCpu.
  ///
  /// In en, this message translates to:
  /// **'Sort by CPU'**
  String get resourceSortCpu;

  /// No description provided for @resourceSortMemory.
  ///
  /// In en, this message translates to:
  /// **'Sort by Memory'**
  String get resourceSortMemory;

  /// No description provided for @resourceRss.
  ///
  /// In en, this message translates to:
  /// **'RSS Memory'**
  String get resourceRss;

  /// No description provided for @resourceUsed.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get resourceUsed;

  /// No description provided for @resourceAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get resourceAvailable;

  /// No description provided for @resourceTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get resourceTotal;

  /// No description provided for @settingsBottomNavOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Selected Items (Drag to reorder)'**
  String get settingsBottomNavOrderTitle;

  /// No description provided for @langSystem.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get langSystem;

  /// No description provided for @serverFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get serverFieldRequired;

  /// No description provided for @serverPortInvalid.
  ///
  /// In en, this message translates to:
  /// **'Port must be between 1 and 65535'**
  String get serverPortInvalid;

  /// No description provided for @serverTestReachability.
  ///
  /// In en, this message translates to:
  /// **'Test Reachability'**
  String get serverTestReachability;

  /// No description provided for @serverSaveFailedGeneric.
  ///
  /// In en, this message translates to:
  /// **'Failed to save server. Please check your configuration and try again.'**
  String get serverSaveFailedGeneric;

  /// No description provided for @serverViewPrivateKey.
  ///
  /// In en, this message translates to:
  /// **'View Private Key'**
  String get serverViewPrivateKey;

  /// No description provided for @serverHidePrivateKey.
  ///
  /// In en, this message translates to:
  /// **'Hide Private Key'**
  String get serverHidePrivateKey;

  /// No description provided for @dockerBashFallbackNotice.
  ///
  /// In en, this message translates to:
  /// **'Bash is unavailable in container, fallback to Sh'**
  String get dockerBashFallbackNotice;

  /// No description provided for @dockerShellLabel.
  ///
  /// In en, this message translates to:
  /// **'Shell'**
  String get dockerShellLabel;

  /// No description provided for @dockerShellBash.
  ///
  /// In en, this message translates to:
  /// **'Bash'**
  String get dockerShellBash;

  /// No description provided for @dockerShellSh.
  ///
  /// In en, this message translates to:
  /// **'Sh'**
  String get dockerShellSh;

  /// No description provided for @cliDraftWorkingDirLabel.
  ///
  /// In en, this message translates to:
  /// **'Working Directory'**
  String get cliDraftWorkingDirLabel;

  /// No description provided for @cliDefaultWorkingDir.
  ///
  /// In en, this message translates to:
  /// **'Default (/)'**
  String get cliDefaultWorkingDir;

  /// No description provided for @cliPickWorkingDirTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Working Directory'**
  String get cliPickWorkingDirTitle;

  /// No description provided for @cliClearWorkingDir.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get cliClearWorkingDir;

  /// No description provided for @cliBrowseWorkingDir.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get cliBrowseWorkingDir;

  /// No description provided for @cliSelectCurrentDir.
  ///
  /// In en, this message translates to:
  /// **'Select This Directory'**
  String get cliSelectCurrentDir;

  /// No description provided for @cliNavigateUp.
  ///
  /// In en, this message translates to:
  /// **'Go up'**
  String get cliNavigateUp;

  /// No description provided for @chatSessionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get chatSessionsTooltip;

  /// No description provided for @hardwareSpecsTitle.
  ///
  /// In en, this message translates to:
  /// **'Hardware & System'**
  String get hardwareSpecsTitle;

  /// No description provided for @hardwareCpu.
  ///
  /// In en, this message translates to:
  /// **'CPU'**
  String get hardwareCpu;

  /// No description provided for @hardwareMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get hardwareMemory;

  /// No description provided for @hardwareDisk.
  ///
  /// In en, this message translates to:
  /// **'Root Disk'**
  String get hardwareDisk;

  /// No description provided for @hardwareDistribution.
  ///
  /// In en, this message translates to:
  /// **'OS'**
  String get hardwareDistribution;

  /// No description provided for @hardwareKernel.
  ///
  /// In en, this message translates to:
  /// **'Kernel'**
  String get hardwareKernel;

  /// No description provided for @hardwareLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading hardware specs...'**
  String get hardwareLoading;

  /// No description provided for @hardwareUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Hardware specs unavailable'**
  String get hardwareUnavailable;

  /// No description provided for @hardwareUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get hardwareUnknown;

  /// No description provided for @systemInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'System Info'**
  String get systemInfoTitle;

  /// No description provided for @systemInfoTapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to view ASCII art'**
  String get systemInfoTapHint;

  /// No description provided for @systemInfoHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get systemInfoHost;

  /// No description provided for @serverShutdown.
  ///
  /// In en, this message translates to:
  /// **'Shutdown'**
  String get serverShutdown;

  /// No description provided for @serverShutdownDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Server Shutdown'**
  String get serverShutdownDialogTitle;

  /// No description provided for @serverShutdownDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to shut down this server? The system will be powered off completely and cannot be accessed remotely until powered on manually.'**
  String get serverShutdownDialogMessage;

  /// No description provided for @serverShutdownConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Shut Down Now'**
  String get serverShutdownConfirmButton;

  /// No description provided for @serverShutdownSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Sending shutdown command...'**
  String get serverShutdownSubmitting;

  /// No description provided for @serverShutdownAccepted.
  ///
  /// In en, this message translates to:
  /// **'Shutdown command accepted; shutdown completion has not been verified.'**
  String get serverShutdownAccepted;

  /// No description provided for @serverShutdownUnknown.
  ///
  /// In en, this message translates to:
  /// **'Shutdown result unknown: The command may have been sent but cannot be confirmed. Please check manually; it will not be retried automatically.'**
  String get serverShutdownUnknown;

  /// No description provided for @serverShutdownPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Sudo Password Required for Shutdown'**
  String get serverShutdownPasswordTitle;

  /// No description provided for @serverShutdownPasswordMessage.
  ///
  /// In en, this message translates to:
  /// **'Root privileges are required to shut down the server. Please enter the sudo password (used once, not saved):'**
  String get serverShutdownPasswordMessage;

  /// No description provided for @serverShutdownPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Sudo Password'**
  String get serverShutdownPasswordHint;

  /// No description provided for @serverShutdownServerChanged.
  ///
  /// In en, this message translates to:
  /// **'Target server changed, shutdown cancelled'**
  String get serverShutdownServerChanged;

  /// No description provided for @metricsNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network Rate'**
  String get metricsNetwork;

  /// No description provided for @networkModalTitle.
  ///
  /// In en, this message translates to:
  /// **'Network Interfaces Details'**
  String get networkModalTitle;

  /// No description provided for @networkDownloadRate.
  ///
  /// In en, this message translates to:
  /// **'Download (RX)'**
  String get networkDownloadRate;

  /// No description provided for @networkUploadRate.
  ///
  /// In en, this message translates to:
  /// **'Upload (TX)'**
  String get networkUploadRate;

  /// No description provided for @networkTotalRx.
  ///
  /// In en, this message translates to:
  /// **'Total RX'**
  String get networkTotalRx;

  /// No description provided for @networkTotalTx.
  ///
  /// In en, this message translates to:
  /// **'Total TX'**
  String get networkTotalTx;

  /// No description provided for @networkPrimary.
  ///
  /// In en, this message translates to:
  /// **'Default Route'**
  String get networkPrimary;

  /// No description provided for @networkRatesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No active network interfaces detected'**
  String get networkRatesEmpty;

  /// No description provided for @networkWaitingSecondSample.
  ///
  /// In en, this message translates to:
  /// **'Waiting for second sample'**
  String get networkWaitingSecondSample;

  /// No description provided for @networkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get networkUnavailable;

  /// No description provided for @networkNoDefaultInterface.
  ///
  /// In en, this message translates to:
  /// **'No default route'**
  String get networkNoDefaultInterface;

  /// No description provided for @selectThemeModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Theme Mode'**
  String get selectThemeModeTitle;

  /// No description provided for @selectLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguageTitle;

  /// No description provided for @selectStartupPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Startup Page'**
  String get selectStartupPageTitle;

  /// No description provided for @selectAutoConnectModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Auto-connect Mode'**
  String get selectAutoConnectModeTitle;

  /// No description provided for @accentColorDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Customize Accent Colors'**
  String get accentColorDialogTitle;

  /// No description provided for @accentColorLightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get accentColorLightMode;

  /// No description provided for @accentColorDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get accentColorDarkMode;

  /// No description provided for @accentColorAmoledMode.
  ///
  /// In en, this message translates to:
  /// **'AMOLED (Geek)'**
  String get accentColorAmoledMode;

  /// No description provided for @accentColorPresets.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get accentColorPresets;

  /// No description provided for @accentColorHsvPicker.
  ///
  /// In en, this message translates to:
  /// **'Color Wheel'**
  String get accentColorHsvPicker;

  /// No description provided for @accentColorHexCode.
  ///
  /// In en, this message translates to:
  /// **'Hex Color'**
  String get accentColorHexCode;

  /// No description provided for @accentColorPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get accentColorPreview;

  /// No description provided for @accentColorSampleButton.
  ///
  /// In en, this message translates to:
  /// **'Accent Button'**
  String get accentColorSampleButton;

  /// No description provided for @accentColorInvalidHex.
  ///
  /// In en, this message translates to:
  /// **'Invalid hex format (e.g. #10B981)'**
  String get accentColorInvalidHex;

  /// No description provided for @settingsDashboardQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Dashboard Quick Actions'**
  String get settingsDashboardQuickActions;

  /// No description provided for @settingsDashboardQuickActionsDesc.
  ///
  /// In en, this message translates to:
  /// **'Configure quick shortcut entries shown on the dashboard. Clearing will hide the quick actions section.'**
  String get settingsDashboardQuickActionsDesc;

  /// No description provided for @settingsDashboardQuickActionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Quick actions hidden (no shortcuts selected)'**
  String get settingsDashboardQuickActionsEmpty;

  /// No description provided for @settingsDashboardQuickActionsOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Drag to Reorder Shortcuts'**
  String get settingsDashboardQuickActionsOrderTitle;

  /// No description provided for @settingsDashboardQuickActionsCandidates.
  ///
  /// In en, this message translates to:
  /// **'Select Visible Shortcuts'**
  String get settingsDashboardQuickActionsCandidates;

  /// No description provided for @terminalCopySelection.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get terminalCopySelection;

  /// No description provided for @terminalSelectionCopied.
  ///
  /// In en, this message translates to:
  /// **'Selection copied to clipboard'**
  String get terminalSelectionCopied;

  /// No description provided for @editAgent.
  ///
  /// In en, this message translates to:
  /// **'Edit Agent'**
  String get editAgent;

  /// No description provided for @agentExecutionTarget.
  ///
  /// In en, this message translates to:
  /// **'Execution Environment'**
  String get agentExecutionTarget;

  /// No description provided for @agentExecutionHost.
  ///
  /// In en, this message translates to:
  /// **'Host System'**
  String get agentExecutionHost;

  /// No description provided for @agentExecutionDocker.
  ///
  /// In en, this message translates to:
  /// **'Docker Container'**
  String get agentExecutionDocker;

  /// No description provided for @agentContainerBinding.
  ///
  /// In en, this message translates to:
  /// **'Container Binding Mode'**
  String get agentContainerBinding;

  /// No description provided for @agentContainerBindingId.
  ///
  /// In en, this message translates to:
  /// **'By Container ID'**
  String get agentContainerBindingId;

  /// No description provided for @agentContainerBindingName.
  ///
  /// In en, this message translates to:
  /// **'By Container Name'**
  String get agentContainerBindingName;

  /// No description provided for @agentContainerReference.
  ///
  /// In en, this message translates to:
  /// **'Target Container'**
  String get agentContainerReference;

  /// No description provided for @agentContainerReferenceHint.
  ///
  /// In en, this message translates to:
  /// **'Select or enter container ID or name'**
  String get agentContainerReferenceHint;

  /// No description provided for @agentContainerRequired.
  ///
  /// In en, this message translates to:
  /// **'Target container is required for Docker execution'**
  String get agentContainerRequired;

  /// No description provided for @agentLoadingContainers.
  ///
  /// In en, this message translates to:
  /// **'Querying containers on server...'**
  String get agentLoadingContainers;

  /// No description provided for @agentNoContainersFound.
  ///
  /// In en, this message translates to:
  /// **'No containers found on this server'**
  String get agentNoContainersFound;

  /// No description provided for @agentContainerUser.
  ///
  /// In en, this message translates to:
  /// **'Container Execution User (Optional)'**
  String get agentContainerUser;

  /// No description provided for @agentContainerUserHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. dev'**
  String get agentContainerUserHint;

  /// No description provided for @agentContainerUserHelper.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use image default user; e.g. dev; supports user, UID, user:group, UID:GID'**
  String get agentContainerUserHelper;

  /// No description provided for @agentContainerUserSelect.
  ///
  /// In en, this message translates to:
  /// **'Select container user'**
  String get agentContainerUserSelect;

  /// No description provided for @agentContainerUsersLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading users...'**
  String get agentContainerUsersLoading;

  /// No description provided for @agentContainerUsersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No passwd users found'**
  String get agentContainerUsersEmpty;

  /// No description provided for @agentViewDiagnosticLog.
  ///
  /// In en, this message translates to:
  /// **'View Diagnostic Log'**
  String get agentViewDiagnosticLog;

  /// No description provided for @agentDiagnosticLogCopied.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic log copied to clipboard'**
  String get agentDiagnosticLogCopied;

  /// No description provided for @agentDiagnosticLogCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get agentDiagnosticLogCopy;

  /// No description provided for @agentDiagnosticLogClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get agentDiagnosticLogClose;

  /// No description provided for @settingsCliHistoryPageSize.
  ///
  /// In en, this message translates to:
  /// **'CLI History Page Size'**
  String get settingsCliHistoryPageSize;

  /// No description provided for @settingsCliHistoryPageSizeDesc.
  ///
  /// In en, this message translates to:
  /// **'Number of older messages loaded per page when scrolling up (5-100)'**
  String get settingsCliHistoryPageSizeDesc;

  /// No description provided for @settingsCliHistoryPageSizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Select CLI History Page Size'**
  String get settingsCliHistoryPageSizeTitle;

  /// No description provided for @cliLoadingOlderMessages.
  ///
  /// In en, this message translates to:
  /// **'Loading older messages...'**
  String get cliLoadingOlderMessages;

  /// No description provided for @chatLoadOlderMessages.
  ///
  /// In en, this message translates to:
  /// **'Load earlier messages'**
  String get chatLoadOlderMessages;

  /// No description provided for @chatCommandsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Commands'**
  String get chatCommandsTooltip;

  /// No description provided for @chatAttachTooltip.
  ///
  /// In en, this message translates to:
  /// **'Attach file'**
  String get chatAttachTooltip;

  /// No description provided for @chatAttachImage.
  ///
  /// In en, this message translates to:
  /// **'Attach local image'**
  String get chatAttachImage;

  /// No description provided for @chatAttachLocalText.
  ///
  /// In en, this message translates to:
  /// **'Attach local text file'**
  String get chatAttachLocalText;

  /// No description provided for @chatAttachRemoteText.
  ///
  /// In en, this message translates to:
  /// **'Attach remote text file'**
  String get chatAttachRemoteText;

  /// No description provided for @chatAttachRemotePathTitle.
  ///
  /// In en, this message translates to:
  /// **'Attach Remote Text File'**
  String get chatAttachRemotePathTitle;

  /// No description provided for @chatAttachRemotePathHint.
  ///
  /// In en, this message translates to:
  /// **'/path/to/file.txt'**
  String get chatAttachRemotePathHint;

  /// No description provided for @chatAttachTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File exceeds size limit'**
  String get chatAttachTooLarge;

  /// No description provided for @chatUsageAndDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Usage & Diagnostics'**
  String get chatUsageAndDiagnostics;

  /// No description provided for @chatWorkingDirTooltip.
  ///
  /// In en, this message translates to:
  /// **'Draft Working Directory'**
  String get chatWorkingDirTooltip;

  /// No description provided for @chatAttachFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to attach file'**
  String get chatAttachFailed;

  /// No description provided for @chatInvalidRemotePath.
  ///
  /// In en, this message translates to:
  /// **'Invalid remote file path (must start with /)'**
  String get chatInvalidRemotePath;

  /// No description provided for @chatRemoteReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to read remote file'**
  String get chatRemoteReadFailed;

  /// No description provided for @chatInvalidDirPath.
  ///
  /// In en, this message translates to:
  /// **'Invalid directory path (must start with /)'**
  String get chatInvalidDirPath;

  /// No description provided for @chatNoSubdirectories.
  ///
  /// In en, this message translates to:
  /// **'No subdirectories'**
  String get chatNoSubdirectories;

  /// No description provided for @chatUsageTitle.
  ///
  /// In en, this message translates to:
  /// **'Token & Cost Usage'**
  String get chatUsageTitle;

  /// No description provided for @chatUsageUsed.
  ///
  /// In en, this message translates to:
  /// **'Tokens Used'**
  String get chatUsageUsed;

  /// No description provided for @chatUsageSize.
  ///
  /// In en, this message translates to:
  /// **'Context Size'**
  String get chatUsageSize;

  /// No description provided for @chatUsageCost.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get chatUsageCost;

  /// No description provided for @chatDiagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics Log'**
  String get chatDiagnosticsTitle;

  /// No description provided for @chatNoDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'No diagnostic logs available'**
  String get chatNoDiagnostics;

  /// No description provided for @deleteSessionLocalOnlyNotice.
  ///
  /// In en, this message translates to:
  /// **'This only removes the local record in Valhalla and will not delete native agent session history on the server.'**
  String get deleteSessionLocalOnlyNotice;

  /// No description provided for @chatSearchSessionsHint.
  ///
  /// In en, this message translates to:
  /// **'Search sessions...'**
  String get chatSearchSessionsHint;

  /// No description provided for @chatLoadMoreSessions.
  ///
  /// In en, this message translates to:
  /// **'Load more sessions'**
  String get chatLoadMoreSessions;

  /// No description provided for @chatLoadingMoreSessions.
  ///
  /// In en, this message translates to:
  /// **'Loading more sessions...'**
  String get chatLoadingMoreSessions;

  /// No description provided for @chatExportSession.
  ///
  /// In en, this message translates to:
  /// **'Export Session (Markdown)'**
  String get chatExportSession;

  /// No description provided for @chatExportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Session exported successfully'**
  String get chatExportSuccess;

  /// No description provided for @chatExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to export session'**
  String get chatExportFailed;

  /// No description provided for @chatRemoteSessions.
  ///
  /// In en, this message translates to:
  /// **'Remote Sessions'**
  String get chatRemoteSessions;

  /// No description provided for @chatRemoteSessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Remote Agent Sessions'**
  String get chatRemoteSessionsTitle;

  /// No description provided for @chatRemoteSessionsDesc.
  ///
  /// In en, this message translates to:
  /// **'View and import native session history from the remote agent'**
  String get chatRemoteSessionsDesc;

  /// No description provided for @chatRemoteSessionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No remote sessions found'**
  String get chatRemoteSessionsEmpty;

  /// No description provided for @chatRemoteImporting.
  ///
  /// In en, this message translates to:
  /// **'Importing remote session history...'**
  String get chatRemoteImporting;

  /// No description provided for @chatRemoteImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to import remote session'**
  String get chatRemoteImportFailed;

  /// No description provided for @chatStatusInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Interrupted'**
  String get chatStatusInterrupted;

  /// No description provided for @chatStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get chatStatusFailed;

  /// No description provided for @chatShowFullOutput.
  ///
  /// In en, this message translates to:
  /// **'Show full output'**
  String get chatShowFullOutput;

  /// No description provided for @chatShowLessOutput.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get chatShowLessOutput;

  /// No description provided for @chatToolLocations.
  ///
  /// In en, this message translates to:
  /// **'Affected paths'**
  String get chatToolLocations;

  /// No description provided for @cmdParamPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter value for {param}'**
  String cmdParamPlaceholder(String param);

  /// No description provided for @processTerminateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Process {pid} terminated'**
  String processTerminateSuccess(Object pid);

  /// No description provided for @serviceActionSuccess.
  ///
  /// In en, this message translates to:
  /// **'Action {action} on {service} succeeded'**
  String serviceActionSuccess(Object action, Object service);

  /// No description provided for @riskPatternMatched.
  ///
  /// In en, this message translates to:
  /// **'Triggered rule: {pattern}'**
  String riskPatternMatched(Object pattern);

  /// No description provided for @stateExitCode.
  ///
  /// In en, this message translates to:
  /// **'Exit Code: {code}'**
  String stateExitCode(Object code);

  /// No description provided for @sshConnectedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Successfully connected to {server} via SSH'**
  String sshConnectedSuccess(Object server);

  /// No description provided for @sshConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'SSH connection failed: {error}'**
  String sshConnectionFailed(Object error);

  /// No description provided for @trustHostFingerprintMessage.
  ///
  /// In en, this message translates to:
  /// **'Connecting to {host} ({type}) for the first time.\n\nSHA-256 Fingerprint:\n{fingerprint}\n\nTrust this fingerprint and connect?'**
  String trustHostFingerprintMessage(
    Object fingerprint,
    Object host,
    Object type,
  );

  /// No description provided for @enterPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter password for {server}'**
  String enterPasswordTitle(Object server);

  /// No description provided for @confirmDeleteServerMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete server \'{name}\'? This action cannot be undone.'**
  String confirmDeleteServerMessage(Object name);

  /// No description provided for @deleteAgentMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete Agent \'{name}\'? This removes its configuration and runtime state on this server without affecting historical chat sessions or SSH credentials.'**
  String deleteAgentMessage(Object name);

  /// No description provided for @agentLastChecked.
  ///
  /// In en, this message translates to:
  /// **'Last checked: {time}'**
  String agentLastChecked(Object time);

  /// No description provided for @agentAuthPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how to log in to {agent}'**
  String agentAuthPickerTitle(Object agent);

  /// No description provided for @sshStatusReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting… (attempt {n})'**
  String sshStatusReconnecting(Object n);

  /// No description provided for @sshKeepAliveNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'{n} active session(s)'**
  String sshKeepAliveNotificationBody(Object n);

  /// No description provided for @bindServerConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Bind this session to server \\\"{serverName}\\\"? Once bound, this session will be associated with this server.'**
  String bindServerConfirmMessage(Object serverName);

  /// No description provided for @deleteSessionConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete session \\\"{title}\\\"? This action cannot be undone.'**
  String deleteSessionConfirmMessage(Object title);

  /// No description provided for @dockerActionSuccess.
  ///
  /// In en, this message translates to:
  /// **'Container {name} {action} succeeded'**
  String dockerActionSuccess(Object action, Object name);

  /// No description provided for @dockerActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Action failed: {error}'**
  String dockerActionFailed(Object error);

  /// No description provided for @serverRebootTarget.
  ///
  /// In en, this message translates to:
  /// **'Target Server: {name} ({address})'**
  String serverRebootTarget(Object address, Object name);

  /// No description provided for @serverRebootRunningTerminals.
  ///
  /// In en, this message translates to:
  /// **'Terminal Sessions: {count}'**
  String serverRebootRunningTerminals(Object count);

  /// No description provided for @serverRebootRunningAgents.
  ///
  /// In en, this message translates to:
  /// **'Agent Sessions: {count}'**
  String serverRebootRunningAgents(Object count);

  /// No description provided for @serverRebootRunningTransfers.
  ///
  /// In en, this message translates to:
  /// **'Active Transfers: {count}'**
  String serverRebootRunningTransfers(Object count);

  /// No description provided for @serverRebootFailed.
  ///
  /// In en, this message translates to:
  /// **'Reboot failed: {error}'**
  String serverRebootFailed(Object error);

  /// No description provided for @cliDeleteFailedWithDetail.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete remote session: {detail}'**
  String cliDeleteFailedWithDetail(Object detail);

  /// No description provided for @metricsTrendTitle.
  ///
  /// In en, this message translates to:
  /// **'{metric} Trend'**
  String metricsTrendTitle(Object metric);

  /// No description provided for @metricsThresholdWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning: {value}'**
  String metricsThresholdWarning(Object value);

  /// No description provided for @metricsThresholdDanger.
  ///
  /// In en, this message translates to:
  /// **'Danger: {value}'**
  String metricsThresholdDanger(Object value);

  /// No description provided for @metricsHistoryPoints.
  ///
  /// In en, this message translates to:
  /// **'{count} data points'**
  String metricsHistoryPoints(Object count);

  /// No description provided for @resourceUsageTitle.
  ///
  /// In en, this message translates to:
  /// **'{metric} Resource Usage'**
  String resourceUsageTitle(Object metric);

  /// No description provided for @serverPortReachable.
  ///
  /// In en, this message translates to:
  /// **'TCP port {port} reachable'**
  String serverPortReachable(Object port);

  /// No description provided for @serverConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed: {error}'**
  String serverConnectionFailed(Object error);

  /// No description provided for @serverSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save server: {error}'**
  String serverSaveFailed(Object error);

  /// No description provided for @hardwareCpuCores.
  ///
  /// In en, this message translates to:
  /// **'{cores} Cores'**
  String hardwareCpuCores(Object cores);

  /// No description provided for @serverShutdownFailed.
  ///
  /// In en, this message translates to:
  /// **'Shutdown failed: {error}'**
  String serverShutdownFailed(Object error);

  /// No description provided for @networkInterface.
  ///
  /// In en, this message translates to:
  /// **'Interface: {name}'**
  String networkInterface(Object name);

  /// No description provided for @agentContainersLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load containers: {error}'**
  String agentContainersLoadFailed(Object error);

  /// No description provided for @agentContainerUsersFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load container users: {error}'**
  String agentContainerUsersFailed(Object error);

  /// No description provided for @agentDiagnosticLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic Log - {name}'**
  String agentDiagnosticLogTitle(Object name);

  /// No description provided for @agentDockerDetectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Docker/container detection failed'**
  String get agentDockerDetectionFailed;

  /// No description provided for @chatCopiedAllMessages.
  ///
  /// In en, this message translates to:
  /// **'All messages copied'**
  String get chatCopiedAllMessages;

  /// No description provided for @chatCopyAllMessages.
  ///
  /// In en, this message translates to:
  /// **'Copy all messages'**
  String get chatCopyAllMessages;

  /// No description provided for @cliModelAtCapacity.
  ///
  /// In en, this message translates to:
  /// **'Selected model is at capacity. Try another model.'**
  String get cliModelAtCapacity;

  /// No description provided for @chatLaunchBlankDraft.
  ///
  /// In en, this message translates to:
  /// **'Blank draft'**
  String get chatLaunchBlankDraft;

  /// No description provided for @chatLaunchFixedSession.
  ///
  /// In en, this message translates to:
  /// **'Fixed session'**
  String get chatLaunchFixedSession;

  /// No description provided for @chatLaunchRememberLast.
  ///
  /// In en, this message translates to:
  /// **'Remember last session'**
  String get chatLaunchRememberLast;

  /// No description provided for @chatPermissionAskEveryTime.
  ///
  /// In en, this message translates to:
  /// **'Ask every time'**
  String get chatPermissionAskEveryTime;

  /// No description provided for @chatPermissionAutoAllowAll.
  ///
  /// In en, this message translates to:
  /// **'Allow all automatically'**
  String get chatPermissionAutoAllowAll;

  /// No description provided for @chatPermissionAutoAllowAllConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'The agent will execute all operations without asking. Continue?'**
  String get chatPermissionAutoAllowAllConfirmMessage;

  /// No description provided for @chatPermissionAutoAllowAllConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow all operations?'**
  String get chatPermissionAutoAllowAllConfirmTitle;

  /// No description provided for @chatPermissionAutoAllowSafe.
  ///
  /// In en, this message translates to:
  /// **'Automatically allow safe operations'**
  String get chatPermissionAutoAllowSafe;

  /// No description provided for @chatRunSettingsDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get chatRunSettingsDefault;

  /// No description provided for @chatRunSettingsInteractiveCli.
  ///
  /// In en, this message translates to:
  /// **'Interactive CLI'**
  String get chatRunSettingsInteractiveCli;

  /// No description provided for @chatRunSettingsModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get chatRunSettingsModel;

  /// No description provided for @chatRunSettingsPermissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get chatRunSettingsPermissions;

  /// No description provided for @chatRunSettingsReasoning.
  ///
  /// In en, this message translates to:
  /// **'Reasoning level'**
  String get chatRunSettingsReasoning;

  /// No description provided for @chatRunSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Run settings'**
  String get chatRunSettingsTitle;

  /// No description provided for @cliActionInsertCommand.
  ///
  /// In en, this message translates to:
  /// **'Insert command'**
  String get cliActionInsertCommand;

  /// No description provided for @cliActionInsertFile.
  ///
  /// In en, this message translates to:
  /// **'Insert file'**
  String get cliActionInsertFile;

  /// No description provided for @cliActionInsertWorkdir.
  ///
  /// In en, this message translates to:
  /// **'Insert working directory'**
  String get cliActionInsertWorkdir;

  /// No description provided for @cliComposerInsertAction.
  ///
  /// In en, this message translates to:
  /// **'Insert'**
  String get cliComposerInsertAction;

  /// No description provided for @cliOperationFailedWithDetail.
  ///
  /// In en, this message translates to:
  /// **'CLI operation failed: {detail}'**
  String cliOperationFailedWithDetail(String detail);

  /// No description provided for @cliSelectCommandTitle.
  ///
  /// In en, this message translates to:
  /// **'Select command'**
  String get cliSelectCommandTitle;

  /// No description provided for @defaultAgentTitle.
  ///
  /// In en, this message translates to:
  /// **'Default agent'**
  String get defaultAgentTitle;

  /// No description provided for @insertSkills.
  ///
  /// In en, this message translates to:
  /// **'Insert skills'**
  String get insertSkills;

  /// No description provided for @isDefaultSession.
  ///
  /// In en, this message translates to:
  /// **'Default session'**
  String get isDefaultSession;

  /// No description provided for @sessionLaunchMode.
  ///
  /// In en, this message translates to:
  /// **'Session launch mode'**
  String get sessionLaunchMode;

  /// No description provided for @setAsDefaultSession.
  ///
  /// In en, this message translates to:
  /// **'Set as default session'**
  String get setAsDefaultSession;

  /// No description provided for @navNas.
  ///
  /// In en, this message translates to:
  /// **'NAS Media'**
  String get navNas;

  /// No description provided for @nasAddExcludePath.
  ///
  /// In en, this message translates to:
  /// **'Add excluded path'**
  String get nasAddExcludePath;

  /// No description provided for @nasAddIncludePath.
  ///
  /// In en, this message translates to:
  /// **'Add scan path'**
  String get nasAddIncludePath;

  /// No description provided for @nasCancelScan.
  ///
  /// In en, this message translates to:
  /// **'Cancel scan'**
  String get nasCancelScan;

  /// No description provided for @nasClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get nasClearSearch;

  /// No description provided for @nasConfigDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Media library settings'**
  String get nasConfigDialogTitle;

  /// No description provided for @nasConfigure.
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get nasConfigure;

  /// No description provided for @nasConfigureScanDirs.
  ///
  /// In en, this message translates to:
  /// **'Configure scan folders'**
  String get nasConfigureScanDirs;

  /// No description provided for @nasCreatePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Create playlist'**
  String get nasCreatePlaylist;

  /// No description provided for @nasEmptyConfigDesc.
  ///
  /// In en, this message translates to:
  /// **'Add at least one folder to start building your media library.'**
  String get nasEmptyConfigDesc;

  /// No description provided for @nasEmptyConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'No scan folders configured'**
  String get nasEmptyConfigTitle;

  /// No description provided for @nasExcludePaths.
  ///
  /// In en, this message translates to:
  /// **'Excluded folders'**
  String get nasExcludePaths;

  /// No description provided for @nasExcludedBadge.
  ///
  /// In en, this message translates to:
  /// **'Excluded'**
  String get nasExcludedBadge;

  /// No description provided for @nasFilterImages.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get nasFilterImages;

  /// No description provided for @nasFilterVideos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get nasFilterVideos;

  /// No description provided for @nasIncludePaths.
  ///
  /// In en, this message translates to:
  /// **'Scan folders'**
  String get nasIncludePaths;

  /// No description provided for @nasItemCount.
  ///
  /// In en, this message translates to:
  /// **'{value} items'**
  String nasItemCount(Object value);

  /// No description provided for @nasLastScan.
  ///
  /// In en, this message translates to:
  /// **'Last scan: {value}'**
  String nasLastScan(Object value);

  /// No description provided for @nasLibrarySettings.
  ///
  /// In en, this message translates to:
  /// **'Library settings'**
  String get nasLibrarySettings;

  /// No description provided for @nasMediaOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening {value}…'**
  String nasMediaOpening(Object value);

  /// No description provided for @nasMiniPlayer.
  ///
  /// In en, this message translates to:
  /// **'Mini player'**
  String get nasMiniPlayer;

  /// No description provided for @nasNoExcludePaths.
  ///
  /// In en, this message translates to:
  /// **'No excluded folders'**
  String get nasNoExcludePaths;

  /// No description provided for @nasNoFavorites.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get nasNoFavorites;

  /// No description provided for @nasNoIncludePaths.
  ///
  /// In en, this message translates to:
  /// **'No scan folders'**
  String get nasNoIncludePaths;

  /// No description provided for @nasNoIndexDesc.
  ///
  /// In en, this message translates to:
  /// **'Configure folders and run a scan to index your media.'**
  String get nasNoIndexDesc;

  /// No description provided for @nasNoIndexTitle.
  ///
  /// In en, this message translates to:
  /// **'Media library is empty'**
  String get nasNoIndexTitle;

  /// No description provided for @nasNoPlaylists.
  ///
  /// In en, this message translates to:
  /// **'No playlists yet'**
  String get nasNoPlaylists;

  /// No description provided for @nasNoSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No matching media'**
  String get nasNoSearchResults;

  /// No description provided for @nasNotScanned.
  ///
  /// In en, this message translates to:
  /// **'Not scanned yet'**
  String get nasNotScanned;

  /// No description provided for @nasNowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get nasNowPlaying;

  /// No description provided for @nasOpenMethodPrompt.
  ///
  /// In en, this message translates to:
  /// **'How would you like to open this file?'**
  String get nasOpenMethodPrompt;

  /// No description provided for @nasOpenPolicyAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask every time'**
  String get nasOpenPolicyAsk;

  /// No description provided for @nasOpenPolicyExternal.
  ///
  /// In en, this message translates to:
  /// **'Open with another app'**
  String get nasOpenPolicyExternal;

  /// No description provided for @nasOpenPolicyInApp.
  ///
  /// In en, this message translates to:
  /// **'Open in app'**
  String get nasOpenPolicyInApp;

  /// No description provided for @nasOpeningPolicy.
  ///
  /// In en, this message translates to:
  /// **'Default open method'**
  String get nasOpeningPolicy;

  /// No description provided for @nasPlaylistName.
  ///
  /// In en, this message translates to:
  /// **'Playlist name'**
  String get nasPlaylistName;

  /// No description provided for @nasQuickStats.
  ///
  /// In en, this message translates to:
  /// **'Library overview'**
  String get nasQuickStats;

  /// No description provided for @nasScan.
  ///
  /// In en, this message translates to:
  /// **'Scan now'**
  String get nasScan;

  /// No description provided for @nasScanCancelled.
  ///
  /// In en, this message translates to:
  /// **'Scan cancelled'**
  String get nasScanCancelled;

  /// No description provided for @nasScanFailed.
  ///
  /// In en, this message translates to:
  /// **'Scan failed: {value}'**
  String nasScanFailed(Object value);

  /// No description provided for @nasScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get nasScanning;

  /// No description provided for @nasScopeBadge.
  ///
  /// In en, this message translates to:
  /// **'Scan scope'**
  String get nasScopeBadge;

  /// No description provided for @nasSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search media'**
  String get nasSearchHint;

  /// No description provided for @nasStatMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get nasStatMusic;

  /// No description provided for @nasStatPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get nasStatPhotos;

  /// No description provided for @nasStatTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get nasStatTotal;

  /// No description provided for @nasStatVideos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get nasStatVideos;

  /// No description provided for @nasTabFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get nasTabFavorites;

  /// No description provided for @nasTabFolders.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get nasTabFolders;

  /// No description provided for @nasTabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get nasTabHome;

  /// No description provided for @nasTabMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get nasTabMusic;

  /// No description provided for @nasTabPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get nasTabPhotos;

  /// No description provided for @nasTabPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get nasTabPlaylists;

  /// No description provided for @nasTabVideos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get nasTabVideos;

  /// No description provided for @nasSources.
  ///
  /// In en, this message translates to:
  /// **'Media sources'**
  String get nasSources;

  /// No description provided for @nasAddSource.
  ///
  /// In en, this message translates to:
  /// **'Add media source'**
  String get nasAddSource;

  /// No description provided for @nasEditSource.
  ///
  /// In en, this message translates to:
  /// **'Edit media source'**
  String get nasEditSource;

  /// No description provided for @nasRemoveSource.
  ///
  /// In en, this message translates to:
  /// **'Remove media source'**
  String get nasRemoveSource;

  /// No description provided for @nasRemoveSourceConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove media source \'{name}\'? This removes its configuration without deleting remote files.'**
  String nasRemoveSourceConfirm(Object name);

  /// No description provided for @nasNoSources.
  ///
  /// In en, this message translates to:
  /// **'No media sources configured'**
  String get nasNoSources;

  /// No description provided for @nasNoSourcesDesc.
  ///
  /// In en, this message translates to:
  /// **'Add SFTP, SMB, WebDAV, Jellyfin, or Emby to start browsing media.'**
  String get nasNoSourcesDesc;

  /// No description provided for @nasSourceType.
  ///
  /// In en, this message translates to:
  /// **'Source type'**
  String get nasSourceType;

  /// No description provided for @nasSourceName.
  ///
  /// In en, this message translates to:
  /// **'Source name'**
  String get nasSourceName;

  /// No description provided for @nasProbe.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get nasProbe;

  /// No description provided for @nasProbeSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connection successful'**
  String get nasProbeSuccess;

  /// No description provided for @nasProbeFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection test failed'**
  String get nasProbeFailed;

  /// No description provided for @nasEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Endpoint / URL'**
  String get nasEndpoint;

  /// No description provided for @nasRootPath.
  ///
  /// In en, this message translates to:
  /// **'Root path'**
  String get nasRootPath;

  /// No description provided for @nasUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get nasUsername;

  /// No description provided for @nasPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get nasPassword;

  /// No description provided for @nasDomain.
  ///
  /// In en, this message translates to:
  /// **'Domain (optional)'**
  String get nasDomain;

  /// No description provided for @nasAuthenticate.
  ///
  /// In en, this message translates to:
  /// **'Authenticate'**
  String get nasAuthenticate;

  /// No description provided for @nasAuthSuccess.
  ///
  /// In en, this message translates to:
  /// **'Authentication successful'**
  String get nasAuthSuccess;

  /// No description provided for @nasAuthFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed'**
  String get nasAuthFailed;

  /// No description provided for @nasTabDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get nasTabDownloads;

  /// No description provided for @nasNoDownloads.
  ///
  /// In en, this message translates to:
  /// **'No download tasks'**
  String get nasNoDownloads;

  /// No description provided for @nasDownloadQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get nasDownloadQueued;

  /// No description provided for @nasDownloadDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get nasDownloadDownloading;

  /// No description provided for @nasDownloadCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get nasDownloadCompleted;

  /// No description provided for @nasDownloadCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get nasDownloadCancelled;

  /// No description provided for @nasDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get nasDownloadFailed;

  /// No description provided for @nasRetryDownload.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get nasRetryDownload;

  /// No description provided for @nasCancelDownload.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get nasCancelDownload;

  /// No description provided for @nasOpenDownloadedFile.
  ///
  /// In en, this message translates to:
  /// **'Open file'**
  String get nasOpenDownloadedFile;

  /// No description provided for @nasQueue.
  ///
  /// In en, this message translates to:
  /// **'Play queue'**
  String get nasQueue;

  /// No description provided for @nasNoQueue.
  ///
  /// In en, this message translates to:
  /// **'Queue is empty'**
  String get nasNoQueue;

  /// No description provided for @nasSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get nasSpeed;

  /// No description provided for @nasQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get nasQuality;

  /// No description provided for @nasAudioTrack.
  ///
  /// In en, this message translates to:
  /// **'Audio track'**
  String get nasAudioTrack;

  /// No description provided for @nasSubtitleTrack.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get nasSubtitleTrack;

  /// No description provided for @nasRepeatOff.
  ///
  /// In en, this message translates to:
  /// **'Repeat off'**
  String get nasRepeatOff;

  /// No description provided for @nasRepeatAll.
  ///
  /// In en, this message translates to:
  /// **'Repeat all'**
  String get nasRepeatAll;

  /// No description provided for @nasRepeatOne.
  ///
  /// In en, this message translates to:
  /// **'Repeat one'**
  String get nasRepeatOne;

  /// No description provided for @nasShuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get nasShuffle;

  /// No description provided for @nasCast.
  ///
  /// In en, this message translates to:
  /// **'Cast'**
  String get nasCast;

  /// No description provided for @nasCastUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No cast devices available'**
  String get nasCastUnavailable;

  /// No description provided for @nasSlideshow.
  ///
  /// In en, this message translates to:
  /// **'Slideshow'**
  String get nasSlideshow;

  /// No description provided for @nasByFolder.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get nasByFolder;

  /// No description provided for @nasByArtist.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get nasByArtist;

  /// No description provided for @nasByAlbum.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get nasByAlbum;

  /// No description provided for @nasAllTracks.
  ///
  /// In en, this message translates to:
  /// **'All tracks'**
  String get nasAllTracks;

  /// No description provided for @nasPlayAll.
  ///
  /// In en, this message translates to:
  /// **'Play all'**
  String get nasPlayAll;

  /// No description provided for @nasPreviousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get nasPreviousPage;

  /// No description provided for @nasNextPage.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nasNextPage;

  /// No description provided for @nasClearScope.
  ///
  /// In en, this message translates to:
  /// **'Back to all'**
  String get nasClearScope;

  /// No description provided for @nasRenamePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Rename playlist'**
  String get nasRenamePlaylist;

  /// No description provided for @nasRemoveFromPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Remove from playlist'**
  String get nasRemoveFromPlaylist;

  /// No description provided for @nasMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get nasMoveUp;

  /// No description provided for @nasMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get nasMoveDown;

  /// No description provided for @nasSshServer.
  ///
  /// In en, this message translates to:
  /// **'SSH server'**
  String get nasSshServer;

  /// No description provided for @nasSelectSshServer.
  ///
  /// In en, this message translates to:
  /// **'Select saved SSH server'**
  String get nasSelectSshServer;

  /// No description provided for @nasQualityOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get nasQualityOriginal;

  /// No description provided for @nasQualityAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get nasQualityAuto;

  /// No description provided for @nasQuality4Mbps.
  ///
  /// In en, this message translates to:
  /// **'4 Mbps'**
  String get nasQuality4Mbps;

  /// No description provided for @nasQuality10Mbps.
  ///
  /// In en, this message translates to:
  /// **'10 Mbps'**
  String get nasQuality10Mbps;

  /// No description provided for @nasQuality20Mbps.
  ///
  /// In en, this message translates to:
  /// **'20 Mbps'**
  String get nasQuality20Mbps;

  /// No description provided for @nasCastDevices.
  ///
  /// In en, this message translates to:
  /// **'Available DLNA Devices'**
  String get nasCastDevices;

  /// No description provided for @nasCastDiscovering.
  ///
  /// In en, this message translates to:
  /// **'Searching for DLNA devices...'**
  String get nasCastDiscovering;

  /// No description provided for @nasCastRelayingNotice.
  ///
  /// In en, this message translates to:
  /// **'Relaying stream via foreground app. Keep Valhalla open.'**
  String get nasCastRelayingNotice;

  /// No description provided for @nasCastStop.
  ///
  /// In en, this message translates to:
  /// **'Stop Casting'**
  String get nasCastStop;

  /// No description provided for @nasCastVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get nasCastVolume;

  /// No description provided for @nasCastRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry Search'**
  String get nasCastRetry;

  /// No description provided for @nasInstallTitle.
  ///
  /// In en, this message translates to:
  /// **'Deploy NAS Media Server'**
  String get nasInstallTitle;

  /// No description provided for @nasInstallProduct.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get nasInstallProduct;

  /// No description provided for @nasInstallMediaPath.
  ///
  /// In en, this message translates to:
  /// **'Media Directory (Read-Only)'**
  String get nasInstallMediaPath;

  /// No description provided for @nasInstallDataRoot.
  ///
  /// In en, this message translates to:
  /// **'Data & Config Directory'**
  String get nasInstallDataRoot;

  /// No description provided for @nasInstallPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get nasInstallPort;

  /// No description provided for @nasInstallBindAddress.
  ///
  /// In en, this message translates to:
  /// **'Bind Address'**
  String get nasInstallBindAddress;

  /// No description provided for @nasInstallWebdavUser.
  ///
  /// In en, this message translates to:
  /// **'WebDAV Username'**
  String get nasInstallWebdavUser;

  /// No description provided for @nasInstallWebdavPassword.
  ///
  /// In en, this message translates to:
  /// **'WebDAV Password (min 12 chars)'**
  String get nasInstallWebdavPassword;

  /// No description provided for @nasInstallPreparePlan.
  ///
  /// In en, this message translates to:
  /// **'Review Deployment Plan'**
  String get nasInstallPreparePlan;

  /// No description provided for @nasInstallPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Technical Review & Confirmation'**
  String get nasInstallPlanTitle;

  /// No description provided for @nasInstallBlockersTitle.
  ///
  /// In en, this message translates to:
  /// **'Deployment Blockers'**
  String get nasInstallBlockersTitle;

  /// No description provided for @nasInstallConfirmDeploy.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Install'**
  String get nasInstallConfirmDeploy;

  /// No description provided for @nasInstallDeploying.
  ///
  /// In en, this message translates to:
  /// **'Deploying container...'**
  String get nasInstallDeploying;

  /// No description provided for @nasInstallSuccess.
  ///
  /// In en, this message translates to:
  /// **'Deployed Successfully'**
  String get nasInstallSuccess;

  /// No description provided for @nasInstallSuccessDesc.
  ///
  /// In en, this message translates to:
  /// **'Service is now running. Complete server initial setup before adding it as a media source.'**
  String get nasInstallSuccessDesc;

  /// No description provided for @nasInstallContainerId.
  ///
  /// In en, this message translates to:
  /// **'Container ID'**
  String get nasInstallContainerId;

  /// No description provided for @nasInstallEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get nasInstallEndpoint;

  /// No description provided for @nasUseSshTunnel.
  ///
  /// In en, this message translates to:
  /// **'Use SSH Tunnel'**
  String get nasUseSshTunnel;

  /// No description provided for @nasUseSshTunnelDesc.
  ///
  /// In en, this message translates to:
  /// **'Route traffic through a saved SSH server (e.g. http://127.0.0.1:8096)'**
  String get nasUseSshTunnelDesc;

  /// No description provided for @nasSshTunnelHint.
  ///
  /// In en, this message translates to:
  /// **'Endpoint should be accessible from the SSH server, e.g. http://127.0.0.1:8096'**
  String get nasSshTunnelHint;

  /// No description provided for @nasKeepEmptyPassword.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to keep existing password / token'**
  String get nasKeepEmptyPassword;

  /// No description provided for @nasSourceNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Source name is required'**
  String get nasSourceNameRequired;

  /// No description provided for @nasInvalidEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Invalid endpoint URL or scheme'**
  String get nasInvalidEndpoint;

  /// No description provided for @nasSourceUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Unable to reach media source'**
  String get nasSourceUnreachable;

  /// No description provided for @nasSshTunnelFailed.
  ///
  /// In en, this message translates to:
  /// **'SSH tunnel connection failed'**
  String get nasSshTunnelFailed;

  /// No description provided for @nasOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed'**
  String get nasOperationFailed;

  /// No description provided for @nasInstallStepCreateDir.
  ///
  /// In en, this message translates to:
  /// **'Create private directory'**
  String get nasInstallStepCreateDir;

  /// No description provided for @nasInstallStepWriteCompose.
  ///
  /// In en, this message translates to:
  /// **'Write docker-compose.json configuration'**
  String get nasInstallStepWriteCompose;

  /// No description provided for @nasInstallStepWriteCreds.
  ///
  /// In en, this message translates to:
  /// **'Write private credentials'**
  String get nasInstallStepWriteCreds;

  /// No description provided for @nasInstallStepPullImage.
  ///
  /// In en, this message translates to:
  /// **'Pull pinned container image'**
  String get nasInstallStepPullImage;

  /// No description provided for @nasInstallStepStartService.
  ///
  /// In en, this message translates to:
  /// **'Start containerized service'**
  String get nasInstallStepStartService;

  /// No description provided for @nasInstallStepCheckHttp.
  ///
  /// In en, this message translates to:
  /// **'Check service HTTP health'**
  String get nasInstallStepCheckHttp;

  /// No description provided for @nasInstallBlockerDocker.
  ///
  /// In en, this message translates to:
  /// **'Docker Engine is required on target server'**
  String get nasInstallBlockerDocker;

  /// No description provided for @nasInstallBlockerCompose.
  ///
  /// In en, this message translates to:
  /// **'Docker Compose plugin is required'**
  String get nasInstallBlockerCompose;

  /// No description provided for @nasInstallBlockerIdentity.
  ///
  /// In en, this message translates to:
  /// **'Target server identity could not be verified'**
  String get nasInstallBlockerIdentity;

  /// No description provided for @nasInstallBlockerTools.
  ///
  /// In en, this message translates to:
  /// **'Required tools (curl, ss, realpath) are missing on target server'**
  String get nasInstallBlockerTools;

  /// No description provided for @nasInstallBlockerMedia.
  ///
  /// In en, this message translates to:
  /// **'Media directory does not exist or is not readable'**
  String get nasInstallBlockerMedia;

  /// No description provided for @nasInstallBlockerParent.
  ///
  /// In en, this message translates to:
  /// **'Data root parent directory is not writable'**
  String get nasInstallBlockerParent;

  /// No description provided for @nasInstallBlockerOverlap.
  ///
  /// In en, this message translates to:
  /// **'Media directory and data directory cannot overlap'**
  String get nasInstallBlockerOverlap;

  /// No description provided for @nasInstallBlockerCollision.
  ///
  /// In en, this message translates to:
  /// **'Target data directory already exists or is a symlink'**
  String get nasInstallBlockerCollision;

  /// No description provided for @nasInstallBlockerPort.
  ///
  /// In en, this message translates to:
  /// **'Selected port is already in use on target server'**
  String get nasInstallBlockerPort;

  /// No description provided for @nasInstallBlockerContainer.
  ///
  /// In en, this message translates to:
  /// **'A container with this project name already exists'**
  String get nasInstallBlockerContainer;

  /// No description provided for @nasInstallBlockerImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to verify container image. Check image name, network connectivity, and server architecture, then retry.'**
  String get nasInstallBlockerImage;

  /// No description provided for @nasInstallGuidanceTunnel.
  ///
  /// In en, this message translates to:
  /// **'Loopback binding (127.0.0.1) requires SSH tunnel for remote access'**
  String get nasInstallGuidanceTunnel;

  /// No description provided for @nasInstallGuidanceTls.
  ///
  /// In en, this message translates to:
  /// **'Public binding recommended to be secured behind TLS reverse proxy'**
  String get nasInstallGuidanceTls;

  /// No description provided for @nasInstallGuidanceSetup.
  ///
  /// In en, this message translates to:
  /// **'Complete initial admin account setup in browser on first launch'**
  String get nasInstallGuidanceSetup;

  /// No description provided for @nasInstallGuidanceReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Media directory is mounted read-only to safeguard your files'**
  String get nasInstallGuidanceReadOnly;

  /// No description provided for @nasInstallGuidancePreserved.
  ///
  /// In en, this message translates to:
  /// **'Data directory will be preserved on failure for troubleshooting'**
  String get nasInstallGuidancePreserved;

  /// No description provided for @nasDownloadCompletedWithOpenError.
  ///
  /// In en, this message translates to:
  /// **'Downloaded (Failed to open externally)'**
  String get nasDownloadCompletedWithOpenError;

  /// No description provided for @nasRetryOpen.
  ///
  /// In en, this message translates to:
  /// **'Retry Open'**
  String get nasRetryOpen;

  /// No description provided for @nasExternalOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open file in external app'**
  String get nasExternalOpenFailed;

  /// No description provided for @nasTitle.
  ///
  /// In en, this message translates to:
  /// **'NAS Media'**
  String get nasTitle;

  /// No description provided for @nasLoadMoreGroups.
  ///
  /// In en, this message translates to:
  /// **'Load more groups'**
  String get nasLoadMoreGroups;

  /// No description provided for @nasMetadataEnriching.
  ///
  /// In en, this message translates to:
  /// **'Enriching music tags...'**
  String get nasMetadataEnriching;

  /// No description provided for @nasMetadataEnrichingWithCount.
  ///
  /// In en, this message translates to:
  /// **'Enriching music tags ({count} processed)...'**
  String nasMetadataEnrichingWithCount(int count);

  /// No description provided for @nasDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading {value}…'**
  String nasDownloading(String value);

  /// No description provided for @nasSubtitleNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get nasSubtitleNone;

  /// No description provided for @nasLibraryId.
  ///
  /// In en, this message translates to:
  /// **'Library ID'**
  String get nasLibraryId;

  /// No description provided for @nasLibraryIdHint.
  ///
  /// In en, this message translates to:
  /// **'Default: all (/), or specify library ID'**
  String get nasLibraryIdHint;

  /// No description provided for @nasScanPathRelativeHint.
  ///
  /// In en, this message translates to:
  /// **'Relative to source root ({value})'**
  String nasScanPathRelativeHint(String value);

  /// No description provided for @nasSourceChangedError.
  ///
  /// In en, this message translates to:
  /// **'Source changed while configuring, save cancelled'**
  String get nasSourceChangedError;

  /// No description provided for @nasInvalidLibraryId.
  ///
  /// In en, this message translates to:
  /// **'Invalid library ID'**
  String get nasInvalidLibraryId;

  /// No description provided for @startupFailed.
  ///
  /// In en, this message translates to:
  /// **'Application failed to start'**
  String get startupFailed;

  /// No description provided for @startupFailedDesc.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred during startup. You can retry or export diagnostic logs.'**
  String get startupFailedDesc;

  /// No description provided for @retryStartup.
  ///
  /// In en, this message translates to:
  /// **'Retry Startup'**
  String get retryStartup;

  /// No description provided for @viewDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'View Diagnostics'**
  String get viewDiagnostics;

  /// No description provided for @exportDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Export Diagnostics'**
  String get exportDiagnostics;

  /// No description provided for @diagnosticsExportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics exported to {path}'**
  String diagnosticsExportSuccess(String path);

  /// No description provided for @diagnosticsExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to export diagnostics'**
  String get diagnosticsExportFailed;

  /// No description provided for @diagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'App Diagnostics'**
  String get diagnosticsTitle;

  /// No description provided for @settingsDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics & Logs'**
  String get settingsDiagnostics;

  /// No description provided for @settingsDiagnosticsDesc.
  ///
  /// In en, this message translates to:
  /// **'View and export local sanitized application logs'**
  String get settingsDiagnosticsDesc;

  /// No description provided for @diagnosticsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No diagnostic records found'**
  String get diagnosticsEmpty;

  /// No description provided for @diagnosticsStorageError.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics storage error: {error}'**
  String diagnosticsStorageError(String error);

  /// No description provided for @diagnosticsIncidentNotice.
  ///
  /// In en, this message translates to:
  /// **'Recoverable incident reported: {category}'**
  String diagnosticsIncidentNotice(String category);

  /// No description provided for @diagnosticsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh Logs'**
  String get diagnosticsRefresh;

  /// No description provided for @nasInstallTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Deployment Task'**
  String get nasInstallTaskTitle;

  /// No description provided for @nasInstallStagePreflight.
  ///
  /// In en, this message translates to:
  /// **'Preflight Check'**
  String get nasInstallStagePreflight;

  /// No description provided for @nasInstallStageReview.
  ///
  /// In en, this message translates to:
  /// **'Plan Review'**
  String get nasInstallStageReview;

  /// No description provided for @nasInstallStageWriting.
  ///
  /// In en, this message translates to:
  /// **'Writing Configuration'**
  String get nasInstallStageWriting;

  /// No description provided for @nasInstallStagePulling.
  ///
  /// In en, this message translates to:
  /// **'Pulling Image'**
  String get nasInstallStagePulling;

  /// No description provided for @nasInstallStageStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting Container'**
  String get nasInstallStageStarting;

  /// No description provided for @nasInstallStageHealth.
  ///
  /// In en, this message translates to:
  /// **'Health Checking'**
  String get nasInstallStageHealth;

  /// No description provided for @nasInstallStageCleanup.
  ///
  /// In en, this message translates to:
  /// **'Cleaning Up'**
  String get nasInstallStageCleanup;

  /// No description provided for @nasInstallStageSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Deployment Succeeded'**
  String get nasInstallStageSucceeded;

  /// No description provided for @nasInstallStageFailed.
  ///
  /// In en, this message translates to:
  /// **'Deployment Failed'**
  String get nasInstallStageFailed;

  /// No description provided for @nasInstallStageCancelled.
  ///
  /// In en, this message translates to:
  /// **'Deployment Cancelled'**
  String get nasInstallStageCancelled;

  /// No description provided for @nasInstallStageNeedsInspection.
  ///
  /// In en, this message translates to:
  /// **'Requires Inspection'**
  String get nasInstallStageNeedsInspection;

  /// No description provided for @nasInstallStageReconciling.
  ///
  /// In en, this message translates to:
  /// **'Reconciling State'**
  String get nasInstallStageReconciling;

  /// No description provided for @nasInstallCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel Deployment'**
  String get nasInstallCancel;

  /// No description provided for @nasInstallReconcile.
  ///
  /// In en, this message translates to:
  /// **'Reconcile Status'**
  String get nasInstallReconcile;

  /// No description provided for @nasInstallServerNotFound.
  ///
  /// In en, this message translates to:
  /// **'Selected server was not found'**
  String get nasInstallServerNotFound;

  /// No description provided for @nasInstallPortRangeError.
  ///
  /// In en, this message translates to:
  /// **'Port must be between 1 and 65535'**
  String get nasInstallPortRangeError;

  /// No description provided for @nasInstallElapsedTime.
  ///
  /// In en, this message translates to:
  /// **'Elapsed: {time}'**
  String nasInstallElapsedTime(String time);

  /// No description provided for @nasInstallLogTail.
  ///
  /// In en, this message translates to:
  /// **'Recent Logs'**
  String get nasInstallLogTail;

  /// No description provided for @nasInstallCleanupCompleted.
  ///
  /// In en, this message translates to:
  /// **'Rollback cleanup completed'**
  String get nasInstallCleanupCompleted;

  /// No description provided for @nasInstallCleanupIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Rollback cleanup incomplete'**
  String get nasInstallCleanupIncomplete;

  /// No description provided for @nasInstallNewDeployment.
  ///
  /// In en, this message translates to:
  /// **'New Deployment'**
  String get nasInstallNewDeployment;

  /// No description provided for @nasInstallBackEdit.
  ///
  /// In en, this message translates to:
  /// **'Back / Edit Form'**
  String get nasInstallBackEdit;

  /// No description provided for @nasInstallClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get nasInstallClose;

  /// No description provided for @nasInstallMediaPathHint.
  ///
  /// In en, this message translates to:
  /// **'Read-only bind mount on host (e.g. /mnt/media)'**
  String get nasInstallMediaPathHint;

  /// No description provided for @nasInstallDataRootHint.
  ///
  /// In en, this message translates to:
  /// **'Private data & config directory (must not exist yet)'**
  String get nasInstallDataRootHint;

  /// No description provided for @nasInstallBindAddressHint.
  ///
  /// In en, this message translates to:
  /// **'127.0.0.1 for tunnel, 0.0.0.0 for LAN'**
  String get nasInstallBindAddressHint;

  /// No description provided for @nasInstallWebdavPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Minimum 12 characters required'**
  String get nasInstallWebdavPasswordHint;

  /// No description provided for @nasInstallTargetServer.
  ///
  /// In en, this message translates to:
  /// **'Target Server'**
  String get nasInstallTargetServer;

  /// No description provided for @nasInstallTargetImage.
  ///
  /// In en, this message translates to:
  /// **'Target Image'**
  String get nasInstallTargetImage;

  /// No description provided for @nasInstallContainerName.
  ///
  /// In en, this message translates to:
  /// **'Container Name'**
  String get nasInstallContainerName;

  /// No description provided for @nasInstallBindAndPort.
  ///
  /// In en, this message translates to:
  /// **'Bind & Port'**
  String get nasInstallBindAndPort;

  /// No description provided for @nasInstallComposePreview.
  ///
  /// In en, this message translates to:
  /// **'docker-compose.json Preview'**
  String get nasInstallComposePreview;

  /// No description provided for @nasInstallPlannedSteps.
  ///
  /// In en, this message translates to:
  /// **'Planned Steps'**
  String get nasInstallPlannedSteps;

  /// No description provided for @nasInstallGuidanceNotes.
  ///
  /// In en, this message translates to:
  /// **'Deployment Notes & Guidance'**
  String get nasInstallGuidanceNotes;

  /// No description provided for @nasInstallNoLogsYet.
  ///
  /// In en, this message translates to:
  /// **'No logs yet'**
  String get nasInstallNoLogsYet;

  /// No description provided for @sftpPreviewTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File exceeds 1 MiB preview limit. Please download and open it externally.'**
  String get sftpPreviewTooLarge;

  /// No description provided for @sftpSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save file. Check permissions or network connection.'**
  String get sftpSaveFailed;

  /// No description provided for @sftpSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get sftpSaving;

  /// No description provided for @nasInstallBlockerConnectionChanged.
  ///
  /// In en, this message translates to:
  /// **'Target server connection changed; verify remote state before proceeding'**
  String get nasInstallBlockerConnectionChanged;

  /// No description provided for @nasInstallBlockerCancelled.
  ///
  /// In en, this message translates to:
  /// **'Deployment was cancelled by user. Review settings and retry if needed.'**
  String get nasInstallBlockerCancelled;

  /// No description provided for @nasInstallBlockerInspectFailed.
  ///
  /// In en, this message translates to:
  /// **'Inspection failed to query remote container. Check server connectivity or inspect manually.'**
  String get nasInstallBlockerInspectFailed;

  /// No description provided for @nasInstallBlockerDeadlineExceeded.
  ///
  /// In en, this message translates to:
  /// **'Deployment step timed out. Check server load or network connection and retry.'**
  String get nasInstallBlockerDeadlineExceeded;

  /// No description provided for @nasInstallBlockerInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Deployment was interrupted; review remote state before proceeding.'**
  String get nasInstallBlockerInterrupted;

  /// No description provided for @nasInstallBlockerHealthTimeout.
  ///
  /// In en, this message translates to:
  /// **'Service started but HTTP health check timed out. Verify service logs or port availability.'**
  String get nasInstallBlockerHealthTimeout;

  /// No description provided for @nasInstallBlockerReconciliationFailed.
  ///
  /// In en, this message translates to:
  /// **'Reconciliation failed. Verify remote container status manually or start a new deployment.'**
  String get nasInstallBlockerReconciliationFailed;

  /// No description provided for @nasInstallBlockerRemoteInspectionRequired.
  ///
  /// In en, this message translates to:
  /// **'Remote container status is uncertain. Manual inspection and reconciliation required.'**
  String get nasInstallBlockerRemoteInspectionRequired;

  /// No description provided for @nasInstallBlockerServiceExited.
  ///
  /// In en, this message translates to:
  /// **'Container process exited prematurely. Check logs for configuration or permission errors.'**
  String get nasInstallBlockerServiceExited;

  /// No description provided for @nasInstallBlockerWriteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to write deployment files on target server. Check disk space and permissions.'**
  String get nasInstallBlockerWriteFailed;

  /// No description provided for @nasInstallBlockerPlanStale.
  ///
  /// In en, this message translates to:
  /// **'Deployment plan is stale. Please re-run preflight checks.'**
  String get nasInstallBlockerPlanStale;

  /// No description provided for @nasInstallBlockerOwnershipChanged.
  ///
  /// In en, this message translates to:
  /// **'Existing container was not created by this app. Inspect manually to prevent overwriting.'**
  String get nasInstallBlockerOwnershipChanged;

  /// No description provided for @nasInstallBlockerSshRequired.
  ///
  /// In en, this message translates to:
  /// **'Active SSH connection to target server is required.'**
  String get nasInstallBlockerSshRequired;

  /// No description provided for @nasInstallBlockerReconciliationRequired.
  ///
  /// In en, this message translates to:
  /// **'Remote state differs from local state. Please reconcile before proceeding.'**
  String get nasInstallBlockerReconciliationRequired;

  /// No description provided for @nasInstallBlockerFailed.
  ///
  /// In en, this message translates to:
  /// **'Deployment encountered an error. Check logs and retry.'**
  String get nasInstallBlockerFailed;

  /// No description provided for @nasInstallBlockerBusy.
  ///
  /// In en, this message translates to:
  /// **'An installation task is already in progress. Please check the current task progress.'**
  String get nasInstallBlockerBusy;

  /// No description provided for @nasInstallBlockerStateSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to persist deployment state. Please check local storage space and file permissions.'**
  String get nasInstallBlockerStateSaveFailed;

  /// No description provided for @nasInstallBlockerCommandResultUnknown.
  ///
  /// In en, this message translates to:
  /// **'Remote command outcome is unknown. Please run a read-only inspection instead of retrying deployment directly.'**
  String get nasInstallBlockerCommandResultUnknown;

  /// No description provided for @nasInstallBlockerPreflightFailed.
  ///
  /// In en, this message translates to:
  /// **'Pre-deployment environment check failed. Please resolve the blockers before continuing.'**
  String get nasInstallBlockerPreflightFailed;

  /// No description provided for @serverDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete server: {error}'**
  String serverDeleteFailed(String error);

  /// No description provided for @chatRunSettingsAgentMode.
  ///
  /// In en, this message translates to:
  /// **'Agent Mode'**
  String get chatRunSettingsAgentMode;

  /// No description provided for @chatRunSettingsApprovalPolicy.
  ///
  /// In en, this message translates to:
  /// **'Local Approval Policy'**
  String get chatRunSettingsApprovalPolicy;

  /// No description provided for @chatRunSettingsExtraSettings.
  ///
  /// In en, this message translates to:
  /// **'Additional Settings'**
  String get chatRunSettingsExtraSettings;

  /// No description provided for @chatPermissionAutoAllowSafeDesc.
  ///
  /// In en, this message translates to:
  /// **'Automatically allows known-safe operations; asks whenever operation safety cannot be determined.'**
  String get chatPermissionAutoAllowSafeDesc;

  /// No description provided for @chatRunSettingsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to apply run settings: {error}'**
  String chatRunSettingsSaveFailed(String error);

  /// No description provided for @chatMessageCopied.
  ///
  /// In en, this message translates to:
  /// **'Message copied to clipboard'**
  String get chatMessageCopied;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @sessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Session Title'**
  String get sessionTitle;

  /// No description provided for @chatSettingsStale.
  ///
  /// In en, this message translates to:
  /// **'Stale'**
  String get chatSettingsStale;

  /// No description provided for @chatSettingsAvailableAfterFirstMessage.
  ///
  /// In en, this message translates to:
  /// **'Settings available after first message'**
  String get chatSettingsAvailableAfterFirstMessage;

  /// No description provided for @chatReimportAsCopy.
  ///
  /// In en, this message translates to:
  /// **'Re-import as Copy'**
  String get chatReimportAsCopy;

  /// No description provided for @chatSearchCommandsHint.
  ///
  /// In en, this message translates to:
  /// **'Search commands or skills...'**
  String get chatSearchCommandsHint;

  /// No description provided for @chatCommandsTab.
  ///
  /// In en, this message translates to:
  /// **'Commands'**
  String get chatCommandsTab;

  /// No description provided for @chatSkillsTab.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get chatSkillsTab;

  /// No description provided for @chatAccountAndQuotaTitle.
  ///
  /// In en, this message translates to:
  /// **'Account & Quota'**
  String get chatAccountAndQuotaTitle;

  /// No description provided for @chatAccountSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get chatAccountSectionTitle;

  /// No description provided for @chatAccountNotProvided.
  ///
  /// In en, this message translates to:
  /// **'No account details reported'**
  String get chatAccountNotProvided;

  /// No description provided for @chatAccountKind.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get chatAccountKind;

  /// No description provided for @chatAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get chatAccountLabel;

  /// No description provided for @chatAccountPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get chatAccountPlan;

  /// No description provided for @chatAccountEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get chatAccountEmail;

  /// No description provided for @chatAccountUpdatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get chatAccountUpdatedAt;

  /// No description provided for @chatQuotaSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Quota & Status'**
  String get chatQuotaSectionTitle;

  /// No description provided for @chatStatusSourceNote.
  ///
  /// In en, this message translates to:
  /// **'Raw Agent /status Output'**
  String get chatStatusSourceNote;

  /// No description provided for @chatStatusNotQueried.
  ///
  /// In en, this message translates to:
  /// **'Status not queried yet'**
  String get chatStatusNotQueried;

  /// No description provided for @chatQueryStatusAction.
  ///
  /// In en, this message translates to:
  /// **'Query Status (/status)'**
  String get chatQueryStatusAction;

  /// No description provided for @chatQueryStatusUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Status query unavailable in current session'**
  String get chatQueryStatusUnavailable;

  /// No description provided for @chatAttachmentMissing.
  ///
  /// In en, this message translates to:
  /// **'Attachment file missing or unavailable'**
  String get chatAttachmentMissing;

  /// No description provided for @chatViewModeList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get chatViewModeList;

  /// No description provided for @chatViewModeCards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get chatViewModeCards;

  /// No description provided for @chatViewModeGrid.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get chatViewModeGrid;

  /// No description provided for @chatRemoteBrowserTitle.
  ///
  /// In en, this message translates to:
  /// **'Remote Workspace'**
  String get chatRemoteBrowserTitle;

  /// No description provided for @chatSelectDirectory.
  ///
  /// In en, this message translates to:
  /// **'Select Directory'**
  String get chatSelectDirectory;

  /// No description provided for @chatAttachSelectedFiles.
  ///
  /// In en, this message translates to:
  /// **'Attach Selected ({count})'**
  String chatAttachSelectedFiles(int count);

  /// No description provided for @chatNoFilesFound.
  ///
  /// In en, this message translates to:
  /// **'No files found'**
  String get chatNoFilesFound;

  /// No description provided for @chatRootDirectory.
  ///
  /// In en, this message translates to:
  /// **'Root'**
  String get chatRootDirectory;

  /// No description provided for @chatSelectThisDirectory.
  ///
  /// In en, this message translates to:
  /// **'Use this directory'**
  String get chatSelectThisDirectory;

  /// No description provided for @chatAgentVersion.
  ///
  /// In en, this message translates to:
  /// **'Agent Version'**
  String get chatAgentVersion;

  /// No description provided for @chatParentDirectory.
  ///
  /// In en, this message translates to:
  /// **'Parent Directory'**
  String get chatParentDirectory;

  /// No description provided for @chatSearchFilesHint.
  ///
  /// In en, this message translates to:
  /// **'Search files...'**
  String get chatSearchFilesHint;

  /// No description provided for @chatCommandsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No slash commands provided by the agent'**
  String get chatCommandsEmpty;

  /// No description provided for @chatSkillsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No skills provided by the agent'**
  String get chatSkillsEmpty;

  /// No description provided for @chatFileUnsupported.
  ///
  /// In en, this message translates to:
  /// **'File type not supported for attachment'**
  String get chatFileUnsupported;

  /// No description provided for @chatStatusNotProvided.
  ///
  /// In en, this message translates to:
  /// **'Status query not provided by agent'**
  String get chatStatusNotProvided;

  /// No description provided for @sessionRecoveryReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting...'**
  String get sessionRecoveryReconnecting;

  /// No description provided for @sessionRecoverySyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing output...'**
  String get sessionRecoverySyncing;

  /// No description provided for @sessionRecoveryIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Some output could not be recovered'**
  String get sessionRecoveryIncomplete;

  /// No description provided for @sessionRecoveryFailed.
  ///
  /// In en, this message translates to:
  /// **'Recovery failed'**
  String get sessionRecoveryFailed;

  /// No description provided for @sessionRecoveryRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get sessionRecoveryRetry;

  /// No description provided for @dashboardUpdatesPaused.
  ///
  /// In en, this message translates to:
  /// **'Updates paused'**
  String get dashboardUpdatesPaused;

  /// No description provided for @chatSettingsIndependentModelUnavailable.
  ///
  /// In en, this message translates to:
  /// **'CLI model catalog is currently unavailable. Models may be cached or limited by the CLI version; you can also enter a model name manually.'**
  String get chatSettingsIndependentModelUnavailable;

  /// No description provided for @chatSettingsModelCatalogNote.
  ///
  /// In en, this message translates to:
  /// **'Models are queried from the CLI app-server using your existing CLI login. The catalog may be cached or version-limited; you can refresh manually or switch to manual input.'**
  String get chatSettingsModelCatalogNote;

  /// No description provided for @chatModelCatalogError403.
  ///
  /// In en, this message translates to:
  /// **'CLI model query access denied (403). Check CLI login and service connectivity, or enter a model name manually.'**
  String get chatModelCatalogError403;

  /// No description provided for @chatModelCatalogErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Model catalog error: {error}'**
  String chatModelCatalogErrorGeneric(String error);

  /// No description provided for @chatModelAuthorizeButton.
  ///
  /// In en, this message translates to:
  /// **'Authorize Model Catalog'**
  String get chatModelAuthorizeButton;

  /// No description provided for @chatModelAuthorizeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Authorize Model Catalog'**
  String get chatModelAuthorizeConfirmTitle;

  /// No description provided for @chatModelAuthorizeConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will start browser authorization for the model catalog on target host/container. Your existing Codex login and terminal sessions will remain completely untouched. Continue?'**
  String get chatModelAuthorizeConfirmMessage;

  /// No description provided for @chatModelAuthorizing.
  ///
  /// In en, this message translates to:
  /// **'Authorizing via browser...'**
  String get chatModelAuthorizing;

  /// No description provided for @chatModelAuthorizeCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel Authorization'**
  String get chatModelAuthorizeCancel;

  /// No description provided for @chatCommandsFirstTurnNote.
  ///
  /// In en, this message translates to:
  /// **'Slash commands will be advertised by the agent runtime once the session is initialized, without requiring a prior ordinary conversation; drafts do not automatically create sessions.'**
  String get chatCommandsFirstTurnNote;

  /// No description provided for @chatCommandsClientActionRunSettings.
  ///
  /// In en, this message translates to:
  /// **'Run Settings'**
  String get chatCommandsClientActionRunSettings;

  /// No description provided for @chatCommandsClientActionWorkingDirectory.
  ///
  /// In en, this message translates to:
  /// **'Working Directory'**
  String get chatCommandsClientActionWorkingDirectory;

  /// No description provided for @chatCommandsClientActionsSection.
  ///
  /// In en, this message translates to:
  /// **'Local Actions'**
  String get chatCommandsClientActionsSection;

  /// No description provided for @chatRunSettingsModelSourceCatalog.
  ///
  /// In en, this message translates to:
  /// **'Model List'**
  String get chatRunSettingsModelSourceCatalog;

  /// No description provided for @chatRunSettingsModelSourceCustom.
  ///
  /// In en, this message translates to:
  /// **'Manual Input'**
  String get chatRunSettingsModelSourceCustom;

  /// No description provided for @chatRunSettingsCustomModelHint.
  ///
  /// In en, this message translates to:
  /// **'Enter model ID'**
  String get chatRunSettingsCustomModelHint;

  /// No description provided for @chatRunSettingsCustomModelNotice.
  ///
  /// In en, this message translates to:
  /// **'Manual model names are unverified and will be sent directly to the agent runtime, which may reject unsupported models.'**
  String get chatRunSettingsCustomModelNotice;

  /// No description provided for @chatRunSettingsCustomModelEmptyError.
  ///
  /// In en, this message translates to:
  /// **'Model name cannot be empty'**
  String get chatRunSettingsCustomModelEmptyError;

  /// No description provided for @chatRunSettingsCustomModelInvalidError.
  ///
  /// In en, this message translates to:
  /// **'Model name must be at most 256 characters with no spaces or control characters'**
  String get chatRunSettingsCustomModelInvalidError;

  /// No description provided for @chatCommandsDraftPreviewNotice.
  ///
  /// In en, this message translates to:
  /// **'Commands verified for the current adapter version. Selecting inserts text into the draft; Send will initialize the session on demand and run the command directly.'**
  String get chatCommandsDraftPreviewNotice;

  /// No description provided for @chatCommandsDiscoveryFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to discover commands or skills'**
  String get chatCommandsDiscoveryFailed;
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
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
