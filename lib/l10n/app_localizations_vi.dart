// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appName => 'Valhalla';

  @override
  String get appSubtitle => 'Quản lý Máy chủ & Agent Chuẩn AI';

  @override
  String get navAiChat => 'Trò chuyện AI';

  @override
  String get navTerminal => 'Terminal';

  @override
  String get navFiles => 'Tệp SFTP';

  @override
  String get navCommands => 'Lệnh';

  @override
  String get navSettings => 'Cài đặt';

  @override
  String get serverConnected => 'Đã kết nối';

  @override
  String get serverOnline => 'Trực tuyến';

  @override
  String get serverOffline => 'Ngoại tuyến';

  @override
  String get latencyMs => 'ms';

  @override
  String get reconnect => 'Kết nối lại';

  @override
  String get disconnect => 'Ngắt kết nối';

  @override
  String get quickDisconnect => 'Ngắt kết nối nhanh';

  @override
  String get newSession => 'Phiên mới';

  @override
  String get historySessions => 'Lịch sử phiên';

  @override
  String get switchAgent => 'Chuyển đổi Agent';

  @override
  String get agentClaudeCode => 'Claude CodeX';

  @override
  String get agentCodex => 'OpenAI Codex';

  @override
  String get agentOpenCode => 'OpenCode ACP';

  @override
  String get agentGemini => 'Gemini CLI';

  @override
  String get activeAgent => 'Agent đang hoạt động';

  @override
  String get inputPromptHint =>
      'Yêu cầu Agent chẩn đoán, chạy công cụ hoặc viết lệnh... (Nhấn Enter để gửi)';

  @override
  String get thinking => 'Quá trình suy nghĩ';

  @override
  String get executionPlan => 'Kế hoạch thực thi';

  @override
  String get toolCall => 'Gọi công cụ';

  @override
  String get toolStatusPending => 'Đang chờ';

  @override
  String get toolStatusRunning => 'Đang chạy...';

  @override
  String get toolStatusCompleted => 'Đã hoàn thành';

  @override
  String get toolStatusFailed => 'Thất bại';

  @override
  String get permissionRequired => 'Yêu cầu cấp quyền';

  @override
  String get permissionDescription =>
      'Agent muốn thực thi lệnh này trên máy chủ:';

  @override
  String get permissionReject => 'Từ chối';

  @override
  String get permissionAllowOnce => 'Cho phép một lần';

  @override
  String get permissionAllowAlways => 'Luôn cho phép';

  @override
  String get quickTroubleshootCpu => 'Khắc phục sự cố CPU cao';

  @override
  String get quickDockerHealth => 'Kiểm tra tình trạng Docker';

  @override
  String get quickCleanCache => 'Dọn dẹp bộ nhớ đệm hệ thống';

  @override
  String get quickNginxLogs => 'Kiểm tra nhật ký lỗi Nginx';

  @override
  String get terminalNewTab => 'Tab mới';

  @override
  String get terminalCloseTab => 'Đóng tab';

  @override
  String get terminalClear => 'Xóa';

  @override
  String get terminalQuickCmds => 'Bảng lệnh';

  @override
  String get terminalPaste => 'Dán';

  @override
  String get sftpCurrentPath => 'Đường dẫn hiện tại';

  @override
  String get sftpUpload => 'Tải lên';

  @override
  String get sftpNewFolder => 'Thư mục mới';

  @override
  String get sftpNewFile => 'Tệp mới';

  @override
  String get sftpRefresh => 'Làm mới';

  @override
  String get sftpSearchHint => 'Tìm kiếm tệp hoặc thư mục...';

  @override
  String get sftpEmpty => 'Thư mục trống';

  @override
  String get sftpFileName => 'Tên';

  @override
  String get sftpFileSize => 'Kích thước';

  @override
  String get sftpFilePerm => 'Quyền';

  @override
  String get sftpFileModified => 'Đã sửa đổi';

  @override
  String get cmdCategoryDocker => 'NGĂN XẾP CONTAINER DOCKER';

  @override
  String get cmdCategorySystem => 'BẢO TRÌ HỆ THỐNG';

  @override
  String get cmdCategoryNetwork => 'MẠNG & CỔNG';

  @override
  String get cmdExecute => 'Chạy';

  @override
  String get cmdDangerous => 'Lệnh nguy hiểm';

  @override
  String get cmdDangerousWarning =>
      'Thao tác này không thể hoàn tác và có thể gây gián đoạn dịch vụ. Bạn có chắc chắn muốn tiếp tục?';

  @override
  String get cmdParamRequired => 'Yêu cầu nhập tham số';

  @override
  String get cmdConfirm => 'Xác nhận & Chạy';

  @override
  String get cmdCancel => 'Hủy';

  @override
  String get settingsAppearance => 'Giao diện & Chủ đề';

  @override
  String get settingsThemeMode => 'Chế độ chủ đề';

  @override
  String get themeSystem => 'Theo hệ thống';

  @override
  String get themeSystemDesc => 'Tự động điều chỉnh';

  @override
  String get themeLight => 'Chế độ sáng';

  @override
  String get themeLightDesc => 'Giấy sáng';

  @override
  String get themeDark => 'Geek Tối';

  @override
  String get themeDarkDesc => 'Than đen sâu';

  @override
  String get themeAmoled => 'Đen AMOLED';

  @override
  String get themeAmoledDesc => 'Đen tuyền 0x000000';

  @override
  String get settingsAccentColor => 'Màu nhấn chủ đề';

  @override
  String get accentCyberEmerald => 'Ngọc lục bảo Cyber';

  @override
  String get accentTechBlue => 'Xanh công nghệ';

  @override
  String get accentElectricViolet => 'Tím điện tích';

  @override
  String get accentCrimsonRed => 'Đỏ thẫm';

  @override
  String get accentAmberOrange => 'Cam hổ phách';

  @override
  String get settingsLanguage => 'Ngôn ngữ & Khu vực';

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
  String get settingsAiOps => 'AI Ops & Động cơ';

  @override
  String get settingsSecurity => 'Kết nối & Bảo mật';

  @override
  String get settingsKnownHosts => 'Khóa máy chủ đã biết';

  @override
  String get settingsClearStorage => 'Đặt lại thông tin xác thực';

  @override
  String get settingsResetDefault => 'Khôi phục mặc định';

  @override
  String get settingsTerminalUseTmux => 'Phiên duy trì (tmux)';

  @override
  String get settingsTerminalUseTmuxSubtitle =>
      'Chạy các phiên terminal bên trong tmux trên máy chủ từ xa';

  @override
  String get settingsTerminalUseTmuxDescription =>
      'Giữ lại đầu ra terminal sau khi ngắt kết nối. Yêu cầu tmux trên máy chủ từ xa. Thay đổi áp dụng cho các tab terminal mới mở.';

  @override
  String get settingsTerminalFontSize => 'Cỡ chữ terminal';

  @override
  String get settingsTerminalFontSizeSubtitle =>
      'Điều chỉnh cỡ chữ terminal SSH và CLI';

  @override
  String get version => 'Phiên bản';

  @override
  String get addServer => 'Thêm máy chủ';

  @override
  String get editServer => 'Chỉnh sửa máy chủ';

  @override
  String get serverName => 'Tên máy chủ';

  @override
  String get serverHost => 'Máy chủ / IP';

  @override
  String get serverPort => 'Cổng';

  @override
  String get serverUsername => 'Tên người dùng';

  @override
  String get serverAuthType => 'Loại xác thực';

  @override
  String get serverPassword => 'Mật khẩu';

  @override
  String get serverPrivateKey => 'Khóa riêng tư';

  @override
  String get serverSave => 'Lưu máy chủ';

  @override
  String get serverDelete => 'Xóa máy chủ';

  @override
  String get fileEditor => 'Trình chỉnh sửa tệp';

  @override
  String get fileEditorSave => 'Lưu thay đổi';

  @override
  String get fileSavedSuccess => 'Đã lưu tệp thành công';

  @override
  String get addCommand => 'Lệnh mới';

  @override
  String get commandTitle => 'Tiêu đề lệnh';

  @override
  String get commandContent => 'Chuỗi lệnh';

  @override
  String get commandCategory => 'Danh mục';

  @override
  String get commandDescription => 'Mô tả';

  @override
  String get save => 'Lưu';

  @override
  String get delete => 'Xóa';

  @override
  String get cancel => 'Hủy';

  @override
  String get confirm => 'Xác nhận';

  @override
  String get cmdExecutionChannel => 'Kênh thực thi';

  @override
  String get cmdChannelTerminal => 'Trực tiếp đến Terminal SSH';

  @override
  String get cmdChannelTerminalDesc =>
      'Lệnh được nhập trực tiếp vào phiên terminal đang hoạt động';

  @override
  String get cmdChannelBackground => 'Chạy trong phiên nền';

  @override
  String get cmdChannelBackgroundDesc =>
      'Thực thi qua shell đăng nhập SSH và ghi lại đầu ra';

  @override
  String get cmdInjectedToTerminal => 'Đã gửi lệnh đến terminal';

  @override
  String get cmdExecutionCompleted => 'Thực thi hoàn tất';

  @override
  String get cmdExecutionFailed => 'Thực thi thất bại';

  @override
  String get cmdExecutingRemote => 'Đang thực thi lệnh từ xa...';

  @override
  String get cmdClose => 'Đóng';

  @override
  String get navDashboard => 'Bảng điều khiển';

  @override
  String get navDocker => 'Docker';

  @override
  String get navSystem => 'Hệ thống';

  @override
  String get navMore => 'Thêm';

  @override
  String get dashboardTitle => 'Bảng điều khiển máy chủ';

  @override
  String get metricsCpu => 'Sử dụng CPU';

  @override
  String get metricsMemory => 'Sử dụng bộ nhớ';

  @override
  String get metricsLoadAvg => 'Tải trung bình';

  @override
  String get metricsUptime => 'Thời gian hoạt động';

  @override
  String get metricsRootDisk => 'Sử dụng đĩa gốc';

  @override
  String get quickActions => 'Điều hướng nhanh';

  @override
  String get activeServerStatus => 'Trạng thái máy chủ hoạt động';

  @override
  String get noServerSelected =>
      'Hiện chưa chọn máy chủ nào. Vui lòng chọn một máy chủ trước.';

  @override
  String get serverDisconnected => 'Đã ngắt kết nối';

  @override
  String get serverConnecting => 'Đang kết nối...';

  @override
  String get connectNow => 'Kết nối ngay';

  @override
  String get serverSpecs => 'Thông tin & Cấu hình máy chủ';

  @override
  String get dockerTitle => 'Container Docker';

  @override
  String get dockerSearchHint => 'Tìm kiếm container theo tên hoặc hình ảnh...';

  @override
  String get dockerFilterAll => 'Tất cả';

  @override
  String get dockerFilterRunning => 'Đang chạy';

  @override
  String get dockerFilterExited => 'Đã thoát';

  @override
  String get dockerFilterPaused => 'Đã tạm dừng';

  @override
  String get dockerActionStart => 'Khởi động';

  @override
  String get dockerActionStop => 'Dừng';

  @override
  String get dockerActionRestart => 'Khởi động lại';

  @override
  String get dockerActionPause => 'Tạm dừng';

  @override
  String get dockerActionUnpause => 'Tiếp tục';

  @override
  String get dockerActionRm => 'Xóa';

  @override
  String get dockerActionLogs => 'Nhật ký';

  @override
  String get dockerActionInspect => 'Kiểm tra';

  @override
  String get dockerLogsTitle => 'Nhật ký container';

  @override
  String get dockerInspectTitle => 'Chi tiết kiểm tra container';

  @override
  String get dockerNoContainers => 'Không tìm thấy container trên máy chủ';

  @override
  String get dockerEmptyRunning => 'Không có container nào đang chạy';

  @override
  String get dockerPorts => 'Cổng';

  @override
  String get dockerCreated => 'Đã tạo';

  @override
  String get dockerImage => 'Hình ảnh';

  @override
  String get systemTitle => 'Tiến trình & Dịch vụ';

  @override
  String get tabProcesses => 'Tiến trình';

  @override
  String get tabServices => 'Dịch vụ Systemd';

  @override
  String get processSearchHint => 'Tìm kiếm theo tên tiến trình hoặc PID...';

  @override
  String get processPid => 'PID';

  @override
  String get processCpu => '% CPU';

  @override
  String get processMem => '% MEM';

  @override
  String get processStat => 'Trạng thái';

  @override
  String get processCommand => 'Lệnh';

  @override
  String get processTerminate => 'Chấm dứt (SIGTERM)';

  @override
  String get processForceKill => 'Buộc dừng (SIGKILL)';

  @override
  String get processKillForbidden =>
      'Từ chối chấm dứt tiến trình init hệ thống (PID <= 1)';

  @override
  String get serviceSearchHint => 'Tìm kiếm dịch vụ theo tên...';

  @override
  String get serviceName => 'Dịch vụ';

  @override
  String get serviceDescription => 'Mô tả';

  @override
  String get serviceStatus => 'Trạng thái';

  @override
  String get serviceStartup => 'Khởi động';

  @override
  String get serviceActionStart => 'Khởi động';

  @override
  String get serviceActionStop => 'Dừng';

  @override
  String get serviceActionRestart => 'Khởi động lại';

  @override
  String get serviceActionReload => 'Tải lại';

  @override
  String get serviceActionEnable => 'Bật';

  @override
  String get serviceActionDisable => 'Tắt';

  @override
  String get serviceNoServices => 'Không tìm thấy dịch vụ systemd';

  @override
  String get riskDangerTitle => 'Xác nhận thao tác có rủi ro cao';

  @override
  String get riskWarningTitle => 'Xác nhận cảnh báo thao tác';

  @override
  String get riskSafeTitle => 'Xác nhận hành động';

  @override
  String get riskIrreversibleWarning =>
      'Thao tác này được phân loại là RỦI RO CAO và không thể hoàn tác. Nó có thể gây mất dữ liệu hoặc gián đoạn dịch vụ.';

  @override
  String get riskWarningDescription =>
      'Thao tác này có thể ảnh hưởng đến các dịch vụ đang hoạt động hoặc khởi động lại tiến trình. Hãy thận trọng tiếp tục.';

  @override
  String get riskCommandPreview => 'Xem trước lệnh';

  @override
  String get riskConfirmButton => 'Xác nhận & Tiếp tục';

  @override
  String get riskCancelButton => 'Hủy';

  @override
  String get stateLoading => 'Đang tải dữ liệu từ xa...';

  @override
  String get stateOffline => 'Máy chủ ngoại tuyến';

  @override
  String get stateOfflineDesc =>
      'Thiết lập kết nối SSH hoạt động để quản lý tài nguyên và truyền số liệu.';

  @override
  String get stateError => 'Đã xảy ra lỗi';

  @override
  String get stateRetry => 'Thử lại';

  @override
  String get stateEmpty => 'Không tìm thấy mục nào';

  @override
  String get inspectorTitle => 'Trình kiểm tra';

  @override
  String get inspectorClose => 'Đóng';

  @override
  String get inspectorDetails => 'Chi tiết kiểm tra';

  @override
  String get selectServerTitle => 'Chọn máy chủ đích';

  @override
  String get sshDisconnectedSuccess => 'Đã ngắt kết nối SSH thành công';

  @override
  String get trustHostFingerprintTitle => 'Tin cậy dấu vân tay máy chủ?';

  @override
  String get trustAndConnect => 'Tin cậy & Kết nối';

  @override
  String get reject => 'Từ chối';

  @override
  String get confirmDeleteServerTitle => 'Xóa máy chủ';

  @override
  String get noServersFound => 'Chưa có máy chủ nào được cấu hình';

  @override
  String get agentNotReadyError =>
      'Agent đã chọn chưa sẵn sàng. Vui lòng xác minh môi trường và cấu hình.';

  @override
  String get sshDisconnectedError =>
      'SSH đã ngắt kết nối. Vui lòng kết nối với máy chủ trước khi sử dụng AI Ops.';

  @override
  String get noAgentAvailable => 'Không có Agent khả dụng';

  @override
  String get noAgentAvailablePrompt =>
      'Không có Agent nào đang hoạt động. Vui lòng cấu hình hoặc chuẩn bị một agent trước.';

  @override
  String get noAgentAvailableHint =>
      'Chọn hoặc cấu hình một agent khả dụng để trò chuyện...';

  @override
  String get manageAgents => 'Quản lý Agent';

  @override
  String get noReadyAgentsTitle => 'Không có Agent sẵn sàng';

  @override
  String get noReadyAgentsDesc =>
      'Không có agent nào trên máy chủ này vượt qua kiểm tra môi trường.';

  @override
  String get agentStatusReady => 'Sẵn sàng';

  @override
  String get agentStatusChecking => 'Đang kiểm tra...';

  @override
  String get agentStatusCliMissing => 'Chưa phát hiện cài đặt';

  @override
  String get agentStatusAcpMissing => 'Chưa phát hiện thành phần ACP';

  @override
  String get agentStatusNotLoggedIn => 'Chưa đăng nhập';

  @override
  String get agentStatusError => 'Lỗi';

  @override
  String get agentStatusUnknown => 'Không xác định';

  @override
  String get agentActionInstall => 'Cài đặt';

  @override
  String get agentActionLogin => 'Đăng nhập';

  @override
  String get agentActionRefresh => 'Kiểm tra trạng thái';

  @override
  String get noConfiguredAgents =>
      'Không có agent nào được cấu hình trên máy chủ này';

  @override
  String get agentManagementTitle => 'Quản lý Agent';

  @override
  String get settingsAgentManagement => 'Quản lý Agent';

  @override
  String get settingsAgentManagementSubtitle =>
      'Cấu hình, phát hiện và quản lý Agent ACP cho máy chủ hiện tại';

  @override
  String get addAgentButton => 'Thêm Agent';

  @override
  String get noServerSelectedForAgents =>
      'Chưa chọn máy chủ nào. Vui lòng chọn một máy chủ từ giao diện chính trước.';

  @override
  String get sshDisconnectedAgentWarning =>
      'SSH đã ngắt kết nối. Tính năng phát hiện, cài đặt và đăng nhập bị tắt cho đến khi kết nối được thiết lập.';

  @override
  String get noAgentsConfiguredTitle => 'Chưa cấu hình Agent';

  @override
  String get noAgentsConfiguredDesc =>
      'Thêm Claude Code, Codex, OpenCode, AGY hoặc agent ACP tùy chỉnh để bật AI Ops trên máy chủ này.';

  @override
  String get agentPresetLabel => 'Mẫu sẵn';

  @override
  String get agentPresetClaudeCode => 'Claude Code';

  @override
  String get agentPresetCodex => 'OpenAI Codex';

  @override
  String get agentPresetOpenCode => 'OpenCode ACP';

  @override
  String get agentPresetAgy => 'Antigravity AGY';

  @override
  String get agentPresetCustom => 'Tùy chỉnh';

  @override
  String get agentNameLabel => 'Tên Agent';

  @override
  String get agentNameHint => 'ví dụ: Production Codex';

  @override
  String get agentDescriptionLabel => 'Mô tả';

  @override
  String get agentDescriptionHint => 'Mô tả ngắn gọn về agent';

  @override
  String get agentCliCommandLabel => 'Lệnh kiểm tra CLI';

  @override
  String get agentCliCommandHint => 'ví dụ: claude, codex';

  @override
  String get agentAcpCommandLabel => 'Lệnh khởi chạy ACP';

  @override
  String get agentAcpCommandHint => 'ví dụ: codex-acp --stdio';

  @override
  String get agentInstallCommandLabel => 'Lệnh cài đặt (Tùy chọn)';

  @override
  String get agentInstallCommandHint => 'ví dụ: npm install -g @openai/codex';

  @override
  String get agentLoginCheckCommandLabel =>
      'Lệnh kiểm tra đăng nhập (Tùy chọn)';

  @override
  String get agentLoginCheckCommandHint => 'ví dụ: codex --version';

  @override
  String get agentLoginCommandLabel => 'Lệnh đăng nhập (Tùy chọn)';

  @override
  String get agentLoginCommandHint => 'ví dụ: codex login';

  @override
  String get agentSaveButton => 'Lưu & Phát hiện';

  @override
  String get agentCliRequired => 'Lệnh kiểm tra CLI là bắt buộc';

  @override
  String get agentAcpRequired => 'Lệnh khởi chạy ACP là bắt buộc';

  @override
  String get agentNameRequired => 'Tên agent là bắt buộc';

  @override
  String get confirmInstallAgentTitle => 'Xác nhận cài đặt Agent';

  @override
  String get confirmLoginAgentTitle => 'Xác nhận đăng nhập Agent';

  @override
  String get agentCommandRiskWarning =>
      'Lệnh này sẽ được thực thi trực tiếp trên máy chủ từ xa với quyền hạn người dùng hiện tại. Nó có thể cài đặt gói hoặc sửa đổi môi trường hệ thống.';

  @override
  String get targetServerLabel => 'Máy chủ đích';

  @override
  String get commandPreviewLabel => 'Xem trước lệnh';

  @override
  String get executeButton => 'Thực thi';

  @override
  String get deleteAgentTitle => 'Xóa Agent';

  @override
  String get deleteAgentConfirm => 'Xóa';

  @override
  String get agentStatusCheckingDesc =>
      'Đang phát hiện môi trường trên máy chủ từ xa...';

  @override
  String get agentStatusInstalling =>
      'Đang cài đặt các phụ thuộc trên máy chủ...';

  @override
  String get agentStatusLoggingIn =>
      'Đang thực thi lệnh đăng nhập trên máy chủ...';

  @override
  String get agentNoLoginCheckProvided =>
      'Chưa chỉ định lệnh kiểm tra đăng nhập';

  @override
  String get agentInstallPrompt =>
      'Chưa phát hiện cài đặt. Tự động cài đặt ngay bây giờ?';

  @override
  String get agentActionAutoInstall => 'Tự động cài đặt';

  @override
  String get agentLoginPrompt => 'Chưa đăng nhập. Đăng nhập ngay bây giờ?';

  @override
  String get agentActionExecuteLogin => 'Đăng nhập ngay';

  @override
  String get agentNeedsInstallOrReadyPrompt =>
      'Các agent trên máy chủ này chưa được cài đặt hoặc chưa sẵn sàng. Vui lòng quản lý và hoàn tất thiết lập môi trường.';

  @override
  String get agentNeedsInstallOrReadyHint =>
      'Cài đặt và chuẩn bị một agent để bắt đầu trò chuyện...';

  @override
  String get agentAcpInstallPrompt =>
      'Chưa phát hiện thành phần ACP. Tự động cài đặt ngay bây giờ?';

  @override
  String get agentInstallCommandAcpLabel => 'Lệnh cài đặt ACP (Tùy chọn)';

  @override
  String get agentInstallCommandAcpHint =>
      'ví dụ: npm install -g @zed-industries/codex-acp';

  @override
  String get agentNoInstallCommand =>
      'Không có lệnh cài đặt nào được cấu hình cho agent này';

  @override
  String get agentInstallLogTitle => 'Đầu ra cài đặt';

  @override
  String get agentInstallLogEmpty => 'Đang chờ đầu ra cài đặt…';

  @override
  String get agentInstallLogTruncated =>
      'Đầu ra quá dài; chỉ hiển thị các dòng gần đây nhất';

  @override
  String get agentAcpOptional => 'Tùy chọn; để trống nếu chỉ dùng CLI';

  @override
  String get acpStreaming => 'Đang phát luồng ACP...';

  @override
  String get aiOpsAgentTitle => 'Agent Valhalla AI Ops';

  @override
  String get aiOpsEmptySubtitle => 'Đã kết nối qua ACP stdio trên Kênh SSH';

  @override
  String get agentAuthRequiredTitle => 'Yêu cầu xác thực';

  @override
  String get agentAuthRequiredDesc =>
      'Agent yêu cầu xác thực trước khi có thể xử lý yêu cầu của bạn.';

  @override
  String get agentAuthMethodLabel => 'Phương thức xác thực';

  @override
  String get agentAuthNoMethodsNotice =>
      'Agent không cung cấp phương thức đăng nhập. Vui lòng kiểm tra cấu hình của nó trên máy chủ.';

  @override
  String get agentAuthProceedButton => 'Đăng nhập';

  @override
  String get agentAuthCancelButton => 'Hủy';

  @override
  String get agentAuthRetryHint =>
      'Sau khi đăng nhập, hãy gửi lại tin nhắn của bạn.';

  @override
  String get agentAuthRequiredError =>
      'Yêu cầu xác thực. Vui lòng đăng nhập để tiếp tục.';

  @override
  String get agentLoginTerminalTitle => 'Terminal đăng nhập tương tác';

  @override
  String get agentLoginTerminalSubtitle =>
      'Hoàn thành các bước đăng nhập trong terminal bên dưới. Làm theo bất kỳ lời nhắc URL hoặc mã nào được hiển thị.';

  @override
  String get agentLoginTerminalRunning =>
      'Lệnh đăng nhập đang chạy trong terminal...';

  @override
  String get agentLoginTerminalDisconnected =>
      'Mất kết nối SSH. Phiên đăng nhập đã bị gián đoạn.';

  @override
  String get agentLoginTerminalRetry => 'Kết nối lại Terminal';

  @override
  String get agentLoginTerminalFinish => 'Hoàn tất & Xác minh';

  @override
  String get agentLoginTerminalClose => 'Đóng';

  @override
  String get agentLoginTerminalNoTtyHint =>
      'Nếu agent yêu cầu dán mã, nhấn giữ vào terminal để dán hoặc sử dụng phím PASTE.';

  @override
  String get agentLoginTerminalUrlLabel => 'Đã phát hiện URL đăng nhập';

  @override
  String get agentLoginTerminalUrlCopy => 'Sao chép liên kết';

  @override
  String get agentLoginTerminalUrlCopied =>
      'Đã sao chép URL đăng nhập vào khay nhớ tạm';

  @override
  String get agentLoginTerminalCopyAll => 'Sao chép tất cả đầu ra';

  @override
  String get agentLoginTerminalCopiedAll =>
      'Đã sao chép đầu ra terminal vào khay nhớ tạm';

  @override
  String get sshStatusReconnected => 'Đã khôi phục kết nối';

  @override
  String get sshStatusDisconnectedRetrying => 'Mất kết nối, đang thử lại';

  @override
  String get sshStatusDisconnectedManual => 'Đã ngắt kết nối';

  @override
  String get sshStatusHostKeyChanged =>
      'Khóa máy chủ đã thay đổi — từ chối kết nối';

  @override
  String get sshKeepAliveNotificationTitle =>
      'Valhalla đang duy trì các phiên của bạn';

  @override
  String get terminalTmuxMissingNotice =>
      'Không tìm thấy tmux — các phiên sẽ không tồn tại khi bị ngắt kết nối';

  @override
  String get terminalTmuxSessionRestored => 'Đã khôi phục phiên terminal';

  @override
  String get moshSectionTitle => 'Mosh';

  @override
  String get moshEnable =>
      'Bật Mosh — terminal chuyển vùng duy trì qua các lần ngắt kết nối và đổi IP';

  @override
  String get moshServerPathLabel => 'Đường dẫn mosh-server';

  @override
  String get moshPortRangeLabel => 'Dải cổng UDP';

  @override
  String get moshNewSession => 'Phiên Mosh mới';

  @override
  String get moshNotInstalled =>
      'Không tìm thấy mosh-server trên máy chủ từ xa. Cài đặt bằng: sudo apt install mosh (Debian/Ubuntu) hoặc sudo dnf install mosh (Fedora/RHEL).';

  @override
  String moshBootstrapFailed(String detail) {
    return 'Khởi động phiên Mosh thất bại: $detail';
  }

  @override
  String get moshUdpTimeout =>
      'Kết nối Mosh đã hết thời gian — kiểm tra xem lưu lượng UDP có bị tường lửa chặn không.';

  @override
  String get moshSessionTag => 'mosh';

  @override
  String get acpSessionRestored => 'Đã khôi phục phiên agent';

  @override
  String get acpSessionRestartNotice =>
      'Đã khởi động lại phiên agent — ngữ cảnh trước đó không khả dụng';

  @override
  String get terminalTmuxInstallDialogTitle =>
      'Cài đặt tmux trên Máy chủ Từ xa?';

  @override
  String get terminalTmuxInstallDialogMessage =>
      'tmux là bắt buộc để duy trì các phiên terminal qua các lần ngắt kết nối. Bạn có muốn cài đặt ngay bây giờ?';

  @override
  String get terminalTmuxInstallCommandLabel => 'Lệnh thực thi:';

  @override
  String get terminalTmuxInstallUnsupported =>
      'Không phát hiện trình quản lý gói được hỗ trợ nào trên máy chủ từ xa. Vui lòng cài đặt tmux thủ công.';

  @override
  String get terminalTmuxInstallFailed =>
      'Cài đặt tmux thất bại. Vui lòng xác minh quyền máy chủ và mạng.';

  @override
  String get terminalTmuxInstallDisconnected =>
      'Mất kết nối SSH. Vui lòng kết nối lại để cài đặt tmux.';

  @override
  String get terminalTmuxInstallInstalling => 'Đang cài đặt tmux...';

  @override
  String get terminalTmuxInstallConfirm => 'Cài đặt tmux';

  @override
  String get terminalTmuxInstallSkip => 'Bỏ qua (Dùng Shell Thường)';

  @override
  String get sftpDownload => 'Tải xuống';

  @override
  String get sftpOpen => 'Mở';

  @override
  String get sftpUploadFailed => 'Tải lên thất bại. Kiểm tra quyền và thử lại.';

  @override
  String get sftpDownloadFailed => 'Tải xuống thất bại';

  @override
  String get sftpOpenUnsupported => 'Định dạng tệp này không thể mở được.';

  @override
  String get sftpReadFailed => 'Đọc tệp thất bại. Kiểm tra quyền và thử lại.';

  @override
  String get sftpTransferFailed => 'Thao tác tệp thất bại. Vui lòng thử lại.';

  @override
  String get sftpDownloadSuccess => 'Tải xuống thành công';

  @override
  String get sftpUploading => 'Đang tải lên...';

  @override
  String get sftpDownloading => 'Đang tải xuống...';

  @override
  String get sftpUpDirectory => 'Lên thư mục cha';

  @override
  String get sftpShowHiddenFiles => 'Hiện tệp ẩn';

  @override
  String get sftpHideHiddenFiles => 'Ẩn tệp ẩn';

  @override
  String get sftpHiddenPreferenceSaveFailed => 'Không thể lưu tùy chọn tệp ẩn';

  @override
  String get sftpSymlink => 'Liên kết tượng trưng';

  @override
  String get sftpLinkTargetUnavailable =>
      'Đích liên kết tượng trưng bị hỏng hoặc không khả dụng';

  @override
  String get sftpLinkTargetPermissionDenied =>
      'Bị từ chối quyền truy cập đích liên kết tượng trưng';

  @override
  String get settingsAutoConnect => 'Tự động kết nối khi khởi chạy';

  @override
  String get settingsAutoConnectFixed => 'SSH mặc định cố định';

  @override
  String get settingsAutoConnectFixedDesc =>
      'Luôn kết nối với máy chủ bạn chọn bên dưới';

  @override
  String get settingsAutoConnectLast => 'Ghi nhớ kết nối gần nhất';

  @override
  String get settingsAutoConnectLastDesc =>
      'Kết nối với máy chủ đã kết nối thành công gần nhất';

  @override
  String get settingsAutoConnectPickServer => 'Máy chủ';

  @override
  String get settingsAutoConnectNoServer => 'Chưa chọn máy chủ nào';

  @override
  String get sftpSort => 'Sắp xếp';

  @override
  String get sftpSortName => 'Tên';

  @override
  String get sftpSortSize => 'Kích thước';

  @override
  String get sftpSortDate => 'Ngày sửa đổi';

  @override
  String get sftpSortAscending => 'Tăng dần';

  @override
  String get sftpSortDescending => 'Giảm dần';

  @override
  String get themeQuickSwitch => 'Chủ đề';

  @override
  String get transferList => 'Truyền tệp';

  @override
  String get transferEmpty => 'Chưa có lượt truyền nào';

  @override
  String get transferUpload => 'Tải lên';

  @override
  String get transferDownload => 'Tải xuống';

  @override
  String get transferStatusQueued => 'Trong hàng đợi';

  @override
  String get transferStatusRunning => 'Đang truyền';

  @override
  String get transferStatusPaused => 'Đã tạm dừng';

  @override
  String get transferStatusCompleted => 'Đã hoàn thành';

  @override
  String get transferStatusFailed => 'Thất bại';

  @override
  String get transferStatusCanceled => 'Đã hủy';

  @override
  String get transferPause => 'Tạm dừng';

  @override
  String get transferResume => 'Tiếp tục';

  @override
  String get transferCancel => 'Hủy';

  @override
  String get transferRemove => 'Xóa';

  @override
  String get transferClearFinished => 'Xóa mục đã hoàn thành';

  @override
  String get transferSizeUnknown => 'Kích thước không xác định';

  @override
  String get transferFailedUpload => 'Tải lên thất bại';

  @override
  String get transferFailedDownload => 'Tải xuống thất bại';

  @override
  String get stopGeneration => 'Dừng';

  @override
  String get chatServerBindingRequired =>
      'Phiên này chưa được liên kết với máy chủ. Vui lòng liên kết với máy chủ hiện tại để tiếp tục.';

  @override
  String get chatSessionUnboundNotice =>
      'Phiên này không được liên kết với bất kỳ máy chủ nào.';

  @override
  String get bindServerAction => 'Liên kết máy chủ';

  @override
  String get bindServerDialogTitle => 'Liên kết phiên với máy chủ';

  @override
  String get bindServerConfirmAction => 'Xác nhận liên kết';

  @override
  String get chatSessionIdentityMismatch =>
      'Máy chủ hoặc agent hiện tại không khớp với danh tính đã liên kết của phiên này. Chuyển sang máy chủ và agent phù hợp để tiếp tục.';

  @override
  String get deleteSessionTitle => 'Xóa phiên';

  @override
  String get deleteSessionConfirmAction => 'Xóa';

  @override
  String get shareAgentSessionsTitle => 'Chia sẻ phiên Agent';

  @override
  String get shareAgentSessionsSubtitle =>
      'Chia sẻ phiên giữa các agent khác nhau trên máy chủ này';

  @override
  String get shareAgentSessionsEnabled => 'Đã bật chia sẻ phiên agent';

  @override
  String get shareAgentSessionsDisabled => 'Đã tắt chia sẻ phiên agent';

  @override
  String get agentCliStatusInstalled => 'CLI: Đã cài đặt';

  @override
  String get agentCliStatusMissing => 'CLI: Thiếu';

  @override
  String get agentCliStatusChecking => 'CLI: Đang kiểm tra...';

  @override
  String get agentCliStatusUnknown => 'CLI: Không xác định';

  @override
  String get agentCliStatusError => 'CLI: Lỗi';

  @override
  String get agentAcpStatusReady => 'ACP: Sẵn sàng';

  @override
  String get agentAcpStatusMissing => 'ACP: Thiếu';

  @override
  String get agentAcpStatusChecking => 'ACP: Đang kiểm tra...';

  @override
  String get agentAcpStatusPendingCli => 'ACP: Chờ CLI';

  @override
  String get agentAcpStatusUnknown => 'ACP: Không xác định';

  @override
  String get agentAcpStatusError => 'ACP: Lỗi';

  @override
  String get agentAcpStatusNa => 'ACP: N/A';

  @override
  String get agentAuthStatusAuthenticated => 'Xác thực: Đã đăng nhập';

  @override
  String get agentAuthStatusUnauthenticated => 'Xác thực: Chưa đăng nhập';

  @override
  String get agentAuthStatusUnknown => 'Xác thực: Không xác định';

  @override
  String get downloadNotificationsUnavailable =>
      'Thông báo tải xuống hệ thống không khả dụng. Quá trình tải xuống tiếp tục ở chế độ nền.';

  @override
  String get downloadOpenFailed => 'Không thể mở tệp đã tải xuống.';

  @override
  String get dockerActionPending =>
      'Một hành động đang được thực hiện cho container này';

  @override
  String get dockerNoLogs => '(Không có nhật ký)';

  @override
  String get serverReboot => 'Khởi động lại';

  @override
  String get serverRebootDialogTitle => 'Xác nhận khởi động lại máy chủ';

  @override
  String get serverRebootDialogMessage =>
      'Bạn có chắc chắn muốn khởi động lại máy chủ này? Tất cả các kết nối đang hoạt động và dịch vụ nền sẽ bị chấm dứt.';

  @override
  String get serverRebootConfirmButton => 'Khởi động lại ngay';

  @override
  String get serverRebootPasswordTitle => 'Yêu cầu mật khẩu Sudo';

  @override
  String get serverRebootPasswordMessage =>
      'Quyền root là bắt buộc để khởi động lại máy chủ. Vui lòng nhập mật khẩu sudo (dùng một lần, không lưu):';

  @override
  String get serverRebootPasswordHint => 'Mật khẩu Sudo';

  @override
  String get serverRebootSubmitting => 'Đang gửi lệnh khởi động lại...';

  @override
  String get serverRebootAccepted =>
      'Đã chấp nhận lệnh khởi động lại; việc hoàn tất chưa được xác minh. Vui lòng kết nối lại khi máy chủ trực tuyến trở lại.';

  @override
  String get serverRebootVerified =>
      'Đã xác minh khởi động lại máy chủ; hệ thống đã trực tuyến trở lại.';

  @override
  String get serverRebootUnknown =>
      'Kết quả khởi động lại không chắc chắn. Lệnh đã được gửi nhưng không thể xác nhận hoàn tất. Vui lòng kiểm tra kết nối thủ công.';

  @override
  String get serverRebootReconnect => 'Kết nối lại';

  @override
  String get serverRebootServerChanged =>
      'Máy chủ đích đã thay đổi, đã hủy khởi động lại';

  @override
  String get navCliChat => 'Trò chuyện CLI';

  @override
  String get cliChatTitle => 'Phiên CLI';

  @override
  String get cliChatSubtitle => 'Các phiên Agent CLI gốc trên máy chủ từ xa';

  @override
  String get cliSelectAgent => 'Chọn Agent';

  @override
  String get cliNoAgentsConfigured => 'Chưa thêm agent nào cho máy chủ này';

  @override
  String get cliAgentNeedsSetup =>
      'Môi trường agent bị thiếu hoặc chưa đăng nhập';

  @override
  String get cliManageAgentsGuide => 'Cấu hình trong Quản lý Agent';

  @override
  String get cliNewDraft => 'Bản nháp mới';

  @override
  String get cliNewDraftTooltip =>
      'Tạo bản nháp trống (phiên được tạo ở tin nhắn đầu tiên)';

  @override
  String get cliDeleteSessionTitle => 'Xóa lịch sử phiên CLI từ xa';

  @override
  String get cliDeleteSessionMessage =>
      'Thao tác này sẽ xóa vĩnh viễn lịch sử phiên CLI trên máy chủ từ xa. Bạn có chắc chắn muốn tiếp tục?';

  @override
  String get cliDeleteConfirmButton => 'Xóa phiên';

  @override
  String get cliCannotDeleteTooltip =>
      'Xóa phiên từ xa không được hỗ trợ hoặc bị tắt';

  @override
  String get cliSessionsHeader => 'Phiên';

  @override
  String get cliNoSessions => 'Không tìm thấy phiên CLI';

  @override
  String get cliFilterCwdHint => 'Lọc theo đường dẫn CWD...';

  @override
  String get cliFilterCwdAction => 'Lọc';

  @override
  String get cliClearCwdAction => 'Xóa';

  @override
  String get cliLoadMoreSessions => 'Tải thêm phiên';

  @override
  String get cliRefreshSessions => 'Làm mới';

  @override
  String get cliClaudeReadOnlyNotice =>
      'Lịch sử Claude là chỉ đọc. Tiếp tục cuộc trò chuyện trong terminal thực.';

  @override
  String get cliContinueInTerminal => 'Tiếp tục trong Terminal';

  @override
  String get cliOpenTerminal => 'Mở Terminal';

  @override
  String get cliCloseTerminal => 'Đóng Terminal';

  @override
  String get cliTerminalRunning => 'Terminal CLI tương tác';

  @override
  String get cliAgyTerminalOnlyNotice =>
      'Agent này không hỗ trợ đồng bộ hóa lịch sử có cấu trúc. Vui lòng sử dụng terminal CLI gốc để tương tác và chọn phiên.';

  @override
  String get cliInstallSdkTitle => 'Cài đặt SDK Lịch sử Claude chính thức';

  @override
  String get cliInstallSdkMessage =>
      'Claude Code History SDK chính thức bị thiếu trên máy chủ từ xa. Bạn có muốn cài đặt ngay bây giờ?';

  @override
  String get cliInstallSdkAction => 'Cài đặt SDK chính thức';

  @override
  String get cliApprovalsTitle => 'Phê duyệt đang chờ xử lý';

  @override
  String get cliApprovalDetails => 'Chi tiết';

  @override
  String get cliApprovalAllow => 'Cho phép';

  @override
  String get cliApprovalDecline => 'Từ chối';

  @override
  String get cliInputHint => 'Nhập tin nhắn cho agent CLI...';

  @override
  String get cliSend => 'Gửi';

  @override
  String get cliStop => 'Dừng';

  @override
  String get cliBusy => 'Thao tác đang diễn ra, vui lòng đợi...';

  @override
  String get cliDisconnected => 'SSH chưa kết nối';

  @override
  String get cliServerChanged => 'Máy chủ đích đã thay đổi';

  @override
  String get cliTurnFailed => 'Thực thi lượt CLI thất bại';

  @override
  String get cliUseTerminal =>
      'Yêu cầu lời nhắc tương tác, vui lòng mở terminal để tiếp tục';

  @override
  String get cliDeleteFailed => 'Không thể xóa phiên từ xa';

  @override
  String get cliDeleteUnsupported =>
      'Xóa phiên từ xa không được CLI này hỗ trợ';

  @override
  String get cliOperationFailed => 'Thao tác CLI thất bại';

  @override
  String get cliHistorySdkMissing =>
      'SDK Lịch sử chính thức bị thiếu trên máy chủ';

  @override
  String get cliHistoryRuntimeMissing =>
      'Lịch sử Claude yêu cầu Node.js/npm trên máy chủ. Vui lòng cài đặt Node.js thủ công; bạn vẫn có thể sử dụng CLI thực trong terminal.';

  @override
  String get cliLoginRequired =>
      'Yêu cầu đăng nhập agent. Vui lòng đăng nhập qua Quản lý Agent.';

  @override
  String get cliNotInstalled =>
      'Chưa cài đặt CLI agent. Vui lòng cài đặt qua Quản lý Agent.';

  @override
  String get cliVersionUnsupported =>
      'Phiên bản CLI agent không được hỗ trợ. Vui lòng nâng cấp hoặc cài đặt lại qua Quản lý Agent.';

  @override
  String get settingsNavigation => 'Điều hướng';

  @override
  String get settingsNavigationDesc =>
      'Cấu hình trang khởi động mặc định và thanh điều hướng dưới cùng';

  @override
  String get settingsStartupPage => 'Trang khởi động';

  @override
  String get settingsStartupPageDesc => 'Trang hiển thị khi mở ứng dụng';

  @override
  String get settingsBottomNav => 'Thanh điều hướng dưới cùng';

  @override
  String get settingsBottomNavDesc =>
      'Chọn các phần hiển thị trong thanh dưới cùng di động (hỗ trợ 0 đến 9 mục)';

  @override
  String get settingsResetSuccess => 'Đã khôi phục tất cả cài đặt về mặc định';

  @override
  String get metricsTrendSubtitle => '~3 phút gần đây (tối đa 60 mẫu)';

  @override
  String get metricsCurrent => 'Hiện tại';

  @override
  String get metricsPeak => 'Đỉnh';

  @override
  String get metricsValley => 'Đáy';

  @override
  String get metricsTrendWaiting => 'Đang thu thập dữ liệu số liệu...';

  @override
  String get metricsTrendStopped =>
      'Thu thập dữ liệu đã dừng (SSH ngắt kết nối)';

  @override
  String get dockerActionTerminal => 'Terminal Exec';

  @override
  String get dockerTerminalTitle => 'Terminal Container';

  @override
  String get dockerTerminalNotRunning => 'Container không chạy';

  @override
  String get setDefaultAgent => 'Đặt làm mặc định';

  @override
  String get defaultBadge => 'Mặc định';

  @override
  String get isDefaultAgent => 'Agent mặc định';

  @override
  String get setAsDefaultAgent => 'Đặt làm agent mặc định cho máy chủ này';

  @override
  String get agentGroupBasic => 'Thông tin cơ bản';

  @override
  String get agentGroupCommands => 'Lệnh';

  @override
  String get agentGroupAuth => 'Cài đặt & Xác thực';

  @override
  String get agentPresetTitle => 'Mẫu định sẵn';

  @override
  String get resourceProcessList => 'Tiến trình';

  @override
  String get resourceDiskScanning =>
      'Đang quét các thư mục gốc, có thể mất vài giây...';

  @override
  String get resourceDiskScanPartial =>
      'Một số thư mục không thể quét do quyền hoặc hết thời gian';

  @override
  String get resourceDiskDirectories => 'Mức sử dụng thư mục cấp cao nhất';

  @override
  String get resourceSortCpu => 'Sắp xếp theo CPU';

  @override
  String get resourceSortMemory => 'Sắp xếp theo Bộ nhớ';

  @override
  String get resourceRss => 'Bộ nhớ RSS';

  @override
  String get resourceUsed => 'Đã dùng';

  @override
  String get resourceAvailable => 'Khả dụng';

  @override
  String get resourceTotal => 'Tổng số';

  @override
  String get settingsBottomNavOrderTitle => 'Mục đã chọn (Kéo để sắp xếp lại)';

  @override
  String get langSystem => 'Theo hệ thống';

  @override
  String get serverFieldRequired => 'Bắt buộc';

  @override
  String get serverPortInvalid => 'Cổng phải từ 1 đến 65535';

  @override
  String get serverTestReachability => 'Kiểm tra khả năng tiếp cận';

  @override
  String get serverSaveFailedGeneric =>
      'Lưu máy chủ thất bại. Vui lòng kiểm tra cấu hình và thử lại.';

  @override
  String get serverViewPrivateKey => 'Xem khóa riêng tư';

  @override
  String get serverHidePrivateKey => 'Ẩn khóa riêng tư';

  @override
  String get dockerBashFallbackNotice =>
      'Bash không khả dụng trong container, chuyển sang Sh';

  @override
  String get dockerShellLabel => 'Shell';

  @override
  String get dockerShellBash => 'Bash';

  @override
  String get dockerShellSh => 'Sh';

  @override
  String get cliDraftWorkingDirLabel => 'Thư mục làm việc';

  @override
  String get cliDefaultWorkingDir => 'Mặc định (/)';

  @override
  String get cliPickWorkingDirTitle => 'Chọn thư mục làm việc';

  @override
  String get cliClearWorkingDir => 'Đặt lại về mặc định';

  @override
  String get cliBrowseWorkingDir => 'Duyệt';

  @override
  String get cliSelectCurrentDir => 'Chọn thư mục này';

  @override
  String get cliNavigateUp => 'Lên trên';

  @override
  String get chatSessionsTooltip => 'Phiên';

  @override
  String get hardwareSpecsTitle => 'Phần cứng & Hệ thống';

  @override
  String get hardwareCpu => 'CPU';

  @override
  String get hardwareMemory => 'Bộ nhớ';

  @override
  String get hardwareDisk => 'Đĩa gốc';

  @override
  String get hardwareDistribution => 'Hệ điều hành';

  @override
  String get hardwareKernel => 'Kernel';

  @override
  String get hardwareLoading => 'Đang tải thông số phần cứng...';

  @override
  String get hardwareUnavailable => 'Thông số phần cứng không khả dụng';

  @override
  String get hardwareUnknown => 'Không xác định';

  @override
  String get systemInfoTitle => 'Thông tin hệ thống';

  @override
  String get systemInfoTapHint => 'Nhấn để xem nghệ thuật ASCII';

  @override
  String get systemInfoHost => 'Máy chủ';

  @override
  String get serverShutdown => 'Tắt nguồn';

  @override
  String get serverShutdownDialogTitle => 'Xác nhận tắt máy chủ';

  @override
  String get serverShutdownDialogMessage =>
      'Bạn có chắc chắn muốn tắt máy chủ này? Hệ thống sẽ tắt hoàn toàn và không thể truy cập từ xa cho đến khi được bật thủ công.';

  @override
  String get serverShutdownConfirmButton => 'Tắt ngay';

  @override
  String get serverShutdownSubmitting => 'Đang gửi lệnh tắt nguồn...';

  @override
  String get serverShutdownAccepted =>
      'Đã chấp nhận lệnh tắt máy; việc tắt máy chưa được xác minh.';

  @override
  String get serverShutdownUnknown =>
      'Không rõ kết quả tắt máy: Lệnh có thể đã được gửi nhưng không thể xác nhận. Vui lòng kiểm tra thủ công; lệnh sẽ không tự động thử lại.';

  @override
  String get serverShutdownPasswordTitle =>
      'Yêu cầu mật khẩu Sudo để tắt nguồn';

  @override
  String get serverShutdownPasswordMessage =>
      'Quyền root là bắt buộc để tắt máy chủ. Vui lòng nhập mật khẩu sudo (dùng một lần, không lưu):';

  @override
  String get serverShutdownPasswordHint => 'Mật khẩu Sudo';

  @override
  String get serverShutdownServerChanged =>
      'Máy chủ đích đã thay đổi, đã hủy tắt nguồn';

  @override
  String get metricsNetwork => 'Tốc độ mạng';

  @override
  String get networkModalTitle => 'Chi tiết giao diện mạng';

  @override
  String get networkDownloadRate => 'Tải xuống (RX)';

  @override
  String get networkUploadRate => 'Tải lên (TX)';

  @override
  String get networkTotalRx => 'Tổng RX';

  @override
  String get networkTotalTx => 'Tổng TX';

  @override
  String get networkPrimary => 'Tuyến đường mặc định';

  @override
  String get networkRatesEmpty =>
      'Không phát hiện giao diện mạng nào đang hoạt động';

  @override
  String get networkWaitingSecondSample => 'Đang chờ mẫu thứ hai';

  @override
  String get networkUnavailable => 'Không khả dụng';

  @override
  String get networkNoDefaultInterface => 'Không có tuyến đường mặc định';

  @override
  String get selectThemeModeTitle => 'Chọn chế độ chủ đề';

  @override
  String get selectLanguageTitle => 'Chọn ngôn ngữ';

  @override
  String get selectStartupPageTitle => 'Chọn trang khởi động';

  @override
  String get selectAutoConnectModeTitle => 'Chọn chế độ tự động kết nối';

  @override
  String get accentColorDialogTitle => 'Tùy chỉnh màu nhấn';

  @override
  String get accentColorLightMode => 'Chế độ sáng';

  @override
  String get accentColorDarkMode => 'Chế độ tối';

  @override
  String get accentColorAmoledMode => 'AMOLED (Geek)';

  @override
  String get accentColorPresets => 'Mẫu sẵn';

  @override
  String get accentColorHsvPicker => 'Bánh xe màu';

  @override
  String get accentColorHexCode => 'Mã màu Hex';

  @override
  String get accentColorPreview => 'Xem trước';

  @override
  String get accentColorSampleButton => 'Nút mẫu nhấn';

  @override
  String get accentColorInvalidHex =>
      'Định dạng hex không hợp lệ (ví dụ: #10B981)';

  @override
  String get settingsDashboardQuickActions => 'Hành động nhanh bảng điều khiển';

  @override
  String get settingsDashboardQuickActionsDesc =>
      'Cấu hình các mục phím tắt nhanh hiển thị trên bảng điều khiển. Xóa sẽ ẩn phần hành động nhanh.';

  @override
  String get settingsDashboardQuickActionsEmpty =>
      'Hành động nhanh bị ẩn (chưa chọn phím tắt nào)';

  @override
  String get settingsDashboardQuickActionsOrderTitle =>
      'Kéo để sắp xếp lại phím tắt';

  @override
  String get settingsDashboardQuickActionsCandidates =>
      'Chọn phím tắt hiển thị';

  @override
  String get terminalCopySelection => 'Sao chép';

  @override
  String get terminalSelectionCopied =>
      'Đã sao chép vùng chọn vào khay nhớ tạm';

  @override
  String get editAgent => 'Chỉnh sửa Agent';

  @override
  String get agentExecutionTarget => 'Môi trường thực thi';

  @override
  String get agentExecutionHost => 'Hệ thống máy chủ';

  @override
  String get agentExecutionDocker => 'Container Docker';

  @override
  String get agentContainerBinding => 'Chế độ liên kết container';

  @override
  String get agentContainerBindingId => 'Theo ID Container';

  @override
  String get agentContainerBindingName => 'Theo Tên Container';

  @override
  String get agentContainerReference => 'Container đích';

  @override
  String get agentContainerReferenceHint =>
      'Chọn hoặc nhập ID hoặc tên container';

  @override
  String get agentContainerRequired =>
      'Container đích là bắt buộc đối với thực thi Docker';

  @override
  String get agentLoadingContainers =>
      'Đang truy vấn các container trên máy chủ...';

  @override
  String get agentNoContainersFound =>
      'Không tìm thấy container nào trên máy chủ này';

  @override
  String get agentContainerUser => 'Người dùng thực thi container (Tùy chọn)';

  @override
  String get agentContainerUserHint => 'ví dụ: dev';

  @override
  String get agentContainerUserHelper =>
      'Để trống để sử dụng người dùng mặc định của hình ảnh; ví dụ: dev; hỗ trợ user, UID, user:group, UID:GID';

  @override
  String get agentContainerUserSelect => 'Chọn người dùng container';

  @override
  String get agentContainerUsersLoading => 'Đang tải người dùng...';

  @override
  String get agentContainerUsersEmpty => 'Không tìm thấy người dùng passwd nào';

  @override
  String get agentViewDiagnosticLog => 'Xem nhật ký chẩn đoán';

  @override
  String get agentDiagnosticLogCopied =>
      'Đã sao chép nhật ký chẩn đoán vào khay nhớ tạm';

  @override
  String get agentDiagnosticLogCopy => 'Sao chép';

  @override
  String get agentDiagnosticLogClose => 'Đóng';

  @override
  String get settingsCliHistoryPageSize => 'Kích thước trang lịch sử CLI';

  @override
  String get settingsCliHistoryPageSizeDesc =>
      'Số lượng tin nhắn cũ được tải trên mỗi trang khi cuộn lên (5-100)';

  @override
  String get settingsCliHistoryPageSizeTitle =>
      'Chọn kích thước trang lịch sử CLI';

  @override
  String get cliLoadingOlderMessages => 'Đang tải tin nhắn cũ hơn...';

  @override
  String get chatLoadOlderMessages => 'Tải tin nhắn trước đó';

  @override
  String get chatCommandsTooltip => 'Lệnh';

  @override
  String get chatAttachTooltip => 'Đính kèm tệp';

  @override
  String get chatAttachImage => 'Đính kèm hình ảnh cục bộ';

  @override
  String get chatAttachLocalText => 'Đính kèm tệp văn bản cục bộ';

  @override
  String get chatAttachRemoteText => 'Đính kèm tệp văn bản từ xa';

  @override
  String get chatAttachRemotePathTitle => 'Đính kèm tệp văn bản từ xa';

  @override
  String get chatAttachRemotePathHint => '/duong/dan/tep.txt';

  @override
  String get chatAttachTooLarge => 'Tệp vượt quá giới hạn kích thước';

  @override
  String get chatUsageAndDiagnostics => 'Sử dụng & Chẩn đoán';

  @override
  String get chatWorkingDirTooltip => 'Thư mục làm việc của bản nháp';

  @override
  String get chatAttachFailed => 'Đính kèm tệp thất bại';

  @override
  String get chatInvalidRemotePath =>
      'Đường dẫn tệp từ xa không hợp lệ (phải bắt đầu bằng /)';

  @override
  String get chatRemoteReadFailed => 'Đọc tệp từ xa thất bại';

  @override
  String get chatInvalidDirPath =>
      'Đường dẫn thư mục không hợp lệ (phải bắt đầu bằng /)';

  @override
  String get chatNoSubdirectories => 'Không có thư mục con';

  @override
  String get chatUsageTitle => 'Sử dụng Token & Chi phí';

  @override
  String get chatUsageUsed => 'Token đã sử dụng';

  @override
  String get chatUsageSize => 'Kích thước ngữ cảnh';

  @override
  String get chatUsageCost => 'Chi phí';

  @override
  String get chatDiagnosticsTitle => 'Nhật ký chẩn đoán';

  @override
  String get chatNoDiagnostics => 'Không có nhật ký chẩn đoán nào khả dụng';

  @override
  String get deleteSessionLocalOnlyNotice =>
      'Thao tác này chỉ xóa bản ghi cục bộ trong Valhalla và sẽ không xóa lịch sử phiên agent gốc trên máy chủ.';

  @override
  String get chatSearchSessionsHint => 'Tìm kiếm phiên...';

  @override
  String get chatLoadMoreSessions => 'Tải thêm phiên';

  @override
  String get chatLoadingMoreSessions => 'Đang tải thêm phiên...';

  @override
  String get chatExportSession => 'Xuất phiên (Markdown)';

  @override
  String get chatExportSuccess => 'Xuất phiên thành công';

  @override
  String get chatExportFailed => 'Xuất phiên thất bại';

  @override
  String get chatRemoteSessions => 'Phiên từ xa';

  @override
  String get chatRemoteSessionsTitle => 'Phiên Agent từ xa';

  @override
  String get chatRemoteSessionsDesc =>
      'Xem và nhập lịch sử phiên gốc từ agent từ xa';

  @override
  String get chatRemoteSessionsEmpty => 'Không tìm thấy phiên từ xa';

  @override
  String get chatRemoteImporting => 'Đang nhập lịch sử phiên từ xa...';

  @override
  String get chatRemoteImportFailed => 'Nhập phiên từ xa thất bại';

  @override
  String get chatStatusInterrupted => 'Bị gián đoạn';

  @override
  String get chatStatusFailed => 'Thất bại';

  @override
  String get chatStatusAwaitingAuth => 'Đang chờ xác thực ACP';

  @override
  String get chatShowFullOutput => 'Hiển thị đầu ra đầy đủ';

  @override
  String get chatShowLessOutput => 'Hiển thị ít hơn';

  @override
  String get chatToolLocations => 'Đường dẫn bị ảnh hưởng';

  @override
  String cmdParamPlaceholder(String param) {
    return 'Nhập giá trị cho $param';
  }

  @override
  String processTerminateSuccess(Object pid) {
    return 'Đã chấm dứt tiến trình $pid';
  }

  @override
  String serviceActionSuccess(Object action, Object service) {
    return 'Hành động $action trên $service thành công';
  }

  @override
  String riskPatternMatched(Object pattern) {
    return 'Quy tắc được kích hoạt: $pattern';
  }

  @override
  String stateExitCode(Object code) {
    return 'Mã thoát: $code';
  }

  @override
  String sshConnectedSuccess(Object server) {
    return 'Đã kết nối thành công với $server qua SSH';
  }

  @override
  String sshConnectionFailed(Object error) {
    return 'Kết nối SSH thất bại: $error';
  }

  @override
  String trustHostFingerprintMessage(
    Object fingerprint,
    Object host,
    Object type,
  ) {
    return 'Kết nối với $host ($type) lần đầu tiên.\n\nDấu vân tay SHA-256:\n$fingerprint\n\nTin cậy dấu vân tay này và kết nối?';
  }

  @override
  String enterPasswordTitle(Object server) {
    return 'Nhập mật khẩu cho $server';
  }

  @override
  String confirmDeleteServerMessage(Object name) {
    return 'Bạn có chắc chắn muốn xóa máy chủ \'$name\'? Hành động này không thể hoàn tác.';
  }

  @override
  String deleteAgentMessage(Object name) {
    return 'Bạn có chắc chắn muốn xóa Agent \'$name\'? Thao tác này sẽ xóa cấu hình và trạng thái runtime của nó trên máy chủ này mà không ảnh hưởng đến các phiên trò chuyện lịch sử hoặc thông tin xác thực SSH.';
  }

  @override
  String agentLastChecked(Object time) {
    return 'Kiểm tra lần cuối: $time';
  }

  @override
  String agentAuthPickerTitle(Object agent) {
    return 'Chọn cách đăng nhập vào $agent';
  }

  @override
  String sshStatusReconnecting(Object n) {
    return 'Đang kết nối lại… (lần thử $n)';
  }

  @override
  String sshKeepAliveNotificationBody(Object n) {
    return '$n phiên đang hoạt động';
  }

  @override
  String bindServerConfirmMessage(Object serverName) {
    return 'Liên kết phiên này với máy chủ \"$serverName\"? Sau khi liên kết, phiên này sẽ được liên kết với máy chủ này.';
  }

  @override
  String deleteSessionConfirmMessage(Object title) {
    return 'Bạn có chắc chắn muốn xóa phiên \"$title\"? Hành động này không thể hoàn tác.';
  }

  @override
  String dockerActionSuccess(Object action, Object name) {
    return 'Hành động $action trên container $name thành công';
  }

  @override
  String dockerActionFailed(Object error) {
    return 'Hành động thất bại: $error';
  }

  @override
  String serverRebootTarget(Object address, Object name) {
    return 'Máy chủ đích: $name ($address)';
  }

  @override
  String serverRebootRunningTerminals(Object count) {
    return 'Phiên Terminal: $count';
  }

  @override
  String serverRebootRunningAgents(Object count) {
    return 'Phiên Agent: $count';
  }

  @override
  String serverRebootRunningTransfers(Object count) {
    return 'Lượt truyền đang hoạt động: $count';
  }

  @override
  String serverRebootFailed(Object error) {
    return 'Khởi động lại thất bại: $error';
  }

  @override
  String cliDeleteFailedWithDetail(Object detail) {
    return 'Không thể xóa phiên từ xa: $detail';
  }

  @override
  String metricsTrendTitle(Object metric) {
    return 'Xu hướng $metric';
  }

  @override
  String metricsThresholdWarning(Object value) {
    return 'Cảnh báo: $value';
  }

  @override
  String metricsThresholdDanger(Object value) {
    return 'Nguy hiểm: $value';
  }

  @override
  String metricsHistoryPoints(Object count) {
    return '$count điểm dữ liệu';
  }

  @override
  String resourceUsageTitle(Object metric) {
    return 'Sử dụng tài nguyên $metric';
  }

  @override
  String serverPortReachable(Object port) {
    return 'Cổng TCP $port có thể tiếp cận';
  }

  @override
  String serverConnectionFailed(Object error) {
    return 'Kết nối thất bại: $error';
  }

  @override
  String serverSaveFailed(Object error) {
    return 'Lưu máy chủ thất bại: $error';
  }

  @override
  String hardwareCpuCores(Object cores) {
    return '$cores Lõi';
  }

  @override
  String serverShutdownFailed(Object error) {
    return 'Tắt nguồn thất bại: $error';
  }

  @override
  String networkInterface(Object name) {
    return 'Giao diện: $name';
  }

  @override
  String agentContainersLoadFailed(Object error) {
    return 'Tải container thất bại: $error';
  }

  @override
  String agentContainerUsersFailed(Object error) {
    return 'Tải người dùng container thất bại: $error';
  }

  @override
  String agentDiagnosticLogTitle(Object name) {
    return 'Nhật ký chẩn đoán - $name';
  }

  @override
  String get agentDockerDetectionFailed =>
      'Phát hiện Docker/container thất bại';

  @override
  String get chatCopiedAllMessages => 'Đã sao chép tất cả tin nhắn';

  @override
  String get chatCopyAllMessages => 'Sao chép tất cả tin nhắn';

  @override
  String get cliModelAtCapacity =>
      'Mô hình đã chọn đã hết công suất. Hãy thử một mô hình khác.';

  @override
  String get chatLaunchBlankDraft => 'Bản nháp trống';

  @override
  String get chatLaunchFixedSession => 'Phiên cố định';

  @override
  String get chatLaunchRememberLast => 'Ghi nhớ phiên gần nhất';

  @override
  String get chatPermissionAskEveryTime => 'Hỏi mỗi lần';

  @override
  String get chatPermissionAutoAllowAll => 'Tự động cho phép tất cả';

  @override
  String get chatPermissionAutoAllowAllConfirmMessage =>
      'Agent sẽ thực thi tất cả các thao tác mà không cần hỏi. Tiếp tục?';

  @override
  String get chatPermissionAutoAllowAllConfirmTitle =>
      'Cho phép tất cả các thao tác?';

  @override
  String get chatPermissionAutoAllowSafe =>
      'Tự động cho phép các thao tác an toàn';

  @override
  String get chatRunSettingsDefault => 'Mặc định';

  @override
  String get chatRunSettingsInteractiveCli => 'CLI tương tác';

  @override
  String get chatRunSettingsModel => 'Mô hình';

  @override
  String get chatRunSettingsPermissions => 'Quyền';

  @override
  String get chatRunSettingsReasoning => 'Mức độ suy luận';

  @override
  String get chatRunSettingsTitle => 'Cài đặt chạy';

  @override
  String get cliActionInsertCommand => 'Chèn lệnh';

  @override
  String get cliActionInsertFile => 'Chèn tệp';

  @override
  String get cliActionInsertWorkdir => 'Chèn thư mục làm việc';

  @override
  String get cliComposerInsertAction => 'Chèn';

  @override
  String cliOperationFailedWithDetail(String detail) {
    return 'Thao tác CLI thất bại: $detail';
  }

  @override
  String get cliSelectCommandTitle => 'Chọn lệnh';

  @override
  String get defaultAgentTitle => 'Agent mặc định';

  @override
  String get insertSkills => 'Chèn kỹ năng';

  @override
  String get isDefaultSession => 'Phiên mặc định';

  @override
  String get sessionLaunchMode => 'Chế độ khởi chạy phiên';

  @override
  String get setAsDefaultSession => 'Đặt làm phiên mặc định';

  @override
  String get navNas => 'Media NAS';

  @override
  String get nasAddExcludePath => 'Thêm đường dẫn loại trừ';

  @override
  String get nasAddIncludePath => 'Thêm đường dẫn quét';

  @override
  String get nasCancelScan => 'Hủy quét';

  @override
  String get nasClearSearch => 'Xóa tìm kiếm';

  @override
  String get nasConfigDialogTitle => 'Cài đặt thư viện phương tiện';

  @override
  String get nasConfigure => 'Cấu hình';

  @override
  String get nasConfigureScanDirs => 'Cấu hình thư mục quét';

  @override
  String get nasCreatePlaylist => 'Tạo danh sách phát';

  @override
  String get nasEmptyConfigDesc =>
      'Thêm ít nhất một thư mục để bắt đầu xây dựng thư viện phương tiện của bạn.';

  @override
  String get nasEmptyConfigTitle => 'Chưa cấu hình thư mục quét';

  @override
  String get nasExcludePaths => 'Thư mục bị loại trừ';

  @override
  String get nasExcludedBadge => 'Bị loại trừ';

  @override
  String get nasFilterImages => 'Hình ảnh';

  @override
  String get nasFilterVideos => 'Video';

  @override
  String get nasIncludePaths => 'Thư mục quét';

  @override
  String nasItemCount(Object value) {
    return '$value mục';
  }

  @override
  String nasLastScan(Object value) {
    return 'Quét lần cuối: $value';
  }

  @override
  String get nasLibrarySettings => 'Cài đặt thư viện';

  @override
  String nasMediaOpening(Object value) {
    return 'Đang mở $value…';
  }

  @override
  String get nasMiniPlayer => 'Trình phát thu nhỏ';

  @override
  String get nasNoExcludePaths => 'Không có thư mục bị loại trừ';

  @override
  String get nasNoFavorites => 'Chưa có mục yêu thích nào';

  @override
  String get nasNoIncludePaths => 'Không có thư mục quét';

  @override
  String get nasNoIndexDesc =>
      'Cấu hình thư mục và chạy quét để lập chỉ mục phương tiện của bạn.';

  @override
  String get nasNoIndexTitle => 'Thư viện phương tiện trống';

  @override
  String get nasNoPlaylists => 'Chưa có danh sách phát nào';

  @override
  String get nasNoSearchResults => 'Không có phương tiện phù hợp';

  @override
  String get nasNotScanned => 'Chưa quét';

  @override
  String get nasNowPlaying => 'Đang phát';

  @override
  String get nasOpenMethodPrompt => 'Bạn muốn mở tệp này như thế nào?';

  @override
  String get nasOpenPolicyAsk => 'Hỏi mỗi lần';

  @override
  String get nasOpenPolicyExternal => 'Mở bằng ứng dụng khác';

  @override
  String get nasOpenPolicyInApp => 'Mở trong ứng dụng';

  @override
  String get nasOpeningPolicy => 'Phương thức mở mặc định';

  @override
  String get nasPlaylistName => 'Tên danh sách phát';

  @override
  String get nasQuickStats => 'Tổng quan thư viện';

  @override
  String get nasScan => 'Quét ngay';

  @override
  String get nasScanCancelled => 'Đã hủy quét';

  @override
  String nasScanFailed(Object value) {
    return 'Quét thất bại: $value';
  }

  @override
  String get nasScanning => 'Đang quét…';

  @override
  String get nasScopeBadge => 'Phạm vi quét';

  @override
  String get nasSearchHint => 'Tìm kiếm phương tiện';

  @override
  String get nasStatMusic => 'Nhạc';

  @override
  String get nasStatPhotos => 'Ảnh';

  @override
  String get nasStatTotal => 'Tổng số';

  @override
  String get nasStatVideos => 'Video';

  @override
  String get nasTabFavorites => 'Yêu thích';

  @override
  String get nasTabFolders => 'Thư mục';

  @override
  String get nasTabHome => 'Trang chủ';

  @override
  String get nasTabMusic => 'Nhạc';

  @override
  String get nasTabPhotos => 'Ảnh';

  @override
  String get nasTabPlaylists => 'Danh sách phát';

  @override
  String get nasTabVideos => 'Video';

  @override
  String get nasSources => 'Nguồn phương tiện';

  @override
  String get nasAddSource => 'Thêm nguồn phương tiện';

  @override
  String get nasEditSource => 'Chỉnh sửa nguồn phương tiện';

  @override
  String get nasRemoveSource => 'Xóa nguồn phương tiện';

  @override
  String nasRemoveSourceConfirm(Object name) {
    return 'Bạn có chắc chắn muốn xóa nguồn phương tiện \'$name\'? Thao tác này sẽ xóa cấu hình của nó mà không xóa các tệp từ xa.';
  }

  @override
  String get nasNoSources => 'Chưa cấu hình nguồn phương tiện';

  @override
  String get nasNoSourcesDesc =>
      'Thêm SFTP, SMB, WebDAV, Jellyfin hoặc Emby để bắt đầu duyệt phương tiện.';

  @override
  String get nasSourceType => 'Loại nguồn';

  @override
  String get nasSourceName => 'Tên nguồn';

  @override
  String get nasProbe => 'Kiểm tra kết nối';

  @override
  String get nasProbeSuccess => 'Kết nối thành công';

  @override
  String get nasProbeFailed => 'Kiểm tra kết nối thất bại';

  @override
  String get nasEndpoint => 'Điểm cuối / URL';

  @override
  String get nasRootPath => 'Đường dẫn gốc';

  @override
  String get nasUsername => 'Tên người dùng';

  @override
  String get nasPassword => 'Mật khẩu';

  @override
  String get nasDomain => 'Miền (tùy chọn)';

  @override
  String get nasAuthenticate => 'Xác thực';

  @override
  String get nasAuthSuccess => 'Xác thực thành công';

  @override
  String get nasAuthFailed => 'Xác thực thất bại';

  @override
  String get nasTabDownloads => 'Tải xuống';

  @override
  String get nasNoDownloads => 'Không có tác vụ tải xuống';

  @override
  String get nasDownloadQueued => 'Trong hàng đợi';

  @override
  String get nasDownloadDownloading => 'Đang tải xuống';

  @override
  String get nasDownloadCompleted => 'Đã hoàn thành';

  @override
  String get nasDownloadCancelled => 'Đã hủy';

  @override
  String get nasDownloadFailed => 'Tải xuống thất bại';

  @override
  String get nasRetryDownload => 'Thử lại';

  @override
  String get nasCancelDownload => 'Hủy';

  @override
  String get nasOpenDownloadedFile => 'Mở tệp';

  @override
  String get nasQueue => 'Hàng đợi phát';

  @override
  String get nasNoQueue => 'Hàng đợi trống';

  @override
  String get nasSpeed => 'Tốc độ';

  @override
  String get nasQuality => 'Chất lượng';

  @override
  String get nasAudioTrack => 'Bản âm thanh';

  @override
  String get nasSubtitleTrack => 'Phụ đề';

  @override
  String get nasRepeatOff => 'Tắt lặp lại';

  @override
  String get nasRepeatAll => 'Lặp lại tất cả';

  @override
  String get nasRepeatOne => 'Lặp lại một bài';

  @override
  String get nasShuffle => 'Xáo trộn';

  @override
  String get nasCast => 'Truyền (Cast)';

  @override
  String get nasCastUnavailable => 'Không có thiết bị truyền khả dụng';

  @override
  String get nasSlideshow => 'Trình chiếu';

  @override
  String get nasByFolder => 'Thư mục';

  @override
  String get nasByArtist => 'Nghệ sĩ';

  @override
  String get nasByAlbum => 'Album';

  @override
  String get nasAllTracks => 'Tất cả bài hát';

  @override
  String get nasPlayAll => 'Phát tất cả';

  @override
  String get nasPreviousPage => 'Trước';

  @override
  String get nasNextPage => 'Tiếp theo';

  @override
  String get nasClearScope => 'Quay lại tất cả';

  @override
  String get nasRenamePlaylist => 'Đổi tên danh sách phát';

  @override
  String get nasRemoveFromPlaylist => 'Xóa khỏi danh sách phát';

  @override
  String get nasMoveUp => 'Di chuyển lên';

  @override
  String get nasMoveDown => 'Di chuyển xuống';

  @override
  String get nasSshServer => 'Máy chủ SSH';

  @override
  String get nasSelectSshServer => 'Chọn máy chủ SSH đã lưu';

  @override
  String get nasQualityOriginal => 'Gốc';

  @override
  String get nasQualityAuto => 'Tự động';

  @override
  String get nasQuality4Mbps => '4 Mbps';

  @override
  String get nasQuality10Mbps => '10 Mbps';

  @override
  String get nasQuality20Mbps => '20 Mbps';

  @override
  String get nasCastDevices => 'Thiết bị DLNA khả dụng';

  @override
  String get nasCastDiscovering => 'Đang tìm kiếm thiết bị DLNA...';

  @override
  String get nasCastRelayingNotice =>
      'Đang chuyển tiếp luồng qua ứng dụng nền trước. Hãy mở Valhalla.';

  @override
  String get nasCastStop => 'Dừng truyền';

  @override
  String get nasCastVolume => 'Âm lượng';

  @override
  String get nasCastRetry => 'Thử tìm kiếm lại';

  @override
  String get nasInstallTitle => 'Triển khai Máy chủ Phương tiện NAS';

  @override
  String get nasInstallProduct => 'Sản phẩm';

  @override
  String get nasInstallMediaPath => 'Thư mục Phương tiện (Chỉ đọc)';

  @override
  String get nasInstallDataRoot => 'Thư mục Dữ liệu & Cấu hình';

  @override
  String get nasInstallPort => 'Cổng';

  @override
  String get nasInstallBindAddress => 'Địa chỉ liên kết';

  @override
  String get nasInstallWebdavUser => 'Tên người dùng WebDAV';

  @override
  String get nasInstallWebdavPassword => 'Mật khẩu WebDAV (tối thiểu 12 ký tự)';

  @override
  String get nasInstallPreparePlan => 'Xem lại Kế hoạch Triển khai';

  @override
  String get nasInstallPlanTitle => 'Đánh giá Kỹ thuật & Xác nhận';

  @override
  String get nasInstallBlockersTitle => 'Yếu tố cản trở triển khai';

  @override
  String get nasInstallConfirmDeploy => 'Xác nhận & Cài đặt';

  @override
  String get nasInstallDeploying => 'Đang triển khai container...';

  @override
  String get nasInstallSuccess => 'Triển khai Thành công';

  @override
  String get nasInstallSuccessDesc =>
      'Dịch vụ hiện đang chạy. Hoàn tất thiết lập ban đầu của máy chủ trước khi thêm làm nguồn phương tiện.';

  @override
  String get nasInstallContainerId => 'ID Container';

  @override
  String get nasInstallEndpoint => 'Điểm cuối';

  @override
  String get nasUseSshTunnel => 'Sử dụng Đường hầm SSH';

  @override
  String get nasUseSshTunnelDesc =>
      'Định tuyến lưu lượng qua máy chủ SSH đã lưu (ví dụ: http://127.0.0.1:8096)';

  @override
  String get nasSshTunnelHint =>
      'Điểm cuối phải có thể truy cập được từ máy chủ SSH, ví dụ: http://127.0.0.1:8096';

  @override
  String get nasKeepEmptyPassword =>
      'Để trống để giữ mật khẩu / token hiện tại';

  @override
  String get nasSourceNameRequired => 'Tên nguồn là bắt buộc';

  @override
  String get nasInvalidEndpoint => 'URL hoặc giao thức điểm cuối không hợp lệ';

  @override
  String get nasSourceUnreachable => 'Không thể tiếp cận nguồn phương tiện';

  @override
  String get nasSshTunnelFailed => 'Kết nối đường hầm SSH thất bại';

  @override
  String get nasOperationFailed => 'Thao tác thất bại';

  @override
  String get nasInstallStepCreateDir => 'Tạo thư mục riêng tư';

  @override
  String get nasInstallStepWriteCompose => 'Ghi cấu hình docker-compose.json';

  @override
  String get nasInstallStepWriteCreds => 'Ghi thông tin xác thực riêng tư';

  @override
  String get nasInstallStepPullImage => 'Kéo hình ảnh container đã ghim';

  @override
  String get nasInstallStepStartService => 'Khởi động dịch vụ trong container';

  @override
  String get nasInstallStepCheckHttp => 'Kiểm tra tình trạng HTTP của dịch vụ';

  @override
  String get nasInstallBlockerDocker =>
      'Docker Engine là bắt buộc trên máy chủ đích';

  @override
  String get nasInstallBlockerCompose => 'Plugin Docker Compose là bắt buộc';

  @override
  String get nasInstallBlockerIdentity =>
      'Không thể xác minh danh tính máy chủ đích';

  @override
  String get nasInstallBlockerTools =>
      'Các công cụ cần thiết (curl, ss, realpath) bị thiếu trên máy chủ đích';

  @override
  String get nasInstallBlockerMedia =>
      'Thư mục phương tiện không tồn tại hoặc không thể đọc';

  @override
  String get nasInstallBlockerParent =>
      'Thư mục cha của gốc dữ liệu không có quyền ghi';

  @override
  String get nasInstallBlockerOverlap =>
      'Thư mục phương tiện và thư mục dữ liệu không thể trùng nhau';

  @override
  String get nasInstallBlockerCollision =>
      'Thư mục dữ liệu đích đã tồn tại hoặc là liên kết tượng trưng';

  @override
  String get nasInstallBlockerPort =>
      'Cổng đã chọn đang được sử dụng trên máy chủ đích';

  @override
  String get nasInstallBlockerContainer =>
      'Một container với tên dự án này đã tồn tại';

  @override
  String get nasInstallBlockerImage =>
      'Xác minh hình ảnh container thất bại. Kiểm tra tên hình ảnh, kết nối mạng và kiến trúc máy chủ, sau đó thử lại.';

  @override
  String get nasInstallGuidanceTunnel =>
      'Liên kết loopback (127.0.0.1) yêu cầu đường hầm SSH để truy cập từ xa';

  @override
  String get nasInstallGuidanceTls =>
      'Khuyến nghị bảo mật liên kết công khai đằng sau reverse proxy TLS';

  @override
  String get nasInstallGuidanceSetup =>
      'Hoàn tất thiết lập tài khoản quản trị ban đầu trong trình duyệt ở lần khởi chạy đầu tiên';

  @override
  String get nasInstallGuidanceReadOnly =>
      'Thư mục phương tiện được gắn ở chế độ chỉ đọc để bảo vệ tệp của bạn';

  @override
  String get nasInstallGuidancePreserved =>
      'Thư mục dữ liệu sẽ được giữ lại khi xảy ra sự cố để khắc phục';

  @override
  String get nasDownloadCompletedWithOpenError =>
      'Đã tải xuống (Không thể mở bằng ứng dụng ngoài)';

  @override
  String get nasRetryOpen => 'Thử mở lại';

  @override
  String get nasExternalOpenFailed => 'Không thể mở tệp trong ứng dụng ngoài';

  @override
  String get nasTitle => 'Media NAS';

  @override
  String get nasLoadMoreGroups => 'Tải thêm nhóm';

  @override
  String get nasMetadataEnriching => 'Đang làm phong phú thẻ nhạc...';

  @override
  String nasMetadataEnrichingWithCount(int count) {
    return 'Đang làm phong phú thẻ nhạc (đã xử lý $count)...';
  }

  @override
  String nasDownloading(String value) {
    return 'Đang tải xuống $value…';
  }

  @override
  String get nasSubtitleNone => 'Không có';

  @override
  String get nasLibraryId => 'ID Thư viện';

  @override
  String get nasLibraryIdHint =>
      'Mặc định: tất cả (/), hoặc chỉ định ID thư viện';

  @override
  String nasScanPathRelativeHint(String value) {
    return 'Tương đối với gốc nguồn ($value)';
  }

  @override
  String get nasSourceChangedError =>
      'Nguồn đã thay đổi trong khi cấu hình, đã hủy lưu';

  @override
  String get nasInvalidLibraryId => 'ID thư viện không hợp lệ';

  @override
  String get startupFailed => 'Ứng dụng khởi động thất bại';

  @override
  String get startupFailedDesc =>
      'Đã xảy ra lỗi không mong muốn trong khi khởi động. Bạn có thể thử lại hoặc xuất nhật ký chẩn đoán.';

  @override
  String get retryStartup => 'Thử khởi động lại';

  @override
  String get viewDiagnostics => 'Xem chẩn đoán';

  @override
  String get exportDiagnostics => 'Xuất chẩn đoán';

  @override
  String diagnosticsExportSuccess(String path) {
    return 'Đã xuất chẩn đoán ra $path';
  }

  @override
  String get diagnosticsExportFailed => 'Xuất chẩn đoán thất bại';

  @override
  String get diagnosticsTitle => 'Chẩn đoán ứng dụng';

  @override
  String get settingsDiagnostics => 'Chẩn đoán & Nhật ký';

  @override
  String get settingsDiagnosticsDesc =>
      'Xem và xuất nhật ký ứng dụng cục bộ đã được làm sạch';

  @override
  String get diagnosticsEmpty => 'Không tìm thấy bản ghi chẩn đoán nào';

  @override
  String diagnosticsStorageError(String error) {
    return 'Lỗi lưu trữ chẩn đoán: $error';
  }

  @override
  String diagnosticsIncidentNotice(String category) {
    return 'Đã báo cáo sự cố có thể khôi phục: $category';
  }

  @override
  String get diagnosticsRefresh => 'Làm mới nhật ký';

  @override
  String get nasInstallTaskTitle => 'Nhiệm vụ Triển khai';

  @override
  String get nasInstallStagePreflight => 'Kiểm tra trước';

  @override
  String get nasInstallStageReview => 'Đánh giá kế hoạch';

  @override
  String get nasInstallStageWriting => 'Ghi cấu hình';

  @override
  String get nasInstallStagePulling => 'Kéo hình ảnh';

  @override
  String get nasInstallStageStarting => 'Khởi động container';

  @override
  String get nasInstallStageHealth => 'Kiểm tra sức khỏe';

  @override
  String get nasInstallStageCleanup => 'Đang dọn dẹp';

  @override
  String get nasInstallStageSucceeded => 'Triển khai Thành công';

  @override
  String get nasInstallStageFailed => 'Triển khai Thất bại';

  @override
  String get nasInstallStageCancelled => 'Triển khai Đã hủy';

  @override
  String get nasInstallStageNeedsInspection => 'Cần kiểm tra';

  @override
  String get nasInstallStageReconciling => 'Đang đối chiếu trạng thái';

  @override
  String get nasInstallCancel => 'Hủy triển khai';

  @override
  String get nasInstallReconcile => 'Đối chiếu trạng thái';

  @override
  String get nasInstallServerNotFound => 'Không tìm thấy máy chủ đã chọn';

  @override
  String get nasInstallPortRangeError => 'Cổng phải từ 1 đến 65535';

  @override
  String nasInstallElapsedTime(String time) {
    return 'Đã qua: $time';
  }

  @override
  String get nasInstallLogTail => 'Nhật ký gần đây';

  @override
  String get nasInstallCleanupCompleted => 'Dọn dẹp khôi phục hoàn tất';

  @override
  String get nasInstallCleanupIncomplete => 'Dọn dẹp khôi phục chưa hoàn tất';

  @override
  String get nasInstallNewDeployment => 'Triển khai Mới';

  @override
  String get nasInstallBackEdit => 'Quay lại / Chỉnh sửa biểu mẫu';

  @override
  String get nasInstallClose => 'Đóng';

  @override
  String get nasInstallMediaPathHint =>
      'Gắn kết chỉ đọc trên máy chủ (ví dụ: /mnt/media)';

  @override
  String get nasInstallDataRootHint =>
      'Thư mục dữ liệu & cấu hình riêng tư (chưa được tồn tại)';

  @override
  String get nasInstallBindAddressHint =>
      '127.0.0.1 cho đường hầm, 0.0.0.0 cho mạng LAN';

  @override
  String get nasInstallWebdavPasswordHint => 'Yêu cầu tối thiểu 12 ký tự';

  @override
  String get nasInstallTargetServer => 'Máy chủ đích';

  @override
  String get nasInstallTargetImage => 'Hình ảnh đích';

  @override
  String get nasInstallContainerName => 'Tên container';

  @override
  String get nasInstallBindAndPort => 'Liên kết & Cổng';

  @override
  String get nasInstallComposePreview => 'Xem trước docker-compose.json';

  @override
  String get nasInstallPlannedSteps => 'Các bước đã lên kế hoạch';

  @override
  String get nasInstallGuidanceNotes => 'Ghi chú & Hướng dẫn Triển khai';

  @override
  String get nasInstallNoLogsYet => 'Chưa có nhật ký nào';

  @override
  String get sftpPreviewTooLarge =>
      'Tệp vượt quá giới hạn xem trước 1 MiB. Vui lòng tải xuống và mở bên ngoài.';

  @override
  String get sftpSaveFailed =>
      'Lưu tệp thất bại. Kiểm tra quyền hoặc kết nối mạng.';

  @override
  String get sftpSaving => 'Đang lưu...';

  @override
  String get nasInstallBlockerConnectionChanged =>
      'Kết nối máy chủ đích đã thay đổi; xác minh trạng thái từ xa trước khi tiếp tục';

  @override
  String get nasInstallBlockerCancelled =>
      'Triển khai đã bị hủy bởi người dùng. Xem lại cài đặt và thử lại nếu cần.';

  @override
  String get nasInstallBlockerInspectFailed =>
      'Kiểm tra không thể truy vấn container từ xa. Kiểm tra kết nối máy chủ hoặc kiểm tra thủ công.';

  @override
  String get nasInstallBlockerDeadlineExceeded =>
      'Bước triển khai đã hết thời gian. Kiểm tra tải máy chủ hoặc kết nối mạng và thử lại.';

  @override
  String get nasInstallBlockerInterrupted =>
      'Triển khai đã bị gián đoạn; xem lại trạng thái từ xa trước khi tiếp tục.';

  @override
  String get nasInstallBlockerHealthTimeout =>
      'Dịch vụ đã bắt đầu nhưng kiểm tra tình trạng HTTP đã hết thời gian. Xác minh nhật ký dịch vụ hoặc tính khả dụng của cổng.';

  @override
  String get nasInstallBlockerReconciliationFailed =>
      'Đối chiếu thất bại. Xác minh trạng thái container từ xa thủ công hoặc bắt đầu triển khai mới.';

  @override
  String get nasInstallBlockerRemoteInspectionRequired =>
      'Trạng thái container từ xa không chắc chắn. Cần kiểm tra và đối chiếu thủ công.';

  @override
  String get nasInstallBlockerServiceExited =>
      'Tiến trình container đã thoát sớm. Kiểm tra nhật ký xem có lỗi cấu hình hoặc quyền không.';

  @override
  String get nasInstallBlockerWriteFailed =>
      'Không thể ghi tệp triển khai trên máy chủ đích. Kiểm tra dung lượng đĩa và quyền.';

  @override
  String get nasInstallBlockerPlanStale =>
      'Kế hoạch triển khai đã cũ. Vui lòng chạy lại các bước kiểm tra trước.';

  @override
  String get nasInstallBlockerOwnershipChanged =>
      'Container hiện có không được tạo bởi ứng dụng này. Kiểm tra thủ công để tránh ghi đè.';

  @override
  String get nasInstallBlockerSshRequired =>
      'Yêu cầu kết nối SSH đang hoạt động tới máy chủ đích.';

  @override
  String get nasInstallBlockerReconciliationRequired =>
      'Trạng thái từ xa khác với trạng thái cục bộ. Vui lòng đối chiếu trước khi tiếp tục.';

  @override
  String get nasInstallBlockerFailed =>
      'Triển khai gặp lỗi. Kiểm tra nhật ký và thử lại.';

  @override
  String get nasInstallBlockerBusy =>
      'Một nhiệm vụ cài đặt đang được tiến hành. Vui lòng kiểm tra tiến trình nhiệm vụ hiện tại.';

  @override
  String get nasInstallBlockerStateSaveFailed =>
      'Không thể lưu giữ trạng thái triển khai. Vui lòng kiểm tra dung lượng lưu trữ cục bộ và quyền tệp.';

  @override
  String get nasInstallBlockerCommandResultUnknown =>
      'Kết quả lệnh từ xa không xác định. Vui lòng chạy kiểm tra chỉ đọc thay vì thử lại triển khai trực tiếp.';

  @override
  String get nasInstallBlockerPreflightFailed =>
      'Kiểm tra môi trường trước khi triển khai thất bại. Vui lòng giải quyết các vấn đề cản trở trước khi tiếp tục.';

  @override
  String serverDeleteFailed(String error) {
    return 'Xóa máy chủ thất bại: $error';
  }

  @override
  String get chatRunSettingsAgentMode => 'Chế độ Agent';

  @override
  String get chatRunSettingsApprovalPolicy => 'Chính sách phê duyệt cục bộ';

  @override
  String get chatRunSettingsExtraSettings => 'Cài đặt bổ sung';

  @override
  String get chatPermissionAutoAllowSafeDesc =>
      'Tự động cho phép các thao tác được xác định là an toàn; hỏi bất cứ khi nào không thể xác định độ an toàn của thao tác.';

  @override
  String chatRunSettingsSaveFailed(String error) {
    return 'Áp dụng cài đặt chạy thất bại: $error';
  }

  @override
  String get chatMessageCopied => 'Đã sao chép tin nhắn vào khay nhớ tạm';

  @override
  String get copy => 'Sao chép';

  @override
  String get rename => 'Đổi tên';

  @override
  String get refresh => 'Làm mới';

  @override
  String get sessionTitle => 'Tiêu đề phiên';

  @override
  String get chatSettingsStale => 'Cũ';

  @override
  String get chatSettingsAvailableAfterFirstMessage =>
      'Cài đặt khả dụng sau tin nhắn đầu tiên';

  @override
  String get chatReimportAsCopy => 'Nhập lại dưới dạng bản sao';

  @override
  String get chatSearchCommandsHint => 'Tìm kiếm lệnh hoặc kỹ năng...';

  @override
  String get chatCommandsTab => 'Lệnh';

  @override
  String get chatSkillsTab => 'Kỹ năng';

  @override
  String get chatAccountAndQuotaTitle => 'Tài khoản & Hạn mức';

  @override
  String get chatAccountSectionTitle => 'Tài khoản';

  @override
  String get chatAccountNotProvided =>
      'Không có chi tiết tài khoản nào được báo cáo';

  @override
  String get chatAccountKind => 'Loại';

  @override
  String get chatAccountLabel => 'Nhãn';

  @override
  String get chatAccountPlan => 'Gói';

  @override
  String get chatAccountEmail => 'Email';

  @override
  String get chatAccountUpdatedAt => 'Đã cập nhật';

  @override
  String get chatQuotaSectionTitle => 'Hạn mức & Trạng thái';

  @override
  String get chatStatusSourceNote => 'Đầu ra /status thô của Agent';

  @override
  String get chatStatusNotQueried => 'Chưa truy vấn trạng thái';

  @override
  String get chatQueryStatusAction => 'Truy vấn trạng thái (/status)';

  @override
  String get chatQueryStatusUnavailable =>
      'Truy vấn trạng thái không khả dụng trong phiên hiện tại';

  @override
  String get chatAttachmentMissing =>
      'Tệp đính kèm bị thiếu hoặc không khả dụng';

  @override
  String get chatViewModeList => 'Danh sách';

  @override
  String get chatViewModeCards => 'Thẻ';

  @override
  String get chatViewModeGrid => 'Hình ảnh';

  @override
  String get chatRemoteBrowserTitle => 'Không gian làm việc từ xa';

  @override
  String get chatSelectDirectory => 'Chọn thư mục';

  @override
  String chatAttachSelectedFiles(int count) {
    return 'Đính kèm mục đã chọn ($count)';
  }

  @override
  String get chatNoFilesFound => 'Không tìm thấy tệp nào';

  @override
  String get chatRootDirectory => 'Gốc';

  @override
  String get chatSelectThisDirectory => 'Sử dụng thư mục này';

  @override
  String get chatAgentVersion => 'Phiên bản Agent';

  @override
  String get chatParentDirectory => 'Thư mục cha';

  @override
  String get chatSearchFilesHint => 'Tìm kiếm tệp...';

  @override
  String get chatCommandsEmpty => 'Không có lệnh slash nào do agent cung cấp';

  @override
  String get chatSkillsEmpty => 'Không có kỹ năng nào do agent cung cấp';

  @override
  String get chatFileUnsupported => 'Loại tệp không được hỗ trợ để đính kèm';

  @override
  String get chatStatusNotProvided =>
      'Truy vấn trạng thái không được agent cung cấp';

  @override
  String get sessionRecoveryReconnecting => 'Đang kết nối lại...';

  @override
  String get sessionRecoverySyncing => 'Đang đồng bộ hóa đầu ra...';

  @override
  String get sessionRecoveryIncomplete => 'Một số đầu ra không thể khôi phục';

  @override
  String get sessionRecoveryFailed => 'Khôi phục thất bại';

  @override
  String get sessionRecoveryRetry => 'Thử lại';

  @override
  String get dashboardUpdatesPaused => 'Đã tạm dừng cập nhật';

  @override
  String get chatSettingsIndependentModelUnavailable =>
      'Danh mục mô hình CLI hiện không khả dụng. Các mô hình có thể được lưu vào bộ nhớ đệm hoặc bị giới hạn bởi phiên bản CLI; bạn cũng có thể nhập tên mô hình thủ công.';

  @override
  String get chatSettingsModelCatalogNote =>
      'Các mô hình được truy vấn từ app-server CLI bằng đăng nhập CLI hiện tại của bạn. Danh mục có thể được lưu trữ tạm thời hoặc giới hạn phiên bản; bạn có thể làm mới thủ công hoặc chuyển sang nhập thủ công.';

  @override
  String get chatModelCatalogError403 =>
      'Truy cập truy vấn mô hình CLI bị từ chối (403). Kiểm tra đăng nhập CLI và kết nối dịch vụ, hoặc nhập tên mô hình thủ công.';

  @override
  String chatModelCatalogErrorGeneric(String error) {
    return 'Lỗi danh mục mô hình: $error';
  }

  @override
  String get chatModelAuthorizeButton => 'Ủy quyền Danh mục Mô hình';

  @override
  String get chatModelAuthorizeConfirmTitle => 'Ủy quyền Danh mục Mô hình';

  @override
  String get chatModelAuthorizeConfirmMessage =>
      'Thao tác này sẽ bắt đầu ủy quyền qua trình duyệt cho danh mục mô hình trên máy chủ/container đích. Đăng nhập Codex hiện tại và các phiên terminal của bạn sẽ hoàn toàn không bị ảnh hưởng. Tiếp tục?';

  @override
  String get chatModelAuthorizing => 'Đang ủy quyền qua trình duyệt...';

  @override
  String get chatModelAuthorizeCancel => 'Hủy ủy quyền';

  @override
  String get chatCommandsFirstTurnNote =>
      'Các lệnh slash sẽ được quảng bá bởi runtime agent ngay khi phiên được khởi tạo, mà không yêu cầu cuộc trò chuyện thông thường trước đó; các bản nháp không tự động tạo phiên.';

  @override
  String get chatCommandsClientActionRunSettings => 'Cài đặt chạy';

  @override
  String get chatCommandsClientActionWorkingDirectory => 'Thư mục làm việc';

  @override
  String get chatCommandsClientActionsSection => 'Hành động cục bộ';

  @override
  String get chatRunSettingsModelSourceCatalog => 'Danh sách mô hình';

  @override
  String get chatRunSettingsModelSourceCustom => 'Nhập thủ công';

  @override
  String get chatRunSettingsCustomModelHint => 'Nhập ID mô hình';

  @override
  String get chatRunSettingsCustomModelNotice =>
      'Tên mô hình thủ công chưa được xác minh và sẽ được gửi trực tiếp đến runtime của agent, nơi có thể từ chối các mô hình không được hỗ trợ.';

  @override
  String get chatRunSettingsCustomModelEmptyError =>
      'Tên mô hình không được để trống';

  @override
  String get chatRunSettingsCustomModelInvalidError =>
      'Tên mô hình tối đa 256 ký tự và không chứa khoảng trắng hoặc ký tự điều khiển';

  @override
  String get chatCommandsDraftPreviewNotice =>
      'Các lệnh đã được xác minh cho phiên bản bộ điều hợp hiện tại. Việc chọn sẽ chèn văn bản vào bản nháp; Gửi sẽ khởi tạo phiên theo yêu cầu và chạy lệnh trực tiếp.';

  @override
  String get chatCommandsDiscoveryFailed =>
      'Khám phá lệnh hoặc kỹ năng thất bại';

  @override
  String get chatAuthWaitingForBrowser =>
      'Đang chờ ủy quyền trong trình duyệt...';

  @override
  String get chatAuthBrowserLaunchFailed =>
      'Không thể mở trình duyệt bên ngoài. Vui lòng mở lại hoặc sao chép liên kết ủy quyền bên dưới.';

  @override
  String get chatAuthReopenBrowser => 'Mở lại Trình duyệt';

  @override
  String get chatAuthCopyLink => 'Sao chép liên kết';

  @override
  String get chatAuthManualCallback => 'Callback thủ công';

  @override
  String get chatAuthManualCallbackTitle => 'Nhập URL Callback Ủy quyền';

  @override
  String get chatAuthManualCallbackDesc =>
      'Dán URL chuyển hướng đầy đủ (http://127.0.0.1:PORT/...?code=...&state=...) từ trình duyệt để hoàn tất ủy quyền. Mã ủy quyền thô không được chấp nhận.';

  @override
  String get chatAuthCallbackInputLabel => 'URL Callback';

  @override
  String get chatAuthCallbackInputHint =>
      'http://127.0.0.1:PORT/...?code=...&state=...';

  @override
  String get chatAuthCallbackInvalidError =>
      'Định dạng URL callback không hợp lệ hoặc gửi thất bại';

  @override
  String get agentAuthAgYNotice =>
      'Antigravity ACP yêu cầu ủy quyền tài khoản chính thức, tách biệt với đăng nhập CLI terminal.';

  @override
  String get chatAuthDiscoveryPrompt =>
      'Lượt này yêu cầu xác thực ACP. Kết nối lại và yêu cầu ủy quyền để tiếp tục.';

  @override
  String get chatRequestAuthButton => 'Yêu cầu xác thực';

  @override
  String get agentActionAcpLogin => 'Đăng nhập ACP';

  @override
  String get agentActionCliLogin => 'Đăng nhập CLI';

  @override
  String get agentAgyAcpSignInRequired =>
      'Thiếu thông tin xác thực ACP (yêu cầu đăng nhập ACP)';

  @override
  String get agentAgyAcpCredentialsSaved =>
      'Đã lưu thông tin xác thực ACP (chưa xác minh)';

  @override
  String get chatAuthMethodUnavailable =>
      'Phương thức xác thực đã chọn không khả dụng.';

  @override
  String get chatAuthConnectionExpired =>
      'Kết nối xác thực đã hết hạn. Vui lòng thử lại.';

  @override
  String get chatAuthCallbackDeliveryFailed =>
      'Gửi callback ủy quyền tới máy chủ thất bại.';

  @override
  String get agentTargetChangedNotice =>
      'Máy chủ đích đã thay đổi. Vui lòng mở lại quản lý agent trên máy chủ hiện tại.';

  @override
  String get agentAgyAuthCheckUnavailable =>
      'Kiểm tra xác thực Antigravity không khả dụng';

  @override
  String get agentAgyAuthCheckInvalid =>
      'Phản hồi kiểm tra xác thực Antigravity không hợp lệ';

  @override
  String get sftpDownloadDisconnected => 'Tải xuống đã bị ngắt kết nối';

  @override
  String get sftpDownloadPermissionDenied => 'Quyền bị từ chối';

  @override
  String get sftpDownloadNotFound => 'Không tìm thấy tệp từ xa';

  @override
  String get sftpDownloadTimeout => 'Tải xuống đã hết thời gian';

  @override
  String get sftpDownloadLocalSpace => 'Không đủ dung lượng lưu trữ cục bộ';

  @override
  String get sftpDownloadLocalIo => 'Ghi vào bộ nhớ cục bộ thất bại';

  @override
  String get sftpDownloadIncomplete => 'Tải xuống không hoàn chỉnh';

  @override
  String get transferStatusWaitingConnection => 'Đang chờ kết nối';

  @override
  String get chatAuthCallbackListenerFailed =>
      'Khởi động trình lắng nghe callback ủy quyền cục bộ thất bại. Vui lòng thử xác thực lại.';

  @override
  String get settingsExperimentalFeatures => 'Tính năng thử nghiệm';

  @override
  String get settingsExperimentalFeaturesDesc =>
      'Trải nghiệm các khả năng xem trước và thử nghiệm';

  @override
  String get settingsExperimentalCliChatTitle => 'Trò chuyện thông minh CLI';

  @override
  String get settingsExperimentalCliChatDesc =>
      'Bật giao diện trò chuyện chuyên dụng cho agent dòng lệnh';

  @override
  String get settingsExperimentalDialogClose => 'Đóng';

  @override
  String get settingsExperimentalSaveFailed =>
      'Cập nhật cài đặt tính năng thử nghiệm thất bại';

  @override
  String get settingsExperimentalNasTitle => 'Media NAS';

  @override
  String get settingsExperimentalNasDesc =>
      'Bật thư viện phương tiện, quét thư mục và phát âm thanh';

  @override
  String get settingsLanguageSaveFailed => 'Cập nhật cài đặt ngôn ngữ thất bại';

  @override
  String get settingsAboutPrivacy => 'Giới thiệu và quyền riêng tư';

  @override
  String get privacyPolicyTitle => 'Chính sách quyền riêng tư';

  @override
  String get privacyPolicyDescription => 'Sử dụng dữ liệu và lựa chọn của bạn';

  @override
  String get privacyContactTitle => 'Liên hệ về quyền riêng tư';

  @override
  String get privacyCopyEmail => 'Sao chép địa chỉ email';

  @override
  String get privacyEmailCopied => 'Đã sao chép địa chỉ email';

  @override
  String get privacyOnlineVersion => 'Xem phiên bản trực tuyến';

  @override
  String get privacyLinkFailed =>
      'Không thể mở liên kết. Bạn có thể sao chép địa chỉ email.';

  @override
  String get privacyLoadFailed =>
      'Không thể tải chính sách. Hãy xem phiên bản trực tuyến.';

  @override
  String get privacyVersionUnknown => 'Không có thông tin phiên bản';

  @override
  String get aboutWebsite => 'Trang web chính thức';

  @override
  String get aboutLicense => 'Giấy phép ứng dụng';

  @override
  String get aboutThirdPartyLicenses => 'Giấy phép nguồn mở của bên thứ ba';

  @override
  String get aboutLicenseSummary =>
      'Nội dung gốc của Valhalla được cấp phép cho mục đích phi thương mại theo PolyForm Noncommercial 1.0.0. Việc sử dụng thương mại ngoài phạm vi cho phép của giấy phép cần được cấp phép riêng. Các thành phần bên thứ ba giữ nguyên giấy phép của mình. Việc sử dụng tuân theo toàn bộ điều khoản bên dưới.';

  @override
  String get aboutCopyrightNotice => 'Thông báo bản quyền';

  @override
  String get aboutLicenseLoadFailed =>
      'Không thể tải giấy phép. Vui lòng liên hệ norns.soft@gmail.com.';

  @override
  String get aboutLinkFailed =>
      'Không thể mở liên kết. Hãy mở https://norns.cc.cd trong trình duyệt.';

  @override
  String get downloadReveal => 'Hiển thị trong File Explorer';

  @override
  String get downloadRevealFailed =>
      'Không thể mở thư mục tải xuống. Thư mục có thể đã được di chuyển hoặc xóa.';
}
