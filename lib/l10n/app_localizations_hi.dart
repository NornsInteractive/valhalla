// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appName => 'Valhalla';

  @override
  String get appSubtitle => 'AI-ने native सर्वर और एजेंट प्रबंधन';

  @override
  String get navAiChat => 'AI चैट';

  @override
  String get navTerminal => 'टर्मिनल';

  @override
  String get navFiles => 'SFTP फ़ाइलें';

  @override
  String get navCommands => 'कमांड्स';

  @override
  String get navSettings => 'सेटिंग्स';

  @override
  String get serverConnected => 'कनेक्टेड';

  @override
  String get serverOnline => 'ऑनलाइन';

  @override
  String get serverOffline => 'ऑफ़लाइन';

  @override
  String get latencyMs => 'मि.से.';

  @override
  String get reconnect => 'पुनः कनेक्ट करें';

  @override
  String get disconnect => 'डिस्कनेक्ट करें';

  @override
  String get quickDisconnect => 'त्वरित डिस्कनेक्ट';

  @override
  String get newSession => 'नया सत्र';

  @override
  String get historySessions => 'सत्र इतिहास';

  @override
  String get switchAgent => 'एजेंट बदलें';

  @override
  String get agentClaudeCode => 'Claude CodeX';

  @override
  String get agentCodex => 'OpenAI Codex';

  @override
  String get agentOpenCode => 'OpenCode ACP';

  @override
  String get agentGemini => 'Gemini CLI';

  @override
  String get activeAgent => 'सक्रिय एजेंट';

  @override
  String get inputPromptHint =>
      'एजेंट से निदान करने, उपकरण चलाने या कमांड लिखने के लिए कहें... (भेजने के लिए Enter दबाएं)';

  @override
  String get thinking => 'विचार प्रक्रिया';

  @override
  String get executionPlan => 'निष्पादन योजना';

  @override
  String get toolCall => 'टूल कॉल';

  @override
  String get toolStatusPending => 'लंबित';

  @override
  String get toolStatusRunning => 'चल रहा है...';

  @override
  String get toolStatusCompleted => 'पूर्ण';

  @override
  String get toolStatusFailed => 'विफल';

  @override
  String get permissionRequired => 'अनुमति आवश्यक है';

  @override
  String get permissionDescription =>
      'एजेंट सर्वर पर यह कमांड निष्पादित करना चाहता है:';

  @override
  String get permissionReject => 'अस्वीकार करें';

  @override
  String get permissionAllowOnce => 'एक बार अनुमति दें';

  @override
  String get permissionAllowAlways => 'हमेशा अनुमति दें';

  @override
  String get quickTroubleshootCpu => 'उच्च CPU समस्या निवारण';

  @override
  String get quickDockerHealth => 'Docker स्वास्थ्य जांच';

  @override
  String get quickCleanCache => 'सिस्टम कैश साफ़ करें';

  @override
  String get quickNginxLogs => 'Nginx त्रुटि लॉग जांचें';

  @override
  String get terminalNewTab => 'नया टैब';

  @override
  String get terminalCloseTab => 'टैब बंद करें';

  @override
  String get terminalClear => 'साफ़ करें';

  @override
  String get terminalQuickCmds => 'कमांड पैलेट';

  @override
  String get terminalPaste => 'पेस्ट करें';

  @override
  String get sftpCurrentPath => 'वर्तमान पथ';

  @override
  String get sftpUpload => 'अपलोड करें';

  @override
  String get sftpNewFolder => 'नया फ़ोल्डर';

  @override
  String get sftpNewFile => 'नई फ़ाइल';

  @override
  String get sftpRefresh => 'ताज़ा करें';

  @override
  String get sftpSearchHint => 'फ़ाइलें या फ़ोल्डर खोजें...';

  @override
  String get sftpEmpty => 'डायरेक्टरी खाली है';

  @override
  String get sftpFileName => 'नाम';

  @override
  String get sftpFileSize => 'आकार';

  @override
  String get sftpFilePerm => 'अनुमतियाँ';

  @override
  String get sftpFileModified => 'संशोधित';

  @override
  String get cmdCategoryDocker => 'DOCKER कंटेनर स्टैक';

  @override
  String get cmdCategorySystem => 'सिस्टम रखरखाव';

  @override
  String get cmdCategoryNetwork => 'नेटवर्क और पोर्ट्स';

  @override
  String get cmdExecute => 'चलाएं';

  @override
  String get cmdDangerous => 'खतरनाक कमांड';

  @override
  String get cmdDangerousWarning =>
      'यह ऑपरेशन अपरिवर्तनीय है और इससे सेवा में रुकावट आ सकती है। क्या आप वाकई आगे बढ़ना चाहते हैं?';

  @override
  String get cmdParamRequired => 'पैरामीटर इनपुट आवश्यक है';

  @override
  String get cmdConfirm => 'पुष्टि करें और चलाएं';

  @override
  String get cmdCancel => 'रद्द करें';

  @override
  String get settingsAppearance => 'उपस्थिति और थीम';

  @override
  String get settingsThemeMode => 'थीम मोड';

  @override
  String get themeSystem => 'सिस्टम का पालन करें';

  @override
  String get themeSystemDesc => 'स्वचालित अनुकूलन';

  @override
  String get themeLight => 'लाइट मोड';

  @override
  String get themeLightDesc => 'कागज़ी उच्च-प्रकाश';

  @override
  String get themeDark => 'गीक डार्क';

  @override
  String get themeDarkDesc => 'गहरा चारकोल';

  @override
  String get themeAmoled => 'AMOLED ब्लैक';

  @override
  String get themeAmoledDesc => 'वास्तविक काला 0x000000';

  @override
  String get settingsAccentColor => 'थीम एक्सेंट रंग';

  @override
  String get accentCyberEmerald => 'साइबर एमराल्ड';

  @override
  String get accentTechBlue => 'टेक ब्लू';

  @override
  String get accentElectricViolet => 'इलेक्ट्रिक वॉयलेट';

  @override
  String get accentCrimsonRed => 'क्रिमसन रेड';

  @override
  String get accentAmberOrange => 'एम्बर ऑरेंज';

  @override
  String get settingsLanguage => 'भाषा और क्षेत्र';

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
  String get settingsAiOps => 'AI Ops और इंजन';

  @override
  String get settingsSecurity => 'कनेक्शन और सुरक्षा';

  @override
  String get settingsKnownHosts => 'ज्ञात होस्ट कुंजियाँ';

  @override
  String get settingsClearStorage => 'क्रेडेंशियल्स रीसेट करें';

  @override
  String get settingsResetDefault => 'डिफ़ॉल्ट पर रीसेट करें';

  @override
  String get settingsTerminalUseTmux => 'स्थायी सत्र (tmux)';

  @override
  String get settingsTerminalUseTmuxSubtitle =>
      'रिमोट सर्वर पर tmux के अंदर टर्मिनल सत्र चलाएं';

  @override
  String get settingsTerminalUseTmuxDescription =>
      'डिस्कनेक्ट होने के बाद भी टर्मिनल आउटपुट सुरक्षित रखता है। रिमोट सर्वर पर tmux आवश्यक है। नए खोले गए टर्मिनल टैब पर लागू होता है।';

  @override
  String get settingsTerminalFontSize => 'टर्मिनल फ़ॉन्ट आकार';

  @override
  String get settingsTerminalFontSizeSubtitle =>
      'SSH और CLI टर्मिनल फ़ॉन्ट आकार समायोजित करें';

  @override
  String get version => 'संस्करण';

  @override
  String get addServer => 'सर्वर जोड़ें';

  @override
  String get editServer => 'सर्वर संपादित करें';

  @override
  String get serverName => 'सर्वर का नाम';

  @override
  String get serverHost => 'होस्ट / IP';

  @override
  String get serverPort => 'पोर्ट';

  @override
  String get serverUsername => 'उपयोगकर्ता नाम';

  @override
  String get serverAuthType => 'प्रमाणीकरण प्रकार';

  @override
  String get serverPassword => 'पासवर्ड';

  @override
  String get serverPrivateKey => 'निजी कुंजी (Private Key)';

  @override
  String get serverSave => 'सर्वर सहेजें';

  @override
  String get serverDelete => 'सर्वर हटाएं';

  @override
  String get fileEditor => 'फ़ाइल संपादक';

  @override
  String get fileEditorSave => 'परिवर्तन सहेजें';

  @override
  String get fileSavedSuccess => 'फ़ाइल सफलतापूर्वक सहेजी गई';

  @override
  String get addCommand => 'नया कमांड';

  @override
  String get commandTitle => 'कमांड शीर्षक';

  @override
  String get commandContent => 'कमांड स्ट्रिंग';

  @override
  String get commandCategory => 'श्रेणी';

  @override
  String get commandDescription => 'विवरण';

  @override
  String get save => 'सहेजें';

  @override
  String get delete => 'हटाएं';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get confirm => 'पुष्टि करें';

  @override
  String get cmdExecutionChannel => 'निष्पादन चैनल';

  @override
  String get cmdChannelTerminal => 'सीधे SSH टर्मिनल पर';

  @override
  String get cmdChannelTerminalDesc =>
      'कमांड सीधे सक्रिय टर्मिनल सत्र में टाइप किया जाता है';

  @override
  String get cmdChannelBackground => 'पृष्ठभूमि सत्र में चलाएं';

  @override
  String get cmdChannelBackgroundDesc =>
      'SSH लॉगिन शेल के माध्यम से निष्पादित होता है और आउटपुट कैप्चर करता है';

  @override
  String get cmdInjectedToTerminal => 'कमांड टर्मिनल पर भेजा गया';

  @override
  String get cmdExecutionCompleted => 'निष्पादन पूर्ण हुआ';

  @override
  String get cmdExecutionFailed => 'निष्पादन विफल रहा';

  @override
  String get cmdExecutingRemote => 'रिमोट कमांड निष्पादित किया जा रहा है...';

  @override
  String get cmdClose => 'बंद करें';

  @override
  String get navDashboard => 'डैशबोर्ड';

  @override
  String get navDocker => 'Docker';

  @override
  String get navSystem => 'सिस्टम';

  @override
  String get navMore => 'अधिक';

  @override
  String get dashboardTitle => 'सर्वर डैशबोर्ड';

  @override
  String get metricsCpu => 'CPU उपयोग';

  @override
  String get metricsMemory => 'मेमोरी उपयोग';

  @override
  String get metricsLoadAvg => 'औसत लोड';

  @override
  String get metricsUptime => 'सिस्टम अपटाइम';

  @override
  String get metricsRootDisk => 'रूट डिस्क उपयोग';

  @override
  String get quickActions => 'त्वरित नेविगेशन';

  @override
  String get activeServerStatus => 'सक्रिय सर्वर स्थिति';

  @override
  String get noServerSelected =>
      'वर्तमान में कोई सर्वर चयनित नहीं है। कृपया पहले एक सर्वर चुनें।';

  @override
  String get serverDisconnected => 'डिस्कनेक्टेड';

  @override
  String get serverConnecting => 'कनेक्ट हो रहा है...';

  @override
  String get connectNow => 'अभी कनेक्ट करें';

  @override
  String get serverSpecs => 'सर्वर जानकारी और विवरण';

  @override
  String get dockerTitle => 'Docker कंटेनर';

  @override
  String get dockerSearchHint => 'नाम या छवि द्वारा कंटेनर खोजें...';

  @override
  String get dockerFilterAll => 'सभी';

  @override
  String get dockerFilterRunning => 'चल रहे हैं';

  @override
  String get dockerFilterExited => 'बाहर निकले';

  @override
  String get dockerFilterPaused => 'रोके गए';

  @override
  String get dockerActionStart => 'प्रारंभ करें';

  @override
  String get dockerActionStop => 'रोकें';

  @override
  String get dockerActionRestart => 'पुनः प्रारंभ करें';

  @override
  String get dockerActionPause => 'विराम दें';

  @override
  String get dockerActionUnpause => 'फिर से शुरू करें';

  @override
  String get dockerActionRm => 'हटाएं';

  @override
  String get dockerActionLogs => 'लॉग्स';

  @override
  String get dockerActionInspect => 'निरीक्षण करें';

  @override
  String get dockerLogsTitle => 'कंटेनर लॉग्स';

  @override
  String get dockerInspectTitle => 'कंटेनर निरीक्षण';

  @override
  String get dockerNoContainers => 'सर्वर पर कोई कंटेनर नहीं मिला';

  @override
  String get dockerEmptyRunning => 'कोई कंटेनर चल नहीं रहा है';

  @override
  String get dockerPorts => 'पोर्ट्स';

  @override
  String get dockerCreated => 'निर्मित';

  @override
  String get dockerImage => 'छवि';

  @override
  String get systemTitle => 'प्रक्रियाएं और सेवाएं';

  @override
  String get tabProcesses => 'प्रक्रियाएं';

  @override
  String get tabServices => 'Systemd सेवाएं';

  @override
  String get processSearchHint => 'प्रक्रिया नाम या PID द्वारा खोजें...';

  @override
  String get processPid => 'PID';

  @override
  String get processCpu => 'CPU %';

  @override
  String get processMem => 'MEM %';

  @override
  String get processStat => 'स्थिति';

  @override
  String get processCommand => 'कमांड';

  @override
  String get processTerminate => 'समाप्त करें (SIGTERM)';

  @override
  String get processForceKill => 'बलपूर्वक समाप्त करें (SIGKILL)';

  @override
  String get processKillForbidden =>
      'सिस्टम इनिट (PID <= 1) को समाप्त करने से इनकार किया गया';

  @override
  String get serviceSearchHint => 'नाम से सेवाएं खोजें...';

  @override
  String get serviceName => 'सेवा';

  @override
  String get serviceDescription => 'विवरण';

  @override
  String get serviceStatus => 'स्थिति';

  @override
  String get serviceStartup => 'स्टार्टअप';

  @override
  String get serviceActionStart => 'प्रारंभ करें';

  @override
  String get serviceActionStop => 'रोकें';

  @override
  String get serviceActionRestart => 'पुनः प्रारंभ करें';

  @override
  String get serviceActionReload => 'पुनः लोड करें';

  @override
  String get serviceActionEnable => 'सक्षम करें';

  @override
  String get serviceActionDisable => 'अक्षम करें';

  @override
  String get serviceNoServices => 'कोई systemd सेवा नहीं मिली';

  @override
  String get riskDangerTitle => 'उच्च जोखिम ऑपरेशन पुष्टि';

  @override
  String get riskWarningTitle => 'ऑपरेशन चेतावनी पुष्टि';

  @override
  String get riskSafeTitle => 'कार्रवाई की पुष्टि करें';

  @override
  String get riskIrreversibleWarning =>
      'यह ऑपरेशन उच्च जोखिम के रूप में वर्गीकृत है और इसे पूर्ववत नहीं किया जा सकता है। इससे डेटा हानि या सेवा में रुकावट आ सकती है।';

  @override
  String get riskWarningDescription =>
      'यह ऑपरेशन सक्रिय सेवाओं को प्रभावित कर सकता है या प्रक्रियाओं को पुनः प्रारंभ कर सकता है। सावधानी से आगे बढ़ें।';

  @override
  String get riskCommandPreview => 'कमांड पूर्वावलोकन';

  @override
  String get riskConfirmButton => 'पुष्टि करें और आगे बढ़ें';

  @override
  String get riskCancelButton => 'रद्द करें';

  @override
  String get stateLoading => 'रिमोट डेटा लोड हो रहा है...';

  @override
  String get stateOffline => 'सर्वर ऑफ़लाइन है';

  @override
  String get stateOfflineDesc =>
      'संसाधनों का प्रबंधन करने और मेट्रिक्स स्ट्रीम करने के लिए एक सक्रिय SSH कनेक्शन स्थापित करें।';

  @override
  String get stateError => 'एक त्रुटि उत्पन्न हुई';

  @override
  String get stateRetry => 'पुनः प्रयास करें';

  @override
  String get stateEmpty => 'कोई आइटम नहीं मिला';

  @override
  String get inspectorTitle => 'निरीक्षक';

  @override
  String get inspectorClose => 'बंद करें';

  @override
  String get inspectorDetails => 'निरीक्षण विवरण';

  @override
  String get selectServerTitle => 'लक्ष्य सर्वर चुनें';

  @override
  String get sshDisconnectedSuccess => 'SSH कनेक्शन डिस्कनेक्ट हो गया';

  @override
  String get trustHostFingerprintTitle =>
      'क्या होस्ट फ़िंगरप्रिंट पर भरोसा करें?';

  @override
  String get trustAndConnect => 'भरोसा करें और कनेक्ट करें';

  @override
  String get reject => 'अस्वीकार करें';

  @override
  String get confirmDeleteServerTitle => 'सर्वर हटाएं';

  @override
  String get noServersFound => 'अभी तक कोई सर्वर कॉन्फ़िगर नहीं किया गया है';

  @override
  String get agentNotReadyError =>
      'चयनित एजेंट तैयार नहीं है। कृपया इसके परिवेश और कॉन्फ़िगरेशन को सत्यापित करें।';

  @override
  String get sshDisconnectedError =>
      'SSH डिस्कनेक्टेड है। AI Ops का उपयोग करने से पहले कृपया एक सर्वर से कनेक्ट करें।';

  @override
  String get noAgentAvailable => 'कोई एजेंट उपलब्ध नहीं है';

  @override
  String get noAgentAvailablePrompt =>
      'कोई सक्रिय एजेंट उपलब्ध नहीं है। कृपया पहले एक एजेंट कॉन्फ़िगर या तैयार करें।';

  @override
  String get noAgentAvailableHint =>
      'बातचीत शुरू करने के लिए उपलब्ध एजेंट का चयन या कॉन्फ़िगर करें...';

  @override
  String get manageAgents => 'एजेंट प्रबंधित करें';

  @override
  String get noReadyAgentsTitle => 'कोई तैयार एजेंट नहीं';

  @override
  String get noReadyAgentsDesc =>
      'इस सर्वर पर किसी भी एजेंट ने परिवेश जांच पास नहीं की है।';

  @override
  String get agentStatusReady => 'तैयार';

  @override
  String get agentStatusChecking => 'जांच हो रही है...';

  @override
  String get agentStatusCliMissing => 'इंस्टॉलेशन नहीं मिला';

  @override
  String get agentStatusAcpMissing => 'ACP घटक नहीं मिला';

  @override
  String get agentStatusNotLoggedIn => 'लॉग इन नहीं है';

  @override
  String get agentStatusError => 'त्रुटि';

  @override
  String get agentStatusUnknown => 'अज्ञात';

  @override
  String get agentActionInstall => 'इंस्टॉल करें';

  @override
  String get agentActionLogin => 'लॉग इन करें';

  @override
  String get agentActionRefresh => 'स्थिति जांचें';

  @override
  String get noConfiguredAgents => 'इस सर्वर पर कोई एजेंट कॉन्फ़िगर नहीं है';

  @override
  String get agentManagementTitle => 'एजेंट प्रबंधन';

  @override
  String get settingsAgentManagement => 'एजेंट प्रबंधन';

  @override
  String get settingsAgentManagementSubtitle =>
      'वर्तमान सर्वर के लिए ACP एजेंटों को कॉन्फ़िगर, डिटेक्ट और प्रबंधित करें';

  @override
  String get addAgentButton => 'एजेंट जोड़ें';

  @override
  String get noServerSelectedForAgents =>
      'कोई सर्वर चयनित नहीं है। कृपया पहले मुख्य इंटरफ़ेस से एक सर्वर चुनें।';

  @override
  String get sshDisconnectedAgentWarning =>
      'SSH डिस्कनेक्टेड है। कनेक्शन स्थापित होने तक डिटेक्शन, इंस्टॉलेशन और लॉगिन अक्षम रहेंगे।';

  @override
  String get noAgentsConfiguredTitle => 'कोई एजेंट कॉन्फ़िगर नहीं है';

  @override
  String get noAgentsConfiguredDesc =>
      'इस सर्वर पर AI Ops सक्षम करने के लिए Claude Code, Codex, OpenCode, AGY या कस्टम ACP एजेंट जोड़ें।';

  @override
  String get agentPresetLabel => 'प्रीसेट';

  @override
  String get agentPresetClaudeCode => 'Claude Code';

  @override
  String get agentPresetCodex => 'OpenAI Codex';

  @override
  String get agentPresetOpenCode => 'OpenCode ACP';

  @override
  String get agentPresetAgy => 'Antigravity AGY';

  @override
  String get agentPresetCustom => 'कस्टम';

  @override
  String get agentNameLabel => 'एजेंट का नाम';

  @override
  String get agentNameHint => 'उदा. Production Codex';

  @override
  String get agentDescriptionLabel => 'विवरण';

  @override
  String get agentDescriptionHint => 'एजेंट का संक्षिप्त विवरण';

  @override
  String get agentCliCommandLabel => 'CLI जांच कमांड';

  @override
  String get agentCliCommandHint => 'उदा. claude, codex';

  @override
  String get agentAcpCommandLabel => 'ACP लॉन्च कमांड';

  @override
  String get agentAcpCommandHint => 'उदा. codex-acp --stdio';

  @override
  String get agentInstallCommandLabel => 'इंस्टॉल कमांड (वैकल्पिक)';

  @override
  String get agentInstallCommandHint => 'उदा. npm install -g @openai/codex';

  @override
  String get agentLoginCheckCommandLabel => 'लॉगिन जांच कमांड (वैकल्पिक)';

  @override
  String get agentLoginCheckCommandHint => 'उदा. codex --version';

  @override
  String get agentLoginCommandLabel => 'लॉगिन कमांड (वैकल्पिक)';

  @override
  String get agentLoginCommandHint => 'उदा. codex login';

  @override
  String get agentSaveButton => 'सहेजें और जांचें';

  @override
  String get agentCliRequired => 'CLI जांच कमांड आवश्यक है';

  @override
  String get agentAcpRequired => 'ACP लॉन्च कमांड आवश्यक है';

  @override
  String get agentNameRequired => 'एजेंट का नाम आवश्यक है';

  @override
  String get confirmInstallAgentTitle => 'एजेंट इंस्टॉलेशन की पुष्टि करें';

  @override
  String get confirmLoginAgentTitle => 'एजेंट लॉगिन की पुष्टि करें';

  @override
  String get agentCommandRiskWarning =>
      'यह कमांड वर्तमान उपयोगकर्ता विशेषाधिकारों के साथ सीधे रिमोट सर्वर पर निष्पादित किया जाएगा। यह पैकेज इंस्टॉल कर सकता है या सिस्टम परिवेश को संशोधित कर सकता है।';

  @override
  String get targetServerLabel => 'लक्ष्य सर्वर';

  @override
  String get commandPreviewLabel => 'कमांड पूर्वावलोकन';

  @override
  String get executeButton => 'निष्पादित करें';

  @override
  String get deleteAgentTitle => 'एजेंट हटाएं';

  @override
  String get deleteAgentConfirm => 'हटाएं';

  @override
  String get agentStatusCheckingDesc =>
      'रिमोट सर्वर पर परिवेश का पता लगाया जा रहा है...';

  @override
  String get agentStatusInstalling =>
      'सर्वर पर निर्भरताएं इंस्टॉल की जा रही हैं...';

  @override
  String get agentStatusLoggingIn =>
      'सर्वर पर लॉगिन कमांड निष्पादित किया जा रहा है...';

  @override
  String get agentNoLoginCheckProvided =>
      'कोई लॉगिन जांच कमांड निर्दिष्ट नहीं है';

  @override
  String get agentInstallPrompt =>
      'इंस्टॉलेशन नहीं मिला। क्या अभी स्वचालित रूप से इंस्टॉल करें?';

  @override
  String get agentActionAutoInstall => 'स्वचालित इंस्टॉल';

  @override
  String get agentLoginPrompt => 'लॉग इन नहीं है। क्या अभी लॉग इन करें?';

  @override
  String get agentActionExecuteLogin => 'अभी लॉग इन करें';

  @override
  String get agentNeedsInstallOrReadyPrompt =>
      'इस सर्वर पर एजेंट अभी इंस्टॉल या तैयार नहीं हैं। कृपया परिवेश सेटअप प्रबंधित और पूर्ण करें।';

  @override
  String get agentNeedsInstallOrReadyHint =>
      'बातचीत शुरू करने के लिए एक एजेंट इंस्टॉल और तैयार करें...';

  @override
  String get agentAcpInstallPrompt =>
      'ACP घटक नहीं मिला। क्या अभी स्वचालित रूप से इंस्टॉल करें?';

  @override
  String get agentInstallCommandAcpLabel => 'ACP इंस्टॉल कमांड (वैकल्पिक)';

  @override
  String get agentInstallCommandAcpHint =>
      'उदा. npm install -g @zed-industries/codex-acp';

  @override
  String get agentNoInstallCommand =>
      'इस एजेंट के लिए कोई इंस्टॉल कमांड कॉन्फ़िगर नहीं है';

  @override
  String get agentInstallLogTitle => 'इंस्टॉल आउटपुट';

  @override
  String get agentInstallLogEmpty =>
      'इंस्टॉल आउटपुट की प्रतीक्षा की जा रही है…';

  @override
  String get agentInstallLogTruncated =>
      'आउटपुट बहुत लंबा है; सबसे हालिया पंक्तियाँ दिखाई जा रही हैं';

  @override
  String get agentAcpOptional => 'वैकल्पिक; केवल CLI के लिए खाली छोड़ें';

  @override
  String get acpStreaming => 'ACP स्ट्रीमिंग...';

  @override
  String get aiOpsAgentTitle => 'Valhalla AI Ops एजेंट';

  @override
  String get aiOpsEmptySubtitle =>
      'SSH चैनल पर ACP stdio के माध्यम से कनेक्टेड';

  @override
  String get agentAuthRequiredTitle => 'प्रमाणीकरण आवश्यक है';

  @override
  String get agentAuthRequiredDesc =>
      'आपके अनुरोध को संसाधित करने से पहले एजेंट को प्रमाणीकरण की आवश्यकता है।';

  @override
  String get agentAuthMethodLabel => 'प्रमाणीकरण विधि';

  @override
  String get agentAuthNoMethodsNotice =>
      'एजेंट ने लॉगिन विधि प्रदान नहीं की। कृपया सर्वर पर इसके कॉन्फ़िगरेशन की जांच करें।';

  @override
  String get agentAuthProceedButton => 'लॉग इन करें';

  @override
  String get agentAuthCancelButton => 'रद्द करें';

  @override
  String get agentAuthRetryHint =>
      'लॉग इन करने के बाद, अपना संदेश फिर से भेजें।';

  @override
  String get agentAuthRequiredError =>
      'प्रमाणीकरण आवश्यक है। जारी रखने के लिए कृपया लॉग इन करें।';

  @override
  String get agentLoginTerminalTitle => 'इंटरैक्टिव लॉगिन टर्मिनल';

  @override
  String get agentLoginTerminalSubtitle =>
      'नीचे दिए गए टर्मिनल में लॉगिन चरण पूरे करें। दिखाए गए किसी भी URL या कोड संकेतों का पालन करें।';

  @override
  String get agentLoginTerminalRunning =>
      'टर्मिनल में लॉगिन कमांड चल रहा है...';

  @override
  String get agentLoginTerminalDisconnected =>
      'SSH कनेक्शन टूट गया। लॉगिन सत्र बाधित हुआ।';

  @override
  String get agentLoginTerminalRetry => 'टर्मिनल पुनः कनेक्ट करें';

  @override
  String get agentLoginTerminalFinish => 'पूर्ण करें और सत्यापित करें';

  @override
  String get agentLoginTerminalClose => 'बंद करें';

  @override
  String get agentLoginTerminalNoTtyHint =>
      'यदि एजेंट को कोड पेस्ट करने की आवश्यकता है, तो पेस्ट करने के लिए टर्मिनल को देर तक दबाएं या PASTE कुंजी का उपयोग करें।';

  @override
  String get agentLoginTerminalUrlLabel => 'लॉगिन URL का पता चला';

  @override
  String get agentLoginTerminalUrlCopy => 'लिंक कॉपी करें';

  @override
  String get agentLoginTerminalUrlCopied =>
      'लॉगिन URL क्लिपबोर्ड पर कॉपी किया गया';

  @override
  String get agentLoginTerminalCopyAll => 'सभी आउटपुट कॉपी करें';

  @override
  String get agentLoginTerminalCopiedAll =>
      'टर्मिनल आउटपुट क्लिपबोर्ड पर कॉपी किया गया';

  @override
  String get sshStatusReconnected => 'कनेक्शन बहाल हुआ';

  @override
  String get sshStatusDisconnectedRetrying =>
      'कनेक्शन टूट गया, पुनः प्रयास किया जा रहा है';

  @override
  String get sshStatusDisconnectedManual => 'डिस्कनेक्टेड';

  @override
  String get sshStatusHostKeyChanged => 'होस्ट कुंजी बदल गई — कनेक्शन अस्वीकृत';

  @override
  String get sshKeepAliveNotificationTitle =>
      'Valhalla आपके सत्रों को सक्रिय रख रहा है';

  @override
  String get terminalTmuxMissingNotice =>
      'tmux नहीं मिला — कनेक्शन टूटने पर सत्र जीवित नहीं रहेंगे';

  @override
  String get terminalTmuxSessionRestored => 'टर्मिनल सत्र बहाल हुआ';

  @override
  String get moshSectionTitle => 'Mosh';

  @override
  String get moshEnable =>
      'Mosh सक्षम करें — एक रोमिंग टर्मिनल जो कनेक्शन टूटने और IP परिवर्तनों से सुरक्षित रहता है';

  @override
  String get moshServerPathLabel => 'mosh-server पथ';

  @override
  String get moshPortRangeLabel => 'UDP पोर्ट श्रेणी';

  @override
  String get moshNewSession => 'नया Mosh सत्र';

  @override
  String get moshNotInstalled =>
      'रिमोट सर्वर पर mosh-server नहीं मिला। इसे इंस्टॉल करें: sudo apt install mosh (Debian/Ubuntu) या sudo dnf install mosh (Fedora/RHEL)।';

  @override
  String moshBootstrapFailed(String detail) {
    return 'Mosh सत्र प्रारंभ करने में विफल: $detail';
  }

  @override
  String get moshUdpTimeout =>
      'Mosh कनेक्शन का समय समाप्त हो गया — जांचें कि फ़ायरवॉल द्वारा UDP ट्रैफ़िक अवरुद्ध तो नहीं है।';

  @override
  String get moshSessionTag => 'mosh';

  @override
  String get acpSessionRestored => 'एजेंट सत्र बहाल हुआ';

  @override
  String get acpSessionRestartNotice =>
      'एजेंट सत्र पुनः प्रारंभ हुआ — पिछला संदर्भ अनुपलब्ध';

  @override
  String get terminalTmuxInstallDialogTitle =>
      'रिमोट सर्वर पर tmux इंस्टॉल करें?';

  @override
  String get terminalTmuxInstallDialogMessage =>
      'डिस्कनेक्शन के दौरान टर्मिनल सत्रों को सुरक्षित रखने के लिए tmux आवश्यक है। क्या आप इसे अभी इंस्टॉल करना चाहते हैं?';

  @override
  String get terminalTmuxInstallCommandLabel => 'निष्पादित करने के लिए कमांड:';

  @override
  String get terminalTmuxInstallUnsupported =>
      'रिमोट सर्वर पर कोई समर्थित पैकेज प्रबंधक नहीं मिला। कृपया मैन्युअल रूप से tmux इंस्टॉल करें।';

  @override
  String get terminalTmuxInstallFailed =>
      'tmux इंस्टॉलेशन विफल रहा। कृपया सर्वर अनुमतियाँ और नेटवर्क सत्यापित करें।';

  @override
  String get terminalTmuxInstallDisconnected =>
      'SSH कनेक्शन टूट गया। tmux इंस्टॉल करने के लिए कृपया पुनः कनेक्ट करें।';

  @override
  String get terminalTmuxInstallInstalling => 'tmux इंस्टॉल हो रहा है...';

  @override
  String get terminalTmuxInstallConfirm => 'tmux इंस्टॉल करें';

  @override
  String get terminalTmuxInstallSkip => 'छोड़ें (साधारण शेल का उपयोग करें)';

  @override
  String get sftpDownload => 'डाउनलोड करें';

  @override
  String get sftpOpen => 'खोलें';

  @override
  String get sftpUploadFailed =>
      'अपलोड विफल रहा। अनुमतियाँ जांचें और पुनः प्रयास करें।';

  @override
  String get sftpDownloadFailed => 'डाउनलोड विफल रहा';

  @override
  String get sftpOpenUnsupported => 'यह फ़ाइल स्वरूप खोला नहीं जा सकता।';

  @override
  String get sftpReadFailed =>
      'फ़ाइल पढ़ने में विफल। अनुमतियाँ जांचें और पुनः प्रयास करें।';

  @override
  String get sftpTransferFailed =>
      'फ़ाइल संचालन विफल रहा। कृपया पुन: प्रयास करें।';

  @override
  String get sftpDownloadSuccess => 'सफलतापूर्वक डाउनलोड किया गया';

  @override
  String get sftpUploading => 'अपलोड हो रहा है...';

  @override
  String get sftpDownloading => 'डाउनलोड हो रहा है...';

  @override
  String get sftpUpDirectory => 'मूल निर्देशिका पर जाएं';

  @override
  String get sftpShowHiddenFiles => 'छिपी हुई फ़ाइलें दिखाएं';

  @override
  String get sftpHideHiddenFiles => 'छिपी हुई फ़ाइलें छिपाएं';

  @override
  String get sftpHiddenPreferenceSaveFailed =>
      'छिपी हुई फ़ाइलों की प्राथमिकता सहेजने में विफल';

  @override
  String get sftpSymlink => 'सिम्बोलिक लिंक';

  @override
  String get sftpLinkTargetUnavailable =>
      'सिम्बोलिक लिंक लक्ष्य अनुपलब्ध या टूटा हुआ है';

  @override
  String get sftpLinkTargetPermissionDenied =>
      'सिम्बोलिक लिंक लक्ष्य पढ़ने की अनुमति अस्वीकृत';

  @override
  String get settingsAutoConnect => 'लॉन्च पर ऑटो-कनेक्ट';

  @override
  String get settingsAutoConnectFixed => 'निश्चित डिफ़ॉल्ट SSH';

  @override
  String get settingsAutoConnectFixedDesc =>
      'हमेशा नीचे चुने गए सर्वर से कनेक्ट करें';

  @override
  String get settingsAutoConnectLast => 'अंतिम कनेक्शन याद रखें';

  @override
  String get settingsAutoConnectLastDesc =>
      'उस सर्वर से कनेक्ट करें जो पिछली बार सफलतापूर्वक कनेक्ट हुआ था';

  @override
  String get settingsAutoConnectPickServer => 'सर्वर';

  @override
  String get settingsAutoConnectNoServer => 'अभी तक कोई सर्वर चयनित नहीं है';

  @override
  String get sftpSort => 'क्रमबद्ध करें';

  @override
  String get sftpSortName => 'नाम';

  @override
  String get sftpSortSize => 'आकार';

  @override
  String get sftpSortDate => 'संशोधन तिथि';

  @override
  String get sftpSortAscending => 'आरोही';

  @override
  String get sftpSortDescending => 'अवरोही';

  @override
  String get themeQuickSwitch => 'थीम';

  @override
  String get transferList => 'स्थानांतरण';

  @override
  String get transferEmpty => 'अभी तक कोई स्थानांतरण नहीं';

  @override
  String get transferUpload => 'अपलोड';

  @override
  String get transferDownload => 'डाउनलोड';

  @override
  String get transferStatusQueued => 'कतारबद्ध';

  @override
  String get transferStatusRunning => 'स्थानांतरित हो रहा है';

  @override
  String get transferStatusPaused => 'रोका गया';

  @override
  String get transferStatusCompleted => 'पूर्ण';

  @override
  String get transferStatusFailed => 'विफल';

  @override
  String get transferStatusCanceled => 'रद्द किया गया';

  @override
  String get transferPause => 'रोकें';

  @override
  String get transferResume => 'फिर से शुरू करें';

  @override
  String get transferCancel => 'रद्द करें';

  @override
  String get transferRemove => 'हटाएं';

  @override
  String get transferClearFinished => 'पूर्ण किए गए हटाएं';

  @override
  String get transferSizeUnknown => 'आकार अज्ञात';

  @override
  String get transferFailedUpload => 'अपलोड विफल';

  @override
  String get transferFailedDownload => 'डाउनलोड विफल';

  @override
  String get stopGeneration => 'रोकें';

  @override
  String get chatServerBindingRequired =>
      'यह सत्र किसी सर्वर से बाध्य नहीं है। जारी रखने के लिए कृपया इसे वर्तमान सर्वर से बांधें।';

  @override
  String get chatSessionUnboundNotice => 'यह सत्र किसी सर्वर से बाध्य नहीं है।';

  @override
  String get bindServerAction => 'सर्वर से बांधें';

  @override
  String get bindServerDialogTitle => 'सत्र को सर्वर से बांधें';

  @override
  String get bindServerConfirmAction => 'बाध्यता की पुष्टि करें';

  @override
  String get chatSessionIdentityMismatch =>
      'वर्तमान सर्वर या एजेंट इस सत्र की बाध्य पहचान से मेल नहीं खाता। जारी रखने के लिए मेल खाने वाले सर्वर और एजेंट पर स्विच करें।';

  @override
  String get deleteSessionTitle => 'सत्र हटाएं';

  @override
  String get deleteSessionConfirmAction => 'हटाएं';

  @override
  String get shareAgentSessionsTitle => 'एजेंट सत्र साझा करें';

  @override
  String get shareAgentSessionsSubtitle =>
      'इस सर्वर पर विभिन्न एजेंटों के बीच सत्र साझा करें';

  @override
  String get shareAgentSessionsEnabled => 'एजेंट सत्र साझाकरण सक्षम';

  @override
  String get shareAgentSessionsDisabled => 'एजेंट सत्र साझाकरण अक्षम';

  @override
  String get agentCliStatusInstalled => 'CLI: स्थापित';

  @override
  String get agentCliStatusMissing => 'CLI: अनुपलब्ध';

  @override
  String get agentCliStatusChecking => 'CLI: जांच हो रही है...';

  @override
  String get agentCliStatusUnknown => 'CLI: अज्ञात';

  @override
  String get agentCliStatusError => 'CLI: त्रुटि';

  @override
  String get agentAcpStatusReady => 'ACP: तैयार';

  @override
  String get agentAcpStatusMissing => 'ACP: अनुपलब्ध';

  @override
  String get agentAcpStatusChecking => 'ACP: जांच हो रही है...';

  @override
  String get agentAcpStatusPendingCli => 'ACP: CLI लंबित';

  @override
  String get agentAcpStatusUnknown => 'ACP: अज्ञात';

  @override
  String get agentAcpStatusError => 'ACP: त्रुटि';

  @override
  String get agentAcpStatusNa => 'ACP: लागू नहीं';

  @override
  String get agentAuthStatusAuthenticated => 'प्रमाणीकरण: लॉग इन';

  @override
  String get agentAuthStatusUnauthenticated => 'प्रमाणीकरण: लॉग इन नहीं';

  @override
  String get agentAuthStatusUnknown => 'प्रमाणीकरण: अज्ञात';

  @override
  String get downloadNotificationsUnavailable =>
      'सिस्टम डाउनलोड सूचनाएं अनुपलब्ध हैं। डाउनलोड पृष्ठभूमि में जारी रहेंगे।';

  @override
  String get downloadOpenFailed => 'डाउनलोड की गई फ़ाइल खोलने में विफल।';

  @override
  String get dockerActionPending =>
      'इस कंटेनर के लिए एक कार्रवाई पहले से जारी है';

  @override
  String get dockerNoLogs => '(कोई लॉग नहीं)';

  @override
  String get serverReboot => 'रिबूट';

  @override
  String get serverRebootDialogTitle => 'सर्वर रिबूट की पुष्टि करें';

  @override
  String get serverRebootDialogMessage =>
      'क्या आप वाकई इस सर्वर को रीबूट करना चाहते हैं? सभी सक्रिय कनेक्शन और पृष्ठभूमि सेवाएं समाप्त हो जाएंगी।';

  @override
  String get serverRebootConfirmButton => 'अभी रिबूट करें';

  @override
  String get serverRebootPasswordTitle => 'Sudo पासवर्ड आवश्यक है';

  @override
  String get serverRebootPasswordMessage =>
      'सर्वर को रीबूट करने के लिए रूट विशेषाधिकार आवश्यक हैं। कृपया sudo पासवर्ड दर्ज करें (एक बार उपयोग किया जाता है, सहेजा नहीं जाता):';

  @override
  String get serverRebootPasswordHint => 'Sudo पासवर्ड';

  @override
  String get serverRebootSubmitting => 'रिबूट कमांड भेजा जा रहा है...';

  @override
  String get serverRebootAccepted =>
      'रिबूट कमांड स्वीकार किया गया; पूर्णता अभी सत्यापित नहीं हुई है। सर्वर ऑनलाइन वापस आने पर कृपया पुनः कनेक्ट करें।';

  @override
  String get serverRebootVerified =>
      'सर्वर रिबूट सत्यापित किया गया; सिस्टम ऑनलाइन वापस आ गया है।';

  @override
  String get serverRebootUnknown =>
      'रिबूट परिणाम अनिश्चित है। कमांड भेज दिया गया था, लेकिन पूर्णता की पुष्टि नहीं की जा सकी। कृपया मैन्युअल रूप से कनेक्शन की जांच करें।';

  @override
  String get serverRebootReconnect => 'पुनः कनेक्ट करें';

  @override
  String get serverRebootServerChanged =>
      'लक्ष्य सर्वर बदल गया, रिबूट रद्द कर दिया गया';

  @override
  String get navCliChat => 'CLI चैट';

  @override
  String get cliChatTitle => 'CLI सत्र';

  @override
  String get cliChatSubtitle => 'रिमोट सर्वर पर मूल CLI एजेंट सत्र';

  @override
  String get cliSelectAgent => 'एजेंट चुनें';

  @override
  String get cliNoAgentsConfigured =>
      'इस सर्वर के लिए कोई एजेंट नहीं जोड़ा गया';

  @override
  String get cliAgentNeedsSetup => 'एजेंट परिवेश अनुपलब्ध या लॉग इन नहीं है';

  @override
  String get cliManageAgentsGuide => 'एजेंट प्रबंधन में कॉन्फ़िगर करें';

  @override
  String get cliNewDraft => 'नया ड्राफ़्ट';

  @override
  String get cliNewDraftTooltip =>
      'एक खाली ड्राफ़्ट बनाएं (पहले संदेश पर सत्र बनता है)';

  @override
  String get cliDeleteSessionTitle => 'रिमोट CLI सत्र इतिहास हटाएं';

  @override
  String get cliDeleteSessionMessage =>
      'यह रिमोट सर्वर पर CLI सत्र इतिहास को स्थायी रूप से हटा देगा। क्या आप वाकई आगे बढ़ना चाहते हैं?';

  @override
  String get cliDeleteConfirmButton => 'सत्र हटाएं';

  @override
  String get cliCannotDeleteTooltip =>
      'रिमोट सत्र विलोपन समर्थित नहीं है या अक्षम है';

  @override
  String get cliSessionsHeader => 'सत्र';

  @override
  String get cliNoSessions => 'कोई CLI सत्र नहीं मिला';

  @override
  String get cliFilterCwdHint => 'CWD पथ द्वारा फ़िल्टर करें...';

  @override
  String get cliFilterCwdAction => 'फ़िल्टर करें';

  @override
  String get cliClearCwdAction => 'साफ़ करें';

  @override
  String get cliLoadMoreSessions => 'अधिक सत्र लोड करें';

  @override
  String get cliRefreshSessions => 'ताज़ा करें';

  @override
  String get cliClaudeReadOnlyNotice =>
      'Claude इतिहास केवल-पढ़ने के लिए है। वास्तविक टर्मिनल में बातचीत जारी रखें।';

  @override
  String get cliContinueInTerminal => 'टर्मिनल में जारी रखें';

  @override
  String get cliOpenTerminal => 'टर्मिनल खोलें';

  @override
  String get cliCloseTerminal => 'टर्मिनल बंद करें';

  @override
  String get cliTerminalRunning => 'इंटरैक्टिव CLI टर्मिनल';

  @override
  String get cliAgyTerminalOnlyNotice =>
      'यह एजेंट संरचित इतिहास सिंक्रनाइज़ेशन का समर्थन नहीं करता है। बातचीत और सत्र चयन के लिए कृपया मूल CLI टर्मिनल का उपयोग करें।';

  @override
  String get cliInstallSdkTitle => 'आधिकारिक Claude History SDK इंस्टॉल करें';

  @override
  String get cliInstallSdkMessage =>
      'रिमोट सर्वर पर आधिकारिक Claude Code History SDK अनुपलब्ध है। क्या आप इसे अभी इंस्टॉल करना चाहते हैं?';

  @override
  String get cliInstallSdkAction => 'आधिकारिक SDK इंस्टॉल करें';

  @override
  String get cliApprovalsTitle => 'लंबित स्वीकृतियां';

  @override
  String get cliApprovalDetails => 'विवरण';

  @override
  String get cliApprovalAllow => 'अनुमति दें';

  @override
  String get cliApprovalDecline => 'अस्वीकार करें';

  @override
  String get cliInputHint => 'CLI एजेंट को एक संदेश लिखें...';

  @override
  String get cliSend => 'भेजें';

  @override
  String get cliStop => 'रोकें';

  @override
  String get cliBusy => 'ऑपरेशन जारी है, कृपया प्रतीक्षा करें...';

  @override
  String get cliDisconnected => 'SSH कनेक्टेड नहीं है';

  @override
  String get cliServerChanged => 'लक्ष्य सर्वर बदल गया';

  @override
  String get cliTurnFailed => 'CLI टर्न निष्पादन विफल रहा';

  @override
  String get cliUseTerminal =>
      'इंटरैक्टिव प्रॉम्प्ट आवश्यक है, जारी रखने के लिए कृपया टर्मिनल खोलें';

  @override
  String get cliDeleteFailed => 'रिमोट सत्र हटाने में विफल';

  @override
  String get cliDeleteUnsupported =>
      'इस CLI द्वारा रिमोट सत्रों को हटाना समर्थित नहीं है';

  @override
  String get cliOperationFailed => 'CLI ऑपरेशन विफल रहा';

  @override
  String get cliHistorySdkMissing =>
      'सर्वर पर आधिकारिक History SDK अनुपलब्ध है';

  @override
  String get cliHistoryRuntimeMissing =>
      'Claude इतिहास के लिए सर्वर पर Node.js/npm आवश्यक है। कृपया मैन्युअल रूप से Node.js इंस्टॉल करें; आप अभी भी टर्मिनल में वास्तविक CLI का उपयोग कर सकते हैं।';

  @override
  String get cliLoginRequired =>
      'एजेंट लॉगिन आवश्यक है। कृपया एजेंट प्रबंधन के माध्यम से लॉग इन करें।';

  @override
  String get cliNotInstalled =>
      'एजेंट CLI स्थापित नहीं है। कृपया इसे एजेंट प्रबंधन के माध्यम से स्थापित करें।';

  @override
  String get cliVersionUnsupported =>
      'एजेंट CLI संस्करण असमर्थित है। कृपया एजेंट प्रबंधन के माध्यम से अपग्रेड या पुनः स्थापित करें।';

  @override
  String get settingsNavigation => 'नेविगेशन';

  @override
  String get settingsNavigationDesc =>
      'डिफ़ॉल्ट स्टार्टअप पृष्ठ और निचला नेविगेशन बार कॉन्फ़िगर करें';

  @override
  String get settingsStartupPage => 'स्टार्टअप पृष्ठ';

  @override
  String get settingsStartupPageDesc => 'ऐप खुलने पर प्रदर्शित होने वाला पृष्ठ';

  @override
  String get settingsBottomNav => 'निचला नेविगेशन बार';

  @override
  String get settingsBottomNavDesc =>
      'मोबाइल निचले बार में प्रदर्शित करने के लिए अनुभाग चुनें (0 से 9 आइटम समर्थित)';

  @override
  String get settingsResetSuccess => 'सभी सेटिंग्स डिफ़ॉल्ट पर बहाल कर दी गईं';

  @override
  String get metricsTrendSubtitle => 'अंतिम ~3 मिनट (अधिकतम 60 नमूने)';

  @override
  String get metricsCurrent => 'वर्तमान';

  @override
  String get metricsPeak => 'शिखर';

  @override
  String get metricsValley => 'गर्त';

  @override
  String get metricsTrendWaiting => 'मेट्रिक्स डेटा एकत्र किया जा रहा है...';

  @override
  String get metricsTrendStopped => 'डेटा संग्रह रुका (SSH डिस्कनेक्टेड)';

  @override
  String get dockerActionTerminal => 'Exec टर्मिनल';

  @override
  String get dockerTerminalTitle => 'कंटेनर टर्मिनल';

  @override
  String get dockerTerminalNotRunning => 'कंटेनर नहीं चल रहा है';

  @override
  String get setDefaultAgent => 'डिफ़ॉल्ट के रूप में सेट करें';

  @override
  String get defaultBadge => 'डिफ़ॉल्ट';

  @override
  String get isDefaultAgent => 'डिफ़ॉल्ट एजेंट';

  @override
  String get setAsDefaultAgent =>
      'इस सर्वर के लिए डिफ़ॉल्ट एजेंट के रूप में सेट करें';

  @override
  String get agentGroupBasic => 'मूल जानकारी';

  @override
  String get agentGroupCommands => 'कमांड्स';

  @override
  String get agentGroupAuth => 'इंस्टॉलेशन और प्रमाणीकरण';

  @override
  String get agentPresetTitle => 'प्रीसेट टेम्प्लेट';

  @override
  String get resourceProcessList => 'प्रक्रियाएं';

  @override
  String get resourceDiskScanning =>
      'रूट डायरेक्टरीज़ स्कैन की जा रही हैं, इसमें कुछ सेकंड लग सकते हैं...';

  @override
  String get resourceDiskScanPartial =>
      'अनुमतियों या समय समाप्त होने के कारण कुछ डायरेक्टरीज़ स्कैन नहीं की जा सकीं';

  @override
  String get resourceDiskDirectories => 'शीर्ष-स्तरीय डायरेक्टरी उपयोग';

  @override
  String get resourceSortCpu => 'CPU के अनुसार क्रमबद्ध करें';

  @override
  String get resourceSortMemory => 'मेमोरी के अनुसार क्रमबद्ध करें';

  @override
  String get resourceRss => 'RSS मेमोरी';

  @override
  String get resourceUsed => 'प्रयुक्त';

  @override
  String get resourceAvailable => 'उपलब्ध';

  @override
  String get resourceTotal => 'कुल';

  @override
  String get settingsBottomNavOrderTitle =>
      'चयनित आइटम (पुनः व्यवस्थित करने के लिए खींचें)';

  @override
  String get langSystem => 'सिस्टम का पालन करें';

  @override
  String get serverFieldRequired => 'आवश्यक है';

  @override
  String get serverPortInvalid => 'पोर्ट 1 और 65535 के बीच होना चाहिए';

  @override
  String get serverTestReachability => 'पहुंच का परीक्षण करें';

  @override
  String get serverSaveFailedGeneric =>
      'सर्वर सहेजने में विफल। कृपया अपने कॉन्फ़िगरेशन की जांच करें और पुनः प्रयास करें।';

  @override
  String get serverViewPrivateKey => 'निजी कुंजी देखें';

  @override
  String get serverHidePrivateKey => 'निजी कुंजी छुपाएं';

  @override
  String get dockerBashFallbackNotice =>
      'कंटेनर में Bash अनुपलब्ध है, Sh का उपयोग किया जा रहा है';

  @override
  String get dockerShellLabel => 'शेल';

  @override
  String get dockerShellBash => 'Bash';

  @override
  String get dockerShellSh => 'Sh';

  @override
  String get cliDraftWorkingDirLabel => 'कार्यशील डायरेक्टरी';

  @override
  String get cliDefaultWorkingDir => 'डिफ़ॉल्ट (/)';

  @override
  String get cliPickWorkingDirTitle => 'कार्यशील डायरेक्टरी चुनें';

  @override
  String get cliClearWorkingDir => 'डिफ़ॉल्ट पर रीसेट करें';

  @override
  String get cliBrowseWorkingDir => 'ब्राउज़ करें';

  @override
  String get cliSelectCurrentDir => 'इस डायरेक्टरी का चयन करें';

  @override
  String get cliNavigateUp => 'ऊपर जाएं';

  @override
  String get chatSessionsTooltip => 'सत्र';

  @override
  String get hardwareSpecsTitle => 'हार्डवेयर और सिस्टम';

  @override
  String get hardwareCpu => 'CPU';

  @override
  String get hardwareMemory => 'मेमोरी';

  @override
  String get hardwareDisk => 'रूट डिस्क';

  @override
  String get hardwareDistribution => 'OS';

  @override
  String get hardwareKernel => 'कर्नेल';

  @override
  String get hardwareLoading => 'हार्डवेयर विवरण लोड हो रहा है...';

  @override
  String get hardwareUnavailable => 'हार्डवेयर विवरण अनुपलब्ध';

  @override
  String get hardwareUnknown => 'अज्ञात';

  @override
  String get systemInfoTitle => 'सिस्टम जानकारी';

  @override
  String get systemInfoTapHint => 'ASCII आर्ट देखने के लिए टैप करें';

  @override
  String get systemInfoHost => 'होस्ट';

  @override
  String get serverShutdown => 'शटडाउन';

  @override
  String get serverShutdownDialogTitle => 'सर्वर शटडाउन की पुष्टि करें';

  @override
  String get serverShutdownDialogMessage =>
      'क्या आप वाकई इस सर्वर को बंद करना चाहते हैं? सिस्टम पूरी तरह से बंद हो जाएगा और मैन्युअल रूप से चालू होने तक इसे दूरस्थ रूप से एक्सेस नहीं किया जा सकता है।';

  @override
  String get serverShutdownConfirmButton => 'अभी शटडाउन करें';

  @override
  String get serverShutdownSubmitting => 'शटडाउन कमांड भेजा जा रहा है...';

  @override
  String get serverShutdownAccepted =>
      'शटडाउन कमांड स्वीकार किया गया; शटडाउन पूर्णता अभी सत्यापित नहीं हुई है।';

  @override
  String get serverShutdownUnknown =>
      'शटडाउन परिणाम अज्ञात: कमांड भेजा गया हो सकता है लेकिन पुष्टि नहीं की जा सकी। कृपया मैन्युअल रूप से जांचें; यह स्वचालित रूप से पुनः प्रयास नहीं करेगा।';

  @override
  String get serverShutdownPasswordTitle =>
      'शटडाउन के लिए Sudo पासवर्ड आवश्यक है';

  @override
  String get serverShutdownPasswordMessage =>
      'सर्वर को बंद करने के लिए रूट विशेषाधिकार आवश्यक हैं। कृपया sudo पासवर्ड दर्ज करें (एक बार उपयोग किया जाता है, सहेजा नहीं जाता):';

  @override
  String get serverShutdownPasswordHint => 'Sudo पासवर्ड';

  @override
  String get serverShutdownServerChanged =>
      'लक्ष्य सर्वर बदल गया, शटडाउन रद्द किया गया';

  @override
  String get metricsNetwork => 'नेटवर्क दर';

  @override
  String get networkModalTitle => 'नेटवर्क इंटरफ़ेस विवरण';

  @override
  String get networkDownloadRate => 'डाउनलोड (RX)';

  @override
  String get networkUploadRate => 'अपलोड (TX)';

  @override
  String get networkTotalRx => 'कुल RX';

  @override
  String get networkTotalTx => 'कुल TX';

  @override
  String get networkPrimary => 'डिफ़ॉल्ट रूट';

  @override
  String get networkRatesEmpty => 'कोई सक्रिय नेटवर्क इंटरफ़ेस नहीं मिला';

  @override
  String get networkWaitingSecondSample =>
      'दूसरे नमूने की प्रतीक्षा की जा रही है';

  @override
  String get networkUnavailable => 'अनुपलब्ध';

  @override
  String get networkNoDefaultInterface => 'कोई डिफ़ॉल्ट रूट नहीं';

  @override
  String get selectThemeModeTitle => 'थीम मोड चुनें';

  @override
  String get selectLanguageTitle => 'भाषा चुनें';

  @override
  String get selectStartupPageTitle => 'स्टार्टअप पृष्ठ चुनें';

  @override
  String get selectAutoConnectModeTitle => 'ऑटो-कनेक्ट मोड चुनें';

  @override
  String get accentColorDialogTitle => 'एक्सेंट रंग अनुकूलित करें';

  @override
  String get accentColorLightMode => 'लाइट मोड';

  @override
  String get accentColorDarkMode => 'डार्क मोड';

  @override
  String get accentColorAmoledMode => 'AMOLED (गीक)';

  @override
  String get accentColorPresets => 'प्रीसेट';

  @override
  String get accentColorHsvPicker => 'कलर व्हील';

  @override
  String get accentColorHexCode => 'हेक्स रंग कोड';

  @override
  String get accentColorPreview => 'पूर्वावलोकन';

  @override
  String get accentColorSampleButton => 'एक्सेंट बटन';

  @override
  String get accentColorInvalidHex => 'अमान्य हेक्स प्रारूप (उदा. #10B981)';

  @override
  String get settingsDashboardQuickActions => 'डैशबोर्ड त्वरित क्रियाएं';

  @override
  String get settingsDashboardQuickActionsDesc =>
      'डैशबोर्ड पर दिखाए गए त्वरित शॉर्टकट प्रविष्टियां कॉन्फ़िगर करें। साफ़ करने पर त्वरित क्रिया अनुभाग छिप जाएगा।';

  @override
  String get settingsDashboardQuickActionsEmpty =>
      'त्वरित क्रियाएं छिपी हुई हैं (कोई शॉर्टकट चयनित नहीं)';

  @override
  String get settingsDashboardQuickActionsOrderTitle =>
      'शॉर्टकट पुन: व्यवस्थित करने के लिए खींचें';

  @override
  String get settingsDashboardQuickActionsCandidates =>
      'दृश्यमान शॉर्टकट चुनें';

  @override
  String get terminalCopySelection => 'कॉपी करें';

  @override
  String get terminalSelectionCopied => 'चयन क्लिपबोर्ड पर कॉपी किया गया';

  @override
  String get editAgent => 'एजेंट संपादित करें';

  @override
  String get agentExecutionTarget => 'निष्पादन परिवेश';

  @override
  String get agentExecutionHost => 'होस्ट सिस्टम';

  @override
  String get agentExecutionDocker => 'Docker कंटेनर';

  @override
  String get agentContainerBinding => 'कंटेनर बाइंडिंग मोड';

  @override
  String get agentContainerBindingId => 'कंटेनर ID द्वारा';

  @override
  String get agentContainerBindingName => 'कंटेनर नाम द्वारा';

  @override
  String get agentContainerReference => 'लक्ष्य कंटेनर';

  @override
  String get agentContainerReferenceHint =>
      'कंटेनर ID या नाम चुनें या दर्ज करें';

  @override
  String get agentContainerRequired =>
      'Docker निष्पादन के लिए लक्ष्य कंटेनर आवश्यक है';

  @override
  String get agentLoadingContainers =>
      'सर्वर पर कंटेनरों की जानकारी प्राप्त की जा रही है...';

  @override
  String get agentNoContainersFound => 'इस सर्वर पर कोई कंटेनर नहीं मिला';

  @override
  String get agentContainerUser => 'कंटेनर निष्पादन उपयोगकर्ता (वैकल्पिक)';

  @override
  String get agentContainerUserHint => 'उदा. dev';

  @override
  String get agentContainerUserHelper =>
      'छवि के डिफ़ॉल्ट उपयोगकर्ता का उपयोग करने के लिए खाली छोड़ें; उदा. dev; उपयोगकर्ता, UID, user:group, UID:GID का समर्थन करता है';

  @override
  String get agentContainerUserSelect => 'कंटेनर उपयोगकर्ता चुनें';

  @override
  String get agentContainerUsersLoading => 'उपयोगकर्ता लोड हो रहे हैं...';

  @override
  String get agentContainerUsersEmpty => 'कोई passwd उपयोगकर्ता नहीं मिला';

  @override
  String get agentViewDiagnosticLog => 'निदान लॉग देखें';

  @override
  String get agentDiagnosticLogCopied =>
      'निदान लॉग क्लिपबोर्ड पर कॉपी किया गया';

  @override
  String get agentDiagnosticLogCopy => 'कॉपी करें';

  @override
  String get agentDiagnosticLogClose => 'बंद करें';

  @override
  String get settingsCliHistoryPageSize => 'CLI इतिहास पृष्ठ आकार';

  @override
  String get settingsCliHistoryPageSizeDesc =>
      'ऊपर स्क्रॉल करते समय प्रति पृष्ठ लोड किए गए पुराने संदेशों की संख्या (5-100)';

  @override
  String get settingsCliHistoryPageSizeTitle => 'CLI इतिहास पृष्ठ आकार चुनें';

  @override
  String get cliLoadingOlderMessages => 'पुराने संदेश लोड हो रहे हैं...';

  @override
  String get chatLoadOlderMessages => 'पहले के संदेश लोड करें';

  @override
  String get chatCommandsTooltip => 'कमांड्स';

  @override
  String get chatAttachTooltip => 'फ़ाइल संलग्न करें';

  @override
  String get chatAttachImage => 'स्थानीय छवि संलग्न करें';

  @override
  String get chatAttachLocalText => 'स्थानीय टेक्स्ट फ़ाइल संलग्न करें';

  @override
  String get chatAttachRemoteText => 'रिमोट टेक्स्ट फ़ाइल संलग्न करें';

  @override
  String get chatAttachRemotePathTitle => 'रिमोट टेक्स्ट फ़ाइल संलग्न करें';

  @override
  String get chatAttachRemotePathHint => '/path/to/file.txt';

  @override
  String get chatAttachTooLarge => 'फ़ाइल आकार सीमा से अधिक है';

  @override
  String get chatUsageAndDiagnostics => 'उपयोग और निदान';

  @override
  String get chatWorkingDirTooltip => 'ड्राफ़्ट कार्यशील डायरेक्टरी';

  @override
  String get chatAttachFailed => 'फ़ाइल संलग्न करने में विफल';

  @override
  String get chatInvalidRemotePath =>
      'अमान्य रिमोट फ़ाइल पथ (/ से शुरू होना चाहिए)';

  @override
  String get chatRemoteReadFailed => 'रिमोट फ़ाइल पढ़ने में विफल';

  @override
  String get chatInvalidDirPath =>
      'अमान्य डायरेक्टरी पथ (/ से शुरू होना चाहिए)';

  @override
  String get chatNoSubdirectories => 'कोई सब-डायरेक्टरी नहीं';

  @override
  String get chatUsageTitle => 'टोकन और लागत उपयोग';

  @override
  String get chatUsageUsed => 'प्रयुक्त टोकन';

  @override
  String get chatUsageSize => 'संदर्भ आकार';

  @override
  String get chatUsageCost => 'लागत';

  @override
  String get chatDiagnosticsTitle => 'निदान लॉग';

  @override
  String get chatNoDiagnostics => 'कोई निदान लॉग उपलब्ध नहीं है';

  @override
  String get deleteSessionLocalOnlyNotice =>
      'यह केवल Valhalla में स्थानीय रिकॉर्ड हटाता है और सर्वर पर मूल एजेंट सत्र इतिहास को नहीं हटाएगा।';

  @override
  String get chatSearchSessionsHint => 'सत्र खोजें...';

  @override
  String get chatLoadMoreSessions => 'अधिक सत्र लोड करें';

  @override
  String get chatLoadingMoreSessions => 'अधिक सत्र लोड हो रहे हैं...';

  @override
  String get chatExportSession => 'सत्र निर्यात करें (Markdown)';

  @override
  String get chatExportSuccess => 'सत्र सफलतापूर्वक निर्यात किया गया';

  @override
  String get chatExportFailed => 'सत्र निर्यात करने में विफल';

  @override
  String get chatRemoteSessions => 'रिमोट सत्र';

  @override
  String get chatRemoteSessionsTitle => 'रिमोट एजेंट सत्र';

  @override
  String get chatRemoteSessionsDesc =>
      'रिमोट एजेंट से मूल सत्र इतिहास देखें और आयात करें';

  @override
  String get chatRemoteSessionsEmpty => 'कोई रिमोट सत्र नहीं मिला';

  @override
  String get chatRemoteImporting => 'रिमोट सत्र इतिहास आयात किया जा रहा है...';

  @override
  String get chatRemoteImportFailed => 'रिमोट सत्र आयात करने में विफल';

  @override
  String get chatStatusInterrupted => 'बाधित';

  @override
  String get chatStatusFailed => 'विफल';

  @override
  String get chatStatusAwaitingAuth => 'ACP प्रमाणीकरण की प्रतीक्षा है';

  @override
  String get chatShowFullOutput => 'पूरा आउटपुट दिखाएं';

  @override
  String get chatShowLessOutput => 'कम दिखाएं';

  @override
  String get chatToolLocations => 'प्रभावित पथ';

  @override
  String cmdParamPlaceholder(String param) {
    return '$param के लिए मान दर्ज करें';
  }

  @override
  String processTerminateSuccess(Object pid) {
    return 'प्रक्रिया $pid समाप्त की गई';
  }

  @override
  String serviceActionSuccess(Object action, Object service) {
    return '$service पर कार्रवाई $action सफल रही';
  }

  @override
  String riskPatternMatched(Object pattern) {
    return 'ट्रिगर हुआ नियम: $pattern';
  }

  @override
  String stateExitCode(Object code) {
    return 'एग्जिट कोड: $code';
  }

  @override
  String sshConnectedSuccess(Object server) {
    return 'SSH के माध्यम से $server से सफलतापूर्वक कनेक्ट हुआ';
  }

  @override
  String sshConnectionFailed(Object error) {
    return 'SSH कनेक्शन विफल: $error';
  }

  @override
  String trustHostFingerprintMessage(
    Object fingerprint,
    Object host,
    Object type,
  ) {
    return 'पहली बार $host ($type) से कनेक्ट हो रहे हैं।\n\nSHA-256 फ़िंगरप्रिंट:\n$fingerprint\n\nक्या इस फ़िंगरप्रिंट पर भरोसा करें और कनेक्ट करें?';
  }

  @override
  String enterPasswordTitle(Object server) {
    return '$server के लिए पासवर्ड दर्ज करें';
  }

  @override
  String confirmDeleteServerMessage(Object name) {
    return 'क्या आप वाकई सर्वर \'$name\' हटाना चाहते हैं? इस कार्रवाई को पूर्ववत नहीं किया जा सकता है।';
  }

  @override
  String deleteAgentMessage(Object name) {
    return 'क्या आप वाकई एजेंट \'$name\' हटाना चाहते हैं? यह ऐतिहासिक चैट सत्रों या SSH क्रेडेंशियल्स को प्रभावित किए बिना इस सर्वर पर इसके कॉन्फ़िगरेशन और रनटाइम स्थिति को हटा देता है।';
  }

  @override
  String agentLastChecked(Object time) {
    return 'अंतिम जांच: $time';
  }

  @override
  String agentAuthPickerTitle(Object agent) {
    return 'चुनें कि $agent में कैसे लॉग इन करना है';
  }

  @override
  String sshStatusReconnecting(Object n) {
    return 'पुनः कनेक्ट हो रहा है… (प्रयास $n)';
  }

  @override
  String sshKeepAliveNotificationBody(Object n) {
    return '$n सक्रिय सत्र';
  }

  @override
  String bindServerConfirmMessage(Object serverName) {
    return 'क्या इस सत्र को सर्वर \"$serverName\" से बांधें? एक बार बंध जाने के बाद, यह सत्र इस सर्वर से संबद्ध हो जाएगा।';
  }

  @override
  String deleteSessionConfirmMessage(Object title) {
    return 'क्या आप वाकई सत्र \"$title\" हटाना चाहते हैं? इस कार्रवाई को पूर्ववत नहीं किया जा सकता है।';
  }

  @override
  String dockerActionSuccess(Object action, Object name) {
    return 'कंटेनर $name $action सफल रहा';
  }

  @override
  String dockerActionFailed(Object error) {
    return 'कार्रवाई विफल: $error';
  }

  @override
  String serverRebootTarget(Object address, Object name) {
    return 'लक्ष्य सर्वर: $name ($address)';
  }

  @override
  String serverRebootRunningTerminals(Object count) {
    return 'टर्मिनल सत्र: $count';
  }

  @override
  String serverRebootRunningAgents(Object count) {
    return 'एजेंट सत्र: $count';
  }

  @override
  String serverRebootRunningTransfers(Object count) {
    return 'सक्रिय स्थानांतरण: $count';
  }

  @override
  String serverRebootFailed(Object error) {
    return 'रिबूट विफल: $error';
  }

  @override
  String cliDeleteFailedWithDetail(Object detail) {
    return 'रिमोट सत्र हटाने में विफल: $detail';
  }

  @override
  String metricsTrendTitle(Object metric) {
    return '$metric रुझान';
  }

  @override
  String metricsThresholdWarning(Object value) {
    return 'चेतावनी: $value';
  }

  @override
  String metricsThresholdDanger(Object value) {
    return 'खतरा: $value';
  }

  @override
  String metricsHistoryPoints(Object count) {
    return '$count डेटा बिंदु';
  }

  @override
  String resourceUsageTitle(Object metric) {
    return '$metric संसाधन उपयोग';
  }

  @override
  String serverPortReachable(Object port) {
    return 'TCP पोर्ट $port पहुंच योग्य है';
  }

  @override
  String serverConnectionFailed(Object error) {
    return 'कनेक्शन विफल: $error';
  }

  @override
  String serverSaveFailed(Object error) {
    return 'सर्वर सहेजने में विफल: $error';
  }

  @override
  String hardwareCpuCores(Object cores) {
    return '$cores कोर';
  }

  @override
  String serverShutdownFailed(Object error) {
    return 'शटडाउन विफल: $error';
  }

  @override
  String networkInterface(Object name) {
    return 'इंटरफ़ेस: $name';
  }

  @override
  String agentContainersLoadFailed(Object error) {
    return 'कंटेनर लोड करने में विफल: $error';
  }

  @override
  String agentContainerUsersFailed(Object error) {
    return 'कंटेनर उपयोगकर्ता लोड करने में विफल: $error';
  }

  @override
  String agentDiagnosticLogTitle(Object name) {
    return 'निदान लॉग - $name';
  }

  @override
  String get agentDockerDetectionFailed => 'Docker/कंटेनर पहचान विफल';

  @override
  String get chatCopiedAllMessages => 'सभी संदेश कॉपी किए गए';

  @override
  String get chatCopyAllMessages => 'सभी संदेश कॉपी करें';

  @override
  String get cliModelAtCapacity =>
      'चयनित मॉडल पूरी क्षमता पर है। कोई अन्य मॉडल आज़माएं।';

  @override
  String get chatLaunchBlankDraft => 'खाली ड्राफ़्ट';

  @override
  String get chatLaunchFixedSession => 'निश्चित सत्र';

  @override
  String get chatLaunchRememberLast => 'अंतिम सत्र याद रखें';

  @override
  String get chatPermissionAskEveryTime => 'हर बार पूछें';

  @override
  String get chatPermissionAutoAllowAll => 'स्वचालित रूप से सभी की अनुमति दें';

  @override
  String get chatPermissionAutoAllowAllConfirmMessage =>
      'एजेंट बिना पूछे सभी ऑपरेशनों को निष्पादित करेगा। क्या जारी रखें?';

  @override
  String get chatPermissionAutoAllowAllConfirmTitle =>
      'सभी ऑपरेशनों की अनुमति दें?';

  @override
  String get chatPermissionAutoAllowSafe =>
      'सुरक्षित ऑपरेशनों को स्वचालित रूप से अनुमति दें';

  @override
  String get chatRunSettingsDefault => 'डिफ़ॉल्ट';

  @override
  String get chatRunSettingsInteractiveCli => 'इंटरैक्टिव CLI';

  @override
  String get chatRunSettingsModel => 'मॉडल';

  @override
  String get chatRunSettingsPermissions => 'अनुमतियाँ';

  @override
  String get chatRunSettingsReasoning => 'तर्क स्तर';

  @override
  String get chatRunSettingsTitle => 'रन सेटिंग्स';

  @override
  String get cliActionInsertCommand => 'कमांड डालें';

  @override
  String get cliActionInsertFile => 'फ़ाइल डालें';

  @override
  String get cliActionInsertWorkdir => 'कार्यशील डायरेक्टरी डालें';

  @override
  String get cliComposerInsertAction => 'डालें';

  @override
  String cliOperationFailedWithDetail(String detail) {
    return 'CLI ऑपरेशन विफल: $detail';
  }

  @override
  String get cliSelectCommandTitle => 'कमांड चुनें';

  @override
  String get defaultAgentTitle => 'डिफ़ॉल्ट एजेंट';

  @override
  String get insertSkills => 'कौशल डालें';

  @override
  String get isDefaultSession => 'डिफ़ॉल्ट सत्र';

  @override
  String get sessionLaunchMode => 'सत्र लॉन्च मोड';

  @override
  String get setAsDefaultSession => 'डिफ़ॉल्ट सत्र के रूप में सेट करें';

  @override
  String get navNas => 'NAS मीडिया';

  @override
  String get nasAddExcludePath => 'अपवर्जित पथ जोड़ें';

  @override
  String get nasAddIncludePath => 'स्कैन पथ जोड़ें';

  @override
  String get nasCancelScan => 'स्कैन रद्द करें';

  @override
  String get nasClearSearch => 'खोज साफ़ करें';

  @override
  String get nasConfigDialogTitle => 'मीडिया लाइब्रेरी सेटिंग्स';

  @override
  String get nasConfigure => 'कॉन्फ़िगर करें';

  @override
  String get nasConfigureScanDirs => 'स्कैन फ़ोल्डर कॉन्फ़िगर करें';

  @override
  String get nasCreatePlaylist => 'प्लेलिस्ट बनाएं';

  @override
  String get nasEmptyConfigDesc =>
      'अपनी मीडिया लाइब्रेरी बनाना शुरू करने के लिए कम से कम एक फ़ोल्डर जोड़ें।';

  @override
  String get nasEmptyConfigTitle => 'कोई स्कैन फ़ोल्डर कॉन्फ़िगर नहीं है';

  @override
  String get nasExcludePaths => 'अपवर्जित फ़ोल्डर';

  @override
  String get nasExcludedBadge => 'अपवर्जित';

  @override
  String get nasFilterImages => 'छवियां';

  @override
  String get nasFilterVideos => 'वीडियो';

  @override
  String get nasIncludePaths => 'स्कैन फ़ोल्डर';

  @override
  String nasItemCount(Object value) {
    return '$value आइटम';
  }

  @override
  String nasLastScan(Object value) {
    return 'अंतिम स्कैन: $value';
  }

  @override
  String get nasLibrarySettings => 'लाइब्रेरी सेटिंग्स';

  @override
  String nasMediaOpening(Object value) {
    return '$value खोला जा रहा है…';
  }

  @override
  String get nasMiniPlayer => 'मिनी प्लेयर';

  @override
  String get nasNoExcludePaths => 'कोई अपवर्जित फ़ोल्डर नहीं';

  @override
  String get nasNoFavorites => 'अभी तक कोई पसंदीदा नहीं';

  @override
  String get nasNoIncludePaths => 'कोई स्कैन फ़ोल्डर नहीं';

  @override
  String get nasNoIndexDesc =>
      'अपने मीडिया को अनुक्रमित करने के लिए फ़ोल्डर कॉन्फ़िगर करें और स्कैन चलाएं।';

  @override
  String get nasNoIndexTitle => 'मीडिया लाइब्रेरी खाली है';

  @override
  String get nasNoPlaylists => 'अभी तक कोई प्लेलिस्ट नहीं';

  @override
  String get nasNoSearchResults => 'कोई मेल खाने वाला मीडिया नहीं मिला';

  @override
  String get nasNotScanned => 'अभी तक स्कैन नहीं किया गया';

  @override
  String get nasNowPlaying => 'अब चल रहा है';

  @override
  String get nasOpenMethodPrompt => 'आप इस फ़ाइल को कैसे खोलना चाहेंगे?';

  @override
  String get nasOpenPolicyAsk => 'हर बार पूछें';

  @override
  String get nasOpenPolicyExternal => 'किसी अन्य ऐप से खोलें';

  @override
  String get nasOpenPolicyInApp => 'ऐप में खोलें';

  @override
  String get nasOpeningPolicy => 'डिफ़ॉल्ट खोलने की विधि';

  @override
  String get nasPlaylistName => 'प्लेलिस्ट का नाम';

  @override
  String get nasQuickStats => 'लाइब्रेरी अवलोकन';

  @override
  String get nasScan => 'अभी स्कैन करें';

  @override
  String get nasScanCancelled => 'स्कैन रद्द कर दिया गया';

  @override
  String nasScanFailed(Object value) {
    return 'स्कैन विफल रहा: $value';
  }

  @override
  String get nasScanning => 'स्कैन हो रहा है…';

  @override
  String get nasScopeBadge => 'स्कैन दायरा';

  @override
  String get nasSearchHint => 'मीडिया खोजें';

  @override
  String get nasStatMusic => 'संगीत';

  @override
  String get nasStatPhotos => 'फ़ोटो';

  @override
  String get nasStatTotal => 'कुल';

  @override
  String get nasStatVideos => 'वीडियो';

  @override
  String get nasTabFavorites => 'पसंदीदा';

  @override
  String get nasTabFolders => 'फ़ोल्डर';

  @override
  String get nasTabHome => 'होम';

  @override
  String get nasTabMusic => 'संगीत';

  @override
  String get nasTabPhotos => 'फ़ोटो';

  @override
  String get nasTabPlaylists => 'प्लेलिस्ट';

  @override
  String get nasTabVideos => 'वीडियो';

  @override
  String get nasSources => 'मीडिया स्रोत';

  @override
  String get nasAddSource => 'मीडिया स्रोत जोड़ें';

  @override
  String get nasEditSource => 'मीडिया स्रोत संपादित करें';

  @override
  String get nasRemoveSource => 'मीडिया स्रोत हटाएं';

  @override
  String nasRemoveSourceConfirm(Object name) {
    return 'क्या आप वाकई मीडिया स्रोत \'$name\' हटाना चाहते हैं? यह रिमोट फ़ाइलों को हटाए बिना इसके कॉन्फ़िगरेशन को हटा देता है।';
  }

  @override
  String get nasNoSources => 'कोई मीडिया स्रोत कॉन्फ़िगर नहीं है';

  @override
  String get nasNoSourcesDesc =>
      'मीडिया ब्राउज़ करना शुरू करने के लिए SFTP, SMB, WebDAV, Jellyfin, या Emby जोड़ें।';

  @override
  String get nasSourceType => 'स्रोत प्रकार';

  @override
  String get nasSourceName => 'स्रोत नाम';

  @override
  String get nasProbe => 'कनेक्शन का परीक्षण करें';

  @override
  String get nasProbeSuccess => 'कनेक्शन सफल';

  @override
  String get nasProbeFailed => 'कनेक्शन परीक्षण विफल रहा';

  @override
  String get nasEndpoint => 'एंडपॉइंट / URL';

  @override
  String get nasRootPath => 'रूट पथ';

  @override
  String get nasUsername => 'उपयोगकर्ता नाम';

  @override
  String get nasPassword => 'पासवर्ड';

  @override
  String get nasDomain => 'डोमेन (वैकल्पिक)';

  @override
  String get nasAuthenticate => 'प्रमाणित करें';

  @override
  String get nasAuthSuccess => 'प्रमाणीकरण सफल';

  @override
  String get nasAuthFailed => 'प्रमाणीकरण विफल';

  @override
  String get nasTabDownloads => 'डाउनलोड';

  @override
  String get nasNoDownloads => 'कोई डाउनलोड कार्य नहीं';

  @override
  String get nasDownloadQueued => 'कतारबद्ध';

  @override
  String get nasDownloadDownloading => 'डाउनलोड हो रहा है';

  @override
  String get nasDownloadCompleted => 'पूर्ण';

  @override
  String get nasDownloadCancelled => 'रद्द किया गया';

  @override
  String get nasDownloadFailed => 'डाउनलोड विफल';

  @override
  String get nasRetryDownload => 'पुनः प्रयास करें';

  @override
  String get nasCancelDownload => 'रद्द करें';

  @override
  String get nasOpenDownloadedFile => 'फ़ाइल खोलें';

  @override
  String get nasQueue => 'प्ले कतार';

  @override
  String get nasNoQueue => 'कतार खाली है';

  @override
  String get nasSpeed => 'गति';

  @override
  String get nasQuality => 'गुणवत्ता';

  @override
  String get nasAudioTrack => 'ऑडियो ट्रैक';

  @override
  String get nasSubtitleTrack => 'उपशीर्षक (Subtitles)';

  @override
  String get nasRepeatOff => 'दोहराव बंद';

  @override
  String get nasRepeatAll => 'सभी दोहराएं';

  @override
  String get nasRepeatOne => 'एक दोहराएं';

  @override
  String get nasShuffle => 'शफ़ल';

  @override
  String get nasCast => 'कास्ट करें';

  @override
  String get nasCastUnavailable => 'कोई कास्ट उपकरण उपलब्ध नहीं है';

  @override
  String get nasSlideshow => 'स्लाइड शो';

  @override
  String get nasByFolder => 'फ़ोल्डर';

  @override
  String get nasByArtist => 'कलाकार';

  @override
  String get nasByAlbum => 'एल्बम';

  @override
  String get nasAllTracks => 'सभी ट्रैक';

  @override
  String get nasPlayAll => 'सभी चलाएं';

  @override
  String get nasPreviousPage => 'पिछला';

  @override
  String get nasNextPage => 'अगला';

  @override
  String get nasClearScope => 'वापस सभी पर जाएं';

  @override
  String get nasRenamePlaylist => 'प्लेलिस्ट का नाम बदलें';

  @override
  String get nasRemoveFromPlaylist => 'प्लेलिस्ट से हटाएं';

  @override
  String get nasMoveUp => 'ऊपर ले जाएं';

  @override
  String get nasMoveDown => 'नीचे ले जाएं';

  @override
  String get nasSshServer => 'SSH सर्वर';

  @override
  String get nasSelectSshServer => 'सहेजा गया SSH सर्वर चुनें';

  @override
  String get nasQualityOriginal => 'मूल';

  @override
  String get nasQualityAuto => 'स्वचालित';

  @override
  String get nasQuality4Mbps => '4 Mbps';

  @override
  String get nasQuality10Mbps => '10 Mbps';

  @override
  String get nasQuality20Mbps => '20 Mbps';

  @override
  String get nasCastDevices => 'उपलब्ध DLNA उपकरण';

  @override
  String get nasCastDiscovering => 'DLNA उपकरणों की खोज की जा रही है...';

  @override
  String get nasCastRelayingNotice =>
      'अग्रभूमि ऐप के माध्यम से स्ट्रीम रिले हो रही है। Valhalla खुला रखें।';

  @override
  String get nasCastStop => 'कास्टिंग रोकें';

  @override
  String get nasCastVolume => 'वॉल्यूम';

  @override
  String get nasCastRetry => 'खोज पुनः प्रयास करें';

  @override
  String get nasInstallTitle => 'NAS मीडिया सर्वर तैनात करें';

  @override
  String get nasInstallProduct => 'उत्पाद';

  @override
  String get nasInstallMediaPath => 'मीडिया डायरेक्टरी (केवल-पढ़ने के लिए)';

  @override
  String get nasInstallDataRoot => 'डेटा और कॉन्फ़िगरेशन डायरेक्टरी';

  @override
  String get nasInstallPort => 'पोर्ट';

  @override
  String get nasInstallBindAddress => 'बाइंड पता';

  @override
  String get nasInstallWebdavUser => 'WebDAV उपयोगकर्ता नाम';

  @override
  String get nasInstallWebdavPassword => 'WebDAV पासवर्ड (न्यूनतम 12 वर्ण)';

  @override
  String get nasInstallPreparePlan => 'तैनाती योजना की समीक्षा करें';

  @override
  String get nasInstallPlanTitle => 'तकनीकी समीक्षा और पुष्टि';

  @override
  String get nasInstallBlockersTitle => 'तैनाती अवरोधक';

  @override
  String get nasInstallConfirmDeploy => 'पुष्टि करें और इंस्टॉल करें';

  @override
  String get nasInstallDeploying => 'कंटेनर तैनात किया जा रहा है...';

  @override
  String get nasInstallSuccess => 'सफलतापूर्वक तैनात किया गया';

  @override
  String get nasInstallSuccessDesc =>
      'सेवा अब चल रही है। मीडिया स्रोत के रूप में जोड़ने से पहले सर्वर का प्रारंभिक सेटअप पूरा करें।';

  @override
  String get nasInstallContainerId => 'कंटेनर ID';

  @override
  String get nasInstallEndpoint => 'एंडपॉइंट';

  @override
  String get nasUseSshTunnel => 'SSH टनल का उपयोग करें';

  @override
  String get nasUseSshTunnelDesc =>
      'सहेजे गए SSH सर्वर के माध्यम से ट्रैफ़िक रूट करें (उदा. http://127.0.0.1:8096)';

  @override
  String get nasSshTunnelHint =>
      'एंडपॉइंट SSH सर्वर से पहुंच योग्य होना चाहिए, उदा. http://127.0.0.1:8096';

  @override
  String get nasKeepEmptyPassword =>
      'मौजूदा पासवर्ड / टोकन रखने के लिए खाली छोड़ें';

  @override
  String get nasSourceNameRequired => 'स्रोत नाम आवश्यक है';

  @override
  String get nasInvalidEndpoint => 'अमान्य एंडपॉइंट URL या योजना';

  @override
  String get nasSourceUnreachable => 'मीडिया स्रोत तक पहुंचने में असमर्थ';

  @override
  String get nasSshTunnelFailed => 'SSH टनल कनेक्शन विफल रहा';

  @override
  String get nasOperationFailed => 'ऑपरेशन विफल रहा';

  @override
  String get nasInstallStepCreateDir => 'निजी डायरेक्टरी बनाएं';

  @override
  String get nasInstallStepWriteCompose =>
      'docker-compose.json कॉन्फ़िगरेशन लिखें';

  @override
  String get nasInstallStepWriteCreds => 'निजी क्रेडेंशियल्स लिखें';

  @override
  String get nasInstallStepPullImage => 'पिन की गई कंटेनर छवि खींचें';

  @override
  String get nasInstallStepStartService => 'कंटेनरीकृत सेवा प्रारंभ करें';

  @override
  String get nasInstallStepCheckHttp => 'सेवा HTTP स्वास्थ्य की जांच करें';

  @override
  String get nasInstallBlockerDocker =>
      'लक्ष्य सर्वर पर Docker Engine आवश्यक है';

  @override
  String get nasInstallBlockerCompose => 'Docker Compose प्लगइन आवश्यक है';

  @override
  String get nasInstallBlockerIdentity =>
      'लक्ष्य सर्वर पहचान सत्यापित नहीं की जा सकी';

  @override
  String get nasInstallBlockerTools =>
      'आवश्यक उपकरण (curl, ss, realpath) लक्ष्य सर्वर पर अनुपलब्ध हैं';

  @override
  String get nasInstallBlockerMedia =>
      'मीडिया डायरेक्टरी मौजूद नहीं है या पढ़ने योग्य नहीं है';

  @override
  String get nasInstallBlockerParent =>
      'डेटा रूट मूल डायरेक्टरी लिखने योग्य नहीं है';

  @override
  String get nasInstallBlockerOverlap =>
      'मीडिया डायरेक्टरी और डेटा डायरेक्टरी ओवरलैप नहीं हो सकतीं';

  @override
  String get nasInstallBlockerCollision =>
      'लक्ष्य डेटा डायरेक्टरी पहले से मौजूद है या एक सिम्लिंक है';

  @override
  String get nasInstallBlockerPort =>
      'चयनित पोर्ट लक्ष्य सर्वर पर पहले से उपयोग में है';

  @override
  String get nasInstallBlockerContainer =>
      'इस प्रोजेक्ट नाम वाला एक कंटेनर पहले से मौजूद है';

  @override
  String get nasInstallBlockerImage =>
      'कंटेनर छवि सत्यापित करने में विफल। छवि का नाम, नेटवर्क कनेक्टिविटी और सर्वर आर्किटेक्चर जांचें, फिर पुनः प्रयास करें।';

  @override
  String get nasInstallGuidanceTunnel =>
      'लूपबैक बाइंडिंग (127.0.0.1) को रिमोट एक्सेस के लिए SSH टनल की आवश्यकता होती है';

  @override
  String get nasInstallGuidanceTls =>
      'सार्वजनिक बाइंडिंग को TLS रिवर्स प्रॉक्सी के पीछे सुरक्षित करने की अनुशंसा की जाती है';

  @override
  String get nasInstallGuidanceSetup =>
      'पहले लॉन्च पर ब्राउज़र में प्रारंभिक व्यवस्थापक खाता सेटअप पूरा करें';

  @override
  String get nasInstallGuidanceReadOnly =>
      'आपकी फ़ाइलों की सुरक्षा के लिए मीडिया डायरेक्टरी को केवल-पढ़ने के लिए माउंट किया गया है';

  @override
  String get nasInstallGuidancePreserved =>
      'समस्या निवारण के लिए विफलता पर डेटा डायरेक्टरी सुरक्षित रखी जाएगी';

  @override
  String get nasDownloadCompletedWithOpenError =>
      'डाउनलोड किया गया (बाहरी रूप से खोलने में विफल)';

  @override
  String get nasRetryOpen => 'खोलने का पुनः प्रयास करें';

  @override
  String get nasExternalOpenFailed => 'बाहरी ऐप में फ़ाइल खोलने में विफल';

  @override
  String get nasTitle => 'NAS मीडिया';

  @override
  String get nasLoadMoreGroups => 'अधिक समूह लोड करें';

  @override
  String get nasMetadataEnriching => 'संगीत टैग समृद्ध किए जा रहे हैं...';

  @override
  String nasMetadataEnrichingWithCount(int count) {
    return 'संगीत टैग समृद्ध किए जा रहे हैं ($count संसाधित)...';
  }

  @override
  String nasDownloading(String value) {
    return '$value डाउनलोड हो रहा है…';
  }

  @override
  String get nasSubtitleNone => 'कोई नहीं';

  @override
  String get nasLibraryId => 'लाइब्रेरी ID';

  @override
  String get nasLibraryIdHint =>
      'डिफ़ॉल्ट: सभी (/), या लाइब्रेरी ID निर्दिष्ट करें';

  @override
  String nasScanPathRelativeHint(String value) {
    return 'स्रोत रूट ($value) के सापेक्ष';
  }

  @override
  String get nasSourceChangedError =>
      'कॉन्फ़िगर करते समय स्रोत बदल गया, सहेजना रद्द किया गया';

  @override
  String get nasInvalidLibraryId => 'अमान्य लाइब्रेरी ID';

  @override
  String get startupFailed => 'एप्लिकेशन प्रारंभ होने में विफल रहा';

  @override
  String get startupFailedDesc =>
      'स्टार्टअप के दौरान एक अप्रत्याशित त्रुटि हुई। आप पुनः प्रयास कर सकते हैं या निदान लॉग निर्यात कर सकते हैं।';

  @override
  String get retryStartup => 'स्टार्टअप पुनः प्रयास करें';

  @override
  String get viewDiagnostics => 'निदान देखें';

  @override
  String get exportDiagnostics => 'निदान निर्यात करें';

  @override
  String diagnosticsExportSuccess(String path) {
    return 'निदान $path पर निर्यात किया गया';
  }

  @override
  String get diagnosticsExportFailed => 'निदान निर्यात करने में विफल';

  @override
  String get diagnosticsTitle => 'ऐप निदान';

  @override
  String get settingsDiagnostics => 'निदान और लॉग्स';

  @override
  String get settingsDiagnosticsDesc =>
      'स्थानीय स्वच्छ एप्लिकेशन लॉग देखें और निर्यात करें';

  @override
  String get diagnosticsEmpty => 'कोई निदान रिकॉर्ड नहीं मिला';

  @override
  String diagnosticsStorageError(String error) {
    return 'निदान संग्रहण त्रुटि: $error';
  }

  @override
  String diagnosticsIncidentNotice(String category) {
    return 'पुनर्प्राप्ति योग्य घटना रिपोर्ट की गई: $category';
  }

  @override
  String get diagnosticsRefresh => 'लॉग ताज़ा करें';

  @override
  String get nasInstallTaskTitle => 'तैनाती कार्य';

  @override
  String get nasInstallStagePreflight => 'प्रीफ़्लाइट जांच';

  @override
  String get nasInstallStageReview => 'योजना समीक्षा';

  @override
  String get nasInstallStageWriting => 'कॉन्फ़िगरेशन लिखा जा रहा है';

  @override
  String get nasInstallStagePulling => 'छवि खींची जा रही है';

  @override
  String get nasInstallStageStarting => 'कंटेनर प्रारंभ हो रहा है';

  @override
  String get nasInstallStageHealth => 'स्वास्थ्य जांच';

  @override
  String get nasInstallStageCleanup => 'सफाई हो रही है';

  @override
  String get nasInstallStageSucceeded => 'तैनाती सफल रही';

  @override
  String get nasInstallStageFailed => 'तैनाती विफल रही';

  @override
  String get nasInstallStageCancelled => 'तैनाती रद्द की गई';

  @override
  String get nasInstallStageNeedsInspection => 'निरीक्षण की आवश्यकता है';

  @override
  String get nasInstallStageReconciling => 'स्थिति का मिलान किया जा रहा है';

  @override
  String get nasInstallCancel => 'तैनाती रद्द करें';

  @override
  String get nasInstallReconcile => 'स्थिति का मिलान करें';

  @override
  String get nasInstallServerNotFound => 'चयनित सर्वर नहीं मिला';

  @override
  String get nasInstallPortRangeError => 'पोर्ट 1 और 65535 के बीच होना चाहिए';

  @override
  String nasInstallElapsedTime(String time) {
    return 'बीता समय: $time';
  }

  @override
  String get nasInstallLogTail => 'हाल के लॉग्स';

  @override
  String get nasInstallCleanupCompleted => 'रोलबैक सफाई पूरी हुई';

  @override
  String get nasInstallCleanupIncomplete => 'रोलबैक सफाई अधूरी है';

  @override
  String get nasInstallNewDeployment => 'नई तैनाती';

  @override
  String get nasInstallBackEdit => 'वापस / फ़ॉर्म संपादित करें';

  @override
  String get nasInstallClose => 'बंद करें';

  @override
  String get nasInstallMediaPathHint =>
      'होस्ट पर केवल-पढ़ने के लिए बाइंड माउंट (उदा. /mnt/media)';

  @override
  String get nasInstallDataRootHint =>
      'निजी डेटा और कॉन्फ़िग डायरेक्टरी (अभी मौजूद नहीं होनी चाहिए)';

  @override
  String get nasInstallBindAddressHint =>
      'टनल के लिए 127.0.0.1, LAN के लिए 0.0.0.0';

  @override
  String get nasInstallWebdavPasswordHint => 'न्यूनतम 12 वर्ण आवश्यक हैं';

  @override
  String get nasInstallTargetServer => 'लक्ष्य सर्वर';

  @override
  String get nasInstallTargetImage => 'लक्ष्य छवि';

  @override
  String get nasInstallContainerName => 'कंटेनर नाम';

  @override
  String get nasInstallBindAndPort => 'बाइंड और पोर्ट';

  @override
  String get nasInstallComposePreview => 'docker-compose.json पूर्वावलोकन';

  @override
  String get nasInstallPlannedSteps => 'योजनाबद्ध चरण';

  @override
  String get nasInstallGuidanceNotes => 'तैनाती नोट्स और मार्गदर्शन';

  @override
  String get nasInstallNoLogsYet => 'अभी तक कोई लॉग नहीं';

  @override
  String get sftpPreviewTooLarge =>
      'फ़ाइल 1 MiB पूर्वावलोकन सीमा से अधिक है। कृपया डाउनलोड करें और इसे बाहरी रूप से खोलें।';

  @override
  String get sftpSaveFailed =>
      'फ़ाइल सहेजने में विफल। अनुमतियाँ या नेटवर्क कनेक्शन जांचें।';

  @override
  String get sftpSaving => 'सहेजा जा रहा है...';

  @override
  String get nasInstallBlockerConnectionChanged =>
      'लक्ष्य सर्वर कनेक्शन बदल गया; आगे बढ़ने से पहले रिमोट स्थिति सत्यापित करें';

  @override
  String get nasInstallBlockerCancelled =>
      'तैनाती उपयोगकर्ता द्वारा रद्द कर दी गई। सेटिंग्स की समीक्षा करें और यदि आवश्यक हो तो पुनः प्रयास करें।';

  @override
  String get nasInstallBlockerInspectFailed =>
      'रिमोट कंटेनर की जानकारी प्राप्त करने में निरीक्षण विफल रहा। सर्वर कनेक्टिविटी जांचें या मैन्युअल रूप से निरीक्षण करें।';

  @override
  String get nasInstallBlockerDeadlineExceeded =>
      'तैनाती चरण का समय समाप्त हो गया। सर्वर लोड या नेटवर्क कनेक्शन जांचें और पुनः प्रयास करें।';

  @override
  String get nasInstallBlockerInterrupted =>
      'तैनाती बाधित हुई; आगे बढ़ने से पहले रिमोट स्थिति की समीक्षा करें।';

  @override
  String get nasInstallBlockerHealthTimeout =>
      'सेवा प्रारंभ हुई लेकिन HTTP स्वास्थ्य जांच का समय समाप्त हो गया। सेवा लॉग या पोर्ट उपलब्धता सत्यापित करें।';

  @override
  String get nasInstallBlockerReconciliationFailed =>
      'मिलान विफल रहा। मैन्युअल रूप से रिमोट कंटेनर स्थिति सत्यापित करें या नई तैनाती शुरू करें।';

  @override
  String get nasInstallBlockerRemoteInspectionRequired =>
      'रिमोट कंटेनर स्थिति अनिश्चित है। मैन्युअल निरीक्षण और मिलान आवश्यक है।';

  @override
  String get nasInstallBlockerServiceExited =>
      'कंटेनर प्रक्रिया समय से पहले समाप्त हो गई। कॉन्फ़िगरेशन या अनुमति त्रुटियों के लिए लॉग जांचें।';

  @override
  String get nasInstallBlockerWriteFailed =>
      'लक्ष्य सर्वर पर तैनाती फ़ाइलें लिखने में विफल। डिस्क स्थान और अनुमतियाँ जांचें।';

  @override
  String get nasInstallBlockerPlanStale =>
      'तैनाती योजना बासी है। कृपया प्रीफ़्लाइट जांच पुनः चलाएं।';

  @override
  String get nasInstallBlockerOwnershipChanged =>
      'मौजूदा कंटेनर इस ऐप द्वारा नहीं बनाया गया था। ओवरराइटिंग को रोकने के लिए मैन्युअल रूप से निरीक्षण करें।';

  @override
  String get nasInstallBlockerSshRequired =>
      'लक्ष्य सर्वर से सक्रिय SSH कनेक्शन आवश्यक है।';

  @override
  String get nasInstallBlockerReconciliationRequired =>
      'रिमोट स्थिति स्थानीय स्थिति से भिन्न है। कृपया आगे बढ़ने से पहले मिलान करें।';

  @override
  String get nasInstallBlockerFailed =>
      'तैनाती में एक त्रुटि आई। लॉग जांचें और पुनः प्रयास करें।';

  @override
  String get nasInstallBlockerBusy =>
      'एक इंस्टॉलेशन कार्य पहले से जारी है। कृपया वर्तमान कार्य प्रगति की जांच करें।';

  @override
  String get nasInstallBlockerStateSaveFailed =>
      'तैनाती स्थिति सहेजने में विफल। कृपया स्थानीय संग्रहण स्थान और फ़ाइल अनुमतियाँ जांचें।';

  @override
  String get nasInstallBlockerCommandResultUnknown =>
      'रिमोट कमांड परिणाम अज्ञात है। कृपया सीधे तैनाती पुनः प्रयास करने के बजाय केवल-पढ़ने के लिए निरीक्षण चलाएं।';

  @override
  String get nasInstallBlockerPreflightFailed =>
      'तैनाती-पूर्व परिवेश जांच विफल रही। कृपया जारी रखने से पहले अवरोधकों को हल करें।';

  @override
  String serverDeleteFailed(String error) {
    return 'सर्वर हटाने में विफल: $error';
  }

  @override
  String get chatRunSettingsAgentMode => 'एजेंट मोड';

  @override
  String get chatRunSettingsApprovalPolicy => 'स्थानीय स्वीकृति नीति';

  @override
  String get chatRunSettingsExtraSettings => 'अतिरिक्त सेटिंग्स';

  @override
  String get chatPermissionAutoAllowSafeDesc =>
      'ज्ञात-सुरक्षित ऑपरेशनों को स्वचालित रूप से अनुमति देता है; जब भी ऑपरेशन सुरक्षा निर्धारित नहीं की जा सकती है, तब पूछता है।';

  @override
  String chatRunSettingsSaveFailed(String error) {
    return 'रन सेटिंग्स लागू करने में विफल: $error';
  }

  @override
  String get chatMessageCopied => 'संदेश क्लिपबोर्ड पर कॉपी किया गया';

  @override
  String get copy => 'कॉपी करें';

  @override
  String get rename => 'नाम बदलें';

  @override
  String get refresh => 'ताज़ा करें';

  @override
  String get sessionTitle => 'सत्र शीर्षक';

  @override
  String get chatSettingsStale => 'बासी';

  @override
  String get chatSettingsAvailableAfterFirstMessage =>
      'पहले संदेश के बाद सेटिंग्स उपलब्ध होंगी';

  @override
  String get chatReimportAsCopy => 'प्रतिलिपि के रूप में पुनः आयात करें';

  @override
  String get chatSearchCommandsHint => 'कमांड या कौशल खोजें...';

  @override
  String get chatCommandsTab => 'कमांड्स';

  @override
  String get chatSkillsTab => 'कौशल';

  @override
  String get chatAccountAndQuotaTitle => 'खाता और कोटा';

  @override
  String get chatAccountSectionTitle => 'खाता';

  @override
  String get chatAccountNotProvided => 'कोई खाता विवरण रिपोर्ट नहीं किया गया';

  @override
  String get chatAccountKind => 'प्रकार';

  @override
  String get chatAccountLabel => 'लेबल';

  @override
  String get chatAccountPlan => 'योजना';

  @override
  String get chatAccountEmail => 'ईमेल';

  @override
  String get chatAccountUpdatedAt => 'अद्यतन किया गया';

  @override
  String get chatQuotaSectionTitle => 'कोटा और स्थिति';

  @override
  String get chatStatusSourceNote => 'मूल एजेंट /status आउटपुट';

  @override
  String get chatStatusNotQueried => 'अभी तक स्थिति की जानकारी नहीं ली गई';

  @override
  String get chatQueryStatusAction => 'स्थिति पूछें (/status)';

  @override
  String get chatQueryStatusUnavailable =>
      'वर्तमान सत्र में स्थिति प्रश्न अनुपलब्ध है';

  @override
  String get chatAttachmentMissing => 'संलग्न फ़ाइल अनुपलब्ध या गायब है';

  @override
  String get chatViewModeList => 'सूची';

  @override
  String get chatViewModeCards => 'कार्ड';

  @override
  String get chatViewModeGrid => 'छवियां';

  @override
  String get chatRemoteBrowserTitle => 'रिमोट कार्यक्षेत्र';

  @override
  String get chatSelectDirectory => 'डायरेक्टरी चुनें';

  @override
  String chatAttachSelectedFiles(int count) {
    return 'चयनित संलग्न करें ($count)';
  }

  @override
  String get chatNoFilesFound => 'कोई फ़ाइल नहीं मिली';

  @override
  String get chatRootDirectory => 'रूट';

  @override
  String get chatSelectThisDirectory => 'इस डायरेक्टरी का उपयोग करें';

  @override
  String get chatAgentVersion => 'एजेंट संस्करण';

  @override
  String get chatParentDirectory => 'मूल डायरेक्टरी';

  @override
  String get chatSearchFilesHint => 'फ़ाइलें खोजें...';

  @override
  String get chatCommandsEmpty =>
      'एजेंट द्वारा कोई स्लैश कमांड प्रदान नहीं किया गया';

  @override
  String get chatSkillsEmpty => 'एजेंट द्वारा कोई कौशल प्रदान नहीं किया गया';

  @override
  String get chatFileUnsupported =>
      'संलग्नक के लिए फ़ाइल प्रकार समर्थित नहीं है';

  @override
  String get chatStatusNotProvided =>
      'एजेंट द्वारा स्थिति प्रश्न प्रदान नहीं किया गया';

  @override
  String get sessionRecoveryReconnecting => 'पुनः कनेक्ट हो रहा है...';

  @override
  String get sessionRecoverySyncing => 'आउटपुट सिंक हो रहा है...';

  @override
  String get sessionRecoveryIncomplete =>
      'कुछ आउटपुट पुनर्प्राप्त नहीं किए जा सके';

  @override
  String get sessionRecoveryFailed => 'पुनर्प्राप्ति विफल रही';

  @override
  String get sessionRecoveryRetry => 'पुनः प्रयास करें';

  @override
  String get dashboardUpdatesPaused => 'अपडेट रोके गए';

  @override
  String get chatSettingsIndependentModelUnavailable =>
      'CLI मॉडल कैटलॉग वर्तमान में अनुपलब्ध है। मॉडल कैश्ड हो सकते हैं या CLI संस्करण द्वारा सीमित हो सकते हैं; आप मैन्युअल रूप से भी मॉडल का नाम दर्ज कर सकते हैं।';

  @override
  String get chatSettingsModelCatalogNote =>
      'मॉडल आपके मौजूदा CLI लॉगिन का उपयोग करके CLI ऐप-सर्वर से पूछे जाते हैं। कैटलॉग कैश्ड या संस्करण-सीमित हो सकता है; आप मैन्युअल रूप से रीफ़्रेश कर सकते हैं या मैन्युअल इनपुट पर स्विच कर सकते हैं।';

  @override
  String get chatModelCatalogError403 =>
      'CLI मॉडल क्वेरी एक्सेस अस्वीकृत (403)। CLI लॉगिन और सेवा कनेक्टिविटी जांचें, या मैन्युअल रूप से मॉडल नाम दर्ज करें।';

  @override
  String chatModelCatalogErrorGeneric(String error) {
    return 'मॉडल कैटलॉग त्रुटि: $error';
  }

  @override
  String get chatModelAuthorizeButton => 'मॉडल कैटलॉग को अधिकृत करें';

  @override
  String get chatModelAuthorizeConfirmTitle => 'मॉडल कैटलॉग को अधिकृत करें';

  @override
  String get chatModelAuthorizeConfirmMessage =>
      'यह लक्ष्य होस्ट/कंटेनर पर मॉडल कैटलॉग के लिए ब्राउज़र प्राधिकरण शुरू करेगा। आपका मौजूदा Codex लॉगिन और टर्मिनल सत्र पूरी तरह से अछूते रहेंगे। क्या जारी रखें?';

  @override
  String get chatModelAuthorizing =>
      'ब्राउज़र के माध्यम से अधिकृत किया जा रहा है...';

  @override
  String get chatModelAuthorizeCancel => 'प्राधिकरण रद्द करें';

  @override
  String get chatCommandsFirstTurnNote =>
      'सत्र प्रारंभ होते ही एजेंट रनटाइम द्वारा स्लैश कमांड विज्ञापित किए जाएंगे, बिना किसी पूर्व साधारण बातचीत के; ड्राफ़्ट स्वचालित रूप से सत्र नहीं बनाते हैं।';

  @override
  String get chatCommandsClientActionRunSettings => 'रन सेटिंग्स';

  @override
  String get chatCommandsClientActionWorkingDirectory => 'कार्यशील डायरेक्टरी';

  @override
  String get chatCommandsClientActionsSection => 'स्थानीय क्रियाएं';

  @override
  String get chatRunSettingsModelSourceCatalog => 'मॉडल सूची';

  @override
  String get chatRunSettingsModelSourceCustom => 'मैन्युअल इनपुट';

  @override
  String get chatRunSettingsCustomModelHint => 'मॉडल ID दर्ज करें';

  @override
  String get chatRunSettingsCustomModelNotice =>
      'मैन्युअल मॉडल नाम असत्यापित हैं और सीधे एजेंट रनटाइम पर भेजे जाएंगे, जो असमर्थित मॉडलों को अस्वीकार कर सकता है।';

  @override
  String get chatRunSettingsCustomModelEmptyError =>
      'मॉडल का नाम खाली नहीं हो सकता';

  @override
  String get chatRunSettingsCustomModelInvalidError =>
      'मॉडल का नाम अधिकतम 256 वर्णों का होना चाहिए, जिसमें कोई रिक्त स्थान या नियंत्रण वर्ण न हों';

  @override
  String get chatCommandsDraftPreviewNotice =>
      'वर्तमान एडेप्टर संस्करण के लिए सत्यापित कमांड। चयन करने पर ड्राफ़्ट में टेक्स्ट डाला जाता है; Send मांग पर सत्र प्रारंभ करेगा और कमांड को सीधे चलाएगा।';

  @override
  String get chatCommandsDiscoveryFailed => 'कमांड या कौशल खोजने में विफल';

  @override
  String get chatAuthWaitingForBrowser =>
      'ब्राउज़र में प्राधिकरण की प्रतीक्षा की जा रही है...';

  @override
  String get chatAuthBrowserLaunchFailed =>
      'बाहरी ब्राउज़र नहीं खोला जा सका। कृपया नीचे दिए गए प्राधिकरण लिंक को फिर से खोलें या कॉपी करें।';

  @override
  String get chatAuthReopenBrowser => 'ब्राउज़र पुनः खोलें';

  @override
  String get chatAuthCopyLink => 'लिंक कॉपी करें';

  @override
  String get chatAuthManualCallback => 'मैन्युअल कॉलबैक';

  @override
  String get chatAuthManualCallbackTitle => 'प्राधिकरण कॉलबैक URL दर्ज करें';

  @override
  String get chatAuthManualCallbackDesc =>
      'प्राधिकरण पूरा करने के लिए ब्राउज़र से पूरा रीडायरेक्ट URL (http://127.0.0.1:PORT/...?code=...&state=...) पेस्ट करें। कच्चे प्राधिकरण कोड स्वीकार नहीं किए जाते हैं।';

  @override
  String get chatAuthCallbackInputLabel => 'कॉलबैक URL';

  @override
  String get chatAuthCallbackInputHint =>
      'http://127.0.0.1:PORT/...?code=...&state=...';

  @override
  String get chatAuthCallbackInvalidError =>
      'अमान्य कॉलबैक URL प्रारूप या डिलीवरी विफल';

  @override
  String get agentAuthAgYNotice =>
      'Antigravity ACP के लिए आधिकारिक खाता प्राधिकरण की आवश्यकता होती है, जो टर्मिनल CLI लॉगिन से अलग है।';

  @override
  String get chatAuthDiscoveryPrompt =>
      'इस टर्न के लिए ACP प्रमाणीकरण की आवश्यकता है। आगे बढ़ने के लिए पुनः कनेक्ट करें और प्राधिकरण का अनुरोध करें।';

  @override
  String get chatRequestAuthButton => 'प्रमाणीकरण का अनुरोध करें';

  @override
  String get agentActionAcpLogin => 'ACP साइन-इन';

  @override
  String get agentActionCliLogin => 'CLI लॉगिन';

  @override
  String get agentAgyAcpSignInRequired =>
      'ACP क्रेडेंशियल अनुपलब्ध (ACP साइन-इन आवश्यक है)';

  @override
  String get agentAgyAcpCredentialsSaved =>
      'ACP क्रेडेंशियल सहेजे गए (असत्यापित)';

  @override
  String get chatAuthMethodUnavailable =>
      'चयनित प्रमाणीकरण विधि उपलब्ध नहीं है।';

  @override
  String get chatAuthConnectionExpired =>
      'प्रमाणीकरण कनेक्शन समाप्त हो गया। कृपया पुनः प्रयास करें।';

  @override
  String get chatAuthCallbackDeliveryFailed =>
      'सर्वर पर प्राधिकरण कॉलबैक वितरित करने में विफल।';

  @override
  String get agentTargetChangedNotice =>
      'लक्ष्य सर्वर बदल गया है। कृपया वर्तमान सर्वर पर एजेंट प्रबंधन पुनः खोलें।';

  @override
  String get agentAgyAuthCheckUnavailable =>
      'Antigravity प्रमाणीकरण जांच अनुपलब्ध है';

  @override
  String get agentAgyAuthCheckInvalid =>
      'Antigravity प्रमाणीकरण जांच प्रतिक्रिया अमान्य है';

  @override
  String get sftpDownloadDisconnected => 'डाउनलोड डिस्कनेक्ट हो गया';

  @override
  String get sftpDownloadPermissionDenied => 'अनुमति अस्वीकृत';

  @override
  String get sftpDownloadNotFound => 'रिमोट फ़ाइल नहीं मिली';

  @override
  String get sftpDownloadTimeout => 'डाउनलोड का समय समाप्त हो गया';

  @override
  String get sftpDownloadLocalSpace => 'अपर्याप्त स्थानीय संग्रहण स्थान';

  @override
  String get sftpDownloadLocalIo => 'स्थानीय संग्रहण में लिखने में विफल';

  @override
  String get sftpDownloadIncomplete => 'अधूरा डाउनलोड';

  @override
  String get transferStatusWaitingConnection => 'कनेक्शन की प्रतीक्षा है';

  @override
  String get chatAuthCallbackListenerFailed =>
      'स्थानीय प्राधिकरण कॉलबैक श्रोता प्रारंभ करने में विफल। कृपया प्रमाणीकरण का पुनः प्रयास करें।';

  @override
  String get settingsExperimentalFeatures => 'प्रायोगिक सुविधाएँ';

  @override
  String get settingsExperimentalFeaturesDesc =>
      'पूर्वावलोकन और प्रायोगिक क्षमताओं का परीक्षण करें';

  @override
  String get settingsExperimentalCliChatTitle => 'CLI स्मार्ट चैट';

  @override
  String get settingsExperimentalCliChatDesc =>
      'समर्पित कमांड-लाइन एजेंट चैट इंटरफ़ेस सक्षम करें';

  @override
  String get settingsExperimentalDialogClose => 'बंद करें';

  @override
  String get settingsExperimentalSaveFailed =>
      'प्रायोगिक सुविधा सेटिंग्स अद्यतन करने में विफल';

  @override
  String get settingsExperimentalNasTitle => 'NAS मीडिया';

  @override
  String get settingsExperimentalNasDesc =>
      'मीडिया लाइब्रेरी, फ़ोल्डर स्कैन और ऑडियो प्लेबैक सक्षम करें';

  @override
  String get settingsLanguageSaveFailed => 'भाषा सेटिंग्स अद्यतन करने में विफल';

  @override
  String get settingsAboutPrivacy => 'परिचय और गोपनीयता';

  @override
  String get privacyPolicyTitle => 'गोपनीयता नीति';

  @override
  String get privacyPolicyDescription => 'डेटा का उपयोग और आपके विकल्प';

  @override
  String get privacyContactTitle => 'गोपनीयता संपर्क';

  @override
  String get privacyCopyEmail => 'ईमेल पता कॉपी करें';

  @override
  String get privacyEmailCopied => 'ईमेल पता कॉपी किया गया';

  @override
  String get privacyOnlineVersion => 'ऑनलाइन संस्करण देखें';

  @override
  String get privacyLinkFailed =>
      'लिंक नहीं खुल सका। आप ईमेल पता कॉपी कर सकते हैं।';

  @override
  String get privacyLoadFailed => 'नीति लोड नहीं हुई। ऑनलाइन संस्करण देखें।';

  @override
  String get privacyVersionUnknown => 'संस्करण उपलब्ध नहीं';

  @override
  String get aboutWebsite => 'आधिकारिक वेबसाइट';

  @override
  String get aboutLicense => 'ऐप लाइसेंस';

  @override
  String get aboutThirdPartyLicenses => 'तृतीय-पक्ष ओपन सोर्स लाइसेंस';

  @override
  String get aboutLicenseSummary =>
      'Valhalla की मूल सामग्री PolyForm Noncommercial 1.0.0 के अंतर्गत गैर-व्यावसायिक उपयोग के लिए लाइसेंस प्राप्त है। लाइसेंस की अनुमतियों से बाहर व्यावसायिक उपयोग के लिए अलग अनुमति आवश्यक है। तृतीय-पक्ष घटकों के अपने लाइसेंस लागू रहते हैं। उपयोग नीचे दी गई पूरी शर्तों के अधीन है।';

  @override
  String get aboutCopyrightNotice => 'कॉपीराइट सूचनाएँ';

  @override
  String get aboutLicenseLoadFailed =>
      'लाइसेंस लोड नहीं हो सका। norns.soft@gmail.com से संपर्क करें।';

  @override
  String get aboutLinkFailed =>
      'लिंक नहीं खुल सका। अपने ब्राउज़र में https://norns.cc.cd खोलें।';

  @override
  String get downloadReveal => 'फ़ाइल एक्सप्लोरर में दिखाएँ';

  @override
  String get downloadRevealFailed =>
      'डाउनलोड फ़ोल्डर नहीं खुल सका। संभव है कि उसे स्थानांतरित या हटा दिया गया हो।';
}
