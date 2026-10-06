// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Thai (`th`).
class AppLocalizationsTh extends AppLocalizations {
  AppLocalizationsTh([String locale = 'th']) : super(locale);

  @override
  String get appName => 'Valhalla';

  @override
  String get appSubtitle => 'การจัดการเซิร์ฟเวอร์และ Agent แบบ AI-Native';

  @override
  String get navAiChat => 'แชท AI';

  @override
  String get navTerminal => 'เทอร์มินัล';

  @override
  String get navFiles => 'ไฟล์ SFTP';

  @override
  String get navCommands => 'คำสั่ง';

  @override
  String get navSettings => 'การตั้งค่า';

  @override
  String get serverConnected => 'เชื่อมต่อแล้ว';

  @override
  String get serverOnline => 'ออนไลน์';

  @override
  String get serverOffline => 'ออฟไลน์';

  @override
  String get latencyMs => 'มิลลิวินาที';

  @override
  String get reconnect => 'เชื่อมต่อใหม่';

  @override
  String get disconnect => 'ตัดการเชื่อมต่อ';

  @override
  String get quickDisconnect => 'ตัดการเชื่อมต่อด่วน';

  @override
  String get newSession => 'เซสชันใหม่';

  @override
  String get historySessions => 'ประวัติเซสชัน';

  @override
  String get switchAgent => 'สลับ Agent';

  @override
  String get agentClaudeCode => 'Claude CodeX';

  @override
  String get agentCodex => 'OpenAI Codex';

  @override
  String get agentOpenCode => 'OpenCode ACP';

  @override
  String get agentGemini => 'Gemini CLI';

  @override
  String get activeAgent => 'Agent ที่ใช้งานอยู่';

  @override
  String get inputPromptHint =>
      'ขอให้ Agent วินิจฉัย เรียกใช้เครื่องมือ หรือเขียนคำสั่ง... (กด Enter เพื่อส่ง)';

  @override
  String get thinking => 'กระบวนการคิด';

  @override
  String get executionPlan => 'แผนการดำเนินการ';

  @override
  String get toolCall => 'การเรียกใช้เครื่องมือ';

  @override
  String get toolStatusPending => 'รอดำเนินการ';

  @override
  String get toolStatusRunning => 'กำลังทำงาน...';

  @override
  String get toolStatusCompleted => 'เสร็จสิ้น';

  @override
  String get toolStatusFailed => 'ล้มเหลว';

  @override
  String get permissionRequired => 'จำเป็นต้องได้รับอนุญาต';

  @override
  String get permissionDescription =>
      'Agent ต้องการดำเนินการคำสั่งนี้บนเซิร์ฟเวอร์:';

  @override
  String get permissionReject => 'ปฏิเสธ';

  @override
  String get permissionAllowOnce => 'อนุญาตครั้งเดียว';

  @override
  String get permissionAllowAlways => 'อนุญาตเสมอ';

  @override
  String get quickTroubleshootCpu => 'แก้ไขปัญหา CPU สูง';

  @override
  String get quickDockerHealth => 'ตรวจสอบสถานะ Docker';

  @override
  String get quickCleanCache => 'ล้างแคชระบบ';

  @override
  String get quickNginxLogs => 'ตรวจสอบบันทึกข้อผิดพลาด Nginx';

  @override
  String get terminalNewTab => 'แท็บใหม่';

  @override
  String get terminalCloseTab => 'ปิดแท็บ';

  @override
  String get terminalClear => 'ล้างหน้าจอ';

  @override
  String get terminalQuickCmds => 'ชุดคำสั่งด่วน';

  @override
  String get terminalPaste => 'วาง';

  @override
  String get sftpCurrentPath => 'เส้นทางปัจจุบัน';

  @override
  String get sftpUpload => 'อัปโหลด';

  @override
  String get sftpNewFolder => 'โฟลเดอร์ใหม่';

  @override
  String get sftpNewFile => 'ไฟล์ใหม่';

  @override
  String get sftpRefresh => 'รีเฟรช';

  @override
  String get sftpSearchHint => 'ค้นหาไฟล์หรือโฟลเดอร์...';

  @override
  String get sftpEmpty => 'ไดเรกทอรีว่างเปล่า';

  @override
  String get sftpFileName => 'ชื่อ';

  @override
  String get sftpFileSize => 'ขนาด';

  @override
  String get sftpFilePerm => 'สิทธิ์';

  @override
  String get sftpFileModified => 'แก้ไขเมื่อ';

  @override
  String get cmdCategoryDocker => 'สแต็กคอนเทนเนอร์ DOCKER';

  @override
  String get cmdCategorySystem => 'การบำรุงรักษาระบบ';

  @override
  String get cmdCategoryNetwork => 'เครือข่ายและพอร์ต';

  @override
  String get cmdExecute => 'เรียกใช้';

  @override
  String get cmdDangerous => 'คำสั่งอันตราย';

  @override
  String get cmdDangerousWarning =>
      'การดำเนินการนี้ไม่สามารถย้อนกลับได้และอาจทำให้บริการหยุดชะงัก คุณแน่ใจหรือไม่ว่าต้องการดำเนินการต่อ?';

  @override
  String get cmdParamRequired => 'จำเป็นต้องป้อนพารามิเตอร์';

  @override
  String get cmdConfirm => 'ยืนยันและเรียกใช้';

  @override
  String get cmdCancel => 'ยกเลิก';

  @override
  String get settingsAppearance => 'รูปลักษณ์และธีม';

  @override
  String get settingsThemeMode => 'โหมดธีม';

  @override
  String get themeSystem => 'ตามระบบ';

  @override
  String get themeSystemDesc => 'ปรับอัตโนมัติ';

  @override
  String get themeLight => 'โหมดสว่าง';

  @override
  String get themeLightDesc => 'กระดาษสว่างชัด';

  @override
  String get themeDark => 'Geek มืด';

  @override
  String get themeDarkDesc => 'เทาเข้มลึก';

  @override
  String get themeAmoled => 'ดำ AMOLED';

  @override
  String get themeAmoledDesc => 'ดำสนิท 0x000000';

  @override
  String get settingsAccentColor => 'สีเน้นธีม';

  @override
  String get accentCyberEmerald => 'มรกตไซเบอร์';

  @override
  String get accentTechBlue => 'น้ำเงินเทค';

  @override
  String get accentElectricViolet => 'ม่วงอิเล็กทริก';

  @override
  String get accentCrimsonRed => 'แดงคริมสัน';

  @override
  String get accentAmberOrange => 'ส้มอำพัน';

  @override
  String get settingsLanguage => 'ภาษาและภูมิภาค';

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
  String get settingsAiOps => 'AI Ops และระบบประมวลผล';

  @override
  String get settingsSecurity => 'การเชื่อมต่อและความปลอดภัย';

  @override
  String get settingsKnownHosts => 'คีย์โฮสต์ที่รู้จัก';

  @override
  String get settingsClearStorage => 'รีเซ็ตข้อมูลประจำตัว';

  @override
  String get settingsResetDefault => 'คืนค่าเริ่มต้น';

  @override
  String get settingsTerminalUseTmux => 'เซสชันต่อเนื่อง (tmux)';

  @override
  String get settingsTerminalUseTmuxSubtitle =>
      'เรียกใช้เซสชันเทอร์มินัลภายใน tmux บนเซิร์ฟเวอร์ระยะไกล';

  @override
  String get settingsTerminalUseTmuxDescription =>
      'รักษาผลลัพธ์ของเทอร์มินัลไว้หลังจากตัดการเชื่อมต่อ ต้องมี tmux บนเซิร์ฟเวอร์ระยะไกล การเปลี่ยนแปลงจะมีผลกับแท็บเทอร์มินัลที่เปิดใหม่';

  @override
  String get settingsTerminalFontSize => 'ขนาดตัวอักษรเทอร์มินัล';

  @override
  String get settingsTerminalFontSizeSubtitle =>
      'ปรับขนาดตัวอักษรเทอร์มินัล SSH และ CLI';

  @override
  String get version => 'เวอร์ชัน';

  @override
  String get addServer => 'เพิ่มเซิร์ฟเวอร์';

  @override
  String get editServer => 'แก้ไขเซิร์ฟเวอร์';

  @override
  String get serverName => 'ชื่อเซิร์ฟเวอร์';

  @override
  String get serverHost => 'โฮสต์ / IP';

  @override
  String get serverPort => 'พอร์ต';

  @override
  String get serverUsername => 'ชื่อผู้ใช้';

  @override
  String get serverAuthType => 'ประเภทการตรวจสอบสิทธิ์';

  @override
  String get serverPassword => 'รหัสผ่าน';

  @override
  String get serverPrivateKey => 'คีย์ส่วนตัว';

  @override
  String get serverSave => 'บันทึกเซิร์ฟเวอร์';

  @override
  String get serverDelete => 'ลบเซิร์ฟเวอร์';

  @override
  String get fileEditor => 'ตัวแก้ไขไฟล์';

  @override
  String get fileEditorSave => 'บันทึกการเปลี่ยนแปลง';

  @override
  String get fileSavedSuccess => 'บันทึกไฟล์สำเร็จ';

  @override
  String get addCommand => 'คำสั่งใหม่';

  @override
  String get commandTitle => 'ชื่อคำสั่ง';

  @override
  String get commandContent => 'ข้อความคำสั่ง';

  @override
  String get commandCategory => 'หมวดหมู่';

  @override
  String get commandDescription => 'คำอธิบาย';

  @override
  String get save => 'บันทึก';

  @override
  String get delete => 'ลบ';

  @override
  String get cancel => 'ยกเลิก';

  @override
  String get confirm => 'ยืนยัน';

  @override
  String get cmdExecutionChannel => 'ช่องทางการดำเนินการ';

  @override
  String get cmdChannelTerminal => 'ส่งตรงไปยังเทอร์มินัล SSH';

  @override
  String get cmdChannelTerminalDesc =>
      'พิมพ์คำสั่งลงในเซสชันเทอร์มินัลที่ใช้งานอยู่โดยตรง';

  @override
  String get cmdChannelBackground => 'เรียกใช้ในเซสชันพื้นหลัง';

  @override
  String get cmdChannelBackgroundDesc =>
      'ดำเนินการผ่าน SSH ล็อกอินเชลล์และบันทึกผลลัพธ์';

  @override
  String get cmdInjectedToTerminal => 'ส่งคำสั่งไปยังเทอร์มินัลแล้ว';

  @override
  String get cmdExecutionCompleted => 'ดำเนินการเสร็จสิ้น';

  @override
  String get cmdExecutionFailed => 'ดำเนินการล้มเหลว';

  @override
  String get cmdExecutingRemote => 'กำลังดำเนินการคำสั่งระยะไกล...';

  @override
  String get cmdClose => 'ปิด';

  @override
  String get navDashboard => 'แดชบอร์ด';

  @override
  String get navDocker => 'Docker';

  @override
  String get navSystem => 'ระบบ';

  @override
  String get navMore => 'เพิ่มเติม';

  @override
  String get dashboardTitle => 'แดชบอร์ดเซิร์ฟเวอร์';

  @override
  String get metricsCpu => 'การใช้งาน CPU';

  @override
  String get metricsMemory => 'การใช้งานหน่วยความจำ';

  @override
  String get metricsLoadAvg => 'โหลดเฉลี่ย';

  @override
  String get metricsUptime => 'เวลาทำงานของระบบ';

  @override
  String get metricsRootDisk => 'การใช้งานดิสก์รูท';

  @override
  String get quickActions => 'การนำทางด่วน';

  @override
  String get activeServerStatus => 'สถานะเซิร์ฟเวอร์ที่ใช้งานอยู่';

  @override
  String get noServerSelected =>
      'ยังไม่ได้เลือกเซิร์ฟเวอร์ในขณะนี้ โปรดเลือกเซิร์ฟเวอร์ก่อน';

  @override
  String get serverDisconnected => 'ตัดการเชื่อมต่อแล้ว';

  @override
  String get serverConnecting => 'กำลังเชื่อมต่อ...';

  @override
  String get connectNow => 'เชื่อมต่อทันที';

  @override
  String get serverSpecs => 'ข้อมูลและสเปกเซิร์ฟเวอร์';

  @override
  String get dockerTitle => 'คอนเทนเนอร์ Docker';

  @override
  String get dockerSearchHint => 'ค้นหาคอนเทนเนอร์ตามชื่อหรืออิมเมจ...';

  @override
  String get dockerFilterAll => 'ทั้งหมด';

  @override
  String get dockerFilterRunning => 'กำลังทำงาน';

  @override
  String get dockerFilterExited => 'ออกแล้ว';

  @override
  String get dockerFilterPaused => 'หยุดชั่วคราว';

  @override
  String get dockerActionStart => 'เริ่ม';

  @override
  String get dockerActionStop => 'หยุด';

  @override
  String get dockerActionRestart => 'เริ่มใหม่';

  @override
  String get dockerActionPause => 'หยุดชั่วคราว';

  @override
  String get dockerActionUnpause => 'ทำงานต่อ';

  @override
  String get dockerActionRm => 'ลบ';

  @override
  String get dockerActionLogs => 'บันทึก';

  @override
  String get dockerActionInspect => 'ตรวจสอบ';

  @override
  String get dockerLogsTitle => 'บันทึกคอนเทนเนอร์';

  @override
  String get dockerInspectTitle => 'การตรวจสอบคอนเทนเนอร์';

  @override
  String get dockerNoContainers => 'ไม่พบคอนเทนเนอร์บนเซิร์ฟเวอร์';

  @override
  String get dockerEmptyRunning => 'ไม่มีคอนเทนเนอร์ที่กำลังทำงาน';

  @override
  String get dockerPorts => 'พอร์ต';

  @override
  String get dockerCreated => 'สร้างเมื่อ';

  @override
  String get dockerImage => 'อิมเมจ';

  @override
  String get systemTitle => 'กระบวนการและบริการ';

  @override
  String get tabProcesses => 'กระบวนการ';

  @override
  String get tabServices => 'บริการ Systemd';

  @override
  String get processSearchHint => 'ค้นหาตามชื่อกระบวนการหรือ PID...';

  @override
  String get processPid => 'PID';

  @override
  String get processCpu => '% CPU';

  @override
  String get processMem => '% MEM';

  @override
  String get processStat => 'สถานะ';

  @override
  String get processCommand => 'คำสั่ง';

  @override
  String get processTerminate => 'ยุติ (SIGTERM)';

  @override
  String get processForceKill => 'บังคับปิด (SIGKILL)';

  @override
  String get processKillForbidden =>
      'ปฏิเสธการยุติกระบวนการเริ่มต้นระบบ (PID <= 1)';

  @override
  String get serviceSearchHint => 'ค้นหาบริการตามชื่อ...';

  @override
  String get serviceName => 'บริการ';

  @override
  String get serviceDescription => 'คำอธิบาย';

  @override
  String get serviceStatus => 'สถานะ';

  @override
  String get serviceStartup => 'การเริ่มต้น';

  @override
  String get serviceActionStart => 'เริ่ม';

  @override
  String get serviceActionStop => 'หยุด';

  @override
  String get serviceActionRestart => 'เริ่มใหม่';

  @override
  String get serviceActionReload => 'โหลดใหม่';

  @override
  String get serviceActionEnable => 'เปิดใช้งาน';

  @override
  String get serviceActionDisable => 'ปิดใช้งาน';

  @override
  String get serviceNoServices => 'ไม่พบบริการ systemd';

  @override
  String get riskDangerTitle => 'การยืนยันการดำเนินการที่มีความเสี่ยงสูง';

