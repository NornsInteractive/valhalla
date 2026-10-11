// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => 'Valhalla';

  @override
  String get appSubtitle => 'AI ネイティブ サーバー & エージェント管理';

  @override
  String get navAiChat => 'AI チャット';

  @override
  String get navTerminal => 'ターミナル';

  @override
  String get navFiles => 'SFTP ファイル';

  @override
  String get navCommands => 'コマンド';

  @override
  String get navSettings => '設定';

  @override
  String get serverConnected => '接続済み';

  @override
  String get serverOnline => 'オンライン';

  @override
  String get serverOffline => 'オフライン';

  @override
  String get latencyMs => 'ms';

  @override
  String get reconnect => '再接続';

  @override
  String get disconnect => '切断';

  @override
  String get quickDisconnect => 'クイック切断';

  @override
  String get newSession => '新規セッション';

  @override
  String get historySessions => 'セッション履歴';

  @override
  String get switchAgent => 'エージェント切り替え';

  @override
  String get agentClaudeCode => 'Claude CodeX';

  @override
  String get agentCodex => 'OpenAI Codex';

  @override
  String get agentOpenCode => 'OpenCode ACP';

  @override
  String get agentGemini => 'Gemini CLI';

  @override
  String get activeAgent => '有効なエージェント';

  @override
  String get inputPromptHint => 'エージェントに診断、ツールの実行、コマンドの作成を依頼... (Enterで送信)';

  @override
  String get thinking => '思考プロセス';

  @override
  String get executionPlan => '実行プラン';

  @override
  String get toolCall => 'ツール呼び出し';

  @override
  String get toolStatusPending => '保留中';

  @override
  String get toolStatusRunning => '実行中...';

  @override
  String get toolStatusCompleted => '完了';

  @override
  String get toolStatusFailed => '失敗';

  @override
  String get permissionRequired => '権限が必要です';

  @override
  String get permissionDescription => 'エージェントがサーバー上でこのコマンドを実行しようとしています:';

  @override
  String get permissionReject => '拒否';

  @override
  String get permissionAllowOnce => '1回のみ許可';

  @override
  String get permissionAllowAlways => '常に許可';

  @override
  String get quickTroubleshootCpu => '高CPU使用率の診断';

  @override
  String get quickDockerHealth => 'Docker ヘルスチェック';

  @override
  String get quickCleanCache => 'システムキャッシュのクリア';

  @override
  String get quickNginxLogs => 'Nginx エラーログの確認';

  @override
  String get terminalNewTab => '新規タブ';

  @override
  String get terminalCloseTab => 'タブを閉じる';

  @override
  String get terminalClear => 'クリア';

  @override
  String get terminalQuickCmds => 'コマンドパレット';

  @override
  String get terminalPaste => '貼り付け';

  @override
  String get terminalConfirmPasteTitle => '貼り付けの確認';

  @override
  String terminalConfirmPasteMessage(int count) {
    return 'ターミナルに $count 行のテキストを貼り付けます。続行しますか？';
  }

  @override
  String get settingsTerminalPinnedKeys => 'ターミナルショートカットキー';

  @override
  String get settingsTerminalPinnedKeysSubtitle =>
      'ツールバーのショートカットキーをカスタマイズおよび並べ替え';

  @override
  String get terminalResetPinnedKeys => 'デフォルトに戻す';

  @override
  String get terminalToggleKeyboard => 'キーボードの切り替え';

  @override
  String get sftpCurrentPath => '現在のパス';

  @override
  String get sftpUpload => 'アップロード';

  @override
  String get sftpNewFolder => '新規フォルダー';

  @override
  String get sftpNewFile => '新規ファイル';

  @override
  String get sftpRefresh => '更新';

  @override
  String get sftpSearchHint => 'ファイルまたはフォルダーを検索...';

  @override
  String get sftpEmpty => 'ディレクトリは空です';

  @override
  String get sftpFileName => '名前';

  @override
  String get sftpFileSize => 'サイズ';

  @override
  String get sftpFilePerm => '権限';

  @override
  String get sftpFileModified => '更新日時';

  @override
  String get cmdCategoryDocker => 'DOCKER コンテナスタック';

  @override
  String get cmdCategorySystem => 'システムメンテナンス';

  @override
  String get cmdCategoryNetwork => 'ネットワーク & ポート';

  @override
  String get cmdExecute => '実行';

  @override
  String get cmdDangerous => '危険なコマンド';

  @override
  String get cmdDangerousWarning =>
      'この操作は元に戻せず、サービスの中断を引き起こす可能性があります。続行してもよろしいですか？';

  @override
  String get cmdParamRequired => 'パラメーターの入力が必要です';

  @override
  String get cmdConfirm => '確認して実行';

  @override
  String get cmdCancel => 'キャンセル';

  @override
  String get settingsAppearance => '外観とテーマ';

  @override
  String get settingsThemeMode => 'テーマモード';

  @override
  String get themeSystem => 'システムに従う';

  @override
  String get themeSystemDesc => 'システムの自動適応';

  @override
  String get themeLight => 'ライトモード';

  @override
  String get themeLightDesc => 'クリーンなホワイト';

  @override
  String get themeDark => 'ギークダーク';

  @override
  String get themeDarkDesc => 'ディープチャコール';

  @override
  String get themeAmoled => 'AMOLED ブラック';

  @override
  String get themeAmoledDesc => '完全な黒 0x000000';

  @override
  String get settingsAccentColor => 'テーマアクセントカラー';

  @override
  String get accentCyberEmerald => 'サイバーエメラルド';

  @override
  String get accentTechBlue => 'テックブルー';

  @override
  String get accentElectricViolet => 'エレクトリックバイオレット';

  @override
  String get accentCrimsonRed => 'クリムゾンレッド';

  @override
  String get accentAmberOrange => 'アンバーオレンジ';

  @override
  String get settingsLanguage => '言語とロケール';

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
  String get settingsAiOps => 'AI Ops & エンジン';

  @override
  String get settingsSecurity => '接続とセキュリティ';

  @override
  String get settingsKnownHosts => '既知のホストキー';

  @override
  String get settingsClearStorage => '認証情報の初期化';

  @override
  String get settingsResetDefault => 'デフォルトに戻す';

  @override
  String get settingsTerminalUseTmux => '永続セッション (tmux)';

  @override
  String get settingsTerminalUseTmuxSubtitle =>
      'リモートサーバー上の tmux 内でターミナルセッションを実行';

  @override
  String get settingsTerminalUseTmuxDescription =>
      '切断後もターミナル出力を保持します。リモートサーバーに tmux が必要です。新しく開いたタブに適用されます。';

  @override
  String get settingsTerminalFontSize => 'ターミナルフォントサイズ';

  @override
  String get settingsTerminalFontSizeSubtitle => 'SSH および CLI ターミナルの文字サイズを調整';

  @override
  String get version => 'バージョン';

  @override
  String get addServer => 'サーバーを追加';

  @override
  String get editServer => 'サーバーを編集';

  @override
  String get serverName => 'サーバー名';

  @override
  String get serverHost => 'ホスト / IP';

  @override
  String get serverPort => 'ポート';

  @override
  String get serverUsername => 'ユーザー名';

  @override
  String get serverAuthType => '認証タイプ';

  @override
  String get serverPassword => 'パスワード';

  @override
  String get serverPrivateKey => '秘密鍵';

  @override
  String get serverSave => 'サーバーを保存';

  @override
  String get serverDelete => 'サーバーを削除';

  @override
  String get fileEditor => 'ファイルエディター';

  @override
  String get fileEditorSave => '変更を保存';

  @override
  String get fileSavedSuccess => 'ファイルを正常に保存しました';

  @override
  String get addCommand => '新規コマンド';

  @override
  String get commandTitle => 'コマンド名';

  @override
  String get commandContent => 'コマンド文字列';

  @override
  String get commandCategory => 'カテゴリー';

  @override
  String get commandDescription => '説明';

  @override
  String get save => '保存';

  @override
  String get delete => '削除';

  @override
  String get cancel => 'キャンセル';

  @override
  String get confirm => '確認';

  @override
  String get cmdExecutionChannel => '実行チャネル';

  @override
  String get cmdChannelTerminal => 'SSH ターミナルへ直接入力';

  @override
  String get cmdChannelTerminalDesc => 'コマンドはアクティブなターミナルセッションに直接入力されます';

  @override
  String get cmdChannelBackground => 'バックグラウンドセッションで実行';

  @override
  String get cmdChannelBackgroundDesc => 'SSH ログインシェル経由で実行し出力をキャプチャします';

  @override
  String get cmdInjectedToTerminal => 'コマンドをターミナルに送信しました';

  @override
  String get cmdExecutionCompleted => '実行完了';

  @override
  String get cmdExecutionFailed => '実行失敗';

  @override
  String get cmdExecutingRemote => 'リモートコマンドを実行中...';

  @override
  String get cmdClose => '閉じる';

  @override
  String get navDashboard => 'ダッシュボード';

  @override
  String get navDocker => 'Docker';

  @override
  String get navSystem => 'システム';

  @override
  String get navMore => 'その他';

  @override
  String get dashboardTitle => 'サーバーダッシュボード';

  @override
  String get metricsCpu => 'CPU 使用率';

  @override
  String get metricsMemory => 'メモリ使用率';

  @override
  String get metricsLoadAvg => 'ロードアベレージ';

  @override
  String get metricsUptime => 'システム稼働時間';

  @override
  String get metricsRootDisk => 'ルートディスク使用率';

  @override
  String get quickActions => 'クイックナビゲーション';

  @override
  String get activeServerStatus => '接続中サーバーの状態';

  @override
  String get noServerSelected => '現在選択されているサーバーはありません。先にサーバーを選択してください。';

  @override
  String get serverDisconnected => '切断されました';

  @override
  String get serverConnecting => '接続中...';

  @override
  String get connectNow => '今すぐ接続';

  @override
  String get serverSpecs => 'サーバー情報 & スペック';

  @override
  String get dockerTitle => 'Docker コンテナ一覧';

  @override
  String get dockerSearchHint => 'コンテナ名またはイメージで検索...';

  @override
  String get dockerFilterAll => 'すべて';

  @override
  String get dockerFilterRunning => '実行中';

  @override
  String get dockerFilterExited => '停止中';

  @override
  String get dockerFilterPaused => '一時停止中';

  @override
  String get dockerActionStart => '開始';

  @override
  String get dockerActionStop => '停止';

  @override
  String get dockerActionRestart => '再起動';

  @override
  String get dockerActionPause => '一時停止';

  @override
  String get dockerActionUnpause => '再開';

  @override
  String get dockerActionRm => '削除';

  @override
  String get dockerActionLogs => 'ログ';

  @override
  String get dockerActionInspect => '詳細情報';

  @override
  String get dockerLogsTitle => 'コンテナログ';

  @override
  String get dockerInspectTitle => 'コンテナ詳細';

  @override
  String get dockerNoContainers => 'サーバー上にコンテナが見つかりません';

  @override
  String get dockerEmptyRunning => '実行中のコンテナはありません';

  @override
  String get dockerPorts => 'ポート';

  @override
  String get dockerCreated => '作成日時';

  @override
  String get dockerImage => 'イメージ';

  @override
  String get systemTitle => 'プロセス & サービス';

  @override
  String get tabProcesses => 'プロセス';

  @override
  String get tabServices => 'Systemd サービス';

  @override
  String get processSearchHint => 'プロセス名または PID で検索...';

  @override
  String get processPid => 'PID';

  @override
  String get processCpu => 'CPU %';

  @override
  String get processMem => 'メモリ %';

  @override
  String get processStat => '状態';

  @override
  String get processCommand => 'コマンド';

  @override
  String get processTerminate => '終了 (SIGTERM)';

  @override
  String get processForceKill => '強制終了 (SIGKILL)';

  @override
  String get processKillForbidden => 'システム init (PID <= 1) の終了を拒否しました';

  @override
  String get serviceSearchHint => 'サービス名で検索...';

  @override
  String get serviceName => 'サービス';

  @override
  String get serviceDescription => '説明';

  @override
  String get serviceStatus => 'ステータス';

  @override
  String get serviceStartup => '自動起動';

  @override
  String get serviceActionStart => '開始';

  @override
  String get serviceActionStop => '停止';

  @override
  String get serviceActionRestart => '再起動';

  @override
  String get serviceActionReload => 'リロード';

  @override
  String get serviceActionEnable => '有効化';

  @override
  String get serviceActionDisable => '無効化';

  @override
  String get serviceNoServices => 'Systemd サービスが見つかりません';

  @override
  String get riskDangerTitle => '高リスク操作の確認';

  @override
  String get riskWarningTitle => '操作警告の確認';

  @override
  String get riskSafeTitle => '操作の確認';

  @override
  String get riskIrreversibleWarning =>
      'この操作は高リスクに分類され、元に戻せません。データ損失やサービス停止を引き起こす可能性があります。';

  @override
  String get riskWarningDescription =>
      'この操作は稼働中のサービスやプロセスに影響を与える可能性があります。注意して実行してください。';

  @override
  String get riskCommandPreview => 'コマンドプレビュー';

  @override
  String get riskConfirmButton => '確認して続行';

  @override
  String get riskCancelButton => 'キャンセル';

  @override
  String get stateLoading => 'リモートデータを読み込み中...';

  @override
  String get stateOffline => 'サーバーはオフラインです';

  @override
  String get stateOfflineDesc => 'リソース管理とメトリクス取得のために SSH 接続を確立してください。';

  @override
  String get stateError => 'エラーが発生しました';

  @override
  String get stateRetry => '再試行';

  @override
  String get stateEmpty => '項目が見つかりません';

  @override
  String get inspectorTitle => 'インスペクター';

  @override
  String get inspectorClose => '閉じる';

  @override
  String get inspectorDetails => '詳細を確認';

  @override
  String get selectServerTitle => 'ターゲットサーバーを選択';

  @override
  String get sshDisconnectedSuccess => 'SSH 接続を切断しました';

  @override
  String get trustHostFingerprintTitle => 'ホストフィンガープリントを信頼しますか？';

  @override
  String get trustAndConnect => '信頼して接続';

  @override
  String get reject => '拒否';

  @override
  String get confirmDeleteServerTitle => 'サーバーを削除';

  @override
  String get noServersFound => '設定済みのサーバーがありません';

  @override
  String get agentNotReadyError => '選択したエージェントは準備ができていません。環境と設定を確認してください。';

  @override
  String get sshDisconnectedError =>
      'SSH が切断されています。AI Ops を使用する前にサーバーに接続してください。';

  @override
  String get noAgentAvailable => '利用可能なエージェントがありません';

  @override
  String get noAgentAvailablePrompt =>
      '利用可能なアクティブエージェントがありません。先にエージェントを設定または準備してください。';

  @override
  String get noAgentAvailableHint => 'チャットするエージェントを選択または設定してください...';

  @override
  String get manageAgents => 'エージェント管理';

  @override
  String get noReadyAgentsTitle => '準備完了エージェントなし';

  @override
  String get noReadyAgentsDesc => 'このサーバー上で環境チェックに合格したエージェントがありません。';

  @override
  String get agentStatusReady => '準備完了';

  @override
  String get agentStatusChecking => '確認中...';

  @override
  String get agentStatusCliMissing => '未インストール';

  @override
  String get agentStatusAcpMissing => 'ACP コンポーネント未検出';

  @override
  String get agentStatusNotLoggedIn => '未ログイン';

  @override
  String get agentStatusError => 'エラー';

  @override
  String get agentStatusUnknown => '不明';

  @override
  String get agentActionInstall => 'インストール';

  @override
  String get agentActionLogin => 'ログイン';

  @override
  String get agentActionRefresh => '状態確認';

  @override
  String get noConfiguredAgents => 'このサーバーに設定されたエージェントはありません';

  @override
  String get agentManagementTitle => 'エージェント管理';

  @override
  String get settingsAgentManagement => 'エージェント管理';

  @override
  String get settingsAgentManagementSubtitle => '現在のサーバーの ACP エージェントを設定、検出、管理';

  @override
  String get addAgentButton => 'エージェントを追加';

  @override
  String get noServerSelectedForAgents =>
      'サーバーが選択されていません。先にメイン画面からサーバーを選択してください。';

  @override
  String get sshDisconnectedAgentWarning =>
      'SSH が切断されています。接続が確立されるまで検出、インストール、ログインは無効です。';

  @override
  String get noAgentsConfiguredTitle => '設定されたエージェントなし';

  @override
  String get noAgentsConfiguredDesc =>
      'Claude Code、Codex、OpenCode、AGY またはカスタム ACP エージェントを追加して AI Ops を有効にしてください。';

  @override
  String get agentPresetLabel => 'プリセット';

  @override
  String get agentPresetClaudeCode => 'Claude Code';

  @override
  String get agentPresetCodex => 'OpenAI Codex';

  @override
  String get agentPresetOpenCode => 'OpenCode ACP';

  @override
  String get agentPresetAgy => 'Antigravity AGY';

  @override
  String get agentPresetCustom => 'カスタム';

  @override
  String get agentNameLabel => 'エージェント名';

  @override
  String get agentNameHint => '例: 本番用 Codex';

  @override
  String get agentDescriptionLabel => '説明';

  @override
  String get agentDescriptionHint => 'エージェントの概要説明';

  @override
  String get agentCliCommandLabel => 'CLI 検出コマンド';

  @override
  String get agentCliCommandHint => '例: claude, codex';

  @override
  String get agentAcpCommandLabel => 'ACP 起動コマンド';

  @override
  String get agentAcpCommandHint => '例: codex-acp --stdio';

  @override
  String get agentInstallCommandLabel => 'インストールコマンド (任意)';

  @override
  String get agentInstallCommandHint => '例: npm install -g @openai/codex';

  @override
  String get agentLoginCheckCommandLabel => 'ログイン確認コマンド (任意)';

  @override
  String get agentLoginCheckCommandHint => '例: codex --version';

  @override
  String get agentLoginCommandLabel => 'ログインコマンド (任意)';

  @override
  String get agentLoginCommandHint => '例: codex login';

  @override
  String get agentSaveButton => '保存して検出';

  @override
  String get agentCliRequired => 'CLI 検出コマンドは必須です';

  @override
  String get agentAcpRequired => 'ACP 起動コマンドは必須です';

  @override
  String get agentNameRequired => 'エージェント名は必須です';

  @override
  String get confirmInstallAgentTitle => 'エージェントインストールの確認';

  @override
  String get confirmLoginAgentTitle => 'エージェントログインの確認';

  @override
  String get agentCommandRiskWarning =>
      'このコマンドは現在のユーザー権限でリモートサーバー上で直接実行されます。パッケージのインストールやシステム環境の変更を伴う可能性があります。';

  @override
  String get targetServerLabel => '対象サーバー';

  @override
  String get commandPreviewLabel => 'コマンドプレビュー';

  @override
  String get executeButton => '実行';

  @override
  String get deleteAgentTitle => 'エージェントを削除';

  @override
  String get deleteAgentConfirm => '削除';

  @override
  String get agentStatusCheckingDesc => 'リモートサーバーの環境を検出中...';

  @override
  String get agentStatusInstalling => 'サーバーに依存関係をインストール中...';

  @override
  String get agentStatusLoggingIn => 'サーバーでログインコマンドを実行中...';

  @override
  String get agentNoLoginCheckProvided => 'ログイン確認コマンドが指定されていません';

  @override
  String get agentInstallPrompt => 'インストールが検出されませんでした。自動インストールしますか？';

  @override
  String get agentActionAutoInstall => '自動インストール';

  @override
  String get agentLoginPrompt => '未ログインです。今すぐログインしますか？';

  @override
  String get agentActionExecuteLogin => '今すぐログイン';

  @override
  String get agentNeedsInstallOrReadyPrompt =>
      'このサーバー上のエージェントはインストールされていないか、準備ができていません。環境設定を完了してください。';

  @override
  String get agentNeedsInstallOrReadyHint =>
      'チャットを開始するにはエージェントをインストールして準備してください...';

  @override
  String get agentAcpInstallPrompt => 'ACP コンポーネントが見つかりません。自動インストールしますか？';

  @override
  String get agentInstallCommandAcpLabel => 'ACP インストールコマンド (任意)';

  @override
  String get agentInstallCommandAcpHint =>
      '例: npm install -g @zed-industries/codex-acp';

  @override
  String get agentNoInstallCommand => 'このエージェント用のインストールコマンドが設定されていません';

  @override
  String get agentInstallLogTitle => 'インストール出力ログ';

  @override
  String get agentInstallLogEmpty => 'インストール出力を待機中…';

  @override
  String get agentInstallLogTruncated => '出力が長すぎるため、最新の行のみを表示しています';

  @override
  String get agentAcpOptional => '任意: CLI のみで使用する場合は空欄のままにします';

  @override
  String get acpStreaming => 'ACP ストリーミング中...';

  @override
  String get aiOpsAgentTitle => 'Valhalla AI Ops エージェント';

  @override
  String get aiOpsEmptySubtitle => 'SSH チャネル経由の ACP stdio で接続';

  @override
  String get agentAuthRequiredTitle => '認証が必要です';

  @override
  String get agentAuthRequiredDesc => 'リクエストを処理する前にエージェントの認証が必要です。';

  @override
  String get agentAuthMethodLabel => '認証方式';

  @override
  String get agentAuthNoMethodsNotice =>
      'エージェントからログイン方式が提供されませんでした。サーバー側の設定を確認してください。';

  @override
  String get agentAuthProceedButton => 'ログイン';

  @override
  String get agentAuthCancelButton => 'キャンセル';

  @override
  String get agentAuthRetryHint => 'ログイン完了後、メッセージを再送信してください。';

  @override
  String get agentAuthRequiredError => '認証が必要です。続行するにはログインしてください。';

  @override
  String get agentLoginTerminalTitle => '対話型ログインターミナル';

  @override
  String get agentLoginTerminalSubtitle =>
      '以下のターミナルでログイン手順を完了してください。表示される URL やコードプロンプトに従ってください。';

  @override
  String get agentLoginTerminalRunning => 'ターミナルでログインコマンドを実行中...';

  @override
  String get agentLoginTerminalDisconnected =>
      'SSH 接続が切断されました。ログインセッションが中断しました。';

  @override
  String get agentLoginTerminalRetry => 'ターミナルを再接続';

  @override
  String get agentLoginTerminalFinish => '完了 & 検証';

  @override
  String get agentLoginTerminalClose => '閉じる';

  @override
  String get agentLoginTerminalNoTtyHint =>
      'エージェントがコードの貼り付けを要求する場合は、ターミナルを長押しして貼り付けるか PASTE キーを使用してください。';

  @override
  String get agentLoginTerminalUrlLabel => 'ログイン URL を検出しました';

  @override
  String get agentLoginTerminalUrlCopy => 'リンクをコピー';

  @override
  String get agentLoginTerminalUrlCopied => 'ログイン URL をクリップボードにコピーしました';

  @override
  String get agentLoginTerminalCopyAll => 'すべての出力をコピー';

  @override
  String get agentLoginTerminalCopiedAll => 'ターミナル出力をクリップボードにコピーしました';

  @override
  String get sshStatusReconnected => '接続を復元しました';

  @override
  String get sshStatusDisconnectedRetrying => '接続が切れました。再試行中';

  @override
  String get sshStatusDisconnectedManual => '切断されました';

  @override
  String get sshStatusHostKeyChanged => 'ホストキーが変更されました — 接続が拒否されました';

  @override
  String get sshKeepAliveNotificationTitle => 'Valhalla がセッションを維持しています';

  @override
  String get terminalTmuxMissingNotice => 'tmux が見つかりません — 接続切断時にセッションが保持されません';

  @override
  String get terminalTmuxSessionRestored => 'ターミナルセッションを復元しました';

  @override
  String get moshSectionTitle => 'Mosh';

  @override
  String get moshEnable => 'Mosh を有効化 — 接続切断や IP 変更にも耐えるローミングターミナル';

  @override
  String get moshServerPathLabel => 'mosh-server のパス';

  @override
  String get moshPortRangeLabel => 'UDP ポート範囲';

  @override
  String get moshNewSession => '新規 Mosh セッション';

  @override
  String get moshNotInstalled =>
      'リモートサーバーに mosh-server が見つかりません。次のようにインストールしてください: sudo apt install mosh (Debian/Ubuntu) または sudo dnf install mosh (Fedora/RHEL)。';

  @override
  String moshBootstrapFailed(String detail) {
    return 'Mosh セッションの起動に失敗しました: $detail';
  }

  @override
  String get moshUdpTimeout =>
      'Mosh 接続がタイムアウトしました — UDP 通信がファイアウォールでブロックされていないか確認してください。';

  @override
  String get moshSessionTag => 'mosh';

  @override
  String get acpSessionRestored => 'エージェントセッションを復元しました';

  @override
  String get acpSessionRestartNotice =>
      'エージェントセッションが再起動しました — 以前のコンテキストは利用できません';

  @override
  String get terminalTmuxInstallDialogTitle => 'リモートサーバーに tmux をインストールしますか？';

  @override
  String get terminalTmuxInstallDialogMessage =>
      '切断をまたいでターミナルセッションを保持するには tmux が必要です。今すぐインストールしますか？';

  @override
  String get terminalTmuxInstallCommandLabel => '実行するコマンド:';

  @override
  String get terminalTmuxInstallUnsupported =>
      'リモートサーバーでサポートされているパッケージマネージャーが見つかりませんでした。手動で tmux をインストールしてください。';

  @override
  String get terminalTmuxInstallFailed =>
      'tmux のインストールに失敗しました。サーバーの権限とネットワークを確認してください。';

  @override
  String get terminalTmuxInstallDisconnected =>
      'SSH 接続が切断されました。再接続後に tmux をインストールしてください。';

  @override
  String get terminalTmuxInstallInstalling => 'tmux をインストール中...';

  @override
  String get terminalTmuxInstallConfirm => 'tmux をインストール';

  @override
  String get terminalTmuxInstallSkip => 'スキップ (通常のシェルを使用)';

  @override
  String get sftpDownload => 'ダウンロード';

  @override
  String get sftpOpen => '開く';

  @override
  String get sftpUploadFailed => 'アップロードに失敗しました。権限を確認して再試行してください。';

  @override
  String get sftpDownloadFailed => 'ダウンロードに失敗しました';

  @override
  String get sftpOpenUnsupported => 'このファイル形式を開くことはできません。';

  @override
  String get sftpReadFailed => 'ファイルの読み取りに失敗しました。権限を確認して再試行してください。';

  @override
  String get sftpTransferFailed => 'ファイル操作に失敗しました。再試行してください。';

  @override
  String get sftpDownloadSuccess => 'ダウンロードが完了しました';

  @override
  String get sftpUploading => 'アップロード中...';

  @override
  String get sftpDownloading => 'ダウンロード中...';

  @override
  String get sftpUpDirectory => '親ディレクトリへ移動';

  @override
  String get sftpShowHiddenFiles => '隠しファイルを表示';

  @override
  String get sftpHideHiddenFiles => '隠しファイルを非表示';

  @override
  String get sftpHiddenPreferenceSaveFailed => '隠しファイル設定の保存に失敗しました';

  @override
  String get sftpViewModeList => 'リスト表示';

  @override
  String get sftpViewModeGrid => 'グリッド表示';

  @override
  String get sftpViewPreferenceSaveFailed => '表示モード設定の保存に失敗しました';

  @override
  String get sftpSymlink => 'シンボリックリンク';

  @override
  String get sftpLinkTargetUnavailable => 'リンク先が無効または見つかりません';

  @override
  String get sftpLinkTargetPermissionDenied => 'リンク先へのアクセス権限がありません';

  @override
  String get settingsAutoConnect => '起動時に自動接続';

  @override
  String get settingsAutoConnectFixed => '指定したデフォルト SSH';

  @override
  String get settingsAutoConnectFixedDesc => '常に以下で選択したサーバーに接続します';

  @override
  String get settingsAutoConnectLast => '前回の接続を記憶';

  @override
  String get settingsAutoConnectLastDesc => '前回正常に接続したサーバーに接続します';

  @override
  String get settingsAutoConnectPickServer => 'サーバー';

  @override
  String get settingsAutoConnectNoServer => 'サーバーが選択されていません';

  @override
  String get sftpSort => '並べ替え';

  @override
  String get sftpSortName => '名前';

  @override
  String get sftpSortSize => 'サイズ';

  @override
  String get sftpSortDate => '更新日時';

  @override
  String get sftpSortAscending => '昇順';

  @override
  String get sftpSortDescending => '降順';

  @override
  String get themeQuickSwitch => 'テーマ';

  @override
  String get transferList => '転送一覧';

  @override
  String get transferEmpty => '転送タスクはありません';

  @override
  String get transferUpload => 'アップロード';

  @override
  String get transferDownload => 'ダウンロード';

  @override
  String get transferStatusQueued => '待機中';

  @override
  String get transferStatusRunning => '転送中';

  @override
  String get transferStatusPaused => '一時停止';

  @override
  String get transferStatusCompleted => '完了';

  @override
  String get transferStatusFailed => '失敗';

  @override
  String get transferStatusCanceled => 'キャンセル済み';

  @override
  String get transferPause => '一時停止';

  @override
  String get transferResume => '再開';

  @override
  String get transferCancel => 'キャンセル';

  @override
  String get transferRemove => '削除';

  @override
  String get transferClearFinished => '完了した項目をクリア';

  @override
  String get transferSizeUnknown => 'サイズ不明';

  @override
  String get transferFailedUpload => 'アップロード失敗';

  @override
  String get transferFailedDownload => 'ダウンロード失敗';

  @override
  String get stopGeneration => '停止';

  @override
  String get chatServerBindingRequired =>
      'このセッションはサーバーに関連付けられていません。続行するには現在のサーバーに関連付けてください。';

  @override
  String get chatSessionUnboundNotice => 'このセッションはどのサーバーにも関連付けられていません。';

  @override
  String get bindServerAction => 'サーバーに関連付け';

  @override
  String get bindServerDialogTitle => 'セッションをサーバーに関連付け';

  @override
  String get bindServerConfirmAction => '関連付けを確認';

  @override
  String get chatSessionIdentityMismatch =>
      '現在のサーバーまたはエージェントが、このセッションの関連付けと一致しません。一致するサーバーとエージェントに切り替えてください。';

  @override
  String get deleteSessionTitle => 'セッションを削除';

  @override
  String get deleteSessionConfirmAction => '削除';

  @override
  String get shareAgentSessionsTitle => 'エージェント間セッション共有';

  @override
  String get shareAgentSessionsSubtitle => 'このサーバー上の異なるエージェント間でセッションを共有';

  @override
  String get shareAgentSessionsEnabled => 'エージェントセッション共有が有効です';

  @override
  String get shareAgentSessionsDisabled => 'エージェントセッション共有が無効です';

  @override
  String get agentCliStatusInstalled => 'CLI: インストール済み';

  @override
  String get agentCliStatusMissing => 'CLI: 未検出';

  @override
  String get agentCliStatusChecking => 'CLI: 確認中...';

  @override
  String get agentCliStatusUnknown => 'CLI: 不明';

  @override
  String get agentCliStatusError => 'CLI: エラー';

  @override
  String get agentAcpStatusReady => 'ACP: 準備完了';

  @override
  String get agentAcpStatusMissing => 'ACP: 未検出';

  @override
  String get agentAcpStatusChecking => 'ACP: 確認中...';

  @override
  String get agentAcpStatusPendingCli => 'ACP: CLI 待ち';

  @override
  String get agentAcpStatusUnknown => 'ACP: 不明';

  @override
  String get agentAcpStatusError => 'ACP: エラー';

  @override
  String get agentAcpStatusNa => 'ACP: 該当なし';

  @override
  String get agentAuthStatusAuthenticated => '認証: ログイン済み';

  @override
  String get agentAuthStatusUnauthenticated => '認証: 未ログイン';

  @override
  String get agentAuthStatusUnknown => '認証: 不明';

  @override
  String get downloadNotificationsUnavailable =>
      'システムのダウンロード通知を利用できません。ダウンロードはバックグラウンドで継続します。';

  @override
  String get downloadOpenFailed => 'ダウンロードしたファイルを開けませんでした。';

  @override
  String get dockerActionPending => 'このコンテナではすでにアクションが進行中です';

  @override
  String get dockerNoLogs => '(ログなし)';

  @override
  String get serverReboot => '再起動';

  @override
  String get serverRebootDialogTitle => 'サーバー再起動の確認';

  @override
  String get serverRebootDialogMessage =>
      'このサーバーを再起動してもよろしいですか？すべてのアクティブな接続とバックグラウンドサービスが終了します。';

  @override
  String get serverRebootConfirmButton => '今すぐ再起動';

  @override
  String get serverRebootPasswordTitle => 'sudo パスワードが必要です';

  @override
  String get serverRebootPasswordMessage =>
      'サーバーを再起動するには root 権限が必要です。sudo パスワードを入力してください (1回のみ使用され、保存されません):';

  @override
  String get serverRebootPasswordHint => 'sudo パスワード';

  @override
  String get serverRebootSubmitting => '再起動コマンドを送信中...';

  @override
  String get serverRebootAccepted =>
      '再起動コマンドを受理しました。完了は未検証です。サーバーがオンラインに戻ったら再接続してください。';

  @override
  String get serverRebootVerified => 'サーバーの再起動を確認しました。システムはオンラインです。';

  @override
  String get serverRebootUnknown =>
      '再起動結果は不明です。コマンドは送信されましたが、完了を確認できませんでした。接続を手動で確認してください。';

  @override
  String get serverRebootReconnect => '再接続';

  @override
  String get serverRebootServerChanged => 'ターゲットサーバーが変更されたため、再起動を中止しました';

  @override
  String get navCliChat => 'CLI チャット';

  @override
  String get cliChatTitle => 'CLI セッション';

  @override
  String get cliChatSubtitle => 'リモートサーバー上のネイティブ CLI エージェントセッション';

  @override
  String get cliSelectAgent => 'エージェントを選択';

  @override
  String get cliNoAgentsConfigured => 'このサーバーに追加されたエージェントはありません';

  @override
  String get cliAgentNeedsSetup => 'エージェント環境がないか、ログインしていません';

  @override
  String get cliManageAgentsGuide => 'エージェント管理で設定';

  @override
  String get cliNewDraft => '新規下書き';

  @override
  String get cliNewDraftTooltip => '空の下書きを作成 (最初のメッセージ送信時にセッション作成)';

  @override
  String get cliDeleteSessionTitle => 'リモート CLI セッション履歴を削除';

  @override
  String get cliDeleteSessionMessage =>
      'リモートサーバー上の CLI セッション履歴を完全に削除します。続行してもよろしいですか？';

  @override
  String get cliDeleteConfirmButton => 'セッションを削除';

  @override
  String get cliCannotDeleteTooltip => 'リモートセッションの削除はサポートされていないか無効です';

  @override
  String get cliSessionsHeader => 'セッション一覧';

  @override
  String get cliNoSessions => 'CLI セッションが見つかりません';

  @override
  String get cliFilterCwdHint => '作業ディレクトリのパスでフィルター...';

  @override
  String get cliFilterCwdAction => 'フィルター';

  @override
  String get cliClearCwdAction => 'クリア';

  @override
  String get cliLoadMoreSessions => 'さらにセッションを読み込む';

  @override
  String get cliRefreshSessions => '更新';

  @override
  String get cliClaudeReadOnlyNotice =>
      'Claude の履歴は読み取り専用です。実際のターミナルで会話を続けてください。';

  @override
  String get cliContinueInTerminal => 'ターミナルで続ける';

  @override
  String get cliOpenTerminal => 'ターミナルを開く';

  @override
  String get cliCloseTerminal => 'ターミナルを閉じる';

  @override
  String get cliTerminalRunning => '対話型 CLI ターミナル';

  @override
  String get cliAgyTerminalOnlyNotice =>
      'このエージェントは構造化された履歴同期をサポートしていません。対話やセッション選択にはネイティブ CLI ターミナルを使用してください。';

  @override
  String get cliInstallSdkTitle => '公式 Claude History SDK をインストール';

  @override
  String get cliInstallSdkMessage =>
      'リモートサーバーに公式の Claude Code History SDK がありません。今すぐインストールしますか？';

  @override
  String get cliInstallSdkAction => '公式 SDK をインストール';

  @override
  String get cliApprovalsTitle => '承認待ちの操作';

  @override
  String get cliApprovalDetails => '詳細';

  @override
  String get cliApprovalAllow => '許可';

  @override
  String get cliApprovalDecline => '拒否';

  @override
  String get cliInputHint => 'CLI エージェントにメッセージを入力...';

  @override
  String get cliSend => '送信';

  @override
  String get cliStop => '停止';

  @override
  String get cliBusy => '処理を実行中です。しばらくお待ちください...';

  @override
  String get cliDisconnected => 'SSH が接続されていません';

  @override
  String get cliServerChanged => 'ターゲットサーバーが変更されました';

  @override
  String get cliTurnFailed => 'CLI ターンの実行に失敗しました';

  @override
  String get cliUseTerminal => '対話型プロンプトが必要です。ターミナルを開いて続行してください';

  @override
  String get cliDeleteFailed => 'リモートセッションの削除に失敗しました';

  @override
  String get cliDeleteUnsupported => 'この CLI ではリモートセッションの削除がサポートされていません';

  @override
  String get cliOperationFailed => 'CLI 操作に失敗しました';

  @override
  String get cliHistorySdkMissing => 'サーバーに公式 History SDK がありません';

  @override
  String get cliHistoryRuntimeMissing =>
      'Claude 履歴にはサーバー上に Node.js/npm が必要です。手動で Node.js をインストールしてください。ターミナルではそのまま実際の CLI を使用できます。';

  @override
  String get cliLoginRequired => 'エージェントのログインが必要です。エージェント管理からログインしてください。';

  @override
  String get cliNotInstalled =>
      'エージェント CLI がインストールされていません。エージェント管理からインストールしてください。';

  @override
  String get cliVersionUnsupported =>
      'エージェント CLI のバージョンがサポートされていません。エージェント管理からアップグレードまたは再インストールしてください。';

  @override
  String get settingsNavigation => 'ナビゲーション';

  @override
  String get settingsNavigationDesc => 'デフォルトの起動ページとボトムナビゲーションバーを設定';

  @override
  String get settingsStartupPage => '起動時ページ';

  @override
  String get settingsStartupPageDesc => 'アプリ起動時に表示される画面';

  @override
  String get settingsBottomNav => 'ボトムナビゲーションバー';

  @override
  String get settingsBottomNavDesc => 'モバイルのボトムバーに表示するセクションを選択 (0〜9 項目対応)';

  @override
  String get settingsResetSuccess => 'すべての設定を初期値に戻しました';

  @override
  String get metricsTrendSubtitle => '直近約3分間 (最大60サンプル)';

  @override
  String get metricsCurrent => '現在値';

  @override
  String get metricsPeak => 'ピーク';

  @override
  String get metricsValley => 'ボトム';

  @override
  String get metricsTrendWaiting => 'メトリクスデータを収集中...';

  @override
  String get metricsTrendStopped => 'データ収集が停止しました (SSH 切断)';

  @override
  String get dockerActionTerminal => 'Exec ターミナル';

  @override
  String get dockerTerminalTitle => 'コンテナターミナル';

  @override
  String get dockerTerminalNotRunning => 'コンテナが起動していません';

  @override
  String get setDefaultAgent => 'デフォルトに設定';

  @override
  String get defaultBadge => 'デフォルト';

  @override
  String get isDefaultAgent => 'デフォルトエージェント';

  @override
  String get setAsDefaultAgent => 'このサーバーのデフォルトエージェントに設定';

  @override
  String get agentGroupBasic => '基本情報';

  @override
  String get agentGroupCommands => 'コマンド';

  @override
  String get agentGroupAuth => 'インストール & 認証';

  @override
  String get agentPresetTitle => 'プリセットテンプレート';

  @override
  String get resourceProcessList => 'プロセス一覧';

  @override
  String get resourceDiskScanning => 'ルートディレクトリをスキャン中... 数秒かかる場合があります';

  @override
  String get resourceDiskScanPartial => '権限またはタイムアウトのため、一部のディレクトリをスキャンできませんでした';

  @override
  String get resourceDiskDirectories => '最上位ディレクトリの使用量';

  @override
  String get resourceSortCpu => 'CPU 順で並べ替え';

  @override
  String get resourceSortMemory => 'メモリ順で並べ替え';

  @override
  String get resourceRss => 'RSS メモリ';

  @override
  String get resourceUsed => '使用中';

  @override
  String get resourceAvailable => '空き容量';

  @override
  String get resourceTotal => '合計';

  @override
  String get settingsBottomNavOrderTitle => '選択された項目 (ドラッグして並べ替え)';

  @override
  String get langSystem => 'システム設定に従う';

  @override
  String get serverFieldRequired => '必須入力です';

  @override
  String get serverPortInvalid => 'ポートは 1 から 65535 の間である必要があります';

  @override
  String get serverTestReachability => '接続性をテスト';

  @override
  String get serverSaveFailedGeneric => 'サーバーの保存に失敗しました。設定を確認して再試行してください。';

  @override
  String get serverViewPrivateKey => '秘密鍵を表示';

  @override
  String get serverHidePrivateKey => '秘密鍵を隠す';

  @override
  String get dockerBashFallbackNotice => 'コンテナ内で Bash が利用できないため、Sh にフォールバックします';

  @override
  String get dockerShellLabel => 'シェル';

  @override
  String get dockerShellBash => 'Bash';

  @override
  String get dockerShellSh => 'Sh';

  @override
  String get cliDraftWorkingDirLabel => '作業ディレクトリ';

  @override
  String get cliDefaultWorkingDir => 'デフォルト (/)';

  @override
  String get cliPickWorkingDirTitle => '作業ディレクトリを選択';

  @override
  String get cliClearWorkingDir => 'デフォルトに戻す';

  @override
  String get cliBrowseWorkingDir => '参照';

  @override
  String get cliSelectCurrentDir => 'このディレクトリを選択';

  @override
  String get cliNavigateUp => '上へ';

  @override
  String get chatSessionsTooltip => 'セッション一覧';

  @override
  String get hardwareSpecsTitle => 'ハードウェア & システム';

  @override
  String get hardwareCpu => 'CPU';

  @override
  String get hardwareMemory => 'メモリ';

  @override
  String get hardwareDisk => 'ルートディスク';

  @override
  String get hardwareDistribution => 'OS';

  @override
  String get hardwareKernel => 'カーネル';

  @override
  String get hardwareLoading => 'ハードウェアスペックを読み込み中...';

  @override
  String get hardwareUnavailable => 'ハードウェアスペックを取得できません';

  @override
  String get hardwareUnknown => '不明';

  @override
  String get systemInfoTitle => 'システム情報';

  @override
  String get systemInfoTapHint => 'タップして ASCII アートを表示';

  @override
  String get systemInfoHost => 'ホスト';

  @override
  String get serverShutdown => 'シャットダウン';

  @override
  String get serverShutdownDialogTitle => 'サーバーシャットダウンの確認';

  @override
  String get serverShutdownDialogMessage =>
      'このサーバーをシャットダウンしてもよろしいですか？システムは完全に電源オフとなり、手動で電源を入れるまでリモートからアクセスできなくなります。';

  @override
  String get serverShutdownConfirmButton => '今すぐシャットダウン';

  @override
  String get serverShutdownSubmitting => 'シャットダウンコマンドを送信中...';

  @override
  String get serverShutdownAccepted => 'シャットダウンコマンドを受理しました。完了は未検証です。';

  @override
  String get serverShutdownUnknown =>
      'シャットダウン結果は不明です。コマンドは送信された可能性がありますが確認できませんでした。手動で確認してください。自動再試行は行われません。';

  @override
  String get serverShutdownPasswordTitle => 'シャットダウン用 sudo パスワード';

  @override
  String get serverShutdownPasswordMessage =>
      'サーバーをシャットダウンするには root 権限が必要です。sudo パスワードを入力してください (1回のみ使用され、保存されません):';

  @override
  String get serverShutdownPasswordHint => 'sudo パスワード';

  @override
  String get serverShutdownServerChanged => 'ターゲットサーバーが変更されたため、シャットダウンを中止しました';

  @override
  String get metricsNetwork => 'ネットワークレート';

  @override
  String get networkModalTitle => 'ネットワークインターフェース詳細';

  @override
  String get networkDownloadRate => '受信 (RX)';

  @override
  String get networkUploadRate => '送信 (TX)';

  @override
  String get networkTotalRx => '累計受信 (RX)';

  @override
  String get networkTotalTx => '累計送信 (TX)';

  @override
  String get networkPrimary => 'デフォルトルート';

  @override
  String get networkRatesEmpty => 'アクティブなネットワークインターフェースが検出されませんでした';

  @override
  String get networkWaitingSecondSample => '2回目のサンプル取得を待機中';

  @override
  String get networkUnavailable => '利用不可';

  @override
  String get networkNoDefaultInterface => 'デフォルトルートなし';

  @override
  String get selectThemeModeTitle => 'テーマモードを選択';

  @override
  String get selectLanguageTitle => '言語を選択';

  @override
  String get selectStartupPageTitle => '起動時ページを選択';

  @override
  String get selectAutoConnectModeTitle => '自動接続モードを選択';

  @override
  String get accentColorDialogTitle => 'アクセントカラーのカスタマイズ';

  @override
  String get accentColorLightMode => 'ライトモード';

  @override
  String get accentColorDarkMode => 'ダークモード';

  @override
  String get accentColorAmoledMode => 'AMOLED (ギーク)';

  @override
  String get accentColorPresets => 'プリセット';

  @override
  String get accentColorHsvPicker => 'カラーホイール';

  @override
  String get accentColorHexCode => 'HEX カラー';

  @override
  String get accentColorPreview => 'プレビュー';

  @override
  String get accentColorSampleButton => 'アクセントボタン';

  @override
  String get accentColorInvalidHex => '無効な HEX 形式です (例: #10B981)';

  @override
  String get settingsDashboardQuickActions => 'ダッシュボードクイックアクション';

  @override
  String get settingsDashboardQuickActionsDesc =>
      'ダッシュボードに表示するショートカットを設定します。すべて解除するとクイックアクションセクションが非表示になります。';

  @override
  String get settingsDashboardQuickActionsEmpty =>
      'クイックアクションは非表示です (ショートカット未選択)';

  @override
  String get settingsDashboardQuickActionsOrderTitle => 'ドラッグしてショートカットを並べ替え';

  @override
  String get settingsDashboardQuickActionsCandidates => '表示するショートカットを選択';

  @override
  String get terminalCopySelection => 'コピー';

  @override
  String get terminalSelectionCopied => '選択範囲をクリップボードにコピーしました';

  @override
  String get editAgent => 'エージェントを編集';

  @override
  String get agentExecutionTarget => '実行環境';

  @override
  String get agentExecutionHost => 'ホストシステム';

  @override
  String get agentExecutionDocker => 'Docker コンテナ';

  @override
  String get agentContainerBinding => 'コンテナバインディング方式';

  @override
  String get agentContainerBindingId => 'コンテナ ID 指定';

  @override
  String get agentContainerBindingName => 'コンテナ名指定';

  @override
  String get agentContainerReference => '対象コンテナ';

  @override
  String get agentContainerReferenceHint => 'コンテナ ID または名前を選択・入力';

  @override
  String get agentContainerRequired => 'Docker 実行には対象コンテナの指定が必須です';

  @override
  String get agentLoadingContainers => 'サーバー上のコンテナを問い合わせ中...';

  @override
  String get agentNoContainersFound => 'このサーバー上にコンテナが見つかりません';

  @override
  String get agentContainerUser => 'コンテナ実行ユーザー (任意)';

  @override
  String get agentContainerUserHint => '例: dev';

  @override
  String get agentContainerUserHelper =>
      'イメージ既定のユーザーを使用する場合は空欄にします。例: dev。user、UID、user:group、UID:GID をサポート';

  @override
  String get agentContainerUserSelect => 'コンテナユーザーを選択';

  @override
  String get agentContainerUsersLoading => 'ユーザーを読み込み中...';

  @override
  String get agentContainerUsersEmpty => 'passwd ユーザーが見つかりません';

  @override
  String get agentViewDiagnosticLog => '診断ログを表示';

  @override
  String get agentDiagnosticLogCopied => '診断ログをクリップボードにコピーしました';

  @override
  String get agentDiagnosticLogCopy => 'コピー';

  @override
  String get agentDiagnosticLogClose => '閉じる';

  @override
  String get settingsCliHistoryPageSize => 'CLI 履歴のページサイズ';

  @override
  String get settingsCliHistoryPageSizeDesc =>
      '上にスクロールしたときに1ページあたりに読み込む過去メッセージ数 (5〜100)';

  @override
  String get settingsCliHistoryPageSizeTitle => 'CLI 履歴のページサイズを選択';

  @override
  String get cliLoadingOlderMessages => '過去のメッセージを読み込み中...';

  @override
  String get chatLoadOlderMessages => '以前のメッセージを読み込む';

  @override
  String get chatCommandsTooltip => 'コマンド';

  @override
  String get chatAttachTooltip => 'ファイルを添付';

  @override
  String get chatAttachImage => 'ローカル画像を添付';

  @override
  String get chatAttachLocalText => 'ローカルテキストファイルを添付';

  @override
  String get chatAttachRemoteText => 'リモートテキストファイルを添付';

  @override
  String get chatAttachRemotePathTitle => 'リモートテキストファイルを添付';

  @override
  String get chatAttachRemotePathHint => '/path/to/file.txt';

  @override
  String get chatAttachTooLarge => 'ファイルサイズが上限を超えています';

  @override
  String get chatUsageAndDiagnostics => '使用量 & 診断';

  @override
  String get chatWorkingDirTooltip => '下書きの作業ディレクトリ';

  @override
  String get chatAttachFailed => 'ファイルの添付に失敗しました';

  @override
  String get chatInvalidRemotePath => '無効なリモートファイルパスです (/ で始まる必要があります)';

  @override
  String get chatRemoteReadFailed => 'リモートファイルの読み取りに失敗しました';

  @override
  String get chatInvalidDirPath => '無効なディレクトリパスです (/ で始まる必要があります)';

  @override
  String get chatNoSubdirectories => 'サブディレクトリはありません';

  @override
  String get chatUsageTitle => 'トークン & コスト使用量';

  @override
  String get chatUsageUsed => '使用トークン数';

  @override
  String get chatUsageSize => 'コンテキストサイズ';

  @override
  String get chatUsageCost => 'コスト';

  @override
  String get chatDiagnosticsTitle => '診断ログ';

  @override
  String get chatNoDiagnostics => '利用可能な診断ログはありません';

  @override
  String get deleteSessionLocalOnlyNotice =>
      'これは Valhalla 内のローカル記録のみを削除し、サーバー上のエージェントネイティブセッション履歴は削除しません。';

  @override
  String get chatSearchSessionsHint => 'セッションを検索...';

  @override
  String get chatLoadMoreSessions => 'さらにセッションを読み込む';

  @override
  String get chatLoadingMoreSessions => 'さらにセッションを読み込み中...';

  @override
  String get chatExportSession => 'セッションをエクスポート (Markdown)';

  @override
  String get chatExportSuccess => 'セッションを正常にエクスポートしました';

  @override
  String get chatExportFailed => 'セッションのエクスポートに失敗しました';

  @override
  String get chatRemoteSessions => 'リモートセッション';

  @override
  String get chatRemoteSessionsTitle => 'リモートエージェントセッション';

  @override
  String get chatRemoteSessionsDesc => 'リモートエージェントからネイティブセッション履歴を表示・インポート';

  @override
  String get chatRemoteSessionsEmpty => 'リモートセッションが見つかりません';

  @override
  String get chatRemoteImporting => 'リモートセッション履歴をインポート中...';

  @override
  String get chatRemoteImportFailed => 'リモートセッションのインポートに失敗しました';

  @override
  String get chatStatusInterrupted => '中断されました';

  @override
  String get chatStatusFailed => '失敗';

  @override
  String get chatStatusAwaitingAuth => 'ACP 認証待機中';

  @override
  String get chatShowFullOutput => '出力をすべて表示';

  @override
  String get chatShowLessOutput => '折りたたむ';

  @override
  String get chatToolLocations => '影響を受けたパス';

  @override
  String cmdParamPlaceholder(String param) {
    return '$param の値を入力';
  }

  @override
  String processTerminateSuccess(Object pid) {
    return 'プロセス $pid を終了しました';
  }

  @override
  String serviceActionSuccess(Object action, Object service) {
    return 'サービス $service での $action に成功しました';
  }

  @override
  String riskPatternMatched(Object pattern) {
    return 'トリガーされたルール: $pattern';
  }

  @override
  String stateExitCode(Object code) {
    return '終了コード: $code';
  }

  @override
  String sshConnectedSuccess(Object server) {
    return 'SSH 経由で $server に正常に接続しました';
  }

  @override
  String sshConnectionFailed(Object error) {
    return 'SSH 接続に失敗しました: $error';
  }

  @override
  String trustHostFingerprintMessage(
    Object fingerprint,
    Object host,
    Object type,
  ) {
    return '$host ($type) に初めて接続します。\n\nSHA-256 フィンガープリント:\n$fingerprint\n\nこのフィンガープリントを信頼して接続しますか？';
  }

  @override
  String enterPasswordTitle(Object server) {
    return '$server のパスワードを入力';
  }

  @override
  String confirmDeleteServerMessage(Object name) {
    return 'サーバー \'$name\' を削除してもよろしいですか？この操作は元に戻せません。';
  }

  @override
  String deleteAgentMessage(Object name) {
    return 'エージェント \'$name\' を削除してもよろしいですか？これにより、過去のチャットセッションや SSH 認証情報に影響を与えることなく、このサーバー上の設定と実行状態が削除されます。';
  }

  @override
  String agentLastChecked(Object time) {
    return '最終確認: $time';
  }

  @override
  String agentAuthPickerTitle(Object agent) {
    return '$agent へのログイン方法を選択';
  }

  @override
  String sshStatusReconnecting(Object n) {
    return '再接続中… ($n 回目)';
  }

  @override
  String sshKeepAliveNotificationBody(Object n) {
    return '$n 個のアクティブセッション';
  }

  @override
  String bindServerConfirmMessage(Object serverName) {
    return 'このセッションをサーバー「$serverName」に関連付けますか？関連付け後、このセッションはそのサーバーと紐付けられます。';
  }

  @override
  String deleteSessionConfirmMessage(Object title) {
    return 'セッション「$title」を削除してもよろしいですか？この操作は元に戻せません。';
  }

  @override
  String dockerActionSuccess(Object action, Object name) {
    return 'コンテナ $name の $action が成功しました';
  }

  @override
  String dockerActionFailed(Object error) {
    return '操作に失敗しました: $error';
  }

  @override
  String serverRebootTarget(Object address, Object name) {
    return '対象サーバー: $name ($address)';
  }

  @override
  String serverRebootRunningTerminals(Object count) {
    return 'ターミナルセッション: $count';
  }

  @override
  String serverRebootRunningAgents(Object count) {
    return 'エージェントセッション: $count';
  }

  @override
  String serverRebootRunningTransfers(Object count) {
    return '実行中の転送: $count';
  }

  @override
  String serverRebootFailed(Object error) {
    return '再起動に失敗しました: $error';
  }

  @override
  String cliDeleteFailedWithDetail(Object detail) {
    return 'リモートセッションの削除に失敗しました: $detail';
  }

  @override
  String metricsTrendTitle(Object metric) {
    return '$metric の推移';
  }

  @override
  String metricsThresholdWarning(Object value) {
    return '警告: $value';
  }

  @override
  String metricsThresholdDanger(Object value) {
    return '危険: $value';
  }

  @override
  String metricsHistoryPoints(Object count) {
    return '$count 個のデータポイント';
  }

  @override
  String resourceUsageTitle(Object metric) {
    return '$metric リソース使用状況';
  }

  @override
  String serverPortReachable(Object port) {
    return 'TCP ポート $port に到達可能';
  }

  @override
  String serverConnectionFailed(Object error) {
    return '接続に失敗しました: $error';
  }

  @override
  String serverSaveFailed(Object error) {
    return 'サーバーの保存に失敗しました: $error';
  }

  @override
  String hardwareCpuCores(Object cores) {
    return '$cores コア';
  }

  @override
  String serverShutdownFailed(Object error) {
    return 'シャットダウンに失敗しました: $error';
  }

  @override
  String networkInterface(Object name) {
    return 'インターフェース: $name';
  }

  @override
  String agentContainersLoadFailed(Object error) {
    return 'コンテナ一覧の取得に失敗しました: $error';
  }

  @override
  String agentContainerUsersFailed(Object error) {
    return 'コンテナユーザーの取得に失敗しました: $error';
  }

  @override
  String agentDiagnosticLogTitle(Object name) {
    return '診断ログ - $name';
  }

  @override
  String get agentDockerDetectionFailed => 'Docker/コンテナの検出に失敗しました';

  @override
  String get chatCopiedAllMessages => 'すべてのメッセージをコピーしました';

  @override
  String get chatCopyAllMessages => 'すべてのメッセージをコピー';

  @override
  String get cliModelAtCapacity => '選択されたモデルは現在キャパシティに達しています。別のモデルをお試しください。';

  @override
  String get chatLaunchBlankDraft => '空の下書き';

  @override
  String get chatLaunchFixedSession => '固定セッション';

  @override
  String get chatLaunchRememberLast => '前回のセッションを記憶';

  @override
  String get chatPermissionAskEveryTime => '毎回確認する';

  @override
  String get chatPermissionAutoAllowAll => 'すべて自動で許可';

  @override
  String get chatPermissionAutoAllowAllConfirmMessage =>
      'エージェントは確認なしですべての操作を実行します。続行しますか？';

  @override
  String get chatPermissionAutoAllowAllConfirmTitle => 'すべての操作を許可しますか？';

  @override
  String get chatPermissionAutoAllowSafe => '安全な操作を自動で許可';

  @override
  String get chatRunSettingsDefault => 'デフォルト';

  @override
  String get chatRunSettingsInteractiveCli => '対話型 CLI';

  @override
  String get chatRunSettingsModel => 'モデル';

  @override
  String get chatRunSettingsPermissions => '権限';

  @override
  String get chatRunSettingsReasoning => '推論レベル';

  @override
  String get chatRunSettingsTitle => '実行設定';

  @override
  String get cliActionInsertCommand => 'コマンドを挿入';

  @override
  String get cliActionInsertFile => 'ファイルを挿入';

  @override
  String get cliActionInsertWorkdir => '作業ディレクトリを挿入';

  @override
  String get cliComposerInsertAction => '挿入';

  @override
  String cliOperationFailedWithDetail(String detail) {
    return 'CLI 操作に失敗しました: $detail';
  }

  @override
  String get cliSelectCommandTitle => 'コマンドを選択';

  @override
  String get defaultAgentTitle => 'デフォルトエージェント';

  @override
  String get insertSkills => 'スキルを挿入';

  @override
  String get isDefaultSession => 'デフォルトセッション';

  @override
  String get sessionLaunchMode => 'セッション起動モード';

  @override
  String get setAsDefaultSession => 'デフォルトセッションに設定';

  @override
  String get navNas => 'NAS メディア';

  @override
  String get nasAddExcludePath => '除外パスを追加';

  @override
  String get nasAddIncludePath => 'スキャンパスを追加';

  @override
  String get nasCancelScan => 'スキャンをキャンセル';

  @override
  String get nasClearSearch => '検索をクリア';

  @override
  String get nasConfigDialogTitle => 'メディアライブラリ設定';

  @override
  String get nasConfigure => '設定';

  @override
  String get nasConfigureScanDirs => 'スキャンフォルダーを設定';

  @override
  String get nasCreatePlaylist => 'プレイリストを作成';

  @override
  String get nasEmptyConfigDesc =>
      'メディアライブラリの構築を開始するには、少なくとも1つのフォルダーを追加してください。';

  @override
  String get nasEmptyConfigTitle => 'スキャンフォルダーが設定されていません';

  @override
  String get nasExcludePaths => '除外フォルダー';

  @override
  String get nasExcludedBadge => '除外済み';

  @override
  String get nasFilterImages => '画像';

  @override
  String get nasFilterVideos => '動画';

  @override
  String get nasIncludePaths => 'スキャンフォルダー';

  @override
  String nasItemCount(Object value) {
    return '$value 項目';
  }

  @override
  String nasLastScan(Object value) {
    return '前回のスキャン: $value';
  }

  @override
  String get nasLibrarySettings => 'ライブラリ設定';

  @override
  String nasMediaOpening(Object value) {
    return '$value を開いています…';
  }

  @override
  String get nasMiniPlayer => 'ミニプレイヤー';

  @override
  String get nasNoExcludePaths => '除外フォルダーはありません';

  @override
  String get nasNoFavorites => 'お気に入りはまだありません';

  @override
  String get nasNoIncludePaths => 'スキャンフォルダーがありません';

  @override
  String get nasNoIndexDesc => 'フォルダーを設定し、スキャンを実行してメディアをインデックス化してください。';

  @override
  String get nasNoIndexTitle => 'メディアライブラリは空です';

  @override
  String get nasNoPlaylists => 'プレイリストはまだありません';

  @override
  String get nasNoSearchResults => '一致するメディアはありません';

  @override
  String get nasNotScanned => 'まだスキャンされていません';

  @override
  String get nasNowPlaying => '再生中';

  @override
  String get nasOpenMethodPrompt => 'このファイルをどのように開きますか？';

  @override
  String get nasOpenPolicyAsk => '毎回確認する';

  @override
  String get nasOpenPolicyExternal => '他のアプリで開く';

  @override
  String get nasOpenPolicyInApp => 'アプリ内で開く';

  @override
  String get nasOpeningPolicy => 'デフォルトの開き方';

  @override
  String get nasPlaylistName => 'プレイリスト名';

  @override
  String get nasQuickStats => 'ライブラリ概要';

  @override
  String get nasScan => '今すぐスキャン';

  @override
  String get nasScanCancelled => 'スキャンをキャンセルしました';

  @override
  String nasScanFailed(Object value) {
    return 'スキャンに失敗しました: $value';
  }

  @override
  String get nasScanning => 'スキャン中…';

  @override
  String get nasScopeBadge => 'スキャン範囲';

  @override
  String get nasSearchHint => 'メディアを検索';

  @override
  String get nasStatMusic => '音楽';

  @override
  String get nasStatPhotos => '写真';

  @override
  String get nasStatTotal => '合計';

  @override
  String get nasStatVideos => '動画';

  @override
  String get nasTabFavorites => 'お気に入り';

  @override
  String get nasTabFolders => 'フォルダー';

  @override
  String get nasTabHome => 'ホーム';

  @override
  String get nasTabMusic => '音楽';

  @override
  String get nasTabPhotos => '写真';

  @override
  String get nasTabPlaylists => 'プレイリスト';

  @override
  String get nasTabVideos => '動画';

  @override
  String get nasSources => 'メディアソース';

  @override
  String get nasAddSource => 'メディアソースを追加';

  @override
  String get nasEditSource => 'メディアソースを編集';

  @override
  String get nasRemoveSource => 'メディアソースを削除';

  @override
  String nasRemoveSourceConfirm(Object name) {
    return 'メディアソース \'$name\' を削除してもよろしいですか？リモートファイルを削除せずに設定のみを削除します。';
  }

  @override
  String get nasNoSources => 'メディアソースが設定されていません';

  @override
  String get nasNoSourcesDesc =>
      'SFTP、SMB、WebDAV、Jellyfin、または Emby を追加してメディアの閲覧を開始してください。';

  @override
  String get nasSourceType => 'ソースの種類';

  @override
  String get nasSourceName => 'ソース名';

  @override
  String get nasProbe => '接続テスト';

  @override
  String get nasProbeSuccess => '接続に成功しました';

  @override
  String get nasProbeFailed => '接続テストに失敗しました';

  @override
  String get nasEndpoint => 'エンドポイント / URL';

  @override
  String get nasRootPath => 'ルートパス';

  @override
  String get nasUsername => 'ユーザー名';

  @override
  String get nasPassword => 'パスワード';

  @override
  String get nasDomain => 'ドメイン (任意)';

  @override
  String get nasAuthenticate => '認証';

  @override
  String get nasAuthSuccess => '認証に成功しました';

  @override
  String get nasAuthFailed => '認証に失敗しました';

  @override
  String get nasTabDownloads => 'ダウンロード';

  @override
  String get nasNoDownloads => 'ダウンロードタスクはありません';

  @override
  String get nasDownloadQueued => '待機中';

  @override
  String get nasDownloadDownloading => 'ダウンロード中';

  @override
  String get nasDownloadCompleted => '完了';

  @override
  String get nasDownloadCancelled => 'キャンセル済み';

  @override
  String get nasDownloadFailed => 'ダウンロード失敗';

  @override
  String get nasRetryDownload => '再試行';

  @override
  String get nasCancelDownload => 'キャンセル';

  @override
  String get nasOpenDownloadedFile => 'ファイルを開く';

  @override
  String get nasQueue => '再生キュー';

  @override
  String get nasNoQueue => '再生キューは空です';

  @override
  String get nasSpeed => '速度';

  @override
  String get nasQuality => '画質';

  @override
  String get nasAudioTrack => '音声トラック';

  @override
  String get nasSubtitleTrack => '字幕';

  @override
  String get nasRepeatOff => 'リピートオフ';

  @override
  String get nasRepeatAll => 'すべてリピート';

  @override
  String get nasRepeatOne => '1曲リピート';

  @override
  String get nasShuffle => 'シャッフル';

  @override
  String get nasCast => 'キャスト';

  @override
  String get nasCastUnavailable => '利用可能なキャストデバイスはありません';

  @override
  String get nasSlideshow => 'スライドショー';

  @override
  String get nasByFolder => 'フォルダー';

  @override
  String get nasByArtist => 'アーティスト';

  @override
  String get nasByAlbum => 'アルバム';

  @override
  String get nasAllTracks => 'すべてのトラック';

  @override
  String get nasPlayAll => 'すべて再生';

  @override
  String get nasPreviousPage => '前へ';

  @override
  String get nasNextPage => '次へ';

  @override
  String get nasClearScope => 'すべてに戻る';

  @override
  String get nasRenamePlaylist => 'プレイリスト名を変更';

  @override
  String get nasRemoveFromPlaylist => 'プレイリストから削除';

  @override
  String get nasMoveUp => '上へ移動';

  @override
  String get nasMoveDown => '下へ移動';

  @override
  String get nasSshServer => 'SSH サーバー';

  @override
  String get nasSelectSshServer => '保存された SSH サーバーを選択';

  @override
  String get nasQualityOriginal => 'オリジナル';

  @override
  String get nasQualityAuto => '自動';

  @override
  String get nasQuality4Mbps => '4 Mbps';

  @override
  String get nasQuality10Mbps => '10 Mbps';

  @override
  String get nasQuality20Mbps => '20 Mbps';

  @override
  String get nasCastDevices => '利用可能な DLNA デバイス';

  @override
  String get nasCastDiscovering => 'DLNA デバイスを検索中...';

  @override
  String get nasCastRelayingNotice =>
      'フォアグラウンドアプリ経由でストリームを中継しています。Valhalla を開いたままにしてください。';

  @override
  String get nasCastStop => 'キャストを停止';

  @override
  String get nasCastVolume => '音量';

  @override
  String get nasCastRetry => '検索を再試行';

  @override
  String get nasInstallTitle => 'NAS メディアサーバーのデプロイ';

  @override
  String get nasInstallProduct => '製品';

  @override
  String get nasInstallMediaPath => 'メディアディレクトリ (読み取り専用)';

  @override
  String get nasInstallDataRoot => 'データ & 設定ディレクトリ';

  @override
  String get nasInstallPort => 'ポート';

  @override
  String get nasInstallBindAddress => 'バインドアドレス';

  @override
  String get nasInstallWebdavUser => 'WebDAV ユーザー名';

  @override
  String get nasInstallWebdavPassword => 'WebDAV パスワード (最低12文字)';

  @override
  String get nasInstallPreparePlan => 'デプロイ計画を確認';

  @override
  String get nasInstallPlanTitle => '技術レビューと確認';

  @override
  String get nasInstallBlockersTitle => 'デプロイの障害要因';

  @override
  String get nasInstallConfirmDeploy => '確認してインストール';

  @override
  String get nasInstallDeploying => 'コンテナをデプロイ中...';

  @override
  String get nasInstallSuccess => 'デプロイが完了しました';

  @override
  String get nasInstallSuccessDesc =>
      'サービスが実行中です。メディアソースとして追加する前に、サーバーの初期設定を完了してください。';

  @override
  String get nasInstallContainerId => 'コンテナ ID';

  @override
  String get nasInstallEndpoint => 'エンドポイント';

  @override
  String get nasUseSshTunnel => 'SSH トンネルを使用';

  @override
  String get nasUseSshTunnelDesc =>
      '保存された SSH サーバー経由でトラフィックをルーティング (例: http://127.0.0.1:8096)';

  @override
  String get nasSshTunnelHint =>
      'エンドポイントは SSH サーバーからアクセス可能である必要があります (例: http://127.0.0.1:8096)';

  @override
  String get nasKeepEmptyPassword => '空欄のままにすると既存のパスワード/トークンを保持します';

  @override
  String get nasSourceNameRequired => 'ソース名は必須です';

  @override
  String get nasInvalidEndpoint => '無効なエンドポイント URL またはスキームです';

  @override
  String get nasSourceUnreachable => 'メディアソースに接続できません';

  @override
  String get nasSshTunnelFailed => 'SSH トンネル接続に失敗しました';

  @override
  String get nasOperationFailed => '操作に失敗しました';

  @override
  String get nasInstallStepCreateDir => 'プライベートディレクトリの作成';

  @override
  String get nasInstallStepWriteCompose => 'docker-compose.json 設定の書き込み';

  @override
  String get nasInstallStepWriteCreds => 'プライベート認証情報の書き込み';

  @override
  String get nasInstallStepPullImage => '固定コンテナイメージの取得';

  @override
  String get nasInstallStepStartService => 'コンテナ化サービスの開始';

  @override
  String get nasInstallStepCheckHttp => 'サービス HTTP ヘルスの確認';

  @override
  String get nasInstallBlockerDocker => 'ターゲットサーバーに Docker Engine が必要です';

  @override
  String get nasInstallBlockerCompose => 'Docker Compose プラグインが必要です';

  @override
  String get nasInstallBlockerIdentity => 'ターゲットサーバーの識別情報を確認できませんでした';

  @override
  String get nasInstallBlockerTools =>
      '必要なツール (curl, ss, realpath) がターゲットサーバーにありません';

  @override
  String get nasInstallBlockerMedia => 'メディアディレクトリが存在しないか、読み取り可能ではありません';

  @override
  String get nasInstallBlockerParent => 'データルートの親ディレクトリに書き込み権限がありません';

  @override
  String get nasInstallBlockerOverlap => 'メディアディレクトリとデータディレクトリは重複できません';

  @override
  String get nasInstallBlockerCollision => '対象のデータディレクトリがすでに存在するかシンボリックリンクです';

  @override
  String get nasInstallBlockerPort => '選択されたポートはターゲットサーバーですでに使用されています';

  @override
  String get nasInstallBlockerContainer => 'このプロジェクト名のコンテナがすでに存在します';

  @override
  String get nasInstallBlockerImage =>
      'コンテナイメージの検証に失敗しました。イメージ名、ネットワーク接続、サーバーアーキテクチャを確認して再試行してください。';

  @override
  String get nasInstallGuidanceTunnel =>
      'ループバックバインド (127.0.0.1) ではリモートアクセスのために SSH トンネルが必要です';

  @override
  String get nasInstallGuidanceTls => 'パブリックバインドは TLS リバースプロキシの背後で保護することを推奨します';

  @override
  String get nasInstallGuidanceSetup => '初回起動時にブラウザで初期管理者アカウントの設定を完了してください';

  @override
  String get nasInstallGuidanceReadOnly =>
      'ファイルを保護するため、メディアディレクトリは読み取り専用でマウントされます';

  @override
  String get nasInstallGuidancePreserved =>
      'トラブルシューティングのため、失敗時もデータディレクトリは保持されます';

  @override
  String get nasDownloadCompletedWithOpenError => 'ダウンロード完了 (外部アプリでの起動に失敗)';

  @override
  String get nasRetryOpen => '開くのを再試行';

  @override
  String get nasExternalOpenFailed => '外部アプリでファイルを開けませんでした';

  @override
  String get nasTitle => 'NAS メディア';

  @override
  String get nasLoadMoreGroups => 'さらにグループを読み込む';

  @override
  String get nasMetadataEnriching => '音楽タグを解析中...';

  @override
  String nasMetadataEnrichingWithCount(int count) {
    return '音楽タグを解析中 ($count 件処理済み)...';
  }

  @override
  String nasDownloading(String value) {
    return '$value をダウンロード中…';
  }

  @override
  String get nasSubtitleNone => 'なし';

  @override
  String get nasLibraryId => 'ライブラリ ID';

  @override
  String get nasLibraryIdHint => 'デフォルト: 全体 (/)、またはライブラリ ID を指定';

  @override
  String nasScanPathRelativeHint(String value) {
    return 'ソースルートからの相対パス ($value)';
  }

  @override
  String get nasSourceChangedError => '設定中にソースが変更されたため、保存を中止しました';

  @override
  String get nasInvalidLibraryId => '無効なライブラリ ID です';

  @override
  String get startupFailed => 'アプリの起動に失敗しました';

  @override
  String get startupFailedDesc =>
      '起動中に予期しないエラーが発生しました。再試行するか診断ログをエクスポートしてください。';

  @override
  String get retryStartup => '起動を再試行';

  @override
  String get viewDiagnostics => '診断ログを表示';

  @override
  String get exportDiagnostics => '診断ログをエクスポート';

  @override
  String diagnosticsExportSuccess(String path) {
    return '診断ログを $path にエクスポートしました';
  }

  @override
  String get diagnosticsExportFailed => '診断ログのエクスポートに失敗しました';

  @override
  String get diagnosticsTitle => 'アプリ診断';

  @override
  String get settingsDiagnostics => '診断 & ログ';

  @override
  String get settingsDiagnosticsDesc => 'サニタイズされたローカルアプリケーションログを表示・エクスポート';

  @override
  String get diagnosticsEmpty => '診断レコードは見つかりませんでした';

  @override
  String diagnosticsStorageError(String error) {
    return '診断ログのストレージエラー: $error';
  }

  @override
  String diagnosticsIncidentNotice(String category) {
    return '回復可能なインシデントが報告されました: $category';
  }

  @override
  String get diagnosticsRefresh => 'ログを更新';

  @override
  String get nasInstallTaskTitle => 'デプロイタスク';

  @override
  String get nasInstallStagePreflight => '事前チェック';

  @override
  String get nasInstallStageReview => '計画レビュー';

  @override
  String get nasInstallStageWriting => '設定を書き込み中';

  @override
  String get nasInstallStagePulling => 'イメージを取得中';

  @override
  String get nasInstallStageStarting => 'コンテナを起動中';

  @override
  String get nasInstallStageHealth => 'ヘルスチェック中';

  @override
  String get nasInstallStageCleanup => 'クリーンアップ中';

  @override
  String get nasInstallStageSucceeded => 'デプロイ成功';

  @override
  String get nasInstallStageFailed => 'デプロイ失敗';

  @override
  String get nasInstallStageCancelled => 'デプロイ中止';

  @override
  String get nasInstallStageNeedsInspection => '手動検査が必要';

  @override
  String get nasInstallStageReconciling => '状態を調整中';

  @override
  String get nasInstallCancel => 'デプロイを中止';

  @override
  String get nasInstallReconcile => '状態を再同期';

  @override
  String get nasInstallServerNotFound => '選択されたサーバーが見つかりませんでした';

  @override
  String get nasInstallPortRangeError => 'ポートは 1 から 65535 の間である必要があります';

  @override
  String nasInstallElapsedTime(String time) {
    return '経過時間: $time';
  }

  @override
  String get nasInstallLogTail => '最新のログ';

  @override
  String get nasInstallCleanupCompleted => 'ロールバッククリーンアップ完了';

  @override
  String get nasInstallCleanupIncomplete => 'ロールバッククリーンアップ不完全';

  @override
  String get nasInstallNewDeployment => '新規デプロイ';

  @override
  String get nasInstallBackEdit => '戻る / フォームを編集';

  @override
  String get nasInstallClose => '閉じる';

  @override
  String get nasInstallMediaPathHint => 'ホスト側の読み取り専用バインドマウント (例: /mnt/media)';

  @override
  String get nasInstallDataRootHint => 'プライベートデータ & 設定ディレクトリ (存在しないこと)';

  @override
  String get nasInstallBindAddressHint => 'トンネル用は 127.0.0.1、LAN 用は 0.0.0.0';

  @override
  String get nasInstallWebdavPasswordHint => '12文字以上が必須です';

  @override
  String get nasInstallTargetServer => '対象サーバー';

  @override
  String get nasInstallTargetImage => '対象イメージ';

  @override
  String get nasInstallContainerName => 'コンテナ名';

  @override
  String get nasInstallBindAndPort => 'バインド & ポート';

  @override
  String get nasInstallComposePreview => 'docker-compose.json プレビュー';

  @override
  String get nasInstallPlannedSteps => '計画された手順';

  @override
  String get nasInstallGuidanceNotes => 'デプロイに関する注意事項とガイダンス';

  @override
  String get nasInstallNoLogsYet => 'ログはまだありません';

  @override
  String get sftpPreviewTooLarge =>
      'ファイルサイズが 1 MiB のプレビュー制限を超えています。ダウンロードして外部で開いてください。';

  @override
  String get sftpSaveFailed => 'ファイルの保存に失敗しました。権限またはネットワーク接続を確認してください。';

  @override
  String get sftpSaving => '保存中...';

  @override
  String get nasInstallBlockerConnectionChanged =>
      '対象サーバーの接続が変更されました。続行する前にリモートの状態を確認してください。';

  @override
  String get nasInstallBlockerCancelled =>
      'デプロイはユーザーによってキャンセルされました。設定を確認して再試行してください。';

  @override
  String get nasInstallBlockerInspectFailed =>
      'リモートコンテナの検査に失敗しました。接続を確認するか手動で検査してください。';

  @override
  String get nasInstallBlockerDeadlineExceeded =>
      'デプロイ手順がタイムアウトしました。サーバー負荷またはネットワークを確認して再試行してください。';

  @override
  String get nasInstallBlockerInterrupted =>
      'デプロイが中断されました。続行する前にリモートの状態を確認してください。';

  @override
  String get nasInstallBlockerHealthTimeout =>
      'サービスは開始されましたが、HTTP ヘルスチェックがタイムアウトしました。ログまたはポートを確認してください。';

  @override
  String get nasInstallBlockerReconciliationFailed =>
      '状態の再同期に失敗しました。リモートコンテナを手動で確認するか、新規デプロイを開始してください。';

  @override
  String get nasInstallBlockerRemoteInspectionRequired =>
      'リモートコンテナの状態が不確定です。手動での検査と同期が必要です。';

  @override
  String get nasInstallBlockerServiceExited =>
      'コンテナプロセスが早期に終了しました。設定や権限のエラーがないかログを確認してください。';

  @override
  String get nasInstallBlockerWriteFailed =>
      '対象サーバーへのデプロイファイルの書き込みに失敗しました。ディスク容量と権限を確認してください。';

  @override
  String get nasInstallBlockerPlanStale => 'デプロイ計画が古くなっています。事前チェックを再実行してください。';

  @override
  String get nasInstallBlockerOwnershipChanged =>
      '既存のコンテナはこのアプリで作成されたものではありません。上書きを防ぐため手動で検査してください。';

  @override
  String get nasInstallBlockerSshRequired => '対象サーバーへのアクティブな SSH 接続が必要です。';

  @override
  String get nasInstallBlockerReconciliationRequired =>
      'リモートの状態がローカルと異なります。続行する前に同期してください。';

  @override
  String get nasInstallBlockerFailed => 'デプロイでエラーが発生しました。ログを確認して再試行してください。';

  @override
  String get nasInstallBlockerBusy => '別のインストールタスクがすでに進行中です。現在の進捗を確認してください。';

  @override
  String get nasInstallBlockerStateSaveFailed =>
      'デプロイ状態の保存に失敗しました。ローカルストレージ容量とファイル権限を確認してください。';

  @override
  String get nasInstallBlockerCommandResultUnknown =>
      'リモートコマンドの結果が不明です。再試行する前に読み取り専用の検査を実行してください。';

  @override
  String get nasInstallBlockerPreflightFailed =>
      'デプロイ前の環境チェックに失敗しました。障害要因を解決してから続行してください。';

  @override
  String serverDeleteFailed(String error) {
    return 'サーバーの削除に失敗しました: $error';
  }

  @override
  String get chatRunSettingsAgentMode => 'エージェントモード';

  @override
  String get chatRunSettingsApprovalPolicy => 'ローカル承認ポリシー';

  @override
  String get chatRunSettingsExtraSettings => '追加設定';

  @override
  String get chatPermissionAutoAllowSafeDesc =>
      '既知の安全な操作を自動的に許可します。安全性を判断できない場合は常に確認します。';

  @override
  String chatRunSettingsSaveFailed(String error) {
    return '実行設定の適用に失敗しました: $error';
  }

  @override
  String get chatMessageCopied => 'メッセージをクリップボードにコピーしました';

  @override
  String get copy => 'コピー';

  @override
  String get rename => '名前を変更';

  @override
  String get refresh => '更新';

  @override
  String get sessionTitle => 'セッション名';

  @override
  String get chatSettingsStale => '古い設定';

  @override
  String get chatSettingsAvailableAfterFirstMessage => '最初のメッセージ送信後に設定可能になります';

  @override
  String get chatReimportAsCopy => 'コピーとして再インポート';

  @override
  String get chatSearchCommandsHint => 'コマンドまたはスキルを検索...';

  @override
  String get chatCommandsTab => 'コマンド';

  @override
  String get chatSkillsTab => 'スキル';

  @override
  String get chatAccountAndQuotaTitle => 'アカウント & クォータ';

  @override
  String get chatAccountSectionTitle => 'アカウント';

  @override
  String get chatAccountNotProvided => 'アカウント情報はありません';

  @override
  String get chatAccountKind => '種類';

  @override
  String get chatAccountLabel => 'ラベル';

  @override
  String get chatAccountPlan => 'プラン';

  @override
  String get chatAccountEmail => 'メールアドレス';

  @override
  String get chatAccountUpdatedAt => '更新日時';

  @override
  String get chatQuotaSectionTitle => 'クォータ & ステータス';

  @override
  String get chatStatusSourceNote => 'エージェントの生 /status 出力';

  @override
  String get chatStatusNotQueried => 'ステータスはまだ問い合わせていません';

  @override
  String get chatQueryStatusAction => 'ステータスを問い合わせ (/status)';

  @override
  String get chatQueryStatusUnavailable => '現在のセッションではステータス問い合わせを利用できません';

  @override
  String get chatAttachmentMissing => '添付ファイルが見つからないか利用できません';

  @override
  String get chatViewModeList => 'リスト';

  @override
  String get chatViewModeCards => 'カード';

  @override
  String get chatViewModeGrid => '画像';

  @override
  String get chatRemoteBrowserTitle => 'リモートワークスペース';

  @override
  String get chatSelectDirectory => 'ディレクトリを選択';

  @override
  String chatAttachSelectedFiles(int count) {
    return '選択した項目を添付 ($count)';
  }

  @override
  String get chatNoFilesFound => 'ファイルが見つかりません';

  @override
  String get chatRootDirectory => 'ルート';

  @override
  String get chatSelectThisDirectory => 'このディレクトリを使用';

  @override
  String get chatAgentVersion => 'エージェントバージョン';

  @override
  String get chatParentDirectory => '親ディレクトリ';

  @override
  String get chatSearchFilesHint => 'ファイルを検索...';

  @override
  String get chatCommandsEmpty => 'エージェントからスラッシュコマンドが提供されていません';

  @override
  String get chatSkillsEmpty => 'エージェントからスキルが提供されていません';

  @override
  String get chatFileUnsupported => 'このファイル形式は添付に対応していません';

  @override
  String get chatStatusNotProvided => 'エージェントからステータス問い合わせが提供されていません';

  @override
  String get sessionRecoveryReconnecting => '再接続中...';

  @override
  String get sessionRecoverySyncing => '出力を同期中...';

  @override
  String get sessionRecoveryIncomplete => '一部の出力を復元できませんでした';

  @override
  String get sessionRecoveryFailed => '復元に失敗しました';

  @override
  String get sessionRecoveryRetry => '再試行';

  @override
  String get dashboardUpdatesPaused => '更新を一時停止しました';

  @override
  String get chatSettingsIndependentModelUnavailable =>
      'CLI モデルカタログは現在利用できません。モデルがキャッシュされているか CLI バージョンにより制限されている可能性があります。モデル名を手動で入力することもできます。';

  @override
  String get chatSettingsModelCatalogNote =>
      'モデルは既存の CLI ログインを使用して CLI アプリサーバーから取得されます。カタログはキャッシュまたはバージョン制限されている場合があります。手動で更新するか手動入力に切り替えることができます。';

  @override
  String get chatModelCatalogError403 =>
      'CLI モデル取得アクセスが拒否されました (403)。CLI ログインと接続を確認するか、モデル名を手動で入力してください。';

  @override
  String chatModelCatalogErrorGeneric(String error) {
    return 'モデルカタログエラー: $error';
  }

  @override
  String get chatModelAuthorizeButton => 'モデルカタログを認可';

  @override
  String get chatModelAuthorizeConfirmTitle => 'モデルカタログの認可';

  @override
  String get chatModelAuthorizeConfirmMessage =>
      'ターゲットホスト/コンテナ上でモデルカタログ用のブラウザ認証を開始します。既存の Codex ログインとターミナルセッションはそのまま維持されます。続行しますか？';

  @override
  String get chatModelAuthorizing => 'ブラウザ経由で認可中...';

  @override
  String get chatModelAuthorizeCancel => '認可をキャンセル';

  @override
  String get chatCommandsFirstTurnNote =>
      'スラッシュコマンドはセッション初期化後にエージェントランタイムから提示されます。事前の通常の会話は不要です。下書きから自動的にセッションが作成されることはありません。';

  @override
  String get chatCommandsClientActionRunSettings => '実行設定';

  @override
  String get chatCommandsClientActionWorkingDirectory => '作業ディレクトリ';

  @override
  String get chatCommandsClientActionsSection => 'ローカルアクション';

  @override
  String get chatRunSettingsModelSourceCatalog => 'モデル一覧';

  @override
  String get chatRunSettingsModelSourceCustom => '手動入力';

  @override
  String get chatRunSettingsCustomModelHint => 'モデル ID を入力';

  @override
  String get chatRunSettingsCustomModelNotice =>
      '手動入力されたモデル名は検証されずにエージェントランタイムに直接送信されるため、未サポートのモデルは拒否される可能性があります。';

  @override
  String get chatRunSettingsCustomModelEmptyError => 'モデル名を空にすることはできません';

  @override
  String get chatRunSettingsCustomModelInvalidError =>
      'モデル名は空白や制御文字を含まない 256 文字以内である必要があります';

  @override
  String get chatCommandsDraftPreviewNotice =>
      '現在の適合バージョンで検証済みのコマンドです。選択すると下書きにテキストが挿入されます。送信時にオンデマンドでセッションが初期化され、コマンドが直接実行されます。';

  @override
  String get chatCommandsDiscoveryFailed => 'コマンドまたはスキルの検出に失敗しました';

  @override
  String get chatAuthWaitingForBrowser => 'ブラウザでの認可を待機中...';

  @override
  String get chatAuthBrowserLaunchFailed =>
      '外部ブラウザを開けませんでした。以下の認可リンクを開くかコピーしてください。';

  @override
  String get chatAuthReopenBrowser => 'ブラウザを再度開く';

  @override
  String get chatAuthCopyLink => 'リンクをコピー';

  @override
  String get chatAuthManualCallback => '手動コールバック';

  @override
  String get chatAuthManualCallbackTitle => '認可コールバック URL を入力';

  @override
  String get chatAuthManualCallbackDesc =>
      'ブラウザからリダイレクトされた完全な URL (http://127.0.0.1:PORT/...?code=...&state=...) を貼り付けて認可を完了してください。生の認可コードは受け付けられません。';

  @override
  String get chatAuthCallbackInputLabel => 'コールバック URL';

  @override
  String get chatAuthCallbackInputHint =>
      'http://127.0.0.1:PORT/...?code=...&state=...';

  @override
  String get chatAuthCallbackInvalidError => '無効なコールバック URL 形式、または配信に失敗しました';

  @override
  String get agentAuthAgYNotice =>
      'Antigravity ACP にはターミナル CLI ログインとは別に、公式アカウントの認可が必要です。';

  @override
  String get chatAuthDiscoveryPrompt => 'このターンには ACP 認証が必要です。再接続して認可を要求してください。';

  @override
  String get chatRequestAuthButton => '認証を要求';

  @override
  String get agentActionAcpLogin => 'ACP サインイン';

  @override
  String get agentActionCliLogin => 'CLI ログイン';

  @override
  String get agentAgyAcpSignInRequired => 'ACP 認証情報がありません (ACP サインインが必要)';

  @override
  String get agentAgyAcpCredentialsSaved => 'ACP 認証情報を保存しました (未検証)';

  @override
  String get chatAuthMethodUnavailable => '選択された認証方式は利用できません。';

  @override
  String get chatAuthConnectionExpired => '認証接続の有効期限が切れました。もう一度お試しください。';

  @override
  String get chatAuthCallbackDeliveryFailed => 'サーバーへの認可コールバックの配信に失敗しました。';

  @override
  String get agentTargetChangedNotice =>
      '対象サーバーが変更されました。現在のサーバーでエージェント管理を再度開いてください。';

  @override
  String get agentAgyAuthCheckUnavailable => 'Antigravity 認証確認を利用できません';

  @override
  String get agentAgyAuthCheckInvalid => 'Antigravity 認証確認の応答が無効です';

  @override
  String get sftpDownloadDisconnected => 'ダウンロードが切断されました';

  @override
  String get sftpDownloadPermissionDenied => '権限が拒否されました';

  @override
  String get sftpDownloadNotFound => 'リモートファイルが見つかりません';

  @override
  String get sftpDownloadTimeout => 'ダウンロードがタイムアウトしました';

  @override
  String get sftpDownloadLocalSpace => 'ローカルストレージの空き容量が不足しています';

  @override
  String get sftpDownloadLocalIo => 'ローカルストレージへの書き込みに失敗しました';

  @override
  String get sftpDownloadIncomplete => 'ダウンロードが不完全です';

  @override
  String get transferStatusWaitingConnection => '接続待機中';

  @override
  String get chatAuthCallbackListenerFailed =>
      'ローカル認可コールバックリスナーの起動に失敗しました。認証を再試行してください。';

  @override
  String get settingsExperimentalFeatures => '実験的機能';

  @override
  String get settingsExperimentalFeaturesDesc => 'プレビュー機能や実験的機能を試す';

  @override
  String get settingsExperimentalCliChatTitle => 'CLI スマートチャット';

  @override
  String get settingsExperimentalCliChatDesc =>
      '専用のコマンドラインエージェント対話インターフェースを有効化';

  @override
  String get settingsExperimentalDialogClose => '閉じる';

  @override
  String get settingsExperimentalSaveFailed => '実験的機能の設定更新に失敗しました';

  @override
  String get settingsExperimentalNasTitle => 'NAS メディア';

  @override
  String get settingsExperimentalNasDesc => 'メディアライブラリ、フォルダーのスキャン、オーディオ再生を有効化';

  @override
  String get settingsLanguageSaveFailed => '言語設定の更新に失敗しました';

  @override
  String get settingsAboutPrivacy => '情報とプライバシー';

  @override
  String get privacyPolicyTitle => 'プライバシーポリシー';

  @override
  String get privacyPolicyDescription => 'データの使用と選択肢';

  @override
  String get privacyContactTitle => 'プライバシーに関する連絡先';

  @override
  String get privacyCopyEmail => 'メールアドレスをコピー';

  @override
  String get privacyEmailCopied => 'メールアドレスをコピーしました';

  @override
  String get privacyOnlineVersion => 'オンライン版を表示';

  @override
  String get privacyLinkFailed => 'リンクを開けません。メールアドレスはコピーできます。';

  @override
  String get privacyLoadFailed => 'ポリシーを読み込めません。オンライン版をご覧ください。';

  @override
  String get privacyVersionUnknown => 'バージョン情報なし';

  @override
  String get aboutWebsite => '公式サイト';

  @override
  String get aboutLicense => 'アプリのライセンス';

  @override
  String get aboutThirdPartyLicenses => 'サードパーティのオープンソースライセンス';

  @override
  String get aboutLicenseSummary =>
      'Valhalla の独自コンテンツには、非商用向けの PolyForm Noncommercial 1.0.0 が適用されます。ライセンスの許可範囲を超える商用利用には別途許諾が必要です。第三者のコンポーネントには各自のライセンスが適用されます。利用条件は以下の全文に従います。';

  @override
  String get aboutCopyrightNotice => '著作権表示';

  @override
  String get aboutLicenseLoadFailed =>
      'ライセンスを読み込めません。norns.soft@gmail.com にお問い合わせください。';

  @override
  String get aboutLinkFailed =>
      'リンクを開けません。ブラウザで https://norns.cc.cd にアクセスしてください。';

  @override
  String get downloadReveal => 'エクスプローラーで表示';

  @override
  String get downloadRevealFailed => 'ダウンロードフォルダーを開けません。移動または削除された可能性があります。';

  @override
  String settingsKnownHostsSubtitle(int count) {
    return '$count 件の信頼済みホストキー';
  }

  @override
  String get settingsKnownHostsEmpty => '信頼済みホストキーはありません';

  @override
  String get settingsKnownHostsDialogTitle => '既知のホストキー';

  @override
  String get settingsHostKeyRevoke => '取り消す';

  @override
  String get settingsHostKeyRevokeConfirmTitle => 'ホストキーの取り消し';

  @override
  String settingsHostKeyRevokeConfirmMessage(String hostPort) {
    return '$hostPort のホストキーを取り消しますか？該当ホストのアクティブなSSH接続は切断され、次回接続時にホストキーの再確認が必要になります。';
  }

  @override
  String get settingsHostKeyFingerprintCopied => 'フィンガープリントをクリップボードにコピーしました';

  @override
  String get settingsHostKeyRevoked => 'ホストキーを取り消しました';

  @override
  String get settingsClearStorageSubtitle => '選択したサーバーのパスワードと秘密鍵を消去';

  @override
  String get settingsClearStorageDialogTitle => 'サーバー認証情報の初期化';

  @override
  String get settingsClearStorageDesc =>
      '安全なストレージからSSHパスワードと秘密鍵を消去するサーバーを選択します。サーバー設定やチャット履歴は削除されません。';

  @override
  String get settingsClearStorageNoServers => '登録されているサーバーがありません';

  @override
  String get settingsClearStorageSelectAll => 'すべて選択';

  @override
  String get settingsClearStorageDeselectAll => '選択解除';

  @override
  String get settingsClearStorageConfirmTitle => '認証情報消去の確認';

  @override
  String settingsClearStorageConfirmMessage(int count) {
    return '選択した $count 台のサーバーの認証情報を消去しますか？これらのサーバーへのアクティブな接続は直ちに切断されます。';
  }

  @override
  String settingsClearStorageAction(int count) {
    return '選択項目を消去 ($count)';
  }

  @override
  String get settingsClearStorageSuccess => '選択したサーバーの認証情報を消去しました';

  @override
  String get settingsClearStorageError => '一部のサーバー認証情報の消去に失敗しました。もう一度お試しください。';

  @override
  String get settingsDefaultAcpAgent => 'デフォルト ACP エージェント';

  @override
  String get settingsDefaultAcpAgentSubtitle => 'このサーバーのACPチャット用デフォルトエージェント';

  @override
  String get settingsDefaultCliAgent => 'デフォルト CLI エージェント';

  @override
  String get settingsDefaultCliAgentSubtitle => 'このサーバーのCLIチャット用デフォルトエージェント';

  @override
  String get settingsDefaultAgentAutomatic => '自動（利用可能な最初の項目）';

  @override
  String get settingsDefaultAgentSelectTitle => 'デフォルトエージェントの選択';

  @override
  String get settingsDefaultAgentNoServer => 'サーバーが選択されていません';

  @override
  String get settingsDefaultAgentNoAgents => 'このサーバーに設定されたエージェントはありません';

  @override
  String get settingsDefaultAgentSaveFailed => 'デフォルトエージェントの設定更新に失敗しました';

  @override
  String get dockerViewGroupContainers => 'コンテナ';

  @override
  String get dockerViewGroupProjects => 'Compose プロジェクト';

  @override
  String get dockerProjectActionStart => 'プロジェクトを開始';

  @override
  String get dockerProjectActionStop => 'プロジェクトを停止';

  @override
  String get dockerProjectActionRestart => 'プロジェクトを再起動';

  @override
  String get dockerProjectConfirmStopTitle => 'Compose プロジェクトの停止';

  @override
  String get dockerProjectConfirmRestartTitle => 'Compose プロジェクトの再起動';

  @override
  String dockerProjectConfirmMessage(String action, String project, int count) {
    return 'プロジェクト「$project」に対して $action を実行しますか？以下の $count 個のコンテナが影響を受けます：';
  }

  @override
  String dockerProjectActionSuccess(String project, String action) {
    return 'プロジェクト「$project」の$actionが完了しました';
  }

  @override
  String dockerProjectActionPartial(
    String project,
    String action,
    int failedCount,
  ) {
    return 'プロジェクト「$project」の$actionが完了しました（$failedCount 件失敗）';
  }

  @override
  String get dockerNoProjects => 'Docker Compose プロジェクトが見つかりません';

  @override
  String get dockerMountsTitle => 'マウント';

  @override
  String get dockerMountReadOnly => '読み取り専用';

  @override
  String get dockerMountReadWrite => '読み書き可能';

  @override
  String get sftpBookmarksTitle => 'ディレクトリーブックマーク';

  @override
  String get sftpNoBookmarks => '保存されたブックマークはありません';

  @override
  String get sftpAddBookmark => 'ブックマークに追加';

  @override
  String get sftpRemoveBookmark => 'ブックマークを解除';

  @override
  String get sftpCurrentDirectory => '現在のディレクトリ';

  @override
  String get sftpSelectMode => '複数選択モード';

  @override
  String sftpSelectedCount(int count) {
    return '$count 件選択中';
  }

  @override
  String get sftpSelectAll => 'すべて選択';

  @override
  String get sftpDeselectAll => '選択を解除';

  @override
  String get sftpBatchCopy => 'コピー';

  @override
  String get sftpBatchMove => '移動';

  @override
  String get sftpBatchDeleteConfirmTitle => '一括削除の確認';

  @override
  String sftpBatchDeleteConfirmMessage(int count) {
    return '選択した $count 件のアイテムを削除してもよろしいですか？';
  }

  @override
  String get sftpBatchDeleteNonEmptyNotice =>
      '注意：空ではないディレクトリは再帰的に削除できないためスキップされます。';

  @override
  String get sftpBatchCopyConfirmTitle => '一括コピーの確認';

  @override
  String sftpBatchCopyConfirmMessage(int count, String directory) {
    return '選択した $count 件のアイテムを「$directory」にコピーしますか？';
  }

  @override
  String get sftpBatchMoveConfirmTitle => '一括移動の確認';

  @override
  String sftpBatchMoveConfirmMessage(int count, String directory) {
    return '選択した $count 件のアイテムを「$directory」に移動しますか？';
  }

  @override
  String get sftpBatchResultsTitle => '一括処理の結果';

  @override
  String get sftpBatchOutcomeSkipped => 'スキップ（既に存在するか非対応）';

  @override
  String get sftpBatchTargetRestricted =>
      '自身またはサブディレクトリをコピー・移動先として指定することはできません';

  @override
  String get sftpSelectCurrentDir => 'このディレクトリを選択';

  @override
  String sftpBatchOperationSuccess(int count) {
    return '$count 件の処理が完了しました';
  }

  @override
  String get configMigrationTitle => 'バックアップと設定移行';

  @override
  String get configExportTitle => '設定のエクスポート';

  @override
  String get configExportSubtitle =>
      'サーバー、エージェント、クイックコマンド、ブックマーク、設定をJSONにエクスポート';

  @override
  String get configExportDialogTitle => 'Valhalla設定のエクスポート';

  @override
  String get configExportSuccess => '設定を正常にエクスポートしました';

  @override
  String configExportError(String error) {
    return '設定のエクスポートに失敗しました: $error';
  }

  @override
  String get configImportTitle => '設定のインポート';

  @override
  String get configImportSubtitle => 'バックアップJSONファイルから設定をインポート';

  @override
  String get configBackupTooLarge => 'バックアップファイルが最大サイズ制限（8 MB）を超えています';

  @override
  String get configImportPreviewTitle => '設定インポートのプレビュー';

  @override
  String get configImportPreviewDesc => 'インポートする内容を確認してください。既存の項目は保持されマージされます。';

  @override
  String configImportServersCount(int count) {
    return 'サーバー ($count)';
  }

  @override
  String configImportAgentsCount(int count) {
    return 'エージェント ($count)';
  }

  @override
  String configImportCommandsCount(int count) {
    return 'クイックコマンド ($count)';
  }

  @override
  String configImportBookmarksCount(int count) {
    return 'ブックマーク ($count)';
  }

  @override
  String get configImportSecretWarning =>
      'カスタムコマンドには機密性の高いスクリプトや埋め込み認証情報が含まれる場合があります。パスワード、秘密鍵、信頼済みフィンガープリントは転送されません。';

  @override
  String get configImportGlobalPreferences => 'グローバルアプリケーション設定をインポート';

  @override
  String get configImportGlobalPreferencesDesc =>
      '現在のテーマ、ターミナル、ナビゲーション設定を上書きします';

  @override
  String get configImportConfirmAction => 'インポートを確認';

  @override
  String get configImportSuccess => '設定を正常にインポートしました';

  @override
  String get configImportErrorTitle => '無効な設定バックアップファイル';

  @override
  String configImportErrorGeneric(String error) {
    return '設定のインポートに失敗しました: $error';
  }

  @override
  String get configImportErrorCopyDetails => '診断詳細をコピー';

  @override
  String get configImportErrorCopied => '診断詳細をクリップボードにコピーしました';

  @override
  String get configImportErrorUnsupportedVersion =>
      'サポートされていないバックアップ形式またはバージョンです';

  @override
  String get configImportErrorMalformed => '設定JSONファイルが破損しているか形式が不正です';

  @override
  String get aboutRepository => 'GitHub リポジトリ';

  @override
  String get updateCheckTitle => 'アップデートを確認';

  @override
  String get updateChecking => 'アップデートを確認中...';

  @override
  String get updateCheckNow => '今すぐ確認';

  @override
  String get updateUpToDate => '最新バージョンです';

  @override
  String updateInstalledVersion(String version) {
    return 'インストール済み: v$version';
  }

  @override
  String updateAvailableBadge(String version) {
    return '新しいバージョンが利用可能: v$version';
  }

  @override
  String get updateViewUpdate => '更新を表示';

  @override
  String updateLastChecked(String time) {
    return '最終確認: $time';
  }

  @override
  String get updateNeverChecked => '未確認';

  @override
  String get updateAutoCheckTitle => '自動アップデート確認';

  @override
  String get updateAutoCheckSubtitle => 'アプリ起動時に毎日アップデートを確認します';

  @override
  String get updateAutoCheckSaveFailed => '自動更新設定の保存に失敗しました';

  @override
  String get updateDialogTitle => 'ソフトウェアアップデート';

  @override
  String updateCurrentVersion(String version) {
    return '現在のバージョン: $version';
  }

  @override
  String updateTargetVersion(String version) {
    return '最新: v$version';
  }

  @override
  String updateBuildNumber(String build) {
    return 'ビルド $build';
  }

  @override
  String updateCommit(String commit) {
    return 'コミット: $commit';
  }

  @override
  String get updateArtifactDetails => 'インストールパッケージ';

  @override
  String updateArtifactName(String name) {
    return 'ファイル: $name';
  }

  @override
  String updateArtifactSize(String size) {
    return 'サイズ: $size';
  }

  @override
  String updateArtifactHash(String hash) {
    return 'SHA-256 ハッシュ: $hash';
  }

  @override
  String get updateCopyHash => 'SHA-256 ハッシュをコピー';

  @override
  String get updateHashCopied => 'SHA-256 ハッシュをクリップボードにコピーしました';

  @override
  String get updateCopyCommit => 'コミットハッシュをコピー';

  @override
  String get updateCommitCopied => 'コミットハッシュをクリップボードにコピーしました';

  @override
  String get updateReleaseNotes => 'リリースノート';

  @override
  String get updateNoReleaseNotes => 'リリースノートはありません。';

  @override
  String get updateNoArtifactForPlatform =>
      'このデバイスのプラットフォーム/アーキテクチャ用の直接インストールパッケージはありません。';

  @override
  String get updateOpenReleasePage => 'GitHub でリリースページを開く';

  @override
  String get updateDownload => 'アップデートをダウンロード';

  @override
  String updateDownloading(String progress) {
    return 'ダウンロード中... $progress%';
  }

  @override
  String get updatePause => '一時停止';

  @override
  String get updateResume => '再開';

  @override
  String get updateRetry => '再試行';

  @override
  String get updateDownloadPaused => 'ダウンロード一時停止中';

  @override
  String get updateDownloadCompleted => 'ダウンロードが完了し検証されました';

  @override
  String get updateInstall => 'アップデートをインストール';

  @override
  String get updateRevealInFolder => 'フォルダーで表示';

  @override
  String get updateOpenFolder => 'ダウンロード先を開く';

  @override
  String get updateRetryInstall => 'インストールを再試行';

  @override
  String get updateDesktopInstructions =>
      'ダウンロードしたアーカイブを展開し、アプリを終了してから置き換えてください。実行中のプログラムを上書きしないでください。';

  @override
  String get updateCopyErrorDetails => 'エラー詳細をコピー';

  @override
  String get updateErrorCopied => 'エラー詳細をクリップボードにコピーしました';

  @override
  String get updateErrorRateLimited =>
      'GitHub API のレート制限を超過しました。しばらくしてから再試行してください。';

  @override
  String get updateErrorNetwork => 'ネットワーク接続に失敗しました。インターネット接続を確認してください。';

  @override
  String get updateErrorManifest => '更新マニフェストが無効であるか、必要なメタデータがありません。';

  @override
  String get updateErrorIntegrity => 'ダウンロードの整合性チェックに失敗しました。チェックサムが一致しません。';

  @override
  String get updateErrorSignatureMismatch =>
      'インストールの署名が一致しません: アップデートパッケージの署名が現在インストールされているアプリと異なります。データ損失を防ぐため、アプリをアンインストールしたりデータを消去したりしないでください。';

  @override
  String get updateErrorPermissionRequired =>
      'インストール権限が必要です。システム設定で Valhalla による不明なアプリのインストールを許可し、「インストールを再試行」をタップしてください。';

  @override
  String get updateErrorPermission => 'ストレージまたはシステムの権限が拒否されました。';

  @override
  String get updateErrorPackageInvalid => 'パッケージのパスまたはIDが無効です。';

  @override
  String get updateErrorStoreInstall =>
      'このアプリはアプリストアからインストールされました。ストアからアップデートしてください。';

  @override
  String get updateErrorPlatform => 'インストーラーを開くか起動できませんでした。';

  @override
  String get updateErrorGeneric => 'アップデートに失敗しました。再試行するか GitHub リリースを確認してください。';
}
