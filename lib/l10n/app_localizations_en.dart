// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Valhalla';

  @override
  String get appSubtitle => 'AI-Native Server & Agent Management';

  @override
  String get navAiChat => 'AI Ops';

  @override
  String get navTerminal => 'Terminal';

  @override
  String get navFiles => 'SFTP Files';

  @override
  String get navCommands => 'Commands';

  @override
  String get navSettings => 'Settings';

  @override
  String get serverConnected => 'Connected';

  @override
  String get serverOnline => 'Online';

  @override
  String get serverOffline => 'Offline';

  @override
  String get latencyMs => 'ms';

  @override
  String get reconnect => 'Reconnect';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get quickDisconnect => 'Quick Disconnect';

  @override
  String get newSession => 'New Session';

  @override
  String get historySessions => 'History Sessions';

  @override
  String get switchAgent => 'Switch Agent';

  @override
  String get agentClaudeCode => 'Claude CodeX';

  @override
  String get agentCodex => 'OpenAI Codex';

  @override
  String get agentOpenCode => 'OpenCode ACP';

  @override
  String get agentGemini => 'Gemini CLI';

  @override
  String get activeAgent => 'Active Agent';

  @override
  String get inputPromptHint =>
      'Ask Agent to diagnose, run tools or write commands... (Enter to send)';

  @override
  String get thinking => 'Thinking Process';

  @override
  String get executionPlan => 'Execution Plan';

  @override
  String get toolCall => 'Tool Call';

  @override
  String get toolStatusPending => 'Pending';

  @override
  String get toolStatusRunning => 'Running...';

  @override
  String get toolStatusCompleted => 'Completed';

  @override
  String get toolStatusFailed => 'Failed';

  @override
  String get permissionRequired => 'Permission Required';

  @override
  String get permissionDescription =>
      'Agent wants to execute this command on the server:';

  @override
  String get permissionReject => 'Reject';

  @override
  String get permissionAllowOnce => 'Allow Once';

  @override
  String get permissionAllowAlways => 'Always Allow';

  @override
  String get quickTroubleshootCpu => 'Troubleshoot High CPU';

  @override
  String get quickDockerHealth => 'Docker Health Check';

  @override
  String get quickCleanCache => 'Clean System Cache';

  @override
  String get quickNginxLogs => 'Check Nginx Error Logs';

  @override
  String get terminalNewTab => 'New Tab';

  @override
  String get terminalCloseTab => 'Close Tab';

  @override
  String get terminalClear => 'Clear';

  @override
  String get terminalQuickCmds => 'Command Palette';

  @override
  String get terminalPaste => 'Paste';

  @override
  String get sftpCurrentPath => 'Current Path';

  @override
  String get sftpUpload => 'Upload';

  @override
  String get sftpNewFolder => 'New Folder';

  @override
  String get sftpNewFile => 'New File';

  @override
  String get sftpRefresh => 'Refresh';

  @override
  String get sftpSearchHint => 'Search files or folders...';

  @override
  String get sftpEmpty => 'Directory is empty';

  @override
  String get sftpFileName => 'Name';

  @override
  String get sftpFileSize => 'Size';

  @override
  String get sftpFilePerm => 'Permissions';

  @override
  String get sftpFileModified => 'Modified';

  @override
  String get cmdCategoryDocker => 'DOCKER CONTAINER STACK';

  @override
  String get cmdCategorySystem => 'SYSTEM MAINTENANCE';

  @override
  String get cmdCategoryNetwork => 'NETWORK & PORTS';

  @override
  String get cmdExecute => 'Run';

  @override
  String get cmdDangerous => 'Dangerous Command';

  @override
  String get cmdDangerousWarning =>
      'This operation is irreversible and may cause service interruption. Are you sure you want to proceed?';

  @override
  String get cmdParamRequired => 'Parameter Input Required';

  @override
  String get cmdConfirm => 'Confirm & Run';

  @override
  String get cmdCancel => 'Cancel';

  @override
  String get settingsAppearance => 'Appearance & Theming';

  @override
  String get settingsThemeMode => 'Theme Mode';

  @override
  String get themeSystem => 'Follow System';

  @override
  String get themeSystemDesc => 'Auto Adaptive';

  @override
  String get themeLight => 'Light Mode';

  @override
  String get themeLightDesc => 'Paper High-Key';

  @override
  String get themeDark => 'Geek Dark';

  @override
  String get themeDarkDesc => 'Deep Charcoal';

  @override
  String get themeAmoled => 'AMOLED Black';

  @override
  String get themeAmoledDesc => 'True Black 0x000000';

  @override
  String get settingsAccentColor => 'Theme Accent Color';

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
  String get settingsLanguage => 'Language & Locale';

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
  String get settingsAiOps => 'AI Ops & Engine';

  @override
  String get settingsSecurity => 'Connection & Security';

  @override
  String get settingsKnownHosts => 'Known Host Keys';

  @override
  String get settingsClearStorage => 'Reset Credentials';

  @override
  String get settingsResetDefault => 'Reset Defaults';

  @override
  String get settingsTerminalUseTmux => 'Persistent Sessions (tmux)';

  @override
  String get settingsTerminalUseTmuxSubtitle =>
      'Run terminal sessions inside tmux on the remote server';

  @override
  String get settingsTerminalUseTmuxDescription =>
      'Keeps your terminal output after a disconnect. Requires tmux on the remote server. Changes apply to newly opened terminal tabs.';

  @override
  String get settingsTerminalFontSize => 'Terminal Font Size';

  @override
  String get settingsTerminalFontSizeSubtitle =>
      'Adjusts SSH and CLI terminal font size';

  @override
  String get version => 'Version';

  @override
  String get addServer => 'Add Server';

  @override
  String get editServer => 'Edit Server';

  @override
  String get serverName => 'Server Name';

  @override
  String get serverHost => 'Host / IP';

  @override
  String get serverPort => 'Port';

  @override
  String get serverUsername => 'Username';

  @override
  String get serverAuthType => 'Authentication Type';

  @override
  String get serverPassword => 'Password';

  @override
  String get serverPrivateKey => 'Private Key';

  @override
  String get serverSave => 'Save Server';

  @override
  String get serverDelete => 'Delete Server';

  @override
  String get fileEditor => 'File Editor';

  @override
  String get fileEditorSave => 'Save Changes';

  @override
  String get fileSavedSuccess => 'File saved successfully';

  @override
  String get addCommand => 'New Command';

  @override
  String get commandTitle => 'Command Title';

  @override
  String get commandContent => 'Command String';

  @override
  String get commandCategory => 'Category';

  @override
  String get commandDescription => 'Description';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get cmdExecutionChannel => 'Execution Channel';

  @override
  String get cmdChannelTerminal => 'Direct to SSH Terminal';

  @override
  String get cmdChannelTerminalDesc =>
      'Command is typed directly into active terminal session';

  @override
  String get cmdChannelBackground => 'Run in Background Session';

  @override
  String get cmdChannelBackgroundDesc =>
      'Executes via SSH login shell and captures output';

  @override
  String get cmdInjectedToTerminal => 'Command sent to terminal';

  @override
  String get cmdExecutionCompleted => 'Execution Completed';

  @override
  String get cmdExecutionFailed => 'Execution Failed';

  @override
  String get cmdExecutingRemote => 'Executing remote command...';

  @override
  String get cmdClose => 'Close';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navDocker => 'Docker';

  @override
  String get navSystem => 'System';

  @override
  String get navMore => 'More';

  @override
  String get dashboardTitle => 'Server Dashboard';

  @override
  String get metricsCpu => 'CPU Usage';

  @override
  String get metricsMemory => 'Memory Usage';

  @override
  String get metricsLoadAvg => 'Load Average';

  @override
  String get metricsUptime => 'System Uptime';

  @override
  String get metricsRootDisk => 'Root Disk Usage';

  @override
  String get quickActions => 'Quick Navigation';

  @override
  String get activeServerStatus => 'Active Server Status';

  @override
  String get noServerSelected =>
      'No server currently selected. Please select a server first.';

  @override
  String get serverDisconnected => 'Disconnected';

  @override
  String get serverConnecting => 'Connecting...';

  @override
  String get connectNow => 'Connect Now';

  @override
  String get serverSpecs => 'Server Info & Specs';

  @override
  String get dockerTitle => 'Docker Containers';

  @override
  String get dockerSearchHint => 'Search containers by name or image...';

  @override
  String get dockerFilterAll => 'All';

  @override
  String get dockerFilterRunning => 'Running';

  @override
  String get dockerFilterExited => 'Exited';

  @override
  String get dockerFilterPaused => 'Paused';

  @override
  String get dockerActionStart => 'Start';

  @override
  String get dockerActionStop => 'Stop';

  @override
  String get dockerActionRestart => 'Restart';

  @override
  String get dockerActionPause => 'Pause';

  @override
  String get dockerActionUnpause => 'Unpause';

  @override
  String get dockerActionRm => 'Remove';

  @override
  String get dockerActionLogs => 'Logs';

  @override
  String get dockerActionInspect => 'Inspect';

  @override
  String get dockerLogsTitle => 'Container Logs';

  @override
  String get dockerInspectTitle => 'Container Inspect';

  @override
  String get dockerNoContainers => 'No containers found on server';

  @override
  String get dockerEmptyRunning => 'No running containers';

  @override
  String get dockerPorts => 'Ports';

  @override
  String get dockerCreated => 'Created';

  @override
  String get dockerImage => 'Image';

  @override
  String get systemTitle => 'Processes & Services';

  @override
  String get tabProcesses => 'Processes';

  @override
  String get tabServices => 'Systemd Services';

  @override
  String get processSearchHint => 'Search by process name or PID...';

  @override
  String get processPid => 'PID';

  @override
  String get processCpu => 'CPU %';

  @override
  String get processMem => 'MEM %';

  @override
  String get processStat => 'State';

  @override
  String get processCommand => 'Command';

  @override
  String get processTerminate => 'Terminate (SIGTERM)';

  @override
  String get processForceKill => 'Force Kill (SIGKILL)';

  @override
  String get processKillForbidden =>
      'Refusing to terminate system init (PID <= 1)';

  @override
  String get serviceSearchHint => 'Search services by name...';

  @override
  String get serviceName => 'Service';

  @override
  String get serviceDescription => 'Description';

  @override
  String get serviceStatus => 'Status';

  @override
  String get serviceStartup => 'Startup';

  @override
  String get serviceActionStart => 'Start';

  @override
  String get serviceActionStop => 'Stop';

  @override
  String get serviceActionRestart => 'Restart';

  @override
  String get serviceActionReload => 'Reload';

  @override
  String get serviceActionEnable => 'Enable';

  @override
  String get serviceActionDisable => 'Disable';

  @override
  String get serviceNoServices => 'No systemd services found';

  @override
  String get riskDangerTitle => 'High Risk Operation Confirmation';

  @override
  String get riskWarningTitle => 'Operation Warning Confirmation';

  @override
  String get riskSafeTitle => 'Confirm Action';

  @override
  String get riskIrreversibleWarning =>
      'This operation is classified as HIGH RISK and cannot be undone. It may cause data loss or service disruption.';

  @override
  String get riskWarningDescription =>
      'This operation may affect active services or restart processes. Proceed with caution.';

  @override
  String get riskCommandPreview => 'Command Preview';

  @override
  String get riskConfirmButton => 'Confirm & Proceed';

  @override
  String get riskCancelButton => 'Cancel';

  @override
  String get stateLoading => 'Loading remote data...';

  @override
  String get stateOffline => 'Server is offline';

  @override
  String get stateOfflineDesc =>
      'Establish an active SSH connection to manage resources and stream metrics.';

  @override
  String get stateError => 'An error occurred';

  @override
  String get stateRetry => 'Retry';

  @override
  String get stateEmpty => 'No items found';

  @override
  String get inspectorTitle => 'Inspector';

  @override
  String get inspectorClose => 'Close';

  @override
  String get inspectorDetails => 'Inspect Details';

  @override
  String get selectServerTitle => 'Select Target Server';

  @override
  String get sshDisconnectedSuccess => 'SSH connection disconnected';

  @override
  String get trustHostFingerprintTitle => 'Trust Host Fingerprint?';

  @override
  String get trustAndConnect => 'Trust & Connect';

  @override
  String get reject => 'Reject';

  @override
  String get confirmDeleteServerTitle => 'Delete Server';

  @override
  String get noServersFound => 'No servers configured yet';

  @override
  String get agentNotReadyError =>
      'Selected agent is not ready. Please verify its environment and configuration.';

  @override
  String get sshDisconnectedError =>
      'SSH is disconnected. Please connect to a server before using AI Ops.';

  @override
  String get noAgentAvailable => 'No Agent Available';

  @override
  String get noAgentAvailablePrompt =>
      'No active Agent available. Please configure or ready an agent first.';

  @override
  String get noAgentAvailableHint =>
      'Select or configure an available agent to chat...';

  @override
  String get manageAgents => 'Manage Agents';

  @override
  String get noReadyAgentsTitle => 'No Ready Agents';

  @override
  String get noReadyAgentsDesc =>
      'No agents on this server have passed environment checks.';

  @override
  String get agentStatusReady => 'Ready';

  @override
  String get agentStatusChecking => 'Checking...';

  @override
  String get agentStatusCliMissing => 'Installation not detected';

  @override
  String get agentStatusAcpMissing => 'ACP component not detected';

  @override
  String get agentStatusNotLoggedIn => 'Not Logged In';

  @override
  String get agentStatusError => 'Error';

  @override
  String get agentStatusUnknown => 'Unknown';

  @override
  String get agentActionInstall => 'Install';

  @override
  String get agentActionLogin => 'Login';

  @override
  String get agentActionRefresh => 'Check Status';

  @override
  String get noConfiguredAgents => 'No agents configured on this server';

  @override
  String get agentManagementTitle => 'Agent Management';

  @override
  String get settingsAgentManagement => 'Agent Management';

  @override
  String get settingsAgentManagementSubtitle =>
      'Configure, detect and manage ACP Agents for current server';

  @override
  String get addAgentButton => 'Add Agent';

  @override
  String get noServerSelectedForAgents =>
      'No server selected. Please select a server from the main interface first.';

  @override
  String get sshDisconnectedAgentWarning =>
      'SSH is disconnected. Detection, installation, and login are disabled until connection is established.';

  @override
  String get noAgentsConfiguredTitle => 'No Agents Configured';

  @override
  String get noAgentsConfiguredDesc =>
      'Add Claude Code, Codex, OpenCode, AGY or custom ACP agents to enable AI Ops on this server.';

  @override
  String get agentPresetLabel => 'Preset';

  @override
  String get agentPresetClaudeCode => 'Claude Code';

  @override
  String get agentPresetCodex => 'OpenAI Codex';

  @override
  String get agentPresetOpenCode => 'OpenCode ACP';

  @override
  String get agentPresetAgy => 'Antigravity AGY';

  @override
  String get agentPresetCustom => 'Custom';

  @override
  String get agentNameLabel => 'Agent Name';

  @override
  String get agentNameHint => 'e.g. Production Codex';

  @override
  String get agentDescriptionLabel => 'Description';

  @override
  String get agentDescriptionHint => 'Brief description of the agent';

  @override
  String get agentCliCommandLabel => 'CLI Probe Command';

  @override
  String get agentCliCommandHint => 'e.g. claude, codex';

  @override
  String get agentAcpCommandLabel => 'ACP Launch Command';

  @override
  String get agentAcpCommandHint => 'e.g. codex-acp --stdio';

  @override
  String get agentInstallCommandLabel => 'Install Command (Optional)';

  @override
  String get agentInstallCommandHint => 'e.g. npm install -g @openai/codex';

  @override
  String get agentLoginCheckCommandLabel => 'Login Check Command (Optional)';

  @override
  String get agentLoginCheckCommandHint => 'e.g. codex --version';

  @override
  String get agentLoginCommandLabel => 'Login Command (Optional)';

  @override
  String get agentLoginCommandHint => 'e.g. codex login';

  @override
  String get agentSaveButton => 'Save & Detect';

  @override
  String get agentCliRequired => 'CLI probe command is required';

  @override
  String get agentAcpRequired => 'ACP launch command is required';

  @override
  String get agentNameRequired => 'Agent name is required';

  @override
  String get confirmInstallAgentTitle => 'Confirm Agent Installation';

  @override
  String get confirmLoginAgentTitle => 'Confirm Agent Login';

  @override
  String get agentCommandRiskWarning =>
      'This command will be executed directly on the remote server with current user privileges. It may install packages or modify system environments.';

  @override
  String get targetServerLabel => 'Target Server';

  @override
  String get commandPreviewLabel => 'Command Preview';

  @override
  String get executeButton => 'Execute';

  @override
  String get deleteAgentTitle => 'Delete Agent';

  @override
  String get deleteAgentConfirm => 'Delete';

  @override
  String get agentStatusCheckingDesc =>
      'Detecting environment on remote server...';

  @override
  String get agentStatusInstalling => 'Installing dependencies on server...';

  @override
  String get agentStatusLoggingIn => 'Executing login command on server...';

  @override
  String get agentNoLoginCheckProvided => 'No login check command specified';

  @override
  String get agentInstallPrompt =>
      'Installation not detected. Auto-install now?';

  @override
  String get agentActionAutoInstall => 'Auto Install';

  @override
  String get agentLoginPrompt => 'Not logged in. Log in now?';

  @override
  String get agentActionExecuteLogin => 'Log In Now';

  @override
  String get agentNeedsInstallOrReadyPrompt =>
      'Agents on this server are not installed or ready yet. Please manage and complete environment setup.';

  @override
  String get agentNeedsInstallOrReadyHint =>
      'Install and ready an agent to start chatting...';

  @override
  String get agentAcpInstallPrompt =>
      'ACP component not detected. Auto-install now?';

  @override
  String get agentInstallCommandAcpLabel => 'ACP Install Command (Optional)';

  @override
  String get agentInstallCommandAcpHint =>
      'e.g. npm install -g @zed-industries/codex-acp';

  @override
  String get agentNoInstallCommand =>
      'No install command configured for this agent';

  @override
  String get agentInstallLogTitle => 'Install output';

  @override
  String get agentInstallLogEmpty => 'Waiting for install output…';

  @override
  String get agentInstallLogTruncated =>
      'Output too long; showing the most recent lines';

  @override
  String get agentAcpOptional => 'Optional; leave empty for CLI-only';

  @override
  String get acpStreaming => 'ACP Streaming...';

  @override
  String get aiOpsAgentTitle => 'Valhalla AI Ops Agent';

  @override
  String get aiOpsEmptySubtitle => 'Connected via ACP stdio over SSH Channel';

  @override
  String get agentAuthRequiredTitle => 'Authentication Required';

  @override
  String get agentAuthRequiredDesc =>
      'The agent requires authentication before it can process your request.';

  @override
  String get agentAuthMethodLabel => 'Authentication Method';

  @override
  String get agentAuthNoMethodsNotice =>
      'The agent did not provide a login method. Please check its configuration on the server.';

  @override
  String get agentAuthProceedButton => 'Log In';

  @override
  String get agentAuthCancelButton => 'Cancel';

  @override
  String get agentAuthRetryHint => 'After logging in, send your message again.';

  @override
  String get agentAuthRequiredError =>
      'Authentication required. Please log in to continue.';

  @override
  String get agentLoginTerminalTitle => 'Interactive Login Terminal';

  @override
  String get agentLoginTerminalSubtitle =>
      'Complete the login steps in the terminal below. Follow any URL or code prompt shown.';

  @override
  String get agentLoginTerminalRunning =>
      'Login command is running in the terminal...';

  @override
  String get agentLoginTerminalDisconnected =>
      'SSH connection lost. The login session was interrupted.';

  @override
  String get agentLoginTerminalRetry => 'Reconnect Terminal';

  @override
  String get agentLoginTerminalFinish => 'Finish & Verify';

  @override
  String get agentLoginTerminalClose => 'Close';

  @override
  String get agentLoginTerminalNoTtyHint =>
      'If the agent requires pasting a code, long-press the terminal to paste or use the PASTE key.';

  @override
  String get agentLoginTerminalUrlLabel => 'Login URL detected';

  @override
  String get agentLoginTerminalUrlCopy => 'Copy link';

  @override
  String get agentLoginTerminalUrlCopied => 'Login URL copied to clipboard';

  @override
  String get agentLoginTerminalCopyAll => 'Copy all output';

  @override
  String get agentLoginTerminalCopiedAll =>
      'Terminal output copied to clipboard';

  @override
  String get sshStatusReconnected => 'Connection restored';

  @override
  String get sshStatusDisconnectedRetrying => 'Connection lost, retrying';

  @override
  String get sshStatusDisconnectedManual => 'Disconnected';

  @override
  String get sshStatusHostKeyChanged => 'Host key changed — connection refused';

  @override
  String get sshKeepAliveNotificationTitle =>
      'Valhalla is keeping your sessions alive';

  @override
  String get terminalTmuxMissingNotice =>
      'tmux not found — sessions won\'t survive a drop';

  @override
  String get terminalTmuxSessionRestored => 'Terminal session restored';

  @override
  String get moshSectionTitle => 'Mosh';

  @override
  String get moshEnable =>
      'Enable Mosh — a roaming terminal that survives connection drops and IP changes';

  @override
  String get moshServerPathLabel => 'mosh-server path';

  @override
  String get moshPortRangeLabel => 'UDP port range';

  @override
  String get moshNewSession => 'New Mosh Session';

  @override
  String get moshNotInstalled =>
      'mosh-server was not found on the remote server. Install it with: sudo apt install mosh (Debian/Ubuntu) or sudo dnf install mosh (Fedora/RHEL).';

  @override
  String moshBootstrapFailed(String detail) {
    return 'Failed to start Mosh session: $detail';
  }

  @override
  String get moshUdpTimeout =>
      'Mosh connection timed out — check that UDP traffic is not blocked by a firewall.';

  @override
  String get moshSessionTag => 'mosh';

  @override
  String get acpSessionRestored => 'Agent session restored';

  @override
  String get acpSessionRestartNotice =>
      'Agent session restarted — previous context unavailable';

  @override
  String get terminalTmuxInstallDialogTitle => 'Install tmux on Remote Server?';

  @override
  String get terminalTmuxInstallDialogMessage =>
      'tmux is required to preserve terminal sessions across disconnections. Would you like to install it now?';

  @override
  String get terminalTmuxInstallCommandLabel => 'Command to execute:';

  @override
  String get terminalTmuxInstallUnsupported =>
      'No supported package manager detected on remote server. Please install tmux manually.';

  @override
  String get terminalTmuxInstallFailed =>
      'tmux installation failed. Please verify server permissions and network.';

  @override
  String get terminalTmuxInstallDisconnected =>
      'SSH connection lost. Please reconnect to install tmux.';

  @override
  String get terminalTmuxInstallInstalling => 'Installing tmux...';

  @override
  String get terminalTmuxInstallConfirm => 'Install tmux';

  @override
  String get terminalTmuxInstallSkip => 'Skip (Use Plain Shell)';

  @override
  String get sftpDownload => 'Download';

  @override
  String get sftpOpen => 'Open';

  @override
  String get sftpUploadFailed =>
      'Upload failed. Check permissions and try again.';

  @override
  String get sftpDownloadFailed => 'Download failed';

  @override
  String get sftpOpenUnsupported => 'This file format cannot be opened.';

  @override
  String get sftpReadFailed =>
      'Failed to read the file. Check permissions and try again.';

  @override
  String get sftpTransferFailed => 'File operation failed. Please try again.';

  @override
  String get sftpDownloadSuccess => 'Downloaded successfully';

  @override
  String get sftpUploading => 'Uploading...';

  @override
  String get sftpDownloading => 'Downloading...';

  @override
  String get sftpUpDirectory => 'Up to parent directory';

  @override
  String get sftpShowHiddenFiles => 'Show hidden files';

  @override
  String get sftpHideHiddenFiles => 'Hide hidden files';

  @override
  String get sftpHiddenPreferenceSaveFailed =>
      'Failed to save hidden files preference';

  @override
  String get sftpSymlink => 'Symlink';

  @override
  String get sftpLinkTargetUnavailable =>
      'Symlink target is broken or unavailable';

  @override
  String get sftpLinkTargetPermissionDenied =>
      'Permission denied reading symlink target';

  @override
  String get settingsAutoConnect => 'Auto connect on launch';

  @override
  String get settingsAutoConnectFixed => 'Fixed default SSH';

  @override
  String get settingsAutoConnectFixedDesc =>
      'Always connect to the server you pick below';

  @override
  String get settingsAutoConnectLast => 'Remember last connection';

  @override
  String get settingsAutoConnectLastDesc =>
      'Connect to the server that was last connected successfully';

  @override
  String get settingsAutoConnectPickServer => 'Server';

  @override
  String get settingsAutoConnectNoServer => 'No server selected yet';

  @override
  String get sftpSort => 'Sort';

  @override
  String get sftpSortName => 'Name';

  @override
  String get sftpSortSize => 'Size';

  @override
  String get sftpSortDate => 'Date modified';

  @override
  String get sftpSortAscending => 'Ascending';

  @override
  String get sftpSortDescending => 'Descending';

  @override
  String get themeQuickSwitch => 'Theme';

  @override
  String get transferList => 'Transfers';

  @override
  String get transferEmpty => 'No transfers yet';

  @override
  String get transferUpload => 'Upload';

  @override
  String get transferDownload => 'Download';

  @override
  String get transferStatusQueued => 'Queued';

  @override
  String get transferStatusRunning => 'Transferring';

  @override
  String get transferStatusPaused => 'Paused';

  @override
  String get transferStatusCompleted => 'Completed';

  @override
  String get transferStatusFailed => 'Failed';

  @override
  String get transferStatusCanceled => 'Canceled';

  @override
  String get transferPause => 'Pause';

  @override
  String get transferResume => 'Resume';

  @override
  String get transferCancel => 'Cancel';

  @override
  String get transferRemove => 'Remove';

  @override
  String get transferClearFinished => 'Clear finished';

  @override
  String get transferSizeUnknown => 'Size unknown';

  @override
  String get transferFailedUpload => 'Upload failed';

  @override
  String get transferFailedDownload => 'Download failed';

  @override
  String get stopGeneration => 'Stop';

  @override
  String get chatServerBindingRequired =>
      'This session is not bound to a server. Please bind it to the current server to continue.';

  @override
  String get chatSessionUnboundNotice =>
      'This session is not bound to any server.';

  @override
  String get bindServerAction => 'Bind Server';

  @override
  String get bindServerDialogTitle => 'Bind Session to Server';

  @override
  String get bindServerConfirmAction => 'Confirm Bind';

  @override
  String get chatSessionIdentityMismatch =>
      'Current server or agent does not match this session\'s bound identity. Switch to the matching server and agent to continue.';

  @override
  String get deleteSessionTitle => 'Delete Session';

  @override
  String get deleteSessionConfirmAction => 'Delete';

  @override
  String get shareAgentSessionsTitle => 'Share Agent Sessions';

  @override
  String get shareAgentSessionsSubtitle =>
      'Share sessions across different agents on this server';

  @override
  String get shareAgentSessionsEnabled => 'Agent session sharing enabled';

  @override
  String get shareAgentSessionsDisabled => 'Agent session sharing disabled';

  @override
  String get agentCliStatusInstalled => 'CLI: Installed';

  @override
  String get agentCliStatusMissing => 'CLI: Missing';

  @override
  String get agentCliStatusChecking => 'CLI: Checking...';

  @override
  String get agentCliStatusUnknown => 'CLI: Unknown';

  @override
  String get agentCliStatusError => 'CLI: Error';

  @override
  String get agentAcpStatusReady => 'ACP: Ready';

  @override
  String get agentAcpStatusMissing => 'ACP: Missing';

  @override
  String get agentAcpStatusChecking => 'ACP: Checking...';

  @override
  String get agentAcpStatusPendingCli => 'ACP: Pending CLI';

  @override
  String get agentAcpStatusUnknown => 'ACP: Unknown';

  @override
  String get agentAcpStatusError => 'ACP: Error';

  @override
  String get agentAcpStatusNa => 'ACP: N/A';

  @override
  String get agentAuthStatusAuthenticated => 'Auth: Logged In';

  @override
  String get agentAuthStatusUnauthenticated => 'Auth: Not Logged In';

  @override
  String get agentAuthStatusUnknown => 'Auth: Unknown';

  @override
  String get downloadNotificationsUnavailable =>
      'System download notifications are unavailable. Downloads continue in background.';

  @override
  String get downloadOpenFailed => 'Failed to open downloaded file.';

  @override
  String get dockerActionPending =>
      'An action is already in progress for this container';

  @override
  String get dockerNoLogs => '(No logs)';

  @override
  String get serverReboot => 'Reboot';

  @override
  String get serverRebootDialogTitle => 'Confirm Server Reboot';

  @override
  String get serverRebootDialogMessage =>
      'Are you sure you want to reboot this server? All active connections and background services will be terminated.';

  @override
  String get serverRebootConfirmButton => 'Reboot Now';

  @override
  String get serverRebootPasswordTitle => 'Sudo Password Required';

  @override
  String get serverRebootPasswordMessage =>
      'Root privileges are required to reboot the server. Please enter the sudo password (used once, not saved):';

  @override
  String get serverRebootPasswordHint => 'Sudo Password';

  @override
  String get serverRebootSubmitting => 'Sending reboot command...';

  @override
  String get serverRebootAccepted =>
      'Reboot command accepted; completion not yet verified. Please reconnect when the server is back online.';

  @override
  String get serverRebootVerified =>
      'Server reboot has been verified; the system is back online.';

  @override
  String get serverRebootUnknown =>
      'Reboot result is uncertain. The command was dispatched, but completion could not be confirmed. Please check the connection manually.';

  @override
  String get serverRebootReconnect => 'Reconnect';

  @override
  String get serverRebootServerChanged =>
      'Target server changed, reboot cancelled';

  @override
  String get navCliChat => 'CLI Chat';

  @override
  String get cliChatTitle => 'CLI Sessions';

  @override
  String get cliChatSubtitle => 'Native CLI Agent sessions on remote server';

  @override
  String get cliSelectAgent => 'Select Agent';

  @override
  String get cliNoAgentsConfigured => 'No agents added for this server';

  @override
  String get cliAgentNeedsSetup => 'Agent environment missing or not logged in';

  @override
  String get cliManageAgentsGuide => 'Configure in Agent Management';

  @override
  String get cliNewDraft => 'New Draft';

  @override
  String get cliNewDraftTooltip =>
      'Create a blank draft (session created on first message)';

  @override
  String get cliDeleteSessionTitle => 'Delete Remote CLI Session History';

  @override
  String get cliDeleteSessionMessage =>
      'This will permanently delete the CLI session history on the remote server. Are you sure you want to proceed?';

  @override
  String get cliDeleteConfirmButton => 'Delete Session';

  @override
  String get cliCannotDeleteTooltip =>
      'Remote session deletion not supported or disabled';

  @override
  String get cliSessionsHeader => 'Sessions';

  @override
  String get cliNoSessions => 'No CLI sessions found';

  @override
  String get cliFilterCwdHint => 'Filter by CWD path...';

  @override
  String get cliFilterCwdAction => 'Filter';

  @override
  String get cliClearCwdAction => 'Clear';

  @override
  String get cliLoadMoreSessions => 'Load More Sessions';

  @override
  String get cliRefreshSessions => 'Refresh';

  @override
  String get cliClaudeReadOnlyNotice =>
      'Claude history is read-only. Continue the conversation in real terminal.';

  @override
  String get cliContinueInTerminal => 'Continue in Terminal';

  @override
  String get cliOpenTerminal => 'Open Terminal';

  @override
  String get cliCloseTerminal => 'Close Terminal';

  @override
  String get cliTerminalRunning => 'Interactive CLI Terminal';

  @override
  String get cliAgyTerminalOnlyNotice =>
      'This agent does not support structured history synchronization. Please use the native CLI terminal for interaction and session selection.';

  @override
  String get cliInstallSdkTitle => 'Install Official Claude History SDK';

  @override
  String get cliInstallSdkMessage =>
      'The official Claude Code History SDK is missing on the remote server. Would you like to install it now?';

  @override
  String get cliInstallSdkAction => 'Install Official SDK';

  @override
  String get cliApprovalsTitle => 'Pending Approvals';

  @override
  String get cliApprovalDetails => 'Details';

  @override
  String get cliApprovalAllow => 'Allow';

  @override
  String get cliApprovalDecline => 'Decline';

  @override
  String get cliInputHint => 'Type a message to the CLI agent...';

  @override
  String get cliSend => 'Send';

  @override
  String get cliStop => 'Stop';

  @override
  String get cliBusy => 'Operation is in progress, please wait...';

  @override
  String get cliDisconnected => 'SSH is not connected';

  @override
  String get cliServerChanged => 'Target server changed';

  @override
  String get cliTurnFailed => 'CLI turn execution failed';

  @override
  String get cliUseTerminal =>
      'Interactive prompt required, please open terminal to continue';

  @override
  String get cliDeleteFailed => 'Failed to delete remote session';

  @override
  String get cliDeleteUnsupported =>
      'Deleting remote sessions is not supported by this CLI';

  @override
  String get cliOperationFailed => 'CLI operation failed';

  @override
  String get cliHistorySdkMissing =>
      'Official History SDK is missing on the server';

  @override
  String get cliHistoryRuntimeMissing =>
      'Claude history requires Node.js/npm on the server. Please install Node.js manually; you can still use the real CLI in terminal.';

  @override
  String get cliLoginRequired =>
      'Agent login required. Please log in via Agent Management.';

  @override
  String get cliNotInstalled =>
      'Agent CLI not installed. Please install it via Agent Management.';

  @override
  String get cliVersionUnsupported =>
      'Agent CLI version is unsupported. Please upgrade or reinstall via Agent Management.';

  @override
  String get settingsNavigation => 'Navigation';

  @override
  String get settingsNavigationDesc =>
      'Configure default startup page and bottom navigation bar';

  @override
  String get settingsStartupPage => 'Startup Page';

  @override
  String get settingsStartupPageDesc => 'Page displayed when app opens';

  @override
  String get settingsBottomNav => 'Bottom Navigation Bar';

  @override
  String get settingsBottomNavDesc =>
      'Select sections to display in mobile bottom bar (supports 0 to 9 items)';

  @override
  String get settingsResetSuccess => 'All settings restored to defaults';

  @override
  String get metricsTrendSubtitle => 'Last ~3 minutes (up to 60 samples)';

  @override
  String get metricsCurrent => 'Current';

  @override
  String get metricsPeak => 'Peak';

  @override
  String get metricsValley => 'Valley';

  @override
  String get metricsTrendWaiting => 'Collecting metrics data...';

  @override
  String get metricsTrendStopped =>
      'Data collection stopped (SSH disconnected)';

  @override
  String get dockerActionTerminal => 'Exec Terminal';

  @override
  String get dockerTerminalTitle => 'Container Terminal';

  @override
  String get dockerTerminalNotRunning => 'Container is not running';

  @override
  String get setDefaultAgent => 'Set as default';

  @override
  String get defaultBadge => 'Default';

  @override
  String get isDefaultAgent => 'Default Agent';

  @override
  String get setAsDefaultAgent => 'Set as default agent for this server';

  @override
  String get agentGroupBasic => 'Basic Information';

  @override
  String get agentGroupCommands => 'Commands';

  @override
  String get agentGroupAuth => 'Install & Authentication';

  @override
  String get agentPresetTitle => 'Preset Template';

  @override
  String get resourceProcessList => 'Processes';

  @override
  String get resourceDiskScanning =>
      'Scanning root directories, this may take a few seconds...';

  @override
  String get resourceDiskScanPartial =>
      'Some directories could not be scanned due to permissions or timeout';

  @override
  String get resourceDiskDirectories => 'Top-level Directory Usage';

  @override
  String get resourceSortCpu => 'Sort by CPU';

  @override
  String get resourceSortMemory => 'Sort by Memory';

  @override
  String get resourceRss => 'RSS Memory';

  @override
  String get resourceUsed => 'Used';

  @override
  String get resourceAvailable => 'Available';

  @override
  String get resourceTotal => 'Total';

  @override
  String get settingsBottomNavOrderTitle => 'Selected Items (Drag to reorder)';

  @override
  String get langSystem => 'System Default';

  @override
  String get serverFieldRequired => 'Required';

  @override
  String get serverPortInvalid => 'Port must be between 1 and 65535';

  @override
  String get serverTestReachability => 'Test Reachability';

  @override
  String get serverSaveFailedGeneric =>
      'Failed to save server. Please check your configuration and try again.';

  @override
  String get serverViewPrivateKey => 'View Private Key';

  @override
  String get serverHidePrivateKey => 'Hide Private Key';

  @override
  String get dockerBashFallbackNotice =>
      'Bash is unavailable in container, fallback to Sh';

  @override
  String get dockerShellLabel => 'Shell';

  @override
  String get dockerShellBash => 'Bash';

  @override
  String get dockerShellSh => 'Sh';

  @override
  String get cliDraftWorkingDirLabel => 'Working Directory';

  @override
  String get cliDefaultWorkingDir => 'Default (/)';

  @override
  String get cliPickWorkingDirTitle => 'Select Working Directory';

  @override
  String get cliClearWorkingDir => 'Reset to Default';

  @override
  String get cliBrowseWorkingDir => 'Browse';

  @override
  String get cliSelectCurrentDir => 'Select This Directory';

  @override
  String get cliNavigateUp => 'Go up';

  @override
  String get chatSessionsTooltip => 'Sessions';

  @override
  String get hardwareSpecsTitle => 'Hardware & System';

  @override
  String get hardwareCpu => 'CPU';

  @override
  String get hardwareMemory => 'Memory';

  @override
  String get hardwareDisk => 'Root Disk';

  @override
  String get hardwareDistribution => 'OS';

  @override
  String get hardwareKernel => 'Kernel';

  @override
  String get hardwareLoading => 'Loading hardware specs...';

  @override
  String get hardwareUnavailable => 'Hardware specs unavailable';

  @override
  String get hardwareUnknown => 'Unknown';

  @override
  String get systemInfoTitle => 'System Info';

  @override
  String get systemInfoTapHint => 'Tap to view ASCII art';

  @override
  String get systemInfoHost => 'Host';

  @override
  String get serverShutdown => 'Shutdown';

  @override
  String get serverShutdownDialogTitle => 'Confirm Server Shutdown';

  @override
  String get serverShutdownDialogMessage =>
      'Are you sure you want to shut down this server? The system will be powered off completely and cannot be accessed remotely until powered on manually.';

  @override
  String get serverShutdownConfirmButton => 'Shut Down Now';

  @override
  String get serverShutdownSubmitting => 'Sending shutdown command...';

  @override
  String get serverShutdownAccepted =>
      'Shutdown command accepted; shutdown completion has not been verified.';

  @override
  String get serverShutdownUnknown =>
      'Shutdown result unknown: The command may have been sent but cannot be confirmed. Please check manually; it will not be retried automatically.';

  @override
  String get serverShutdownPasswordTitle =>
      'Sudo Password Required for Shutdown';

  @override
  String get serverShutdownPasswordMessage =>
      'Root privileges are required to shut down the server. Please enter the sudo password (used once, not saved):';

  @override
  String get serverShutdownPasswordHint => 'Sudo Password';

  @override
  String get serverShutdownServerChanged =>
      'Target server changed, shutdown cancelled';

  @override
  String get metricsNetwork => 'Network Rate';

  @override
  String get networkModalTitle => 'Network Interfaces Details';

  @override
  String get networkDownloadRate => 'Download (RX)';

  @override
  String get networkUploadRate => 'Upload (TX)';

  @override
  String get networkTotalRx => 'Total RX';

  @override
  String get networkTotalTx => 'Total TX';

  @override
  String get networkPrimary => 'Default Route';

  @override
  String get networkRatesEmpty => 'No active network interfaces detected';

  @override
  String get networkWaitingSecondSample => 'Waiting for second sample';

  @override
  String get networkUnavailable => 'Unavailable';

  @override
  String get networkNoDefaultInterface => 'No default route';

  @override
  String get selectThemeModeTitle => 'Select Theme Mode';

  @override
  String get selectLanguageTitle => 'Select Language';

  @override
  String get selectStartupPageTitle => 'Select Startup Page';

  @override
  String get selectAutoConnectModeTitle => 'Select Auto-connect Mode';

  @override
  String get accentColorDialogTitle => 'Customize Accent Colors';

  @override
  String get accentColorLightMode => 'Light Mode';

  @override
  String get accentColorDarkMode => 'Dark Mode';

  @override
  String get accentColorAmoledMode => 'AMOLED (Geek)';

  @override
  String get accentColorPresets => 'Presets';

  @override
  String get accentColorHsvPicker => 'Color Wheel';

  @override
  String get accentColorHexCode => 'Hex Color';

  @override
  String get accentColorPreview => 'Preview';

  @override
  String get accentColorSampleButton => 'Accent Button';

  @override
  String get accentColorInvalidHex => 'Invalid hex format (e.g. #10B981)';

  @override
  String get settingsDashboardQuickActions => 'Dashboard Quick Actions';

  @override
  String get settingsDashboardQuickActionsDesc =>
      'Configure quick shortcut entries shown on the dashboard. Clearing will hide the quick actions section.';

  @override
  String get settingsDashboardQuickActionsEmpty =>
      'Quick actions hidden (no shortcuts selected)';

  @override
  String get settingsDashboardQuickActionsOrderTitle =>
      'Drag to Reorder Shortcuts';

  @override
  String get settingsDashboardQuickActionsCandidates =>
      'Select Visible Shortcuts';

  @override
  String get terminalCopySelection => 'Copy';

  @override
  String get terminalSelectionCopied => 'Selection copied to clipboard';

  @override
  String get editAgent => 'Edit Agent';

  @override
  String get agentExecutionTarget => 'Execution Environment';

  @override
  String get agentExecutionHost => 'Host System';

  @override
  String get agentExecutionDocker => 'Docker Container';

  @override
  String get agentContainerBinding => 'Container Binding Mode';

  @override
  String get agentContainerBindingId => 'By Container ID';

  @override
  String get agentContainerBindingName => 'By Container Name';

  @override
  String get agentContainerReference => 'Target Container';

  @override
  String get agentContainerReferenceHint =>
      'Select or enter container ID or name';

  @override
  String get agentContainerRequired =>
      'Target container is required for Docker execution';

  @override
  String get agentLoadingContainers => 'Querying containers on server...';

  @override
  String get agentNoContainersFound => 'No containers found on this server';

  @override
  String get agentContainerUser => 'Container Execution User (Optional)';

  @override
  String get agentContainerUserHint => 'e.g. dev';

  @override
  String get agentContainerUserHelper =>
      'Leave empty to use image default user; e.g. dev; supports user, UID, user:group, UID:GID';

  @override
  String get agentContainerUserSelect => 'Select container user';

  @override
  String get agentContainerUsersLoading => 'Loading users...';

  @override
  String get agentContainerUsersEmpty => 'No passwd users found';

  @override
  String get agentViewDiagnosticLog => 'View Diagnostic Log';

  @override
  String get agentDiagnosticLogCopied => 'Diagnostic log copied to clipboard';

  @override
  String get agentDiagnosticLogCopy => 'Copy';

  @override
  String get agentDiagnosticLogClose => 'Close';

  @override
  String get settingsCliHistoryPageSize => 'CLI History Page Size';

  @override
  String get settingsCliHistoryPageSizeDesc =>
      'Number of older messages loaded per page when scrolling up (5-100)';

  @override
  String get settingsCliHistoryPageSizeTitle => 'Select CLI History Page Size';

  @override
  String get cliLoadingOlderMessages => 'Loading older messages...';

  @override
  String get chatLoadOlderMessages => 'Load earlier messages';

  @override
  String get chatCommandsTooltip => 'Commands';

  @override
  String get chatAttachTooltip => 'Attach file';

  @override
  String get chatAttachImage => 'Attach local image';

  @override
  String get chatAttachLocalText => 'Attach local text file';

  @override
  String get chatAttachRemoteText => 'Attach remote text file';

  @override
  String get chatAttachRemotePathTitle => 'Attach Remote Text File';

  @override
  String get chatAttachRemotePathHint => '/path/to/file.txt';

  @override
  String get chatAttachTooLarge => 'File exceeds size limit';

  @override
  String get chatUsageAndDiagnostics => 'Usage & Diagnostics';

  @override
  String get chatWorkingDirTooltip => 'Draft Working Directory';

  @override
  String get chatAttachFailed => 'Failed to attach file';

  @override
  String get chatInvalidRemotePath =>
      'Invalid remote file path (must start with /)';

  @override
  String get chatRemoteReadFailed => 'Failed to read remote file';

  @override
  String get chatInvalidDirPath => 'Invalid directory path (must start with /)';

  @override
  String get chatNoSubdirectories => 'No subdirectories';

  @override
  String get chatUsageTitle => 'Token & Cost Usage';

  @override
  String get chatUsageUsed => 'Tokens Used';

  @override
  String get chatUsageSize => 'Context Size';

  @override
  String get chatUsageCost => 'Cost';

  @override
  String get chatDiagnosticsTitle => 'Diagnostics Log';

  @override
  String get chatNoDiagnostics => 'No diagnostic logs available';

  @override
  String get deleteSessionLocalOnlyNotice =>
      'This only removes the local record in Valhalla and will not delete native agent session history on the server.';

  @override
  String get chatSearchSessionsHint => 'Search sessions...';

  @override
  String get chatLoadMoreSessions => 'Load more sessions';

  @override
  String get chatLoadingMoreSessions => 'Loading more sessions...';

  @override
  String get chatExportSession => 'Export Session (Markdown)';

  @override
  String get chatExportSuccess => 'Session exported successfully';

  @override
  String get chatExportFailed => 'Failed to export session';

  @override
  String get chatRemoteSessions => 'Remote Sessions';

  @override
  String get chatRemoteSessionsTitle => 'Remote Agent Sessions';

  @override
  String get chatRemoteSessionsDesc =>
      'View and import native session history from the remote agent';

  @override
  String get chatRemoteSessionsEmpty => 'No remote sessions found';

  @override
  String get chatRemoteImporting => 'Importing remote session history...';

  @override
  String get chatRemoteImportFailed => 'Failed to import remote session';

  @override
  String get chatStatusInterrupted => 'Interrupted';

  @override
  String get chatStatusFailed => 'Failed';

  @override
  String get chatStatusAwaitingAuth => 'Awaiting ACP Authentication';

  @override
  String get chatShowFullOutput => 'Show full output';

  @override
  String get chatShowLessOutput => 'Show less';

  @override
  String get chatToolLocations => 'Affected paths';

  @override
  String cmdParamPlaceholder(String param) {
    return 'Enter value for $param';
  }

  @override
  String processTerminateSuccess(Object pid) {
    return 'Process $pid terminated';
  }

  @override
  String serviceActionSuccess(Object action, Object service) {
    return 'Action $action on $service succeeded';
  }

  @override
  String riskPatternMatched(Object pattern) {
    return 'Triggered rule: $pattern';
  }

  @override
  String stateExitCode(Object code) {
    return 'Exit Code: $code';
  }

  @override
  String sshConnectedSuccess(Object server) {
    return 'Successfully connected to $server via SSH';
  }

  @override
  String sshConnectionFailed(Object error) {
    return 'SSH connection failed: $error';
  }

  @override
  String trustHostFingerprintMessage(
    Object fingerprint,
    Object host,
    Object type,
  ) {
    return 'Connecting to $host ($type) for the first time.\n\nSHA-256 Fingerprint:\n$fingerprint\n\nTrust this fingerprint and connect?';
  }

  @override
  String enterPasswordTitle(Object server) {
    return 'Enter password for $server';
  }

  @override
  String confirmDeleteServerMessage(Object name) {
    return 'Are you sure you want to delete server \'$name\'? This action cannot be undone.';
  }

  @override
  String deleteAgentMessage(Object name) {
    return 'Are you sure you want to delete Agent \'$name\'? This removes its configuration and runtime state on this server without affecting historical chat sessions or SSH credentials.';
  }

  @override
  String agentLastChecked(Object time) {
    return 'Last checked: $time';
  }

  @override
  String agentAuthPickerTitle(Object agent) {
    return 'Choose how to log in to $agent';
  }

  @override
  String sshStatusReconnecting(Object n) {
    return 'Reconnecting… (attempt $n)';
  }

  @override
  String sshKeepAliveNotificationBody(Object n) {
    return '$n active session(s)';
  }

  @override
  String bindServerConfirmMessage(Object serverName) {
    return 'Bind this session to server \\\"$serverName\\\"? Once bound, this session will be associated with this server.';
  }

  @override
  String deleteSessionConfirmMessage(Object title) {
    return 'Are you sure you want to delete session \\\"$title\\\"? This action cannot be undone.';
  }

  @override
  String dockerActionSuccess(Object action, Object name) {
    return 'Container $name $action succeeded';
  }

  @override
  String dockerActionFailed(Object error) {
    return 'Action failed: $error';
  }

  @override
  String serverRebootTarget(Object address, Object name) {
    return 'Target Server: $name ($address)';
  }

  @override
  String serverRebootRunningTerminals(Object count) {
    return 'Terminal Sessions: $count';
  }

  @override
  String serverRebootRunningAgents(Object count) {
    return 'Agent Sessions: $count';
  }

  @override
  String serverRebootRunningTransfers(Object count) {
    return 'Active Transfers: $count';
  }

  @override
  String serverRebootFailed(Object error) {
    return 'Reboot failed: $error';
  }

  @override
  String cliDeleteFailedWithDetail(Object detail) {
    return 'Failed to delete remote session: $detail';
  }

  @override
  String metricsTrendTitle(Object metric) {
    return '$metric Trend';
  }

  @override
  String metricsThresholdWarning(Object value) {
    return 'Warning: $value';
  }

  @override
  String metricsThresholdDanger(Object value) {
    return 'Danger: $value';
  }

  @override
  String metricsHistoryPoints(Object count) {
    return '$count data points';
  }

  @override
  String resourceUsageTitle(Object metric) {
    return '$metric Resource Usage';
  }

  @override
  String serverPortReachable(Object port) {
    return 'TCP port $port reachable';
  }

  @override
  String serverConnectionFailed(Object error) {
    return 'Connection failed: $error';
  }

  @override
  String serverSaveFailed(Object error) {
    return 'Failed to save server: $error';
  }

  @override
  String hardwareCpuCores(Object cores) {
    return '$cores Cores';
  }

  @override
  String serverShutdownFailed(Object error) {
    return 'Shutdown failed: $error';
  }

  @override
  String networkInterface(Object name) {
    return 'Interface: $name';
  }

  @override
  String agentContainersLoadFailed(Object error) {
    return 'Failed to load containers: $error';
  }

  @override
  String agentContainerUsersFailed(Object error) {
    return 'Failed to load container users: $error';
  }

  @override
  String agentDiagnosticLogTitle(Object name) {
    return 'Diagnostic Log - $name';
  }

  @override
  String get agentDockerDetectionFailed => 'Docker/container detection failed';

  @override
  String get chatCopiedAllMessages => 'All messages copied';

  @override
  String get chatCopyAllMessages => 'Copy all messages';

  @override
  String get cliModelAtCapacity =>
      'Selected model is at capacity. Try another model.';

  @override
  String get chatLaunchBlankDraft => 'Blank draft';

  @override
  String get chatLaunchFixedSession => 'Fixed session';

  @override
  String get chatLaunchRememberLast => 'Remember last session';

  @override
  String get chatPermissionAskEveryTime => 'Ask every time';

  @override
  String get chatPermissionAutoAllowAll => 'Allow all automatically';

  @override
  String get chatPermissionAutoAllowAllConfirmMessage =>
      'The agent will execute all operations without asking. Continue?';

  @override
  String get chatPermissionAutoAllowAllConfirmTitle => 'Allow all operations?';

  @override
  String get chatPermissionAutoAllowSafe =>
      'Automatically allow safe operations';

  @override
  String get chatRunSettingsDefault => 'Default';

  @override
  String get chatRunSettingsInteractiveCli => 'Interactive CLI';

  @override
  String get chatRunSettingsModel => 'Model';

  @override
  String get chatRunSettingsPermissions => 'Permissions';

  @override
  String get chatRunSettingsReasoning => 'Reasoning level';

  @override
  String get chatRunSettingsTitle => 'Run settings';

  @override
  String get cliActionInsertCommand => 'Insert command';

  @override
  String get cliActionInsertFile => 'Insert file';

  @override
  String get cliActionInsertWorkdir => 'Insert working directory';

  @override
  String get cliComposerInsertAction => 'Insert';

  @override
  String cliOperationFailedWithDetail(String detail) {
    return 'CLI operation failed: $detail';
  }

  @override
  String get cliSelectCommandTitle => 'Select command';

  @override
  String get defaultAgentTitle => 'Default agent';

  @override
  String get insertSkills => 'Insert skills';

  @override
  String get isDefaultSession => 'Default session';

  @override
  String get sessionLaunchMode => 'Session launch mode';

  @override
  String get setAsDefaultSession => 'Set as default session';

  @override
  String get navNas => 'NAS Media';

  @override
  String get nasAddExcludePath => 'Add excluded path';

  @override
  String get nasAddIncludePath => 'Add scan path';

  @override
  String get nasCancelScan => 'Cancel scan';

  @override
  String get nasClearSearch => 'Clear search';

  @override
  String get nasConfigDialogTitle => 'Media library settings';

  @override
  String get nasConfigure => 'Configure';

  @override
  String get nasConfigureScanDirs => 'Configure scan folders';

  @override
  String get nasCreatePlaylist => 'Create playlist';

  @override
  String get nasEmptyConfigDesc =>
      'Add at least one folder to start building your media library.';

  @override
  String get nasEmptyConfigTitle => 'No scan folders configured';

  @override
  String get nasExcludePaths => 'Excluded folders';

  @override
  String get nasExcludedBadge => 'Excluded';

  @override
  String get nasFilterImages => 'Images';

  @override
  String get nasFilterVideos => 'Videos';

  @override
  String get nasIncludePaths => 'Scan folders';

  @override
  String nasItemCount(Object value) {
    return '$value items';
  }

  @override
  String nasLastScan(Object value) {
    return 'Last scan: $value';
  }

  @override
  String get nasLibrarySettings => 'Library settings';

  @override
  String nasMediaOpening(Object value) {
    return 'Opening $value…';
  }

  @override
  String get nasMiniPlayer => 'Mini player';

  @override
  String get nasNoExcludePaths => 'No excluded folders';

  @override
  String get nasNoFavorites => 'No favorites yet';

  @override
  String get nasNoIncludePaths => 'No scan folders';

  @override
  String get nasNoIndexDesc =>
      'Configure folders and run a scan to index your media.';

  @override
  String get nasNoIndexTitle => 'Media library is empty';

  @override
  String get nasNoPlaylists => 'No playlists yet';

  @override
  String get nasNoSearchResults => 'No matching media';

  @override
  String get nasNotScanned => 'Not scanned yet';

  @override
  String get nasNowPlaying => 'Now playing';

  @override
  String get nasOpenMethodPrompt => 'How would you like to open this file?';

  @override
  String get nasOpenPolicyAsk => 'Ask every time';

  @override
  String get nasOpenPolicyExternal => 'Open with another app';

  @override
  String get nasOpenPolicyInApp => 'Open in app';

  @override
  String get nasOpeningPolicy => 'Default open method';

  @override
  String get nasPlaylistName => 'Playlist name';

  @override
  String get nasQuickStats => 'Library overview';

  @override
  String get nasScan => 'Scan now';

  @override
  String get nasScanCancelled => 'Scan cancelled';

  @override
  String nasScanFailed(Object value) {
    return 'Scan failed: $value';
  }

  @override
  String get nasScanning => 'Scanning…';

  @override
  String get nasScopeBadge => 'Scan scope';

  @override
  String get nasSearchHint => 'Search media';

  @override
  String get nasStatMusic => 'Music';

  @override
  String get nasStatPhotos => 'Photos';

  @override
  String get nasStatTotal => 'Total';

  @override
  String get nasStatVideos => 'Videos';

  @override
  String get nasTabFavorites => 'Favorites';

  @override
  String get nasTabFolders => 'Folders';

  @override
  String get nasTabHome => 'Home';

  @override
  String get nasTabMusic => 'Music';

  @override
  String get nasTabPhotos => 'Photos';

  @override
  String get nasTabPlaylists => 'Playlists';

  @override
  String get nasTabVideos => 'Videos';

  @override
  String get nasSources => 'Media sources';

  @override
  String get nasAddSource => 'Add media source';

  @override
  String get nasEditSource => 'Edit media source';

  @override
  String get nasRemoveSource => 'Remove media source';

  @override
  String nasRemoveSourceConfirm(Object name) {
    return 'Are you sure you want to remove media source \'$name\'? This removes its configuration without deleting remote files.';
  }

  @override
  String get nasNoSources => 'No media sources configured';

  @override
  String get nasNoSourcesDesc =>
      'Add SFTP, SMB, WebDAV, Jellyfin, or Emby to start browsing media.';

  @override
  String get nasSourceType => 'Source type';

  @override
  String get nasSourceName => 'Source name';

  @override
  String get nasProbe => 'Test connection';

  @override
  String get nasProbeSuccess => 'Connection successful';

  @override
  String get nasProbeFailed => 'Connection test failed';

  @override
  String get nasEndpoint => 'Endpoint / URL';

  @override
  String get nasRootPath => 'Root path';

  @override
  String get nasUsername => 'Username';

  @override
  String get nasPassword => 'Password';

  @override
  String get nasDomain => 'Domain (optional)';

  @override
  String get nasAuthenticate => 'Authenticate';

  @override
  String get nasAuthSuccess => 'Authentication successful';

  @override
  String get nasAuthFailed => 'Authentication failed';

  @override
  String get nasTabDownloads => 'Downloads';

  @override
  String get nasNoDownloads => 'No download tasks';

  @override
  String get nasDownloadQueued => 'Queued';

  @override
  String get nasDownloadDownloading => 'Downloading';

  @override
  String get nasDownloadCompleted => 'Completed';

  @override
  String get nasDownloadCancelled => 'Cancelled';

  @override
  String get nasDownloadFailed => 'Download failed';

  @override
  String get nasRetryDownload => 'Retry';

  @override
  String get nasCancelDownload => 'Cancel';

  @override
  String get nasOpenDownloadedFile => 'Open file';

  @override
  String get nasQueue => 'Play queue';

  @override
  String get nasNoQueue => 'Queue is empty';

  @override
  String get nasSpeed => 'Speed';

  @override
  String get nasQuality => 'Quality';

  @override
  String get nasAudioTrack => 'Audio track';

  @override
  String get nasSubtitleTrack => 'Subtitles';

  @override
  String get nasRepeatOff => 'Repeat off';

  @override
  String get nasRepeatAll => 'Repeat all';

  @override
  String get nasRepeatOne => 'Repeat one';

  @override
  String get nasShuffle => 'Shuffle';

  @override
  String get nasCast => 'Cast';

  @override
  String get nasCastUnavailable => 'No cast devices available';

  @override
  String get nasSlideshow => 'Slideshow';

  @override
  String get nasByFolder => 'Folders';

  @override
  String get nasByArtist => 'Artists';

  @override
  String get nasByAlbum => 'Albums';

  @override
  String get nasAllTracks => 'All tracks';

  @override
  String get nasPlayAll => 'Play all';

  @override
  String get nasPreviousPage => 'Previous';

  @override
  String get nasNextPage => 'Next';

  @override
  String get nasClearScope => 'Back to all';

  @override
  String get nasRenamePlaylist => 'Rename playlist';

  @override
  String get nasRemoveFromPlaylist => 'Remove from playlist';

  @override
  String get nasMoveUp => 'Move up';

  @override
  String get nasMoveDown => 'Move down';

  @override
  String get nasSshServer => 'SSH server';

  @override
  String get nasSelectSshServer => 'Select saved SSH server';

  @override
  String get nasQualityOriginal => 'Original';

  @override
  String get nasQualityAuto => 'Auto';

  @override
  String get nasQuality4Mbps => '4 Mbps';

  @override
  String get nasQuality10Mbps => '10 Mbps';

  @override
  String get nasQuality20Mbps => '20 Mbps';

  @override
  String get nasCastDevices => 'Available DLNA Devices';

  @override
  String get nasCastDiscovering => 'Searching for DLNA devices...';

  @override
  String get nasCastRelayingNotice =>
      'Relaying stream via foreground app. Keep Valhalla open.';

  @override
  String get nasCastStop => 'Stop Casting';

  @override
  String get nasCastVolume => 'Volume';

  @override
  String get nasCastRetry => 'Retry Search';

  @override
  String get nasInstallTitle => 'Deploy NAS Media Server';

  @override
  String get nasInstallProduct => 'Product';

  @override
  String get nasInstallMediaPath => 'Media Directory (Read-Only)';

  @override
  String get nasInstallDataRoot => 'Data & Config Directory';

  @override
  String get nasInstallPort => 'Port';

  @override
  String get nasInstallBindAddress => 'Bind Address';

  @override
  String get nasInstallWebdavUser => 'WebDAV Username';

  @override
  String get nasInstallWebdavPassword => 'WebDAV Password (min 12 chars)';

  @override
  String get nasInstallPreparePlan => 'Review Deployment Plan';

  @override
  String get nasInstallPlanTitle => 'Technical Review & Confirmation';

  @override
  String get nasInstallBlockersTitle => 'Deployment Blockers';

  @override
  String get nasInstallConfirmDeploy => 'Confirm & Install';

  @override
  String get nasInstallDeploying => 'Deploying container...';

  @override
  String get nasInstallSuccess => 'Deployed Successfully';

  @override
  String get nasInstallSuccessDesc =>
      'Service is now running. Complete server initial setup before adding it as a media source.';

  @override
  String get nasInstallContainerId => 'Container ID';

  @override
  String get nasInstallEndpoint => 'Endpoint';

  @override
  String get nasUseSshTunnel => 'Use SSH Tunnel';

  @override
  String get nasUseSshTunnelDesc =>
      'Route traffic through a saved SSH server (e.g. http://127.0.0.1:8096)';

  @override
  String get nasSshTunnelHint =>
      'Endpoint should be accessible from the SSH server, e.g. http://127.0.0.1:8096';

  @override
  String get nasKeepEmptyPassword =>
      'Leave blank to keep existing password / token';

  @override
  String get nasSourceNameRequired => 'Source name is required';

  @override
  String get nasInvalidEndpoint => 'Invalid endpoint URL or scheme';

  @override
  String get nasSourceUnreachable => 'Unable to reach media source';

  @override
  String get nasSshTunnelFailed => 'SSH tunnel connection failed';

  @override
  String get nasOperationFailed => 'Operation failed';

  @override
  String get nasInstallStepCreateDir => 'Create private directory';

  @override
  String get nasInstallStepWriteCompose =>
      'Write docker-compose.json configuration';

  @override
  String get nasInstallStepWriteCreds => 'Write private credentials';

  @override
  String get nasInstallStepPullImage => 'Pull pinned container image';

  @override
  String get nasInstallStepStartService => 'Start containerized service';

  @override
  String get nasInstallStepCheckHttp => 'Check service HTTP health';

  @override
  String get nasInstallBlockerDocker =>
      'Docker Engine is required on target server';

  @override
  String get nasInstallBlockerCompose => 'Docker Compose plugin is required';

  @override
  String get nasInstallBlockerIdentity =>
      'Target server identity could not be verified';

  @override
  String get nasInstallBlockerTools =>
      'Required tools (curl, ss, realpath) are missing on target server';

  @override
  String get nasInstallBlockerMedia =>
      'Media directory does not exist or is not readable';

  @override
  String get nasInstallBlockerParent =>
      'Data root parent directory is not writable';

  @override
  String get nasInstallBlockerOverlap =>
      'Media directory and data directory cannot overlap';

  @override
  String get nasInstallBlockerCollision =>
      'Target data directory already exists or is a symlink';

  @override
  String get nasInstallBlockerPort =>
      'Selected port is already in use on target server';

  @override
  String get nasInstallBlockerContainer =>
      'A container with this project name already exists';

  @override
  String get nasInstallBlockerImage =>
      'Failed to verify container image. Check image name, network connectivity, and server architecture, then retry.';

  @override
  String get nasInstallGuidanceTunnel =>
      'Loopback binding (127.0.0.1) requires SSH tunnel for remote access';

  @override
  String get nasInstallGuidanceTls =>
      'Public binding recommended to be secured behind TLS reverse proxy';

  @override
  String get nasInstallGuidanceSetup =>
      'Complete initial admin account setup in browser on first launch';

  @override
  String get nasInstallGuidanceReadOnly =>
      'Media directory is mounted read-only to safeguard your files';

  @override
  String get nasInstallGuidancePreserved =>
      'Data directory will be preserved on failure for troubleshooting';

  @override
  String get nasDownloadCompletedWithOpenError =>
      'Downloaded (Failed to open externally)';

  @override
  String get nasRetryOpen => 'Retry Open';

  @override
  String get nasExternalOpenFailed => 'Failed to open file in external app';

  @override
  String get nasTitle => 'NAS Media';

  @override
  String get nasLoadMoreGroups => 'Load more groups';

  @override
  String get nasMetadataEnriching => 'Enriching music tags...';

  @override
  String nasMetadataEnrichingWithCount(int count) {
    return 'Enriching music tags ($count processed)...';
  }

  @override
  String nasDownloading(String value) {
    return 'Downloading $value…';
  }

  @override
  String get nasSubtitleNone => 'None';

  @override
  String get nasLibraryId => 'Library ID';

  @override
  String get nasLibraryIdHint => 'Default: all (/), or specify library ID';

  @override
  String nasScanPathRelativeHint(String value) {
    return 'Relative to source root ($value)';
  }

  @override
  String get nasSourceChangedError =>
      'Source changed while configuring, save cancelled';

  @override
  String get nasInvalidLibraryId => 'Invalid library ID';

  @override
  String get startupFailed => 'Application failed to start';

  @override
  String get startupFailedDesc =>
      'An unexpected error occurred during startup. You can retry or export diagnostic logs.';

  @override
  String get retryStartup => 'Retry Startup';

  @override
  String get viewDiagnostics => 'View Diagnostics';

  @override
  String get exportDiagnostics => 'Export Diagnostics';

  @override
  String diagnosticsExportSuccess(String path) {
    return 'Diagnostics exported to $path';
  }

  @override
  String get diagnosticsExportFailed => 'Failed to export diagnostics';

  @override
  String get diagnosticsTitle => 'App Diagnostics';

  @override
  String get settingsDiagnostics => 'Diagnostics & Logs';

  @override
  String get settingsDiagnosticsDesc =>
      'View and export local sanitized application logs';

  @override
  String get diagnosticsEmpty => 'No diagnostic records found';

  @override
  String diagnosticsStorageError(String error) {
    return 'Diagnostics storage error: $error';
  }

  @override
  String diagnosticsIncidentNotice(String category) {
    return 'Recoverable incident reported: $category';
  }

  @override
  String get diagnosticsRefresh => 'Refresh Logs';

  @override
  String get nasInstallTaskTitle => 'Deployment Task';

  @override
  String get nasInstallStagePreflight => 'Preflight Check';

  @override
  String get nasInstallStageReview => 'Plan Review';

  @override
  String get nasInstallStageWriting => 'Writing Configuration';

  @override
  String get nasInstallStagePulling => 'Pulling Image';

  @override
  String get nasInstallStageStarting => 'Starting Container';

  @override
  String get nasInstallStageHealth => 'Health Checking';

  @override
  String get nasInstallStageCleanup => 'Cleaning Up';

  @override
  String get nasInstallStageSucceeded => 'Deployment Succeeded';

  @override
  String get nasInstallStageFailed => 'Deployment Failed';

  @override
  String get nasInstallStageCancelled => 'Deployment Cancelled';

  @override
  String get nasInstallStageNeedsInspection => 'Requires Inspection';

  @override
  String get nasInstallStageReconciling => 'Reconciling State';

  @override
  String get nasInstallCancel => 'Cancel Deployment';

  @override
  String get nasInstallReconcile => 'Reconcile Status';

  @override
  String get nasInstallServerNotFound => 'Selected server was not found';

  @override
  String get nasInstallPortRangeError => 'Port must be between 1 and 65535';

  @override
  String nasInstallElapsedTime(String time) {
    return 'Elapsed: $time';
  }

  @override
  String get nasInstallLogTail => 'Recent Logs';

  @override
  String get nasInstallCleanupCompleted => 'Rollback cleanup completed';

  @override
  String get nasInstallCleanupIncomplete => 'Rollback cleanup incomplete';

  @override
  String get nasInstallNewDeployment => 'New Deployment';

  @override
  String get nasInstallBackEdit => 'Back / Edit Form';

  @override
  String get nasInstallClose => 'Close';

  @override
  String get nasInstallMediaPathHint =>
      'Read-only bind mount on host (e.g. /mnt/media)';

  @override
  String get nasInstallDataRootHint =>
      'Private data & config directory (must not exist yet)';

  @override
  String get nasInstallBindAddressHint =>
      '127.0.0.1 for tunnel, 0.0.0.0 for LAN';

  @override
  String get nasInstallWebdavPasswordHint => 'Minimum 12 characters required';

  @override
  String get nasInstallTargetServer => 'Target Server';

  @override
  String get nasInstallTargetImage => 'Target Image';

  @override
  String get nasInstallContainerName => 'Container Name';

  @override
  String get nasInstallBindAndPort => 'Bind & Port';

  @override
  String get nasInstallComposePreview => 'docker-compose.json Preview';

  @override
  String get nasInstallPlannedSteps => 'Planned Steps';

  @override
  String get nasInstallGuidanceNotes => 'Deployment Notes & Guidance';

  @override
  String get nasInstallNoLogsYet => 'No logs yet';

  @override
  String get sftpPreviewTooLarge =>
      'File exceeds 1 MiB preview limit. Please download and open it externally.';

  @override
  String get sftpSaveFailed =>
      'Failed to save file. Check permissions or network connection.';

  @override
  String get sftpSaving => 'Saving...';

  @override
  String get nasInstallBlockerConnectionChanged =>
      'Target server connection changed; verify remote state before proceeding';

  @override
  String get nasInstallBlockerCancelled =>
      'Deployment was cancelled by user. Review settings and retry if needed.';

  @override
  String get nasInstallBlockerInspectFailed =>
      'Inspection failed to query remote container. Check server connectivity or inspect manually.';

  @override
  String get nasInstallBlockerDeadlineExceeded =>
      'Deployment step timed out. Check server load or network connection and retry.';

  @override
  String get nasInstallBlockerInterrupted =>
      'Deployment was interrupted; review remote state before proceeding.';

  @override
  String get nasInstallBlockerHealthTimeout =>
      'Service started but HTTP health check timed out. Verify service logs or port availability.';

  @override
  String get nasInstallBlockerReconciliationFailed =>
      'Reconciliation failed. Verify remote container status manually or start a new deployment.';

  @override
  String get nasInstallBlockerRemoteInspectionRequired =>
      'Remote container status is uncertain. Manual inspection and reconciliation required.';

  @override
  String get nasInstallBlockerServiceExited =>
      'Container process exited prematurely. Check logs for configuration or permission errors.';

  @override
  String get nasInstallBlockerWriteFailed =>
      'Failed to write deployment files on target server. Check disk space and permissions.';

  @override
  String get nasInstallBlockerPlanStale =>
      'Deployment plan is stale. Please re-run preflight checks.';

  @override
  String get nasInstallBlockerOwnershipChanged =>
      'Existing container was not created by this app. Inspect manually to prevent overwriting.';

  @override
  String get nasInstallBlockerSshRequired =>
      'Active SSH connection to target server is required.';

  @override
  String get nasInstallBlockerReconciliationRequired =>
      'Remote state differs from local state. Please reconcile before proceeding.';

  @override
  String get nasInstallBlockerFailed =>
      'Deployment encountered an error. Check logs and retry.';

  @override
  String get nasInstallBlockerBusy =>
      'An installation task is already in progress. Please check the current task progress.';

  @override
  String get nasInstallBlockerStateSaveFailed =>
      'Failed to persist deployment state. Please check local storage space and file permissions.';

  @override
  String get nasInstallBlockerCommandResultUnknown =>
      'Remote command outcome is unknown. Please run a read-only inspection instead of retrying deployment directly.';

  @override
  String get nasInstallBlockerPreflightFailed =>
      'Pre-deployment environment check failed. Please resolve the blockers before continuing.';

  @override
  String serverDeleteFailed(String error) {
    return 'Failed to delete server: $error';
  }

  @override
  String get chatRunSettingsAgentMode => 'Agent Mode';

  @override
  String get chatRunSettingsApprovalPolicy => 'Local Approval Policy';

  @override
  String get chatRunSettingsExtraSettings => 'Additional Settings';

  @override
  String get chatPermissionAutoAllowSafeDesc =>
      'Automatically allows known-safe operations; asks whenever operation safety cannot be determined.';

  @override
  String chatRunSettingsSaveFailed(String error) {
    return 'Failed to apply run settings: $error';
  }

  @override
  String get chatMessageCopied => 'Message copied to clipboard';

  @override
  String get copy => 'Copy';

  @override
  String get rename => 'Rename';

  @override
  String get refresh => 'Refresh';

  @override
  String get sessionTitle => 'Session Title';

  @override
  String get chatSettingsStale => 'Stale';

  @override
  String get chatSettingsAvailableAfterFirstMessage =>
      'Settings available after first message';

  @override
  String get chatReimportAsCopy => 'Re-import as Copy';

  @override
  String get chatSearchCommandsHint => 'Search commands or skills...';

  @override
  String get chatCommandsTab => 'Commands';

  @override
  String get chatSkillsTab => 'Skills';

  @override
  String get chatAccountAndQuotaTitle => 'Account & Quota';

  @override
  String get chatAccountSectionTitle => 'Account';

  @override
  String get chatAccountNotProvided => 'No account details reported';

  @override
  String get chatAccountKind => 'Type';

  @override
  String get chatAccountLabel => 'Label';

  @override
  String get chatAccountPlan => 'Plan';

  @override
  String get chatAccountEmail => 'Email';

  @override
  String get chatAccountUpdatedAt => 'Updated';

  @override
  String get chatQuotaSectionTitle => 'Quota & Status';

  @override
  String get chatStatusSourceNote => 'Raw Agent /status Output';

  @override
  String get chatStatusNotQueried => 'Status not queried yet';

  @override
  String get chatQueryStatusAction => 'Query Status (/status)';

  @override
  String get chatQueryStatusUnavailable =>
      'Status query unavailable in current session';

  @override
  String get chatAttachmentMissing => 'Attachment file missing or unavailable';

  @override
  String get chatViewModeList => 'List';

  @override
  String get chatViewModeCards => 'Cards';

  @override
  String get chatViewModeGrid => 'Images';

  @override
  String get chatRemoteBrowserTitle => 'Remote Workspace';

  @override
  String get chatSelectDirectory => 'Select Directory';

  @override
  String chatAttachSelectedFiles(int count) {
    return 'Attach Selected ($count)';
  }

  @override
  String get chatNoFilesFound => 'No files found';

  @override
  String get chatRootDirectory => 'Root';

  @override
  String get chatSelectThisDirectory => 'Use this directory';

  @override
  String get chatAgentVersion => 'Agent Version';

  @override
  String get chatParentDirectory => 'Parent Directory';

  @override
  String get chatSearchFilesHint => 'Search files...';

  @override
  String get chatCommandsEmpty => 'No slash commands provided by the agent';

  @override
  String get chatSkillsEmpty => 'No skills provided by the agent';

  @override
  String get chatFileUnsupported => 'File type not supported for attachment';

  @override
  String get chatStatusNotProvided => 'Status query not provided by agent';

  @override
  String get sessionRecoveryReconnecting => 'Reconnecting...';

  @override
  String get sessionRecoverySyncing => 'Syncing output...';

  @override
  String get sessionRecoveryIncomplete => 'Some output could not be recovered';

  @override
  String get sessionRecoveryFailed => 'Recovery failed';

  @override
  String get sessionRecoveryRetry => 'Retry';

  @override
  String get dashboardUpdatesPaused => 'Updates paused';

  @override
  String get chatSettingsIndependentModelUnavailable =>
      'CLI model catalog is currently unavailable. Models may be cached or limited by the CLI version; you can also enter a model name manually.';

  @override
  String get chatSettingsModelCatalogNote =>
      'Models are queried from the CLI app-server using your existing CLI login. The catalog may be cached or version-limited; you can refresh manually or switch to manual input.';

  @override
  String get chatModelCatalogError403 =>
      'CLI model query access denied (403). Check CLI login and service connectivity, or enter a model name manually.';

  @override
  String chatModelCatalogErrorGeneric(String error) {
    return 'Model catalog error: $error';
  }

  @override
  String get chatModelAuthorizeButton => 'Authorize Model Catalog';

  @override
  String get chatModelAuthorizeConfirmTitle => 'Authorize Model Catalog';

  @override
  String get chatModelAuthorizeConfirmMessage =>
      'This will start browser authorization for the model catalog on target host/container. Your existing Codex login and terminal sessions will remain completely untouched. Continue?';

  @override
  String get chatModelAuthorizing => 'Authorizing via browser...';

  @override
  String get chatModelAuthorizeCancel => 'Cancel Authorization';

  @override
  String get chatCommandsFirstTurnNote =>
      'Slash commands will be advertised by the agent runtime once the session is initialized, without requiring a prior ordinary conversation; drafts do not automatically create sessions.';

  @override
  String get chatCommandsClientActionRunSettings => 'Run Settings';

  @override
  String get chatCommandsClientActionWorkingDirectory => 'Working Directory';

  @override
  String get chatCommandsClientActionsSection => 'Local Actions';

  @override
  String get chatRunSettingsModelSourceCatalog => 'Model List';

  @override
  String get chatRunSettingsModelSourceCustom => 'Manual Input';

  @override
  String get chatRunSettingsCustomModelHint => 'Enter model ID';

  @override
  String get chatRunSettingsCustomModelNotice =>
      'Manual model names are unverified and will be sent directly to the agent runtime, which may reject unsupported models.';

  @override
  String get chatRunSettingsCustomModelEmptyError =>
      'Model name cannot be empty';

  @override
  String get chatRunSettingsCustomModelInvalidError =>
      'Model name must be at most 256 characters with no spaces or control characters';

  @override
  String get chatCommandsDraftPreviewNotice =>
      'Commands verified for the current adapter version. Selecting inserts text into the draft; Send will initialize the session on demand and run the command directly.';

  @override
  String get chatCommandsDiscoveryFailed =>
      'Failed to discover commands or skills';

  @override
  String get chatAuthWaitingForBrowser =>
      'Waiting for authorization in browser...';

  @override
  String get chatAuthBrowserLaunchFailed =>
      'Could not open external browser. Please reopen or copy the authorization link below.';

  @override
  String get chatAuthReopenBrowser => 'Reopen Browser';

  @override
  String get chatAuthCopyLink => 'Copy Link';

  @override
  String get chatAuthManualCallback => 'Manual Callback';

  @override
  String get chatAuthManualCallbackTitle => 'Enter Authorization Callback URL';

  @override
  String get chatAuthManualCallbackDesc =>
      'Paste the complete redirect URL (http://127.0.0.1:PORT/...?code=...&state=...) from the browser to complete authorization. Raw authorization codes are not accepted.';

  @override
  String get chatAuthCallbackInputLabel => 'Callback URL';

  @override
  String get chatAuthCallbackInputHint =>
      'http://127.0.0.1:PORT/...?code=...&state=...';

  @override
  String get chatAuthCallbackInvalidError =>
      'Invalid callback URL format or delivery failed';

  @override
  String get agentAuthAgYNotice =>
      'Antigravity ACP requires official account authorization, separate from terminal CLI login.';

  @override
  String get chatAuthDiscoveryPrompt =>
      'This turn requires ACP authentication. Reconnect and request authorization to proceed.';

  @override
  String get chatRequestAuthButton => 'Request Authentication';

  @override
  String get agentActionAcpLogin => 'ACP Sign-In';

  @override
  String get agentActionCliLogin => 'CLI Login';

  @override
  String get agentAgyAcpSignInRequired =>
      'ACP credentials missing (ACP sign-in required)';

  @override
  String get agentAgyAcpCredentialsSaved =>
      'ACP credentials saved (unverified)';

  @override
  String get chatAuthMethodUnavailable =>
      'The selected authentication method is not available.';

  @override
  String get chatAuthConnectionExpired =>
      'Authentication connection expired. Please try again.';

  @override
  String get chatAuthCallbackDeliveryFailed =>
      'Failed to deliver authorization callback to server.';

  @override
  String get agentTargetChangedNotice =>
      'Target server has changed. Please reopen agent management on the current server.';

  @override
  String get agentAgyAuthCheckUnavailable =>
      'Antigravity authentication check unavailable';

  @override
  String get agentAgyAuthCheckInvalid =>
      'Antigravity authentication check response invalid';

  @override
  String get sftpDownloadDisconnected => 'Download disconnected';

  @override
  String get sftpDownloadPermissionDenied => 'Permission denied';

  @override
  String get sftpDownloadNotFound => 'Remote file not found';

  @override
  String get sftpDownloadTimeout => 'Download timed out';

  @override
  String get sftpDownloadLocalSpace => 'Insufficient local storage space';

  @override
  String get sftpDownloadLocalIo => 'Local storage write failed';

  @override
  String get sftpDownloadIncomplete => 'Incomplete download';

  @override
  String get transferStatusWaitingConnection => 'Waiting for connection';

  @override
  String get chatAuthCallbackListenerFailed =>
      'Failed to start local authorization callback listener. Please retry authentication.';

  @override
  String get settingsExperimentalFeatures => 'Experimental Features';

  @override
  String get settingsExperimentalFeaturesDesc =>
      'Try preview and experimental capabilities';

  @override
  String get settingsExperimentalCliChatTitle => 'CLI Smart Chat';

  @override
  String get settingsExperimentalCliChatDesc =>
      'Enable dedicated command-line agent chat interface';

  @override
  String get settingsExperimentalDialogClose => 'Close';

  @override
  String get settingsExperimentalSaveFailed =>
      'Failed to update experimental feature settings';

  @override
  String get settingsExperimentalNasTitle => 'NAS Media';

  @override
  String get settingsExperimentalNasDesc =>
      'Enable media library, scan folders, and audio playback';

  @override
  String get settingsLanguageSaveFailed => 'Failed to update language settings';

  @override
  String get settingsAboutPrivacy => 'About & privacy';

  @override
  String get privacyPolicyTitle => 'Privacy policy';

  @override
  String get privacyPolicyDescription => 'Data use and your choices';

  @override
  String get privacyContactTitle => 'Privacy contact';

  @override
  String get privacyCopyEmail => 'Copy email address';

  @override
  String get privacyEmailCopied => 'Email address copied';

  @override
  String get privacyOnlineVersion => 'View online version';

  @override
  String get privacyLinkFailed =>
      'Unable to open the link. You can copy the email address.';

  @override
  String get privacyLoadFailed =>
      'Unable to load the privacy policy. View the online version.';

  @override
  String get privacyVersionUnknown => 'Version unavailable';

  @override
  String get aboutWebsite => 'Official website';

  @override
  String get aboutLicense => 'Application license';

  @override
  String get aboutThirdPartyLicenses => 'Third-party open source licenses';

  @override
  String get aboutLicenseSummary =>
      'Original Valhalla material is licensed for noncommercial use under PolyForm Noncommercial 1.0.0. Commercial use beyond the license permissions requires separate authorization. Third-party components retain their own licenses. The complete terms below govern use.';

  @override
  String get aboutCopyrightNotice => 'Copyright notices';

  @override
  String get aboutLicenseLoadFailed =>
      'Unable to load the license. Please contact norns.soft@gmail.com.';

  @override
  String get aboutLinkFailed =>
      'Unable to open the link. Please open https://norns.cc.cd in your browser.';

  @override
  String get downloadReveal => 'Show in File Explorer';

  @override
  String get downloadRevealFailed =>
      'Unable to open the download folder. It may have been moved or deleted.';

  @override
  String settingsKnownHostsSubtitle(int count) {
    return '$count trusted host keys';
  }

  @override
  String get settingsKnownHostsEmpty => 'No trusted host keys found';

  @override
  String get settingsKnownHostsDialogTitle => 'Known Host Keys';

  @override
  String get settingsHostKeyRevoke => 'Revoke';

  @override
  String get settingsHostKeyRevokeConfirmTitle => 'Revoke Host Key';

  @override
  String settingsHostKeyRevokeConfirmMessage(String hostPort) {
    return 'Revoke host key for $hostPort? Active SSH connections to this host will be disconnected, and you must verify the key on next connection.';
  }

  @override
  String get settingsHostKeyFingerprintCopied =>
      'Host key fingerprint copied to clipboard';

  @override
  String get settingsHostKeyRevoked => 'Host key revoked';

  @override
  String get settingsClearStorageSubtitle =>
      'Clear saved passwords and private keys for selected servers';

  @override
  String get settingsClearStorageDialogTitle => 'Reset Server Credentials';

  @override
  String get settingsClearStorageDesc =>
      'Select servers to clear locally stored SSH passwords, sudo passwords, and private keys from secure storage. Private key users must re-add their key via Edit Server after clearing (source key files are not deleted). Server configurations and chat histories will not be deleted.';

  @override
  String get settingsClearStorageNoServers => 'No servers available';

  @override
  String get settingsClearStorageSelectAll => 'Select All';

  @override
  String get settingsClearStorageDeselectAll => 'Deselect All';

  @override
  String get settingsClearStorageConfirmTitle => 'Confirm Credential Reset';

  @override
  String settingsClearStorageConfirmMessage(int count) {
    return 'Are you sure you want to clear credentials for $count selected server(s)? Active connections to these servers will be disconnected immediately.';
  }

  @override
  String settingsClearStorageAction(int count) {
    return 'Clear Selected ($count)';
  }

  @override
  String get settingsClearStorageSuccess =>
      'Selected server credentials cleared successfully';

  @override
  String get settingsClearStorageError =>
      'Failed to clear credentials for some servers. Please try again.';

  @override
  String get settingsDefaultAcpAgent => 'Default ACP Agent';

  @override
  String get settingsDefaultAcpAgentSubtitle =>
      'Default agent for ACP chat on this server';

  @override
  String get settingsDefaultCliAgent => 'Default CLI Agent';

  @override
  String get settingsDefaultCliAgentSubtitle =>
      'Default agent for CLI chat on this server';

  @override
  String get settingsDefaultAgentAutomatic => 'Automatic (first available)';

  @override
  String get settingsDefaultAgentSelectTitle => 'Select Default Agent';

  @override
  String get settingsDefaultAgentNoServer => 'No server selected';

  @override
  String get settingsDefaultAgentNoAgents =>
      'No agents configured for this server';

  @override
  String get settingsDefaultAgentSaveFailed =>
      'Failed to update default agent setting';

  @override
  String get dockerViewGroupContainers => 'Containers';

  @override
  String get dockerViewGroupProjects => 'Compose Projects';

  @override
  String get dockerProjectActionStart => 'Start Project';

  @override
  String get dockerProjectActionStop => 'Stop Project';

  @override
  String get dockerProjectActionRestart => 'Restart Project';

  @override
  String get dockerProjectConfirmStopTitle => 'Stop Compose Project';

  @override
  String get dockerProjectConfirmRestartTitle => 'Restart Compose Project';

  @override
  String dockerProjectConfirmMessage(String action, String project, int count) {
    return 'Are you sure you want to $action project \"$project\"? The following $count containers will be affected:';
  }

  @override
  String dockerProjectActionSuccess(String project, String action) {
    return 'Project \"$project\" $action completed successfully';
  }

  @override
  String dockerProjectActionPartial(
    String project,
    String action,
    int failedCount,
  ) {
    return 'Project \"$project\" $action completed with $failedCount failure(s)';
  }

  @override
  String get dockerNoProjects => 'No Docker Compose projects found';

  @override
  String get dockerMountsTitle => 'Mounts';

  @override
  String get dockerMountReadOnly => 'Read-only';

  @override
  String get dockerMountReadWrite => 'Read/Write';

  @override
  String get sftpBookmarksTitle => 'Directory Bookmarks';

  @override
  String get sftpNoBookmarks => 'No directory bookmarks saved yet';

  @override
  String get sftpAddBookmark => 'Bookmark this folder';

  @override
  String get sftpRemoveBookmark => 'Remove bookmark';

  @override
  String get sftpCurrentDirectory => 'Current Directory';

  @override
  String get sftpSelectMode => 'Select Multiple Files';

  @override
  String sftpSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get sftpSelectAll => 'Select All';

  @override
  String get sftpDeselectAll => 'Deselect All';

  @override
  String get sftpBatchCopy => 'Copy';

  @override
  String get sftpBatchMove => 'Move';

  @override
  String get sftpBatchDeleteConfirmTitle => 'Confirm Batch Deletion';

  @override
  String sftpBatchDeleteConfirmMessage(int count) {
    return 'Are you sure you want to delete $count selected item(s)?';
  }

  @override
  String get sftpBatchDeleteNonEmptyNotice =>
      'Notice: Non-empty directories cannot be deleted recursively and will be skipped.';

  @override
  String get sftpBatchCopyConfirmTitle => 'Confirm Batch Copy';

  @override
  String sftpBatchCopyConfirmMessage(int count, String directory) {
    return 'Copy $count selected item(s) to \"$directory\"?';
  }

  @override
  String get sftpBatchMoveConfirmTitle => 'Confirm Batch Move';

  @override
  String sftpBatchMoveConfirmMessage(int count, String directory) {
    return 'Move $count selected item(s) to \"$directory\"?';
  }

  @override
  String get sftpBatchResultsTitle => 'Batch Operation Results';

  @override
  String get sftpBatchOutcomeSkipped =>
      'Skipped (Target exists or not supported)';

  @override
  String get sftpBatchTargetRestricted =>
      'Cannot select current or descendant directories as target';

  @override
  String get sftpSelectCurrentDir => 'Choose This Directory';

  @override
  String sftpBatchOperationSuccess(int count) {
    return 'Successfully processed $count item(s)';
  }

  @override
  String get configMigrationTitle => 'Backup & Configuration Migration';

  @override
  String get configExportTitle => 'Export Configuration';

  @override
  String get configExportSubtitle =>
      'Export servers, agents, commands, bookmarks and preferences to JSON';

  @override
  String get configExportDialogTitle => 'Export Valhalla Configuration';

  @override
  String get configExportSuccess => 'Configuration exported successfully';

  @override
  String configExportError(String error) {
    return 'Failed to export configuration: $error';
  }

  @override
  String get configImportTitle => 'Import Configuration';

  @override
  String get configImportSubtitle =>
      'Import configuration from a backup JSON file';

  @override
  String get configBackupTooLarge =>
      'Backup file exceeds maximum allowed size (8 MB)';

  @override
  String get configImportPreviewTitle => 'Preview Configuration Import';

  @override
  String get configImportPreviewDesc =>
      'Review contents before importing. Existing items will be preserved and merged.';

  @override
  String configImportServersCount(int count) {
    return 'Servers ($count)';
  }

  @override
  String configImportAgentsCount(int count) {
    return 'Agents ($count)';
  }

  @override
  String configImportCommandsCount(int count) {
    return 'Quick Commands ($count)';
  }

  @override
  String configImportBookmarksCount(int count) {
    return 'Bookmarks ($count)';
  }

  @override
  String get configImportSecretWarning =>
      'Custom commands may contain sensitive scripts or embedded credentials. No passwords, private keys, or trusted fingerprints are transferred.';

  @override
  String get configImportGlobalPreferences =>
      'Import global application preferences';

  @override
  String get configImportGlobalPreferencesDesc =>
      'Overwrites current theme, terminal, and navigation settings';

  @override
  String get configImportConfirmAction => 'Confirm Import';

  @override
  String get configImportSuccess => 'Configuration imported successfully';

  @override
  String get configImportErrorTitle => 'Invalid Configuration Backup';

  @override
  String configImportErrorGeneric(String error) {
    return 'Failed to import configuration: $error';
  }

  @override
  String get configImportErrorCopyDetails => 'Copy Diagnostic Details';

  @override
  String get configImportErrorCopied =>
      'Diagnostic details copied to clipboard';

  @override
  String get configImportErrorUnsupportedVersion =>
      'Unsupported backup format or version';

  @override
  String get configImportErrorMalformed =>
      'Malformed or damaged configuration JSON';
}