  @override
  String get riskWarningTitle => 'การยืนยันคำเตือนการดำเนินการ';

  @override
  String get riskSafeTitle => 'ยืนยันการดำเนินการ';

  @override
  String get riskIrreversibleWarning =>
      'การดำเนินการนี้จัดอยู่ในประเภทความเสี่ยงสูงและไม่สามารถย้อนกลับได้ อาจทำให้ข้อมูลสูญหายหรือบริการหยุดชะงัก';

  @override
  String get riskWarningDescription =>
      'การดำเนินการนี้อาจส่งผลต่อบริการที่กำลังทำงานอยู่หรือเริ่มกระบวนการใหม่ โปรดดำเนินการด้วยความระมัดระวัง';

  @override
  String get riskCommandPreview => 'ดูตัวอย่างคำสั่ง';

  @override
  String get riskConfirmButton => 'ยืนยันและดำเนินการต่อ';

  @override
  String get riskCancelButton => 'ยกเลิก';

  @override
  String get stateLoading => 'กำลังโหลดข้อมูลระยะไกล...';

  @override
  String get stateOffline => 'เซิร์ฟเวอร์ออฟไลน์';

  @override
  String get stateOfflineDesc =>
      'สร้างการเชื่อมต่อ SSH ที่ใช้งานอยู่เพื่อจัดการทรัพยากรและสตรีมเมตริก';

  @override
  String get stateError => 'เกิดข้อผิดพลาด';

  @override
  String get stateRetry => 'ลองใหม่';

  @override
  String get stateEmpty => 'ไม่พบรายการ';

  @override
  String get inspectorTitle => 'ตัวตรวจสอบ';

  @override
  String get inspectorClose => 'ปิด';

  @override
  String get inspectorDetails => 'รายละเอียดการตรวจสอบ';

  @override
  String get selectServerTitle => 'เลือกเซิร์ฟเวอร์เป้าหมาย';

  @override
  String get sshDisconnectedSuccess => 'ตัดการเชื่อมต่อ SSH สำเร็จ';

  @override
  String get trustHostFingerprintTitle => 'เชื่อถือลายนิ้วมือโฮสต์หรือไม่?';

  @override
  String get trustAndConnect => 'เชื่อถือและเชื่อมต่อ';

  @override
  String get reject => 'ปฏิเสธ';

  @override
  String get confirmDeleteServerTitle => 'ลบเซิร์ฟเวอร์';

  @override
  String get noServersFound => 'ยังไม่มีการกำหนดค่าเซิร์ฟเวอร์';

  @override
  String get agentNotReadyError =>
      'Agent ที่เลือกยังไม่พร้อม โปรดตรวจสอบสภาพแวดล้อมและการกำหนดค่า';

  @override
  String get sshDisconnectedError =>
      'SSH ถูกตัดการเชื่อมต่อ โปรดเชื่อมต่อกับเซิร์ฟเวอร์ก่อนใช้ AI Ops';

  @override
  String get noAgentAvailable => 'ไม่มี Agent ที่พร้อมใช้งาน';

  @override
  String get noAgentAvailablePrompt =>
      'ไม่มี Agent ที่ใช้งานอยู่ โปรดกำหนดค่าหรือเตรียม Agent ก่อน';

  @override
  String get noAgentAvailableHint =>
      'เลือกหรือกำหนดค่า Agent ที่พร้อมใช้งานเพื่อแชท...';

  @override
  String get manageAgents => 'จัดการ Agent';

  @override
  String get noReadyAgentsTitle => 'ไม่มี Agent ที่พร้อมใช้งาน';

  @override
  String get noReadyAgentsDesc =>
      'ไม่มี Agent บนเซิร์ฟเวอร์นี้ที่ผ่านการตรวจสอบสภาพแวดล้อม';

  @override
  String get agentStatusReady => 'พร้อม';

  @override
  String get agentStatusChecking => 'กำลังตรวจสอบ...';

  @override
  String get agentStatusCliMissing => 'ตรวจไม่พบการติดตั้ง';

  @override
  String get agentStatusAcpMissing => 'ตรวจไม่พบคอมโพเนนต์ ACP';

  @override
  String get agentStatusNotLoggedIn => 'ยังไม่ได้เข้าสู่ระบบ';

  @override
  String get agentStatusError => 'ข้อผิดพลาด';

  @override
  String get agentStatusUnknown => 'ไม่ทราบ';

  @override
  String get agentActionInstall => 'ติดตั้ง';

  @override
  String get agentActionLogin => 'เข้าสู่ระบบ';

  @override
  String get agentActionRefresh => 'ตรวจสอบสถานะ';

  @override
  String get noConfiguredAgents => 'ไม่มีการกำหนดค่า Agent บนเซิร์ฟเวอร์นี้';

  @override
  String get agentManagementTitle => 'การจัดการ Agent';

  @override
  String get settingsAgentManagement => 'การจัดการ Agent';

  @override
  String get settingsAgentManagementSubtitle =>
      'กำหนดค่า ตรวจหา และจัดการ ACP Agent สำหรับเซิร์ฟเวอร์ปัจจุบัน';

  @override
  String get addAgentButton => 'เพิ่ม Agent';

  @override
  String get noServerSelectedForAgents =>
      'ยังไม่ได้เลือกเซิร์ฟเวอร์ โปรดเลือกเซิร์ฟเวอร์จากหน้าจอหลักก่อน';

  @override
  String get sshDisconnectedAgentWarning =>
      'SSH ถูกตัดการเชื่อมต่อ การตรวจหา การติดตั้ง และการเข้าสู่ระบบจะถูกปิดใช้งานจนกว่าจะเชื่อมต่อ';

  @override
  String get noAgentsConfiguredTitle => 'ยังไม่ได้กำหนดค่า Agent';

  @override
  String get noAgentsConfiguredDesc =>
      'เพิ่ม Claude Code, Codex, OpenCode, AGY หรือ Agent ACP ที่กำหนดเองเพื่อเปิดใช้งาน AI Ops บนเซิร์ฟเวอร์นี้';

  @override
  String get agentPresetLabel => 'เทมเพลตที่ตั้งไว้';

  @override
  String get agentPresetClaudeCode => 'Claude Code';

  @override
  String get agentPresetCodex => 'OpenAI Codex';

  @override
  String get agentPresetOpenCode => 'OpenCode ACP';

  @override
  String get agentPresetAgy => 'Antigravity AGY';

  @override
  String get agentPresetCustom => 'กำหนดเอง';

  @override
  String get agentNameLabel => 'ชื่อ Agent';

  @override
  String get agentNameHint => 'เช่น Production Codex';

  @override
  String get agentDescriptionLabel => 'คำอธิบาย';

  @override
  String get agentDescriptionHint => 'คำอธิบายสั้นๆ เกี่ยวกับ Agent';

  @override
  String get agentCliCommandLabel => 'คำสั่งตรวจสอบ CLI';

  @override
  String get agentCliCommandHint => 'เช่น claude, codex';

  @override
  String get agentAcpCommandLabel => 'คำสั่งเปิดใช้งาน ACP';

  @override
  String get agentAcpCommandHint => 'เช่น codex-acp --stdio';

  @override
  String get agentInstallCommandLabel => 'คำสั่งติดตั้ง (ไม่บังคับ)';

  @override
  String get agentInstallCommandHint => 'เช่น npm install -g @openai/codex';

  @override
  String get agentLoginCheckCommandLabel =>
      'คำสั่งตรวจสอบการเข้าสู่ระบบ (ไม่บังคับ)';

  @override
  String get agentLoginCheckCommandHint => 'เช่น codex --version';

  @override
  String get agentLoginCommandLabel => 'คำสั่งเข้าสู่ระบบ (ไม่บังคับ)';

  @override
  String get agentLoginCommandHint => 'เช่น codex login';

  @override
  String get agentSaveButton => 'บันทึกและตรวจหา';

  @override
  String get agentCliRequired => 'จำเป็นต้องระบุคำสั่งตรวจสอบ CLI';

  @override
  String get agentAcpRequired => 'จำเป็นต้องระบุคำสั่งเปิดใช้งาน ACP';

  @override
  String get agentNameRequired => 'จำเป็นต้องระบุชื่อ Agent';

  @override
  String get confirmInstallAgentTitle => 'ยืนยันการติดตั้ง Agent';

  @override
  String get confirmLoginAgentTitle => 'ยืนยันการเข้าสู่ระบบ Agent';

  @override
  String get agentCommandRiskWarning =>
      'คำสั่งนี้จะถูกดำเนินการโดยตรงบนเซิร์ฟเวอร์ระยะไกลด้วยสิทธิ์ผู้ใช้ปัจจุบัน อาจติดตั้งแพ็กเกจหรือแก้ไขสภาพแวดล้อมระบบ';

  @override
  String get targetServerLabel => 'เซิร์ฟเวอร์เป้าหมาย';

  @override
  String get commandPreviewLabel => 'ดูตัวอย่างคำสั่ง';

  @override
  String get executeButton => 'ดำเนินการ';

  @override
  String get deleteAgentTitle => 'ลบ Agent';

  @override
  String get deleteAgentConfirm => 'ลบ';

  @override
  String get agentStatusCheckingDesc =>
      'กำลังตรวจหาสภาพแวดล้อมบนเซิร์ฟเวอร์ระยะไกล...';

  @override
  String get agentStatusInstalling => 'กำลังติดตั้งการพึ่งพาบนเซิร์ฟเวอร์...';

  @override
  String get agentStatusLoggingIn =>
      'กำลังดำเนินการคำสั่งเข้าสู่ระบบบนเซิร์ฟเวอร์...';

  @override
  String get agentNoLoginCheckProvided =>
      'ไม่ได้ระบุคำสั่งตรวจสอบการเข้าสู่ระบบ';

  @override
  String get agentInstallPrompt =>
      'ตรวจไม่พบการติดตั้ง ติดตั้งอัตโนมัติตอนนี้หรือไม่?';

  @override
  String get agentActionAutoInstall => 'ติดตั้งอัตโนมัติ';

  @override
  String get agentLoginPrompt =>
      'ยังไม่ได้เข้าสู่ระบบ เข้าสู่ระบบตอนนี้หรือไม่?';

  @override
  String get agentActionExecuteLogin => 'เข้าสู่ระบบตอนนี้';

  @override
  String get agentNeedsInstallOrReadyPrompt =>
      'Agent บนเซิร์ฟเวอร์นี้ยังไม่ได้ติดตั้งหรือไม่พร้อม โปรดจัดการและตั้งค่าสภาพแวดล้อมให้เสร็จสิ้น';

  @override
  String get agentNeedsInstallOrReadyHint =>
      'ติดตั้งและเตรียม Agent ให้พร้อมเพื่อเริ่มแชท...';

  @override
  String get agentAcpInstallPrompt =>
      'ตรวจไม่พบคอมโพเนนต์ ACP ติดตั้งอัตโนมัติตอนนี้หรือไม่?';

  @override
  String get agentInstallCommandAcpLabel => 'คำสั่งติดตั้ง ACP (ไม่บังคับ)';

  @override
  String get agentInstallCommandAcpHint =>
      'เช่น npm install -g @zed-industries/codex-acp';

  @override
  String get agentNoInstallCommand =>
      'ไม่มีคำสั่งติดตั้งที่กำหนดค่าไว้สำหรับ Agent นี้';

  @override
  String get agentInstallLogTitle => 'ผลลัพธ์การติดตั้ง';

  @override
  String get agentInstallLogEmpty => 'กำลังรอผลลัพธ์การติดตั้ง…';

  @override
  String get agentInstallLogTruncated =>
      'ผลลัพธ์ยาวเกินไป แสดงเฉพาะบรรทัดล่าสุด';

  @override
  String get agentAcpOptional => 'ไม่บังคับ เว้นว่างไว้สำหรับ CLI เท่านั้น';

  @override
  String get acpStreaming => 'กำลังสตรีม ACP...';

  @override
  String get aiOpsAgentTitle => 'Agent Valhalla AI Ops';

  @override
  String get aiOpsEmptySubtitle => 'เชื่อมต่อผ่าน ACP stdio บนช่องทาง SSH';

  @override
  String get agentAuthRequiredTitle => 'จำเป็นต้องตรวจสอบสิทธิ์';

  @override
  String get agentAuthRequiredDesc =>
      'Agent ต้องการการตรวจสอบสิทธิ์ก่อนที่จะสามารถประมวลผลคำขอของคุณได้';

  @override
  String get agentAuthMethodLabel => 'วิธีการตรวจสอบสิทธิ์';

  @override
  String get agentAuthNoMethodsNotice =>
      'Agent ไม่ได้ระบุวิธีการเข้าสู่ระบบ โปรดตรวจสอบการกำหนดค่าบนเซิร์ฟเวอร์';

  @override
  String get agentAuthProceedButton => 'เข้าสู่ระบบ';

  @override
  String get agentAuthCancelButton => 'ยกเลิก';

  @override
  String get agentAuthRetryHint =>
      'หลังจากเข้าสู่ระบบแล้ว ให้ส่งข้อความของคุณอีกครั้ง';

  @override
  String get agentAuthRequiredError =>
      'จำเป็นต้องตรวจสอบสิทธิ์ โปรดเข้าสู่ระบบเพื่อดำเนินการต่อ';

  @override
  String get agentLoginTerminalTitle => 'เทอร์มินัลเข้าสู่ระบบแบบโต้ตอบ';

  @override
  String get agentLoginTerminalSubtitle =>
      'ทำตามขั้นตอนการเข้าสู่ระบบในเทอร์มินัลด้านล่าง ทำตามคำแนะนำ URL หรือรหัสที่แสดง';

  @override
  String get agentLoginTerminalRunning =>
      'คำสั่งเข้าสู่ระบบกำลังทำงานในเทอร์มินัล...';

  @override
  String get agentLoginTerminalDisconnected =>
      'การเชื่อมต่อ SSH ขาดหาย เซสชันการเข้าสู่ระบบหยุดชะงัก';

  @override
  String get agentLoginTerminalRetry => 'เชื่อมต่อเทอร์มินัลใหม่';

  @override
  String get agentLoginTerminalFinish => 'เสร็จสิ้นและยืนยัน';

  @override
  String get agentLoginTerminalClose => 'ปิด';

  @override
  String get agentLoginTerminalNoTtyHint =>
      'หาก Agent ต้องการให้วางรหัส ให้กดค้างที่เทอร์มินัลเพื่อวางหรือใช้ปุ่ม PASTE';

  @override
  String get agentLoginTerminalUrlLabel => 'ตรวจพบ URL เข้าสู่ระบบ';

  @override
  String get agentLoginTerminalUrlCopy => 'คัดลอกลิงก์';

  @override
  String get agentLoginTerminalUrlCopied =>
      'คัดลอก URL เข้าสู่ระบบไปยังคลิปบอร์ดแล้ว';

  @override
  String get agentLoginTerminalCopyAll => 'คัดลอกผลลัพธ์ทั้งหมด';

  @override
  String get agentLoginTerminalCopiedAll =>
      'คัดลอกผลลัพธ์เทอร์มินัลไปยังคลิปบอร์ดแล้ว';

  @override
  String get sshStatusReconnected => 'กู้คืนการเชื่อมต่อแล้ว';

  @override
  String get sshStatusDisconnectedRetrying => 'การเชื่อมต่อขาดหาย กำลังลองใหม่';

  @override
  String get sshStatusDisconnectedManual => 'ตัดการเชื่อมต่อแล้ว';

  @override
  String get sshStatusHostKeyChanged =>
      'คีย์โฮสต์เปลี่ยนไป — ปฏิเสธการเชื่อมต่อ';

