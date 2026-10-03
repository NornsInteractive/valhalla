import 'package:flutter/foundation.dart';

/// 一个内置 ACP Agent 的预设定义。
///
/// 这是**编译期常量**，不是用户数据：预设描述我们对上游官方安装方式的既有
/// 知识，运行时不可变，因此**不序列化**、不写入本地存储。`AgentProfile` 才是
/// 持久化实体——新增或迁移 Agent 时把预设值**拷贝**进 profile 即完成固化。
///
/// 若某条命令为 null，表示该环节无需（或无法）通过 shell 自动完成。
@immutable
class BuiltinAgentPreset {
  /// 稳定标识，如 `builtin-codex`。与 `kLegacyAgentTypeToId` 的取值一致。
  final String id;
  final String name;
  final String description;

  /// CLI 探测命令（`command -v <cliCommand>`）。
  final String cliCommand;

  /// ACP 启动命令。为 null 表示该 Agent **没有**可用的 ACP 模式，
  /// 只能作为纯 CLI 使用。
  final String? acpCommand;

  /// 安装 CLI 的命令；null 表示无官方非交互安装方式。
  final String? cliInstallCommand;

  /// 安装 ACP 组件的命令。仅当 ACP 与 CLI 来自**不同**包时才填写；
  /// 为 null 表示 ACP 组件随 CLI 一并安装完成。
  final String? acpInstallCommand;

  /// 登录状态探测命令；null 表示不做登录检查。
  final String? loginCheckCommand;

  /// 非交互登录命令；null 表示登录需人工在远端交互完成。
  final String? loginCommand;

  const BuiltinAgentPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.cliCommand,
    this.acpCommand,
    this.cliInstallCommand,
    this.acpInstallCommand,
    this.loginCheckCommand,
    this.loginCommand,
  });
}

/// 内置 Agent 预设的**唯一真相来源**。
///
/// 迁移（`AgentRepository._migrate`）、安装命令回填与表单预设填充都只依赖此表，
/// 绝不在别处重复字面量，避免行为漂移。
///
/// 命令来源核实记录（2026-09-14，通过 `npm view <pkg> version/bin`、`npm pack`
/// 解包读 README，以及官方文档核实）：
///
/// - `@anthropic-ai/claude-code` 存在；`@zed-industries/claude-code-acp`（0.16.2）
///   提供 `claude-code-acp` 可执行文件。其 README 的启动方式为
///   `ANTHROPIC_API_KEY=sk-... claude-code-acp`——**没有 `--stdio` 参数**。
/// - `@openai/codex` 存在；`@zed-industries/codex-acp`（0.16.0）提供 `codex-acp`
///   可执行文件。其 README 的启动方式为 `OPENAI_API_KEY=sk-... codex-acp`——
///   **没有 `--stdio` 参数**（早期版本曾误加，会报
///   `error: unexpected argument '--stdio' found`）。
/// - `opencode-ai`（1.18.30）提供 `opencode` 可执行文件。官方文档
///   （opencode.ai/docs/acp）配置为 `command: "opencode", args: ["acp"]`，
///   即 **`opencode acp` 子命令**，不是 `--acp` 参数。
/// - Antigravity CLI 官方安装脚本为 `https://antigravity.google/cli/install.sh`；
///   ACP 使用独立的官方 `agy_acp_server.par`，不是 `agy --acp`。
///   2026-10-02 核对 ACP Registry 的 `antigravity-acp` 1.2.1 分发元数据。
/// - 注意：无 scope 的 `codex-acp` / `claude-code-acp` npm 包并非官方发布，勿改用。
/// - Antigravity 通过交互启动 `agy` 完成 OAuth；没有登录状态子命令。
const Map<String, BuiltinAgentPreset> kBuiltinAgentPresets = {
  'builtin-claude-code': BuiltinAgentPreset(
    id: 'builtin-claude-code',
    name: 'Claude CodeX',
    description: 'Anthropic ACP Protocol · High Reasoning',
    cliCommand: 'claude',
    acpCommand: 'claude-code-acp',
    cliInstallCommand: 'npm install -g @anthropic-ai/claude-code',
    acpInstallCommand: 'npm install -g @zed-industries/claude-code-acp',
    loginCheckCommand: 'claude auth status --json',
    loginCommand: 'claude auth login',
  ),
  'builtin-codex': BuiltinAgentPreset(
    id: 'builtin-codex',
    name: 'OpenAI Codex',
    description: 'OpenAI ACP Agent · Coding & Scripting',
    cliCommand: 'codex',
    acpCommand: 'codex-acp',
    cliInstallCommand: 'npm install -g @openai/codex',
    acpInstallCommand: 'npm install -g @agentclientprotocol/codex-acp',
    loginCheckCommand: 'codex login status',
    loginCommand: 'codex login',
  ),
  'builtin-opencode': BuiltinAgentPreset(
    id: 'builtin-opencode',
    name: 'OpenCode ACP',
    description: 'Open-Source Native ACP Agent · Multi-model',
    cliCommand: 'opencode',
    acpCommand: 'opencode acp',
    cliInstallCommand: 'npm install -g opencode-ai',
    loginCheckCommand: 'opencode --version',
    loginCommand: 'opencode auth login',
  ),
  'builtin-agy': BuiltinAgentPreset(
    id: 'builtin-agy',
    name: 'Antigravity AGY',
    description: 'Google Antigravity · Official ACP server & CLI',
    cliCommand: 'agy',
    acpCommand: 'agy_acp_server.par',
    acpInstallCommand: kAntigravityAcpInstallCommand,
    loginCheckCommand: kAntigravityLoginCheckCommand,
    loginCommand: 'agy',
    cliInstallCommand:
        'curl -fsSL https://antigravity.google/cli/install.sh | bash',
  ),
};

