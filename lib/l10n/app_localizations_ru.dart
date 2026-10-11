// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'Valhalla';

  @override
  String get appSubtitle => 'AI-нативное управление серверами и агентами';

  @override
  String get navAiChat => 'AI чат';

  @override
  String get navTerminal => 'Терминал';

  @override
  String get navFiles => 'Файлы SFTP';

  @override
  String get navCommands => 'Команды';

  @override
  String get navSettings => 'Настройки';

  @override
  String get serverConnected => 'Подключено';

  @override
  String get serverOnline => 'В сети';

  @override
  String get serverOffline => 'Не в сети';

  @override
  String get latencyMs => 'мс';

  @override
  String get reconnect => 'Переподключить';

  @override
  String get disconnect => 'Отключить';

  @override
  String get quickDisconnect => 'Быстрое отключение';

  @override
  String get newSession => 'Новая сессия';

  @override
  String get historySessions => 'История сессий';

  @override
  String get switchAgent => 'Переключить агента';

  @override
  String get agentClaudeCode => 'Claude CodeX';

  @override
  String get agentCodex => 'OpenAI Codex';

  @override
  String get agentOpenCode => 'OpenCode ACP';

  @override
  String get agentGemini => 'Gemini CLI';

  @override
  String get activeAgent => 'Активный агент';

  @override
  String get inputPromptHint =>
      'Попросите агента провести диагностику, запустить инструменты или написать команды... (Enter для отправки)';

  @override
  String get thinking => 'Размышление';

  @override
  String get executionPlan => 'План выполнения';

  @override
  String get toolCall => 'Вызов инструмента';

  @override
  String get toolStatusPending => 'В ожидании';

  @override
  String get toolStatusRunning => 'Выполняется...';

  @override
  String get toolStatusCompleted => 'Завершено';

  @override
  String get toolStatusFailed => 'Ошибка';

  @override
  String get permissionRequired => 'Требуется разрешение';

  @override
  String get permissionDescription =>
      'Агент хочет выполнить эту команду на сервере:';

  @override
  String get permissionReject => 'Отклонить';

  @override
  String get permissionAllowOnce => 'Разрешить один раз';

  @override
  String get permissionAllowAlways => 'Разрешать всегда';

  @override
  String get quickTroubleshootCpu => 'Диагностика высокой загрузки ЦП';

  @override
  String get quickDockerHealth => 'Проверка работоспособности Docker';

  @override
  String get quickCleanCache => 'Очистить системный кэш';

  @override
  String get quickNginxLogs => 'Проверить журналы ошибок Nginx';

  @override
  String get terminalNewTab => 'Новая вкладка';

  @override
  String get terminalCloseTab => 'Закрыть вкладку';

  @override
  String get terminalClear => 'Очистить';

  @override
  String get terminalQuickCmds => 'Палитра команд';

  @override
  String get terminalPaste => 'Вставить';

  @override
  String get terminalConfirmPasteTitle => 'Подтвердить вставку';

  @override
  String terminalConfirmPasteMessage(int count) {
    return 'Вставка $count строк текста в терминал. Продолжить?';
  }

  @override
  String get settingsTerminalPinnedKeys => 'Клавиши панели терминала';

  @override
  String get settingsTerminalPinnedKeysSubtitle =>
      'Настройка и изменение порядка клавиш панели инструментов';

  @override
  String get terminalResetPinnedKeys => 'Сбросить по умолчанию';

  @override
  String get terminalToggleKeyboard => 'Переключить клавиатуру';

  @override
  String get sftpCurrentPath => 'Текущий путь';

  @override
  String get sftpUpload => 'Загрузить';

  @override
  String get sftpNewFolder => 'Новая папка';

  @override
  String get sftpNewFile => 'Новый файл';

  @override
  String get sftpRefresh => 'Обновить';

  @override
  String get sftpSearchHint => 'Поиск файлов или папок...';

  @override
  String get sftpEmpty => 'Каталог пуст';

  @override
  String get sftpFileName => 'Имя';

  @override
  String get sftpFileSize => 'Размер';

  @override
  String get sftpFilePerm => 'Права доступа';

  @override
  String get sftpFileModified => 'Изменен';

  @override
  String get cmdCategoryDocker => 'СТЕК КОНТЕЙНЕРОВ DOCKER';

  @override
  String get cmdCategorySystem => 'ОБСЛУЖИВАНИЕ СИСТЕМЫ';

  @override
  String get cmdCategoryNetwork => 'СЕТЬ И ПОРТЫ';

  @override
  String get cmdExecute => 'Запустить';

  @override
  String get cmdDangerous => 'Опасная команда';

  @override
  String get cmdDangerousWarning =>
      'Эта операция необратима и может привести к сбою в работе служб. Вы уверены, что хотите продолжить?';

  @override
  String get cmdParamRequired => 'Требуется ввод параметра';

  @override
  String get cmdConfirm => 'Подтвердить и запустить';

  @override
  String get cmdCancel => 'Отмена';

  @override
  String get settingsAppearance => 'Внешний вид и темы';

  @override
  String get settingsThemeMode => 'Режим темы';

  @override
  String get themeSystem => 'Как в системе';

  @override
  String get themeSystemDesc => 'Автоматическая адаптация';

  @override
  String get themeLight => 'Светлая тема';

  @override
  String get themeLightDesc => 'Светлая бумага';

  @override
  String get themeDark => 'Темная тема';

  @override
  String get themeDarkDesc => 'Глубокий антрацит';

  @override
  String get themeAmoled => 'AMOLED черный';

  @override
  String get themeAmoledDesc => 'Абсолютный черный 0x000000';

  @override
  String get settingsAccentColor => 'Цвет акцента темы';

  @override
  String get accentCyberEmerald => 'Кибер-изумруд';

  @override
  String get accentTechBlue => 'Техно-синий';

  @override
  String get accentElectricViolet => 'Электро-фиолетовый';

  @override
  String get accentCrimsonRed => 'Малиново-красный';

  @override
  String get accentAmberOrange => 'Янтарно-оранжевый';

  @override
  String get settingsLanguage => 'Язык и регион';

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
  String get settingsAiOps => 'AI Ops и движок';

  @override
  String get settingsSecurity => 'Подключение и безопасность';

  @override
  String get settingsKnownHosts => 'Известные ключи хостов';

  @override
  String get settingsClearStorage => 'Сбросить учетные данные';

  @override
  String get settingsResetDefault => 'Сбросить по умолчанию';

  @override
  String get settingsTerminalUseTmux => 'Постоянные сессии (tmux)';

  @override
  String get settingsTerminalUseTmuxSubtitle =>
      'Запускать сессии терминала внутри tmux на удаленном сервере';

  @override
  String get settingsTerminalUseTmuxDescription =>
      'Сохраняет вывод терминала после отключения. Требуется tmux на удаленном сервере. Применяется к новым вкладкам терминала.';

  @override
  String get settingsTerminalFontSize => 'Размер шрифта терминала';

  @override
  String get settingsTerminalFontSizeSubtitle =>
      'Настройка размера шрифта для терминалов SSH и CLI';

  @override
  String get version => 'Версия';

  @override
  String get addServer => 'Добавить сервер';

  @override
  String get editServer => 'Редактировать сервер';

  @override
  String get serverName => 'Имя сервера';

  @override
  String get serverHost => 'Хост / IP';

  @override
  String get serverPort => 'Порт';

  @override
  String get serverUsername => 'Имя пользователя';

  @override
  String get serverAuthType => 'Тип аутентификации';

  @override
  String get serverPassword => 'Пароль';

  @override
  String get serverPrivateKey => 'Приватный ключ';

  @override
  String get serverSave => 'Сохранить сервер';

  @override
  String get serverDelete => 'Удалить сервер';

  @override
  String get fileEditor => 'Редактор файлов';

  @override
  String get fileEditorSave => 'Сохранить изменения';

  @override
  String get fileSavedSuccess => 'Файл успешно сохранен';

  @override
  String get addCommand => 'Новая команда';

  @override
  String get commandTitle => 'Название команды';

  @override
  String get commandContent => 'Строка команды';

  @override
  String get commandCategory => 'Категория';

  @override
  String get commandDescription => 'Описание';

  @override
  String get save => 'Сохранить';

  @override
  String get delete => 'Удалить';

  @override
  String get cancel => 'Отмена';

  @override
  String get confirm => 'Подтвердить';

  @override
  String get cmdExecutionChannel => 'Канал выполнения';

  @override
  String get cmdChannelTerminal => 'Прямо в терминал SSH';

  @override
  String get cmdChannelTerminalDesc =>
      'Команда вводится непосредственно в активную сессию терминала';

  @override
  String get cmdChannelBackground => 'Запуск в фоновой сессии';

  @override
  String get cmdChannelBackgroundDesc =>
      'Выполняется через shell входа SSH и перехватывает вывод';

  @override
  String get cmdInjectedToTerminal => 'Команда отправлена в терминал';

  @override
  String get cmdExecutionCompleted => 'Выполнение завершено';

  @override
  String get cmdExecutionFailed => 'Ошибка выполнения';

  @override
  String get cmdExecutingRemote => 'Выполнение удаленной команды...';

  @override
  String get cmdClose => 'Закрыть';

  @override
  String get navDashboard => 'Панель';

  @override
  String get navDocker => 'Docker';

  @override
  String get navSystem => 'Система';

  @override
  String get navMore => 'Еще';

  @override
  String get dashboardTitle => 'Панель управления сервером';

  @override
  String get metricsCpu => 'Загрузка ЦП';

  @override
  String get metricsMemory => 'Использование памяти';

  @override
  String get metricsLoadAvg => 'Средняя нагрузка';

  @override
  String get metricsUptime => 'Время работы системы';

  @override
  String get metricsRootDisk => 'Корневой диск';

  @override
  String get quickActions => 'Быстрый переход';

  @override
  String get activeServerStatus => 'Статус активного сервера';

  @override
  String get noServerSelected => 'Сервер не выбран. Сначала выберите сервер.';

  @override
  String get serverDisconnected => 'Отключено';

  @override
  String get serverConnecting => 'Подключение...';

  @override
  String get connectNow => 'Подключиться';

  @override
  String get serverSpecs => 'Информация и характеристики';

  @override
  String get dockerTitle => 'Контейнеры Docker';

  @override
  String get dockerSearchHint => 'Поиск контейнеров по имени или образу...';

  @override
  String get dockerFilterAll => 'Все';

  @override
  String get dockerFilterRunning => 'Работают';

  @override
  String get dockerFilterExited => 'Остановлены';

  @override
  String get dockerFilterPaused => 'Приостановлены';

  @override
  String get dockerActionStart => 'Запустить';

  @override
  String get dockerActionStop => 'Остановить';

  @override
  String get dockerActionRestart => 'Перезапустить';

  @override
  String get dockerActionPause => 'Приостановить';

  @override
  String get dockerActionUnpause => 'Возобновить';

  @override
  String get dockerActionRm => 'Удалить';

  @override
  String get dockerActionLogs => 'Журналы';

  @override
  String get dockerActionInspect => 'Проверить';

  @override
  String get dockerLogsTitle => 'Журналы контейнера';

  @override
  String get dockerInspectTitle => 'Сведения о контейнере';

  @override
  String get dockerNoContainers => 'На сервере не найдено контейнеров';

  @override
  String get dockerEmptyRunning => 'Нет работающих контейнеров';

  @override
  String get dockerPorts => 'Порты';

  @override
  String get dockerCreated => 'Создан';

  @override
  String get dockerImage => 'Образ';

  @override
  String get systemTitle => 'Процессы и службы';

  @override
  String get tabProcesses => 'Процессы';

  @override
  String get tabServices => 'Службы Systemd';

  @override
  String get processSearchHint => 'Поиск по имени процесса или PID...';

  @override
  String get processPid => 'PID';

  @override
  String get processCpu => '% ЦП';

  @override
  String get processMem => '% ПАМЯТИ';

  @override
  String get processStat => 'Статус';

  @override
  String get processCommand => 'Команда';

  @override
  String get processTerminate => 'Завершить (SIGTERM)';

  @override
  String get processForceKill => 'Принудительно завершить (SIGKILL)';

  @override
  String get processKillForbidden =>
      'Отказ в завершении процесса инициализации системы (PID <= 1)';

  @override
  String get serviceSearchHint => 'Поиск служб по имени...';

  @override
  String get serviceName => 'Служба';

  @override
  String get serviceDescription => 'Описание';

  @override
  String get serviceStatus => 'Статус';

  @override
  String get serviceStartup => 'Автозапуск';

  @override
  String get serviceActionStart => 'Запустить';

  @override
  String get serviceActionStop => 'Остановить';

  @override
  String get serviceActionRestart => 'Перезапустить';

  @override
  String get serviceActionReload => 'Перезагрузить';

  @override
  String get serviceActionEnable => 'Включить';

  @override
  String get serviceActionDisable => 'Отключить';

  @override
  String get serviceNoServices => 'Службы systemd не найдены';

  @override
  String get riskDangerTitle => 'Подтверждение операции высокого риска';

  @override
  String get riskWarningTitle => 'Подтверждение предупреждения операции';

  @override
  String get riskSafeTitle => 'Подтверждение действия';

  @override
  String get riskIrreversibleWarning =>
      'Эта операция относится к ВЫСОКОМУ РИСКУ и не может быть отменена. Это может привести к потере данных или нарушению работы служб.';

  @override
  String get riskWarningDescription =>
      'Эта операция может повлиять на активные службы или перезапустить процессы. Действуйте с осторожностью.';

  @override
  String get riskCommandPreview => 'Предпросмотр команды';

  @override
  String get riskConfirmButton => 'Подтвердить и продолжить';

  @override
  String get riskCancelButton => 'Отмена';

  @override
  String get stateLoading => 'Загрузка удаленных данных...';

  @override
  String get stateOffline => 'Сервер не в сети';

  @override
  String get stateOfflineDesc =>
      'Установите активное SSH-соединение для управления ресурсами и получения метрик.';

  @override
  String get stateError => 'Произошла ошибка';

  @override
  String get stateRetry => 'Повторить';

  @override
  String get stateEmpty => 'Элементы не найдены';

  @override
  String get inspectorTitle => 'Инспектор';

  @override
  String get inspectorClose => 'Закрыть';

  @override
  String get inspectorDetails => 'Сведения инспекции';

  @override
  String get selectServerTitle => 'Выбрать целевой сервер';

  @override
  String get sshDisconnectedSuccess => 'SSH-соединение отключено';

  @override
  String get trustHostFingerprintTitle => 'Доверять отпечатку хоста?';

  @override
  String get trustAndConnect => 'Доверять и подключиться';

  @override
  String get reject => 'Отклонить';

  @override
  String get confirmDeleteServerTitle => 'Удалить сервер';

  @override
  String get noServersFound => 'Серверы еще не настроены';

  @override
  String get agentNotReadyError =>
      'Выбранный агент не готов. Проверьте его среду и конфигурацию.';

  @override
  String get sshDisconnectedError =>
      'SSH отключен. Подключитесь к серверу перед использованием AI Ops.';

  @override
  String get noAgentAvailable => 'Нет доступных агентов';

  @override
  String get noAgentAvailablePrompt =>
      'Нет активного агента. Сначала настройте или подготовьте агента.';

  @override
  String get noAgentAvailableHint =>
      'Выберите или настройте доступного агента для начала чата...';

  @override
  String get manageAgents => 'Управление агентами';

  @override
  String get noReadyAgentsTitle => 'Нет готовых агентов';

  @override
  String get noReadyAgentsDesc =>
      'Ни один агент на этом сервере не прошел проверку среды.';

  @override
  String get agentStatusReady => 'Готов';

  @override
  String get agentStatusChecking => 'Проверка...';

  @override
  String get agentStatusCliMissing => 'Установка не обнаружена';

  @override
  String get agentStatusAcpMissing => 'Компонент ACP не обнаружен';

  @override
  String get agentStatusNotLoggedIn => 'Не выполнен вход';

  @override
  String get agentStatusError => 'Ошибка';

  @override
  String get agentStatusUnknown => 'Неизвестно';

  @override
  String get agentActionInstall => 'Установить';

  @override
  String get agentActionLogin => 'Войти';

  @override
  String get agentActionRefresh => 'Проверить статус';

  @override
  String get noConfiguredAgents => 'На этом сервере нет настроенных агентов';

  @override
  String get agentManagementTitle => 'Управление агентами';

  @override
  String get settingsAgentManagement => 'Управление агентами';

  @override
  String get settingsAgentManagementSubtitle =>
      'Настройка, обнаружение и управление агентами ACP для текущего сервера';

  @override
  String get addAgentButton => 'Добавить агента';

  @override
  String get noServerSelectedForAgents =>
      'Сервер не выбран. Сначала выберите сервер в главном интерфейсе.';

  @override
  String get sshDisconnectedAgentWarning =>
      'SSH отключен. Обнаружение, установка и вход недоступны до установки соединения.';

  @override
  String get noAgentsConfiguredTitle => 'Нет настроенных агентов';

  @override
  String get noAgentsConfiguredDesc =>
      'Добавьте Claude Code, Codex, OpenCode, AGY или пользовательские агенты ACP для включения AI Ops на этом сервере.';

  @override
  String get agentPresetLabel => 'Пресет';

  @override
  String get agentPresetClaudeCode => 'Claude Code';

  @override
  String get agentPresetCodex => 'OpenAI Codex';

  @override
  String get agentPresetOpenCode => 'OpenCode ACP';

  @override
  String get agentPresetAgy => 'Antigravity AGY';

  @override
  String get agentPresetCustom => 'Пользовательский';

  @override
  String get agentNameLabel => 'Имя агента';

  @override
  String get agentNameHint => 'например, Production Codex';

  @override
  String get agentDescriptionLabel => 'Описание';

  @override
  String get agentDescriptionHint => 'Краткое описание агента';

  @override
  String get agentCliCommandLabel => 'Команда проверки CLI';

  @override
  String get agentCliCommandHint => 'например, claude, codex';

  @override
  String get agentAcpCommandLabel => 'Команда запуска ACP';

  @override
  String get agentAcpCommandHint => 'например, codex-acp --stdio';

  @override
  String get agentInstallCommandLabel => 'Команда установки (Необязательно)';

  @override
  String get agentInstallCommandHint =>
      'например, npm install -g @openai/codex';

  @override
  String get agentLoginCheckCommandLabel =>
      'Команда проверки входа (Необязательно)';

  @override
  String get agentLoginCheckCommandHint => 'например, codex --version';

  @override
  String get agentLoginCommandLabel => 'Команда входа (Необязательно)';

  @override
  String get agentLoginCommandHint => 'например, codex login';

  @override
  String get agentSaveButton => 'Сохранить и обнаружить';

  @override
  String get agentCliRequired => 'Требуется команда проверки CLI';

  @override
  String get agentAcpRequired => 'Требуется команда запуска ACP';

  @override
  String get agentNameRequired => 'Требуется имя агента';

  @override
  String get confirmInstallAgentTitle => 'Подтверждение установки агента';

  @override
  String get confirmLoginAgentTitle => 'Подтверждение входа агента';

  @override
  String get agentCommandRiskWarning =>
      'Эта команда будет выполнена непосредственно на удаленном сервере с правами текущего пользователя. Она может устанавливать пакеты или изменять системное окружение.';

  @override
  String get targetServerLabel => 'Целевой сервер';

  @override
  String get commandPreviewLabel => 'Предпросмотр команды';

  @override
  String get executeButton => 'Выполнить';

  @override
  String get deleteAgentTitle => 'Удалить агента';

  @override
  String get deleteAgentConfirm => 'Удалить';

  @override
  String get agentStatusCheckingDesc =>
      'Определение среды на удаленном сервере...';

  @override
  String get agentStatusInstalling => 'Установка зависимостей на сервер...';

  @override
  String get agentStatusLoggingIn => 'Выполнение команды входа на сервере...';

  @override
  String get agentNoLoginCheckProvided => 'Команда проверки входа не указана';

  @override
  String get agentInstallPrompt =>
      'Установка не обнаружена. Установить автоматически сейчас?';

  @override
  String get agentActionAutoInstall => 'Автоустановка';

  @override
  String get agentLoginPrompt => 'Вход не выполнен. Войти сейчас?';

  @override
  String get agentActionExecuteLogin => 'Войти сейчас';

  @override
  String get agentNeedsInstallOrReadyPrompt =>
      'Агенты на этом сервере еще не установлены или не готовы. Настройте и завершите подготовку среды.';

  @override
  String get agentNeedsInstallOrReadyHint =>
      'Установите и подготовьте агента для начала чата...';

  @override
  String get agentAcpInstallPrompt =>
      'Компонент ACP не обнаружен. Установить автоматически сейчас?';

  @override
  String get agentInstallCommandAcpLabel =>
      'Команда установки ACP (Необязательно)';

  @override
  String get agentInstallCommandAcpHint =>
      'например, npm install -g @zed-industries/codex-acp';

  @override
  String get agentNoInstallCommand =>
      'Для этого агента не настроена команда установки';

  @override
  String get agentInstallLogTitle => 'Вывод установки';

  @override
  String get agentInstallLogEmpty => 'Ожидание вывода установки…';

  @override
  String get agentInstallLogTruncated =>
      'Вывод слишком длинный; показаны самые последние строки';

  @override
  String get agentAcpOptional =>
      'Необязательно; оставьте пустым только для CLI';

  @override
  String get acpStreaming => 'Потоковая передача ACP...';

  @override
  String get aiOpsAgentTitle => 'Агент AI Ops Valhalla';

  @override
  String get aiOpsEmptySubtitle => 'Подключено через ACP stdio по каналу SSH';

  @override
  String get agentAuthRequiredTitle => 'Требуется аутентификация';

  @override
  String get agentAuthRequiredDesc =>
      'Агенту требуется аутентификация перед обработкой вашего запроса.';

  @override
  String get agentAuthMethodLabel => 'Способ аутентификации';

  @override
  String get agentAuthNoMethodsNotice =>
      'Агент не предоставил способ входа. Проверьте его конфигурацию на сервере.';

  @override
  String get agentAuthProceedButton => 'Войти';

  @override
  String get agentAuthCancelButton => 'Отмена';

  @override
  String get agentAuthRetryHint => 'После входа отправьте сообщение снова.';

  @override
  String get agentAuthRequiredError =>
      'Требуется аутентификация. Войдите, чтобы продолжить.';

  @override
  String get agentLoginTerminalTitle => 'Интерактивный терминал входа';

  @override
  String get agentLoginTerminalSubtitle =>
      'Выполните шаги входа в терминале ниже. Следуйте инструкциям с URL или кодом.';

  @override
  String get agentLoginTerminalRunning =>
      'Команда входа выполняется в терминале...';

  @override
  String get agentLoginTerminalDisconnected =>
      'SSH-соединение потеряно. Сессия входа прервана.';

  @override
  String get agentLoginTerminalRetry => 'Переподключить терминал';

  @override
  String get agentLoginTerminalFinish => 'Завершить и проверить';

  @override
  String get agentLoginTerminalClose => 'Закрыть';

  @override
  String get agentLoginTerminalNoTtyHint =>
      'Если агент требует вставки кода, нажмите и удерживайте терминал для вставки или используйте кнопку ВСТАВИТЬ.';

  @override
  String get agentLoginTerminalUrlLabel => 'Обнаружен URL входа';

  @override
  String get agentLoginTerminalUrlCopy => 'Копировать ссылку';

  @override
  String get agentLoginTerminalUrlCopied =>
      'URL входа скопирован в буфер обмена';

  @override
  String get agentLoginTerminalCopyAll => 'Копировать весь вывод';

  @override
  String get agentLoginTerminalCopiedAll =>
      'Вывод терминала скопирован в буфер обмена';

  @override
  String get sshStatusReconnected => 'Соединение восстановлено';

  @override
  String get sshStatusDisconnectedRetrying =>
      'Соединение потеряно, повторная попытка';

  @override
  String get sshStatusDisconnectedManual => 'Отключено';

  @override
  String get sshStatusHostKeyChanged =>
      'Ключ хоста изменен — соединение отклонено';

  @override
  String get sshKeepAliveNotificationTitle =>
      'Valhalla поддерживает активность ваших сессий';

  @override
  String get terminalTmuxMissingNotice =>
      'tmux не найден — сессии не сохранятся при обрыве соединения';

  @override
  String get terminalTmuxSessionRestored => 'Сессия терминала восстановлена';

  @override
  String get moshSectionTitle => 'Mosh';

  @override
  String get moshEnable =>
      'Включить Mosh — роуминговый терминал, устойчивый к разрывам соединения и смене IP';

  @override
  String get moshServerPathLabel => 'Путь к mosh-server';

  @override
  String get moshPortRangeLabel => 'Диапазон UDP-портов';

  @override
  String get moshNewSession => 'Новая сессия Mosh';

  @override
  String get moshNotInstalled =>
      'mosh-server не найден на удаленном сервере. Установите его с помощью: sudo apt install mosh (Debian/Ubuntu) или sudo dnf install mosh (Fedora/RHEL).';

  @override
  String moshBootstrapFailed(String detail) {
    return 'Не удалось запустить сессию Mosh: $detail';
  }

  @override
  String get moshUdpTimeout =>
      'Время ожидания подключения Mosh истекло — убедитесь, что UDP-трафик не заблокирован брандмауэром.';

  @override
  String get moshSessionTag => 'mosh';

  @override
  String get acpSessionRestored => 'Сессия агента восстановлена';

  @override
  String get acpSessionRestartNotice =>
      'Сессия агента перезапущена — предыдущий контекст недоступен';

  @override
  String get terminalTmuxInstallDialogTitle =>
      'Установить tmux на удаленном сервере?';

  @override
  String get terminalTmuxInstallDialogMessage =>
      'tmux необходим для сохранения сессий терминала при отключении. Установить его сейчас?';

  @override
  String get terminalTmuxInstallCommandLabel => 'Команда для выполнения:';

  @override
  String get terminalTmuxInstallUnsupported =>
      'На удаленном сервере не обнаружен поддерживаемый менеджер пакетов. Установите tmux вручную.';

  @override
  String get terminalTmuxInstallFailed =>
      'Сбой установки tmux. Проверьте права доступа и сеть сервера.';

  @override
  String get terminalTmuxInstallDisconnected =>
      'SSH-соединение потеряно. Переподключитесь для установки tmux.';

  @override
  String get terminalTmuxInstallInstalling => 'Установка tmux...';

  @override
  String get terminalTmuxInstallConfirm => 'Установить tmux';

  @override
  String get terminalTmuxInstallSkip =>
      'Пропустить (использовать обычный shell)';

  @override
  String get sftpDownload => 'Скачать';

  @override
  String get sftpOpen => 'Открыть';

  @override
  String get sftpUploadFailed =>
      'Сбой загрузки. Проверьте разрешения и повторите попытку.';

  @override
  String get sftpDownloadFailed => 'Сбой скачивания';

  @override
  String get sftpOpenUnsupported =>
      'Этот формат файла не поддерживается для открытия.';

  @override
  String get sftpReadFailed =>
      'Не удалось прочитать файл. Проверьте разрешения и повторите попытку.';

  @override
  String get sftpTransferFailed => 'Сбой операции с файлом. Повторите попытку.';

  @override
  String get sftpDownloadSuccess => 'Успешно скачано';

  @override
  String get sftpUploading => 'Загрузка...';

  @override
  String get sftpDownloading => 'Скачивание...';

  @override
  String get sftpUpDirectory => 'Вверх в родительский каталог';

  @override
  String get sftpShowHiddenFiles => 'Показать скрытые файлы';

  @override
  String get sftpHideHiddenFiles => 'Скрыть скрытые файлы';

  @override
  String get sftpHiddenPreferenceSaveFailed =>
      'Не удалось сохранить настройки скрытых файлов';

  @override
  String get sftpViewModeList => 'Список';

  @override
  String get sftpViewModeGrid => 'Сетка';

  @override
  String get sftpViewPreferenceSaveFailed =>
      'Не удалось сохранить настройки режима отображения';

  @override
  String get sftpSymlink => 'Символическая ссылка';

  @override
  String get sftpLinkTargetUnavailable =>
      'Цель символической ссылки повреждена или недоступна';

  @override
  String get sftpLinkTargetPermissionDenied =>
      'Отказано в доступе к цели символической ссылки';

  @override
  String get settingsAutoConnect => 'Автоподключение при запуске';

  @override
  String get settingsAutoConnectFixed =>
      'Фиксированный SSH-сервер по умолчанию';

  @override
  String get settingsAutoConnectFixedDesc =>
      'Всегда подключаться к серверу, выбранному ниже';

  @override
  String get settingsAutoConnectLast => 'Запоминать последнее подключение';

  @override
  String get settingsAutoConnectLastDesc =>
      'Подключаться к серверу, к которому успешно подключались в прошлый раз';

  @override
  String get settingsAutoConnectPickServer => 'Сервер';

  @override
  String get settingsAutoConnectNoServer => 'Сервер еще не выбран';

  @override
  String get sftpSort => 'Сортировка';

  @override
  String get sftpSortName => 'Имя';

  @override
  String get sftpSortSize => 'Размер';

  @override
  String get sftpSortDate => 'Дата изменения';

  @override
  String get sftpSortAscending => 'По возрастанию';

  @override
  String get sftpSortDescending => 'По убыванию';

  @override
  String get themeQuickSwitch => 'Тема';

  @override
  String get transferList => 'Передачи';

  @override
  String get transferEmpty => 'Передач пока нет';

  @override
  String get transferUpload => 'Загрузка';

  @override
  String get transferDownload => 'Скачивание';

  @override
  String get transferStatusQueued => 'В очереди';

  @override
  String get transferStatusRunning => 'Передача';

  @override
  String get transferStatusPaused => 'Приостановлено';

  @override
  String get transferStatusCompleted => 'Завершено';

  @override
  String get transferStatusFailed => 'Ошибка';

  @override
  String get transferStatusCanceled => 'Отменено';

  @override
  String get transferPause => 'Пауза';

  @override
  String get transferResume => 'Возобновить';

  @override
  String get transferCancel => 'Отмена';

  @override
  String get transferRemove => 'Удалить';

  @override
  String get transferClearFinished => 'Очистить завершенные';

  @override
  String get transferSizeUnknown => 'Размер неизвестен';

  @override
  String get transferFailedUpload => 'Ошибка загрузки';

  @override
  String get transferFailedDownload => 'Ошибка скачивания';

  @override
  String get stopGeneration => 'Остановить';

  @override
  String get chatServerBindingRequired =>
      'Эта сессия не привязана к серверу. Привяжите ее к текущему серверу для продолжения.';

  @override
  String get chatSessionUnboundNotice =>
      'Эта сессия не привязана ни к одному серверу.';

  @override
  String get bindServerAction => 'Привязать сервер';

  @override
  String get bindServerDialogTitle => 'Привязать сессию к серверу';

  @override
  String get bindServerConfirmAction => 'Подтвердить привязку';

  @override
  String get chatSessionIdentityMismatch =>
      'Текущий сервер или агент не соответствует привязанному идентификатору этой сессии. Переключитесь на соответствующий сервер и агент для продолжения.';

  @override
  String get deleteSessionTitle => 'Удалить сессию';

  @override
  String get deleteSessionConfirmAction => 'Удалить';

  @override
  String get shareAgentSessionsTitle => 'Общий доступ к сессиям агентов';

  @override
  String get shareAgentSessionsSubtitle =>
      'Делиться сессиями между разными агентами на этом сервере';

  @override
  String get shareAgentSessionsEnabled =>
      'Общий доступ к сессиям агентов включен';

  @override
  String get shareAgentSessionsDisabled =>
      'Общий доступ к сессиям агентов отключен';

  @override
  String get agentCliStatusInstalled => 'CLI: Установлен';

  @override
  String get agentCliStatusMissing => 'CLI: Отсутствует';

  @override
  String get agentCliStatusChecking => 'CLI: Проверка...';

  @override
  String get agentCliStatusUnknown => 'CLI: Неизвестно';

  @override
  String get agentCliStatusError => 'CLI: Ошибка';

  @override
  String get agentAcpStatusReady => 'ACP: Готов';

  @override
  String get agentAcpStatusMissing => 'ACP: Отсутствует';

  @override
  String get agentAcpStatusChecking => 'ACP: Проверка...';

  @override
  String get agentAcpStatusPendingCli => 'ACP: Ожидание CLI';

  @override
  String get agentAcpStatusUnknown => 'ACP: Неизвестно';

  @override
  String get agentAcpStatusError => 'ACP: Ошибка';

  @override
  String get agentAcpStatusNa => 'ACP: Н/Д';

  @override
  String get agentAuthStatusAuthenticated => 'Авторизация: Выполнен вход';

  @override
  String get agentAuthStatusUnauthenticated => 'Авторизация: Вход не выполнен';

  @override
  String get agentAuthStatusUnknown => 'Авторизация: Неизвестно';

  @override
  String get downloadNotificationsUnavailable =>
      'Системные уведомления о скачивании недоступны. Загрузка продолжится в фоновом режиме.';

  @override
  String get downloadOpenFailed => 'Не удалось открыть скачанный файл.';

  @override
  String get dockerActionPending =>
      'Для этого контейнера уже выполняется действие';

  @override
  String get dockerNoLogs => '(Нет журналов)';

  @override
  String get serverReboot => 'Перезагрузить';

  @override
  String get serverRebootDialogTitle => 'Подтверждение перезагрузки сервера';

  @override
  String get serverRebootDialogMessage =>
      'Вы уверены, что хотите перезагрузить этот сервер? Все активные подключения и фоновые службы будут прерваны.';

  @override
  String get serverRebootConfirmButton => 'Перезагрузить сейчас';

  @override
  String get serverRebootPasswordTitle => 'Требуется пароль Sudo';

  @override
  String get serverRebootPasswordMessage =>
      'Для перезагрузки сервера требуются права root. Введите пароль sudo (используется один раз, не сохраняется):';

  @override
  String get serverRebootPasswordHint => 'Пароль Sudo';

  @override
  String get serverRebootSubmitting => 'Отправка команды перезагрузки...';

  @override
  String get serverRebootAccepted =>
      'Команда перезагрузки принята; завершение еще не подтверждено. Переподключитесь, когда сервер снова будет в сети.';

  @override
  String get serverRebootVerified =>
      'Перезагрузка сервера подтверждена; система снова в сети.';

  @override
  String get serverRebootUnknown =>
      'Результат перезагрузки неопределен. Команда была отправлена, но подтверждение не получено. Проверьте подключение вручную.';

  @override
  String get serverRebootReconnect => 'Переподключить';

  @override
  String get serverRebootServerChanged =>
      'Целевой сервер изменился, перезагрузка отменена';

  @override
  String get navCliChat => 'CLI чат';

  @override
  String get cliChatTitle => 'Сессии CLI';

  @override
  String get cliChatSubtitle =>
      'Нативные сессии агента CLI на удаленном сервере';

  @override
  String get cliSelectAgent => 'Выбрать агента';

  @override
  String get cliNoAgentsConfigured => 'Для этого сервера не добавлены агенты';

  @override
  String get cliAgentNeedsSetup =>
      'Среда агента отсутствует или не выполнен вход';

  @override
  String get cliManageAgentsGuide => 'Настройте в Управлении агентами';

  @override
  String get cliNewDraft => 'Новый черновик';

  @override
  String get cliNewDraftTooltip =>
      'Создать пустой черновик (сессия создается при первом сообщении)';

  @override
  String get cliDeleteSessionTitle => 'Удалить историю удаленной сессии CLI';

  @override
  String get cliDeleteSessionMessage =>
      'Это навсегда удалит историю сессии CLI на удаленном сервере. Вы уверены, что хотите продолжить?';

  @override
  String get cliDeleteConfirmButton => 'Удалить сессию';

  @override
  String get cliCannotDeleteTooltip =>
      'Удаление удаленной сессии не поддерживается или отключено';

  @override
  String get cliSessionsHeader => 'Сессии';

  @override
  String get cliNoSessions => 'Сессии CLI не найдены';

  @override
  String get cliFilterCwdHint => 'Фильтр по пути CWD...';

  @override
  String get cliFilterCwdAction => 'Фильтровать';

  @override
  String get cliClearCwdAction => 'Очистить';

  @override
  String get cliLoadMoreSessions => 'Загрузить больше сессий';

  @override
  String get cliRefreshSessions => 'Обновить';

  @override
  String get cliClaudeReadOnlyNotice =>
      'История Claude доступна только для чтения. Продолжите разговор в реальном терминале.';

  @override
  String get cliContinueInTerminal => 'Продолжить в терминале';

  @override
  String get cliOpenTerminal => 'Открыть терминал';

  @override
  String get cliCloseTerminal => 'Закрыть терминал';

  @override
  String get cliTerminalRunning => 'Интерактивный терминал CLI';

  @override
  String get cliAgyTerminalOnlyNotice =>
      'Этот агент не поддерживает структурированную синхронизацию истории. Пожалуйста, используйте нативный терминал CLI для взаимодействия и выбора сессий.';

  @override
  String get cliInstallSdkTitle => 'Установить официальный SDK истории Claude';

  @override
  String get cliInstallSdkMessage =>
      'На удаленном сервере отсутствует официальный SDK Claude Code History. Хотите установить его сейчас?';

  @override
  String get cliInstallSdkAction => 'Установить официальный SDK';

  @override
  String get cliApprovalsTitle => 'Ожидающие подтверждения';

  @override
  String get cliApprovalDetails => 'Сведения';

  @override
  String get cliApprovalAllow => 'Разрешить';

  @override
  String get cliApprovalDecline => 'Отклонить';

  @override
  String get cliInputHint => 'Введите сообщение агенту CLI...';

  @override
  String get cliSend => 'Отправить';

  @override
  String get cliStop => 'Остановить';

  @override
  String get cliBusy => 'Операция выполняется, пожалуйста, подождите...';

  @override
  String get cliDisconnected => 'SSH не подключен';

  @override
  String get cliServerChanged => 'Целевой сервер изменился';

  @override
  String get cliTurnFailed => 'Сбой выполнения хода CLI';

  @override
  String get cliUseTerminal =>
      'Требуется интерактивный ввод, откройте терминал для продолжения';

  @override
  String get cliDeleteFailed => 'Не удалось удалить удаленную сессию';

  @override
  String get cliDeleteUnsupported =>
      'Удаление удаленных сессий не поддерживается этим CLI';

  @override
  String get cliOperationFailed => 'Сбой операции CLI';

  @override
  String get cliHistorySdkMissing =>
      'На сервере отсутствует официальный History SDK';

  @override
  String get cliHistoryRuntimeMissing =>
      'Для истории Claude на сервере требуется Node.js/npm. Пожалуйста, установите Node.js вручную; вы по-прежнему можете использовать настоящий CLI в терминале.';

  @override
  String get cliLoginRequired =>
      'Требуется вход агента. Войдите через Управление агентами.';

  @override
  String get cliNotInstalled =>
      'CLI агента не установлен. Установите его через Управление агентами.';

  @override
  String get cliVersionUnsupported =>
      'Версия CLI агента не поддерживается. Обновите или переустановите через Управление агентами.';

  @override
  String get settingsNavigation => 'Навигация';

  @override
  String get settingsNavigationDesc =>
      'Настройка начальной страницы по умолчанию и нижней панели навигации';

  @override
  String get settingsStartupPage => 'Начальная страница';

  @override
  String get settingsStartupPageDesc =>
      'Страница, отображаемая при открытии приложения';

  @override
  String get settingsBottomNav => 'Нижняя панель навигации';

  @override
  String get settingsBottomNavDesc =>
      'Выберите разделы для отображения в нижней панели на мобильных устройствах (поддерживается от 0 до 9 элементов)';

  @override
  String get settingsResetSuccess =>
      'Все настройки сброшены до значений по умолчанию';

  @override
  String get metricsTrendSubtitle => 'Последние ~3 минуты (до 60 измерений)';

  @override
  String get metricsCurrent => 'Текущее';

  @override
  String get metricsPeak => 'Пик';

  @override
  String get metricsValley => 'Минимум';

  @override
  String get metricsTrendWaiting => 'Сбор данных метрик...';

  @override
  String get metricsTrendStopped => 'Сбор данных остановлен (SSH отключен)';

  @override
  String get dockerActionTerminal => 'Exec Терминал';

  @override
  String get dockerTerminalTitle => 'Терминал контейнера';

  @override
  String get dockerTerminalNotRunning => 'Контейнер не запущен';

  @override
  String get setDefaultAgent => 'Назначить по умолчанию';

  @override
  String get defaultBadge => 'По умолчанию';

  @override
  String get isDefaultAgent => 'Агент по умолчанию';

  @override
  String get setAsDefaultAgent =>
      'Установить как агент по умолчанию для этого сервера';

  @override
  String get agentGroupBasic => 'Основная информация';

  @override
  String get agentGroupCommands => 'Команды';

  @override
  String get agentGroupAuth => 'Установка и аутентификация';

  @override
  String get agentPresetTitle => 'Шаблон пресета';

  @override
  String get resourceProcessList => 'Процессы';

  @override
  String get resourceDiskScanning =>
      'Сканирование корневых каталогов, это может занять несколько секунд...';

  @override
  String get resourceDiskScanPartial =>
      'Некоторые каталоги не удалось отсканировать из-за прав доступа или тайм-аута';

  @override
  String get resourceDiskDirectories =>
      'Использование каталогов верхнего уровня';

  @override
  String get resourceSortCpu => 'Сортировать по ЦП';

  @override
  String get resourceSortMemory => 'Сортировать по памяти';

  @override
  String get resourceRss => 'RSS память';

  @override
  String get resourceUsed => 'Использовано';

  @override
  String get resourceAvailable => 'Доступно';

  @override
  String get resourceTotal => 'Всего';

  @override
  String get settingsBottomNavOrderTitle =>
      'Выбранные элементы (Перетащите для изменения порядка)';

  @override
  String get langSystem => 'Системный по умолчанию';

  @override
  String get serverFieldRequired => 'Обязательно';

  @override
  String get serverPortInvalid => 'Порт должен быть в диапазоне от 1 до 65535';

  @override
  String get serverTestReachability => 'Проверить доступность';

  @override
  String get serverSaveFailedGeneric =>
      'Не удалось сохранить сервер. Проверьте конфигурацию и повторите попытку.';

  @override
  String get serverViewPrivateKey => 'Показать приватный ключ';

  @override
  String get serverHidePrivateKey => 'Скрыть приватный ключ';

  @override
  String get dockerBashFallbackNotice =>
      'Bash недоступен в контейнере, переключение на Sh';

  @override
  String get dockerShellLabel => 'Shell';

  @override
  String get dockerShellBash => 'Bash';

  @override
  String get dockerShellSh => 'Sh';

  @override
  String get cliDraftWorkingDirLabel => 'Рабочий каталог';

  @override
  String get cliDefaultWorkingDir => 'По умолчанию (/)';

  @override
  String get cliPickWorkingDirTitle => 'Выбрать рабочий каталог';

  @override
  String get cliClearWorkingDir => 'Сбросить по умолчанию';

  @override
  String get cliBrowseWorkingDir => 'Обзор';

  @override
  String get cliSelectCurrentDir => 'Выбрать этот каталог';

  @override
  String get cliNavigateUp => 'На уровень выше';

  @override
  String get chatSessionsTooltip => 'Сессии';

  @override
  String get hardwareSpecsTitle => 'Оборудование и система';

  @override
  String get hardwareCpu => 'ЦП';

  @override
  String get hardwareMemory => 'Память';

  @override
  String get hardwareDisk => 'Корневой диск';

  @override
  String get hardwareDistribution => 'ОС';

  @override
  String get hardwareKernel => 'Ядро';

  @override
  String get hardwareLoading => 'Загрузка характеристик оборудования...';

  @override
  String get hardwareUnavailable => 'Характеристики оборудования недоступны';

  @override
  String get hardwareUnknown => 'Неизвестно';

  @override
  String get systemInfoTitle => 'Информация о системе';

  @override
  String get systemInfoTapHint => 'Нажмите, чтобы просмотреть ASCII-арт';

  @override
  String get systemInfoHost => 'Хост';

  @override
  String get serverShutdown => 'Выключить';

  @override
  String get serverShutdownDialogTitle => 'Подтверждение выключения сервера';

  @override
  String get serverShutdownDialogMessage =>
      'Вы уверены, что хотите выключить этот сервер? Система будет полностью отключена и станет недоступна удаленно до ручного включения.';

  @override
  String get serverShutdownConfirmButton => 'Выключить сейчас';

  @override
  String get serverShutdownSubmitting => 'Отправка команды выключения...';

  @override
  String get serverShutdownAccepted =>
      'Команда выключения принята; завершение выключения не подтверждено.';

  @override
  String get serverShutdownUnknown =>
      'Результат выключения неизвестен: возможно, команда была отправлена, но подтверждение не получено. Проверьте вручную; автоматических повторов не будет.';

  @override
  String get serverShutdownPasswordTitle =>
      'Требуется пароль Sudo для выключения';

  @override
  String get serverShutdownPasswordMessage =>
      'Для выключения сервера требуются права root. Введите пароль sudo (используется один раз, не сохраняется):';

  @override
  String get serverShutdownPasswordHint => 'Пароль Sudo';

  @override
  String get serverShutdownServerChanged =>
      'Целевой сервер изменился, выключение отменено';

  @override
  String get metricsNetwork => 'Скорость сети';

  @override
  String get networkModalTitle => 'Сведения о сетевых интерфейсах';

  @override
  String get networkDownloadRate => 'Входящий (RX)';

  @override
  String get networkUploadRate => 'Исходящий (TX)';

  @override
  String get networkTotalRx => 'Всего RX';

  @override
  String get networkTotalTx => 'Всего TX';

  @override
  String get networkPrimary => 'Основной маршрут';

  @override
  String get networkRatesEmpty => 'Активные сетевые интерфейсы не обнаружены';

  @override
  String get networkWaitingSecondSample => 'Ожидание второго замера';

  @override
  String get networkUnavailable => 'Недоступно';

  @override
  String get networkNoDefaultInterface => 'Нет маршрута по умолчанию';

  @override
  String get selectThemeModeTitle => 'Выбрать режим темы';

  @override
  String get selectLanguageTitle => 'Выбрать язык';

  @override
  String get selectStartupPageTitle => 'Выбрать начальную страницу';

  @override
  String get selectAutoConnectModeTitle => 'Выбрать режим автоподключения';

  @override
  String get accentColorDialogTitle => 'Настройка цветов акцента';

  @override
  String get accentColorLightMode => 'Светлый режим';

  @override
  String get accentColorDarkMode => 'Темный режим';

  @override
  String get accentColorAmoledMode => 'AMOLED (Geek)';

  @override
  String get accentColorPresets => 'Пресеты';

  @override
  String get accentColorHsvPicker => 'Цветовой круг';

  @override
  String get accentColorHexCode => 'Hex-код';

  @override
  String get accentColorPreview => 'Предпросмотр';

  @override
  String get accentColorSampleButton => 'Кнопка с акцентом';

  @override
  String get accentColorInvalidHex => 'Неверный формат Hex (напр. #10B981)';

  @override
  String get settingsDashboardQuickActions => 'Быстрые действия панели';

  @override
  String get settingsDashboardQuickActionsDesc =>
      'Настройте ярлыки быстрого доступа на панели управления. Очистка скроет раздел быстрых действий.';

  @override
  String get settingsDashboardQuickActionsEmpty =>
      'Быстрые действия скрыты (ярлыки не выбраны)';

  @override
  String get settingsDashboardQuickActionsOrderTitle =>
      'Перетащите для изменения порядка';

  @override
  String get settingsDashboardQuickActionsCandidates =>
      'Выберите видимые ярлыки';

  @override
  String get terminalCopySelection => 'Копировать';

  @override
  String get terminalSelectionCopied => 'Выделение скопировано в буфер обмена';

  @override
  String get editAgent => 'Редактировать агента';

  @override
  String get agentExecutionTarget => 'Среда выполнения';

  @override
  String get agentExecutionHost => 'Хост-система';

  @override
  String get agentExecutionDocker => 'Контейнер Docker';

  @override
  String get agentContainerBinding => 'Режим привязки контейнера';

  @override
  String get agentContainerBindingId => 'По ID контейнера';

  @override
  String get agentContainerBindingName => 'По имени контейнера';

  @override
  String get agentContainerReference => 'Целевой контейнер';

  @override
  String get agentContainerReferenceHint =>
      'Выберите или введите ID или имя контейнера';

  @override
  String get agentContainerRequired =>
      'Целевой контейнер обязателен для выполнения в Docker';

  @override
  String get agentLoadingContainers => 'Запрос контейнеров на сервере...';

  @override
  String get agentNoContainersFound => 'На этом сервере контейнеры не найдены';

  @override
  String get agentContainerUser =>
      'Пользователь запуска контейнера (Необязательно)';

  @override
  String get agentContainerUserHint => 'например, dev';

  @override
  String get agentContainerUserHelper =>
      'Оставьте пустым для пользователя по умолчанию; напр. dev; поддерживает user, UID, user:group, UID:GID';

  @override
  String get agentContainerUserSelect => 'Выбрать пользователя контейнера';

  @override
  String get agentContainerUsersLoading => 'Загрузка пользователей...';

  @override
  String get agentContainerUsersEmpty => 'Пользователи passwd не найдены';

  @override
  String get agentViewDiagnosticLog => 'Просмотреть журнал диагностики';

  @override
  String get agentDiagnosticLogCopied =>
      'Журнал диагностики скопирован в буфер обмена';

  @override
  String get agentDiagnosticLogCopy => 'Копировать';

  @override
  String get agentDiagnosticLogClose => 'Закрыть';

  @override
  String get settingsCliHistoryPageSize => 'Размер страницы истории CLI';

  @override
  String get settingsCliHistoryPageSizeDesc =>
      'Количество старых сообщений, загружаемых на страницу при прокрутке вверх (5-100)';

  @override
  String get settingsCliHistoryPageSizeTitle =>
      'Выбрать размер страницы истории CLI';

  @override
  String get cliLoadingOlderMessages => 'Загрузка более старых сообщений...';

  @override
  String get chatLoadOlderMessages => 'Загрузить предыдущие сообщения';

  @override
  String get chatCommandsTooltip => 'Команды';

  @override
  String get chatAttachTooltip => 'Прикрепить файл';

  @override
  String get chatAttachImage => 'Прикрепить локальное изображение';

  @override
  String get chatAttachLocalText => 'Прикрепить локальный текстовый файл';

  @override
  String get chatAttachRemoteText => 'Прикрепить удаленный текстовый файл';

  @override
  String get chatAttachRemotePathTitle => 'Прикрепить удаленный текстовый файл';

  @override
  String get chatAttachRemotePathHint => '/путь/к/файлу.txt';

  @override
  String get chatAttachTooLarge => 'Файл превышает ограничение по размеру';

  @override
  String get chatUsageAndDiagnostics => 'Использование и диагностика';

  @override
  String get chatWorkingDirTooltip => 'Рабочий каталог черновика';

  @override
  String get chatAttachFailed => 'Не удалось прикрепить файл';

  @override
  String get chatInvalidRemotePath =>
      'Неверный удаленный путь к файлу (должен начинаться с /)';

  @override
  String get chatRemoteReadFailed => 'Не удалось прочитать удаленный файл';

  @override
  String get chatInvalidDirPath =>
      'Неверный путь к каталогу (должен начинаться с /)';

  @override
  String get chatNoSubdirectories => 'Нет подкаталогов';

  @override
  String get chatUsageTitle => 'Расход токенов и стоимость';

  @override
  String get chatUsageUsed => 'Использовано токенов';

  @override
  String get chatUsageSize => 'Размер контекста';

  @override
  String get chatUsageCost => 'Стоимость';

  @override
  String get chatDiagnosticsTitle => 'Журнал диагностики';

  @override
  String get chatNoDiagnostics => 'Нет доступных журналов диагностики';

  @override
  String get deleteSessionLocalOnlyNotice =>
      'Это удаляет только локальную запись в Valhalla и не удалит нативную историю сессий агента на сервере.';

  @override
  String get chatSearchSessionsHint => 'Поиск сессий...';

  @override
  String get chatLoadMoreSessions => 'Загрузить больше сессий';

  @override
  String get chatLoadingMoreSessions => 'Загрузка дополнительных сессий...';

  @override
  String get chatExportSession => 'Экспорт сессии (Markdown)';

  @override
  String get chatExportSuccess => 'Сессия успешно экспортирована';

  @override
  String get chatExportFailed => 'Не удалось экспортировать сессию';

  @override
  String get chatRemoteSessions => 'Удаленные сессии';

  @override
  String get chatRemoteSessionsTitle => 'Сессии удаленного агента';

  @override
  String get chatRemoteSessionsDesc =>
      'Просмотр и импорт нативной истории сессий с удаленного агента';

  @override
  String get chatRemoteSessionsEmpty => 'Удаленные сессии не найдены';

  @override
  String get chatRemoteImporting => 'Импорт истории удаленных сессий...';

  @override
  String get chatRemoteImportFailed =>
      'Не удалось импортировать удаленную сессию';

  @override
  String get chatStatusInterrupted => 'Прервано';

  @override
  String get chatStatusFailed => 'Ошибка';

  @override
  String get chatStatusAwaitingAuth => 'Ожидание аутентификации ACP';

  @override
  String get chatShowFullOutput => 'Показать весь вывод';

  @override
  String get chatShowLessOutput => 'Свернуть';

  @override
  String get chatToolLocations => 'Затронутые пути';

  @override
  String cmdParamPlaceholder(String param) {
    return 'Введите значение для $param';
  }

  @override
  String processTerminateSuccess(Object pid) {
    return 'Процесс $pid завершен';
  }

  @override
  String serviceActionSuccess(Object action, Object service) {
    return 'Действие $action над $service выполнено успешно';
  }

  @override
  String riskPatternMatched(Object pattern) {
    return 'Сработало правило: $pattern';
  }

  @override
  String stateExitCode(Object code) {
    return 'Код завершения: $code';
  }

  @override
  String sshConnectedSuccess(Object server) {
    return 'Успешное подключение к $server по SSH';
  }

  @override
  String sshConnectionFailed(Object error) {
    return 'Сбой SSH-подключения: $error';
  }

  @override
  String trustHostFingerprintMessage(
    Object fingerprint,
    Object host,
    Object type,
  ) {
    return 'Подключение к $host ($type) в первый раз.\n\nОтпечаток SHA-256:\n$fingerprint\n\nДоверять этому отпечатку и подключиться?';
  }

  @override
  String enterPasswordTitle(Object server) {
    return 'Введите пароль для $server';
  }

  @override
  String confirmDeleteServerMessage(Object name) {
    return 'Вы уверены, что хотите удалить сервер \'$name\'? Это действие нельзя отменить.';
  }

  @override
  String deleteAgentMessage(Object name) {
    return 'Вы уверены, что хотите удалить агента \'$name\'? Это удалит его конфигурацию и состояние среды на этом сервере, не затрагивая историю чатов и учетные данные SSH.';
  }

  @override
  String agentLastChecked(Object time) {
    return 'Последняя проверка: $time';
  }

  @override
  String agentAuthPickerTitle(Object agent) {
    return 'Выберите способ входа в $agent';
  }

  @override
  String sshStatusReconnecting(Object n) {
    return 'Переподключение… (попытка $n)';
  }

  @override
  String sshKeepAliveNotificationBody(Object n) {
    return 'Активных сессий: $n';
  }

  @override
  String bindServerConfirmMessage(Object serverName) {
    return 'Привязать эту сессию к серверу \\\"$serverName\\\"? После привязки сессия будет ассоциирована с этим сервером.';
  }

  @override
  String deleteSessionConfirmMessage(Object title) {
    return 'Вы уверены, что хотите удалить сессию \\\"$title\\\"? Это действие нельзя отменить.';
  }

  @override
  String dockerActionSuccess(Object action, Object name) {
    return 'Действие $action для контейнера $name выполнено успешно';
  }

  @override
  String dockerActionFailed(Object error) {
    return 'Сбой действия: $error';
  }

  @override
  String serverRebootTarget(Object address, Object name) {
    return 'Целевой сервер: $name ($address)';
  }

  @override
  String serverRebootRunningTerminals(Object count) {
    return 'Сессии терминала: $count';
  }

  @override
  String serverRebootRunningAgents(Object count) {
    return 'Сессии агентов: $count';
  }

  @override
  String serverRebootRunningTransfers(Object count) {
    return 'Активные передачи: $count';
  }

  @override
  String serverRebootFailed(Object error) {
    return 'Сбой перезагрузки: $error';
  }

  @override
  String cliDeleteFailedWithDetail(Object detail) {
    return 'Не удалось удалить удаленную сессию: $detail';
  }

  @override
  String metricsTrendTitle(Object metric) {
    return 'Тенденция $metric';
  }

  @override
  String metricsThresholdWarning(Object value) {
    return 'Предупреждение: $value';
  }

  @override
  String metricsThresholdDanger(Object value) {
    return 'Опасность: $value';
  }

  @override
  String metricsHistoryPoints(Object count) {
    return 'Точек данных: $count';
  }

  @override
  String resourceUsageTitle(Object metric) {
    return 'Использование ресурсов $metric';
  }

  @override
  String serverPortReachable(Object port) {
    return 'TCP-порт $port доступен';
  }

  @override
  String serverConnectionFailed(Object error) {
    return 'Сбой подключения: $error';
  }

  @override
  String serverSaveFailed(Object error) {
    return 'Не удалось сохранить сервер: $error';
  }

  @override
  String hardwareCpuCores(Object cores) {
    return 'Ядер: $cores';
  }

  @override
  String serverShutdownFailed(Object error) {
    return 'Сбой выключения: $error';
  }

  @override
  String networkInterface(Object name) {
    return 'Интерфейс: $name';
  }

  @override
  String agentContainersLoadFailed(Object error) {
    return 'Не удалось загрузить контейнеры: $error';
  }

  @override
  String agentContainerUsersFailed(Object error) {
    return 'Не удалось загрузить пользователей контейнера: $error';
  }

  @override
  String agentDiagnosticLogTitle(Object name) {
    return 'Журнал диагностики - $name';
  }

  @override
  String get agentDockerDetectionFailed =>
      'Сбой обнаружения Docker/контейнеров';

  @override
  String get chatCopiedAllMessages => 'Все сообщения скопированы';

  @override
  String get chatCopyAllMessages => 'Скопировать все сообщения';

  @override
  String get cliModelAtCapacity =>
      'Выбранная модель перегружена. Попробуйте другую модель.';

  @override
  String get chatLaunchBlankDraft => 'Пустой черновик';

  @override
  String get chatLaunchFixedSession => 'Фиксированная сессия';

  @override
  String get chatLaunchRememberLast => 'Запоминать последнюю сессию';

  @override
  String get chatPermissionAskEveryTime => 'Спрашивать каждый раз';

  @override
  String get chatPermissionAutoAllowAll => 'Разрешать все автоматически';

  @override
  String get chatPermissionAutoAllowAllConfirmMessage =>
      'Агент будет выполнять все операции без запроса подтверждения. Продолжить?';

  @override
  String get chatPermissionAutoAllowAllConfirmTitle =>
      'Разрешить все операции?';

  @override
  String get chatPermissionAutoAllowSafe =>
      'Автоматически разрешать безопасные операции';

  @override
  String get chatRunSettingsDefault => 'По умолчанию';

  @override
  String get chatRunSettingsInteractiveCli => 'Интерактивный CLI';

  @override
  String get chatRunSettingsModel => 'Модель';

  @override
  String get chatRunSettingsPermissions => 'Разрешения';

  @override
  String get chatRunSettingsReasoning => 'Уровень рассуждений';

  @override
  String get chatRunSettingsTitle => 'Параметры запуска';

  @override
  String get cliActionInsertCommand => 'Вставить команду';

  @override
  String get cliActionInsertFile => 'Вставить файл';

  @override
  String get cliActionInsertWorkdir => 'Вставить рабочий каталог';

  @override
  String get cliComposerInsertAction => 'Вставить';

  @override
  String cliOperationFailedWithDetail(String detail) {
    return 'Сбой операции CLI: $detail';
  }

  @override
  String get cliSelectCommandTitle => 'Выбрать команду';

  @override
  String get defaultAgentTitle => 'Агент по умолчанию';

  @override
  String get insertSkills => 'Вставить навыки';

  @override
  String get isDefaultSession => 'Сессия по умолчанию';

  @override
  String get sessionLaunchMode => 'Режим запуска сессии';

  @override
  String get setAsDefaultSession => 'Сделать сессией по умолчанию';

  @override
  String get navNas => 'NAS Медиа';

  @override
  String get nasAddExcludePath => 'Добавить путь исключения';

  @override
  String get nasAddIncludePath => 'Добавить папку сканирования';

  @override
  String get nasCancelScan => 'Отменить сканирование';

  @override
  String get nasClearSearch => 'Очистить поиск';

  @override
  String get nasConfigDialogTitle => 'Настройки медиатеки';

  @override
  String get nasConfigure => 'Настроить';

  @override
  String get nasConfigureScanDirs => 'Настроить папки сканирования';

  @override
  String get nasCreatePlaylist => 'Создать плейлист';

  @override
  String get nasEmptyConfigDesc =>
      'Добавьте хотя бы одну папку, чтобы начать создание медиатеки.';

  @override
  String get nasEmptyConfigTitle => 'Папки сканирования не настроены';

  @override
  String get nasExcludePaths => 'Исключенные папки';

  @override
  String get nasExcludedBadge => 'Исключено';

  @override
  String get nasFilterImages => 'Фото';

  @override
  String get nasFilterVideos => 'Видео';

  @override
  String get nasIncludePaths => 'Папки сканирования';

  @override
  String nasItemCount(Object value) {
    return 'Элементов: $value';
  }

  @override
  String nasLastScan(Object value) {
    return 'Последнее сканирование: $value';
  }

  @override
  String get nasLibrarySettings => 'Настройки библиотеки';

  @override
  String nasMediaOpening(Object value) {
    return 'Открытие $value…';
  }

  @override
  String get nasMiniPlayer => 'Мини-плеер';

  @override
  String get nasNoExcludePaths => 'Нет исключенных папок';

  @override
  String get nasNoFavorites => 'Избранного пока нет';

  @override
  String get nasNoIncludePaths => 'Нет папок сканирования';

  @override
  String get nasNoIndexDesc =>
      'Настройте папки и запустите сканирование для индексации медиа.';

  @override
  String get nasNoIndexTitle => 'Медиатека пуста';

  @override
  String get nasNoPlaylists => 'Плейлистов пока нет';

  @override
  String get nasNoSearchResults => 'Подходящих медиафайлов не найдено';

  @override
  String get nasNotScanned => 'Еще не сканировалось';

  @override
  String get nasNowPlaying => 'Сейчас играет';

  @override
  String get nasOpenMethodPrompt => 'Как вы хотите открыть этот файл?';

  @override
  String get nasOpenPolicyAsk => 'Спрашивать каждый раз';

  @override
  String get nasOpenPolicyExternal => 'Открыть во внешнем приложении';

  @override
  String get nasOpenPolicyInApp => 'Открыть в приложении';

  @override
  String get nasOpeningPolicy => 'Способ открытия по умолчанию';

  @override
  String get nasPlaylistName => 'Имя плейлиста';

  @override
  String get nasQuickStats => 'Обзор библиотеки';

  @override
  String get nasScan => 'Сканировать сейчас';

  @override
  String get nasScanCancelled => 'Сканирование отменено';

  @override
  String nasScanFailed(Object value) {
    return 'Сбой сканирования: $value';
  }

  @override
  String get nasScanning => 'Сканирование…';

  @override
  String get nasScopeBadge => 'Область сканирования';

  @override
  String get nasSearchHint => 'Поиск медиа';

  @override
  String get nasStatMusic => 'Музыка';

  @override
  String get nasStatPhotos => 'Фото';

  @override
  String get nasStatTotal => 'Всего';

  @override
  String get nasStatVideos => 'Видео';

  @override
  String get nasTabFavorites => 'Избранное';

  @override
  String get nasTabFolders => 'Папки';

  @override
  String get nasTabHome => 'Главная';

  @override
  String get nasTabMusic => 'Музыка';

  @override
  String get nasTabPhotos => 'Фото';

  @override
  String get nasTabPlaylists => 'Плейлисты';

  @override
  String get nasTabVideos => 'Видео';

  @override
  String get nasSources => 'Источники медиа';

  @override
  String get nasAddSource => 'Добавить источник медиа';

  @override
  String get nasEditSource => 'Изменить источник медиа';

  @override
  String get nasRemoveSource => 'Удалить источник медиа';

  @override
  String nasRemoveSourceConfirm(Object name) {
    return 'Вы уверены, что хотите удалить источник медиа \'$name\'? Это удалит его конфигурацию без удаления удаленных файлов.';
  }

  @override
  String get nasNoSources => 'Источники медиа не настроены';

  @override
  String get nasNoSourcesDesc =>
      'Добавьте SFTP, SMB, WebDAV, Jellyfin или Emby, чтобы начать просмотр медиа.';

  @override
  String get nasSourceType => 'Тип источника';

  @override
  String get nasSourceName => 'Имя источника';

  @override
  String get nasProbe => 'Проверить соединение';

  @override
  String get nasProbeSuccess => 'Соединение успешно';

  @override
  String get nasProbeFailed => 'Сбой проверки соединения';

  @override
  String get nasEndpoint => 'Эндпоинт / URL';

  @override
  String get nasRootPath => 'Корневой путь';

  @override
  String get nasUsername => 'Имя пользователя';

  @override
  String get nasPassword => 'Пароль';

  @override
  String get nasDomain => 'Домен (необязательно)';

  @override
  String get nasAuthenticate => 'Аутентификация';

  @override
  String get nasAuthSuccess => 'Аутентификация успешна';

  @override
  String get nasAuthFailed => 'Сбой аутентификации';

  @override
  String get nasTabDownloads => 'Загрузки';

  @override
  String get nasNoDownloads => 'Нет задач загрузки';

  @override
  String get nasDownloadQueued => 'В очереди';

  @override
  String get nasDownloadDownloading => 'Скачивание';

  @override
  String get nasDownloadCompleted => 'Завершено';

  @override
  String get nasDownloadCancelled => 'Отменено';

  @override
  String get nasDownloadFailed => 'Сбой скачивания';

  @override
  String get nasRetryDownload => 'Повторить';

  @override
  String get nasCancelDownload => 'Отмена';

  @override
  String get nasOpenDownloadedFile => 'Открыть файл';

  @override
  String get nasQueue => 'Очередь воспроизведения';

  @override
  String get nasNoQueue => 'Очередь пуста';

  @override
  String get nasSpeed => 'Скорость';

  @override
  String get nasQuality => 'Качество';

  @override
  String get nasAudioTrack => 'Аудиодорожка';

  @override
  String get nasSubtitleTrack => 'Субтитры';

  @override
  String get nasRepeatOff => 'Повтор выкл';

  @override
  String get nasRepeatAll => 'Повторять все';

  @override
  String get nasRepeatOne => 'Повторять один трек';

  @override
  String get nasShuffle => 'Случайно';

  @override
  String get nasCast => 'Трансляция (Cast)';

  @override
  String get nasCastUnavailable => 'Нет доступных устройств трансляции';

  @override
  String get nasSlideshow => 'Слайд-шоу';

  @override
  String get nasByFolder => 'Папки';

  @override
  String get nasByArtist => 'Исполнители';

  @override
  String get nasByAlbum => 'Альбомы';

  @override
  String get nasAllTracks => 'Все треки';

  @override
  String get nasPlayAll => 'Воспроизвести все';

  @override
  String get nasPreviousPage => 'Назад';

  @override
  String get nasNextPage => 'Далее';

  @override
  String get nasClearScope => 'Вернуться ко всем';

  @override
  String get nasRenamePlaylist => 'Переименовать плейлист';

  @override
  String get nasRemoveFromPlaylist => 'Удалить из плейлиста';

  @override
  String get nasMoveUp => 'Переместить вверх';

  @override
  String get nasMoveDown => 'Переместить вниз';

  @override
  String get nasSshServer => 'SSH-сервер';

  @override
  String get nasSelectSshServer => 'Выбрать сохраненный SSH-сервер';

  @override
  String get nasQualityOriginal => 'Оригинал';

  @override
  String get nasQualityAuto => 'Авто';

  @override
  String get nasQuality4Mbps => '4 Мбит/с';

  @override
  String get nasQuality10Mbps => '10 Мбит/с';

  @override
  String get nasQuality20Mbps => '20 Мбит/с';

  @override
  String get nasCastDevices => 'Доступные устройства DLNA';

  @override
  String get nasCastDiscovering => 'Поиск устройств DLNA...';

  @override
  String get nasCastRelayingNotice =>
      'Ретрансляция потока через активное приложение. Держите Valhalla открытой.';

  @override
  String get nasCastStop => 'Остановить трансляцию';

  @override
  String get nasCastVolume => 'Громкость';

  @override
  String get nasCastRetry => 'Повторить поиск';

  @override
  String get nasInstallTitle => 'Развертывание медиасервера NAS';

  @override
  String get nasInstallProduct => 'Продукт';

  @override
  String get nasInstallMediaPath => 'Каталог медиа (Только чтение)';

  @override
  String get nasInstallDataRoot => 'Каталог данных и конфигурации';

  @override
  String get nasInstallPort => 'Порт';

  @override
  String get nasInstallBindAddress => 'Адрес привязки';

  @override
  String get nasInstallWebdavUser => 'Имя пользователя WebDAV';

  @override
  String get nasInstallWebdavPassword => 'Пароль WebDAV (мин. 12 символов)';

  @override
  String get nasInstallPreparePlan => 'Проверить план развертывания';

  @override
  String get nasInstallPlanTitle => 'Технический обзор и подтверждение';

  @override
  String get nasInstallBlockersTitle => 'Блокирующие факторы развертывания';

  @override
  String get nasInstallConfirmDeploy => 'Подтвердить и установить';

  @override
  String get nasInstallDeploying => 'Развертывание контейнера...';

  @override
  String get nasInstallSuccess => 'Успешно развернуто';

  @override
  String get nasInstallSuccessDesc =>
      'Служба запущена. Завершите начальную настройку сервера перед добавлением его как источника медиа.';

  @override
  String get nasInstallContainerId => 'ID контейнера';

  @override
  String get nasInstallEndpoint => 'Эндпоинт';

  @override
  String get nasUseSshTunnel => 'Использовать SSH-туннель';

  @override
  String get nasUseSshTunnelDesc =>
      'Маршрутизировать трафик через сохраненный SSH-сервер (напр. http://127.0.0.1:8096)';

  @override
  String get nasSshTunnelHint =>
      'Эндпоинт должен быть доступен с SSH-сервера, напр. http://127.0.0.1:8096';

  @override
  String get nasKeepEmptyPassword =>
      'Оставьте пустым для сохранения текущего пароля / токена';

  @override
  String get nasSourceNameRequired => 'Имя источника обязательно';

  @override
  String get nasInvalidEndpoint => 'Неверный URL или схема эндпоинта';

  @override
  String get nasSourceUnreachable =>
      'Не удается подключиться к источнику медиа';

  @override
  String get nasSshTunnelFailed => 'Сбой подключения к SSH-туннелю';

  @override
  String get nasOperationFailed => 'Операция не удалась';

  @override
  String get nasInstallStepCreateDir => 'Создать приватный каталог';

  @override
  String get nasInstallStepWriteCompose =>
      'Записать конфигурацию docker-compose.json';

  @override
  String get nasInstallStepWriteCreds => 'Записать приватные учетные данные';

  @override
  String get nasInstallStepPullImage =>
      'Загрузить закрепленный образ контейнера';

  @override
  String get nasInstallStepStartService => 'Запустить службу в контейнере';

  @override
  String get nasInstallStepCheckHttp => 'Проверить состояние HTTP службы';

  @override
  String get nasInstallBlockerDocker =>
      'На целевом сервере требуется Docker Engine';

  @override
  String get nasInstallBlockerCompose => 'Требуется плагин Docker Compose';

  @override
  String get nasInstallBlockerIdentity =>
      'Не удалось проверить подлинность целевого сервера';

  @override
  String get nasInstallBlockerTools =>
      'На целевом сервере отсутствуют необходимые утилиты (curl, ss, realpath)';

  @override
  String get nasInstallBlockerMedia =>
      'Каталог медиа не существует или недоступен для чтения';

  @override
  String get nasInstallBlockerParent =>
      'Родительский каталог для корневых данных недоступен для записи';

  @override
  String get nasInstallBlockerOverlap =>
      'Каталог медиа и каталог данных не могут пересекаться';

  @override
  String get nasInstallBlockerCollision =>
      'Целевой каталог данных уже существует или является симлинком';

  @override
  String get nasInstallBlockerPort =>
      'Выбранный порт уже используется на целевом сервере';

  @override
  String get nasInstallBlockerContainer =>
      'Контейнер с таким именем проекта уже существует';

  @override
  String get nasInstallBlockerImage =>
      'Не удалось проверить образ контейнера. Проверьте имя образа, сеть и архитектуру сервера, затем повторите.';

  @override
  String get nasInstallGuidanceTunnel =>
      'Привязка loopback (127.0.0.1) требует SSH-туннеля для удаленного доступа';

  @override
  String get nasInstallGuidanceTls =>
      'Публичную привязку рекомендуется защищать с помощью обратного прокси TLS';

  @override
  String get nasInstallGuidanceSetup =>
      'Завершите первоначальную настройку учетной записи администратора в браузере при первом запуске';

  @override
  String get nasInstallGuidanceReadOnly =>
      'Каталог медиа монтируется только для чтения для защиты ваших файлов';

  @override
  String get nasInstallGuidancePreserved =>
      'Каталог данных будет сохранен в случае сбоя для устранения неполадок';

  @override
  String get nasDownloadCompletedWithOpenError =>
      'Скачано (Не удалось открыть во внешнем приложении)';

  @override
  String get nasRetryOpen => 'Повторить открытие';

  @override
  String get nasExternalOpenFailed =>
      'Не удалось открыть файл во внешнем приложении';

  @override
  String get nasTitle => 'NAS Медиа';

  @override
  String get nasLoadMoreGroups => 'Загрузить больше групп';

  @override
  String get nasMetadataEnriching => 'Обогащение тегов музыки...';

  @override
  String nasMetadataEnrichingWithCount(int count) {
    return 'Обогащение тегов музыки ($count обработано)...';
  }

  @override
  String nasDownloading(String value) {
    return 'Скачивание $value…';
  }

  @override
  String get nasSubtitleNone => 'Нет';

  @override
  String get nasLibraryId => 'ID библиотеки';

  @override
  String get nasLibraryIdHint =>
      'По умолчанию: все (/), или укажите ID библиотеки';

  @override
  String nasScanPathRelativeHint(String value) {
    return 'Относительно корня источника ($value)';
  }

  @override
  String get nasSourceChangedError =>
      'Источник изменился во время настройки, сохранение отменено';

  @override
  String get nasInvalidLibraryId => 'Неверный ID библиотеки';

  @override
  String get startupFailed => 'Не удалось запустить приложение';

  @override
  String get startupFailedDesc =>
      'Во время запуска произошла непредвиденная ошибка. Вы можете повторить попытку или экспортировать журналы диагностики.';

  @override
  String get retryStartup => 'Повторить запуск';

  @override
  String get viewDiagnostics => 'Просмотр диагностики';

  @override
  String get exportDiagnostics => 'Экспорт диагностики';

  @override
  String diagnosticsExportSuccess(String path) {
    return 'Диагностика экспортирована в $path';
  }

  @override
  String get diagnosticsExportFailed => 'Не удалось экспортировать диагностику';

  @override
  String get diagnosticsTitle => 'Диагностика приложения';

  @override
  String get settingsDiagnostics => 'Диагностика и журналы';

  @override
  String get settingsDiagnosticsDesc =>
      'Просмотр и экспорт локальных очищенных журналов приложения';

  @override
  String get diagnosticsEmpty => 'Записи диагностики не найдены';

  @override
  String diagnosticsStorageError(String error) {
    return 'Ошибка хранилища диагностики: $error';
  }

  @override
  String diagnosticsIncidentNotice(String category) {
    return 'Зарегистрирован восстановимый инцидент: $category';
  }

  @override
  String get diagnosticsRefresh => 'Обновить журналы';

  @override
  String get nasInstallTaskTitle => 'Задача развертывания';

  @override
  String get nasInstallStagePreflight => 'Предварительная проверка';

  @override
  String get nasInstallStageReview => 'Проверка плана';

  @override
  String get nasInstallStageWriting => 'Запись конфигурации';

  @override
  String get nasInstallStagePulling => 'Загрузка образа';

  @override
  String get nasInstallStageStarting => 'Запуск контейнера';

  @override
  String get nasInstallStageHealth => 'Проверка работоспособности';

  @override
  String get nasInstallStageCleanup => 'Очистка';

  @override
  String get nasInstallStageSucceeded => 'Развертывание успешно';

  @override
  String get nasInstallStageFailed => 'Развертывание не удалось';

  @override
  String get nasInstallStageCancelled => 'Развертывание отменено';

  @override
  String get nasInstallStageNeedsInspection => 'Требуется проверка';

  @override
  String get nasInstallStageReconciling => 'Согласование состояния';

  @override
  String get nasInstallCancel => 'Отменить развертывание';

  @override
  String get nasInstallReconcile => 'Согласовать статус';

  @override
  String get nasInstallServerNotFound => 'Выбранный сервер не найден';

  @override
  String get nasInstallPortRangeError =>
      'Порт должен быть в диапазоне от 1 до 65535';

  @override
  String nasInstallElapsedTime(String time) {
    return 'Прошло: $time';
  }

  @override
  String get nasInstallLogTail => 'Недавние журналы';

  @override
  String get nasInstallCleanupCompleted => 'Очистка при откате завершена';

  @override
  String get nasInstallCleanupIncomplete => 'Очистка при откате не завершена';

  @override
  String get nasInstallNewDeployment => 'Новое развертывание';

  @override
  String get nasInstallBackEdit => 'Назад / Редактировать форму';

  @override
  String get nasInstallClose => 'Закрыть';

  @override
  String get nasInstallMediaPathHint =>
      'Монтирование bind только для чтения на хосте (напр. /mnt/media)';

  @override
  String get nasInstallDataRootHint =>
      'Приватный каталог данных и конфигурации (еще не должен существовать)';

  @override
  String get nasInstallBindAddressHint =>
      '127.0.0.1 для туннеля, 0.0.0.0 для локальной сети';

  @override
  String get nasInstallWebdavPasswordHint => 'Требуется не менее 12 символов';

  @override
  String get nasInstallTargetServer => 'Целевой сервер';

  @override
  String get nasInstallTargetImage => 'Целевой образ';

  @override
  String get nasInstallContainerName => 'Имя контейнера';

  @override
  String get nasInstallBindAndPort => 'Привязка и порт';

  @override
  String get nasInstallComposePreview => 'Предпросмотр docker-compose.json';

  @override
  String get nasInstallPlannedSteps => 'Запланированные шаги';

  @override
  String get nasInstallGuidanceNotes =>
      'Примечания и руководство по развертыванию';

  @override
  String get nasInstallNoLogsYet => 'Журналов пока нет';

  @override
  String get sftpPreviewTooLarge =>
      'Файл превышает лимит предпросмотра 1 МиБ. Скачайте и откройте его во внешнем приложении.';

  @override
  String get sftpSaveFailed =>
      'Не удалось сохранить файл. Проверьте разрешения или сетевое подключение.';

  @override
  String get sftpSaving => 'Сохранение...';

  @override
  String get nasInstallBlockerConnectionChanged =>
      'Подключение к целевому серверу изменилось; проверьте состояние перед продолжением';

  @override
  String get nasInstallBlockerCancelled =>
      'Развертывание отменено пользователем. Проверьте настройки и повторите при необходимости.';

  @override
  String get nasInstallBlockerInspectFailed =>
      'Не удалось опросить удаленный контейнер. Проверьте подключение или проверьте вручную.';

  @override
  String get nasInstallBlockerDeadlineExceeded =>
      'Время ожидания этапа развертывания истекло. Проверьте нагрузку на сервер или сеть и повторите.';

  @override
  String get nasInstallBlockerInterrupted =>
      'Развертывание было прервано; проверьте состояние удаленного сервера перед продолжением.';

  @override
  String get nasInstallBlockerHealthTimeout =>
      'Служба запущена, но время проверки HTTP истекло. Проверьте журналы службы или доступность порта.';

  @override
  String get nasInstallBlockerReconciliationFailed =>
      'Согласование не удалось. Проверьте статус контейнера вручную или начните новое развертывание.';

  @override
  String get nasInstallBlockerRemoteInspectionRequired =>
      'Статус удаленного контейнера неясен. Требуется ручная проверка и согласование.';

  @override
  String get nasInstallBlockerServiceExited =>
      'Процесс контейнера завершился преждевременно. Проверьте журналы на наличие ошибок конфигурации или прав.';

  @override
  String get nasInstallBlockerWriteFailed =>
      'Не удалось записать файлы развертывания на целевой сервер. Проверьте свободное место и права.';

  @override
  String get nasInstallBlockerPlanStale =>
      'План развертывания устарел. Пожалуйста, повторите предварительные проверки.';

  @override
  String get nasInstallBlockerOwnershipChanged =>
      'Существующий контейнер не был создан этим приложением. Проверьте вручную во избежание перезаписи.';

  @override
  String get nasInstallBlockerSshRequired =>
      'Требуется активное SSH-соединение с целевым сервером.';

  @override
  String get nasInstallBlockerReconciliationRequired =>
      'Удаленное состояние отличается от локального. Выполните согласование перед продолжением.';

  @override
  String get nasInstallBlockerFailed =>
      'При развертывании произошла ошибка. Проверьте журналы и повторите.';

  @override
  String get nasInstallBlockerBusy =>
      'Задача установки уже выполняется. Пожалуйста, проверьте ход текущей задачи.';

  @override
  String get nasInstallBlockerStateSaveFailed =>
      'Не удалось сохранить состояние развертывания. Проверьте свободное место и права доступа.';

  @override
  String get nasInstallBlockerCommandResultUnknown =>
      'Результат удаленной команды неизвестен. Выполните проверку только для чтения вместо прямого повтора.';

  @override
  String get nasInstallBlockerPreflightFailed =>
      'Предварительная проверка окружения не удалась. Устраните блокирующие факторы перед продолжением.';

  @override
  String serverDeleteFailed(String error) {
    return 'Не удалось удалить сервер: $error';
  }

  @override
  String get chatRunSettingsAgentMode => 'Режим агента';

  @override
  String get chatRunSettingsApprovalPolicy =>
      'Локальная политика подтверждения';

  @override
  String get chatRunSettingsExtraSettings => 'Дополнительные настройки';

  @override
  String get chatPermissionAutoAllowSafeDesc =>
      'Автоматически разрешает заведомо безопасные операции; запрашивает подтверждение, если безопасность не может быть гарантирована.';

  @override
  String chatRunSettingsSaveFailed(String error) {
    return 'Не удалось применить параметры запуска: $error';
  }

  @override
  String get chatMessageCopied => 'Сообщение скопировано в буфер обмена';

  @override
  String get copy => 'Копировать';

  @override
  String get rename => 'Переименовать';

  @override
  String get refresh => 'Обновить';

  @override
  String get sessionTitle => 'Название сессии';

  @override
  String get chatSettingsStale => 'Устарело';

  @override
  String get chatSettingsAvailableAfterFirstMessage =>
      'Настройки доступны после первого сообщения';

  @override
  String get chatReimportAsCopy => 'Импортировать как копию';

  @override
  String get chatSearchCommandsHint => 'Поиск команд или навыков...';

  @override
  String get chatCommandsTab => 'Команды';

  @override
  String get chatSkillsTab => 'Навыки';

  @override
  String get chatAccountAndQuotaTitle => 'Аккаунт и квота';

  @override
  String get chatAccountSectionTitle => 'Аккаунт';

  @override
  String get chatAccountNotProvided => 'Сведения об аккаунте отсутствуют';

  @override
  String get chatAccountKind => 'Тип';

  @override
  String get chatAccountLabel => 'Метка';

  @override
  String get chatAccountPlan => 'План';

  @override
  String get chatAccountEmail => 'Email';

  @override
  String get chatAccountUpdatedAt => 'Обновлено';

  @override
  String get chatQuotaSectionTitle => 'Квота и статус';

  @override
  String get chatStatusSourceNote => 'Необработанный вывод /status агента';

  @override
  String get chatStatusNotQueried => 'Статус еще не запрашивался';

  @override
  String get chatQueryStatusAction => 'Запросить статус (/status)';

  @override
  String get chatQueryStatusUnavailable =>
      'Запрос статуса недоступен в текущей сессии';

  @override
  String get chatAttachmentMissing =>
      'Файл вложения отсутствует или недоступен';

  @override
  String get chatViewModeList => 'Список';

  @override
  String get chatViewModeCards => 'Карточки';

  @override
  String get chatViewModeGrid => 'Сетка';

  @override
  String get chatRemoteBrowserTitle => 'Удаленная рабочая область';

  @override
  String get chatSelectDirectory => 'Выбрать каталог';

  @override
  String chatAttachSelectedFiles(int count) {
    return 'Прикрепить выбранные ($count)';
  }

  @override
  String get chatNoFilesFound => 'Файлы не найдены';

  @override
  String get chatRootDirectory => 'Корень';

  @override
  String get chatSelectThisDirectory => 'Использовать этот каталог';

  @override
  String get chatAgentVersion => 'Версия агента';

  @override
  String get chatParentDirectory => 'Родительский каталог';

  @override
  String get chatSearchFilesHint => 'Поиск файлов...';

  @override
  String get chatCommandsEmpty => 'Агент не предоставил slash-команд';

  @override
  String get chatSkillsEmpty => 'Агент не предоставил навыков';

  @override
  String get chatFileUnsupported => 'Тип файла не поддерживается для вложения';

  @override
  String get chatStatusNotProvided =>
      'Запрос статуса не поддерживается агентом';

  @override
  String get sessionRecoveryReconnecting => 'Переподключение...';

  @override
  String get sessionRecoverySyncing => 'Синхронизация вывода...';

  @override
  String get sessionRecoveryIncomplete =>
      'Часть вывода не удалось восстановить';

  @override
  String get sessionRecoveryFailed => 'Восстановление не удалось';

  @override
  String get sessionRecoveryRetry => 'Повторить';

  @override
  String get dashboardUpdatesPaused => 'Обновления приостановлены';

  @override
  String get chatSettingsIndependentModelUnavailable =>
      'Каталог моделей CLI в данный момент недоступен. Модели могут быть кэшированы или ограничены версией CLI; вы также можете ввести имя модели вручную.';

  @override
  String get chatSettingsModelCatalogNote =>
      'Модели запрашиваются с сервера приложений CLI с использованием существующего входа. Каталог может быть кэширован или ограничен версией; вы можете обновить его или перейти к ручному вводу.';

  @override
  String get chatModelCatalogError403 =>
      'Доступ к каталогу моделей CLI запрещен (403). Проверьте вход CLI и сетевое соединение, или введите имя модели вручную.';

  @override
  String chatModelCatalogErrorGeneric(String error) {
    return 'Ошибка каталога моделей: $error';
  }

  @override
  String get chatModelAuthorizeButton => 'Авторизовать каталог моделей';

  @override
  String get chatModelAuthorizeConfirmTitle => 'Авторизовать каталог моделей';

  @override
  String get chatModelAuthorizeConfirmMessage =>
      'Это запустит авторизацию в браузере для каталога моделей на целевом хосте/контейнере. Ваш существующий вход Codex и сессии терминала останутся нетронутыми. Продолжить?';

  @override
  String get chatModelAuthorizing => 'Авторизация через браузер...';

  @override
  String get chatModelAuthorizeCancel => 'Отменить авторизацию';

  @override
  String get chatCommandsFirstTurnNote =>
      'Slash-команды будут объявлены средой агента после инициализации сессии, без необходимости предварительного диалога; черновики не создают сессии автоматически.';

  @override
  String get chatCommandsClientActionRunSettings => 'Параметры запуска';

  @override
  String get chatCommandsClientActionWorkingDirectory => 'Рабочий каталог';

  @override
  String get chatCommandsClientActionsSection => 'Локальные действия';

  @override
  String get chatRunSettingsModelSourceCatalog => 'Список моделей';

  @override
  String get chatRunSettingsModelSourceCustom => 'Ручной ввод';

  @override
  String get chatRunSettingsCustomModelHint => 'Введите ID модели';

  @override
  String get chatRunSettingsCustomModelNotice =>
      'Введенные вручную имена моделей не проверяются и отправляются напрямую среде агента, которая может отклонить неподдерживаемые модели.';

  @override
  String get chatRunSettingsCustomModelEmptyError =>
      'Имя модели не может быть пустым';

  @override
  String get chatRunSettingsCustomModelInvalidError =>
      'Имя модели должно быть не более 256 символов без пробелов и управляющих символов';

  @override
  String get chatCommandsDraftPreviewNotice =>
      'Команды проверены для текущей версии адаптера. Выбор вставляет текст в черновик; Отправка инициализирует сессию по требованию и выполнит команду.';

  @override
  String get chatCommandsDiscoveryFailed =>
      'Не удалось обнаружить команды или навыки';

  @override
  String get chatAuthWaitingForBrowser => 'Ожидание авторизации в браузере...';

  @override
  String get chatAuthBrowserLaunchFailed =>
      'Не удалось открыть внешний браузер. Откройте повторно или скопируйте ссылку авторизации ниже.';

  @override
  String get chatAuthReopenBrowser => 'Открыть браузер снова';

  @override
  String get chatAuthCopyLink => 'Копировать ссылку';

  @override
  String get chatAuthManualCallback => 'Ручной колбэк';

  @override
  String get chatAuthManualCallbackTitle => 'Введите URL колбэка авторизации';

  @override
  String get chatAuthManualCallbackDesc =>
      'Вставьте полный URL перенаправления (http://127.0.0.1:PORT/...?code=...&state=...) из браузера для завершения авторизации. Необработанные коды авторизации не принимаются.';

  @override
  String get chatAuthCallbackInputLabel => 'URL колбэка';

  @override
  String get chatAuthCallbackInputHint =>
      'http://127.0.0.1:PORT/...?code=...&state=...';

  @override
  String get chatAuthCallbackInvalidError =>
      'Неверный формат URL колбэка или сбой доставки';

  @override
  String get agentAuthAgYNotice =>
      'Antigravity ACP требует официальной авторизации учетной записи отдельно от входа в терминал CLI.';

  @override
  String get chatAuthDiscoveryPrompt =>
      'Для этого шага требуется аутентификация ACP. Переподключитесь и запросите авторизацию для продолжения.';

  @override
  String get chatRequestAuthButton => 'Запросить аутентификацию';

  @override
  String get agentActionAcpLogin => 'Вход ACP';

  @override
  String get agentActionCliLogin => 'Вход CLI';

  @override
  String get agentAgyAcpSignInRequired =>
      'Учетные данные ACP отсутствуют (требуется вход в ACP)';

  @override
  String get agentAgyAcpCredentialsSaved =>
      'Учетные данные ACP сохранены (не проверено)';

  @override
  String get chatAuthMethodUnavailable =>
      'Выбранный метод аутентификации недоступен.';

  @override
  String get chatAuthConnectionExpired =>
      'Срок действия соединения для аутентификации истек. Пожалуйста, попробуйте снова.';

  @override
  String get chatAuthCallbackDeliveryFailed =>
      'Не удалось доставить колбэк авторизации на сервер.';

  @override
  String get agentTargetChangedNotice =>
      'Целевой сервер изменился. Пожалуйста, откройте управление агентами на текущем сервере заново.';

  @override
  String get agentAgyAuthCheckUnavailable =>
      'Проверка аутентификации Antigravity недоступна';

  @override
  String get agentAgyAuthCheckInvalid =>
      'Ответ проверки аутентификации Antigravity недействителен';

  @override
  String get sftpDownloadDisconnected => 'Скачивание отключено';

  @override
  String get sftpDownloadPermissionDenied => 'В доступе отказано';

  @override
  String get sftpDownloadNotFound => 'Удаленный файл не найден';

  @override
  String get sftpDownloadTimeout => 'Время ожидания скачивания истекло';

  @override
  String get sftpDownloadLocalSpace =>
      'Недостаточно места на локальном накопителе';

  @override
  String get sftpDownloadLocalIo => 'Сбой записи в локальное хранилище';

  @override
  String get sftpDownloadIncomplete => 'Скачивание не завершено';

  @override
  String get transferStatusWaitingConnection => 'Ожидание подключения';

  @override
  String get chatAuthCallbackListenerFailed =>
      'Не удалось запустить локальный слушатель колбэка авторизации. Повторите попытку аутентификации.';

  @override
  String get settingsExperimentalFeatures => 'Экспериментальные функции';

  @override
  String get settingsExperimentalFeaturesDesc =>
      'Попробуйте предварительные и экспериментальные возможности';

  @override
  String get settingsExperimentalCliChatTitle => 'Умный чат CLI';

  @override
  String get settingsExperimentalCliChatDesc =>
      'Включить интерфейс чата для агентов командной строки';

  @override
  String get settingsExperimentalDialogClose => 'Закрыть';

  @override
  String get settingsExperimentalSaveFailed =>
      'Не удалось обновить настройки экспериментальных функций';

  @override
  String get settingsExperimentalNasTitle => 'NAS Медиа';

  @override
  String get settingsExperimentalNasDesc =>
      'Включить медиатеку, сканирование папок и воспроизведение аудио';

  @override
  String get settingsLanguageSaveFailed =>
      'Не удалось обновить настройки языка';

  @override
  String get settingsAboutPrivacy => 'О приложении и конфиденциальность';

  @override
  String get privacyPolicyTitle => 'Политика конфиденциальности';

  @override
  String get privacyPolicyDescription => 'Использование данных и ваш выбор';

  @override
  String get privacyContactTitle => 'Контакт по вопросам конфиденциальности';

  @override
  String get privacyCopyEmail => 'Копировать адрес почты';

  @override
  String get privacyEmailCopied => 'Адрес почты скопирован';

  @override
  String get privacyOnlineVersion => 'Открыть онлайн-версию';

  @override
  String get privacyLinkFailed =>
      'Не удалось открыть ссылку. Адрес почты можно скопировать.';

  @override
  String get privacyLoadFailed =>
      'Не удалось загрузить политику. Откройте онлайн-версию.';

  @override
  String get privacyVersionUnknown => 'Версия недоступна';

  @override
  String get aboutWebsite => 'Официальный сайт';

  @override
  String get aboutLicense => 'Лицензия приложения';

  @override
  String get aboutThirdPartyLicenses =>
      'Лицензии сторонних компонентов с открытым кодом';

  @override
  String get aboutLicenseSummary =>
      'Оригинальные материалы Valhalla доступны для некоммерческого использования по лицензии PolyForm Noncommercial 1.0.0. Коммерческое использование за пределами разрешений лицензии требует отдельного разрешения. Сторонние компоненты сохраняют собственные лицензии. Использование регулируется полными условиями ниже.';

  @override
  String get aboutCopyrightNotice => 'Уведомления об авторских правах';

  @override
  String get aboutLicenseLoadFailed =>
      'Не удалось загрузить лицензию. Свяжитесь с norns.soft@gmail.com.';

  @override
  String get aboutLinkFailed =>
      'Не удалось открыть ссылку. Откройте https://norns.cc.cd в браузере.';

  @override
  String get downloadReveal => 'Показать в Проводнике';

  @override
  String get downloadRevealFailed =>
      'Не удалось открыть папку загрузки. Возможно, она перемещена или удалена.';

  @override
  String settingsKnownHostsSubtitle(int count) {
    return '$count доверенных ключей хостов';
  }

  @override
  String get settingsKnownHostsEmpty => 'Доверенные ключи хостов не найдены';

  @override
  String get settingsKnownHostsDialogTitle => 'Известные ключи хостов';

  @override
  String get settingsHostKeyRevoke => 'Отозвать';

  @override
  String get settingsHostKeyRevokeConfirmTitle => 'Отозвать ключ хоста';

  @override
  String settingsHostKeyRevokeConfirmMessage(String hostPort) {
    return 'Отозвать ключ хоста для $hostPort? Активные SSH-подключения к этому хосту будут разорваны, и при следующем подключении потребуется повторная проверка ключа.';
  }

  @override
  String get settingsHostKeyFingerprintCopied =>
      'Отпечаток ключа хоста скопирован в буфер обмена';

  @override
  String get settingsHostKeyRevoked => 'Ключ хоста отозван';

  @override
  String get settingsClearStorageSubtitle =>
      'Очистить сохраненные пароли и приватные ключи для выбранных серверов';

  @override
  String get settingsClearStorageDialogTitle => 'Сброс учетных данных серверов';

  @override
  String get settingsClearStorageDesc =>
      'Выберите серверы для удаления сохраненных SSH-паролей и приватных ключей из безопасного хранилища. Конфигурация серверов и история чатов не будут удалены.';

  @override
  String get settingsClearStorageNoServers => 'Нет доступных серверов';

  @override
  String get settingsClearStorageSelectAll => 'Выбрать все';

  @override
  String get settingsClearStorageDeselectAll => 'Снять выбор';

  @override
  String get settingsClearStorageConfirmTitle =>
      'Подтверждение сброса учетных данных';

  @override
  String settingsClearStorageConfirmMessage(int count) {
    return 'Вы уверены, что хотите удалить учетные данные для $count выбранных серверов? Активные подключения к ним будут немедленно завершены.';
  }

  @override
  String settingsClearStorageAction(int count) {
    return 'Очистить выбранные ($count)';
  }

  @override
  String get settingsClearStorageSuccess =>
      'Учетные данные выбранных серверов успешно очищены';

  @override
  String get settingsClearStorageError =>
      'Не удалось очистить учетные данные некоторых серверов. Повторите попытку.';

  @override
  String get settingsDefaultAcpAgent => 'ACP-агент по умолчанию';

  @override
  String get settingsDefaultAcpAgentSubtitle =>
      'Агент по умолчанию для ACP-чата на этом сервере';

  @override
  String get settingsDefaultCliAgent => 'CLI-агент по умолчанию';

  @override
  String get settingsDefaultCliAgentSubtitle =>
      'Агент по умолчанию для CLI-чата на этом сервере';

  @override
  String get settingsDefaultAgentAutomatic =>
      'Автоматически (первый доступный)';

  @override
  String get settingsDefaultAgentSelectTitle => 'Выбор агента по умолчанию';

  @override
  String get settingsDefaultAgentNoServer => 'Сервер не выбран';

  @override
  String get settingsDefaultAgentNoAgents =>
      'Для этого сервера нет настроенных агентов';

  @override
  String get settingsDefaultAgentSaveFailed =>
      'Не удалось обновить настройку агента по умолчанию';

  @override
  String get dockerViewGroupContainers => 'Контейнеры';

  @override
  String get dockerViewGroupProjects => 'Проекты Compose';

  @override
  String get dockerProjectActionStart => 'Запустить проект';

  @override
  String get dockerProjectActionStop => 'Остановить проект';

  @override
  String get dockerProjectActionRestart => 'Перезапустить проект';

  @override
  String get dockerProjectConfirmStopTitle => 'Остановить проект Compose';

  @override
  String get dockerProjectConfirmRestartTitle => 'Перезапустить проект Compose';

  @override
  String dockerProjectConfirmMessage(String action, String project, int count) {
    return 'Вы уверены, что хотите выполнить действие \"$action\" для проекта \"$project\"? Будет затронуто следующее количество контейнеров: $count:';
  }

  @override
  String dockerProjectActionSuccess(String project, String action) {
    return 'Проект \"$project\": действие \"$action\" успешно выполнено';
  }

  @override
  String dockerProjectActionPartial(
    String project,
    String action,
    int failedCount,
  ) {
    return 'Проект \"$project\": действие \"$action\" завершено с ошибками ($failedCount)';
  }

  @override
  String get dockerNoProjects => 'Проекты Docker Compose не найдены';

  @override
  String get dockerMountsTitle => 'Точки монтирования';

  @override
  String get dockerMountReadOnly => 'Только чтение';

  @override
  String get dockerMountReadWrite => 'Чтение и запись';

  @override
  String get sftpBookmarksTitle => 'Закладки каталогов';

  @override
  String get sftpNoBookmarks => 'Нет сохраненных закладок';

  @override
  String get sftpAddBookmark => 'Добавить в закладки';

  @override
  String get sftpRemoveBookmark => 'Удалить закладку';

  @override
  String get sftpCurrentDirectory => 'Текущий каталог';

  @override
  String get sftpSelectMode => 'Режим выбора';

  @override
  String sftpSelectedCount(int count) {
    return 'Выбрано: $count';
  }

  @override
  String get sftpSelectAll => 'Выбрать все';

  @override
  String get sftpDeselectAll => 'Снять выбор';

  @override
  String get sftpBatchCopy => 'Копировать';

  @override
  String get sftpBatchMove => 'Переместить';

  @override
  String get sftpBatchDeleteConfirmTitle => 'Подтверждение удаления группы';

  @override
  String sftpBatchDeleteConfirmMessage(int count) {
    return 'Вы действительно хотите удалить $count выбранных элементов?';
  }

  @override
  String get sftpBatchDeleteNonEmptyNotice =>
      'Примечание: непустые каталоги не могут быть удалены рекурсивно и будут пропущены.';

  @override
  String get sftpBatchCopyConfirmTitle => 'Подтверждение копирования группы';

  @override
  String sftpBatchCopyConfirmMessage(int count, String directory) {
    return 'Скопировать $count выбранных элементов в \"$directory\"?';
  }

  @override
  String get sftpBatchMoveConfirmTitle => 'Подтверждение перемещения группы';

  @override
  String sftpBatchMoveConfirmMessage(int count, String directory) {
    return 'Переместить $count выбранных элементов в \"$directory\"?';
  }

  @override
  String get sftpBatchResultsTitle => 'Результаты пакетной операции';

  @override
  String get sftpBatchOutcomeSkipped =>
      'Пропущено (файл существует или не поддерживается)';

  @override
  String get sftpBatchTargetRestricted =>
      'Нельзя выбрать текущий или дочерний каталог в качестве целевого';

  @override
  String get sftpSelectCurrentDir => 'Выбрать этот каталог';

  @override
  String sftpBatchOperationSuccess(int count) {
    return 'Успешно обработано элементов: $count';
  }

  @override
  String get configMigrationTitle => 'Резервное копирование и перенос настроек';

  @override
  String get configExportTitle => 'Экспорт конфигурации';

  @override
  String get configExportSubtitle =>
      'Экспорт серверов, агентов, команд, закладок и настроек в JSON';

  @override
  String get configExportDialogTitle => 'Экспорт конфигурации Valhalla';

  @override
  String get configExportSuccess => 'Конфигурация успешно экспортирована';

  @override
  String configExportError(String error) {
    return 'Ошибка экспорта конфигурации: $error';
  }

  @override
  String get configImportTitle => 'Импорт конфигурации';

  @override
  String get configImportSubtitle =>
      'Импорт конфигурации из файла резервной копии JSON';

  @override
  String get configBackupTooLarge =>
      'Файл резервной копии превышает максимальный размер (8 МБ)';

  @override
  String get configImportPreviewTitle => 'Предпросмотр импорта конфигурации';

  @override
  String get configImportPreviewDesc =>
      'Проверьте данные перед импортом. Существующие элементы будут сохранены и объединены.';

  @override
  String configImportServersCount(int count) {
    return 'Серверы ($count)';
  }

  @override
  String configImportAgentsCount(int count) {
    return 'Агенты ($count)';
  }

  @override
  String configImportCommandsCount(int count) {
    return 'Быстрые команды ($count)';
  }

  @override
  String configImportBookmarksCount(int count) {
    return 'Закладки ($count)';
  }

  @override
  String get configImportSecretWarning =>
      'Пользовательские команды могут содержать конфиденциальные сценарии. Пароли, приватные ключи и доверенные отпечатки хостов не передаются.';

  @override
  String get configImportGlobalPreferences =>
      'Импортировать глобальные настройки приложения';

  @override
  String get configImportGlobalPreferencesDesc =>
      'Перезаписывает текущие параметры темы, терминала и навигации';

  @override
  String get configImportConfirmAction => 'Подтвердить импорт';

  @override
  String get configImportSuccess => 'Конфигурация успешно импортирована';

  @override
  String get configImportErrorTitle => 'Недействительный файл резервной копии';

  @override
  String configImportErrorGeneric(String error) {
    return 'Ошибка импорта конфигурации: $error';
  }

  @override
  String get configImportErrorCopyDetails =>
      'Скопировать диагностические данные';

  @override
  String get configImportErrorCopied =>
      'Диагностические данные скопированы в буфер обмена';

  @override
  String get configImportErrorUnsupportedVersion =>
      'Неподдерживаемый формат или версия резервной копии';

  @override
  String get configImportErrorMalformed =>
      'Поврежденный или неверный JSON конфигурации';

  @override
  String get aboutRepository => 'Репозиторий GitHub';

  @override
  String get updateCheckTitle => 'Проверить обновления';

  @override
  String get updateChecking => 'Проверка обновлений...';

  @override
  String get updateCheckNow => 'Проверить сейчас';

  @override
  String get updateUpToDate => 'Установлена последняя версия';

  @override
  String updateInstalledVersion(String version) {
    return 'Установлено: v$version';
  }

  @override
  String updateAvailableBadge(String version) {
    return 'Доступна новая версия: v$version';
  }

  @override
  String get updateViewUpdate => 'Посмотреть обновление';

  @override
  String updateLastChecked(String time) {
    return 'Последняя проверка: $time';
  }

  @override
  String get updateNeverChecked => 'Никогда не проверялось';

  @override
  String get updateAutoCheckTitle => 'Автоматическая проверка обновлений';

  @override
  String get updateAutoCheckSubtitle =>
      'Ежедневно проверять обновления при активном приложении';

  @override
  String get updateAutoCheckSaveFailed =>
      'Не удалось сохранить настройки автоматической проверки';

  @override
  String get updateDialogTitle => 'Обновление ПО';

  @override
  String updateCurrentVersion(String version) {
    return 'Текущая: $version';
  }

  @override
  String updateTargetVersion(String version) {
    return 'Новейшая: v$version';
  }

  @override
  String updateBuildNumber(String build) {
    return 'Сборка $build';
  }

  @override
  String updateCommit(String commit) {
    return 'Коммит: $commit';
  }

  @override
  String get updateArtifactDetails => 'Установочный пакет';

  @override
  String updateArtifactName(String name) {
    return 'Файл: $name';
  }

  @override
  String updateArtifactSize(String size) {
    return 'Размер: $size';
  }

  @override
  String updateArtifactHash(String hash) {
    return 'Хеш SHA-256: $hash';
  }

  @override
  String get updateCopyHash => 'Скопировать хеш SHA-256';

  @override
  String get updateHashCopied => 'Хеш SHA-256 скопирован в буфер обмена';

  @override
  String get updateCopyCommit => 'Скопировать хеш коммита';

  @override
  String get updateCommitCopied => 'Хеш коммита скопирован в буфер обмена';

  @override
  String get updateReleaseNotes => 'Примечания к выпуску';

  @override
  String get updateNoReleaseNotes => 'Примечания к выпуску отсутствуют.';

  @override
  String get updateNoArtifactForPlatform =>
      'Нет пакета прямой установки для этой платформы/архитектуры.';

  @override
  String get updateOpenReleasePage => 'Открыть страницу выпусков на GitHub';

  @override
  String get updateDownload => 'Скачать обновление';

  @override
  String updateDownloading(String progress) {
    return 'Загрузка... $progress%';
  }

  @override
  String get updatePause => 'Пауза';

  @override
  String get updateResume => 'Продолжить';

  @override
  String get updateRetry => 'Повторить';

  @override
  String get updateDownloadPaused => 'Загрузка приостановлена';

  @override
  String get updateDownloadCompleted => 'Загрузка завершена и проверена';

  @override
  String get updateInstall => 'Установить обновление';

  @override
  String get updateRevealInFolder => 'Показать в папке';

  @override
  String get updateOpenFolder => 'Открыть папку с загрузками';

  @override
  String get updateRetryInstall => 'Повторить установку';

  @override
  String get updateDesktopInstructions =>
      'Распакуйте загруженный архив и замените файлы приложения после его закрытия. Никогда не перезаписывайте работающую программу.';

  @override
  String get updateCopyErrorDetails => 'Скопировать детали ошибки';

  @override
  String get updateErrorCopied => 'Детали ошибки скопированы в буфер обмена';

  @override
  String get updateErrorRateLimited =>
      'Превышен лимит запросов к API GitHub. Пожалуйста, повторите попытку позже.';

  @override
  String get updateErrorNetwork =>
      'Сетевое соединение не удалось. Проверьте подключение к интернету.';

  @override
  String get updateErrorManifest =>
      'Манифест обновления недействителен или отсутствуют метаданные.';

  @override
  String get updateErrorIntegrity =>
      'Проверка целостности загрузки не удалась. Контрольная сумма не совпадает.';

  @override
  String get updateErrorSignatureMismatch =>
      'Несоответствие подписи установки: пакет подписан другим ключом. Невозможно перезаписать приложение с другой подписью. Во избежание потери данных никогда не удаляйте приложение и не очищайте данные.';

  @override
  String get updateErrorPermissionRequired =>
      'Требуется разрешение на установку. Разрешите установку неизвестных приложений в системных настройках и нажмите «Повторить установку».';

  @override
  String get updateErrorPermission =>
      'Отказано в доступе к хранилищу или системе.';

  @override
  String get updateErrorPackageInvalid =>
      'Путь к пакету или идентификатор недействительны.';

  @override
  String get updateErrorStoreInstall =>
      'Это приложение установлено из магазина приложений. Обновите его через магазин.';

  @override
  String get updateErrorPlatform =>
      'Не удалось открыть или запустить установщик.';

  @override
  String get updateErrorGeneric =>
      'Сбой операции обновления. Повторите попытку или перейдите к релизам на GitHub.';
}
