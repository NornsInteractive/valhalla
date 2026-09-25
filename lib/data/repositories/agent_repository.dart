import '../models/agent_profile.dart';
import '../models/builtin_agent_preset.dart';
import '../models/chat_session.dart';
import '../storage/local_storage_service.dart';

class AgentRepository {
  final LocalStorageService _localStorage;
  bool _migrationInProgress = false;
  bool _backfillInProgress = false;
  bool _acpRepairInProgress = false;
  AgentRepository(this._localStorage);

  List<AgentProfile> getAll(String serverId) {
    _localStorage.claimLegacyOwnership(serverId);
    var all = _localStorage.getAgents();
    final authRepaired = all.map((profile) {
      final preset = _presetForAgentId(profile.id);
      if (preset == null) return profile;
      final oldVersionCheck =
          profile.cliCommand == preset.cliCommand &&
          profile.loginCheckCommand == '${preset.cliCommand} --version';
      final oldLogin =
          profile.cliCommand == 'claude' &&
          profile.loginCommand == 'claude login';
      final oldCodexAdapter =
          preset.id == 'builtin-codex' &&
          profile.acpInstallCommand ==
              'npm install -g @zed-industries/codex-acp';
      if (!oldCodexAdapter &&
          !oldVersionCheck &&
          !oldLogin &&
          !(profile.cliCommand == 'agy' && profile.loginCommand == null)) {
        return profile;
      }
      final json = profile.toJson();
      if (oldCodexAdapter) json['acpInstallCommand'] = preset.acpInstallCommand;
      if (oldVersionCheck) json['loginCheckCommand'] = preset.loginCheckCommand;
      if (oldLogin ||
          (profile.cliCommand == 'agy' && profile.loginCommand == null)) {
        json['loginCommand'] = preset.loginCommand;
      }
      return AgentProfile.fromJson(json);
    }).toList();
    if (authRepaired.indexed.any(
      (entry) => !identical(entry.$2, all[entry.$1]),
    )) {
      all = authRepaired;
      _localStorage.saveAgents(all);
    }
    if (!_migrationInProgress &&
        !_localStorage.isAgentMigrationComplete(serverId) &&
        _localStorage.legacyOwnershipServerId == serverId &&
        _localStorage.hasLegacyAgentSource()) {
      _migrationInProgress = true;
      final migrated = _migrate(serverId);
      all = [...all, ...migrated];
      _localStorage.saveAgents(all);
      _localStorage.markAgentMigrationComplete(serverId);
      _migrationInProgress = false;
    }

    final backfilled = _backfillInstallCommands(all);
    if (backfilled != null) {
      all = backfilled;
    }

    final repaired = _repairAcpCommands(all);
    if (repaired != null) {
      all = repaired;
    }

    return all.where((p) => p.serverId == serverId).toList();
  }

  AgentProfile? find(String serverId, String agentId) =>
      getAll(serverId).where((p) => p.id == agentId).firstOrNull;

  Future<void> save(AgentProfile profile) async {
    final all = _localStorage.getAgents();
    final index = all.indexWhere(
      (p) => p.serverId == profile.serverId && p.id == profile.id,
    );
    if (index >= 0) {
      all[index] = profile;
    } else {
      all.add(profile);
    }
    await _localStorage.saveAgents(all);
  }

  Future<void> delete(String serverId, String agentId) async {
    await _localStorage.saveAgents(
      _localStorage
          .getAgents()
          .where((p) => !(p.serverId == serverId && p.id == agentId))
          .toList(),
    );
  }

  List<AgentProfile> _migrate(String serverId) {
    final ids = _localStorage
        .getLegacyAgentTypes()
        .map((e) => kLegacyAgentTypeToId[e.toLowerCase()])
        .whereType<String>()
        .toSet();
    return ids.map((id) {
      final preset = kBuiltinAgentPresets[id];
      return AgentProfile(
        id: id,
        serverId: serverId,
        name: preset?.name ?? id,
        description: preset?.description ?? 'Built-in agent',
        cliCommand: preset?.cliCommand ?? id,
        acpCommand: preset?.acpCommand,
        installCommand: preset?.cliInstallCommand,
        acpInstallCommand: preset?.acpInstallCommand,
        loginCheckCommand: preset?.loginCheckCommand,
        loginCommand: preset?.loginCommand,
      );
    }).toList();
  }