  @override
  String get sshKeepAliveNotificationTitle =>
      'Valhalla กำลังรักษาเซสชันของคุณให้ทำงานอยู่';

  @override
  String get terminalTmuxMissingNotice =>
      'ไม่พบ tmux — เซสชันจะไม่คงอยู่หากการเชื่อมต่อหลุด';

  @override
  String get terminalTmuxSessionRestored => 'กู้คืนเซสชันเทอร์มินัลแล้ว';

  @override
  String get moshSectionTitle => 'Mosh';

  @override
  String get moshEnable =>
      'เปิดใช้ Mosh — เทอร์มินัลโรมมิ่งที่ทนต่อการเชื่อมต่อหลุดและการเปลี่ยน IP';

  @override
  String get moshServerPathLabel => 'เส้นทาง mosh-server';

  @override
  String get moshPortRangeLabel => 'ช่วงพอร์ต UDP';

  @override
  String get moshNewSession => 'เซสชัน Mosh ใหม่';

  @override
  String get moshNotInstalled =>
      'ไม่พบ mosh-server บนเซิร์ฟเวอร์ระยะไกล ติดตั้งด้วย: sudo apt install mosh (Debian/Ubuntu) หรือ sudo dnf install mosh (Fedora/RHEL)';

  @override
  String moshBootstrapFailed(String detail) {
    return 'เริ่มเซสชัน Mosh ล้มเหลว: $detail';
  }

  @override
  String get moshUdpTimeout =>
      'การเชื่อมต่อ Mosh หมดเวลา — ตรวจสอบว่าทราฟฟิก UDP ไม่ได้ถูกบล็อกโดยไฟร์วอลล์';

  @override
  String get moshSessionTag => 'mosh';

  @override
  String get acpSessionRestored => 'กู้คืนเซสชัน Agent แล้ว';

  @override
  String get acpSessionRestartNotice =>
      'เริ่มเซสชัน Agent ใหม่แล้ว — บริบทก่อนหน้าไม่พร้อมใช้งาน';

  @override
  String get terminalTmuxInstallDialogTitle =>
      'ติดตั้ง tmux บนเซิร์ฟเวอร์ระยะไกลหรือไม่?';

  @override
  String get terminalTmuxInstallDialogMessage =>
      'จำเป็นต้องใช้ tmux เพื่อรักษาเซสชันเทอร์มินัลเมื่อการเชื่อมต่อหลุด คุณต้องการติดตั้งตอนนี้หรือไม่?';

  @override
  String get terminalTmuxInstallCommandLabel => 'คำสั่งที่จะดำเนินการ:';

  @override
  String get terminalTmuxInstallUnsupported =>
      'ตรวจไม่พบตัวจัดการแพ็กเกจที่รองรับบนเซิร์ฟเวอร์ระยะไกล โปรดติดตั้ง tmux ด้วยตนเอง';

  @override
  String get terminalTmuxInstallFailed =>
      'การติดตั้ง tmux ล้มเหลว โปรดตรวจสอบสิทธิ์เซิร์ฟเวอร์และเครือข่าย';

  @override
  String get terminalTmuxInstallDisconnected =>
      'การเชื่อมต่อ SSH ขาดหาย โปรดเชื่อมต่อใหม่เพื่อติดตั้ง tmux';

  @override
  String get terminalTmuxInstallInstalling => 'กำลังติดตั้ง tmux...';

  @override
  String get terminalTmuxInstallConfirm => 'ติดตั้ง tmux';

  @override
  String get terminalTmuxInstallSkip => 'ข้าม (ใช้เชลล์ธรรมดา)';

  @override
  String get sftpDownload => 'ดาวน์โหลด';

  @override
  String get sftpOpen => 'เปิด';

  @override
  String get sftpUploadFailed => 'อัปโหลดล้มเหลว ตรวจสอบสิทธิ์แล้วลองใหม่';

  @override
  String get sftpDownloadFailed => 'ดาวน์โหลดล้มเหลว';

  @override
  String get sftpOpenUnsupported => 'ไม่สามารถเปิดรูปแบบไฟล์นี้ได้';

  @override
  String get sftpReadFailed => 'อ่านไฟล์ล้มเหลว ตรวจสอบสิทธิ์แล้วลองใหม่';

  @override
  String get sftpTransferFailed => 'การดำเนินการกับไฟล์ล้มเหลว โปรดลองอีกครั้ง';

  @override
  String get sftpDownloadSuccess => 'ดาวน์โหลดสำเร็จ';

  @override
  String get sftpUploading => 'กำลังอัปโหลด...';

  @override
  String get sftpDownloading => 'กำลังดาวน์โหลด...';

  @override
  String get sftpUpDirectory => 'ขึ้นไปยังไดเรกทอรีหลัก';

  @override
  String get sftpShowHiddenFiles => 'แสดงไฟล์ที่ซ่อนอยู่';

  @override
  String get sftpHideHiddenFiles => 'ซ่อนไฟล์ที่ซ่อนอยู่';

  @override
  String get sftpHiddenPreferenceSaveFailed =>
      'บันทึกการตั้งค่าไฟล์ที่ซ่อนไม่สำเร็จ';

  @override
  String get sftpSymlink => 'ลิงก์สัญลักษณ์';

  @override
  String get sftpLinkTargetUnavailable =>
      'ปลายทางของลิงก์สัญลักษณ์เสียหายหรือใช้งานไม่ได้';

  @override
  String get sftpLinkTargetPermissionDenied =>
      'ปฏิเสธการอนุญาตให้อ่านปลายทางของลิงก์สัญลักษณ์';

  @override
  String get settingsAutoConnect => 'เชื่อมต่ออัตโนมัติเมื่อเปิดแอป';

  @override
  String get settingsAutoConnectFixed => 'SSH เริ่มต้นคงที่';

  @override
  String get settingsAutoConnectFixedDesc =>
      'เชื่อมต่อกับเซิร์ฟเวอร์ที่คุณเลือกด้านล่างเสมอ';

  @override
  String get settingsAutoConnectLast => 'จดจำการเชื่อมต่อล่าสุด';

  @override
  String get settingsAutoConnectLastDesc =>
      'เชื่อมต่อกับเซิร์ฟเวอร์ที่เชื่อมต่อสำเร็จล่าสุด';

  @override
  String get settingsAutoConnectPickServer => 'เซิร์ฟเวอร์';

  @override
  String get settingsAutoConnectNoServer => 'ยังไม่ได้เลือกเซิร์ฟเวอร์';

  @override
  String get sftpSort => 'เรียงลำดับ';

  @override
  String get sftpSortName => 'ชื่อ';

  @override
  String get sftpSortSize => 'ขนาด';

  @override
  String get sftpSortDate => 'วันที่แก้ไข';

  @override
  String get sftpSortAscending => 'จากน้อยไปมาก';

  @override
  String get sftpSortDescending => 'จากมากไปน้อย';

  @override
  String get themeQuickSwitch => 'ธีม';

  @override
  String get transferList => 'การถ่ายโอน';

  @override
  String get transferEmpty => 'ยังไม่มีการถ่ายโอน';

  @override
  String get transferUpload => 'อัปโหลด';

  @override
  String get transferDownload => 'ดาวน์โหลด';

  @override
  String get transferStatusQueued => 'อยู่ในคิว';

  @override
  String get transferStatusRunning => 'กำลังถ่ายโอน';

  @override
  String get transferStatusPaused => 'หยุดชั่วคราว';

  @override
  String get transferStatusCompleted => 'เสร็จสิ้น';

  @override
  String get transferStatusFailed => 'ล้มเหลว';

  @override
  String get transferStatusCanceled => 'ยกเลิกแล้ว';

  @override
  String get transferPause => 'หยุดชั่วคราว';

  @override
  String get transferResume => 'ดำเนินการต่อ';

  @override
  String get transferCancel => 'ยกเลิก';

  @override
  String get transferRemove => 'ลบ';

  @override
  String get transferClearFinished => 'ล้างรายการที่เสร็จแล้ว';

  @override
  String get transferSizeUnknown => 'ไม่ทราบขนาด';

  @override
  String get transferFailedUpload => 'อัปโหลดล้มเหลว';

  @override
  String get transferFailedDownload => 'ดาวน์โหลดล้มเหลว';

  @override
  String get stopGeneration => 'หยุด';

  @override
  String get chatServerBindingRequired =>
      'เซสชันนี้ไม่ได้ผูกกับเซิร์ฟเวอร์ โปรดผูกกับเซิร์ฟเวอร์ปัจจุบันเพื่อดำเนินการต่อ';

  @override
  String get chatSessionUnboundNotice => 'เซสชันนี้ไม่ได้ผูกกับเซิร์ฟเวอร์ใดๆ';

  @override
  String get bindServerAction => 'ผูกเซิร์ฟเวอร์';

  @override
  String get bindServerDialogTitle => 'ผูกเซสชันกับเซิร์ฟเวอร์';

  @override
  String get bindServerConfirmAction => 'ยืนยันการผูก';

  @override
  String get chatSessionIdentityMismatch =>
      'เซิร์ฟเวอร์หรือ Agent ปัจจุบันไม่ตรงกับข้อมูลประจำตัวที่ผูกไว้ของเซสชันนี้ สลับไปยังเซิร์ฟเวอร์และ Agent ที่ตรงกันเพื่อดำเนินการต่อ';

  @override
  String get deleteSessionTitle => 'ลบเซสชัน';

  @override
  String get deleteSessionConfirmAction => 'ลบ';

  @override
  String get shareAgentSessionsTitle => 'แชร์เซสชัน Agent';

  @override
  String get shareAgentSessionsSubtitle =>
      'แชร์เซสชันข้าม Agent ต่างๆ บนเซิร์ฟเวอร์นี้';

  @override
  String get shareAgentSessionsEnabled => 'เปิดใช้งานการแชร์เซสชัน Agent แล้ว';

  @override
  String get shareAgentSessionsDisabled => 'ปิดใช้งานการแชร์เซสชัน Agent แล้ว';

  @override
  String get agentCliStatusInstalled => 'CLI: ติดตั้งแล้ว';

  @override
  String get agentCliStatusMissing => 'CLI: ขาดหาย';

  @override
  String get agentCliStatusChecking => 'CLI: กำลังตรวจสอบ...';

  @override
  String get agentCliStatusUnknown => 'CLI: ไม่ทราบ';

  @override
  String get agentCliStatusError => 'CLI: ข้อผิดพลาด';

  @override
  String get agentAcpStatusReady => 'ACP: พร้อม';

  @override
  String get agentAcpStatusMissing => 'ACP: ขาดหาย';

  @override
  String get agentAcpStatusChecking => 'ACP: กำลังตรวจสอบ...';

  @override
  String get agentAcpStatusPendingCli => 'ACP: รอ CLI';

  @override
  String get agentAcpStatusUnknown => 'ACP: ไม่ทราบ';

  @override
  String get agentAcpStatusError => 'ACP: ข้อผิดพลาด';

  @override
  String get agentAcpStatusNa => 'ACP: ไม่มีข้อมูล';

  @override
  String get agentAuthStatusAuthenticated =>
      'การตรวจสอบสิทธิ์: เข้าสู่ระบบแล้ว';

  @override
  String get agentAuthStatusUnauthenticated =>
      'การตรวจสอบสิทธิ์: ยังไม่ได้เข้าสู่ระบบ';

  @override
  String get agentAuthStatusUnknown => 'การตรวจสอบสิทธิ์: ไม่ทราบ';

  @override
  String get downloadNotificationsUnavailable =>
      'การแจ้งเตือนการดาวน์โหลดของระบบไม่พร้อมใช้งาน การดาวน์โหลดจะดำเนินต่อไปในพื้นหลัง';

  @override
  String get downloadOpenFailed => 'ไม่สามารถเปิดไฟล์ที่ดาวน์โหลดได้';

  @override
  String get dockerActionPending =>
      'กำลังดำเนินการสำหรับการดำเนินการนี้ในคอนเทนเนอร์แล้ว';

  @override
  String get dockerNoLogs => '(ไม่มีบันทึก)';

  @override
  String get serverReboot => 'รีบูต';

  @override
  String get serverRebootDialogTitle => 'ยืนยันการรีบูตเซิร์ฟเวอร์';

  @override
  String get serverRebootDialogMessage =>
      'คุณแน่ใจหรือไม่ว่าต้องการรีบูตเซิร์ฟเวอร์นี้? การเชื่อมต่อและบริการพื้นหลังที่ใช้งานอยู่ทั้งหมดจะถูกยกเลิก';

  @override
  String get serverRebootConfirmButton => 'รีบูตทันที';

  @override
  String get serverRebootPasswordTitle => 'จำเป็นต้องใช้รหัสผ่าน Sudo';

  @override
  String get serverRebootPasswordMessage =>
      'จำเป็นต้องมีสิทธิ์รูทเพื่อรีบูตเซิร์ฟเวอร์ โปรดป้อนรหัสผ่าน sudo (ใช้ครั้งเดียว ไม่มีการบันทึก):';

  @override
  String get serverRebootPasswordHint => 'รหัสผ่าน Sudo';

  @override
  String get serverRebootSubmitting => 'กำลังส่งคำสั่งรีบูต...';

  @override
  String get serverRebootAccepted =>
      'ยอมรับคำสั่งรีบูตแล้ว ยังไม่ได้ตรวจสอบการเสร็จสมบูรณ์ โปรดเชื่อมต่อใหม่เมื่อเซิร์ฟเวอร์กลับมาออนไลน์';

  @override
  String get serverRebootVerified =>
      'การรีบูตเซิร์ฟเวอร์ได้รับการยืนยันแล้ว ระบบกลับมาออนไลน์แล้ว';

  @override
  String get serverRebootUnknown =>
      'ผลการรีบูตไม่แน่นอน ส่งคำสั่งแล้วแต่ไม่สามารถยืนยันความสมบูรณ์ได้ โปรดตรวจสอบการเชื่อมต่อด้วยตนเอง';

  @override
  String get serverRebootReconnect => 'เชื่อมต่อใหม่';

  @override
  String get serverRebootServerChanged =>
      'เซิร์ฟเวอร์เป้าหมายเปลี่ยนไป ยกเลิกการรีบูตแล้ว';

  @override
  String get navCliChat => 'แชท CLI';

  @override
  String get cliChatTitle => 'เซสชัน CLI';

  @override
  String get cliChatSubtitle => 'เซสชัน Agent CLI ดั้งเดิมบนเซิร์ฟเวอร์ระยะไกล';

  @override
  String get cliSelectAgent => 'เลือก Agent';

  @override
  String get cliNoAgentsConfigured =>
      'ไม่มีการเพิ่ม Agent สำหรับเซิร์ฟเวอร์นี้';

  @override
  String get cliAgentNeedsSetup =>
      'สภาพแวดล้อม Agent ขาดหายหรือยังไม่ได้เข้าสู่ระบบ';

  @override
  String get cliManageAgentsGuide => 'กำหนดค่าในการจัดการ Agent';

  @override
  String get cliNewDraft => 'ฉบับร่างใหม่';

  @override
  String get cliNewDraftTooltip =>
      'สร้างฉบับร่างเปล่า (เซสชันจะถูกสร้างขึ้นเมื่อส่งข้อความแรก)';

  @override
  String get cliDeleteSessionTitle => 'ลบประวัติเซสชัน CLI ระยะไกล';

  @override
  String get cliDeleteSessionMessage =>
      'การดำเนินการนี้จะลบประวัติเซสชัน CLI บนเซิร์ฟเวอร์ระยะไกลอย่างถาวร คุณแน่ใจหรือไม่ว่าต้องการดำเนินการต่อ?';

