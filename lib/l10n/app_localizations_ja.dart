// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get nasPlaylistLoadFailed =>
      'プレイリストを一時的に読み込めません。保存済みのメディア一覧は引き続き表示できます。更新して再試行してください。';

  @override
  String get nasAllLibraries => 'すべてのライブラリ';

  @override
  String get nasDiagnosticsTitle => 'メディアソースの診断';

  @override
  String get nasDiagnosticsConnection => '接続';

  @override
  String get nasDiagnosticsScan => 'ライブラリのスキャン';

  @override
  String get nasDiagnosticsLastSuccess => '前回の接続成功日時';

  @override
  String get nasDiagnosticsCredentials => '保存済みの認証情報を確認中';

  @override
  String get nasDiagnosticsFinalizing => 'インデックスを仕上げ中';

  @override
  String get nasDiagnosticsNotChecked => '未確認';

  @override
  String get nasCacheLegacy => '旧形式のサムネイル（ソース未割り当て）';

  @override
  String get nasCacheGlobalBudget => 'サムネイル容量の上限（全ソース共通）';

  @override
  String get nasCacheNoSource => 'キャッシュを管理するメディアソースを選択してください。';

  @override
  String get nasOfflineRecordedHint =>
      '記録されたダウンロードのバイト数であり、実測のディスク使用量ではありません。サムネイルを削除してもオフラインファイルは削除されません。';

  @override
  String nasCacheClearConfirm(String scope) {
    return '$scope のサムネイルを削除しますか？オフラインファイルとリモートメディアは保持されます。';
  }

  @override
  String nasOfflineRecordedBytes(String size) {
    return '記録済みダウンロード量：$size';
  }

  @override
  String get nasDeployDockerTitle => 'Docker アプリ';

  @override
  String get nasDeployDockerDesc =>
      'アプリセンターで公式 Jellyfin アプリを開きます。インストール前に設定を確認してください。';

  @override
  String get nasDeployNativeDesc =>
      '公式パッケージを使用して、このサーバーに Jellyfin を直接インストールします。既存のインストールは変更しません。';

  @override
  String get nasDeployEnableAppCenter =>
      '実験的なアプリセンターを有効にして続行しますか？メニューの配置は変わりません。';

  @override
  String get nasDeployCatalogUnavailable =>
      '公式 Jellyfin アプリを利用できません。公式ソースが有効になっていることを確認してから、再試行してください。';

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
  String get agentClaudeCode => 'Claude Code';

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
  String get terminalKeyArrows => '矢印キー';

  @override
  String get terminalDirectionPad => '方向パッド';

  @override
  String get terminalCloseDirectionPad => '方向パッドを閉じる';

  @override
  String get terminalDirectionPadModeFixed => '右側に固定';

  @override
  String get terminalDirectionPadModeFlow => 'キーと一緒にスクロール';

  @override
  String get terminalDirectionPadModeHidden => '非表示';

  @override
  String get terminalDirectionKeyColor => '方向キーの色';

  @override
  String get terminalDirectionKeyColorDefault => 'テーマに従う';

  @override
  String get terminalDirectionKeyColorReset => 'テーマ色にリセット';

  @override
  String get terminalAccessorySaveFailed => 'アクセサリーバーの設定の保存に失敗しました';

  @override
  String get terminalDirectionKeyNormal => '通常';

  @override
  String get terminalDirectionKeyPressed => '押下時';

  @override
  String terminalPinnedKeysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '固定済み ($count)',
    );
    return '$_temp0';
  }

  @override
  String get terminalNoPinnedKeys => '固定されたキーはありません';

  @override
  String terminalAvailableKeysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '追加可能 ($count)',
    );
    return '$_temp0';
  }

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
  String get settingsTerminalUseTmux => '手動新規ターミナルモード';

  @override
  String get settingsTerminalUseTmuxSubtitle =>
      'リモートサーバー上の tmux 内でターミナルセッションを実行';

  @override
  String get settingsTerminalUseTmuxDescription =>
      '手動で新規作成したターミナルにのみ適用されます。自動作成される新規ターミナルは常に通常のSSHを使用し、復元可能な履歴は保持されません。tmuxを有効にすると、手動作成したセッションは切断後も復元できます（リモートにtmuxが必要）。既存の履歴復元には影響しません。';

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
  String get transferPhasePreparing => '準備中...';

  @override
  String get transferPhaseVerifyingPartial => '部分ファイルを検証中...';

  @override
  String get transferPhaseVerifying => '整合性を検証中...';

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
  String get updateOpenReleasePage => 'リリースページを開く';

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
  String get updatePhaseResolving => '更新サーバーに接続中...';

  @override
  String get updatePhaseVerifying => '更新パッケージを検証中...';

  @override
  String get updateOpeningInstaller => 'インストーラーを準備中...';

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
      'アップデートサービスのレート制限を超過しました。しばらくしてから再試行してください。';

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
  String get updateErrorGeneric => 'アップデートに失敗しました。再試行するかリリースページを確認してください。';

  @override
  String get servicePermissionDenied => 'サービスを管理する権限がありません';

  @override
  String get serviceUnsupported => 'このサービスではサポートされていない操作です';

  @override
  String get serviceQueryFailed => 'サービス状態の照会に失敗しました';

  @override
  String get serviceTargetChanged => '対象サーバーが変更されたため、操作をキャンセルしました';

  @override
  String get serviceActionInProgress => 'このサービスに対する別のアクションが進行中です';

  @override
  String get processIdentityChanged => 'プロセスが再起動されたため、終了を中止しました';

  @override
  String get processIdentityUnavailable => 'プロセスの開始時刻を取得できないため、終了を拒否しました';

  @override
  String get serviceLogsTitle => 'サービスログ';

  @override
  String get serviceLogsLoadOlder => '以前のログを読み込む';

  @override
  String get serviceLogsEmpty => 'ログが見つかりません';

  @override
  String get serviceLogsCopied => 'ログをクリップボードにコピーしました';

  @override
  String get fileEditorUnsavedTitle => '未保存の変更';

  @override
  String get fileEditorUnsavedMessage => '未保存の変更があります。終了する前に操作を選択してください：';

  @override
  String get fileEditorKeepDraft => '下書きを保持';

  @override
  String get fileEditorDiscard => '破棄';

  @override
  String get fileEditorDiscardConfirmTitle => '下書きを破棄しますか？';

  @override
  String get fileEditorDiscardConfirmMessage =>
      'ローカルの下書きを破棄し、サーバーから最新ファイルを再読み込みしますか？';

  @override
  String get fileEditorConflictBanner => 'サーバー上でファイルが変更されたか、ローカル下書きと競合しています。';

  @override
  String get fileEditorCopyDraft => '下書きをコピー';

  @override
  String get fileEditorDraftCopied => '下書きをクリップボードにコピーしました';

  @override
  String get fileEditorReload => '再読み込み';

  @override
  String get sftpAtomicSaveUnsupported => 'サーバーが安全なアトミック保存をサポートしていません';

  @override
  String get sftpEditorExpired => 'エディターセッションの有効期限が切れました';

  @override
  String get sftpDraftSaveFailed => 'ローカル下書きの保存に失敗しました';

  @override
  String get sftpEditConflict => 'サーバー上でファイルが変更されました。再読み込みまたは下書きをコピーしてください';

  @override
  String get sftpEditDraftConflict => 'ローカル下書きがサーバー上のファイルと競合しています';

  @override
  String get sftpTransferSourceChanged => '転送中にソースファイルが変更されました';

  @override
  String get sftpTransferPartialInvalid => '一時転送ファイルが無効または破損しています';

  @override
  String get sftpTransferCommitting => '転送はコミット中のため再開できません';

  @override
  String get sftpTransferCleanupFailed => '未完了の転送のクリーンアップに失敗しました';

  @override
  String get sftpUploadTargetExists => '送信先ファイルが既に存在します';

  @override
  String get sftpUploadCommitFailed => 'リモートアップロードの確定に失敗しました';

  @override
  String get sftpUploadSourceInvalid => 'ローカルのソースファイルが変更されたか無効です';

  @override
  String cachedDataNotice(String time) {
    return '$time にキャッシュ';
  }

  @override
  String get serviceLogsCapReached => '上限：保持ログは最大1000件です';

  @override
  String get nasThumbnailCacheUsage => 'サムネイルキャッシュ';

  @override
  String get nasThumbnailCacheBudget => 'キャッシュ上限';

  @override
  String get nasThumbnailCacheClear => 'キャッシュをクリア';

  @override
  String get nasThumbnailCacheCleared => 'サムネイルキャッシュをクリアしました';

  @override
  String get nasThumbnailCacheOff => 'オフ';

  @override
  String get navAppCenter => 'アプリセンター';

  @override
  String get settingsExperimentalAppCenterTitle => 'アプリセンター (Docker)';

  @override
  String get settingsExperimentalAppCenterDesc => '実験的なアプリストアおよびコンテナデプロイ管理';

  @override
  String get appCenterTitle => 'アプリセンター';

  @override
  String get appCenterTabStore => 'ストア';

  @override
  String get appCenterTabInstalled => 'インストール済み';

  @override
  String get appCenterTabTasks => 'タスク';

  @override
  String get appCenterSources => 'ソース';

  @override
  String get appCenterManageSources => 'ソースの管理';

  @override
  String get appCenterAddSource => 'ソースの追加';

  @override
  String get appCenterSourceName => 'ソース名';

  @override
  String get appCenterSourceUrl => 'ソースURL (HTTPS)';

  @override
  String get appCenterDeleteSource => 'ソースの削除';

  @override
  String get appCenterRefresh => '更新';

  @override
  String get appCenterSearchHint => 'アプリを検索...';

  @override
  String get appCenterFilterAllCategories => 'すべてのカテゴリ';

  @override
  String get appCenterFilterAllSources => 'すべてのソース';

  @override
  String get appCenterNoApps => 'アプリが見つかりません';

  @override
  String get appCenterNoInstalled => 'インストール済みのアプリはありません';

  @override
  String get appCenterNoTasks => '実行中または最近のタスクはありません';

  @override
  String get appCenterInstall => 'インストール';

  @override
  String get appCenterInstalledBadge => 'インストール済み';

  @override
  String get appCenterIncompatibleBadge => '非互換';

  @override
  String get appCenterUpdateAvailable => 'アップデート可能';

  @override
  String get appCenterArchitectureBlocker => 'アーキテクチャが対応していません';

  @override
  String get appCenterAppDetails => 'アプリの詳細';

  @override
  String get appCenterVersion => 'バージョン';

  @override
  String get appCenterCategory => 'カテゴリ';

  @override
  String get appCenterSource => 'ソース';

  @override
  String get appCenterArchitectures => '対応アーキテクチャ';

  @override
  String get appCenterScreenshots => 'スクリーンショット';

  @override
  String get appCenterDescription => '説明';

  @override
  String appCenterWizardTitle(String appName) {
    return '$appName をインストール';
  }

  @override
  String appCenterConfigureTitle(String appName) {
    return '$appName を設定';
  }

  @override
  String appCenterUpdateTitle(String appName) {
    return '$appName をアップデート';
  }

  @override
  String get appCenterStepEnvironment => '環境';

  @override
  String get appCenterStepConfig => '設定';

  @override
  String get appCenterStepReview => 'プラン確認';

  @override
  String get appCenterStepProgress => '進捗状況';

  @override
  String get appCenterInstanceName => 'インスタンス名';

  @override
  String get appCenterDataDirectory => 'データディレクトリ';

  @override
  String get appCenterBrowseDirectory => 'ディレクトリを選択';

  @override
  String get appCenterNetworkAndPorts => 'ネットワークとポート';

  @override
  String get appCenterBindAddress => 'バインドアドレス';

  @override
  String get appCenterBindLoopback => 'ローカルホストのみ (127.0.0.1)';

  @override
  String get appCenterBindAll => 'すべてのインターフェース (0.0.0.0)';

  @override
  String get appCenterPortMapping => 'ポートマッピング';

  @override
  String get appCenterMounts => 'ストレージマウント';

  @override
  String get appCenterMountSource => 'ホストパス';

  @override
  String get appCenterMountTarget => 'コンテナパス';

  @override
  String get appCenterMountReadOnly => '読み取り専用';

  @override
  String get appCenterVariables => '変数';

  @override
  String get appCenterEnvironmentVariables => '環境変数';

  @override
  String get appCenterNext => '次へ';

  @override
  String get appCenterBack => '戻る';

  @override
  String get appCenterConfirmAndExecute => 'プランを実行';

  @override
  String get appCenterPlanPreview => 'デプロイプランのプレビュー';

  @override
  String get appCenterPlanSanitizedNotice => '実行前に生成されたデプロイプランを確認してください：';

  @override
  String get appCenterEnvironmentCheck => 'Docker 環境';

  @override
  String get appCenterDockerFound => 'Docker が利用可能です';

  @override
  String get appCenterDockerMissing => 'Docker がインストールされていません';

  @override
  String get appCenterComposeFound => 'Docker Compose が利用可能です';

  @override
  String get appCenterComposeMissing => 'Docker Compose がインストールされていません';

  @override
  String get appCenterBootstrapPrompt =>
      'このサーバーに Docker と Compose を自動セットアップできます。root/sudo 権限が必要です。';

  @override
  String get appCenterBootstrapButton => 'Docker と Compose をインストール';

  @override
  String get appCenterSudoPassword => 'Sudo パスワード (任意 / 必要な場合)';

  @override
  String get appCenterSudoPasswordHint => '特権操作用の sudo パスワードを入力';

  @override
  String get appCenterOpen => 'Web UI を開く';

  @override
  String get appCenterStart => '起動';

  @override
  String get appCenterStop => '停止';

  @override
  String get appCenterRestart => '再起動';

  @override
  String get appCenterLogs => 'ログ';

  @override
  String get appCenterConfig => '設定';

  @override
  String get appCenterUpdate => 'アップデート';

  @override
  String get appCenterRestore => '復元';

  @override
  String get appCenterUninstall => 'アンインストール';

  @override
  String appCenterUninstallConfirmTitle(String appName) {
    return '$appName をアンインストールしますか？';
  }

  @override
  String appCenterUninstallConfirmMessage(String appName) {
    return '$appName をアンインストールしてもよろしいですか？コンテナは削除されますが、アプリのデータディレクトリは保持されます。';
  }

  @override
  String get appCenterUninstallKeepData => 'アンインストール（データを保持）';

  @override
  String get appCenterUninstallDeleteSelected => 'アンインストールして選択項目を削除';

  @override
  String get appCenterUninstallInspecting => 'アプリのデータディレクトリを確認中...';

  @override
  String get appCenterUninstallInspectionFailedWarning =>
      'データクリーンアップの確認に失敗しました。すべてのデータを安全に保持したまま、アプリコンテナのみをアンインストールできます。';

  @override
  String get appCenterUninstallDirectoriesTitle => 'データディレクトリと Docker ボリューム';

  @override
  String get appCenterUninstallNoDirectories =>
      'バインドマウントのデータディレクトリは検出されませんでした。データを保持したままコンテナが削除されます。';

  @override
  String get appCenterUninstallDefaultPreservedHint =>
      '既定ではすべてのデータを保持します。完全に削除するディレクトリやボリュームのみを選択してください。';

  @override
  String get appCenterUninstallPermanentLossWarning =>
      '選択したデータはサーバーから完全に削除されます。ゴミ箱はありません。';

  @override
  String get appCenterUninstallSelectedPathsTitle => '完全に削除するデータ：';

  @override
  String get appCenterUninstallRiskAck =>
      '表示されたリスクと他のアプリへの影響を理解し、このデータの完全削除を確認します。';

  @override
  String get remoteBrowserAllFileTypes => 'すべての形式';

  @override
  String get remoteBrowserDocuments => 'テキストと文書';

  @override
  String get remoteBrowserFileFormat => 'ファイル形式';

  @override
  String get appCenterUninstallRiskSystem => 'システムパス';

  @override
  String get appCenterUninstallRiskShared => '他のアプリと共有';

  @override
  String get appCenterUninstallRiskVolume => 'Docker ボリューム';

  @override
  String get appCenterCleanupVolumeDeleteFailed =>
      'Docker ボリュームを削除できませんでした。他のコンテナによる使用を解除し、再確認してから再試行してください。';

  @override
  String get appCenterCleanupPermissionDenied =>
      'アクセス権限がありません。データにアクセスできるアカウントまたは sudo を使用してください。';

  @override
  String get appCenterCleanupCriticalPath =>
      'サーバーのルート、実行用・管理用ディレクトリはアプリのアンインストールでは削除できません。';

  @override
  String appCenterUninstallTypeAppNameHint(String appName) {
    return '完全削除を確認するには、正確なアプリ名を入力してください：$appName';
  }

  @override
  String get appCenterUninstallRiskLegacy => '排他的所有権が未確認';

  @override
  String get appCenterUninstallRiskExternal => 'アプリデータルート外のパス';

  @override
  String get appCenterUninstallRiskMedia => 'メディアまたは読み取り専用パス';

  @override
  String get appCenterUninstallTargetBlocked => '保護されたディレクトリのため削除できません';

  @override
  String get appCenterCleanupProtected =>
      '保護されているか削除が安全でないため、データディレクトリは保持されました';

  @override
  String get appCenterCleanupUnavailable =>
      'クリーンアップの確認を利用できません。データを保持したまま通常アンインストールは可能です。';

  @override
  String get appCenterCleanupChanged =>
      'ディレクトリまたはデプロイ対象が変更されました。再確認してもう一度確定してください。';

  @override
  String get appCenterCleanupConfirmationRequired =>
      '選択したディレクトリ、リスク、正確なアプリ名をもう一度確認してください';

  @override
  String get appCenterCleanupRetryUnavailable =>
      '安全なクリーンアップの再試行は利用できません。タスクの詳細を確認してください。';

  @override
  String get appCenterCleanupAlreadyAbsent => 'ディレクトリは既に存在しません。削除は不要です。';

  @override
  String get appCenterCleanupDeleteFailed =>
      '削除が不完全です。一部のファイルは既に削除された可能性があります。残りのパスを確認してください。';

  @override
  String get appCenterCleanupUnconfirmed =>
      'クリーンアップの結果または安全性を確認できませんでした。続行する前にタスクを確認し再検査してください。';

  @override
  String appCenterCleanupRetryTitle(String appName) {
    return '$appName の残りのデータクリーンアップを再試行しますか？';
  }

  @override
  String get appCenterCleanupRetryDescription =>
      'アプリケーションは既にアンインストールされています。未完了のデータディレクトリのみを選択してください。再試行しても再度アンインストールされることはありません。';

  @override
  String get appCenterCleanupRetrySelected => '選択した残りのデータを削除';

  @override
  String get appCenterCleanupResultsTitle => 'ディレクトリのクリーンアップ結果';

  @override
  String get appCenterCleanupPartialSummary =>
      'アプリケーションはアンインストールされましたが、一部のデータが完全には消去されませんでした。';

  @override
  String get appCenterCleanupPending => '完了が未確認';

  @override
  String get appCenterCleanupRemoved => '削除済み';

  @override
  String get appCenterCleanupRetained => '保持済み';

  @override
  String get appCenterCleanupRetryAction => '残りのデータクリーンアップを再試行';

  @override
  String get appCenterJellyfinSoftwareTitle => 'ソフトウェアデコードモード';

  @override
  String get appCenterJellyfinSoftwareDesc =>
      'GPUトランスコードを無効化し、確認済みのGPUデバイスマッピングを削除して、/Mediaを読み取り専用でマウントします。';

  @override
  String get appCenterJellyfinProfileUnavailable =>
      'このテンプレートではソフトウェアデコードプロファイルを利用できません';

  @override
  String get appCenterJellyfinSoftwareChanges => '適用されたプロファイルの変更:';

  @override
  String get nasNativeInstallTitle => 'Jellyfin をインストール（ネイティブパッケージ）';

  @override
  String get nasNativeStepVerifyRepo => '署名付き公式リポジトリを検証';

  @override
  String get nasNativeStepPreventAutostart => '設定前のサービス自動起動を防止';

  @override
  String get nasNativeStepInstallPackages => 'バージョンを固定した署名付きパッケージをインストール';

  @override
  String get nasNativeStepConfigureLoopback => 'localhost のみで待ち受けるように設定';

  @override
  String get nasNativeStageInstalling => '固定バージョンのパッケージをインストール中';

  @override
  String get nasNativeStageStarting => 'systemd サービスを起動中';

  @override
  String get nasNativeGuidanceMediaAccess =>
      'メディアファイルの権限と所有者は変更しません。Jellyfin のサービスユーザーに読み取り権限があることを確認してください。';

  @override
  String get nasNativeGuidanceNoUpgrade =>
      '既存の Jellyfin 環境の管理引き継ぎ、変更、アップグレードは行いません。';

  @override
  String get nasNativeSupportedRequirements =>
      'Debian または Ubuntu（amd64/arm64）、systemd、および root またはパスワード不要の sudo 権限が必要です。';

  @override
  String get nasNativeExistingInstallTitle => '既存の Jellyfin が見つかりました';

  @override
  String get nasNativeExistingInstallExplanation =>
      'このサーバーには Jellyfin が既にインストールされています。Valhalla は変更や再インストールを行いません。直接接続を確認してください。';

  @override
  String get nasNativeCancelExplanation =>
      '安全なチェックポイントでのキャンセルを要求しました。進行中のパッケージ操作は安全に完了します。';

  @override
  String get nasNativeMediaPathLabel => 'メディアディレクトリのパス';

  @override
  String get nasNativeMediaPathHint =>
      'サーバー上に存在する絶対パス（例：/media/library）。権限は変更しません。';

  @override
  String get nasNativeSudoRequired =>
      'システムパッケージのインストールには root またはパスワード不要の sudo 権限が必要です';

  @override
  String appCenterLogsTitle(String appName) {
    return '$appName のログ';
  }

  @override
  String get appCenterLogsEmpty => 'このデプロイのログは記録されていません';

  @override
  String get appCenterLogsCopied => 'ログをクリップボードにコピーしました';

  @override
  String get appCenterTaskStageQueued => '待機中';

  @override
  String get appCenterTaskStagePreparing => '準備中';

  @override
  String get appCenterTaskStagePulling => 'イメージを取得中';

  @override
  String get appCenterTaskStageApplying => '設定を適用中';

  @override
  String get appCenterTaskStageChecking => '状態を確認中';

  @override
  String get appCenterTaskStageSucceeded => '成功';

  @override
  String get appCenterTaskStageFailed => '失敗';

  @override
  String get appCenterTaskStageCancelled => 'キャンセル済み';

  @override
  String get appCenterTaskStageNeedsInspection => '手動確認が必要';

  @override
  String get appCenterCancelTask => 'タスクをキャンセル';

  @override
  String get appCenterCopyLog => 'ログをコピー';

  @override
  String get appCenterErrorNotConnected => 'サーバーが接続されていません';

  @override
  String get appCenterErrorEnvironmentRequired => 'Docker 環境の確認が必要です';

  @override
  String get appCenterErrorPlanExpired => 'デプロイプランの有効期限が切れているか無効です';

  @override
  String get appCenterErrorTargetChanged => '接続先サーバーが変更されたため、操作を中止しました';

  @override
  String get appCenterErrorConfigInvalid => '無効なアプリ設定です';

  @override
  String appCenterErrorPathInvalid(String field) {
    return '$fieldはルート（/）以外の絶対パスである必要があり、. または .. セグメントを含めることはできません';
  }

  @override
  String get appCenterErrorSourceInvalid => '無効なアプリストアソースです';

  @override
  String get appCenterErrorNoWebEntry => 'このアプリには Web インターフェースがありません';

  @override
  String get appCenterErrorHttpsDirectRequired =>
      'HTTPS エンドポイントは SSH トンネル経由で開けません。直接開いてください';

  @override
  String get appCenterErrorOpenFailed => 'アプリ URL を開けませんでした';

  @override
  String appCenterErrorGeneric(String error) {
    return 'アプリセンターエラー：$error';
  }

  @override
  String get appCenterSourceCommunityHint => '例: コミュニティストア';

  @override
  String get appCenterSourceUrlInvalidHttps => '有効な HTTPS URL を入力してください';

  @override
  String get appCenterDirectUrlLabel => '直接 URL';

  @override
  String get appCenterErrorSourceRemoved =>
      'アプリソースがカタログから削除されたため、テンプレートを更新できません。';

  @override
  String appCenterRestoreConfirmTitle(String appName) {
    return '$appName を復元しますか？';
  }

  @override
  String appCenterRestoreConfirmMessage(String appName) {
    return '$appName を以前のデプロイ構成に復元しますか？';
  }

  @override
  String appCenterHostPortLabel(String target) {
    return 'ホストポート (-> $target)';
  }

  @override
  String appCenterHostMountLabel(String target) {
    return 'ホスト: $target';
  }

  @override
  String get appCenterVersionLatest => '最新';

  @override
  String get appCenterWaitingForLogs => 'タスクログを待機中...';

  @override
  String get appCenterNoPreviewAvailable => 'プレビューがありません';

  @override
  String get appCenterBlockerLocalDockerRequired =>
      'ローカル Docker デーモンが必要です（リモート DOCKER_HOST は非対応）';

  @override
  String get appCenterBlockerToolsRequired =>
      'サーバーに必要なツールが不足しています (bash, setsid, flock, base64, realpath, ss, awk)';

  @override
  String get appCenterBlockerLinuxRequired => 'Linux オペレーティングシステムが必要です';

  @override
  String appCenterBlockerTemplateUnsupported(String feature) {
    return 'サポートされていないテンプレート機能: $feature';
  }

  @override
  String get appCenterFieldRequired => 'この項目は必須です';

  @override
  String get appCenterContinueInstall => 'インストールを続行';

  @override
  String get appCenterOperation => '操作';

  @override
  String get nasTabLibrary => 'ライブラリ';

  @override
  String get nasContinueWatching => '続きを見る';

  @override
  String get nasRecentPhotos => '最近の写真';

  @override
  String get nasRecentVideos => '最近の動画';

  @override
  String get nasRecentMusic => '最近の音楽';

  @override
  String get nasDownloadPaused => '一時停止中';

  @override
  String get nasDownloadDeleteConfirmTitle => 'オフラインファイルの削除';

  @override
  String get nasDownloadDeleteConfirmMessage =>
      '端末にダウンロードされたローカルのオフラインファイルを削除します。リモートサーバーの元ファイルは削除されません。';

  @override
  String get nasDownloadDeleteConfirmButton => 'オフラインコピーを削除';

  @override
  String get nasDownloadSourceChangedMessage =>
      'ダウンロード開始後にリモートソースの設定が変更されました。最初から再ダウンロードしますか？';

  @override
  String get nasDownloadRestartFromScratch => '最初から再開';

  @override
  String get nasDownloadErrorSourceChanged => 'ソース設定が変更されました';

  @override
  String get nasDownloadErrorOfflineFileInvalid => 'ダウンロードされたファイルが破損しているか不完全です';

  @override
  String get nasDownloadErrorStorageFailed => 'ストレージへの保存に失敗しました';

  @override
  String get nasDownloadErrorHlsUnsupported => 'ストリーミング配信のオフライン保存には非対応です';

  @override
  String get nasDownloadErrorPathInvalid => 'ダウンロード保存先パスが無効です';

  @override
  String get nasOpenInApp => 'アプリ内で開く';

  @override
  String get nasOpenSystem => 'システムで開く';

  @override
  String get sftpRecentDirectories => '最近使ったディレクトリ';

  @override
  String get sftpNoRecentDirectories => '最近使ったディレクトリはありません';

  @override
  String get sftpRetryFailed => '失敗項目を再試行';

  @override
  String get appCenterDiskCheckFailed => 'サーバー上の空きディスク容量を確認できませんでした';

  @override
  String get appCenterDiskFull => 'サーバーのディスク容量が一杯です。操作を続行できません';

  @override
  String get appCenterHealthInvalid => 'コンテナのヘルスチェックに失敗したか、無効な状態が報告されました';

  @override
  String get appCenterPreflightSummary => '事前チェック概要';

  @override
  String get appCenterMeasuredAvailableSpace => '計測された空き容量';

  @override
  String get appCenterUpdateComparison => 'アップデート比較';

  @override
  String get appCenterNoChangesDetected => '構造上の変更は検出されませんでした';

  @override
  String get appCenterSectionImage => 'コンテナイメージ';

  @override
  String get appCenterSectionPorts => 'ポートマッピング';

  @override
  String get appCenterSectionVolumes => 'ストレージマウント';

  @override
  String get appCenterSectionEnvironment => '環境変数';

  @override
  String get appCenterSectionHealthcheck => 'ヘルスチェック';

  @override
  String get appCenterSectionRestart => '再起動ポリシー';

  @override
  String get appCenterSectionServices => 'サービス一覧';

  @override
  String get appCenterHealthNoCheck => 'ヘルスチェックなし';

  @override
  String get appCenterHealthHealthy => '正常';

  @override
  String get appCenterHealthUnhealthy => '異常';

  @override
  String get appCenterHealthStarting => '起動中';

  @override
  String get appCenterNoSources => '有効なアプリソースがありません';

  @override
  String get appCenterNoMatchingApps => '検索またはフィルタ条件に一致するアプリがありません';

  @override
  String get appCenterClearFilters => 'フィルターをクリア';

  @override
  String get appCenterSourceLoadFailed => 'アプリソースの読み込みに失敗しました';

  @override
  String get appCenterRetry => '再試行';

  @override
  String get appCenterRecheck => '再チェック';

  @override
  String get appCenterRecheckTask => 'タスク状態を再確認';

  @override
  String get appCenterTaskNeedsInspectionTitle => 'タスク結果が未確認です';

  @override
  String get appCenterTaskNeedsInspectionMessage =>
      'サーバーでのタスク結果が不明です。むやみに再実行せず、状態を再確認するかログを確認してください。';

  @override
  String appCenterStopConfirmTitle(String appName) {
    return '$appName を停止しますか？';
  }

  @override
  String appCenterStopConfirmMessage(String appName, String serverName) {
    return 'サーバー $serverName 上の $appName を停止してもよろしいですか？実行中のコンテナが停止します。';
  }

  @override
  String appCenterRestartConfirmTitle(String appName) {
    return '$appName を再起動しますか？';
  }

  @override
  String appCenterRestartConfirmMessage(String appName, String serverName) {
    return 'サーバー $serverName 上の $appName を再起動してもよろしいですか？';
  }

  @override
  String get appCenterBrowseStore => 'アプリストアを見る';

  @override
  String get appCenterViewTasks => 'タスクを表示';

  @override
  String get appCenterViewInstalled => 'インストール済みアプリを表示';

  @override
  String get appCenterRunInBackground => 'バックグラウンドで実行';

  @override
  String get appCenterTaskDetails => 'タスク詳細';

  @override
  String get appCenterTaskTarget => '対象';

  @override
  String get appCenterTaskDirectory => 'ディレクトリ';

  @override
  String get appCenterTaskCreatedAt => '作成日時';

  @override
  String appCenterTaskExitCode(int code) {
    return '終了コード: $code';
  }

  @override
  String get appCenterStatusRunning => '実行中';

  @override
  String get appCenterStatusStopped => '停止中';

  @override
  String get appCenterStatusInstalling => 'インストール中';

  @override
  String get appCenterStatusUnknown => '不明';

  @override
  String get appCenterEnvReady => 'Docker & Compose 環境は準備完了です';

  @override
  String get appCenterEnvNotReady => 'Docker 環境の準備ができていません';

  @override
  String get appCenterEnvInspecting => 'Docker 環境を検出中...';

  @override
  String get appCenterUninstallWholeDataRoot => 'データルート全体';

  @override
  String get appCenterUninstallWholeDataRootWarning =>
      'アプリケーションデータルート配下に保存されているマウントされていないファイルやサブディレクトリも含まれます。';

  @override
  String get appCenterUninstallCoveredByParent => '親ディレクトリに含まれています';

  @override
  String get appCenterContainerNameInvalid =>
      'インスタンス名は英数字で始まり、英数字、アンダースコア、ピリオド、ハイフンのみを使用できます（最大120文字）。';

  @override
  String get appCenterMainService => 'メインサービス';

  @override
  String get appCenterContainerNamesPreview => 'コンテナ名プレビュー';

  @override
  String get appCenterContainersRecreationNotice =>
      'インスタンスコンテナ名を変更すると、既存のアプリケーションコンテナが再作成されます。';

  @override
  String get remoteBrowserTitle => 'リモートファイルブラウザ';

  @override
  String get remoteBrowserSelectDirectory => 'ディレクトリを選択';

  @override
  String get remoteBrowserSelectCurrentDirectory => '現在のディレクトリを選択';

  @override
  String get remoteBrowserSearchHint => 'ファイルとフォルダを検索...';

  @override
  String get remoteBrowserNoEntries => '一致するファイルまたはディレクトリが見つかりません';

  @override
  String get remoteBrowserEmptyDirectory => 'このディレクトリは空です';

  @override
  String remoteBrowserSelectedCount(int count) {
    return '$count 件選択中';
  }

  @override
  String get remoteBrowserParentDirectory => '親ディレクトリ';

  @override
  String get remoteBrowserLibrariesTitle => 'メディアライブラリ';

  @override
  String get remoteBrowserDisconnected => 'リモート接続が切断されたか利用できません。';

  @override
  String get remoteBrowserTargetChanged => 'ターゲット環境またはアクティブなサーバーが変更されました。';

  @override
  String get remoteBrowserPathInvalid => '要求されたパスが無効であるかアクセスできません。';

  @override
  String get remoteBrowserPathOutsideRoot => '要求されたパスは許可されたルートディレクトリの外にあります。';

  @override
  String get remoteBrowserPathDisplayMode => 'パス表示モード';

  @override
  String get remoteBrowserPathDisplayModeScroll => '横スクロール';

  @override
  String get remoteBrowserPathDisplayModeCollapsed => 'パスを折りたたむ';

  @override
  String get remoteBrowserEntryUnavailable => '選択されたエントリは利用できないか無効です。';

  @override
  String get nasBrowseUnavailable => 'NAS ブラウズサービスは現在利用できません。';

  @override
  String get nasInvalidDirectoryEntry => 'NAS の参照中に無効なディレクトリエントリが見つかりました。';

  @override
  String get nasInvalidLibraryResponse => 'メディアライブラリの応答が無効または不正です。';

  @override
  String get nasScanFilterUnresolved => 'スキャンフィルタパスを解決できません。';

  @override
  String get nasSourceSaveIncomplete =>
      '以前のソース保存が一部しか永続化されていません。資格情報を再入力して正常に保存してから参照してください。';

  @override
  String get terminalHistoryTitle => 'セッション履歴';

  @override
  String get terminalHistoryButton => 'セッション履歴';

  @override
  String get terminalHistoryEmpty =>
      'セッション履歴がありません。永続セッションにはリモートサーバーでの tmux が必要です。';

  @override
  String get terminalHistoryRefresh => '履歴を更新';

  @override
  String get terminalStartupSession => '起動セッション';

  @override
  String get terminalStartupSessionSubtitle => 'ターミナル起動時に開くセッションを選択';

  @override
  String get terminalStartupSessionFresh => '新規セッション（デフォルト）';

  @override
  String get terminalStatusOpen => 'オープン中';

  @override
  String get terminalStatusAvailable => '利用可能';

  @override
  String get terminalStatusEnded => '終了済み';

  @override
  String get terminalStatusOffline => 'オフライン';

  @override
  String get terminalDefaultBadge => 'デフォルト';

  @override
  String get terminalLegacyBadge => '未インポート';

  @override
  String get terminalRestoreSession => 'セッションを復元';

  @override
  String get terminalSetDefault => 'デフォルトに設定';

  @override
  String get terminalClearDefault => 'デフォルトを解除';

  @override
  String get terminalRename => 'セッション名を変更';

  @override
  String get terminalRenameDialogTitle => 'セッション名を変更';

  @override
  String get terminalRenameInputLabel => 'セッション名';

  @override
  String get terminalTitleInvalid => 'タイトルは制御文字を除く1〜64文字である必要があります';

  @override
  String get terminalErrorHistoryLoadFailed => 'ターミナル履歴の読み込みに失敗しました';

  @override
  String get terminalErrorHistorySaveFailed => 'ターミナル履歴の保存に失敗しました';

  @override
  String get terminalErrorHistoryRefreshFailed => 'ターミナル履歴の更新に失敗しました';

  @override
  String get terminalErrorStartFailed => 'ターミナルセッションの開始に失敗しました';

  @override
  String get terminalErrorRestoreFailed => 'ターミナルセッションの復元に失敗しました';

  @override
  String get terminalErrorDefaultSaveFailed => 'デフォルト起動セッションの保存に失敗しました';

  @override
  String get terminalErrorCommandFailed => 'ターミナルコマンドの実行に失敗しました';

  @override
  String get terminalErrorTitleInvalid => '無効なセッションタイトル（1〜64文字が必要）';

  @override
  String get terminalErrorSshDisconnected => 'SSH 接続が切断されました';

  @override
  String get terminalNoticeDefaultMissing =>
      'デフォルト起動セッションが見つからないか終了していたため、新しいターミナルを開きました';

  @override
  String get terminalNoticeSessionMissing => '要求された tmux セッションはリモートサーバーに存在しません';

  @override
  String get terminalNoticePlainInterrupted =>
      '接続が切断されました。非 tmux シェルプロセスは再開できませんでした';

  @override
  String get terminalHistoryDeleteDialogTitle => 'セッション履歴の削除';

  @override
  String get terminalHistoryTerminateRemote => 'リモートサーバーのセッションも終了する';

  @override
  String get terminalHistoryTerminateConfirmTitle => 'リモートセッションを終了しますか？';

  @override
  String get terminalHistoryTerminateConfirmMessage =>
      'この操作によりリモートの tmux セッションが終了し、実行中のすべてのプロセスが停止します。';

  @override
  String get terminalErrorHistoryDeleteFailed => 'ターミナル履歴の削除に失敗しました';

  @override
  String get terminalErrorHistoryTerminateFailed => 'リモートセッションの終了に失敗しました';

  @override
  String get terminalErrorTargetChanged =>
      '対象サーバーが変更されました。現在のサーバーでセッションを再度開いてください。';

  @override
  String get terminalModeStandard => '標準SSHターミナル（デフォルト、履歴なし）';

  @override
  String get terminalModeTmux => 'tmuxターミナル（リモートセッションと履歴を保持）';

  @override
  String get terminalModeSaveFailed => 'ターミナルモードの保存に失敗しました。再試行してください';

  @override
  String get sftpNew => '新規';

  @override
  String get terminalHistorySearchHint => 'セッション名を検索…';

  @override
  String get configMigrationBoundaryNote => 'ローカル設定のみを対象とし、リモートサーバーデータは変更しません。';

  @override
  String get configMigrationSubtitle => 'アプリ設定とサーバープロファイルをエクスポート/インポート';

  @override
  String get installAppId => 'アプリケーションID';

  @override
  String get installArchitecture => 'アーキテクチャ';

  @override
  String get installPlatform => 'プラットフォーム';

  @override
  String get settingsAboutPrivacyDesc => 'バージョン、オープンソースライセンス、プライバシーポリシー';

  @override
  String get settingsAccentColorDesc => 'テーマのアクセントカラーをカスタマイズ';

  @override
  String get settingsSearchHint => '設定を検索…';

  @override
  String get settingsSearchNoResults => '一致する設定が見つかりません';

  @override
  String get settingsSecurityDesc => '信頼済みホスト、資格情報、セキュリティアクション';

  @override
  String get agentExpandDetails => '詳細';

  @override
  String get agentCollapseDetails => '折りたたむ';

  @override
  String get transferPauseAll => 'すべて一時停止';

  @override
  String get transferResumePaused => '一時停止中を再開';

  @override
  String get transferFilterAll => 'すべて';

  @override
  String get transferFilterActive => '実行中';

  @override
  String get transferFilterFailed => '失敗';

  @override
  String get transferFilterCompleted => '完了';

  @override
  String get transferPauseReasonUser => 'ユーザーにより一時停止';

  @override
  String get transferPauseReasonNetwork => 'ネットワーク切断により一時停止';

  @override
  String get transferPauseReasonAppRestart => 'アプリ再起動後に一時停止';

  @override
  String get transferRemotePath => 'リモートパス';

  @override
  String get transferLocalPath => 'ローカルパス';

  @override
  String get transferErrorDetail => 'エラー詳細';

  @override
  String get chatFailureKindAuth => '認証が必要です';

  @override
  String get chatFailureKindModelUnavailable => 'モデルが利用できません';

  @override
  String get chatFailureKindConnection => '接続エラー';

  @override
  String get chatFailureKindHistory => '履歴読み込みエラー';

  @override
  String get chatFailureKindOther => 'リクエスト失敗';

  @override
  String get chatFailureActionLogin => 'ログイン';

  @override
  String get chatFailureActionRunSettings => 'モデル設定';

  @override
  String get chatFailureActionReconnect => '再接続';

  @override
  String get chatFailureActionReloadHistory => '再試行';

  @override
  String get chatFailureActionDetails => '詳細';

  @override
  String get sftpConfigureToolbar => 'ツールバーをカスタマイズ';

  @override
  String get sftpConfigureToolbarDesc =>
      'ツールバーに直接固定するアクションを選択します。その他のアクションは「その他」メニューに表示されます。';

  @override
  String get sftpToolbarPreferenceSaveFailed => 'ツールバー設定の保存に失敗しました';

  @override
  String get sftpToolbarActionView => '表示切り替え';

  @override
  String agentUpdateNotice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件のエージェントのアップデートが利用可能です',
    );
    return '$_temp0';
  }

  @override
  String get agentUpdateViewAction => '確認';

  @override
  String get agentUpdateCheckAll => '更新を確認';

  @override
  String get agentUpdateCheck => '更新を確認';

  @override
  String get agentUpdateChecking => '確認中...';

  @override
  String get agentUpdateAvailable => '更新可能';

  @override
  String get agentUpdateUpToDate => '最新の状態';

  @override
  String get agentUpdateDialogTitle => 'エージェントの更新';

  @override
  String get agentUpdateConfirmButton => '確認して更新';

  @override
  String get agentUpdateCancelButton => 'キャンセル';

  @override
  String get agentUpdateTargetServer => 'サーバー';

  @override
  String get agentUpdateTargetEnvironment => '実行環境';

  @override
  String get agentUpdateTargetIdentity => '対象の識別情報';

  @override
  String get agentUpdateCommandPreview => 'コマンドプレビュー';

  @override
  String get agentUpdateClaudeMigrationNotice =>
      'この更新により、レガシーな Claude アダプター (claude-code-acp) が公式の claude-agent-acp アダプターに移行されます。既存の履歴と認証情報は保持されます。';

  @override
  String get agentUpdateAgyNotice =>
      'AgY CLI は公式の安定版リリースチャンネル経由で更新されます。確認時に表示されたスナップショットより新しいバージョンがインストールされる場合があります。';

  @override
  String get agentUpdateLogs => '更新ログ';

  @override
  String get agentUpdateCopyLog => 'ログをコピー';

  @override
  String get agentUpdateLogCopied => '更新ログをクリップボードにコピーしました';

  @override
  String get agentUpdateSuccess => 'エージェントが正常に更新されました';

  @override
  String get agentUpdateFailed => '更新に失敗しました';

  @override
  String get agentUpdateInterrupted =>
      '更新が中断されたか接続が切断されました。安全のため自動再試行は無効になっています。再試行する前に実際のバージョンをご確認ください。';

  @override
  String get agentUpdateInProgress => 'このサーバーでアップデートが進行中です。';

  @override
  String get agentUpdateBusy => 'サーバーまたはエージェントがビジー状態です。現在の処理が完了するまでお待ちください。';

  @override
  String get agentUpdateVersionUnknown => '不明';

  @override
  String get agentUpdateSource => 'ソース';

  @override
  String get agentUpdateLastChecked => '最終確認';

  @override
  String get agentUpdateNeverChecked => '未確認';

  @override
  String get agentUpdateCodexMigrationTitle => '新しいアダプターをインストールしてこのAgentに切り替え';

  @override
  String get agentUpdateCodexMigrationNotice =>
      '既存のプログラムと設定は保持され、独立した新版アダプターをインストールした後に接続を切り替えます。問題発生時は安全にロールバックできます。';

  @override
  String get agentUpdateReplacementCommand => '切り替え後のコマンド';

  @override
  String get terminalGridEditLayout => 'ショートカットの配置を編集';

  @override
  String get terminalGridSave => '保存';

  @override
  String get terminalGridCancel => 'キャンセル';

  @override
  String get terminalGridUndo => '元に戻す';

  @override
  String get terminalGridDiscardConfirm => '未保存の変更は破棄されます。よろしいですか？';

  @override
  String get terminalGridSaveFailed => '配置の保存に失敗しました';

  @override
  String get terminalGridCorruptedPrompt => 'ショートカットバー設定が破損しています。デフォルトに戻しますか？';

  @override
  String get terminalGridCorruptedReset => 'リセット';

  @override
  String get terminalGridAddTab => '追加';

  @override
  String get terminalGridKeyTab => 'キー';

  @override
  String get terminalGridSetTab => '設定';

  @override
  String get terminalGridCurrentPage => '現在のページ';

  @override
  String get terminalGridAddPage => '＋ ページ追加';

  @override
  String get terminalGridDeletePage => 'ページ削除';

  @override
  String terminalGridDeletePageConfirm(int page) {
    return 'ページ $page とそのすべてのキーを削除しますか？';
  }

  @override
  String get terminalGridDeleteKey => 'このキーを削除';

  @override
  String get terminalGridRows => 'キーボード表示行数';

  @override
  String get terminalGridRowsSubtitle => '1〜5行（デフォルト2行）';

  @override
  String get terminalGridInvertedT => '逆T字カーソルキー固定';

  @override
  String get terminalGridInvertedTSubtitle => 'オフにすると4つの独立キーに分離';

  @override
  String get terminalGridSplitArrows => '独立キーに分離';

  @override
  String get terminalGridDeleteArrows => 'カーソルキーグループを削除';

  @override
  String get terminalGridReset => 'デフォルト配置に戻す';

  @override
  String get terminalGridResetConfirm => 'デフォルトのショートカット配置にリセットしますか？';

  @override
  String get terminalGridNoSpace =>
      '現在のページに空きがありません。ページ追加、行数変更、またはキー削除を行ってください';

  @override
  String get terminalGridArrowsNeedTwoRows => '逆T字キーには2行以上必要です。設定でキーを分離してください';

  @override
  String get terminalGridArrowsNeedSpace => '逆T字キーには3×2の空きスペースが必要です';

  @override
  String get terminalGridKeepAtLeastOnePage => '最低1ページは必要です';

  @override
  String terminalGridPageSpaceInsufficient(int page) {
    return 'ページ $page に十分な空きがありません。キーを移動または削除してください';
  }

  @override
  String get terminalGridMetaNotSupported => '端末プロトコルがMetaキーに対応していません';

  @override
  String get terminalGridSelectKeyHint => 'キーをタップしてプロパティ編集\n長押しドラッグで位置調整';

  @override
  String get terminalGridDisplayName => '表示名';

  @override
  String get terminalGridActionSend => '送信';

  @override
  String get terminalGridWidth => '幅（マス）';

  @override
  String get terminalGridCustomCombo => 'カスタムコンボキー';

  @override
  String get terminalGridCustomComboHint => '修飾キーを選択 + キーを入力';

  @override
  String get terminalGridKeyHint => 'キー名（例: C, F5, Tab）';

  @override
  String get terminalGridDisplayNameOptional => '表示名（任意）';

  @override
  String get terminalGridPleaseEnterKey => 'キーを入力してください';

  @override
  String get terminalGridTextMacro => 'テキストマクロ';

  @override
  String get terminalGridTextMacroSubtitle => 'タップで定型テキストを一括送信';

  @override
  String get terminalGridMacroTextHint => '例: ls -la';

  @override
  String get terminalGridMacroAppendEnter => '改行';

  @override
  String get terminalGridPleaseEnterText => 'テキストを入力してください';

  @override
  String get terminalGridSingleKey => '単一キー';

  @override
  String get terminalGridComboKey => 'コンボキー';

  @override
  String get terminalGridMacroKey => 'マクロ';

  @override
  String get terminalCategoryCommon => '常用';

  @override
  String get terminalCategoryNav => 'ナビゲーション';

  @override
  String get terminalCategoryEdit => '編集';

  @override
  String get terminalCategorySym => '記号';

  @override
  String get terminalCategoryModifiers => '修飾キー';

  @override
  String get terminalCategoryCustom => 'カスタム';

  @override
  String get terminalSearchPresets => 'プリセットキーを検索...';

  @override
  String get terminalGridActionEdit => '送信動作を編集';

  @override
  String get terminalGridActionKey => '送信キー';

  @override
  String get terminalGridActionModifiers => '修飾キー';

  @override
  String get terminalGridActionText => '送信テキスト';

  @override
  String get terminalSearchNoMatch => '一致するキーはありません';

  @override
  String get terminalStatusEndedUnrecoverable => '終了済み・復元不可';

  @override
  String get terminalStatusUnavailable => 'ソース未設定';

  @override
  String get terminalGroupUnconfirmed => '未確認';

  @override
  String get terminalGroupUnavailable => 'ソース未設定';

  @override
  String get terminalExternalBadge => '外部';

  @override
  String terminalAttachedClients(int count) {
    return 'クライアント: $count';
  }

  @override
  String get terminalHideSession => '履歴から非表示';

  @override
  String get terminalUnhideSession => '再表示';

  @override
  String get terminalHiddenSessionsTitle => '非表示のセッション';

  @override
  String get terminalNoHiddenSessions => '非表示のセッションはありません';

  @override
  String get terminalSocketSources => 'ソケットソース管理';

  @override
  String get terminalSourceBuiltin => '内蔵';

  @override
  String get terminalSourceCustom => 'カスタム';

  @override
  String get terminalAddSocketSource => 'ソケットソースを追加';

  @override
  String get terminalSocketKindNamed => '名前付きソケット (-L)';

  @override
  String get terminalSocketKindPath => 'パスソケット (-S)';

  @override
  String get terminalSocketInputHint => 'ソケット名または絶対パス';

  @override
  String get terminalSocketInvalid =>
      '無効なソケット形式です。名前付きは1〜64文字の英数字、パスは/で始まり\'..\'を含まない必要があります';

  @override
  String get terminalSocketExists => 'このソケットソースは既に追加されています。';

  @override
  String terminalTerminateClientsWarning(int count) {
    return '警告: 現在 $count 台のクライアントが接続しています。終了するとすべて切断されます。';
  }

  @override
  String get terminalTerminateSession => 'セッション終了';

  @override
  String get terminalSocketLabel => 'ソケット';

  @override
  String get terminalServerLabel => 'サーバー';

  @override
  String terminalSocketErrorsBanner(int count) {
    return '$count 個のソケットソースエラー';
  }

  @override
  String get persistentRuntimeDialogTitle => '永続 Agent ランタイム';

  @override
  String get persistentRuntimeDialogDescription =>
      'バックグラウンド実行を有効にして、アプリの終了や切断時でもサーバー上でタスクを継続します。';

  @override
  String get persistentRuntimeFeaturePythonTitle => 'ユーザー権限サービス';

  @override
  String get persistentRuntimeFeaturePythonDesc =>
      'root 権限不要で、ユーザーアカウントの標準 Python 3.9+ を使用して実行します。';

  @override
  String get persistentRuntimeFeatureSshTitle => 'SSH 経由のみ';

  @override
  String get persistentRuntimeFeatureSshDesc =>
      '外部ポートやサービスは公開されず、既存の SSH 経由で安全に通信します。';

  @override
  String get persistentRuntimeFeatureRetentionTitle => '出力の7日間保持';

  @override
  String get persistentRuntimeFeatureRetentionDesc =>
      'タスク完了後も、実行ログと出力がサーバー上に7日間安全に保持されます。';

  @override
  String get persistentRuntimeFeatureDetachedTitle => 'バックグラウンド継続実行';

  @override
  String get persistentRuntimeFeatureDetachedDesc =>
      'アプリを終了したり通信が途切れても、Agent はバックグラウンドで処理を継続します。';

  @override
  String get persistentRuntimeEnableAction => 'ランタイムを有効化';

  @override
  String get persistentRuntimeSettingUp => 'サーバー上でランタイムを設定中...';

  @override
  String get dismissRecoveryNoticeTooltip => '通知を閉じる';

  @override
  String get terminalReconnectTab => 'ターミナルを再接続';

  @override
  String get terminalCloseTabConfirmTitle => 'タブを閉じる';

  @override
  String get terminalClosePlainConfirmMessage =>
      'このタブを閉じると接続が切断されます。フォアグラウンドで実行中のプロセスは終了する可能性があります。';

  @override
  String get terminalCloseTmuxConfirmMessage =>
      'このターミナルは tmux で実行されています。タブを閉じても現在のビューからデタッチされるだけで、セッションとタスクはバックグラウンドで保持されます。';

  @override
  String get terminalCloseActionTerminate => '終了して閉じる';

  @override
  String get terminalCloseActionDetach => 'デタッチして閉じる';

  @override
  String acpRunningSessionIndicator(String agentName) {
    return 'タスク実行中: $agentName';
  }

  @override
  String get acpReturnToRunningSession => '実行中のセッションに戻る';

  @override
  String get acpServerBusySendDisabled => 'サーバーは現在他のタスクを実行中です。完了するまでお待ちください';

  @override
  String get deleteSessionLocalOnlyOption => 'ローカル記録のみ削除';

  @override
  String get deleteSessionStopAndPurgeOption => '実行を停止しリモートのランタイムデータを消去';

  @override
  String get deleteSessionPurgeRemoteWarning =>
      'リモートのバックグラウンドプロセスを停止し、アプリ専用のランタイムキャッシュを消去します。';

  @override
  String get permissionViewDetails => '詳細を表示';

  @override
  String get permissionDetailsTitle => '権限承認の詳細';

  @override
  String get permissionToolLabel => '要求されたツール';

  @override
  String get permissionCommandLabel => '実行コマンド';

  @override
  String get permissionCopyCommand => 'コマンドをコピー';

  @override
  String get permissionCommandCopied => 'コマンドをクリップボードにコピーしました';

  @override
  String get chatScrollToLatest => '最新へ移動';

  @override
  String get deleteSessionNoManagedRuntimes =>
      'このセッションには管理対象のランタイムインスタンスがありません。';

  @override
  String get deleteSessionAffectedRuntimes => '影響を受けるランタイムインスタンス:';

  @override
  String get deleteSessionInspectingRuntimes => 'リモートランタイムを確認中...';

  @override
  String get deleteSessionOfflineNotice => 'サーバーが未接続です。ローカル削除のみ利用可能です。';

  @override
  String get chatWorkbench => 'ワークベンチ';

  @override
  String get chatWorkbenchFiles => 'ファイル';

  @override
  String get chatWorkbenchTasks => 'タスクとツール';

  @override
  String get chatWorkbenchContext => 'コンテキスト';

  @override
  String get chatWorkspaceProjects => 'プロジェクト';

  @override
  String get chatWorkspaceEditAlias => 'プロジェクト別名を編集';

  @override
  String get chatWorkspaceAliasLabel => 'プロジェクト別名';

  @override
  String get chatWorkspaceFavorite => 'プロジェクトをお気に入りに追加';

  @override
  String get chatWorkspaceUnfavorite => 'プロジェクトのお気に入りを解除';

  @override
  String get chatLoopbackConfirmTitle => 'リモートローカルループバックURLを開く';

  @override
  String get chatLoopbackConfirmMessage =>
      'このリンクはリモートのlocalhostを指しています。ブラウザで開きますか？';

  @override
  String get chatConfirmSaveFile => '保存を確認';

  @override
  String get chatConfirmSaveFileMessage => 'このファイルへの変更を保存しますか？';

  @override
  String get chatFileReadOnly => '読み取り専用';

  @override
  String get chatCopyError => 'エラー詳細をコピー';

  @override
  String get chatFileOutsideWorkspace => 'ファイルがワークスペース外にあります。開きますか？';

  @override
  String get chatUnsavedChangesTitle => '未保存の変更';

  @override
  String get chatUnsavedChangesMessage => '未保存の変更があります。破棄しますか？';

  @override
  String get chatDiscard => '破棄';

  @override
  String get chatNoChangesToSave => '保存する変更はありません';

  @override
  String get chatFileSaved => 'ファイルを保存しました';

  @override
  String get chatLoadingFile => 'ファイルを読み込み中...';

  @override
  String get chatEditorUnavailable => 'コンテナエディタを利用できません（python3 が必要です）。';

  @override
  String get chatFileNotEditable => 'バイナリまたは大きなファイルは編集できません。';

  @override
  String get chatFailedToOpenLink => 'リンクを開けませんでした';

  @override
  String get chatNoActiveTasks => 'アクティブなタスクやツールの実行はありません';

  @override
  String get chatNoFilesInDirectory => 'ディレクトリ内にファイルはありません';

  @override
  String get chatViewCurrentRun => '現在の実行を表示';

  @override
  String get chatExecutionChangedPrompt =>
      'セッションの実行環境が変更されました。続行するには新しいセッションを作成してください。';

  @override
  String get chatLinkCopied => 'リンクをクリップボードにコピーしました';

  @override
  String get chatFileEditorEdit => '編集';

  @override
  String get chatFileEditorDiff => '差分';

  @override
  String terminalLastChecked(String time) {
    return '最終確認: $time';
  }

  @override
  String get terminalNotChecked => '未確認';

  @override
  String get terminalLastCheckedTitle => '最終確認';

  @override
  String chatExpandCode(String lines) {
    return 'コードを展開（$lines 行）';
  }

  @override
  String get chatCollapseCode => 'コードを折りたたむ';

  @override
  String get chatCodeReaderTitle => 'コードリーダー';

  @override
  String get chatCodeCopied => 'コードをクリップボードにコピーしました';

  @override
  String get acpAgentOfflineRunning => 'オフライン（バックグラウンドで実行中）';

  @override
  String get acpAgentOfflineTaskRunning =>
      'SSH 切断中。バックグラウンドの Agent タスクは実行中の可能性があります。';

  @override
  String get chatCloseBanner => '閉じる';

  @override
  String get chatSearchTitle => 'チャット履歴を検索';

  @override
  String get chatSearchHint => 'メッセージとツール出力を検索...';

  @override
  String get chatSearchScopeCurrent => '現在のセッション';

  @override
  String get chatSearchScopeAll => '現在のサーバー';

  @override
  String get chatSearchNoResults => '一致するメッセージは見つかりませんでした';

  @override
  String get chatSearchNoQuery => 'キーワードを入力して履歴を検索';

  @override
  String chatSearchResultsCount(String count) {
    return '$count 件の結果が見つかりました';
  }

  @override
  String get chatSearchReaderTitle => 'メッセージ前後のプレビュー';

  @override
  String get chatSearchGoToSession => '元のセッションを開く';

  @override
  String get chatSearchBackToResults => '検索結果に戻る';

  @override
  String get chatSearchSourceMessage => 'メッセージ';

  @override
  String get chatSearchSourceTool => 'ツール出力';

  @override
  String get chatSearchRemoteFileDisabled =>
      '検索プレビューからはリモートファイルを開けません。元のセッションを開いて表示してください。';

  @override
  String get chatSearchTargetChanged => '検索中にセッションまたはサーバーが変更されました';

  @override
  String get terminalSearch => 'ターミナル内を検索';

  @override
  String get terminalSearchHint => '検索...';

  @override
  String get terminalSearchPrev => '前の一致';

  @override
  String get terminalSearchNext => '次の一致';

  @override
  String get terminalSearchFollowLatest => '最新の位置に戻る';

  @override
  String terminalSearchCount(String current, String total) {
    return '$current / $total';
  }

  @override
  String terminalSearchCountOverflow(String current) {
    return '$current / 1000+';
  }

  @override
  String get terminalSearchNoMatches => '一致なし';

  @override
  String get chatRoleUser => 'ユーザー';

  @override
  String get chatRoleAssistant => 'アシスタント';

  @override
  String get chatRoleSystem => 'システム';

  @override
  String get chatCommandFilterAll => 'すべて';

  @override
  String get chatCommandFilterFavorites => 'お気に入り';

  @override
  String get chatCommandFilterRecent => '最近';

  @override
  String get chatCommandFavoriteAdd => 'お気に入りに追加';

  @override
  String get chatCommandFavoriteRemove => 'お気に入りから削除';

  @override
  String get chatCommandUnavailable => '現在のAgentでは利用できません';

  @override
  String get chatCommandPreferencesSaveFailed => 'コマンド設定の保存に失敗しました';

  @override
  String get chatResetDraftWorkingDir => '作業ディレクトリをデフォルトにリセット';

  @override
  String get terminalClearAllModifiers => 'すべての修飾キーをクリア';

  @override
  String get terminalSavedCommandsTitle => '保存されたコマンド';

  @override
  String get terminalSavedCommandsRun => 'コマンドを実行';

  @override
  String get terminalSavedCommandsEmpty => '保存されたコマンドはありません';

  @override
  String get terminalSavedCommandsPreview => 'コマンドプレビュー';

  @override
  String get terminalSavedCommandsMultilineWarning =>
      'このコマンドには複数行が含まれています。実行しますか？';

  @override
  String get terminalModifierHelp => '修飾キーをタップで1回有効、長押しでロック。キーを長押しでリピート入力。';

  @override
  String get serverWorkspaceTitle => 'サーバーワークスペース';

  @override
  String get serverWorkspaceSubtitle => 'マルチデバイスの状態同期とデバイス下書き';

  @override
  String get serverWorkspaceOriginServer => '対象サーバー';

  @override
  String get serverWorkspaceOriginUser => 'リモートユーザー';

  @override
  String get serverWorkspaceNoActiveServer => 'アクティブなサーバーが選択または接続されていません';

  @override
  String get serverWorkspacePhaseLocal => 'ローカルのみ';

  @override
  String get serverWorkspacePhaseDiscovering => '検出中...';

  @override
  String get serverWorkspacePhaseAvailable => '有効化可能';

  @override
  String get serverWorkspacePhaseSyncing => '同期中...';

  @override
  String get serverWorkspacePhaseReady => '同期済み';

  @override
  String get serverWorkspacePhaseOffline => 'オフライン';

  @override
  String get serverWorkspacePhaseError => '同期エラー';

  @override
  String serverWorkspaceLastSynced(String time) {
    return '最終同期：$time';
  }

  @override
  String get serverWorkspaceNeverSynced => '未同期';

  @override
  String serverWorkspacePendingChanges(int count) {
    return '$count 件の保留中の変更';
  }

  @override
  String get serverWorkspaceNoPendingChanges => 'すべて同期済み';

  @override
  String get serverWorkspaceEnable => 'サーバーワークスペースを有効化';

  @override
  String get serverWorkspaceEnableDialogTitle => 'サーバーワークスペースを有効化';

  @override
  String get serverWorkspaceEnableDialogMessage =>
      '有効にすると、ローカル設定がサーバーに移行されます。ローカルの設定は保持され、削除されません。';

  @override
  String get serverWorkspaceMigrationPreviewTitle => '移行プレビュー';

  @override
  String get serverWorkspaceEnableConfirm => '有効化して同期';

  @override
  String get serverWorkspaceNoDataToMigrate => '移行するローカルデータがありません';

  @override
  String get serverWorkspaceSyncNow => '今すぐ同期';

  @override
  String get serverWorkspaceDisable => '同期を無効化';

  @override
  String get serverWorkspaceDisableDialogTitle => 'サーバーワークスペースを無効化';

  @override
  String get serverWorkspaceDisableDialogMessage =>
      '無効にすると、このデバイスでの同期が停止します。リモートおよびローカルのデータは保持され、削除されません。';

  @override
  String get serverWorkspaceDisableConfirm => '無効化';

  @override
  String get serverWorkspacePreferenceSource => '設定の優先ソースとして使用';

  @override
  String get serverWorkspacePreferenceSourceDesc => 'このサーバーからアプリ全般の設定を同期します';

  @override
  String serverWorkspaceConflictsTitle(int count) {
    return '同期の競合 ($count)';
  }

  @override
  String get serverWorkspaceConflictKeepLocal => 'ローカルを維持';

  @override
  String get serverWorkspaceConflictKeepServer => 'サーバーを維持';

  @override
  String get serverWorkspaceDeviceDraftsTitle => '他デバイスの下書き';

  @override
  String get serverWorkspaceRestoreDraft => '下書きを復元';

  @override
  String get serverWorkspaceRestoreDraftConfirmTitle => 'デバイス下書きを復元';

  @override
  String get serverWorkspaceRestoreDraftConfirmMessage =>
      'この下書きを復元すると、現在のチャット入力下書きが置き換わります。現在の下書きはリモート下書きリストに保存されます。';

  @override
  String get serverWorkspaceRestoreDraftConfirm => '復元';

  @override
  String get serverWorkspaceNoDeviceDrafts => '他のデバイスの下書きはありません';

  @override
  String get serverWorkspaceClearCache => 'ローカル同期キャッシュを消去';

  @override
  String get serverWorkspaceClearCacheConfirmTitle => 'ローカル同期キャッシュを消去';

  @override
  String get serverWorkspaceClearCacheConfirmMessage =>
      'この操作はローカルの同期キャッシュと状態のみを消去します。リモートデータやSSH設定は削除されません。';

  @override
  String get serverWorkspaceClearCacheConfirm => 'キャッシュを消去';

  @override
  String get serverWorkspaceCacheCleared => 'ローカル同期キャッシュを消去しました';

  @override
  String get serverWorkspaceErrorSetupFailed => 'サーバー上のワークスペース初期化に失敗しました';

  @override
  String get serverWorkspaceErrorPythonRequired => 'サーバー上に Python 3.9 以上が必要です';

  @override
  String get serverWorkspaceErrorPathUnsafe => 'ワークスペースのパスが安全でないか、権限が無効です';

  @override
  String get serverWorkspaceErrorConflict => '同期中にデータ競合が検出されました';

  @override
  String get serverWorkspaceErrorControlHeld => 'セッションの制御権が別のデバイスに保持されています';

  @override
  String get serverWorkspaceErrorResponseTooLarge => 'サーバー応答がサイズ上限を超えました';

  @override
  String serverWorkspaceErrorGeneric(String code) {
    return 'ワークスペースエラー ($code)';
  }

  @override
  String get chatWorkspaceControlActive => '制御中';

  @override
  String get chatWorkspaceControlActiveTooltip => '現在このデバイスがセッションを制御しています';

  @override
  String get chatWorkspaceReadOnly => '読み取り専用';

  @override
  String chatWorkspaceReadOnlyDevice(String device) {
    return '読み取り専用 ($device)';
  }

  @override
  String get chatWorkspaceAcquireControl => '制御権を取得';

  @override
  String get chatWorkspaceTakeover => '引き継ぐ';

  @override
  String get chatWorkspaceTakeoverDialogTitle => 'セッション制御権の引き継ぎ';

  @override
  String get chatWorkspaceTakeoverDialogMessage =>
      '制御権を引き継ぐと、このデバイスからメッセージの送信や操作が可能になります。実行中のエージェントが終了したり、セッションが切り替わることはありません。';

  @override
  String get chatWorkspaceTakeoverConfirm => '引き継ぐ';

  @override
  String get chatWorkspaceControlFailed => 'ワークスペース制御権の取得に失敗しました';

  @override
  String get serverWorkspaceErrorRuntimeUpgradeRequired =>
      '以前のランタイムコンポーネントが実行中です。元のデバイスで完了または終了させてからアップグレードしてください。';

  @override
  String get serverWorkspaceErrorNotEnabled => 'サーバーワークスペースが有効化されていません';

  @override
  String get serverWorkspaceErrorPendingChanges =>
      '保留中の変更があるためキャッシュを消去できません。先に同期してください。';

  @override
  String get serverWorkspaceDraftTypeFile => 'ファイル下書き';

  @override
  String get serverWorkspaceDraftTypeChat => 'チャット下書き';

  @override
  String get serverWorkspaceRestoreFileDraftConfirmTitle => 'ファイル下書きを復元';

  @override
  String get serverWorkspaceRestoreFileDraftConfirmMessage =>
      'このファイル下書きを復元するとローカルエディタの下書きに読み込まれます。現在の下書きはリモートリストに保持されます。';

  @override
  String get persistentRuntimeFeatureWorkspaceTitle => 'サーバーワークスペースと状態同期';

  @override
  String get persistentRuntimeFeatureWorkspaceDesc =>
      'アプリ終了後もユーザー専用のランタイムが出力を保持します。SSH認証情報や鍵は端末内に保存され同期されません。';

  @override
  String get serverWorkspaceMigrationPendingHint =>
      'バックグラウンドでレガシーデータを移行中です。設定は同期済みで、履歴データはバックグラウンドで継続して完了します。';

  @override
  String get serverWorkspaceLoadMoreDrafts => 'さらに下書きを読み込む';

  @override
  String get serverWorkspaceLoadingDrafts => '下書きを読み込み中...';
}
