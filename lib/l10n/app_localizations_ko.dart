// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appName => 'Valhalla';

  @override
  String get appSubtitle => 'AI 네이티브 서버 & 에이전트 관리';

  @override
  String get navAiChat => 'AI 채팅';

  @override
  String get navTerminal => '터미널';

  @override
  String get navFiles => 'SFTP 파일';

  @override
  String get navCommands => '명령어';

  @override
  String get navSettings => '설정';

  @override
  String get serverConnected => '연결됨';

  @override
  String get serverOnline => '온라인';

  @override
  String get serverOffline => '오프라인';

  @override
  String get latencyMs => 'ms';

  @override
  String get reconnect => '다시 연결';

  @override
  String get disconnect => '연결 해제';

  @override
  String get quickDisconnect => '빠른 연결 해제';

  @override
  String get newSession => '새 세션';

  @override
  String get historySessions => '세션 기록';

  @override
  String get switchAgent => '에이전트 전환';

  @override
  String get agentClaudeCode => 'Claude CodeX';

  @override
  String get agentCodex => 'OpenAI Codex';

  @override
  String get agentOpenCode => 'OpenCode ACP';

  @override
  String get agentGemini => 'Gemini CLI';

  @override
  String get activeAgent => '활성 에이전트';

  @override
  String get inputPromptHint =>
      '에이전트에게 진단, 도구 실행, 명령어 작성을 요청하세요... (Enter로 전송)';

  @override
  String get thinking => '생각 중';

  @override
  String get executionPlan => '실행 계획';

  @override
  String get toolCall => '도구 호출';

  @override
  String get toolStatusPending => '대기 중';

  @override
  String get toolStatusRunning => '실행 중...';

  @override
  String get toolStatusCompleted => '완료됨';

  @override
  String get toolStatusFailed => '실패함';

  @override
  String get permissionRequired => '권한 필요';

  @override
  String get permissionDescription => '에이전트가 서버에서 다음 명령어를 실행하려고 합니다:';

  @override
  String get permissionReject => '거부';

  @override
  String get permissionAllowOnce => '한 번 허용';

  @override
  String get permissionAllowAlways => '항상 허용';

  @override
  String get quickTroubleshootCpu => '높은 CPU 점유율 진단';

  @override
  String get quickDockerHealth => 'Docker 상태 확인';

  @override
  String get quickCleanCache => '시스템 캐시 정리';

  @override
  String get quickNginxLogs => 'Nginx 오류 로그 확인';

  @override
  String get terminalNewTab => '새 탭';

  @override
  String get terminalCloseTab => '탭 닫기';

  @override
  String get terminalClear => '지우기';

  @override
  String get terminalQuickCmds => '명령어 팔레트';

  @override
  String get terminalPaste => '붙여넣기';

  @override
  String get sftpCurrentPath => '현재 경로';

  @override
  String get sftpUpload => '업로드';

  @override
  String get sftpNewFolder => '새 폴더';

  @override
  String get sftpNewFile => '새 파일';

  @override
  String get sftpRefresh => '새로고침';

  @override
  String get sftpSearchHint => '파일 또는 폴더 검색...';

  @override
  String get sftpEmpty => '디렉터리가 비어 있습니다';

  @override
  String get sftpFileName => '이름';

  @override
  String get sftpFileSize => '크기';

  @override
  String get sftpFilePerm => '권한';

  @override
  String get sftpFileModified => '수정일';

  @override
  String get cmdCategoryDocker => 'DOCKER 컨테이너 스택';

  @override
  String get cmdCategorySystem => '시스템 유지 관리';

  @override
  String get cmdCategoryNetwork => '네트워크 & 포트';

  @override
  String get cmdExecute => '실행';

  @override
  String get cmdDangerous => '위험한 명령어';

  @override
  String get cmdDangerousWarning =>
      '이 작업은 되돌릴 수 없으며 서비스 중단을 일으킬 수 있습니다. 계속 진행하시겠습니까?';

  @override
  String get cmdParamRequired => '매개변수 입력 필요';

  @override
  String get cmdConfirm => '확인 & 실행';

  @override
  String get cmdCancel => '취소';

  @override
  String get settingsAppearance => '화면 & 테마';

  @override
  String get settingsThemeMode => '테마 모드';

  @override
  String get themeSystem => '시스템 설정 따름';

  @override
  String get themeSystemDesc => '자동 적응';

  @override
  String get themeLight => '라이트 모드';

  @override
  String get themeLightDesc => '페이퍼 하이키';

  @override
  String get themeDark => '긱 다크';

  @override
  String get themeDarkDesc => '딥 차콜';

  @override
  String get themeAmoled => 'AMOLED 블랙';

  @override
  String get themeAmoledDesc => '트루 블랙 0x000000';

  @override
  String get settingsAccentColor => '테마 강조 색상';

  @override
  String get accentCyberEmerald => '사이버 에메랄드';

  @override
  String get accentTechBlue => '테크 블루';

  @override
  String get accentElectricViolet => '일렉트릭 바이올렛';

  @override
  String get accentCrimsonRed => '크림슨 레드';

  @override
  String get accentAmberOrange => '앰버 오렌지';

  @override
  String get settingsLanguage => '언어 & 지역';

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
  String get settingsAiOps => 'AI Ops & 엔진';

  @override
  String get settingsSecurity => '연결 & 보안';

  @override
  String get settingsKnownHosts => '알려진 호스트 키';

  @override
  String get settingsClearStorage => '자격 증명 재설정';

  @override
  String get settingsResetDefault => '기본값으로 복원';

  @override
  String get settingsTerminalUseTmux => '영구 세션 (tmux)';

  @override
  String get settingsTerminalUseTmuxSubtitle => '원격 서버의 tmux 내에서 터미널 세션 실행';

  @override
  String get settingsTerminalUseTmuxDescription =>
      '연결이 끊겨도 터미널 출력을 유지합니다. 원격 서버에 tmux가 설치되어 있어야 합니다. 새로 여는 터미널 탭에 적용됩니다.';

  @override
  String get settingsTerminalFontSize => '터미널 글꼴 크기';

  @override
  String get settingsTerminalFontSizeSubtitle => 'SSH 및 CLI 터미널 글꼴 크기 조정';

  @override
  String get version => '버전';

  @override
  String get addServer => '서버 추가';

  @override
  String get editServer => '서버 수정';

  @override
  String get serverName => '서버 이름';

  @override
  String get serverHost => '호스트 / IP';

  @override
  String get serverPort => '포트';

  @override
  String get serverUsername => '사용자 이름';

  @override
  String get serverAuthType => '인증 유형';

  @override
  String get serverPassword => '비밀번호';

  @override
  String get serverPrivateKey => '개인 키';

  @override
  String get serverSave => '서버 저장';

  @override
  String get serverDelete => '서버 삭제';

  @override
  String get fileEditor => '파일 편집기';

  @override
  String get fileEditorSave => '변경사항 저장';

  @override
  String get fileSavedSuccess => '파일이 성공적으로 저장되었습니다';

  @override
  String get addCommand => '새 명령어';

  @override
  String get commandTitle => '명령어 제목';

  @override
  String get commandContent => '명령어 문자열';

  @override
  String get commandCategory => '카테고리';

  @override
  String get commandDescription => '설명';

  @override
  String get save => '저장';

  @override
  String get delete => '삭제';

  @override
  String get cancel => '취소';

  @override
  String get confirm => '확인';

  @override
  String get cmdExecutionChannel => '실행 채널';

  @override
  String get cmdChannelTerminal => 'SSH 터미널로 직접 전송';

  @override
  String get cmdChannelTerminalDesc => '명령어가 활성 터미널 세션에 직접 입력됩니다';

  @override
  String get cmdChannelBackground => '백그라운드 세션에서 실행';

  @override
  String get cmdChannelBackgroundDesc => 'SSH 로그인 셸을 통해 실행하고 출력을 캡처합니다';

  @override
  String get cmdInjectedToTerminal => '명령어가 터미널로 전송되었습니다';

  @override
  String get cmdExecutionCompleted => '실행 완료됨';

  @override
  String get cmdExecutionFailed => '실행 실패함';

  @override
  String get cmdExecutingRemote => '원격 명령어 실행 중...';

  @override
  String get cmdClose => '닫기';

  @override
  String get navDashboard => '대시보드';

  @override
  String get navDocker => 'Docker';

  @override
  String get navSystem => '시스템';

  @override
  String get navMore => '더 보기';

  @override
  String get dashboardTitle => '서버 대시보드';

  @override
  String get metricsCpu => 'CPU 사용률';

  @override
  String get metricsMemory => '메모리 사용률';

  @override
  String get metricsLoadAvg => '평균 부하';

  @override
  String get metricsUptime => '시스템 가동 시간';

  @override
  String get metricsRootDisk => '루트 디스크 사용량';

  @override
  String get quickActions => '빠른 탐색';

  @override
  String get activeServerStatus => '활성 서버 상태';

  @override
  String get noServerSelected => '선택된 서버가 없습니다. 먼저 서버를 선택해 주세요.';

  @override
  String get serverDisconnected => '연결 끊김';

  @override
  String get serverConnecting => '연결 중...';

  @override
  String get connectNow => '지금 연결';

  @override
  String get serverSpecs => '서버 정보 & 사양';

  @override
  String get dockerTitle => 'Docker 컨테이너';

  @override
  String get dockerSearchHint => '이름 또는 이미지로 컨테이너 검색...';

  @override
  String get dockerFilterAll => '전체';

  @override
  String get dockerFilterRunning => '실행 중';

  @override
  String get dockerFilterExited => '종료됨';

  @override
  String get dockerFilterPaused => '일시 정지됨';

  @override
  String get dockerActionStart => '시작';

  @override
  String get dockerActionStop => '중지';

  @override
  String get dockerActionRestart => '다시 시작';

  @override
  String get dockerActionPause => '일시 정지';

  @override
  String get dockerActionUnpause => '다시 시작';

  @override
  String get dockerActionRm => '제거';

  @override
  String get dockerActionLogs => '로그';

  @override
  String get dockerActionInspect => '세부 정보';

  @override
  String get dockerLogsTitle => '컨테이너 로그';

  @override
  String get dockerInspectTitle => '컨테이너 검사';

  @override
  String get dockerNoContainers => '서버에서 컨테이너를 찾을 수 없습니다';

  @override
  String get dockerEmptyRunning => '실행 중인 컨테이너가 없습니다';

  @override
  String get dockerPorts => '포트';

  @override
  String get dockerCreated => '생성일';

  @override
  String get dockerImage => '이미지';

  @override
  String get systemTitle => '프로세스 & 서비스';

  @override
  String get tabProcesses => '프로세스';

  @override
  String get tabServices => 'Systemd 서비스';

  @override
  String get processSearchHint => '프로세스 이름 또는 PID로 검색...';

  @override
  String get processPid => 'PID';

  @override
  String get processCpu => 'CPU %';

  @override
  String get processMem => '메모리 %';

  @override
  String get processStat => '상태';

  @override
  String get processCommand => '명령어';

  @override
  String get processTerminate => '종료 (SIGTERM)';

  @override
  String get processForceKill => '강제 종료 (SIGKILL)';

  @override
  String get processKillForbidden => '시스템 초기화 프로세스 종료 거부 (PID <= 1)';

  @override
  String get serviceSearchHint => '서비스 이름으로 검색...';

  @override
  String get serviceName => '서비스';

  @override
  String get serviceDescription => '설명';

  @override
  String get serviceStatus => '상태';

  @override
  String get serviceStartup => '시작 유형';

  @override
  String get serviceActionStart => '시작';

  @override
  String get serviceActionStop => '중지';

  @override
  String get serviceActionRestart => '다시 시작';

  @override
  String get serviceActionReload => '다시 불러오기';

  @override
  String get serviceActionEnable => '활성화';

  @override
  String get serviceActionDisable => '비활성화';

  @override
  String get serviceNoServices => 'Systemd 서비스를 찾을 수 없습니다';

  @override
  String get riskDangerTitle => '고위험 작업 확인';

  @override
  String get riskWarningTitle => '작업 경고 확인';

  @override
  String get riskSafeTitle => '작업 확인';

  @override
  String get riskIrreversibleWarning =>
      '이 작업은 고위험으로 분류되며 되돌릴 수 없습니다. 데이터 손실이나 서비스 중단이 발생할 수 있습니다.';

  @override
  String get riskWarningDescription =>
      '이 작업은 활성 서비스에 영향을 주거나 프로세스를 다시 시작할 수 있습니다. 주의하여 진행하세요.';

  @override
  String get riskCommandPreview => '명령어 미리보기';

  @override
  String get riskConfirmButton => '확인 & 계속';

  @override
  String get riskCancelButton => '취소';

  @override
  String get stateLoading => '원격 데이터를 불러오는 중...';

  @override
  String get stateOffline => '서버가 오프라인입니다';

  @override
  String get stateOfflineDesc => '리소스 관리 및 지표 스트리밍을 위해 활성 SSH 연결을 설정하세요.';

  @override
  String get stateError => '오류가 발생했습니다';

  @override
  String get stateRetry => '다시 시도';

  @override
  String get stateEmpty => '항목을 찾을 수 없습니다';

  @override
  String get inspectorTitle => '검사기';

  @override
  String get inspectorClose => '닫기';

  @override
  String get inspectorDetails => '검사 세부 정보';

  @override
  String get selectServerTitle => '대상 서버 선택';

  @override
  String get sshDisconnectedSuccess => 'SSH 연결이 해제되었습니다';

  @override
  String get trustHostFingerprintTitle => '호스트 지문을 신뢰하시겠습니까?';

  @override
  String get trustAndConnect => '신뢰 & 연결';

  @override
  String get reject => '거부';

  @override
  String get confirmDeleteServerTitle => '서버 삭제';

  @override
  String get noServersFound => '아직 구성된 서버가 없습니다';

  @override
  String get agentNotReadyError => '선택한 에이전트가 준비되지 않았습니다. 환경과 구성을 확인하세요.';

  @override
  String get sshDisconnectedError =>
      'SSH 연결이 끊어졌습니다. AI Ops를 사용하기 전에 서버에 연결하세요.';

  @override
  String get noAgentAvailable => '사용 가능한 에이전트 없음';

  @override
  String get noAgentAvailablePrompt => '활성 에이전트가 없습니다. 먼저 에이전트를 구성하거나 준비하세요.';

  @override
  String get noAgentAvailableHint => '채팅을 시작하려면 사용 가능한 에이전트를 선택하거나 구성하세요...';

  @override
  String get manageAgents => '에이전트 관리';

  @override
  String get noReadyAgentsTitle => '준비된 에이전트 없음';

  @override
  String get noReadyAgentsDesc => '이 서버에서 환경 검사를 통과한 에이전트가 없습니다.';

  @override
  String get agentStatusReady => '준비됨';

  @override
  String get agentStatusChecking => '확인 중...';

  @override
  String get agentStatusCliMissing => '설치가 감지되지 않음';

  @override
  String get agentStatusAcpMissing => 'ACP 구성 요소가 감지되지 않음';

  @override
  String get agentStatusNotLoggedIn => '로그인되지 않음';

  @override
  String get agentStatusError => '오류';

  @override
  String get agentStatusUnknown => '알 수 없음';

  @override
  String get agentActionInstall => '설치';

  @override
  String get agentActionLogin => '로그인';

  @override
  String get agentActionRefresh => '상태 확인';

  @override
  String get noConfiguredAgents => '이 서버에 구성된 에이전트가 없습니다';

  @override
  String get agentManagementTitle => '에이전트 관리';

  @override
  String get settingsAgentManagement => '에이전트 관리';

  @override
  String get settingsAgentManagementSubtitle => '현재 서버의 ACP 에이전트 구성, 감지 및 관리';

  @override
  String get addAgentButton => '에이전트 추가';

  @override
  String get noServerSelectedForAgents =>
      '선택된 서버가 없습니다. 먼저 기본 인터페이스에서 서버를 선택하세요.';

  @override
  String get sshDisconnectedAgentWarning =>
      'SSH 연결이 끊어졌습니다. 연결이 설정될 때까지 감지, 설치 및 로그인이 비활성화됩니다.';

  @override
  String get noAgentsConfiguredTitle => '구성된 에이전트 없음';

  @override
  String get noAgentsConfiguredDesc =>
      '이 서버에서 AI Ops를 사용하려면 Claude Code, Codex, OpenCode, AGY 또는 커스텀 ACP 에이전트를 추가하세요.';

  @override
  String get agentPresetLabel => '프리셋';

  @override
  String get agentPresetClaudeCode => 'Claude Code';

  @override
  String get agentPresetCodex => 'OpenAI Codex';

  @override
  String get agentPresetOpenCode => 'OpenCode ACP';

  @override
  String get agentPresetAgy => 'Antigravity AGY';

  @override
  String get agentPresetCustom => '사용자 지정';

  @override
  String get agentNameLabel => '에이전트 이름';

  @override
  String get agentNameHint => '예: 프로덕션 Codex';

  @override
  String get agentDescriptionLabel => '설명';

  @override
  String get agentDescriptionHint => '에이전트에 대한 간단한 설명';

  @override
  String get agentCliCommandLabel => 'CLI 감지 명령어';

  @override
  String get agentCliCommandHint => '예: claude, codex';

  @override
  String get agentAcpCommandLabel => 'ACP 실행 명령어';

  @override
  String get agentAcpCommandHint => '예: codex-acp --stdio';

  @override
  String get agentInstallCommandLabel => '설치 명령어 (선택사항)';

  @override
  String get agentInstallCommandHint => '예: npm install -g @openai/codex';

  @override
  String get agentLoginCheckCommandLabel => '로그인 확인 명령어 (선택사항)';

  @override
  String get agentLoginCheckCommandHint => '예: codex --version';

  @override
  String get agentLoginCommandLabel => '로그인 명령어 (선택사항)';

  @override
  String get agentLoginCommandHint => '예: codex login';

  @override
  String get agentSaveButton => '저장 & 감지';

  @override
  String get agentCliRequired => 'CLI 감지 명령어가 필요합니다';

  @override
  String get agentAcpRequired => 'ACP 실행 명령어가 필요합니다';

  @override
  String get agentNameRequired => '에이전트 이름이 필요합니다';

  @override
  String get confirmInstallAgentTitle => '에이전트 설치 확인';

  @override
  String get confirmLoginAgentTitle => '에이전트 로그인 확인';

  @override
  String get agentCommandRiskWarning =>
      '이 명령어는 현재 사용자 권한으로 원격 서버에서 직접 실행됩니다. 패키지를 설치하거나 시스템 환경을 변경할 수 있습니다.';

  @override
  String get targetServerLabel => '대상 서버';

  @override
  String get commandPreviewLabel => '명령어 미리보기';

  @override
  String get executeButton => '실행';

  @override
  String get deleteAgentTitle => '에이전트 삭제';

  @override
  String get deleteAgentConfirm => '삭제';

  @override
  String get agentStatusCheckingDesc => '원격 서버 환경 감지 중...';

  @override
  String get agentStatusInstalling => '서버에 종속 항목 설치 중...';

  @override
  String get agentStatusLoggingIn => '서버에서 로그인 명령어 실행 중...';

  @override
  String get agentNoLoginCheckProvided => '지정된 로그인 확인 명령어가 없습니다';

  @override
  String get agentInstallPrompt => '설치가 감지되지 않았습니다. 지금 자동 설치하시겠습니까?';

  @override
  String get agentActionAutoInstall => '자동 설치';

  @override
  String get agentLoginPrompt => '로그인되지 않았습니다. 지금 로그인하시겠습니까?';

  @override
  String get agentActionExecuteLogin => '지금 로그인';

  @override
  String get agentNeedsInstallOrReadyPrompt =>
      '이 서버의 에이전트가 아직 설치되지 않았거나 준비되지 않았습니다. 환경 설정을 관리하고 완료해 주세요.';

  @override
  String get agentNeedsInstallOrReadyHint => '채팅을 시작하려면 에이전트를 설치하고 준비하세요...';

  @override
  String get agentAcpInstallPrompt => 'ACP 구성 요소가 감지되지 않았습니다. 지금 자동 설치하시겠습니까?';

  @override
  String get agentInstallCommandAcpLabel => 'ACP 설치 명령어 (선택사항)';

  @override
  String get agentInstallCommandAcpHint =>
      '예: npm install -g @zed-industries/codex-acp';

  @override
  String get agentNoInstallCommand => '이 에이전트에 구성된 설치 명령어가 없습니다';

  @override
  String get agentInstallLogTitle => '설치 출력';

  @override
  String get agentInstallLogEmpty => '설치 출력을 기다리는 중…';

  @override
  String get agentInstallLogTruncated => '출력이 너무 깁니다. 가장 최근 줄을 표시합니다';

  @override
  String get agentAcpOptional => '선택사항. CLI 전용인 경우 비워 두세요';

  @override
  String get acpStreaming => 'ACP 스트리밍 중...';

  @override
  String get aiOpsAgentTitle => 'Valhalla AI Ops 에이전트';

  @override
  String get aiOpsEmptySubtitle => 'SSH 채널을 통한 ACP stdio 연결됨';

  @override
  String get agentAuthRequiredTitle => '인증 필요';

  @override
  String get agentAuthRequiredDesc => '에이전트가 요청을 처리하기 전에 인증이 필요합니다.';

  @override
  String get agentAuthMethodLabel => '인증 방식';

  @override
  String get agentAuthNoMethodsNotice =>
      '에이전트가 로그인 방식을 제공하지 않았습니다. 서버에서 구성을 확인하세요.';

  @override
  String get agentAuthProceedButton => '로그인';

  @override
  String get agentAuthCancelButton => '취소';

  @override
  String get agentAuthRetryHint => '로그인 후 메시지를 다시 전송해 주세요.';

  @override
  String get agentAuthRequiredError => '인증이 필요합니다. 계속하려면 로그인하세요.';

  @override
  String get agentLoginTerminalTitle => '대화형 로그인 터미널';

  @override
  String get agentLoginTerminalSubtitle =>
      '아래 터미널에서 로그인 단계를 완료하세요. 표시되는 URL이나 코드 안내를 따르세요.';

  @override
  String get agentLoginTerminalRunning => '터미널에서 로그인 명령어가 실행 중입니다...';

  @override
  String get agentLoginTerminalDisconnected =>
      'SSH 연결이 끊어졌습니다. 로그인 세션이 중단되었습니다.';

  @override
  String get agentLoginTerminalRetry => '터미널 다시 연결';

  @override
  String get agentLoginTerminalFinish => '완료 & 확인';

  @override
  String get agentLoginTerminalClose => '닫기';

  @override
  String get agentLoginTerminalNoTtyHint =>
      '에이전트가 코드 붙여넣기를 요구하는 경우 터미널을 길게 누르거나 붙여넣기 키를 사용하세요.';

  @override
  String get agentLoginTerminalUrlLabel => '로그인 URL 감지됨';

  @override
  String get agentLoginTerminalUrlCopy => '링크 복사';

  @override
  String get agentLoginTerminalUrlCopied => '로그인 URL이 클립보드에 복사되었습니다';

  @override
  String get agentLoginTerminalCopyAll => '전체 출력 복사';

  @override
  String get agentLoginTerminalCopiedAll => '터미널 출력이 클립보드에 복사되었습니다';

  @override
  String get sshStatusReconnected => '연결 복원됨';

  @override
  String get sshStatusDisconnectedRetrying => '연결 끊김, 재시도 중';

  @override
  String get sshStatusDisconnectedManual => '연결 끊김';

  @override
  String get sshStatusHostKeyChanged => '호스트 키 변경됨 — 연결 거부됨';

  @override
  String get sshKeepAliveNotificationTitle => 'Valhalla가 세션을 유지하고 있습니다';

  @override
  String get terminalTmuxMissingNotice =>
      'tmux를 찾을 수 없음 — 연결이 끊기면 세션이 유지되지 않습니다';

  @override
  String get terminalTmuxSessionRestored => '터미널 세션 복원됨';

  @override
  String get moshSectionTitle => 'Mosh';

  @override
  String get moshEnable => 'Mosh 활성화 — 연결 끊김 및 IP 변경에도 유지되는 로밍 터미널';

  @override
  String get moshServerPathLabel => 'mosh-server 경로';

  @override
  String get moshPortRangeLabel => 'UDP 포트 범위';

  @override
  String get moshNewSession => '새 Mosh 세션';

  @override
  String get moshNotInstalled =>
      '원격 서버에서 mosh-server를 찾을 수 없습니다. sudo apt install mosh (Debian/Ubuntu) 또는 sudo dnf install mosh (Fedora/RHEL)로 설치하세요.';

  @override
  String moshBootstrapFailed(String detail) {
    return 'Mosh 세션 시작 실패: $detail';
  }

  @override
  String get moshUdpTimeout =>
      'Mosh 연결 시간 초과 — 방화벽에서 UDP 트래픽이 차단되지 않았는지 확인하세요.';

  @override
  String get moshSessionTag => 'mosh';

  @override
  String get acpSessionRestored => '에이전트 세션 복원됨';

  @override
  String get acpSessionRestartNotice => '에이전트 세션이 다시 시작됨 — 이전 컨텍스트를 사용할 수 없음';

  @override
  String get terminalTmuxInstallDialogTitle => '원격 서버에 tmux를 설치하시겠습니까?';

  @override
  String get terminalTmuxInstallDialogMessage =>
      '연결 해제 시에도 터미널 세션을 보존하려면 tmux가 필요합니다. 지금 설치하시겠습니까?';

  @override
  String get terminalTmuxInstallCommandLabel => '실행할 명령어:';

  @override
  String get terminalTmuxInstallUnsupported =>
      '원격 서버에서 지원되는 패키지 관리자를 감지하지 못했습니다. 수동으로 tmux를 설치하세요.';

  @override
  String get terminalTmuxInstallFailed =>
      'tmux 설치에 실패했습니다. 서버 권한과 네트워크를 확인하세요.';

  @override
  String get terminalTmuxInstallDisconnected =>
      'SSH 연결이 끊어졌습니다. tmux를 설치하려면 다시 연결하세요.';

  @override
  String get terminalTmuxInstallInstalling => 'tmux 설치 중...';

  @override
  String get terminalTmuxInstallConfirm => 'tmux 설치';

  @override
  String get terminalTmuxInstallSkip => '건너뛰기 (일반 셸 사용)';

  @override
  String get sftpDownload => '다운로드';

  @override
  String get sftpOpen => '열기';

  @override
  String get sftpUploadFailed => '업로드에 실패했습니다. 권한을 확인하고 다시 시도하세요.';

  @override
  String get sftpDownloadFailed => '다운로드 실패함';

  @override
  String get sftpOpenUnsupported => '이 파일 형식은 열 수 없습니다.';

  @override
  String get sftpReadFailed => '파일을 읽지 못했습니다. 권한을 확인하고 다시 시도하세요.';

  @override
  String get sftpTransferFailed => '파일 작업에 실패했습니다. 다시 시도해 주세요.';

  @override
  String get sftpDownloadSuccess => '성공적으로 다운로드됨';

  @override
  String get sftpUploading => '업로드 중...';

  @override
  String get sftpDownloading => '다운로드 중...';

  @override
  String get sftpUpDirectory => '상위 디렉터리로 이동';

  @override
  String get sftpShowHiddenFiles => '숨김 파일 표시';

  @override
  String get sftpHideHiddenFiles => '숨김 파일 숨기기';

  @override
  String get sftpHiddenPreferenceSaveFailed => '숨김 파일 설정 저장 실패';

  @override
  String get sftpSymlink => '심볼릭 링크';

  @override
  String get sftpLinkTargetUnavailable => '링크 대상이 유효하지 않거나 없습니다';

  @override
  String get sftpLinkTargetPermissionDenied => '링크 대상에 대한 접근 권한이 없습니다';

  @override
  String get settingsAutoConnect => '시작 시 자동 연결';

  @override
  String get settingsAutoConnectFixed => '고정 기본 SSH 서버';

  @override
  String get settingsAutoConnectFixedDesc => '항상 아래에서 선택한 서버에 연결';

  @override
  String get settingsAutoConnectLast => '마지막 연결 기억';

  @override
  String get settingsAutoConnectLastDesc => '마지막으로 성공적으로 연결된 서버에 연결';

  @override
  String get settingsAutoConnectPickServer => '서버';

  @override
  String get settingsAutoConnectNoServer => '아직 선택된 서버가 없습니다';

  @override
  String get sftpSort => '정렬';

  @override
  String get sftpSortName => '이름';

  @override
  String get sftpSortSize => '크기';

  @override
  String get sftpSortDate => '수정일';

  @override
  String get sftpSortAscending => '오름차순';

  @override
  String get sftpSortDescending => '내림차순';

  @override
  String get themeQuickSwitch => '테마';

  @override
  String get transferList => '전송 목록';

  @override
  String get transferEmpty => '아직 전송 내역이 없습니다';

  @override
  String get transferUpload => '업로드';

  @override
  String get transferDownload => '다운로드';

  @override
  String get transferStatusQueued => '대기열에 추가됨';

  @override
  String get transferStatusRunning => '전송 중';

  @override
  String get transferStatusPaused => '일시 정지됨';

  @override
  String get transferStatusCompleted => '완료됨';

  @override
  String get transferStatusFailed => '실패함';

  @override
  String get transferStatusCanceled => '취소됨';

  @override
  String get transferPause => '일시 정지';

  @override
  String get transferResume => '다시 시작';

  @override
  String get transferCancel => '취소';

  @override
  String get transferRemove => '제거';

  @override
  String get transferClearFinished => '완료된 항목 지우기';

  @override
  String get transferSizeUnknown => '크기 알 수 없음';

  @override
  String get transferFailedUpload => '업로드 실패';

  @override
  String get transferFailedDownload => '다운로드 실패';

  @override
  String get stopGeneration => '중지';

  @override
  String get chatServerBindingRequired =>
      '이 세션은 서버에 바인딩되어 있지 않습니다. 계속하려면 현재 서버에 바인딩하세요.';

  @override
  String get chatSessionUnboundNotice => '이 세션은 어떤 서버에도 바인딩되어 있지 않습니다.';

  @override
  String get bindServerAction => '서버 바인딩';

  @override
  String get bindServerDialogTitle => '세션을 서버에 바인딩';

  @override
  String get bindServerConfirmAction => '바인딩 확인';

  @override
  String get chatSessionIdentityMismatch =>
      '현재 서버 또는 에이전트가 이 세션의 바인딩된 식별 정보와 일치하지 않습니다. 일치하는 서버 및 에이전트로 전환하세요.';

  @override
  String get deleteSessionTitle => '세션 삭제';

  @override
  String get deleteSessionConfirmAction => '삭제';

  @override
  String get shareAgentSessionsTitle => '에이전트 세션 공유';

  @override
  String get shareAgentSessionsSubtitle => '이 서버의 여러 에이전트 간 세션 공유';

  @override
  String get shareAgentSessionsEnabled => '에이전트 세션 공유 활성화됨';

  @override
  String get shareAgentSessionsDisabled => '에이전트 세션 공유 비활성화됨';

  @override
  String get agentCliStatusInstalled => 'CLI: 설치됨';

  @override
  String get agentCliStatusMissing => 'CLI: 없음';

  @override
  String get agentCliStatusChecking => 'CLI: 확인 중...';

  @override
  String get agentCliStatusUnknown => 'CLI: 알 수 없음';

  @override
  String get agentCliStatusError => 'CLI: 오류';

  @override
  String get agentAcpStatusReady => 'ACP: 준비됨';

  @override
  String get agentAcpStatusMissing => 'ACP: 없음';

  @override
  String get agentAcpStatusChecking => 'ACP: 확인 중...';

  @override
  String get agentAcpStatusPendingCli => 'ACP: CLI 대기 중';

  @override
  String get agentAcpStatusUnknown => 'ACP: 알 수 없음';

  @override
  String get agentAcpStatusError => 'ACP: 오류';

  @override
  String get agentAcpStatusNa => 'ACP: 해당 없음';

  @override
  String get agentAuthStatusAuthenticated => '인증: 로그인됨';

  @override
  String get agentAuthStatusUnauthenticated => '인증: 로그인되지 않음';

  @override
  String get agentAuthStatusUnknown => '인증: 알 수 없음';

  @override
  String get downloadNotificationsUnavailable =>
      '시스템 다운로드 알림을 사용할 수 없습니다. 다운로드는 백그라운드에서 계속됩니다.';

  @override
  String get downloadOpenFailed => '다운로드한 파일을 열지 못했습니다.';

  @override
  String get dockerActionPending => '이 컨테이너에 대한 작업이 이미 진행 중입니다';

  @override
  String get dockerNoLogs => '(로그 없음)';

  @override
  String get serverReboot => '재부팅';

  @override
  String get serverRebootDialogTitle => '서버 재부팅 확인';

  @override
  String get serverRebootDialogMessage =>
      '이 서버를 정말 재부팅하시겠습니까? 모든 활성 연결과 백그라운드 서비스가 종료됩니다.';

  @override
  String get serverRebootConfirmButton => '지금 재부팅';

  @override
  String get serverRebootPasswordTitle => 'Sudo 비밀번호 필요';

  @override
  String get serverRebootPasswordMessage =>
      '서버를 재부팅하려면 루트 권한이 필요합니다. sudo 비밀번호를 입력하세요 (1회 사용, 저장되지 않음):';

  @override
  String get serverRebootPasswordHint => 'Sudo 비밀번호';

  @override
  String get serverRebootSubmitting => '재부팅 명령어 전송 중...';

  @override
  String get serverRebootAccepted =>
      '재부팅 명령어가 수락되었습니다. 완료 여부는 아직 확인되지 않았습니다. 서버가 다시 온라인 상태가 되면 다시 연결하세요.';

  @override
  String get serverRebootVerified => '서버 재부팅이 확인되었습니다. 시스템이 다시 온라인 상태입니다.';

  @override
  String get serverRebootUnknown =>
      '재부팅 결과를 알 수 없습니다. 명령어가 발송되었으나 완료를 확인할 수 없습니다. 수동으로 연결을 확인하세요.';

  @override
  String get serverRebootReconnect => '다시 연결';

  @override
  String get serverRebootServerChanged => '대상 서버가 변경되어 재부팅이 취소되었습니다';

  @override
  String get navCliChat => 'CLI 채팅';

  @override
  String get cliChatTitle => 'CLI 세션';

  @override
  String get cliChatSubtitle => '원격 서버의 네이티브 CLI 에이전트 세션';

  @override
  String get cliSelectAgent => '에이전트 선택';

  @override
  String get cliNoAgentsConfigured => '이 서버에 추가된 에이전트가 없습니다';

  @override
  String get cliAgentNeedsSetup => '에이전트 환경이 없거나 로그인되지 않았습니다';

  @override
  String get cliManageAgentsGuide => '에이전트 관리에서 구성하세요';

  @override
  String get cliNewDraft => '새 초안';

  @override
  String get cliNewDraftTooltip => '빈 초안 생성 (첫 메시지 전송 시 세션 생성됨)';

  @override
  String get cliDeleteSessionTitle => '원격 CLI 세션 기록 삭제';

  @override
  String get cliDeleteSessionMessage =>
      '원격 서버의 CLI 세션 기록이 영구적으로 삭제됩니다. 계속 진행하시겠습니까?';

  @override
  String get cliDeleteConfirmButton => '세션 삭제';

  @override
  String get cliCannotDeleteTooltip => '원격 세션 삭제가 지원되지 않거나 비활성화되었습니다';

  @override
  String get cliSessionsHeader => '세션';

  @override
  String get cliNoSessions => 'CLI 세션을 찾을 수 없습니다';

  @override
  String get cliFilterCwdHint => 'CWD 경로로 필터링...';

  @override
  String get cliFilterCwdAction => '필터링';

  @override
  String get cliClearCwdAction => '초기화';

  @override
  String get cliLoadMoreSessions => '세션 더 불러오기';

  @override
  String get cliRefreshSessions => '새로고침';

  @override
  String get cliClaudeReadOnlyNotice =>
      'Claude 기록은 읽기 전용입니다. 실제 터미널에서 대화를 이어가세요.';

  @override
  String get cliContinueInTerminal => '터미널에서 계속';

  @override
  String get cliOpenTerminal => '터미널 열기';

  @override
  String get cliCloseTerminal => '터미널 닫기';

  @override
  String get cliTerminalRunning => '대화형 CLI 터미널';

  @override
  String get cliAgyTerminalOnlyNotice =>
      '이 에이전트는 구조화된 기록 동기화를 지원하지 않습니다. 상호 작용 및 세션 선택을 위해 네이티브 CLI 터미널을 사용하세요.';

  @override
  String get cliInstallSdkTitle => '공식 Claude History SDK 설치';

  @override
  String get cliInstallSdkMessage =>
      '원격 서버에 공식 Claude Code History SDK가 없습니다. 지금 설치하시겠습니까?';

  @override
  String get cliInstallSdkAction => '공식 SDK 설치';

  @override
  String get cliApprovalsTitle => '대기 중인 승인';

  @override
  String get cliApprovalDetails => '세부 정보';

  @override
  String get cliApprovalAllow => '허용';

  @override
  String get cliApprovalDecline => '거부';

  @override
  String get cliInputHint => 'CLI 에이전트에게 메시지 입력...';

  @override
  String get cliSend => '전송';

  @override
  String get cliStop => '중지';

  @override
  String get cliBusy => '작업이 진행 중입니다. 잠시 기다려 주세요...';

  @override
  String get cliDisconnected => 'SSH가 연결되지 않았습니다';

  @override
  String get cliServerChanged => '대상 서버가 변경되었습니다';

  @override
  String get cliTurnFailed => 'CLI 턴 실행 실패';

  @override
  String get cliUseTerminal => '대화형 입력이 필요합니다. 계속하려면 터미널을 여세요';

  @override
  String get cliDeleteFailed => '원격 세션 삭제 실패';

  @override
  String get cliDeleteUnsupported => '이 CLI에서는 원격 세션 삭제를 지원하지 않습니다';

  @override
  String get cliOperationFailed => 'CLI 작업 실패';

  @override
  String get cliHistorySdkMissing => '서버에 공식 History SDK가 없습니다';

  @override
  String get cliHistoryRuntimeMissing =>
      'Claude 기록을 보려면 서버에 Node.js/npm이 필요합니다. 수동으로 Node.js를 설치하세요. 터미널의 실제 CLI는 계속 사용할 수 있습니다.';

  @override
  String get cliLoginRequired => '에이전트 로그인이 필요합니다. 에이전트 관리를 통해 로그인하세요.';

  @override
  String get cliNotInstalled => '에이전트 CLI가 설치되지 않았습니다. 에이전트 관리를 통해 설치하세요.';

  @override
  String get cliVersionUnsupported =>
      '에이전트 CLI 버전을 지원하지 않습니다. 에이전트 관리를 통해 업그레이드하거나 다시 설치하세요.';

  @override
  String get settingsNavigation => '탐색';

  @override
  String get settingsNavigationDesc => '기본 시작 페이지 및 하단 탐색 모음 구성';

  @override
  String get settingsStartupPage => '시작 페이지';

  @override
  String get settingsStartupPageDesc => '앱이 열릴 때 표시되는 페이지';

  @override
  String get settingsBottomNav => '하단 탐색 모음';

  @override
  String get settingsBottomNavDesc => '모바일 하단 모음에 표시할 항목 선택 (0~9개 지원)';

  @override
  String get settingsResetSuccess => '모든 설정이 기본값으로 복원되었습니다';

  @override
  String get metricsTrendSubtitle => '최근 ~3분 (최대 60개 샘플)';

  @override
  String get metricsCurrent => '현재';

  @override
  String get metricsPeak => '최고';

  @override
  String get metricsValley => '최저';

  @override
  String get metricsTrendWaiting => '지표 데이터 수집 중...';

  @override
  String get metricsTrendStopped => '데이터 수집 중지됨 (SSH 연결 끊김)';

  @override
  String get dockerActionTerminal => 'Exec 터미널';

  @override
  String get dockerTerminalTitle => '컨테이너 터미널';

  @override
  String get dockerTerminalNotRunning => '컨테이너가 실행 중이 아닙니다';

  @override
  String get setDefaultAgent => '기본값으로 설정';

  @override
  String get defaultBadge => '기본';

  @override
  String get isDefaultAgent => '기본 에이전트';

  @override
  String get setAsDefaultAgent => '이 서버의 기본 에이전트로 설정';

  @override
  String get agentGroupBasic => '기본 정보';

  @override
  String get agentGroupCommands => '명령어';

  @override
  String get agentGroupAuth => '설치 & 인증';

  @override
  String get agentPresetTitle => '프리셋 템플릿';

  @override
  String get resourceProcessList => '프로세스';

  @override
  String get resourceDiskScanning => '루트 디렉터리 검사 중, 몇 초 정도 걸릴 수 있습니다...';

  @override
  String get resourceDiskScanPartial => '권한 또는 시간 초과로 일부 디렉터리를 검사하지 못했습니다';

  @override
  String get resourceDiskDirectories => '최상위 디렉터리 사용량';

  @override
  String get resourceSortCpu => 'CPU순 정렬';

  @override
  String get resourceSortMemory => '메모리순 정렬';

  @override
  String get resourceRss => 'RSS 메모리';

  @override
  String get resourceUsed => '사용 중';

  @override
  String get resourceAvailable => '사용 가능';

  @override
  String get resourceTotal => '전체';

  @override
  String get settingsBottomNavOrderTitle => '선택한 항목 (드래그하여 순서 변경)';

  @override
  String get langSystem => '시스템 기본값';

  @override
  String get serverFieldRequired => '필수 항목';

  @override
  String get serverPortInvalid => '포트는 1에서 65535 사이여야 합니다';

  @override
  String get serverTestReachability => '연결 테스트';

  @override
  String get serverSaveFailedGeneric => '서버를 저장하지 못했습니다. 구성을 확인하고 다시 시도하세요.';

  @override
  String get serverViewPrivateKey => '개인 키 보기';

  @override
  String get serverHidePrivateKey => '개인 키 숨기기';

  @override
  String get dockerBashFallbackNotice => '컨테이너에서 Bash를 사용할 수 없어 Sh로 대체합니다';

  @override
  String get dockerShellLabel => '셸';

  @override
  String get dockerShellBash => 'Bash';

  @override
  String get dockerShellSh => 'Sh';

  @override
  String get cliDraftWorkingDirLabel => '작업 디렉터리';

  @override
  String get cliDefaultWorkingDir => '기본값 (/)';

  @override
  String get cliPickWorkingDirTitle => '작업 디렉터리 선택';

  @override
  String get cliClearWorkingDir => '기본값으로 재설정';

  @override
  String get cliBrowseWorkingDir => '찾아보기';

  @override
  String get cliSelectCurrentDir => '이 디렉터리 선택';

  @override
  String get cliNavigateUp => '상위 폴더로 이동';

  @override
  String get chatSessionsTooltip => '세션';

  @override
  String get hardwareSpecsTitle => '하드웨어 & 시스템';

  @override
  String get hardwareCpu => 'CPU';

  @override
  String get hardwareMemory => '메모리';

  @override
  String get hardwareDisk => '루트 디스크';

  @override
  String get hardwareDistribution => 'OS';

  @override
  String get hardwareKernel => '커널';

  @override
  String get hardwareLoading => '하드웨어 사양 불러오는 중...';

  @override
  String get hardwareUnavailable => '하드웨어 사양을 사용할 수 없음';

  @override
  String get hardwareUnknown => '알 수 없음';

  @override
  String get systemInfoTitle => '시스템 정보';

  @override
  String get systemInfoTapHint => 'ASCII 아트를 보려면 탭하세요';

  @override
  String get systemInfoHost => '호스트';

  @override
  String get serverShutdown => '시스템 종료';

  @override
  String get serverShutdownDialogTitle => '서버 시스템 종료 확인';

  @override
  String get serverShutdownDialogMessage =>
      '이 서버를 정말 종료하시겠습니까? 전원이 완전히 꺼지며 수동으로 켤 때까지 원격으로 접근할 수 없습니다.';

  @override
  String get serverShutdownConfirmButton => '지금 종료';

  @override
  String get serverShutdownSubmitting => '종료 명령어 전송 중...';

  @override
  String get serverShutdownAccepted =>
      '종료 명령어가 수락되었습니다. 시스템 종료 완료 여부는 확인되지 않았습니다.';

  @override
  String get serverShutdownUnknown =>
      '종료 결과를 알 수 없습니다. 명령어가 전송되었을 수 있으나 확인되지 않았습니다. 수동으로 확인해 주세요. 자동으로 재시도되지 않습니다.';

  @override
  String get serverShutdownPasswordTitle => '시스템 종료를 위한 Sudo 비밀번호 필요';

  @override
  String get serverShutdownPasswordMessage =>
      '서버를 종료하려면 루트 권한이 필요합니다. sudo 비밀번호를 입력하세요 (1회 사용, 저장되지 않음):';

  @override
  String get serverShutdownPasswordHint => 'Sudo 비밀번호';

  @override
  String get serverShutdownServerChanged => '대상 서버가 변경되어 시스템 종료가 취소되었습니다';

  @override
  String get metricsNetwork => '네트워크 속도';

  @override
  String get networkModalTitle => '네트워크 인터페이스 세부 정보';

  @override
  String get networkDownloadRate => '다운로드 (RX)';

  @override
  String get networkUploadRate => '업로드 (TX)';

  @override
  String get networkTotalRx => '총 수신 (RX)';

  @override
  String get networkTotalTx => '총 송신 (TX)';

  @override
  String get networkPrimary => '기본 경로';

  @override
  String get networkRatesEmpty => '활성 네트워크 인터페이스가 감지되지 않았습니다';

  @override
  String get networkWaitingSecondSample => '두 번째 샘플 대기 중';

  @override
  String get networkUnavailable => '사용할 수 없음';

  @override
  String get networkNoDefaultInterface => '기본 경로 없음';

  @override
  String get selectThemeModeTitle => '테마 모드 선택';

  @override
  String get selectLanguageTitle => '언어 선택';

  @override
  String get selectStartupPageTitle => '시작 페이지 선택';

  @override
  String get selectAutoConnectModeTitle => '자동 연결 모드 선택';

  @override
  String get accentColorDialogTitle => '강조 색상 사용자 지정';

  @override
  String get accentColorLightMode => '라이트 모드';

  @override
  String get accentColorDarkMode => '다크 모드';

  @override
  String get accentColorAmoledMode => 'AMOLED (긱)';

  @override
  String get accentColorPresets => '프리셋';

  @override
  String get accentColorHsvPicker => '색상 휠';

  @override
  String get accentColorHexCode => 'Hex 색상';

  @override
  String get accentColorPreview => '미리보기';

  @override
  String get accentColorSampleButton => '강조 버튼';

  @override
  String get accentColorInvalidHex => '잘못된 Hex 형식 (예: #10B981)';

  @override
  String get settingsDashboardQuickActions => '대시보드 빠른 동작';

  @override
  String get settingsDashboardQuickActionsDesc =>
      '대시보드에 표시할 바로가기 항목을 구성합니다. 비워 두면 빠른 동작 섹션이 숨겨집니다.';

  @override
  String get settingsDashboardQuickActionsEmpty => '빠른 동작 숨김 (선택된 바로가기 없음)';

  @override
  String get settingsDashboardQuickActionsOrderTitle => '드래그하여 바로가기 순서 변경';

  @override
  String get settingsDashboardQuickActionsCandidates => '표시할 바로가기 선택';

  @override
  String get terminalCopySelection => '복사';

  @override
  String get terminalSelectionCopied => '선택 영역이 클립보드에 복사되었습니다';

  @override
  String get editAgent => '에이전트 수정';

  @override
  String get agentExecutionTarget => '실행 환경';

  @override
  String get agentExecutionHost => '호스트 시스템';

  @override
  String get agentExecutionDocker => 'Docker 컨테이너';

  @override
  String get agentContainerBinding => '컨테이너 바인딩 모드';

  @override
  String get agentContainerBindingId => '컨테이너 ID 기준';

  @override
  String get agentContainerBindingName => '컨테이너 이름 기준';

  @override
  String get agentContainerReference => '대상 컨테이너';

  @override
  String get agentContainerReferenceHint => '컨테이너 ID 또는 이름을 선택하거나 입력하세요';

  @override
  String get agentContainerRequired => 'Docker 실행을 위해 대상 컨테이너가 필요합니다';

  @override
  String get agentLoadingContainers => '서버에서 컨테이너 조회 중...';

  @override
  String get agentNoContainersFound => '이 서버에서 컨테이너를 찾을 수 없습니다';

  @override
  String get agentContainerUser => '컨테이너 실행 사용자 (선택사항)';

  @override
  String get agentContainerUserHint => '예: dev';

  @override
  String get agentContainerUserHelper =>
      '이미지 기본 사용자를 사용하려면 비워 두세요. 예: dev; user, UID, user:group, UID:GID 지원';

  @override
  String get agentContainerUserSelect => '컨테이너 사용자 선택';

  @override
  String get agentContainerUsersLoading => '사용자 불러오는 중...';

  @override
  String get agentContainerUsersEmpty => 'passwd 사용자를 찾을 수 없습니다';

  @override
  String get agentViewDiagnosticLog => '진단 로그 보기';

  @override
  String get agentDiagnosticLogCopied => '진단 로그가 클립보드에 복사되었습니다';

  @override
  String get agentDiagnosticLogCopy => '복사';

  @override
  String get agentDiagnosticLogClose => '닫기';

  @override
  String get settingsCliHistoryPageSize => 'CLI 기록 페이지 크기';

  @override
  String get settingsCliHistoryPageSizeDesc =>
      '위로 스크롤할 때 페이지당 불러올 이전 메시지 수 (5-100)';

  @override
  String get settingsCliHistoryPageSizeTitle => 'CLI 기록 페이지 크기 선택';

  @override
  String get cliLoadingOlderMessages => '이전 메시지 불러오는 중...';

  @override
  String get chatLoadOlderMessages => '이전 메시지 불러오기';

  @override
  String get chatCommandsTooltip => '명령어';

  @override
  String get chatAttachTooltip => '파일 첨부';

  @override
  String get chatAttachImage => '로컬 이미지 첨부';

  @override
  String get chatAttachLocalText => '로컬 텍스트 파일 첨부';

  @override
  String get chatAttachRemoteText => '원격 텍스트 파일 첨부';

  @override
  String get chatAttachRemotePathTitle => '원격 텍스트 파일 첨부';

  @override
  String get chatAttachRemotePathHint => '/path/to/file.txt';

  @override
  String get chatAttachTooLarge => '파일 크기 제한을 초과했습니다';

  @override
  String get chatUsageAndDiagnostics => '사용량 & 진단';

  @override
  String get chatWorkingDirTooltip => '초안 작업 디렉터리';

  @override
  String get chatAttachFailed => '파일 첨부 실패';

  @override
  String get chatInvalidRemotePath => '잘못된 원격 파일 경로 (/로 시작해야 함)';

  @override
  String get chatRemoteReadFailed => '원격 파일을 읽지 못했습니다';

  @override
  String get chatInvalidDirPath => '잘못된 디렉터리 경로 (/로 시작해야 함)';

  @override
  String get chatNoSubdirectories => '하위 디렉터리 없음';

  @override
  String get chatUsageTitle => '토큰 & 비용 사용량';

  @override
  String get chatUsageUsed => '사용된 토큰';

  @override
  String get chatUsageSize => '컨텍스트 크기';

  @override
  String get chatUsageCost => '비용';

  @override
  String get chatDiagnosticsTitle => '진단 로그';

  @override
  String get chatNoDiagnostics => '사용 가능한 진단 로그가 없습니다';

  @override
  String get deleteSessionLocalOnlyNotice =>
      '이는 Valhalla의 로컬 기록만 제거하며 서버의 네이티브 에이전트 세션 기록은 삭제되지 않습니다.';

  @override
  String get chatSearchSessionsHint => '세션 검색...';

  @override
  String get chatLoadMoreSessions => '세션 더 불러오기';

  @override
  String get chatLoadingMoreSessions => '세션 더 불러오는 중...';

  @override
  String get chatExportSession => '세션 내보내기 (Markdown)';

  @override
  String get chatExportSuccess => '세션을 성공적으로 내보냈습니다';

  @override
  String get chatExportFailed => '세션 내보내기 실패';

  @override
  String get chatRemoteSessions => '원격 세션';

  @override
  String get chatRemoteSessionsTitle => '원격 에이전트 세션';

  @override
  String get chatRemoteSessionsDesc => '원격 에이전트의 네이티브 세션 기록 보기 및 가져오기';

  @override
  String get chatRemoteSessionsEmpty => '원격 세션을 찾을 수 없습니다';

  @override
  String get chatRemoteImporting => '원격 세션 기록 가져오는 중...';

  @override
  String get chatRemoteImportFailed => '원격 세션 가져오기 실패';

  @override
  String get chatStatusInterrupted => '중단됨';

  @override
  String get chatStatusFailed => '실패함';

  @override
  String get chatStatusAwaitingAuth => 'ACP 인증 대기 중';

  @override
  String get chatShowFullOutput => '전체 출력 보기';

  @override
  String get chatShowLessOutput => '간략히 보기';

  @override
  String get chatToolLocations => '영향을 받는 경로';

  @override
  String cmdParamPlaceholder(String param) {
    return '$param의 값을 입력하세요';
  }

  @override
  String processTerminateSuccess(Object pid) {
    return '프로세스 $pid 종료됨';
  }

  @override
  String serviceActionSuccess(Object action, Object service) {
    return '$service에 대한 $action 작업 성공';
  }

  @override
  String riskPatternMatched(Object pattern) {
    return '트리거된 규칙: $pattern';
  }

  @override
  String stateExitCode(Object code) {
    return '종료 코드: $code';
  }

  @override
  String sshConnectedSuccess(Object server) {
    return 'SSH를 통해 $server에 성공적으로 연결되었습니다';
  }

  @override
  String sshConnectionFailed(Object error) {
    return 'SSH 연결 실패: $error';
  }

  @override
  String trustHostFingerprintMessage(
    Object fingerprint,
    Object host,
    Object type,
  ) {
    return '$host ($type)에 처음 연결합니다.\n\nSHA-256 지문:\n$fingerprint\n\n이 지문을 신뢰하고 연결하시겠습니까?';
  }

  @override
  String enterPasswordTitle(Object server) {
    return '$server의 비밀번호 입력';
  }

  @override
  String confirmDeleteServerMessage(Object name) {
    return '서버 \'$name\'을(를) 정말 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';
  }

  @override
  String deleteAgentMessage(Object name) {
    return '에이전트 \'$name\'을(를) 정말 삭제하시겠습니까? 이전 채팅 세션이나 SSH 자격 증명에 영향을 주지 않고 이 서버의 구성 및 런타임 상태만 제거합니다.';
  }

  @override
  String agentLastChecked(Object time) {
    return '마지막 확인: $time';
  }

  @override
  String agentAuthPickerTitle(Object agent) {
    return '$agent 로그인 방식 선택';
  }

  @override
  String sshStatusReconnecting(Object n) {
    return '다시 연결 중… ($n번째 시도)';
  }

  @override
  String sshKeepAliveNotificationBody(Object n) {
    return '$n개의 활성 세션';
  }

  @override
  String bindServerConfirmMessage(Object serverName) {
    return '이 세션을 \\\"$serverName\\\" 서버에 바인딩하시겠습니까? 바인딩된 후 이 세션은 해당 서버와 연결됩니다.';
  }

  @override
  String deleteSessionConfirmMessage(Object title) {
    return '세션 \\\"$title\\\"(을)를 정말 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';
  }

  @override
  String dockerActionSuccess(Object action, Object name) {
    return '컨테이너 $name $action 성공';
  }

  @override
  String dockerActionFailed(Object error) {
    return '작업 실패: $error';
  }

  @override
  String serverRebootTarget(Object address, Object name) {
    return '대상 서버: $name ($address)';
  }

  @override
  String serverRebootRunningTerminals(Object count) {
    return '터미널 세션: $count';
  }

  @override
  String serverRebootRunningAgents(Object count) {
    return '에이전트 세션: $count';
  }

  @override
  String serverRebootRunningTransfers(Object count) {
    return '활성 전송: $count';
  }

  @override
  String serverRebootFailed(Object error) {
    return '재부팅 실패: $error';
  }

  @override
  String cliDeleteFailedWithDetail(Object detail) {
    return '원격 세션 삭제 실패: $detail';
  }

  @override
  String metricsTrendTitle(Object metric) {
    return '$metric 추세';
  }

  @override
  String metricsThresholdWarning(Object value) {
    return '경고: $value';
  }

  @override
  String metricsThresholdDanger(Object value) {
    return '위험: $value';
  }

  @override
  String metricsHistoryPoints(Object count) {
    return '데이터 포인트 $count개';
  }

  @override
  String resourceUsageTitle(Object metric) {
    return '$metric 리소스 사용량';
  }

  @override
  String serverPortReachable(Object port) {
    return 'TCP 포트 $port 연결 가능';
  }

  @override
  String serverConnectionFailed(Object error) {
    return '연결 실패: $error';
  }

  @override
  String serverSaveFailed(Object error) {
    return '서버 저장 실패: $error';
  }

  @override
  String hardwareCpuCores(Object cores) {
    return '$cores 코어';
  }

  @override
  String serverShutdownFailed(Object error) {
    return '시스템 종료 실패: $error';
  }

  @override
  String networkInterface(Object name) {
    return '인터페이스: $name';
  }

  @override
  String agentContainersLoadFailed(Object error) {
    return '컨테이너 불러오기 실패: $error';
  }

  @override
  String agentContainerUsersFailed(Object error) {
    return '컨테이너 사용자 불러오기 실패: $error';
  }

  @override
  String agentDiagnosticLogTitle(Object name) {
    return '진단 로그 - $name';
  }

  @override
  String get agentDockerDetectionFailed => 'Docker/컨테이너 감지 실패';

  @override
  String get chatCopiedAllMessages => '모든 메시지가 복사되었습니다';

  @override
  String get chatCopyAllMessages => '모든 메시지 복사';

  @override
  String get cliModelAtCapacity => '선택한 모델의 용량이 초과되었습니다. 다른 모델을 시도해 보세요.';

  @override
  String get chatLaunchBlankDraft => '빈 초안';

  @override
  String get chatLaunchFixedSession => '고정 세션';

  @override
  String get chatLaunchRememberLast => '마지막 세션 기억';

  @override
  String get chatPermissionAskEveryTime => '매번 묻기';

  @override
  String get chatPermissionAutoAllowAll => '모두 자동 허용';

  @override
  String get chatPermissionAutoAllowAllConfirmMessage =>
      '에이전트가 묻지 않고 모든 작업을 실행합니다. 계속하시겠습니까?';

  @override
  String get chatPermissionAutoAllowAllConfirmTitle => '모든 작업을 허용하시겠습니까?';

  @override
  String get chatPermissionAutoAllowSafe => '안전한 작업 자동 허용';

  @override
  String get chatRunSettingsDefault => '기본값';

  @override
  String get chatRunSettingsInteractiveCli => '대화형 CLI';

  @override
  String get chatRunSettingsModel => '모델';

  @override
  String get chatRunSettingsPermissions => '권한';

  @override
  String get chatRunSettingsReasoning => '추론 수준';

  @override
  String get chatRunSettingsTitle => '실행 설정';

  @override
  String get cliActionInsertCommand => '명령어 삽입';

  @override
  String get cliActionInsertFile => '파일 삽입';

  @override
  String get cliActionInsertWorkdir => '작업 디렉터리 삽입';

  @override
  String get cliComposerInsertAction => '삽입';

  @override
  String cliOperationFailedWithDetail(String detail) {
    return 'CLI 작업 실패: $detail';
  }

  @override
  String get cliSelectCommandTitle => '명령어 선택';

  @override
  String get defaultAgentTitle => '기본 에이전트';

  @override
  String get insertSkills => '스킬 삽입';

  @override
  String get isDefaultSession => '기본 세션';

  @override
  String get sessionLaunchMode => '세션 실행 모드';

  @override
  String get setAsDefaultSession => '기본 세션으로 설정';

  @override
  String get navNas => 'NAS 미디어';

  @override
  String get nasAddExcludePath => '제외할 경로 추가';

  @override
  String get nasAddIncludePath => '검사 경로 추가';

  @override
  String get nasCancelScan => '검사 취소';

  @override
  String get nasClearSearch => '검색 지우기';

  @override
  String get nasConfigDialogTitle => '미디어 라이브러리 설정';

  @override
  String get nasConfigure => '구성';

  @override
  String get nasConfigureScanDirs => '검사 폴더 구성';

  @override
  String get nasCreatePlaylist => '재생목록 생성';

  @override
  String get nasEmptyConfigDesc => '미디어 라이브러리 구축을 시작하려면 폴더를 하나 이상 추가하세요.';

  @override
  String get nasEmptyConfigTitle => '구성된 검사 폴더 없음';

  @override
  String get nasExcludePaths => '제외된 폴더';

  @override
  String get nasExcludedBadge => '제외됨';

  @override
  String get nasFilterImages => '사진';

  @override
  String get nasFilterVideos => '동영상';

  @override
  String get nasIncludePaths => '검사 폴더';

  @override
  String nasItemCount(Object value) {
    return '항목 $value개';
  }

  @override
  String nasLastScan(Object value) {
    return '마지막 검사: $value';
  }

  @override
  String get nasLibrarySettings => '라이브러리 설정';

  @override
  String nasMediaOpening(Object value) {
    return '$value 여는 중…';
  }

  @override
  String get nasMiniPlayer => '미니 플레이어';

  @override
  String get nasNoExcludePaths => '제외된 폴더 없음';

  @override
  String get nasNoFavorites => '아직 즐겨찾기가 없습니다';

  @override
  String get nasNoIncludePaths => '검사 폴더 없음';

  @override
  String get nasNoIndexDesc => '미디어를 색인화하려면 폴더를 구성하고 검사를 실행하세요.';

  @override
  String get nasNoIndexTitle => '미디어 라이브러리가 비어 있습니다';

  @override
  String get nasNoPlaylists => '아직 재생목록이 없습니다';

  @override
  String get nasNoSearchResults => '일치하는 미디어가 없습니다';

  @override
  String get nasNotScanned => '아직 검사되지 않음';

  @override
  String get nasNowPlaying => '현재 재생 중';

  @override
  String get nasOpenMethodPrompt => '이 파일을 어떻게 여시겠습니까?';

  @override
  String get nasOpenPolicyAsk => '매번 묻기';

  @override
  String get nasOpenPolicyExternal => '다른 앱으로 열기';

  @override
  String get nasOpenPolicyInApp => '앱 내에서 열기';

  @override
  String get nasOpeningPolicy => '기본 열기 방식';

  @override
  String get nasPlaylistName => '재생목록 이름';

  @override
  String get nasQuickStats => '라이브러리 개요';

  @override
  String get nasScan => '지금 검사';

  @override
  String get nasScanCancelled => '검사 취소됨';

  @override
  String nasScanFailed(Object value) {
    return '검사 실패: $value';
  }

  @override
  String get nasScanning => '검사 중…';

  @override
  String get nasScopeBadge => '검사 범위';

  @override
  String get nasSearchHint => '미디어 검색';

  @override
  String get nasStatMusic => '음악';

  @override
  String get nasStatPhotos => '사진';

  @override
  String get nasStatTotal => '전체';

  @override
  String get nasStatVideos => '동영상';

  @override
  String get nasTabFavorites => '즐겨찾기';

  @override
  String get nasTabFolders => '폴더';

  @override
  String get nasTabHome => '홈';

  @override
  String get nasTabMusic => '음악';

  @override
  String get nasTabPhotos => '사진';

  @override
  String get nasTabPlaylists => '재생목록';

  @override
  String get nasTabVideos => '동영상';

  @override
  String get nasSources => '미디어 소스';

  @override
  String get nasAddSource => '미디어 소스 추가';

  @override
  String get nasEditSource => '미디어 소스 수정';

  @override
  String get nasRemoveSource => '미디어 소스 제거';

  @override
  String nasRemoveSourceConfirm(Object name) {
    return '미디어 소스 \'$name\'을(를) 정말 제거하시겠습니까? 원격 파일을 삭제하지 않고 구성만 제거합니다.';
  }

  @override
  String get nasNoSources => '구성된 미디어 소스 없음';

  @override
  String get nasNoSourcesDesc =>
      'SFTP, SMB, WebDAV, Jellyfin 또는 Emby를 추가하여 미디어 탐색을 시작하세요.';

  @override
  String get nasSourceType => '소스 유형';

  @override
  String get nasSourceName => '소스 이름';

  @override
  String get nasProbe => '연결 테스트';

  @override
  String get nasProbeSuccess => '연결 성공';

  @override
  String get nasProbeFailed => '연결 테스트 실패';

  @override
  String get nasEndpoint => '엔드포인트 / URL';

  @override
  String get nasRootPath => '루트 경로';

  @override
  String get nasUsername => '사용자 이름';

  @override
  String get nasPassword => '비밀번호';

  @override
  String get nasDomain => '도메인 (선택사항)';

  @override
  String get nasAuthenticate => '인증';

  @override
  String get nasAuthSuccess => '인증 성공';

  @override
  String get nasAuthFailed => '인증 실패';

  @override
  String get nasTabDownloads => '다운로드';

  @override
  String get nasNoDownloads => '다운로드 작업 없음';

  @override
  String get nasDownloadQueued => '대기 중';

  @override
  String get nasDownloadDownloading => '다운로드 중';

  @override
  String get nasDownloadCompleted => '완료됨';

  @override
  String get nasDownloadCancelled => '취소됨';

  @override
  String get nasDownloadFailed => '다운로드 실패';

  @override
  String get nasRetryDownload => '다시 시도';

  @override
  String get nasCancelDownload => '취소';

  @override
  String get nasOpenDownloadedFile => '파일 열기';

  @override
  String get nasQueue => '재생 대기열';

  @override
  String get nasNoQueue => '대기열이 비어 있습니다';

  @override
  String get nasSpeed => '속도';

  @override
  String get nasQuality => '화질';

  @override
  String get nasAudioTrack => '오디오 트랙';

  @override
  String get nasSubtitleTrack => '자막';

  @override
  String get nasRepeatOff => '반복 끔';

  @override
  String get nasRepeatAll => '전체 반복';

  @override
  String get nasRepeatOne => '한 곡 반복';

  @override
  String get nasShuffle => '셔플';

  @override
  String get nasCast => '전송 (Cast)';

  @override
  String get nasCastUnavailable => '사용 가능한 전송 기기가 없습니다';

  @override
  String get nasSlideshow => '슬라이드쇼';

  @override
  String get nasByFolder => '폴더';

  @override
  String get nasByArtist => '아티스트';

  @override
  String get nasByAlbum => '앨범';

  @override
  String get nasAllTracks => '모든 트랙';

  @override
  String get nasPlayAll => '모두 재생';

  @override
  String get nasPreviousPage => '이전';

  @override
  String get nasNextPage => '다음';

  @override
  String get nasClearScope => '전체로 돌아가기';

  @override
  String get nasRenamePlaylist => '재생목록 이름 바꾸기';

  @override
  String get nasRemoveFromPlaylist => '재생목록에서 제거';

  @override
  String get nasMoveUp => '위로 이동';

  @override
  String get nasMoveDown => '아래로 이동';

  @override
  String get nasSshServer => 'SSH 서버';

  @override
  String get nasSelectSshServer => '저장된 SSH 서버 선택';

  @override
  String get nasQualityOriginal => '원본';

  @override
  String get nasQualityAuto => '자동';

  @override
  String get nasQuality4Mbps => '4 Mbps';

  @override
  String get nasQuality10Mbps => '10 Mbps';

  @override
  String get nasQuality20Mbps => '20 Mbps';

  @override
  String get nasCastDevices => '사용 가능한 DLNA 기기';

  @override
  String get nasCastDiscovering => 'DLNA 기기 검색 중...';

  @override
  String get nasCastRelayingNotice =>
      '포그라운드 앱을 통해 스트림을 릴레이합니다. Valhalla를 열어 두세요.';

  @override
  String get nasCastStop => '전송 중지';

  @override
  String get nasCastVolume => '볼륨';

  @override
  String get nasCastRetry => '검색 다시 시도';

  @override
  String get nasInstallTitle => 'NAS 미디어 서버 배포';

  @override
  String get nasInstallProduct => '제품';

  @override
  String get nasInstallMediaPath => '미디어 디렉터리 (읽기 전용)';

  @override
  String get nasInstallDataRoot => '데이터 & 구성 디렉터리';

  @override
  String get nasInstallPort => '포트';

  @override
  String get nasInstallBindAddress => '바인드 주소';

  @override
  String get nasInstallWebdavUser => 'WebDAV 사용자 이름';

  @override
  String get nasInstallWebdavPassword => 'WebDAV 비밀번호 (최소 12자)';

  @override
  String get nasInstallPreparePlan => '배포 계획 검토';

  @override
  String get nasInstallPlanTitle => '기술 검토 & 확인';

  @override
  String get nasInstallBlockersTitle => '배포 차단 항목';

  @override
  String get nasInstallConfirmDeploy => '확인 & 설치';

  @override
  String get nasInstallDeploying => '컨테이너 배포 중...';

  @override
  String get nasInstallSuccess => '배포 성공';

  @override
  String get nasInstallSuccessDesc =>
      '서비스가 실행 중입니다. 미디어 소스로 추가하기 전에 서버 초기 설정을 완료하세요.';

  @override
  String get nasInstallContainerId => '컨테이너 ID';

  @override
  String get nasInstallEndpoint => '엔드포인트';

  @override
  String get nasUseSshTunnel => 'SSH 터널 사용';

  @override
  String get nasUseSshTunnelDesc =>
      '저장된 SSH 서버를 통해 트래픽 라우팅 (예: http://127.0.0.1:8096)';

  @override
  String get nasSshTunnelHint =>
      '엔드포인트는 SSH 서버에서 접근 가능해야 합니다 (예: http://127.0.0.1:8096)';

  @override
  String get nasKeepEmptyPassword => '기존 비밀번호 / 토큰을 유지하려면 비워 두세요';

  @override
  String get nasSourceNameRequired => '소스 이름이 필요합니다';

  @override
  String get nasInvalidEndpoint => '잘못된 엔드포인트 URL 또는 스킴';

  @override
  String get nasSourceUnreachable => '미디어 소스에 연결할 수 없습니다';

  @override
  String get nasSshTunnelFailed => 'SSH 터널 연결 실패';

  @override
  String get nasOperationFailed => '작업 실패';

  @override
  String get nasInstallStepCreateDir => '비공개 디렉터리 생성';

  @override
  String get nasInstallStepWriteCompose => 'docker-compose.json 구성 작성';

  @override
  String get nasInstallStepWriteCreds => '개인 자격 증명 작성';

  @override
  String get nasInstallStepPullImage => '고정된 컨테이너 이미지 풀';

  @override
  String get nasInstallStepStartService => '컨테이너화된 서비스 시작';

  @override
  String get nasInstallStepCheckHttp => '서비스 HTTP 상태 확인';

  @override
  String get nasInstallBlockerDocker => '대상 서버에 Docker Engine이 필요합니다';

  @override
  String get nasInstallBlockerCompose => 'Docker Compose 플러그인이 필요합니다';

  @override
  String get nasInstallBlockerIdentity => '대상 서버 ID를 확인할 수 없습니다';

  @override
  String get nasInstallBlockerTools => '대상 서버에 필수 도구(curl, ss, realpath)가 없습니다';

  @override
  String get nasInstallBlockerMedia => '미디어 디렉터리가 없거나 읽을 수 없습니다';

  @override
  String get nasInstallBlockerParent => '데이터 루트의 상위 디렉터리에 쓸 수 없습니다';

  @override
  String get nasInstallBlockerOverlap => '미디어 디렉터리와 데이터 디렉터리는 겹칠 수 없습니다';

  @override
  String get nasInstallBlockerCollision => '대상 데이터 디렉터리가 이미 존재하거나 심볼릭 링크입니다';

  @override
  String get nasInstallBlockerPort => '선택한 포트가 대상 서버에서 이미 사용 중입니다';

  @override
  String get nasInstallBlockerContainer => '이 프로젝트 이름을 가진 컨테이너가 이미 존재합니다';

  @override
  String get nasInstallBlockerImage =>
      '컨테이너 이미지 확인 실패. 이미지 이름, 네트워크 연결 및 서버 아키텍처를 확인한 후 다시 시도하세요.';

  @override
  String get nasInstallGuidanceTunnel =>
      '루프백 바인딩(127.0.0.1)은 원격 접근을 위해 SSH 터널이 필요합니다';

  @override
  String get nasInstallGuidanceTls => '공용 바인딩은 TLS 역방향 프록시 뒤에서 보호하는 것이 좋습니다';

  @override
  String get nasInstallGuidanceSetup => '최초 실행 시 브라우저에서 초기 관리자 계정 설정을 완료하세요';

  @override
  String get nasInstallGuidanceReadOnly =>
      '파일을 안전하게 보호하기 위해 미디어 디렉터리는 읽기 전용으로 마운트됩니다';

  @override
  String get nasInstallGuidancePreserved => '문제 해결을 위해 실패 시에도 데이터 디렉터리는 보존됩니다';

  @override
  String get nasDownloadCompletedWithOpenError => '다운로드됨 (외부 앱으로 열기 실패)';

  @override
  String get nasRetryOpen => '열기 다시 시도';

  @override
  String get nasExternalOpenFailed => '외부 앱에서 파일을 열지 못했습니다';

  @override
  String get nasTitle => 'NAS 미디어';

  @override
  String get nasLoadMoreGroups => '그룹 더 불러오기';

  @override
  String get nasMetadataEnriching => '음악 태그 보강 중...';

  @override
  String nasMetadataEnrichingWithCount(int count) {
    return '음악 태그 보강 중 ($count개 처리됨)...';
  }

  @override
  String nasDownloading(String value) {
    return '$value 다운로드 중…';
  }

  @override
  String get nasSubtitleNone => '없음';

  @override
  String get nasLibraryId => '라이브러리 ID';

  @override
  String get nasLibraryIdHint => '기본값: 전체 (/), 또는 라이브러리 ID 지정';

  @override
  String nasScanPathRelativeHint(String value) {
    return '소스 루트 기준 상대 경로 ($value)';
  }

  @override
  String get nasSourceChangedError => '구성 중 소스가 변경되어 저장이 취소되었습니다';

  @override
  String get nasInvalidLibraryId => '유효하지 않은 라이브러리 ID';

  @override
  String get startupFailed => '애플리케이션을 시작하지 못했습니다';

  @override
  String get startupFailedDesc =>
      '시작 중 예상치 못한 오류가 발생했습니다. 다시 시도하거나 진단 로그를 내보낼 수 있습니다.';

  @override
  String get retryStartup => '시작 다시 시도';

  @override
  String get viewDiagnostics => '진단 보기';

  @override
  String get exportDiagnostics => '진단 내보내기';

  @override
  String diagnosticsExportSuccess(String path) {
    return '$path(으)로 진단 내보내기 성공';
  }

  @override
  String get diagnosticsExportFailed => '진단 내보내기 실패';

  @override
  String get diagnosticsTitle => '앱 진단';

  @override
  String get settingsDiagnostics => '진단 & 로그';

  @override
  String get settingsDiagnosticsDesc => '로컬 애플리케이션 로그 보기 및 내보내기';

  @override
  String get diagnosticsEmpty => '진단 기록을 찾을 수 없습니다';

  @override
  String diagnosticsStorageError(String error) {
    return '진단 저장소 오류: $error';
  }

  @override
  String diagnosticsIncidentNotice(String category) {
    return '복구 가능한 사건 보고됨: $category';
  }

  @override
  String get diagnosticsRefresh => '로그 새로고침';

  @override
  String get nasInstallTaskTitle => '배포 작업';

  @override
  String get nasInstallStagePreflight => '사전 검사';

  @override
  String get nasInstallStageReview => '계획 검토';

  @override
  String get nasInstallStageWriting => '구성 작성 중';

  @override
  String get nasInstallStagePulling => '이미지 다운로드 중';

  @override
  String get nasInstallStageStarting => '컨테이너 시작 중';

  @override
  String get nasInstallStageHealth => '상태 확인 중';

  @override
  String get nasInstallStageCleanup => '정리 중';

  @override
  String get nasInstallStageSucceeded => '배포 성공';

  @override
  String get nasInstallStageFailed => '배포 실패';

  @override
  String get nasInstallStageCancelled => '배포 취소됨';

  @override
  String get nasInstallStageNeedsInspection => '검사 필요';

  @override
  String get nasInstallStageReconciling => '상태 조정 중';

  @override
  String get nasInstallCancel => '배포 취소';

  @override
  String get nasInstallReconcile => '상태 조정';

  @override
  String get nasInstallServerNotFound => '선택한 서버를 찾을 수 없습니다';

  @override
  String get nasInstallPortRangeError => '포트는 1에서 65535 사이여야 합니다';

  @override
  String nasInstallElapsedTime(String time) {
    return '경과 시간: $time';
  }

  @override
  String get nasInstallLogTail => '최근 로그';

  @override
  String get nasInstallCleanupCompleted => '롤백 정리 완료됨';

  @override
  String get nasInstallCleanupIncomplete => '롤백 정리 불완전함';

  @override
  String get nasInstallNewDeployment => '새 배포';

  @override
  String get nasInstallBackEdit => '뒤로 / 양식 수정';

  @override
  String get nasInstallClose => '닫기';

  @override
  String get nasInstallMediaPathHint => '호스트의 읽기 전용 바인드 마운트 (예: /mnt/media)';

  @override
  String get nasInstallDataRootHint => '비공개 데이터 & 구성 디렉터리 (아직 존재하지 않아야 함)';

  @override
  String get nasInstallBindAddressHint => '터널의 경우 127.0.0.1, LAN의 경우 0.0.0.0';

  @override
  String get nasInstallWebdavPasswordHint => '최소 12자 이상 필요';

  @override
  String get nasInstallTargetServer => '대상 서버';

  @override
  String get nasInstallTargetImage => '대상 이미지';

  @override
  String get nasInstallContainerName => '컨테이너 이름';

  @override
  String get nasInstallBindAndPort => '바인드 & 포트';

  @override
  String get nasInstallComposePreview => 'docker-compose.json 미리보기';

  @override
  String get nasInstallPlannedSteps => '계획된 단계';

  @override
  String get nasInstallGuidanceNotes => '배포 참고 사항 & 안내';

  @override
  String get nasInstallNoLogsYet => '아직 로그 없음';

  @override
  String get sftpPreviewTooLarge =>
      '파일이 1 MiB 미리보기 제한을 초과했습니다. 다운로드하여 외부에서 여세요.';

  @override
  String get sftpSaveFailed => '파일 저장 실패. 권한 또는 네트워크 연결을 확인하세요.';

  @override
  String get sftpSaving => '저장 중...';

  @override
  String get nasInstallBlockerConnectionChanged =>
      '대상 서버 연결이 변경되었습니다. 계속하기 전에 원격 상태를 확인하세요.';

  @override
  String get nasInstallBlockerCancelled =>
      '사용자에 의해 배포가 취소되었습니다. 설정을 검토하고 필요시 다시 시도하세요.';

  @override
  String get nasInstallBlockerInspectFailed =>
      '검사에서 원격 컨테이너를 조회하지 못했습니다. 서버 연결을 확인하거나 수동으로 검사하세요.';

  @override
  String get nasInstallBlockerDeadlineExceeded =>
      '배포 단계 시간 초과. 서버 부하 또는 네트워크를 확인하고 다시 시도하세요.';

  @override
  String get nasInstallBlockerInterrupted =>
      '배포가 중단되었습니다. 계속하기 전에 원격 상태를 검토하세요.';

  @override
  String get nasInstallBlockerHealthTimeout =>
      '서비스가 시작되었으나 HTTP 상태 확인 시간이 초과되었습니다. 서비스 로그 또는 포트 가용성을 확인하세요.';

  @override
  String get nasInstallBlockerReconciliationFailed =>
      '조정 실패. 원격 컨테이너 상태를 수동으로 확인하거나 새 배포를 시작하세요.';

  @override
  String get nasInstallBlockerRemoteInspectionRequired =>
      '원격 컨테이너 상태가 불확실합니다. 수동 검사 및 조정을 수행해야 합니다.';

  @override
  String get nasInstallBlockerServiceExited =>
      '컨테이너 프로세스가 조기 종료되었습니다. 구성 또는 권한 오류가 있는지 로그를 확인하세요.';

  @override
  String get nasInstallBlockerWriteFailed =>
      '대상 서버에 배포 파일을 쓰지 못했습니다. 디스크 공간과 권한을 확인하세요.';

  @override
  String get nasInstallBlockerPlanStale => '배포 계획이 만료되었습니다. 사전 검사를 다시 실행하세요.';

  @override
  String get nasInstallBlockerOwnershipChanged =>
      '기존 컨테이너가 이 앱에 의해 생성되지 않았습니다. 덮어쓰기를 방지하려면 수동으로 검사하세요.';

  @override
  String get nasInstallBlockerSshRequired => '대상 서버에 대한 활성 SSH 연결이 필요합니다.';

  @override
  String get nasInstallBlockerReconciliationRequired =>
      '원격 상태가 로컬 상태와 다릅니다. 계속하기 전에 조정하세요.';

  @override
  String get nasInstallBlockerFailed => '배포 중 오류가 발생했습니다. 로그를 확인하고 다시 시도하세요.';

  @override
  String get nasInstallBlockerBusy => '설치 작업이 이미 진행 중입니다. 현재 작업 진행 상황을 확인하세요.';

  @override
  String get nasInstallBlockerStateSaveFailed =>
      '배포 상태 저장 실패. 로컬 저장 공간과 파일 권한을 확인하세요.';

  @override
  String get nasInstallBlockerCommandResultUnknown =>
      '원격 명령어 결과를 알 수 없습니다. 배포를 직접 재시도하는 대신 읽기 전용 검사를 실행하세요.';

  @override
  String get nasInstallBlockerPreflightFailed =>
      '사전 배포 환경 검사 실패. 계속하기 전에 차단 요소를 해결하세요.';

  @override
  String serverDeleteFailed(String error) {
    return '서버 삭제 실패: $error';
  }

  @override
  String get chatRunSettingsAgentMode => '에이전트 모드';

  @override
  String get chatRunSettingsApprovalPolicy => '로컬 승인 정책';

  @override
  String get chatRunSettingsExtraSettings => '추가 설정';

  @override
  String get chatPermissionAutoAllowSafeDesc =>
      '안전하다고 알려진 작업을 자동으로 허용하며, 작업의 안전성을 확인할 수 없을 때마다 묻습니다.';

  @override
  String chatRunSettingsSaveFailed(String error) {
    return '실행 설정 적용 실패: $error';
  }

  @override
  String get chatMessageCopied => '메시지가 클립보드에 복사되었습니다';

  @override
  String get copy => '복사';

  @override
  String get rename => '이름 바꾸기';

  @override
  String get refresh => '새로고침';

  @override
  String get sessionTitle => '세션 제목';

  @override
  String get chatSettingsStale => '만료됨';

  @override
  String get chatSettingsAvailableAfterFirstMessage => '첫 메시지 전송 후 설정 사용 가능';

  @override
  String get chatReimportAsCopy => '복사본으로 다시 가져오기';

  @override
  String get chatSearchCommandsHint => '명령어 또는 스킬 검색...';

  @override
  String get chatCommandsTab => '명령어';

  @override
  String get chatSkillsTab => '스킬';

  @override
  String get chatAccountAndQuotaTitle => '계정 & 할당량';

  @override
  String get chatAccountSectionTitle => '계정';

  @override
  String get chatAccountNotProvided => '보고된 계정 정보 없음';

  @override
  String get chatAccountKind => '유형';

  @override
  String get chatAccountLabel => '라벨';

  @override
  String get chatAccountPlan => '플랜';

  @override
  String get chatAccountEmail => '이메일';

  @override
  String get chatAccountUpdatedAt => '업데이트됨';

  @override
  String get chatQuotaSectionTitle => '할당량 & 상태';

  @override
  String get chatStatusSourceNote => '원시 에이전트 /status 출력';

  @override
  String get chatStatusNotQueried => '아직 상태를 조회하지 않음';

  @override
  String get chatQueryStatusAction => '상태 조회 (/status)';

  @override
  String get chatQueryStatusUnavailable => '현재 세션에서 상태 조회를 사용할 수 없음';

  @override
  String get chatAttachmentMissing => '첨부 파일이 없거나 사용할 수 없음';

  @override
  String get chatViewModeList => '목록';

  @override
  String get chatViewModeCards => '카드';

  @override
  String get chatViewModeGrid => '이미지';

  @override
  String get chatRemoteBrowserTitle => '원격 작업 영역';

  @override
  String get chatSelectDirectory => '디렉터리 선택';

  @override
  String chatAttachSelectedFiles(int count) {
    return '선택한 항목 첨부 ($count)';
  }

  @override
  String get chatNoFilesFound => '파일을 찾을 수 없습니다';

  @override
  String get chatRootDirectory => '루트';

  @override
  String get chatSelectThisDirectory => '이 디렉터리 사용';

  @override
  String get chatAgentVersion => '에이전트 버전';

  @override
  String get chatParentDirectory => '상위 디렉터리';

  @override
  String get chatSearchFilesHint => '파일 검색...';

  @override
  String get chatCommandsEmpty => '에이전트가 제공하는 슬래시 명령어가 없습니다';

  @override
  String get chatSkillsEmpty => '에이전트가 제공하는 스킬이 없습니다';

  @override
  String get chatFileUnsupported => '첨부할 수 없는 파일 형식입니다';

  @override
  String get chatStatusNotProvided => '에이전트에서 상태 조회를 제공하지 않음';

  @override
  String get sessionRecoveryReconnecting => '다시 연결 중...';

  @override
  String get sessionRecoverySyncing => '출력 동기화 중...';

  @override
  String get sessionRecoveryIncomplete => '일부 출력을 복구할 수 없습니다';

  @override
  String get sessionRecoveryFailed => '복구 실패';

  @override
  String get sessionRecoveryRetry => '다시 시도';

  @override
  String get dashboardUpdatesPaused => '업데이트 일시 정지됨';

  @override
  String get chatSettingsIndependentModelUnavailable =>
      'CLI 모델 카탈로그를 현재 사용할 수 없습니다. 모델이 캐시되었거나 CLI 버전으로 제한될 수 있습니다. 모델 이름을 수동으로 입력할 수도 있습니다.';

  @override
  String get chatSettingsModelCatalogNote =>
      '기존 CLI 로그인을 사용하여 CLI 앱 서버에서 모델을 조회합니다. 카탈로그가 캐시되었거나 버전 제한이 있을 수 있으며 수동으로 새로고침하거나 수동 입력으로 전환할 수 있습니다.';

  @override
  String get chatModelCatalogError403 =>
      'CLI 모델 조회 접근 거부됨 (403). CLI 로그인 및 서비스 연결을 확인하거나 모델 이름을 수동으로 입력하세요.';

  @override
  String chatModelCatalogErrorGeneric(String error) {
    return '모델 카탈로그 오류: $error';
  }

  @override
  String get chatModelAuthorizeButton => '모델 카탈로그 승인';

  @override
  String get chatModelAuthorizeConfirmTitle => '모델 카탈로그 승인';

  @override
  String get chatModelAuthorizeConfirmMessage =>
      '대상 호스트/컨테이너에서 모델 카탈로그에 대한 브라우저 인증을 시작합니다. 기존 Codex 로그인 및 터미널 세션은 그대로 유지됩니다. 계속하시겠습니까?';

  @override
  String get chatModelAuthorizing => '브라우저를 통해 승인 중...';

  @override
  String get chatModelAuthorizeCancel => '승인 취소';

  @override
  String get chatCommandsFirstTurnNote =>
      '슬래시 명령어는 세션이 초기화된 후 에이전트 런타임에 의해 알림이 제공되며 이전 일반 대화가 필요하지 않습니다. 초안은 자동으로 세션을 생성하지 않습니다.';

  @override
  String get chatCommandsClientActionRunSettings => '실행 설정';

  @override
  String get chatCommandsClientActionWorkingDirectory => '작업 디렉터리';

  @override
  String get chatCommandsClientActionsSection => '로컬 동작';

  @override
  String get chatRunSettingsModelSourceCatalog => '모델 목록';

  @override
  String get chatRunSettingsModelSourceCustom => '수동 입력';

  @override
  String get chatRunSettingsCustomModelHint => '모델 ID 입력';

  @override
  String get chatRunSettingsCustomModelNotice =>
      '수동 입력한 모델 이름은 검증되지 않으며 에이전트 런타임으로 직접 전송됩니다. 지원되지 않는 모델은 거부될 수 있습니다.';

  @override
  String get chatRunSettingsCustomModelEmptyError => '모델 이름은 비워둘 수 없습니다';

  @override
  String get chatRunSettingsCustomModelInvalidError =>
      '모델 이름은 공백이나 제어 문자 없이 최대 256자여야 합니다';

  @override
  String get chatCommandsDraftPreviewNotice =>
      '현재 어댑터 버전에 대해 확인된 명령어입니다. 선택하면 텍스트가 초안에 삽입되며 전송 시 온디맨드로 세션을 초기화하고 명령어를 직접 실행합니다.';

  @override
  String get chatCommandsDiscoveryFailed => '명령어 또는 스킬 검색 실패';

  @override
  String get chatAuthWaitingForBrowser => '브라우저에서 인증 대기 중...';

  @override
  String get chatAuthBrowserLaunchFailed =>
      '외부 브라우저를 열 수 없습니다. 다시 열거나 아래 인증 링크를 복사하세요.';

  @override
  String get chatAuthReopenBrowser => '브라우저 다시 열기';

  @override
  String get chatAuthCopyLink => '링크 복사';

  @override
  String get chatAuthManualCallback => '수동 콜백';

  @override
  String get chatAuthManualCallbackTitle => '인증 콜백 URL 입력';

  @override
  String get chatAuthManualCallbackDesc =>
      '인증을 완료하려면 브라우저에서 리디렉션된 전체 URL(http://127.0.0.1:PORT/...?code=...&state=...)을 붙여넣으세요. 원시 인증 코드는 허용되지 않습니다.';

  @override
  String get chatAuthCallbackInputLabel => '콜백 URL';

  @override
  String get chatAuthCallbackInputHint =>
      'http://127.0.0.1:PORT/...?code=...&state=...';

  @override
  String get chatAuthCallbackInvalidError => '잘못된 콜백 URL 형식이거나 전달에 실패했습니다';

  @override
  String get agentAuthAgYNotice =>
      'Antigravity ACP는 터미널 CLI 로그인과 별도로 공식 계정 인증이 필요합니다.';

  @override
  String get chatAuthDiscoveryPrompt =>
      '이 턴에는 ACP 인증이 필요합니다. 계속하려면 다시 연결하고 인증을 요청하세요.';

  @override
  String get chatRequestAuthButton => '인증 요청';

  @override
  String get agentActionAcpLogin => 'ACP 로그인';

  @override
  String get agentActionCliLogin => 'CLI 로그인';

  @override
  String get agentAgyAcpSignInRequired => 'ACP 자격 증명 누락됨 (ACP 로그인 필요)';

  @override
  String get agentAgyAcpCredentialsSaved => 'ACP 자격 증명 저장됨 (확인되지 않음)';

  @override
  String get chatAuthMethodUnavailable => '선택한 인증 방식을 사용할 수 없습니다.';

  @override
  String get chatAuthConnectionExpired => '인증 연결이 만료되었습니다. 다시 시도해 주세요.';

  @override
  String get chatAuthCallbackDeliveryFailed => '서버로 인증 콜백 전달 실패.';

  @override
  String get agentTargetChangedNotice =>
      '대상 서버가 변경되었습니다. 현재 서버에서 에이전트 관리를 다시 여세요.';

  @override
  String get agentAgyAuthCheckUnavailable => 'Antigravity 인증 확인 불가';

  @override
  String get agentAgyAuthCheckInvalid => 'Antigravity 인증 확인 응답이 올바르지 않음';

  @override
  String get sftpDownloadDisconnected => '다운로드 연결 끊김';

  @override
  String get sftpDownloadPermissionDenied => '권한 거부됨';

  @override
  String get sftpDownloadNotFound => '원격 파일을 찾을 수 없습니다';

  @override
  String get sftpDownloadTimeout => '다운로드 시간 초과';

  @override
  String get sftpDownloadLocalSpace => '로컬 저장 공간 부족';

  @override
  String get sftpDownloadLocalIo => '로컬 저장소 쓰기 실패';

  @override
  String get sftpDownloadIncomplete => '불완전한 다운로드';

  @override
  String get transferStatusWaitingConnection => '연결 대기 중';

  @override
  String get chatAuthCallbackListenerFailed =>
      '로컬 인증 콜백 수신기 시작 실패. 인증을 다시 시도하세요.';

  @override
  String get settingsExperimentalFeatures => '실험적 기능';

  @override
  String get settingsExperimentalFeaturesDesc => '미리보기 및 실험적 기능 사용해 보기';

  @override
  String get settingsExperimentalCliChatTitle => 'CLI 스마트 채팅';

  @override
  String get settingsExperimentalCliChatDesc => '전용 명령줄 에이전트 채팅 인터페이스 활성화';

  @override
  String get settingsExperimentalDialogClose => '닫기';

  @override
  String get settingsExperimentalSaveFailed => '실험적 기능 설정 업데이트 실패';

  @override
  String get settingsExperimentalNasTitle => 'NAS 미디어';

  @override
  String get settingsExperimentalNasDesc => '미디어 라이브러리, 폴더 검사 및 오디오 재생 활성화';

  @override
  String get settingsLanguageSaveFailed => '언어 설정 업데이트 실패';

  @override
  String get settingsAboutPrivacy => '정보 및 개인정보';

  @override
  String get privacyPolicyTitle => '개인정보 처리방침';

  @override
  String get privacyPolicyDescription => '데이터 사용 및 선택 사항';

  @override
  String get privacyContactTitle => '개인정보 문의';

  @override
  String get privacyCopyEmail => '이메일 주소 복사';

  @override
  String get privacyEmailCopied => '이메일 주소를 복사했습니다';

  @override
  String get privacyOnlineVersion => '온라인 버전 보기';

  @override
  String get privacyLinkFailed => '링크를 열 수 없습니다. 이메일 주소를 복사할 수 있습니다.';

  @override
  String get privacyLoadFailed => '처리방침을 불러올 수 없습니다. 온라인 버전을 확인하세요.';

  @override
  String get privacyVersionUnknown => '버전 정보 없음';

  @override
  String get aboutWebsite => '공식 웹사이트';

  @override
  String get aboutLicense => '앱 라이선스';

  @override
  String get aboutThirdPartyLicenses => '타사 오픈 소스 라이선스';

  @override
  String get aboutLicenseSummary =>
      'Valhalla의 자체 콘텐츠에는 비상업용 PolyForm Noncommercial 1.0.0 라이선스가 적용됩니다. 라이선스 허용 범위를 벗어나는 상업적 사용에는 별도 승인이 필요합니다. 타사 구성 요소에는 해당 라이선스가 적용됩니다. 아래 전체 약관이 사용 조건을 규정합니다.';

  @override
  String get aboutCopyrightNotice => '저작권 고지';

  @override
  String get aboutLicenseLoadFailed =>
      '라이선스를 불러올 수 없습니다. norns.soft@gmail.com으로 문의하세요.';

  @override
  String get aboutLinkFailed =>
      '링크를 열 수 없습니다. 브라우저에서 https://norns.cc.cd에 접속하세요.';

  @override
  String get downloadReveal => '파일 탐색기에 표시';

  @override
  String get downloadRevealFailed => '다운로드 폴더를 열 수 없습니다. 이동되었거나 삭제되었을 수 있습니다.';
}