  @override
  String get cliDeleteConfirmButton => 'ลบเซสชัน';

  @override
  String get cliCannotDeleteTooltip =>
      'ไม่รองรับการลบเซสชันระยะไกลหรือถูกปิดใช้งาน';

  @override
  String get cliSessionsHeader => 'เซสชัน';

  @override
  String get cliNoSessions => 'ไม่พบเซสชัน CLI';

  @override
  String get cliFilterCwdHint => 'กรองตามเส้นทาง CWD...';

  @override
  String get cliFilterCwdAction => 'กรอง';

  @override
  String get cliClearCwdAction => 'ล้าง';

  @override
  String get cliLoadMoreSessions => 'โหลดเซสชันเพิ่มเติม';

  @override
  String get cliRefreshSessions => 'รีเฟรช';

  @override
  String get cliClaudeReadOnlyNotice =>
      'ประวัติ Claude เป็นแบบอ่านอย่างเดียว ดำเนินการสนทนาต่อในเทอร์มินัลจริง';

  @override
  String get cliContinueInTerminal => 'ดำเนินการต่อในเทอร์มินัล';

  @override
  String get cliOpenTerminal => 'เปิดเทอร์มินัล';

  @override
  String get cliCloseTerminal => 'ปิดเทอร์มินัล';

  @override
  String get cliTerminalRunning => 'เทอร์มินัล CLI แบบโต้ตอบ';

  @override
  String get cliAgyTerminalOnlyNotice =>
      'Agent นี้ไม่รองรับการซิงโครไนซ์ประวัติแบบมีโครงสร้าง โปรดใช้เทอร์มินัล CLI ดั้งเดิมสำหรับการโต้ตอบและการเลือกเซสชัน';

  @override
  String get cliInstallSdkTitle => 'ติดตั้ง SDK ประวัติ Claude อย่างเป็นทางการ';

  @override
  String get cliInstallSdkMessage =>
      'ไม่มี SDK ประวัติ Claude Code อย่างเป็นทางการบนเซิร์ฟเวอร์ระยะไกล คุณต้องการติดตั้งตอนนี้หรือไม่?';

  @override
  String get cliInstallSdkAction => 'ติดตั้ง SDK อย่างเป็นทางการ';

  @override
  String get cliApprovalsTitle => 'การอนุมัติที่รอดำเนินการ';

  @override
  String get cliApprovalDetails => 'รายละเอียด';

  @override
  String get cliApprovalAllow => 'อนุญาต';

  @override
  String get cliApprovalDecline => 'ปฏิเสธ';

  @override
  String get cliInputHint => 'พิมพ์ข้อความถึง Agent CLI...';

  @override
  String get cliSend => 'ส่ง';

  @override
  String get cliStop => 'หยุด';

  @override
  String get cliBusy => 'กำลังดำเนินการ โปรดรอสักครู่...';

  @override
  String get cliDisconnected => 'SSH ไม่ได้เชื่อมต่อ';

  @override
  String get cliServerChanged => 'เซิร์ฟเวอร์เป้าหมายเปลี่ยนไป';

  @override
  String get cliTurnFailed => 'การดำเนินการรอบ CLI ล้มเหลว';

  @override
  String get cliUseTerminal =>
      'จำเป็นต้องใช้พร้อมต์แบบโต้ตอบ โปรดเปิดเทอร์มินัลเพื่อดำเนินการต่อ';

  @override
  String get cliDeleteFailed => 'ไม่สามารถลบเซสชันระยะไกลได้';

  @override
  String get cliDeleteUnsupported => 'CLI นี้ไม่รองรับการลบเซสชันระยะไกล';

  @override
  String get cliOperationFailed => 'การดำเนินการ CLI ล้มเหลว';

  @override
  String get cliHistorySdkMissing =>
      'ไม่มี SDK ประวัติอย่างเป็นทางการบนเซิร์ฟเวอร์';

  @override
  String get cliHistoryRuntimeMissing =>
      'ประวัติ Claude ต้องการ Node.js/npm บนเซิร์ฟเวอร์ โปรดติดตั้ง Node.js ด้วยตนเอง คุณยังคงสามารถใช้ CLI จริงในเทอร์มินัลได้';

  @override
  String get cliLoginRequired =>
      'จำเป็นต้องเข้าสู่ระบบ Agent โปรดเข้าสู่ระบบผ่านการจัดการ Agent';

  @override
  String get cliNotInstalled =>
      'ยังไม่ได้ติดตั้ง Agent CLI โปรดติดตั้งผ่านการจัดการ Agent';

  @override
  String get cliVersionUnsupported =>
      'ไม่รองรับเวอร์ชัน Agent CLI โปรดอัปเกรดหรือติดตั้งใหม่ผ่านการจัดการ Agent';

  @override
  String get settingsNavigation => 'การนำทาง';

  @override
  String get settingsNavigationDesc =>
      'กำหนดค่าหน้าเริ่มต้นเริ่มต้นและแถบนำทางด้านล่าง';

  @override
  String get settingsStartupPage => 'หน้าเริ่มต้น';

  @override
  String get settingsStartupPageDesc => 'หน้าที่แสดงเมื่อเปิดแอป';

  @override
  String get settingsBottomNav => 'แถบนำทางด้านล่าง';

  @override
  String get settingsBottomNavDesc =>
      'เลือกส่วนที่จะแสดงในแถบด้านล่างบนมือถือ (รองรับ 0 ถึง 9 รายการ)';

  @override
  String get settingsResetSuccess =>
      'คืนค่าการตั้งค่าทั้งหมดเป็นค่าเริ่มต้นแล้ว';

  @override
  String get metricsTrendSubtitle => '~3 นาทีที่ผ่านมา (สูงสุด 60 ตัวอย่าง)';

  @override
  String get metricsCurrent => 'ปัจจุบัน';

  @override
  String get metricsPeak => 'สูงสุด';

  @override
  String get metricsValley => 'ต่ำสุด';

  @override
  String get metricsTrendWaiting => 'กำลังรวบรวมข้อมูลเมตริก...';

  @override
  String get metricsTrendStopped =>
      'หยุดการรวบรวมข้อมูลแล้ว (SSH ตัดการเชื่อมต่อ)';

  @override
  String get dockerActionTerminal => 'เทอร์มินัล Exec';

  @override
  String get dockerTerminalTitle => 'เทอร์มินัลคอนเทนเนอร์';

  @override
  String get dockerTerminalNotRunning => 'คอนเทนเนอร์ไม่ได้ทำงาน';

  @override
  String get setDefaultAgent => 'ตั้งเป็นค่าเริ่มต้น';

  @override
  String get defaultBadge => 'ค่าเริ่มต้น';

  @override
  String get isDefaultAgent => 'Agent เริ่มต้น';

  @override
  String get setAsDefaultAgent => 'ตั้งเป็น Agent เริ่มต้นสำหรับเซิร์ฟเวอร์นี้';

  @override
  String get agentGroupBasic => 'ข้อมูลพื้นฐาน';

  @override
  String get agentGroupCommands => 'คำสั่ง';

  @override
  String get agentGroupAuth => 'การติดตั้งและการตรวจสอบสิทธิ์';

  @override
  String get agentPresetTitle => 'เทมเพลตที่ตั้งไว้';

  @override
  String get resourceProcessList => 'กระบวนการ';

  @override
  String get resourceDiskScanning =>
      'กำลังสแกนไดเรกทอรีรูท อาจใช้เวลาสองสามวินาที...';

  @override
  String get resourceDiskScanPartial =>
      'บางไดเรกทอรีไม่สามารถสแกนได้เนื่องจากสิทธิ์หรือหมดเวลา';

  @override
  String get resourceDiskDirectories => 'การใช้งานไดเรกทอรีระดับบนสุด';

  @override
  String get resourceSortCpu => 'เรียงตาม CPU';

  @override
  String get resourceSortMemory => 'เรียงตามหน่วยความจำ';

  @override
  String get resourceRss => 'หน่วยความจำ RSS';

  @override
  String get resourceUsed => 'ใช้ไป';

  @override
  String get resourceAvailable => 'พร้อมใช้งาน';

  @override
  String get resourceTotal => 'ทั้งหมด';

  @override
  String get settingsBottomNavOrderTitle =>
      'รายการที่เลือก (ลากเพื่อจัดลำดับใหม่)';

  @override
  String get langSystem => 'ตามระบบ';

  @override
  String get serverFieldRequired => 'จำเป็น';

  @override
  String get serverPortInvalid => 'พอร์ตต้องอยู่ระหว่าง 1 ถึง 65535';

  @override
  String get serverTestReachability => 'ทดสอบการเข้าถึง';

  @override
  String get serverSaveFailedGeneric =>
      'บันทึกเซิร์ฟเวอร์ไม่สำเร็จ โปรดตรวจสอบการกำหนดค่าของคุณแล้วลองอีกครั้ง';

  @override
  String get serverViewPrivateKey => 'ดูคีย์ส่วนตัว';

  @override
  String get serverHidePrivateKey => 'ซ่อนคีย์ส่วนตัว';

  @override
  String get dockerBashFallbackNotice =>
      'Bash ไม่พร้อมใช้งานในคอนเทนเนอร์ สลับไปใช้ Sh';

  @override
  String get dockerShellLabel => 'เชลล์';

  @override
  String get dockerShellBash => 'Bash';

  @override
  String get dockerShellSh => 'Sh';

  @override
  String get cliDraftWorkingDirLabel => 'ไดเรกทอรีทำงาน';

  @override
  String get cliDefaultWorkingDir => 'ค่าเริ่มต้น (/)';

  @override
  String get cliPickWorkingDirTitle => 'เลือกไดเรกทอรีทำงาน';

  @override
  String get cliClearWorkingDir => 'รีเซ็ตเป็นค่าเริ่มต้น';

  @override
  String get cliBrowseWorkingDir => 'เรียกดู';

  @override
  String get cliSelectCurrentDir => 'เลือกไดเรกทอรีนี้';

  @override
  String get cliNavigateUp => 'ขึ้นไป';

  @override
  String get chatSessionsTooltip => 'เซสชัน';

  @override
  String get hardwareSpecsTitle => 'ฮาร์ดแวร์และระบบ';

  @override
  String get hardwareCpu => 'CPU';

  @override
  String get hardwareMemory => 'หน่วยความจำ';

  @override
  String get hardwareDisk => 'ดิสก์รูท';

  @override
  String get hardwareDistribution => 'ระบบปฏิบัติการ';

  @override
  String get hardwareKernel => 'เคอร์เนล';

  @override
  String get hardwareLoading => 'กำลังโหลดสเปกฮาร์ดแวร์...';

  @override
  String get hardwareUnavailable => 'สเปกฮาร์ดแวร์ไม่พร้อมใช้งาน';

  @override
  String get hardwareUnknown => 'ไม่ทราบ';

  @override
  String get systemInfoTitle => 'ข้อมูลระบบ';

  @override
  String get systemInfoTapHint => 'แตะเพื่อดูภาพ ASCII';

  @override
  String get systemInfoHost => 'โฮสต์';

  @override
  String get serverShutdown => 'ปิดเครื่อง';

  @override
  String get serverShutdownDialogTitle => 'ยืนยันการปิดเซิร์ฟเวอร์';

  @override
  String get serverShutdownDialogMessage =>
      'คุณแน่ใจหรือไม่ว่าต้องการปิดเซิร์ฟเวอร์นี้? ระบบจะปิดโดยสมบูรณ์และไม่สามารถเข้าถึงได้จากระยะไกลจนกว่าจะเปิดด้วยตนเอง';

  @override
  String get serverShutdownConfirmButton => 'ปิดเครื่องทันที';

  @override
  String get serverShutdownSubmitting => 'กำลังส่งคำสั่งปิดเครื่อง...';

  @override
  String get serverShutdownAccepted =>
      'ยอมรับคำสั่งปิดเครื่องแล้ว การปิดเครื่องยังไม่ได้รับการยืนยัน';

  @override
  String get serverShutdownUnknown =>
      'ไม่ทราบผลการปิดเครื่อง: คำสั่งอาจถูกส่งไปแล้วแต่ไม่สามารถยืนยันได้ โปรดตรวจสอบด้วยตนเอง จะไม่มีการลองใหม่โดยอัตโนมัติ';

  @override
  String get serverShutdownPasswordTitle =>
      'จำเป็นต้องใช้รหัสผ่าน Sudo สำหรับการปิดเครื่อง';

  @override
  String get serverShutdownPasswordMessage =>
      'จำเป็นต้องมีสิทธิ์รูทเพื่อปิดเซิร์ฟเวอร์ โปรดป้อนรหัสผ่าน sudo (ใช้ครั้งเดียว ไม่มีการบันทึก):';

  @override
  String get serverShutdownPasswordHint => 'รหัสผ่าน Sudo';

  @override
  String get serverShutdownServerChanged =>
      'เซิร์ฟเวอร์เป้าหมายเปลี่ยนไป ยกเลิกการปิดเครื่องแล้ว';

  @override
  String get metricsNetwork => 'อัตราเครือข่าย';

  @override
  String get networkModalTitle => 'รายละเอียดอินเทอร์เฟซเครือข่าย';

  @override
  String get networkDownloadRate => 'ดาวน์โหลด (RX)';

  @override
  String get networkUploadRate => 'อัปโหลด (TX)';

  @override
  String get networkTotalRx => 'RX รวม';

  @override
  String get networkTotalTx => 'TX รวม';

  @override
  String get networkPrimary => 'เส้นทางเริ่มต้น';

  @override
  String get networkRatesEmpty => 'ตรวจไม่พบอินเทอร์เฟซเครือข่ายที่ใช้งานอยู่';

  @override
  String get networkWaitingSecondSample => 'กำลังรอตัวอย่างที่สอง';

  @override
  String get networkUnavailable => 'ไม่พร้อมใช้งาน';

  @override
  String get networkNoDefaultInterface => 'ไม่มีเส้นทางเริ่มต้น';

  @override
  String get selectThemeModeTitle => 'เลือกโหมดธีม';

  @override
  String get selectLanguageTitle => 'เลือกภาษา';

  @override
  String get selectStartupPageTitle => 'เลือกหน้าเริ่มต้น';

  @override
  String get selectAutoConnectModeTitle => 'เลือกโหมดเชื่อมต่ออัตโนมัติ';

  @override
  String get accentColorDialogTitle => 'ปรับแต่งสีเน้น';

  @override
  String get accentColorLightMode => 'โหมดสว่าง';

  @override
  String get accentColorDarkMode => 'โหมดมืด';

  @override
  String get accentColorAmoledMode => 'AMOLED (Geek)';

  @override
  String get accentColorPresets => 'ค่าที่ตั้งไว้ล่วงหน้า';

  @override
  String get accentColorHsvPicker => 'วงล้อสี';

  @override
  String get accentColorHexCode => 'รหัสสี Hex';

  @override
  String get accentColorPreview => 'ดูตัวอย่าง';

  @override
  String get accentColorSampleButton => 'ปุ่มตัวอย่างเน้น';

  @override
  String get accentColorInvalidHex => 'รูปแบบ hex ไม่ถูกต้อง (เช่น #10B981)';

  @override
  String get settingsDashboardQuickActions => 'การดำเนินการด่วนบนแดชบอร์ด';

  @override
  String get settingsDashboardQuickActionsDesc =>
      'กำหนดค่ารายการทางลัดด่วนที่แสดงบนแดชบอร์ด การล้างจะซ่อนส่วนการดำเนินการด่วน';

