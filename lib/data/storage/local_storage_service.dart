import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/server_profile.dart';
import '../models/host_key_entry.dart';
import '../models/quick_command.dart';
import '../models/chat_session.dart';
import '../models/agent_profile.dart';
import '../models/chat_run_settings.dart';
import '../models/chat_launch_preference.dart';
import '../models/nas_media.dart';
import '../models/nas_source.dart';

/// 本地持久化服务 (SharedPreferences 快速存取)
class LocalStorageService {
  Map<String, dynamic>? getChatDraft(String key) {
    final raw = _prefs.getString('valhalla_chat_draft_v1::$key');
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> saveChatDraft(String key, Map<String, dynamic> value) async {
    await _prefs.setString('valhalla_chat_draft_v1::$key', jsonEncode(value));
  }

  Future<void> clearChatDraft(String key) async {
    await _prefs.remove('valhalla_chat_draft_v1::$key');
  }

  bool getShareAgentSessions(String serverId) =>
      _prefs.getBool('valhalla_share_agent_sessions::$serverId') ?? false;
  Future<void> setShareAgentSessions(String serverId, bool value) async {
    await _prefs.setBool('valhalla_share_agent_sessions::$serverId', value);
  }

  String? get legacyOwnershipServerId =>
      _prefs.getString('valhalla_legacy_owner_v2');
  void claimLegacyOwnership(String serverId) {
    if (legacyOwnershipServerId != null) return;
    for (final key in [_keySessions, _keyAgents]) {
      final raw = _prefs.getString(key);
      if (raw != null) _prefs.setString('${key}_before_owner_v2', raw);
    }
    _prefs.setString('valhalla_legacy_owner_v2', serverId);
  }

  static const _keyServers = 'valhalla_servers_v1';
  static const _keyHostKeys = 'valhalla_host_keys_v1';
  static const _keyCommands = 'valhalla_quick_commands_v1';
  static const _keySessions = 'valhalla_chat_sessions_v1';
  static const _keyActiveServerId = 'valhalla_active_server_id_v1';
  static const _keyAgents = 'valhalla_agents_v1';
  static const _keyAgentMigration = 'valhalla_agents_migration_v1_complete';
  static const _keyAgentInstallBackfill =
      'valhalla_agents_install_backfill_v1_complete';
  static const _keyAgentAcpRepair = 'valhalla_agents_acp_repair_v1_complete';

  /// ACP 会话 id 映射：`<serverId>::<agentId>` → sessionId。
  ///
  /// 持久化的目的是让「重连后恢复同一个 ACP 会话」跨 App 重启也成立。
  static const _keyAcpSessions = 'valhalla_acp_sessions_v1';

  /// 终端是否用 tmux 承载会话。默认 false：普通 SSH PTY。
  static const _keyTerminalUseTmux = 'valhalla_terminal_use_tmux_v1';

  /// 终端字体大小（9..24）。
  static const _keyTerminalFontSize = 'valhalla_terminal_font_size_v1';

  /// 启动时自动连接的模式：`fixed` 或 `lastConnected`。
  static const _keyAutoConnectMode = 'valhalla_auto_connect_mode_v1';

  /// 「固定默认 SSH」模式下用户指定的配置 id。
  static const _keyAutoConnectServerId = 'valhalla_auto_connect_server_id_v1';

  /// 「记住最后一次连接」模式下最近一次成功连接的配置 id。
  static const _keyLastConnectedServerId =
      'valhalla_last_connected_server_id_v1';

  /// 外观模式：`system` / `light` / `dark` / `amoled`。
  static const _keyThemeMode = 'valhalla_theme_mode_v1';

  /// 主题色（强调色）名称。
  static const _keyAccentColor = 'valhalla_accent_color_v1';
  static const _keyDashboardQuickSections =
      'valhalla_dashboard_quick_sections_v1';

  /// 界面语言代码（如 `zh` / `en`）。
  static const _keyLocale = 'valhalla_locale_v1';

  /// 手机端底部导航显示的页面名称列表。空列表表示隐藏底栏。
  static const _keyBottomNavigation = 'valhalla_bottom_navigation_v1';

  /// App 创建主界面时默认打开的页面名称。
  static const _keyStartupSection = 'valhalla_startup_section_v1';

  /// CLI 历史会话首次及向上加载的消息条数。
  static const _keyCliHistoryPageSize = 'valhalla_cli_history_page_size_v1';
  static const _keyChatRunDefaults = 'valhalla_chat_run_defaults_v1';
  static const _keyCliRunSettings = 'valhalla_cli_run_settings_v1';
  static const _keyNasScanConfigs = 'valhalla_nas_scan_configs_v1';
  static const _keyNasLastScans = 'valhalla_nas_last_scans_v1';
  static const _keyNasOpenPolicies = 'valhalla_nas_open_policies_v1';
  static const _keyNasMediaCacheBytes = 'valhalla_nas_media_cache_bytes_v1';
  static const _keyNasThumbnailCacheBytes =
      'valhalla_nas_thumbnail_cache_bytes_v1';
  static const _keyChatLaunchPreferences =
      'valhalla_chat_launch_preferences_v1';
  static const _keyChatLastSessions = 'valhalla_chat_last_sessions_v1';

  /// 远端文件列表的排序字段：`name` / `size` / `date`。
  static const _keyFileSortKey = 'valhalla_file_sort_key_v1';

  /// 远端文件列表是否升序。
  static const _keyFileSortAscending = 'valhalla_file_sort_asc_v1';

  /// 桌面窗口尺寸与坐标
  static const _keyWindowWidth = 'valhalla_window_width_v1';
  static const _keyWindowHeight = 'valhalla_window_height_v1';
  static const _keyWindowOriginX = 'valhalla_window_origin_x_v1';
  static const _keyWindowOriginY = 'valhalla_window_origin_y_v1';

  final SharedPreferences _prefs;

  LocalStorageService(this._prefs);

  static Future<LocalStorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStorageService(prefs);
  }