/// Read-only credential readiness, not a token-validity/entitlement check.
/// Official ACP keeps its own credentials; never read or export token content.
const kAntigravityLoginCheckCommand =
    r'''python3 -c 'import json,os,pathlib,sys; '''
    r'''h=pathlib.Path(os.environ.get("GEMINI_HOME") or str(pathlib.Path.home()/".gemini")).expanduser(); '''
    r'''p=h/"antigravity-acp"; s=p/"settings.json"; '''
    r'''v=json.loads(s.read_text()) if s.is_file() else {}; '''
    r'''a=v.get("auth",{}).get("type"); '''
    r'''f=p/("acp_business_token.json" if a=="oauth-business" else "acp_token.json"); '''
    r'''saved=f.is_file() and os.access(f,os.R_OK); '''
    r'''state="saved" if saved else "unknown" if sys.platform=="darwin" or a in ("gemini-api-key","agent-platform","vertex-ai","gateway") else "missing"; '''
    r'''print(json.dumps({"scope":"antigravity-acp","state":state,"authType":a,"credentialDirectory":str(p),"home":str(pathlib.Path.home())}))' ''';

const kAntigravityAcpInstallCommand =
    r"""bash -c 'set -eu; """
    r'case "$(uname -s)" in Linux) platform=linux ;; Darwin) platform=macos ;; *) echo "ACP_INSTALL_OS_UNSUPPORTED" >&2; exit 1 ;; esac; '
    r'case "$(uname -m)" in x86_64|amd64) arch=x86_64 ;; aarch64|arm64) arch=arm64 ;; *) echo "ACP_INSTALL_ARCH_UNSUPPORTED" >&2; exit 1 ;; esac; '
    r'if [ "$platform" = macos ]; then target=darwin; else target=linux; fi; '
    r'command -v curl >/dev/null || { echo "ACP_INSTALL_REQUIRES_CURL" >&2; exit 1; }; '
    r'command -v unzip >/dev/null || { echo "ACP_INSTALL_REQUIRES_UNZIP" >&2; exit 1; }; '
    r'root="$HOME/.local/share/valhalla/antigravity-acp"; destination="$root/1.2.1"; '
    r'mkdir -p "$root" "$HOME/.local/bin"; temporary=$(mktemp -d "$root/.install.XXXXXX"); '
    r'trap "rm -rf -- \"\$temporary\"" EXIT; '
    r'if [ ! -d "$destination" ]; then '
    r'curl --proto "=https" --tlsv1.2 -fL --retry 2 --connect-timeout 20 '
    r'"https://dl.google.com/agy-extensions/releases/$platform/agy-acp-server-1.2.1-$target-$arch.zip" -o "$temporary/archive.zip"; '
    r'unzip -q "$temporary/archive.zip" -d "$temporary/runtime"; '
    r'test -f "$temporary/runtime/agy_acp_server.par" && test -f "$temporary/runtime/localharness_external" || { echo "ACP_INSTALL_ARCHIVE_INVALID" >&2; exit 1; }; '
    r'chmod u+x "$temporary/runtime/agy_acp_server.par" "$temporary/runtime/localharness_external"; '
    r'mv "$temporary/runtime" "$destination"; fi; '
    r'test -x "$destination/agy_acp_server.par" && test -x "$destination/localharness_external" || { echo "ACP_INSTALL_RUNTIME_INVALID" >&2; exit 1; }; '
    r'printf "%s\n" "#!/bin/sh" "exec \"\$HOME/.local/share/valhalla/antigravity-acp/1.2.1/agy_acp_server.par\" \"\$@\"" > "$temporary/launcher"; '
    r'chmod u+x "$temporary/launcher"; mv "$temporary/launcher" "$HOME/.local/bin/agy_acp_server.par"; '
    r"""echo "Antigravity ACP 1.2.1 installed; authentication is separate from agy CLI."'""";