  @override
  String get settingsDashboardQuickActionsEmpty =>
      'การดำเนินการด่วนถูกซ่อนอยู่ (ไม่ได้เลือกทางลัด)';

  @override
  String get settingsDashboardQuickActionsOrderTitle =>
      'ลากเพื่อจัดลำดับทางลัดใหม่';

  @override
  String get settingsDashboardQuickActionsCandidates =>
      'เลือกทางลัดที่มองเห็นได้';

  @override
  String get terminalCopySelection => 'คัดลอก';

  @override
  String get terminalSelectionCopied => 'คัดลอกส่วนที่เลือกไปยังคลิปบอร์ดแล้ว';

  @override
  String get editAgent => 'แก้ไข Agent';

  @override
  String get agentExecutionTarget => 'สภาพแวดล้อมการดำเนินการ';

  @override
  String get agentExecutionHost => 'ระบบโฮสต์';

  @override
  String get agentExecutionDocker => 'คอนเทนเนอร์ Docker';

  @override
  String get agentContainerBinding => 'โหมดการผูกคอนเทนเนอร์';

  @override
  String get agentContainerBindingId => 'ตาม ID คอนเทนเนอร์';

  @override
  String get agentContainerBindingName => 'ตามชื่อคอนเทนเนอร์';

  @override
  String get agentContainerReference => 'คอนเทนเนอร์เป้าหมาย';

  @override
  String get agentContainerReferenceHint =>
      'เลือกหรือป้อน ID หรือชื่อคอนเทนเนอร์';

  @override
  String get agentContainerRequired =>
      'จำเป็นต้องระบุคอนเทนเนอร์เป้าหมายสำหรับการดำเนินการ Docker';

  @override
  String get agentLoadingContainers => 'กำลังค้นหาคอนเทนเนอร์บนเซิร์ฟเวอร์...';

  @override
  String get agentNoContainersFound => 'ไม่พบคอนเทนเนอร์บนเซิร์ฟเวอร์นี้';

  @override
  String get agentContainerUser => 'ผู้ใช้การดำเนินการคอนเทนเนอร์ (ไม่บังคับ)';

  @override
  String get agentContainerUserHint => 'เช่น dev';

  @override
  String get agentContainerUserHelper =>
      'เว้นว่างไว้เพื่อใช้ผู้ใช้เริ่มต้นของอิมเมจ; เช่น dev; รองรับ user, UID, user:group, UID:GID';

  @override
  String get agentContainerUserSelect => 'เลือกผู้ใช้คอนเทนเนอร์';

  @override
  String get agentContainerUsersLoading => 'กำลังโหลดผู้ใช้...';

  @override
  String get agentContainerUsersEmpty => 'ไม่พบผู้ใช้ใน passwd';

  @override
  String get agentViewDiagnosticLog => 'ดูบันทึกการวินิจฉัย';

  @override
  String get agentDiagnosticLogCopied =>
      'คัดลอกบันทึกการวินิจฉัยไปยังคลิปบอร์ดแล้ว';

  @override
  String get agentDiagnosticLogCopy => 'คัดลอก';

  @override
  String get agentDiagnosticLogClose => 'ปิด';

  @override
  String get settingsCliHistoryPageSize => 'ขนาดหน้าประวัติ CLI';

  @override
  String get settingsCliHistoryPageSizeDesc =>
      'จำนวนข้อความเก่าที่โหลดต่อหน้าเมื่อเลื่อนขึ้น (5-100)';

  @override
  String get settingsCliHistoryPageSizeTitle => 'เลือกขนาดหน้าประวัติ CLI';

  @override
  String get cliLoadingOlderMessages => 'กำลังโหลดข้อความเก่า...';

  @override
  String get chatLoadOlderMessages => 'โหลดข้อความก่อนหน้า';

  @override
  String get chatCommandsTooltip => 'คำสั่ง';

  @override
  String get chatAttachTooltip => 'แนบไฟล์';

  @override
  String get chatAttachImage => 'แนบรูปภาพในเครื่อง';

  @override
  String get chatAttachLocalText => 'แนบไฟล์ข้อความในเครื่อง';

  @override
  String get chatAttachRemoteText => 'แนบไฟล์ข้อความระยะไกล';

  @override
  String get chatAttachRemotePathTitle => 'แนบไฟล์ข้อความระยะไกล';

  @override
  String get chatAttachRemotePathHint => '/path/to/file.txt';

  @override
  String get chatAttachTooLarge => 'ไฟล์มีขนาดเกินขีดจำกัด';

  @override
  String get chatUsageAndDiagnostics => 'การใช้งานและการวินิจฉัย';

  @override
  String get chatWorkingDirTooltip => 'ไดเรกทอรีทำงานของฉบับร่าง';

  @override
  String get chatAttachFailed => 'แนบไฟล์ไม่สำเร็จ';

  @override
  String get chatInvalidRemotePath =>
      'เส้นทางไฟล์ระยะไกลไม่ถูกต้อง (ต้องขึ้นต้นด้วย /)';

  @override
  String get chatRemoteReadFailed => 'อ่านไฟล์ระยะไกลไม่สำเร็จ';

  @override
  String get chatInvalidDirPath =>
      'เส้นทางไดเรกทอรีไม่ถูกต้อง (ต้องขึ้นต้นด้วย /)';

  @override
  String get chatNoSubdirectories => 'ไม่มีไดเรกทอรีย่อย';

  @override
  String get chatUsageTitle => 'การใช้โทเค็นและค่าใช้จ่าย';

  @override
  String get chatUsageUsed => 'โทเค็นที่ใช้';

  @override
  String get chatUsageSize => 'ขนาดบริบท';

  @override
  String get chatUsageCost => 'ค่าใช้จ่าย';

  @override
  String get chatDiagnosticsTitle => 'บันทึกการวินิจฉัย';

  @override
  String get chatNoDiagnostics => 'ไม่มีบันทึกการวินิจฉัย';

  @override
  String get deleteSessionLocalOnlyNotice =>
      'การดำเนินการนี้จะลบเฉพาะบันทึกในเครื่องใน Valhalla เท่านั้น และจะไม่ลบประวัติเซสชันของ Agent ดั้งเดิมบนเซิร์ฟเวอร์';

  @override
  String get chatSearchSessionsHint => 'ค้นหาเซสชัน...';

  @override
  String get chatLoadMoreSessions => 'โหลดเซสชันเพิ่มเติม';

  @override
  String get chatLoadingMoreSessions => 'กำลังโหลดเซสชันเพิ่มเติม...';

  @override
  String get chatExportSession => 'ส่งออกเซสชัน (Markdown)';

  @override
  String get chatExportSuccess => 'ส่งออกเซสชันสำเร็จ';

  @override
  String get chatExportFailed => 'ส่งออกเซสชันไม่สำเร็จ';

  @override
  String get chatRemoteSessions => 'เซสชันระยะไกล';

  @override
  String get chatRemoteSessionsTitle => 'เซสชัน Agent ระยะไกล';

  @override
  String get chatRemoteSessionsDesc =>
      'ดูและนำเข้าประวัติเซสชันดั้งเดิมจาก Agent ระยะไกล';

  @override
  String get chatRemoteSessionsEmpty => 'ไม่พบเซสชันระยะไกล';

  @override
  String get chatRemoteImporting => 'กำลังนำเข้าประวัติเซสชันระยะไกล...';

  @override
  String get chatRemoteImportFailed => 'นำเข้าเซสชันระยะไกลไม่สำเร็จ';

  @override
  String get chatStatusInterrupted => 'ถูกขัดจังหวะ';

  @override
  String get chatStatusFailed => 'ล้มเหลว';

  @override
  String get chatStatusAwaitingAuth => 'กำลังรอการตรวจสอบสิทธิ์ ACP';

  @override
  String get chatShowFullOutput => 'แสดงผลลัพธ์แบบเต็ม';

  @override
  String get chatShowLessOutput => 'แสดงน้อยลง';

  @override
  String get chatToolLocations => 'เส้นทางที่ได้รับผลกระทบ';

  @override
  String cmdParamPlaceholder(String param) {
    return 'ป้อนค่าสำหรับ $param';
  }

  @override
  String processTerminateSuccess(Object pid) {
    return 'กระบวนการ $pid ถูกยุติแล้ว';
  }

  @override
  String serviceActionSuccess(Object action, Object service) {
    return 'การดำเนินการ $action บน $service สำเร็จ';
  }

  @override
  String riskPatternMatched(Object pattern) {
    return 'กฎที่ถูกทริกเกอร์: $pattern';
  }

  @override
  String stateExitCode(Object code) {
    return 'รหัสออก: $code';
  }

  @override
  String sshConnectedSuccess(Object server) {
    return 'เชื่อมต่อกับ $server ผ่าน SSH สำเร็จ';
  }

  @override
  String sshConnectionFailed(Object error) {
    return 'การเชื่อมต่อ SSH ล้มเหลว: $error';
  }

  @override
  String trustHostFingerprintMessage(
    Object fingerprint,
    Object host,
    Object type,
  ) {
    return 'กำลังเชื่อมต่อกับ $host ($type) เป็นครั้งแรก\n\nลายนิ้วมือ SHA-256:\n$fingerprint\n\nเชื่อถือลายนิ้วมือนี้และเชื่อมต่อหรือไม่?';
  }

  @override
  String enterPasswordTitle(Object server) {
    return 'ป้อนรหัสผ่านสำหรับ $server';
  }

  @override
  String confirmDeleteServerMessage(Object name) {
    return 'คุณแน่ใจหรือไม่ว่าต้องการลบเซิร์ฟเวอร์ \'$name\'? การดำเนินการนี้ไม่สามารถย้อนกลับได้';
  }

  @override
  String deleteAgentMessage(Object name) {
    return 'คุณแน่ใจหรือไม่ว่าต้องการลบ Agent \'$name\'? การดำเนินการนี้จะลบการกำหนดค่าและสถานะรันไทม์บนเซิร์ฟเวอร์นี้โดยไม่กระทบต่อประวัติเซสชันแชทหรือข้อมูลรับรอง SSH';
  }

  @override
  String agentLastChecked(Object time) {
    return 'ตรวจสอบล่าสุด: $time';
  }

  @override
  String agentAuthPickerTitle(Object agent) {
    return 'เลือกวิธีเข้าสู่ระบบ $agent';
  }

  @override
  String sshStatusReconnecting(Object n) {
    return 'กำลังเชื่อมต่อใหม่… (ครั้งที่ $n)';
  }

  @override
  String sshKeepAliveNotificationBody(Object n) {
    return '$n เซสชันที่ใช้งานอยู่';
  }

  @override
  String bindServerConfirmMessage(Object serverName) {
    return 'ผูกเซสชันนี้กับเซิร์ฟเวอร์ \"$serverName\" หรือไม่? เมื่อผูกแล้ว เซสชันนี้จะเชื่อมโยงกับเซิร์ฟเวอร์นี้';
  }

  @override
  String deleteSessionConfirmMessage(Object title) {
    return 'คุณแน่ใจหรือไม่ว่าต้องการลบเซสชัน \"$title\"? การดำเนินการนี้ไม่สามารถย้อนกลับได้';
  }

  @override
  String dockerActionSuccess(Object action, Object name) {
    return 'การดำเนินการ $action บนคอนเทนเนอร์ $name สำเร็จ';
  }

  @override
  String dockerActionFailed(Object error) {
    return 'การดำเนินการล้มเหลว: $error';
  }

  @override
  String serverRebootTarget(Object address, Object name) {
    return 'เซิร์ฟเวอร์เป้าหมาย: $name ($address)';
  }

  @override
  String serverRebootRunningTerminals(Object count) {
    return 'เซสชันเทอร์มินัล: $count';
  }

  @override
  String serverRebootRunningAgents(Object count) {
    return 'เซสชัน Agent: $count';
  }

  @override
  String serverRebootRunningTransfers(Object count) {
    return 'การถ่ายโอนที่ใช้งานอยู่: $count';
  }

  @override
  String serverRebootFailed(Object error) {
    return 'การรีบูตล้มเหลว: $error';
  }

  @override
  String cliDeleteFailedWithDetail(Object detail) {
    return 'ลบเซสชันระยะไกลไม่สำเร็จ: $detail';
  }

  @override
  String metricsTrendTitle(Object metric) {
    return 'แนวโน้ม $metric';
  }

  @override
  String metricsThresholdWarning(Object value) {
    return 'คำเตือน: $value';
  }

  @override
  String metricsThresholdDanger(Object value) {
    return 'อันตราย: $value';
  }

  @override
  String metricsHistoryPoints(Object count) {
    return '$count จุดข้อมูล';
  }

  @override
  String resourceUsageTitle(Object metric) {
    return 'การใช้ทรัพยากร $metric';
  }

  @override
  String serverPortReachable(Object port) {
    return 'พอร์ต TCP $port สามารถเข้าถึงได้';
  }

  @override
  String serverConnectionFailed(Object error) {
    return 'การเชื่อมต่อล้มเหลว: $error';
  }

  @override
  String serverSaveFailed(Object error) {
    return 'บันทึกเซิร์ฟเวอร์ไม่สำเร็จ: $error';
  }

  @override
  String hardwareCpuCores(Object cores) {
    return '$cores คอร์';
  }

  @override
  String serverShutdownFailed(Object error) {
    return 'การปิดระบบล้มเหลว: $error';
  }

  @override
  String networkInterface(Object name) {
    return 'อินเทอร์เฟซ: $name';
  }

  @override
  String agentContainersLoadFailed(Object error) {
    return 'โหลดคอนเทนเนอร์ไม่สำเร็จ: $error';
  }

  @override
  String agentContainerUsersFailed(Object error) {
    return 'โหลดผู้ใช้คอนเทนเนอร์ไม่สำเร็จ: $error';
  }

  @override
  String agentDiagnosticLogTitle(Object name) {
    return 'บันทึกการวินิจฉัย - $name';
  }

  @override
  String get agentDockerDetectionFailed =>
      'การตรวจหา Docker/คอนเทนเนอร์ล้มเหลว';

  @override
  String get chatCopiedAllMessages => 'คัดลอกข้อความทั้งหมดแล้ว';

  @override
  String get chatCopyAllMessages => 'คัดลอกข้อความทั้งหมด';

  @override
  String get cliModelAtCapacity =>
      'โมเดลที่เลือกมีความจุเต็ม โปรดลองใช้โมเดลอื่น';

  @override
  String get chatLaunchBlankDraft => 'ฉบับร่างเปล่า';

  @override
  String get chatLaunchFixedSession => 'เซสชันคงที่';

  @override
  String get chatLaunchRememberLast => 'จดจำเซสชันล่าสุด';

  @override
  String get chatPermissionAskEveryTime => 'ถามทุกครั้ง';

  @override
  String get chatPermissionAutoAllowAll => 'อนุญาตทั้งหมดโดยอัตโนมัติ';

  @override
  String get chatPermissionAutoAllowAllConfirmMessage =>
      'Agent จะดำเนินการทั้งหมดโดยไม่ต้องถาม ดำเนินการต่อหรือไม่?';

  @override
  String get chatPermissionAutoAllowAllConfirmTitle =>
      'อนุญาตการดำเนินการทั้งหมดหรือไม่?';

  @override
  String get chatPermissionAutoAllowSafe =>
      'อนุญาตการดำเนินการที่ปลอดภัยโดยอัตโนมัติ';

  @override
  String get chatRunSettingsDefault => 'ค่าเริ่มต้น';

  @override
  String get chatRunSettingsInteractiveCli => 'CLI แบบโต้ตอบ';

  @override
  String get chatRunSettingsModel => 'โมเดล';

  @override
  String get chatRunSettingsPermissions => 'สิทธิ์';