  ChatRunSettings getChatRunDefault(String serverId, String agentId) {
    final map = _jsonMap(_keyChatRunDefaults);
    final raw = map['$serverId::$agentId'];
    return raw is Map
        ? ChatRunSettings.fromJson(Map<String, dynamic>.from(raw))
        : const ChatRunSettings();
  }

  Future<void> saveChatRunDefault(
    String serverId,
    String agentId,
    ChatRunSettings settings,
  ) => _saveJsonEntry(
    _keyChatRunDefaults,
    '$serverId::$agentId',
    settings.toJson(),
  );

  ChatRunSettings getCliRunSettings(
    String serverId,
    String agentId,
    String? sessionId,
  ) {
    final map = _jsonMap(_keyCliRunSettings);
    final key = '$serverId::$agentId::${sessionId ?? 'draft'}';
    final raw = map[key];
    return raw is Map
        ? ChatRunSettings.fromJson(Map<String, dynamic>.from(raw))
        : getChatRunDefault(serverId, agentId);
  }

  Future<void> saveCliRunSettings(
    String serverId,
    String agentId,
    String? sessionId,
    ChatRunSettings settings,
  ) async {
    await _saveJsonEntry(
      _keyCliRunSettings,
      '$serverId::$agentId::${sessionId ?? 'draft'}',
      settings.toJson(),
    );
    await saveChatRunDefault(serverId, agentId, settings);
  }