  /// 为内置 Agent 补齐缺失的安装/登录命令（一次性、幂等）。
  ///
  /// 老版本迁移或手动添加的 profile 没有安装命令，导致「未检测到安装」时无法
  /// 一键安装。这里仅对 id 命中内置预设的 profile **补空值**：
  /// - 绝不覆盖用户已填写的命令；
  /// - 绝不触碰 `custom-*` 及任何非内置 id；
  /// - 通过存储标记保证只执行一次；无改动时不写盘。
  ///
  /// 返回新的列表；无需改动时返回 null（调用方保持原列表）。
  List<AgentProfile>? _backfillInstallCommands(List<AgentProfile> all) {
    if (all.isEmpty ||
        _backfillInProgress ||
        _localStorage.isAgentInstallBackfillComplete()) {
      return null;
    }

    _backfillInProgress = true;
    var changed = false;
    final updated = all.map((profile) {
      final preset = _presetForAgentId(profile.id);
      if (preset == null) return profile;

      String? fill(String? current, String? fallback) {
        if (current != null && current.trim().isNotEmpty) return current;
        return fallback;
      }

      final installCommand = fill(
        profile.installCommand,
        preset.cliInstallCommand,
      );
      final acpInstallCommand = fill(
        profile.acpInstallCommand,
        preset.acpInstallCommand,
      );
      final loginCheckCommand = fill(
        profile.loginCheckCommand,
        preset.loginCheckCommand,
      );
      final loginCommand = fill(profile.loginCommand, preset.loginCommand);

      if (installCommand == profile.installCommand &&
          acpInstallCommand == profile.acpInstallCommand &&
          loginCheckCommand == profile.loginCheckCommand &&
          loginCommand == profile.loginCommand) {
        return profile;
      }

      changed = true;
      return AgentProfile(
        id: profile.id,
        serverId: profile.serverId,
        name: profile.name,
        description: profile.description,
        cliCommand: profile.cliCommand,
        acpCommand: profile.acpCommand,
        installCommand: installCommand,
        acpInstallCommand: acpInstallCommand,
        loginCheckCommand: loginCheckCommand,
        loginCommand: loginCommand,
        createdAt: profile.createdAt,
        updatedAt: profile.updatedAt,
      );
    }).toList();

    _backfillInProgress = false;

    if (changed) {
      _localStorage.saveAgents(updated);
    }
    _localStorage.markAgentInstallBackfillComplete();
    return changed ? updated : null;
  }

  /// 曾经写入过的错误 ACP 启动命令字面量。
  ///
  /// 早期版本为这些内置 Agent 编造了不存在的参数（ACP 适配器根本不接受参数，
  /// `agy` 也没有 ACP 模式），导致探测与启动必然失败。
  static const _legacyAcpCommands = {
    'builtin-claude-code': 'claude-code-acp --stdio',
    'builtin-codex': 'codex-acp --stdio',
    'builtin-opencode': 'opencode --acp',
    'builtin-agy': 'agy --acp',
  };

  /// 修正历史数据里错误的 ACP 启动命令（一次性、幂等）。
  ///
  /// 仅在存量值**精确等于**已知错误字面量时改写为当前预设值，因此：
  /// - 用户自行填写或修改过的 ACP 命令**绝不会**被覆盖；
  /// - 绝不触碰 `custom-*` 及任何非内置 id；
  /// - 通过独立存储标记保证只执行一次；无改动时不写盘。
  ///
  /// 返回新的列表；无需改动时返回 null（调用方保持原列表）。
  List<AgentProfile>? _repairAcpCommands(List<AgentProfile> all) {
    if (all.isEmpty ||
        _acpRepairInProgress ||
        _localStorage.isAgentAcpRepairComplete()) {
      return null;
    }

    _acpRepairInProgress = true;
    var changed = false;
    final updated = all.map((profile) {
      final preset = _presetForAgentId(profile.id);
      if (preset == null) return profile;

      final bogus = _legacyAcpCommands[preset.id];
      if (bogus == null || profile.acpCommand != bogus) return profile;

      changed = true;
      return AgentProfile(
        id: profile.id,
        serverId: profile.serverId,
        name: profile.name,
        description: profile.description,
        cliCommand: profile.cliCommand,
        acpCommand: preset.acpCommand,
        installCommand: profile.installCommand,
        acpInstallCommand: profile.acpInstallCommand,
        loginCheckCommand: profile.loginCheckCommand,
        loginCommand: profile.loginCommand,
        createdAt: profile.createdAt,
        updatedAt: profile.updatedAt,
      );
    }).toList();

    _acpRepairInProgress = false;

    if (changed) {
      _localStorage.saveAgents(updated);
    }
    _localStorage.markAgentAcpRepairComplete();
    return changed ? updated : null;
  }

  /// 解析内置预设：支持 `builtin-codex` 与表单去重后的 `builtin-codex-<suffix>`。
  /// 非内置（含 `custom-*`）一律返回 null。
  BuiltinAgentPreset? _presetForAgentId(String agentId) {
    final exact = kBuiltinAgentPresets[agentId];
    if (exact != null) return exact;
    for (final entry in kBuiltinAgentPresets.entries) {
      if (agentId.startsWith('${entry.key}-')) return entry.value;
    }
    return null;
  }
}