  @override
  String get chatRunSettingsReasoning => 'ระดับการให้เหตุผล';

  @override
  String get chatRunSettingsTitle => 'การตั้งค่าการทำงาน';

  @override
  String get cliActionInsertCommand => 'แทรกคำสั่ง';

  @override
  String get cliActionInsertFile => 'แทรกไฟล์';

  @override
  String get cliActionInsertWorkdir => 'แทรกไดเรกทอรีทำงาน';

  @override
  String get cliComposerInsertAction => 'แทรก';

  @override
  String cliOperationFailedWithDetail(String detail) {
    return 'การดำเนินการ CLI ล้มเหลว: $detail';
  }

  @override
  String get cliSelectCommandTitle => 'เลือกคำสั่ง';

  @override
  String get defaultAgentTitle => 'Agent เริ่มต้น';

  @override
  String get insertSkills => 'แทรกทักษะ';

  @override
  String get isDefaultSession => 'เซสชันเริ่มต้น';

  @override
  String get sessionLaunchMode => 'โหมดเปิดเซสชัน';

  @override
  String get setAsDefaultSession => 'ตั้งเป็นเซสชันเริ่มต้น';

  @override
  String get navNas => 'NAS มีเดีย';

  @override
  String get nasAddExcludePath => 'เพิ่มเส้นทางที่ยกเว้น';

  @override
  String get nasAddIncludePath => 'เพิ่มเส้นทางการสแกน';

  @override
  String get nasCancelScan => 'ยกเลิกการสแกน';

  @override
  String get nasClearSearch => 'ล้างการค้นหา';

  @override
  String get nasConfigDialogTitle => 'การตั้งค่าคลังสื่อ';

  @override
  String get nasConfigure => 'กำหนดค่า';

  @override
  String get nasConfigureScanDirs => 'กำหนดค่าโฟลเดอร์สแกน';

  @override
  String get nasCreatePlaylist => 'สร้างเพลย์ลิสต์';

  @override
  String get nasEmptyConfigDesc =>
      'เพิ่มอย่างน้อยหนึ่งโฟลเดอร์เพื่อเริ่มสร้างคลังสื่อของคุณ';

  @override
  String get nasEmptyConfigTitle => 'ไม่ได้กำหนดค่าโฟลเดอร์สแกน';

  @override
  String get nasExcludePaths => 'โฟลเดอร์ที่ยกเว้น';

  @override
  String get nasExcludedBadge => 'ยกเว้นแล้ว';

  @override
  String get nasFilterImages => 'รูปภาพ';

  @override
  String get nasFilterVideos => 'วิดีโอ';

  @override
  String get nasIncludePaths => 'โฟลเดอร์สแกน';

  @override
  String nasItemCount(Object value) {
    return '$value รายการ';
  }

  @override
  String nasLastScan(Object value) {
    return 'สแกนล่าสุด: $value';
  }

  @override
  String get nasLibrarySettings => 'การตั้งค่าคลัง';

  @override
  String nasMediaOpening(Object value) {
    return 'กำลังเปิด $value…';
  }

  @override
  String get nasMiniPlayer => 'มินิเพลเยอร์';

  @override
  String get nasNoExcludePaths => 'ไม่มีโฟลเดอร์ที่ยกเว้น';

  @override
  String get nasNoFavorites => 'ยังไม่มีรายการโปรด';

  @override
  String get nasNoIncludePaths => 'ไม่มีโฟลเดอร์สแกน';

  @override
  String get nasNoIndexDesc =>
      'กำหนดค่าโฟลเดอร์และเรียกใช้การสแกนเพื่อจัดทำดัชนีสื่อของคุณ';

  @override
  String get nasNoIndexTitle => 'คลังสื่อว่างเปล่า';

  @override
  String get nasNoPlaylists => 'ยังไม่มีเพลย์ลิสต์';

  @override
  String get nasNoSearchResults => 'ไม่พบสื่อที่ตรงกัน';

  @override
  String get nasNotScanned => 'ยังไม่ได้สแกน';

  @override
  String get nasNowPlaying => 'กำลังเล่น';

  @override
  String get nasOpenMethodPrompt => 'คุณต้องการเปิดไฟล์นี้อย่างไร?';

  @override
  String get nasOpenPolicyAsk => 'ถามทุกครั้ง';

  @override
  String get nasOpenPolicyExternal => 'เปิดด้วยแอปอื่น';

  @override
  String get nasOpenPolicyInApp => 'เปิดในแอป';

  @override
  String get nasOpeningPolicy => 'วิธีการเปิดเริ่มต้น';

  @override
  String get nasPlaylistName => 'ชื่อเพลย์ลิสต์';

  @override
  String get nasQuickStats => 'ภาพรวมคลัง';

  @override
  String get nasScan => 'สแกนทันที';

  @override
  String get nasScanCancelled => 'ยกเลิกการสแกนแล้ว';

  @override
  String nasScanFailed(Object value) {
    return 'การสแกนล้มเหลว: $value';
  }

  @override
  String get nasScanning => 'กำลังสแกน…';

  @override
  String get nasScopeBadge => 'ขอบเขตการสแกน';

  @override
  String get nasSearchHint => 'ค้นหาสื่อ';

  @override
  String get nasStatMusic => 'เพลง';

  @override
  String get nasStatPhotos => 'รูปภาพ';

  @override
  String get nasStatTotal => 'ทั้งหมด';

  @override
  String get nasStatVideos => 'วิดีโอ';

  @override
  String get nasTabFavorites => 'รายการโปรด';

  @override
  String get nasTabFolders => 'โฟลเดอร์';

  @override
  String get nasTabHome => 'หน้าแรก';

  @override
  String get nasTabMusic => 'เพลง';

  @override
  String get nasTabPhotos => 'รูปภาพ';

  @override
  String get nasTabPlaylists => 'เพลย์ลิสต์';

  @override
  String get nasTabVideos => 'วิดีโอ';

  @override
  String get nasSources => 'แหล่งที่มาของสื่อ';

  @override
  String get nasAddSource => 'เพิ่มแหล่งที่มาของสื่อ';

  @override
  String get nasEditSource => 'แก้ไขแหล่งที่มาของสื่อ';

  @override
  String get nasRemoveSource => 'ลบแหล่งที่มาของสื่อ';

  @override
  String nasRemoveSourceConfirm(Object name) {
    return 'คุณแน่ใจหรือไม่ว่าต้องการลบแหล่งที่มาของสื่อ \'$name\'? การดำเนินการนี้จะลบการกำหนดค่าโดยไม่ลบไฟล์ระยะไกล';
  }

  @override
  String get nasNoSources => 'ยังไม่ได้กำหนดค่าแหล่งที่มาของสื่อ';

  @override
  String get nasNoSourcesDesc =>
      'เพิ่ม SFTP, SMB, WebDAV, Jellyfin หรือ Emby เพื่อเริ่มเรียกดูสื่อ';

  @override
  String get nasSourceType => 'ประเภทแหล่งที่มา';

  @override
  String get nasSourceName => 'ชื่อแหล่งที่มา';

  @override
  String get nasProbe => 'ทดสอบการเชื่อมต่อ';

  @override
  String get nasProbeSuccess => 'เชื่อมต่อสำเร็จ';

  @override
  String get nasProbeFailed => 'การทดสอบการเชื่อมต่อล้มเหลว';

  @override
  String get nasEndpoint => 'ปลายทาง / URL';

  @override
  String get nasRootPath => 'เส้นทางรูท';

  @override
  String get nasUsername => 'ชื่อผู้ใช้';

  @override
  String get nasPassword => 'รหัสผ่าน';

  @override
  String get nasDomain => 'โดเมน (ไม่บังคับ)';

  @override
  String get nasAuthenticate => 'ตรวจสอบสิทธิ์';

  @override
  String get nasAuthSuccess => 'ตรวจสอบสิทธิ์สำเร็จ';

  @override
  String get nasAuthFailed => 'การตรวจสอบสิทธิ์ล้มเหลว';

  @override
  String get nasTabDownloads => 'การดาวน์โหลด';

  @override
  String get nasNoDownloads => 'ไม่มีงานดาวน์โหลด';

  @override
  String get nasDownloadQueued => 'อยู่ในคิว';

  @override
  String get nasDownloadDownloading => 'กำลังดาวน์โหลด';

  @override
  String get nasDownloadCompleted => 'เสร็จสิ้น';

  @override
  String get nasDownloadCancelled => 'ยกเลิกแล้ว';

  @override
  String get nasDownloadFailed => 'ดาวน์โหลดล้มเหลว';

  @override
  String get nasRetryDownload => 'ลองใหม่';

  @override
  String get nasCancelDownload => 'ยกเลิก';

  @override
  String get nasOpenDownloadedFile => 'เปิดไฟล์';

  @override
  String get nasQueue => 'คิวการเล่น';

  @override
  String get nasNoQueue => 'คิวว่างเปล่า';

  @override
  String get nasSpeed => 'ความเร็ว';

  @override
  String get nasQuality => 'คุณภาพ';

  @override
  String get nasAudioTrack => 'แทร็กเสียง';

  @override
  String get nasSubtitleTrack => 'คำบรรยาย';

  @override
  String get nasRepeatOff => 'ปิดการเล่นซ้ำ';

  @override
  String get nasRepeatAll => 'เล่นซ้ำทั้งหมด';

  @override
  String get nasRepeatOne => 'เล่นซ้ำเพลงเดียว';

  @override
  String get nasShuffle => 'สุ่ม';

  @override
  String get nasCast => 'แคสต์ (Cast)';

  @override
  String get nasCastUnavailable => 'ไม่มีอุปกรณ์แคสต์ที่พร้อมใช้งาน';

  @override
  String get nasSlideshow => 'สไลด์โชว์';

  @override
  String get nasByFolder => 'โฟลเดอร์';

  @override
  String get nasByArtist => 'ศิลปิน';

  @override
  String get nasByAlbum => 'อัลบั้ม';

  @override
  String get nasAllTracks => 'แทร็กทั้งหมด';

  @override
  String get nasPlayAll => 'เล่นทั้งหมด';

  @override
  String get nasPreviousPage => 'ก่อนหน้า';

  @override
  String get nasNextPage => 'ถัดไป';

  @override
  String get nasClearScope => 'กลับไปยังทั้งหมด';

  @override
  String get nasRenamePlaylist => 'เปลี่ยนชื่อเพลย์ลิสต์';

  @override
  String get nasRemoveFromPlaylist => 'ลบออกจากเพลย์ลิสต์';

  @override
  String get nasMoveUp => 'เลื่อนขึ้น';

  @override
  String get nasMoveDown => 'เลื่อนลง';

  @override
  String get nasSshServer => 'เซิร์ฟเวอร์ SSH';

  @override
  String get nasSelectSshServer => 'เลือกเซิร์ฟเวอร์ SSH ที่บันทึกไว้';

  @override
  String get nasQualityOriginal => 'ต้นฉบับ';

  @override
  String get nasQualityAuto => 'อัตโนมัติ';

  @override
  String get nasQuality4Mbps => '4 Mbps';

  @override
  String get nasQuality10Mbps => '10 Mbps';

  @override
  String get nasQuality20Mbps => '20 Mbps';

  @override
  String get nasCastDevices => 'อุปกรณ์ DLNA ที่พร้อมใช้งาน';

  @override
  String get nasCastDiscovering => 'กำลังค้นหาอุปกรณ์ DLNA...';

  @override
  String get nasCastRelayingNotice =>
      'กำลังส่งต่อสตรีมผ่านแอปเบื้องหน้า เปิด Valhalla ไว้';

  @override
  String get nasCastStop => 'หยุดแคสต์';

  @override
  String get nasCastVolume => 'ระดับเสียง';

  @override
  String get nasCastRetry => 'ลองค้นหาใหม่';

  @override
  String get nasInstallTitle => 'ปรับใช้เซิร์ฟเวอร์สื่อ NAS';

  @override
  String get nasInstallProduct => 'ผลิตภัณฑ์';

  @override
  String get nasInstallMediaPath => 'ไดเรกทอรีสื่อ (อ่านอย่างเดียว)';

  @override
  String get nasInstallDataRoot => 'ไดเรกทอรีข้อมูลและการกำหนดค่า';

  @override
  String get nasInstallPort => 'พอร์ต';

  @override
  String get nasInstallBindAddress => 'ที่อยู่ผูกมัด';

  @override
  String get nasInstallWebdavUser => 'ชื่อผู้ใช้ WebDAV';

  @override
  String get nasInstallWebdavPassword =>
      'รหัสผ่าน WebDAV (ขั้นต่ำ 12 ตัวอักษร)';

  @override
  String get nasInstallPreparePlan => 'ตรวจสอบแผนการปรับใช้';

  @override
  String get nasInstallPlanTitle => 'การตรวจสอบทางเทคนิคและการยืนยัน';

  @override
  String get nasInstallBlockersTitle => 'อุปสรรคในการปรับใช้';

  @override
  String get nasInstallConfirmDeploy => 'ยืนยันและติดตั้ง';

  @override
  String get nasInstallDeploying => 'กำลังปรับใช้คอนเทนเนอร์...';

  @override
  String get nasInstallSuccess => 'ปรับใช้สำเร็จ';

  @override
  String get nasInstallSuccessDesc =>
      'บริการกำลังทำงานอยู่ ทำการตั้งค่าเริ่มต้นของเซิร์ฟเวอร์ให้เสร็จสิ้นก่อนเพิ่มเป็นแหล่งที่มาของสื่อ';

  @override
  String get nasInstallContainerId => 'ID คอนเทนเนอร์';

  @override
  String get nasInstallEndpoint => 'ปลายทาง';

  @override
  String get nasUseSshTunnel => 'ใช้ทันเนล SSH';

  @override
  String get nasUseSshTunnelDesc =>
      'กำหนดเส้นทางทราฟฟิกผ่านเซิร์ฟเวอร์ SSH ที่บันทึกไว้ (เช่น http://127.0.0.1:8096)';

  @override
  String get nasSshTunnelHint =>
      'ปลายทางควรเข้าถึงได้จากเซิร์ฟเวอร์ SSH เช่น http://127.0.0.1:8096';

  @override
  String get nasKeepEmptyPassword =>
      'เว้นว่างไว้เพื่อคงรหัสผ่าน / โทเค็นที่มีอยู่';

  @override
  String get nasSourceNameRequired => 'จำเป็นต้องระบุชื่อแหล่งที่มา';

  @override
  String get nasInvalidEndpoint => 'URL หรือรูปแบบปลายทางไม่ถูกต้อง';

  @override
  String get nasSourceUnreachable => 'ไม่สามารถเข้าถึงแหล่งที่มาของสื่อได้';

  @override
  String get nasSshTunnelFailed => 'การเชื่อมต่อทันเนล SSH ล้มเหลว';

  @override
  String get nasOperationFailed => 'การดำเนินการล้มเหลว';

  @override
  String get nasInstallStepCreateDir => 'สร้างไดเรกทอรีส่วนตัว';

  @override
  String get nasInstallStepWriteCompose =>
      'เขียนการกำหนดค่า docker-compose.json';

  @override
  String get nasInstallStepWriteCreds => 'เขียนข้อมูลประจำตัวส่วนตัว';

  @override
  String get nasInstallStepPullImage => 'ดึงอิมเมจคอนเทนเนอร์ที่ตรึงไว้';

  @override
  String get nasInstallStepStartService => 'เริ่มบริการคอนเทนเนอร์';

  @override
  String get nasInstallStepCheckHttp => 'ตรวจสอบสถานะ HTTP ของบริการ';