  Map<String, dynamic> _jsonMap(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveJsonEntry(
    String storageKey,
    String entryKey,
    Object value,
  ) async {
    final map = _jsonMap(storageKey)..[entryKey] = value;
    await _prefs.setString(storageKey, jsonEncode(map));
  }

  NasScanConfig getNasScanConfig(String serverId) {
    final raw = _jsonMap(_keyNasScanConfigs)[serverId];
    return raw is Map
        ? NasScanConfig.fromJson(Map<String, dynamic>.from(raw))
        : const NasScanConfig();
  }

  List<NasSource> getNasSources() {
    final raw = _prefs.getString('valhalla_nas_sources_v1');
    if (raw == null) {
      // Keep legacy IDs so indexes, favorites and resume positions survive.
      return getServers()
          .map(
            (server) => NasSource(
              id: server.id,
              name: server.name,
              type: NasSourceType.sftp,
              sshServerId: server.id,
            ),
          )
          .toList();
    }
    return (jsonDecode(raw) as List)
        .map(
          (value) =>
              NasSource.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList();
  }

  Map<String, dynamic>? getNasInstallTask() {
    final raw = _prefs.getString('valhalla_nas_install_task_v1');
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveNasInstallTask(Map<String, dynamic> summary) async {
    if (!await _prefs.setString(
      'valhalla_nas_install_task_v1',
      jsonEncode(summary),
    )) {
      throw StateError('Could not persist NAS installation state');
    }
  }

  Future<void> saveNasSources(List<NasSource> sources) => _prefs.setString(
    'valhalla_nas_sources_v1',
    jsonEncode(sources.map((e) => e.toJson()).toList()),
  );

  String? getNasSelectedSourceId() =>
      _prefs.getString('valhalla_nas_selected_source_v1');
  Future<void> saveNasSelectedSourceId(String id) =>
      _prefs.setString('valhalla_nas_selected_source_v1', id);

  Future<void> saveNasScanConfig(String serverId, NasScanConfig config) =>
      _saveJsonEntry(_keyNasScanConfigs, serverId, config.toJson());

  DateTime? getNasLastScan(String serverId) {
    final raw = _jsonMap(_keyNasLastScans)[serverId] as String?;
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> saveNasLastScan(String serverId, DateTime value) =>
      _saveJsonEntry(_keyNasLastScans, serverId, value.toIso8601String());

  NasOpenPolicy getNasOpenPolicy(NasMediaKind kind) {
    final raw = _jsonMap(_keyNasOpenPolicies)[kind.name] as String?;
    return NasOpenPolicy.values
            .where((value) => value.name == raw)
            .firstOrNull ??
        NasOpenPolicy.inApp;
  }

  Future<void> saveNasOpenPolicy(NasMediaKind kind, NasOpenPolicy policy) =>
      _saveJsonEntry(_keyNasOpenPolicies, kind.name, policy.name);

  int getNasMediaCacheBytes() =>
      _prefs.getInt(_keyNasMediaCacheBytes) ?? 2 * 1024 * 1024 * 1024;

  Future<void> saveNasMediaCacheBytes(int value) => _prefs.setInt(
    _keyNasMediaCacheBytes,
    value.clamp(0, 20 * 1024 * 1024 * 1024),
  );

  int getNasThumbnailCacheBytes() =>
      _prefs.getInt(_keyNasThumbnailCacheBytes) ?? 256 * 1024 * 1024;

  Future<void> saveNasThumbnailCacheBytes(int value) => _prefs.setInt(
    _keyNasThumbnailCacheBytes,
    value.clamp(0, 2 * 1024 * 1024 * 1024),
  );

  // --- Servers ---
  List<ServerProfile> getServers() {
    final raw = _prefs.getString(_keyServers);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ServerProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveServers(List<ServerProfile> servers) async {
    final raw = jsonEncode(servers.map((e) => e.toJson()).toList());
    await _prefs.setString(_keyServers, raw);
  }

  String? getActiveServerId() => _prefs.getString(_keyActiveServerId);

  Future<void> setActiveServerId(String? id) async {
    if (id == null) {
      await _prefs.remove(_keyActiveServerId);
    } else {
      await _prefs.setString(_keyActiveServerId, id);
    }
  }

  // --- Host Keys ---
  Map<String, HostKeyEntry> getHostKeys() {
    final raw = _prefs.getString(_keyHostKeys);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map(
        (key, val) =>
            MapEntry(key, HostKeyEntry.fromJson(val as Map<String, dynamic>)),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> saveHostKey(HostKeyEntry entry) async {
    final keys = getHostKeys();
    keys[entry.hostPort] = entry;
    final raw = jsonEncode(keys.map((k, v) => MapEntry(k, v.toJson())));
    await _prefs.setString(_keyHostKeys, raw);
  }

  // --- Quick Commands ---
  List<QuickCommand> getQuickCommands() {
    final raw = _prefs.getString(_keyCommands);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => QuickCommand.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveQuickCommands(List<QuickCommand> commands) async {
    final raw = jsonEncode(commands.map((e) => e.toJson()).toList());
    await _prefs.setString(_keyCommands, raw);
  }

  // --- Chat Sessions ---
  /// Original migration source, retained unchanged after SQLite takes ownership.
  String get rawChatSessions => _prefs.getString(_keySessions) ?? '[]';

  List<ChatSession> getChatSessions() {
    final raw = _prefs.getString(_keySessions);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ChatSession.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveChatSessions(List<ChatSession> sessions) async {
    final raw = jsonEncode(sessions.map((e) => e.toJson()).toList());
    await _prefs.setString(_keySessions, raw);
  }

  /// Returns the agent reference of every stored session for migration.
  ///
  /// Prefers the stable `agentId`; falls back to the legacy `agentType` string
  /// (including values no longer represented by [AgentType]). Legacy values are
  /// mapped by the single table in `chat_session.dart`.
  List<String> getLegacyAgentTypes() {
    final raw = _prefs.getString(_keySessions);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map((e) {
            final agentId = e['agentId']?.toString() ?? '';
            if (agentId.isNotEmpty) return agentId;
            return e['agentType']?.toString() ?? '';
          })
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  bool hasLegacyAgentSource() {
    final raw = _prefs.getString(_keySessions);
    if (raw == null || raw.isEmpty) return false;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  List<AgentProfile> getAgents() {
    final raw = _prefs.getString(_keyAgents);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => AgentProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAgents(List<AgentProfile> agents) async {
    await _prefs.setString(
      _keyAgents,
      jsonEncode(agents.map((e) => e.toJson()).toList()),
    );
  }

  bool isAgentMigrationComplete(String serverId) =>
      _prefs.getBool(_keyAgentMigration) ?? false;

  Future<void> markAgentMigrationComplete(String serverId) async {
    await _prefs.setBool(_keyAgentMigration, true);
  }

  bool isAgentInstallBackfillComplete() =>
      _prefs.getBool(_keyAgentInstallBackfill) ?? false;

  Future<void> markAgentInstallBackfillComplete() async {
    await _prefs.setBool(_keyAgentInstallBackfill, true);
  }

  bool isAgentAcpRepairComplete() =>
      _prefs.getBool(_keyAgentAcpRepair) ?? false;

  Future<void> markAgentAcpRepairComplete() async {
    await _prefs.setBool(_keyAgentAcpRepair, true);
  }

  // --- Terminal Settings ---

  /// 终端是否用 tmux 承载会话。
  ///
  /// 缺键即 false：tmux 是 opt-in，首次安装与升级用户都默认走普通 SSH PTY。
  bool getUseTmuxForTerminal() => _prefs.getBool(_keyTerminalUseTmux) ?? false;

  Future<void> setUseTmuxForTerminal(bool enabled) async {
    await _prefs.setBool(_keyTerminalUseTmux, enabled);
  }

  /// 终端字体大小。
  ///
  /// 缺键或存了不合法的值（越界 / 类型不对）时返回 [fallback]（默认 13，
  /// 与 xterm 的默认字号一致），绝不把脏数据交给渲染层。
  int getTerminalFontSize({int fallback = 13}) {
    final value = _prefs.getInt(_keyTerminalFontSize);
    if (value == null || value < 9 || value > 24) return fallback;
    return value;
  }

  Future<void> setTerminalFontSize(int value) async {
    await _prefs.setInt(_keyTerminalFontSize, value.clamp(9, 24));
  }

  // --- Auto Connect ---

  /// 自动连接模式。
  ///
  /// 缺键或存了无法识别的值时返回 [fallback]（默认 `lastConnected`）——
  /// 存储层不认识新模式枚举，所以由调用方把合法值表传进来，而不是在这里
  /// 硬编码一份会漂移的清单。
  String getAutoConnectMode({String fallback = 'lastConnected'}) =>
      _prefs.getString(_keyAutoConnectMode) ?? fallback;

  Future<void> setAutoConnectMode(String mode) async {
    await _prefs.setString(_keyAutoConnectMode, mode);
  }

  /// 「固定默认 SSH」指定的配置 id；null 表示尚未指定。
  String? getAutoConnectServerId() => _prefs.getString(_keyAutoConnectServerId);

  Future<void> setAutoConnectServerId(String? id) async {
    if (id == null) {
      await _prefs.remove(_keyAutoConnectServerId);
    } else {
      await _prefs.setString(_keyAutoConnectServerId, id);
    }
  }

  // --- Appearance ---

  /// 外观模式名；缺键时返回 [fallback]。
  ///
  /// 与 [getAutoConnectMode] 同理：合法值清单属于上层枚举，
  /// 存储层不硬编码，避免两边漂移。
  String getThemeMode({String fallback = 'system'}) =>
      _prefs.getString(_keyThemeMode) ?? fallback;

  Future<void> setThemeMode(String mode) async {
    await _prefs.setString(_keyThemeMode, mode);
  }

  /// 主题色名；缺键时返回 [fallback]。
  String getAccentColor({String fallback = 'cyberEmerald'}) =>
      _prefs.getString(_keyAccentColor) ?? fallback;

  Future<void> setAccentColor(String color) async {
    await _prefs.setString(_keyAccentColor, color);
  }

  String? getThemeAccentColor(String mode) =>
      _prefs.getString('valhalla_accent_color_v2::$mode');

  Future<void> setThemeAccentColor(String mode, String colorHex) async {
    await _prefs.setString('valhalla_accent_color_v2::$mode', colorHex);
  }

  List<String>? getDashboardQuickSections() =>
      _prefs.getStringList(_keyDashboardQuickSections);

  Future<void> setDashboardQuickSections(List<String> sections) async {
    await _prefs.setStringList(_keyDashboardQuickSections, sections);
  }

  /// 界面语言代码；缺键时返回 [fallback]。
  String getLocale({String fallback = 'system'}) =>
      _prefs.getString(_keyLocale) ?? fallback;

  Future<void> setLocale(String languageCode) async {
    await _prefs.setString(_keyLocale, languageCode);
  }

  /// Agent defaults are server-scoped and mode-scoped. Missing means first eligible.
  String? getDefaultAgentId(String serverId, {required bool cli}) => _prefs
      .getString('valhalla_default_agent_${cli ? 'cli' : 'acp'}::$serverId');

  Future<void> setDefaultAgentId(
    String serverId,
    String? agentId, {
    required bool cli,
  }) async {
    final key = 'valhalla_default_agent_${cli ? 'cli' : 'acp'}::$serverId';
    if (agentId == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, agentId);
    }
  }

  String _chatLaunchKey(String serverId, String agentId, {required bool cli}) =>
      '$serverId::${cli ? 'cli' : 'acp'}::$agentId';

  ChatLaunchPreference getChatLaunchPreference(
    String serverId,
    String agentId, {
    required bool cli,
  }) {
    final raw = _jsonMap(
      _keyChatLaunchPreferences,
    )[_chatLaunchKey(serverId, agentId, cli: cli)];
    return raw is Map
        ? ChatLaunchPreference.fromJson(Map<String, dynamic>.from(raw))
        : const ChatLaunchPreference();
  }

  Future<void> saveChatLaunchPreference(
    String serverId,
    String agentId,
    ChatLaunchPreference preference, {
    required bool cli,
  }) => _saveJsonEntry(
    _keyChatLaunchPreferences,
    _chatLaunchKey(serverId, agentId, cli: cli),
    preference.toJson(),
  );

  String? getLastChatSessionId(
    String serverId,
    String agentId, {
    required bool cli,
  }) =>
      _jsonMap(_keyChatLastSessions)[_chatLaunchKey(
            serverId,
            agentId,
            cli: cli,
          )]
          as String?;

  Future<void> saveLastChatSessionId(
    String serverId,
    String agentId,
    String? sessionId, {
    required bool cli,
  }) async {
    final key = _chatLaunchKey(serverId, agentId, cli: cli);
    final values = _jsonMap(_keyChatLastSessions);
    if (sessionId == null) {
      values.remove(key);
    } else {
      values[key] = sessionId;
    }
    await _prefs.setString(_keyChatLastSessions, jsonEncode(values));
  }

  String getContainerShell(String serverId, String containerName) =>
      _prefs.getString(
            'valhalla_container_shell::$serverId::${Uri.encodeComponent(containerName)}',
          ) ==
          'sh'
      ? 'sh'
      : 'bash';

  Future<void> setContainerShell(
    String serverId,
    String containerName,
    String shell,
  ) async {
    if (shell != 'bash' && shell != 'sh') {
      throw ArgumentError.value(shell, 'shell');
    }
    await _prefs.setString(
      'valhalla_container_shell::$serverId::${Uri.encodeComponent(containerName)}',
      shell,
    );
  }

  /// 缺键返回 null，以便上层区分「尚未配置」与用户明确选择空列表。
  List<String>? getBottomNavigationSections() {
    // Read-through migration: preserve the old value as a rollback source.
    final raw = _prefs.getStringList(_keyBottomNavigation);
    if (_prefs.getBool('valhalla_navigation_acp_v2') != true &&
        raw?.join(',') == 'dashboard,cliChat,docker,files') {
      return ['dashboard', 'aiChat', 'docker', 'files'];
    }
    return raw;
  }

  Future<void> setBottomNavigationSections(List<String> sections) async {
    await _prefs.setStringList(_keyBottomNavigation, sections);
    await _prefs.setBool('valhalla_navigation_acp_v2', true);
  }

  String? getStartupSection() => _prefs.getString(_keyStartupSection);

  Future<void> setStartupSection(String section) async {
    await _prefs.setString(_keyStartupSection, section);
  }

  int getCliHistoryPageSize({int fallback = 10}) =>
      _prefs.getInt(_keyCliHistoryPageSize) ?? fallback;

  Future<void> setCliHistoryPageSize(int value) async {
    await _prefs.setInt(_keyCliHistoryPageSize, value);
  }

  // --- File List Sorting ---

  /// 文件列表排序字段名；缺键时返回 [fallback]。
  String getFileSortKey({String fallback = 'name'}) =>
      _prefs.getString(_keyFileSortKey) ?? fallback;

  Future<void> setFileSortKey(String key) async {
    await _prefs.setString(_keyFileSortKey, key);
  }

  /// 文件列表是否升序；默认 true。
  bool getFileSortAscending() => _prefs.getBool(_keyFileSortAscending) ?? true;

  Future<void> setFileSortAscending(bool ascending) async {
    await _prefs.setBool(_keyFileSortAscending, ascending);
  }

  /// 最近一次成功连接的配置 id；null 表示还没有成功连接过。
  String? getLastConnectedServerId() =>
      _prefs.getString(_keyLastConnectedServerId);

  Future<void> setLastConnectedServerId(String? id) async {
    if (id == null) {
      await _prefs.remove(_keyLastConnectedServerId);
    } else {
      await _prefs.setString(_keyLastConnectedServerId, id);
    }
  }

  // --- ACP Sessions ---

  /// 组装会话存储键，避免不同服务器/Agent 之间互相覆盖。
  static String acpSessionKey(String serverId, String agentId) =>
      '$serverId::$agentId';

  Map<String, String> _getAcpSessions() {
    final raw = _prefs.getString(_keyAcpSessions);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((key, value) => MapEntry(key, value.toString()));
    } catch (_) {
      return {};
    }
  }

  String? getAcpSessionId(String serverId, String agentId) =>
      _getAcpSessions()[acpSessionKey(serverId, agentId)];

  Future<void> saveAcpSessionId(
    String serverId,
    String agentId,
    String sessionId,
  ) async {
    final sessions = _getAcpSessions();
    sessions[acpSessionKey(serverId, agentId)] = sessionId;
    await _prefs.setString(_keyAcpSessions, jsonEncode(sessions));
  }

  /// 清除某个 Agent 的会话 id。
  ///
  /// 新建会话后若旧 id 仍留在存储里，下次连接会去 load 一个已经不存在
  /// 的会话，白白多两次失败的往返。
  Future<void> clearAcpSessionId(String serverId, String agentId) async {
    final sessions = _getAcpSessions();
    if (sessions.remove(acpSessionKey(serverId, agentId)) == null) return;
    await _prefs.setString(_keyAcpSessions, jsonEncode(sessions));
  }

  // --- Window Bounds (Desktop) ---
  Future<void> saveWindowBounds({
    required double width,
    required double height,
    double? x,
    double? y,
  }) async {
    await _prefs.setDouble(_keyWindowWidth, width);
    await _prefs.setDouble(_keyWindowHeight, height);
    if (x != null) {
      await _prefs.setDouble(_keyWindowOriginX, x);
    } else {
      await _prefs.remove(_keyWindowOriginX);
    }
    if (y != null) {
      await _prefs.setDouble(_keyWindowOriginY, y);
    } else {
      await _prefs.remove(_keyWindowOriginY);
    }
  }

  Map<String, double?>? getWindowBounds() {
    final width = _prefs.getDouble(_keyWindowWidth);
    final height = _prefs.getDouble(_keyWindowHeight);
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return {
      'width': width,
      'height': height,
      'x': _prefs.getDouble(_keyWindowOriginX),
      'y': _prefs.getDouble(_keyWindowOriginY),
    };
  }
}