  @override
  String get nasInstallBlockerDocker =>
      'จำเป็นต้องมี Docker Engine บนเซิร์ฟเวอร์เป้าหมาย';

  @override
  String get nasInstallBlockerCompose => 'จำเป็นต้องมีปลั๊กอิน Docker Compose';

  @override
  String get nasInstallBlockerIdentity =>
      'ไม่สามารถตรวจสอบข้อมูลประจำตัวของเซิร์ฟเวอร์เป้าหมายได้';

  @override
  String get nasInstallBlockerTools =>
      'เครื่องมือที่จำเป็น (curl, ss, realpath) ขาดหายไปบนเซิร์ฟเวอร์เป้าหมาย';

  @override
  String get nasInstallBlockerMedia => 'ไม่มีไดเรกทอรีสื่อหรือไม่สามารถอ่านได้';

  @override
  String get nasInstallBlockerParent =>
      'ไดเรกทอรีหลักของรูทข้อมูลไม่สามารถเขียนได้';

  @override
  String get nasInstallBlockerOverlap =>
      'ไดเรกทอรีสื่อและไดเรกทอรีข้อมูลไม่สามารถซ้อนทับกันได้';

  @override
  String get nasInstallBlockerCollision =>
      'ไดเรกทอรีข้อมูลเป้าหมายมีอยู่แล้วหรือเป็นลิงก์สัญลักษณ์';

  @override
  String get nasInstallBlockerPort =>
      'พอร์ตที่เลือกกำลังถูกใช้งานบนเซิร์ฟเวอร์เป้าหมายแล้ว';

  @override
  String get nasInstallBlockerContainer =>
      'มีคอนเทนเนอร์ที่มีชื่อโครงการนี้อยู่แล้ว';

  @override
  String get nasInstallBlockerImage =>
      'การตรวจสอบอิมเมจคอนเทนเนอร์ล้มเหลว ตรวจสอบชื่ออิมเมจ การเชื่อมต่อเครือข่าย และสถาปัตยกรรมเซิร์ฟเวอร์ แล้วลองใหม่อีกครั้ง';

  @override
  String get nasInstallGuidanceTunnel =>
      'การผูกย้อนกลับ (127.0.0.1) ต้องใช้ทันเนล SSH สำหรับการเข้าถึงระยะไกล';

  @override
  String get nasInstallGuidanceTls =>
      'แนะนำให้รักษาความปลอดภัยการผูกสาธารณะไว้ด้านหลัง TLS reverse proxy';

  @override
  String get nasInstallGuidanceSetup =>
      'ทำการตั้งค่าบัญชีผู้ดูแลระบบเริ่มต้นในเบราว์เซอร์เมื่อเปิดใช้งานครั้งแรก';

  @override
  String get nasInstallGuidanceReadOnly =>
      'ไดเรกทอรีสื่อถูกต่อเชื่อมแบบอ่านอย่างเดียวเพื่อปกป้องไฟล์ของคุณ';

  @override
  String get nasInstallGuidancePreserved =>
      'ไดเรกทอรีข้อมูลจะถูกเก็บไว้เมื่อเกิดข้อผิดพลาดเพื่อการแก้ไขปัญหา';

  @override
  String get nasDownloadCompletedWithOpenError =>
      'ดาวน์โหลดแล้ว (เปิดด้วยแอปภายนอกไม่สำเร็จ)';

  @override
  String get nasRetryOpen => 'ลองเปิดใหม่';

  @override
  String get nasExternalOpenFailed => 'เปิดไฟล์ในแอปภายนอกไม่สำเร็จ';

  @override
  String get nasTitle => 'NAS มีเดีย';

  @override
  String get nasLoadMoreGroups => 'โหลดกลุ่มเพิ่มเติม';

  @override
  String get nasMetadataEnriching => 'กำลังปรับปรุงแท็กเพลง...';

  @override
  String nasMetadataEnrichingWithCount(int count) {
    return 'กำลังปรับปรุงแท็กเพลง (ประมวลผลแล้ว $count)...';
  }

  @override
  String nasDownloading(String value) {
    return 'กำลังดาวน์โหลด $value…';
  }

  @override
  String get nasSubtitleNone => 'ไม่มี';

  @override
  String get nasLibraryId => 'ID คลัง';

  @override
  String get nasLibraryIdHint => 'ค่าเริ่มต้น: ทั้งหมด (/) หรือระบุ ID คลัง';

  @override
  String nasScanPathRelativeHint(String value) {
    return 'สัมพันธ์กับรูทแหล่งที่มา ($value)';
  }

  @override
  String get nasSourceChangedError =>
      'แหล่งที่มาเปลี่ยนไปขณะกำหนดค่า ยกเลิกการบันทึกแล้ว';

  @override
  String get nasInvalidLibraryId => 'ID คลังไม่ถูกต้อง';

  @override
  String get startupFailed => 'แอปพลิเคชันเริ่มทำงานไม่สำเร็จ';

  @override
  String get startupFailedDesc =>
      'เกิดข้อผิดพลาดที่ไม่คาดคิดระหว่างการเริ่มต้น คุณสามารถลองใหม่หรือส่งออกบันทึกการวินิจฉัย';

  @override
  String get retryStartup => 'ลองเริ่มใหม่';

  @override
  String get viewDiagnostics => 'ดูการวินิจฉัย';

  @override
  String get exportDiagnostics => 'ส่งออกการวินิจฉัย';

  @override
  String diagnosticsExportSuccess(String path) {
    return 'ส่งออกการวินิจฉัยไปยัง $path แล้ว';
  }

  @override
  String get diagnosticsExportFailed => 'ส่งออกการวินิจฉัยไม่สำเร็จ';

  @override
  String get diagnosticsTitle => 'การวินิจฉัยแอป';

  @override
  String get settingsDiagnostics => 'การวินิจฉัยและบันทึก';

  @override
  String get settingsDiagnosticsDesc =>
      'ดูและส่งออกบันทึกแอปพลิเคชันภายในเครื่องที่ผ่านการล้างข้อมูลแล้ว';

  @override
  String get diagnosticsEmpty => 'ไม่พบบันทึกการวินิจฉัย';

  @override
  String diagnosticsStorageError(String error) {
    return 'ข้อผิดพลาดในการจัดเก็บบันทึกการวินิจฉัย: $error';
  }

  @override
  String diagnosticsIncidentNotice(String category) {
    return 'มีรายงานเหตุการณ์ที่กู้คืนได้: $category';
  }

  @override
  String get diagnosticsRefresh => 'รีเฟรชบันทึก';

  @override
  String get nasInstallTaskTitle => 'งานการปรับใช้';

  @override
  String get nasInstallStagePreflight => 'การตรวจสอบเบื้องต้น';

  @override
  String get nasInstallStageReview => 'ตรวจสอบแผน';

  @override
  String get nasInstallStageWriting => 'กำลังเขียนการกำหนดค่า';

  @override
  String get nasInstallStagePulling => 'กำลังดึงอิมเมจ';

  @override
  String get nasInstallStageStarting => 'กำลังเริ่มคอนเทนเนอร์';

  @override
  String get nasInstallStageHealth => 'การตรวจสอบสถานะสุขภาพ';

  @override
  String get nasInstallStageCleanup => 'กำลังล้างข้อมูล';

  @override
  String get nasInstallStageSucceeded => 'ปรับใช้สำเร็จ';

  @override
  String get nasInstallStageFailed => 'ปรับใช้ล้มเหลว';

  @override
  String get nasInstallStageCancelled => 'ยกเลิกการปรับใช้แล้ว';

  @override
  String get nasInstallStageNeedsInspection => 'ต้องมีการตรวจสอบ';

  @override
  String get nasInstallStageReconciling => 'กำลังปรับสถานะให้สอดคล้องกัน';

  @override
  String get nasInstallCancel => 'ยกเลิกการปรับใช้';

  @override
  String get nasInstallReconcile => 'ปรับสถานะให้สอดคล้องกัน';

  @override
  String get nasInstallServerNotFound => 'ไม่พบเซิร์ฟเวอร์ที่เลือก';

  @override
  String get nasInstallPortRangeError => 'พอร์ตต้องอยู่ระหว่าง 1 ถึง 65535';

  @override
  String nasInstallElapsedTime(String time) {
    return 'เวลาที่ผ่านไป: $time';
  }

  @override
  String get nasInstallLogTail => 'บันทึกล่าสุด';

  @override
  String get nasInstallCleanupCompleted => 'การล้างข้อมูลย้อนกลับเสร็จสมบูรณ์';

  @override
  String get nasInstallCleanupIncomplete => 'การล้างข้อมูลย้อนกลับไม่สมบูรณ์';

  @override
  String get nasInstallNewDeployment => 'การปรับใช้ใหม่';

  @override
  String get nasInstallBackEdit => 'ย้อนกลับ / แก้ไขแบบฟอร์ม';

  @override
  String get nasInstallClose => 'ปิด';

  @override
  String get nasInstallMediaPathHint =>
      'จุดต่อเชื่อมแบบผูกอ่านอย่างเดียวบนโฮสต์ (เช่น /mnt/media)';

  @override
  String get nasInstallDataRootHint =>
      'ไดเรกทอรีข้อมูลและการกำหนดค่าส่วนตัว (ต้องยังไม่มีอยู่)';

  @override
  String get nasInstallBindAddressHint =>
      '127.0.0.1 สำหรับทันเนล, 0.0.0.0 สำหรับ LAN';

  @override
  String get nasInstallWebdavPasswordHint => 'ต้องมีอย่างน้อย 12 ตัวอักษร';

  @override
  String get nasInstallTargetServer => 'เซิร์ฟเวอร์เป้าหมาย';

  @override
  String get nasInstallTargetImage => 'อิมเมจเป้าหมาย';

  @override
  String get nasInstallContainerName => 'ชื่อคอนเทนเนอร์';

  @override
  String get nasInstallBindAndPort => 'การผูกและพอร์ต';

  @override
  String get nasInstallComposePreview => 'ดูตัวอย่าง docker-compose.json';

  @override
  String get nasInstallPlannedSteps => 'ขั้นตอนที่วางแผนไว้';

  @override
  String get nasInstallGuidanceNotes => 'หมายเหตุและคำแนะนำการปรับใช้';

  @override
  String get nasInstallNoLogsYet => 'ยังไม่มีบันทึก';

  @override
  String get sftpPreviewTooLarge =>
      'ไฟล์มีขนาดเกินขีดจำกัดการดูตัวอย่าง 1 MiB โปรดดาวน์โหลดและเปิดจากภายนอก';

  @override
  String get sftpSaveFailed =>
      'บันทึกไฟล์ไม่สำเร็จ ตรวจสอบสิทธิ์หรือการเชื่อมต่อเครือข่าย';

  @override
  String get sftpSaving => 'กำลังบันทึก...';

  @override
  String get nasInstallBlockerConnectionChanged =>
      'การเชื่อมต่อเซิร์ฟเวอร์เป้าหมายเปลี่ยนไป โปรดตรวจสอบสถานะระยะไกลก่อนดำเนินการต่อ';

  @override
  String get nasInstallBlockerCancelled =>
      'ผู้ใช้ยกเลิกการปรับใช้แล้ว ตรวจสอบการตั้งค่าและลองใหม่หากจำเป็น';

  @override
  String get nasInstallBlockerInspectFailed =>
      'การตรวจสอบล้มเหลวในการสอบถามคอนเทนเนอร์ระยะไกล ตรวจสอบการเชื่อมต่อเซิร์ฟเวอร์หรือตรวจสอบด้วยตนเอง';

  @override
  String get nasInstallBlockerDeadlineExceeded =>
      'ขั้นตอนการปรับใช้หมดเวลา ตรวจสอบโหลดของเซิร์ฟเวอร์หรือการเชื่อมต่อเครือข่ายแล้วลองใหม่อีกครั้ง';

  @override
  String get nasInstallBlockerInterrupted =>
      'การปรับใช้ถูกขัดจังหวะ ตรวจสอบสถานะระยะไกลก่อนดำเนินการต่อ';

  @override
  String get nasInstallBlockerHealthTimeout =>
      'บริการเริ่มทำงานแล้วแต่การตรวจสอบสถานะ HTTP หมดเวลา ตรวจสอบบันทึกบริการหรือความพร้อมใช้งานของพอร์ต';

  @override
  String get nasInstallBlockerReconciliationFailed =>
      'การปรับสถานะให้สอดคล้องกันล้มเหลว ตรวจสอบสถานะคอนเทนเนอร์ระยะไกลด้วยตนเองหรือเริ่มการปรับใช้ใหม่';

  @override
  String get nasInstallBlockerRemoteInspectionRequired =>
      'สถานะคอนเทนเนอร์ระยะไกลไม่แน่นอน จำเป็นต้องมีการตรวจสอบและปรับสถานะด้วยตนเอง';

  @override
  String get nasInstallBlockerServiceExited =>
      'กระบวนการคอนเทนเนอร์ออกจากระบบก่อนเวลาอันควร ตรวจสอบบันทึกเพื่อหาข้อผิดพลาดในการกำหนดค่าหรือสิทธิ์';

  @override
  String get nasInstallBlockerWriteFailed =>
      'เขียนไฟล์การปรับใช้บนเซิร์ฟเวอร์เป้าหมายไม่สำเร็จ ตรวจสอบพื้นที่ดิสก์และสิทธิ์';

  @override
  String get nasInstallBlockerPlanStale =>
      'แผนการปรับใช้ล้าสมัย โปรดเรียกใช้การตรวจสอบเบื้องต้นอีกครั้ง';

  @override
  String get nasInstallBlockerOwnershipChanged =>
      'คอนเทนเนอร์ที่มีอยู่ไม่ได้สร้างขึ้นโดยแอปนี้ ตรวจสอบด้วยตนเองเพื่อป้องกันการเขียนทับ';

  @override
  String get nasInstallBlockerSshRequired =>
      'จำเป็นต้องมีการเชื่อมต่อ SSH ที่ใช้งานอยู่กับเซิร์ฟเวอร์เป้าหมาย';

  @override
  String get nasInstallBlockerReconciliationRequired =>
      'สถานะระยะไกลแตกต่างจากสถานะภายในเครื่อง โปรดปรับสถานะให้สอดคล้องกันก่อนดำเนินการต่อ';

  @override
  String get nasInstallBlockerFailed =>
      'การปรับใช้พบข้อผิดพลาด ตรวจสอบบันทึกแล้วลองใหม่';

  @override
  String get nasInstallBlockerBusy =>
      'มีงานติดตั้งที่กำลังดำเนินอยู่แล้ว โปรดตรวจสอบความคืบหน้าของงานปัจจุบัน';

  @override
  String get nasInstallBlockerStateSaveFailed =>
      'ไม่สามารถบันทึกสถานะการปรับใช้ได้อย่างถาวร โปรดตรวจสอบพื้นที่จัดเก็บข้อมูลในเครื่องและสิทธิ์ของไฟล์';

  @override
  String get nasInstallBlockerCommandResultUnknown =>
      'ไม่ทราบผลลัพธ์ของคำสั่งระยะไกล โปรดเรียกใช้การตรวจสอบแบบอ่านอย่างเดียวแทนการลองปรับใช้ใหม่โดยตรง';

  @override
  String get nasInstallBlockerPreflightFailed =>
      'การตรวจสอบสภาพแวดล้อมก่อนการปรับใช้ล้มเหลว โปรดแก้ไขอุปสรรคก่อนดำเนินการต่อ';

  @override
  String serverDeleteFailed(String error) {
    return 'ลบเซิร์ฟเวอร์ไม่สำเร็จ: $error';
  }

  @override
  String get chatRunSettingsAgentMode => 'โหมด Agent';

  @override
  String get chatRunSettingsApprovalPolicy => 'นโยบายการอนุมัติในเครื่อง';

  @override
  String get chatRunSettingsExtraSettings => 'การตั้งค่าเพิ่มเติม';

  @override
  String get chatPermissionAutoAllowSafeDesc =>
      'อนุญาตการดำเนินการที่ทราบว่าปลอดภัยโดยอัตโนมัติ จะถามทุกครั้งที่ไม่สามารถระบุความปลอดภัยของการดำเนินการได้';

  @override
  String chatRunSettingsSaveFailed(String error) {
    return 'ใช้การตั้งค่าการทำงานไม่สำเร็จ: $error';
  }

  @override
  String get chatMessageCopied => 'คัดลอกข้อความไปยังคลิปบอร์ดแล้ว';

  @override
  String get copy => 'คัดลอก';

  @override
  String get rename => 'เปลี่ยนชื่อ';

  @override
  String get refresh => 'รีเฟรช';

  @override
  String get sessionTitle => 'ชื่อเซสชัน';

  @override
  String get chatSettingsStale => 'ล้าสมัย';

  @override
  String get chatSettingsAvailableAfterFirstMessage =>
      'การตั้งค่าจะพร้อมใช้งานหลังจากส่งข้อความแรก';

  @override
  String get chatReimportAsCopy => 'นำเข้าใหม่เป็นสำเนา';

  @override
  String get chatSearchCommandsHint => 'ค้นหาคำสั่งหรือทักษะ...';

  @override
  String get chatCommandsTab => 'คำสั่ง';

  @override
  String get chatSkillsTab => 'ทักษะ';

  @override
  String get chatAccountAndQuotaTitle => 'บัญชีและโควต้า';

  @override
  String get chatAccountSectionTitle => 'บัญชี';

  @override
  String get chatAccountNotProvided => 'ไม่มีการรายงานรายละเอียดบัญชี';

  @override
  String get chatAccountKind => 'ประเภท';

  @override
  String get chatAccountLabel => 'ป้ายกำกับ';

  @override
  String get chatAccountPlan => 'แผน';

  @override
  String get chatAccountEmail => 'อีเมล';

  @override
  String get chatAccountUpdatedAt => 'อัปเดตเมื่อ';

  @override
  String get chatQuotaSectionTitle => 'โควต้าและสถานะ';

  @override
  String get chatStatusSourceNote => 'ผลลัพธ์ /status ดิบของ Agent';

  @override
  String get chatStatusNotQueried => 'ยังไม่ได้สอบถามสถานะ';

  @override
  String get chatQueryStatusAction => 'สอบถามสถานะ (/status)';

  @override
  String get chatQueryStatusUnavailable =>
      'การสอบถามสถานะไม่พร้อมใช้งานในเซสชันปัจจุบัน';

  @override
  String get chatAttachmentMissing => 'ไฟล์แนบขาดหายหรือไม่พร้อมใช้งาน';

  @override
  String get chatViewModeList => 'รายการ';

  @override
  String get chatViewModeCards => 'การ์ด';

  @override
  String get chatViewModeGrid => 'รูปภาพ';

  @override
  String get chatRemoteBrowserTitle => 'พื้นที่ทำงานระยะไกล';

  @override
  String get chatSelectDirectory => 'เลือกไดเรกทอรี';

  @override
  String chatAttachSelectedFiles(int count) {
    return 'แนบรายการที่เลือก ($count)';
  }

  @override
  String get chatNoFilesFound => 'ไม่พบไฟล์';

  @override
  String get chatRootDirectory => 'รูท';

  @override
  String get chatSelectThisDirectory => 'ใช้ไดเรกทอรีนี้';

  @override
  String get chatAgentVersion => 'เวอร์ชัน Agent';

  @override
  String get chatParentDirectory => 'ไดเรกทอรีหลัก';

  @override
  String get chatSearchFilesHint => 'ค้นหาไฟล์...';

  @override
  String get chatCommandsEmpty => 'ไม่มีคำสั่ง slash ที่ Agent จัดเตรียมไว้';

  @override
  String get chatSkillsEmpty => 'ไม่มีทักษะที่ Agent จัดเตรียมไว้';

  @override
  String get chatFileUnsupported => 'ไม่รองรับประเภทไฟล์นี้สำหรับการแนบ';

  @override
  String get chatStatusNotProvided => 'Agent ไม่ได้จัดเตรียมการสอบถามสถานะ';

  @override
  String get sessionRecoveryReconnecting => 'กำลังเชื่อมต่อใหม่...';

  @override
  String get sessionRecoverySyncing => 'กำลังซิงค์ผลลัพธ์...';

  @override
  String get sessionRecoveryIncomplete => 'ไม่สามารถกู้คืนผลลัพธ์บางส่วนได้';

  @override
  String get sessionRecoveryFailed => 'การกู้คืนล้มเหลว';

  @override
  String get sessionRecoveryRetry => 'ลองใหม่';

  @override
  String get dashboardUpdatesPaused => 'หยุดการอัปเดตชั่วคราว';

  @override
  String get chatSettingsIndependentModelUnavailable =>
      'แคตตาล็อกโมเดล CLI ยังไม่พร้อมใช้งานในขณะนี้ โมเดลอาจถูกแคชไว้หรือถูกจำกัดโดยเวอร์ชันของ CLI คุณยังสามารถป้อนชื่อโมเดลด้วยตนเองได้';

  @override
  String get chatSettingsModelCatalogNote =>
      'โมเดลจะถูกสอบถามจากแอปเซิร์ฟเวอร์ CLI โดยใช้การเข้าสู่ระบบ CLI ปัจจุบันของคุณ แคตตาล็อกอาจถูกแคชหรือจำกัดเวอร์ชัน คุณสามารถรีเฟรชด้วยตนเองหรือเปลี่ยนไปใช้การป้อนข้อมูลด้วยตนเอง';

  @override
  String get chatModelCatalogError403 =>
      'การเข้าถึงการสอบถามโมเดล CLI ถูกปฏิเสธ (403) ตรวจสอบการเข้าสู่ระบบ CLI และการเชื่อมต่อบริการ หรือป้อนชื่อโมเดลด้วยตนเอง';

  @override
  String chatModelCatalogErrorGeneric(String error) {
    return 'ข้อผิดพลาดของแคตตาล็อกโมเดล: $error';
  }

  @override
  String get chatModelAuthorizeButton => 'อนุญาตแคตตาล็อกโมเดล';

  @override
  String get chatModelAuthorizeConfirmTitle => 'อนุญาตแคตตาล็อกโมเดล';

  @override
  String get chatModelAuthorizeConfirmMessage =>
      'การดำเนินการนี้จะเริ่มการอนุญาตผ่านเบราว์เซอร์สำหรับแคตตาล็อกโมเดลบนโฮสต์/คอนเทนเนอร์เป้าหมาย การเข้าสู่ระบบ Codex และเซสชันเทอร์มินัลที่มีอยู่ของคุณจะไม่ได้รับผลกระทบใดๆ ดำเนินการต่อหรือไม่?';

  @override
  String get chatModelAuthorizing => 'กำลังอนุญาตผ่านเบราว์เซอร์...';

  @override
  String get chatModelAuthorizeCancel => 'ยกเลิกการอนุญาต';

  @override
  String get chatCommandsFirstTurnNote =>
      'คำสั่ง slash จะถูกแจ้งโดยรันไทม์ของ Agent ทันทีที่เซสชันเริ่มต้น โดยไม่จำเป็นต้องมีการสนทนาปกติมาก่อน ฉบับร่างจะไม่สร้างเซสชันโดยอัตโนมัติ';

  @override
  String get chatCommandsClientActionRunSettings => 'การตั้งค่าการทำงาน';

  @override
  String get chatCommandsClientActionWorkingDirectory => 'ไดเรกทอรีทำงาน';

  @override
  String get chatCommandsClientActionsSection => 'การดำเนินการภายในเครื่อง';

  @override
  String get chatRunSettingsModelSourceCatalog => 'รายการโมเดล';

  @override
  String get chatRunSettingsModelSourceCustom => 'ป้อนข้อมูลด้วยตนเอง';

  @override
  String get chatRunSettingsCustomModelHint => 'ป้อน ID โมเดล';

  @override
  String get chatRunSettingsCustomModelNotice =>
      'ชื่อโมเดลที่ป้อนด้วยตนเองยังไม่ได้รับการยืนยันและจะถูกส่งไปยังรันไทม์ของ Agent โดยตรง ซึ่งอาจปฏิเสธโมเดลที่ไม่รองรับได้';

  @override
  String get chatRunSettingsCustomModelEmptyError => 'ชื่อโมเดลต้องไม่เว้นว่าง';

  @override
  String get chatRunSettingsCustomModelInvalidError =>
      'ชื่อโมเดลต้องมีความยาวไม่เกิน 256 ตัวอักษร โดยไม่มีช่องว่างหรืออักขระควบคุม';

  @override
  String get chatCommandsDraftPreviewNotice =>
      'คำสั่งได้รับการตรวจสอบแล้วสำหรับเวอร์ชันอะแดปเตอร์ปัจจุบัน การเลือกจะแทรกข้อความลงในฉบับร่าง การส่งจะเริ่มต้นเซสชันตามความต้องการและเรียกใช้คำสั่งโดยตรง';

  @override
  String get chatCommandsDiscoveryFailed => 'ค้นหาคำสั่งหรือทักษะไม่สำเร็จ';

  @override
  String get chatAuthWaitingForBrowser => 'กำลังรอการอนุญาตในเบราว์เซอร์...';

  @override
  String get chatAuthBrowserLaunchFailed =>
      'ไม่สามารถเปิดเบราว์เซอร์ภายนอกได้ โปรดเปิดใหม่หรือคัดลอกลิงก์การอนุญาตด้านล่าง';

  @override
  String get chatAuthReopenBrowser => 'เปิดเบราว์เซอร์อีกครั้ง';

  @override
  String get chatAuthCopyLink => 'คัดลอกลิงก์';

  @override
  String get chatAuthManualCallback => 'คอลแบ็กด้วยตนเอง';

  @override
  String get chatAuthManualCallbackTitle => 'ป้อน URL คอลแบ็กการอนุญาต';

  @override
  String get chatAuthManualCallbackDesc =>
      'วาง URL เปลี่ยนเส้นทางแบบเต็ม (http://127.0.0.1:PORT/...?code=...&state=...) จากเบราว์เซอร์เพื่อเสร็จสิ้นการอนุญาต ไม่ยอมรับรหัสการอนุญาตแบบดิบ';

  @override
  String get chatAuthCallbackInputLabel => 'URL คอลแบ็ก';

  @override
  String get chatAuthCallbackInputHint =>
      'http://127.0.0.1:PORT/...?code=...&state=...';

  @override
  String get chatAuthCallbackInvalidError =>
      'รูปแบบ URL คอลแบ็กไม่ถูกต้องหรือการส่งล้มเหลว';

  @override
  String get agentAuthAgYNotice =>
      'Antigravity ACP ต้องได้รับการอนุญาตบัญชีอย่างเป็นทางการ ซึ่งแยกออกจากการเข้าสู่ระบบ CLI ในเทอร์มินัล';

  @override
  String get chatAuthDiscoveryPrompt =>
      'รอบนี้ต้องการการตรวจสอบสิทธิ์ ACP เชื่อมต่อใหม่และขอการอนุญาตเพื่อดำเนินการต่อ';

  @override
  String get chatRequestAuthButton => 'ขอการตรวจสอบสิทธิ์';

  @override
  String get agentActionAcpLogin => 'ลงชื่อเข้าใช้ ACP';

  @override
  String get agentActionCliLogin => 'เข้าสู่ระบบ CLI';

  @override
  String get agentAgyAcpSignInRequired =>
      'ข้อมูลประจำตัว ACP ขาดหาย (ต้องลงชื่อเข้าใช้ ACP)';

  @override
  String get agentAgyAcpCredentialsSaved =>
      'บันทึกข้อมูลประจำตัว ACP แล้ว (ยังไม่ได้ยืนยัน)';

  @override
  String get chatAuthMethodUnavailable =>
      'วิธีการตรวจสอบสิทธิ์ที่เลือกไม่พร้อมใช้งาน';

  @override
  String get chatAuthConnectionExpired =>
      'การเชื่อมต่อการตรวจสอบสิทธิ์หมดอายุ โปรดลองอีกครั้ง';

  @override
  String get chatAuthCallbackDeliveryFailed =>
      'ส่งคอลแบ็กการอนุญาตไปยังเซิร์ฟเวอร์ไม่สำเร็จ';

  @override
  String get agentTargetChangedNotice =>
      'เซิร์ฟเวอร์เป้าหมายเปลี่ยนไปแล้ว โปรดเปิดการจัดการ Agent อีกครั้งบนเซิร์ฟเวอร์ปัจจุบัน';

  @override
  String get agentAgyAuthCheckUnavailable =>
      'การตรวจสอบสิทธิ์ Antigravity ไม่พร้อมใช้งาน';

  @override
  String get agentAgyAuthCheckInvalid =>
      'การตอบกลับการตรวจสอบสิทธิ์ Antigravity ไม่ถูกต้อง';

  @override
  String get sftpDownloadDisconnected => 'การดาวน์โหลดถูกตัดการเชื่อมต่อ';

  @override
  String get sftpDownloadPermissionDenied => 'ถูกปฏิเสธการอนุญาต';

  @override
  String get sftpDownloadNotFound => 'ไม่พบไฟล์ระยะไกล';

  @override
  String get sftpDownloadTimeout => 'การดาวน์โหลดหมดเวลา';

  @override
  String get sftpDownloadLocalSpace => 'พื้นที่จัดเก็บในเครื่องไม่เพียงพอ';

  @override
  String get sftpDownloadLocalIo => 'เขียนลงพื้นที่จัดเก็บในเครื่องไม่สำเร็จ';

  @override
  String get sftpDownloadIncomplete => 'การดาวน์โหลดไม่สมบูรณ์';

  @override
  String get transferStatusWaitingConnection => 'กำลังรอการเชื่อมต่อ';

  @override
  String get chatAuthCallbackListenerFailed =>
      'เริ่มตัวรับฟังคอลแบ็กการอนุญาตในเครื่องไม่สำเร็จ โปรดลองตรวจสอบสิทธิ์อีกครั้ง';

  @override
  String get settingsExperimentalFeatures => 'คุณสมบัติทดลอง';

  @override
  String get settingsExperimentalFeaturesDesc =>
      'ทดลองใช้ความสามารถในการแสดงตัวอย่างและคุณสมบัติทดลอง';

  @override
  String get settingsExperimentalCliChatTitle => 'แชทอัจฉริยะ CLI';

  @override
  String get settingsExperimentalCliChatDesc =>
      'เปิดใช้งานอินเทอร์เฟซแชทสำหรับ Agent บรรทัดคำสั่งโดยเฉพาะ';

  @override
  String get settingsExperimentalDialogClose => 'ปิด';

  @override
  String get settingsExperimentalSaveFailed =>
      'อัปเดตการตั้งค่าคุณสมบัติทดลองไม่สำเร็จ';

  @override
  String get settingsExperimentalNasTitle => 'NAS มีเดีย';

  @override
  String get settingsExperimentalNasDesc =>
      'เปิดใช้งานคลังสื่อ การสแกนโฟลเดอร์ และการเล่นเสียง';

  @override
  String get settingsLanguageSaveFailed => 'อัปเดตการตั้งค่าภาษาไม่สำเร็จ';
}
