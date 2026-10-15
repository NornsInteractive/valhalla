import '../../core/utils/shell_quote.dart';
import '../../data/models/agent_profile.dart';
import '../../data/models/native_cli_session.dart';

/// Quote program source as one shell argument. Unlike ordinary data arguments,
/// generated shell/JavaScript programs may contain line breaks. Keep this local:
/// paths, models and target identities must still use strict [cliShellQuote].
String _agentScriptQuote(String script) {
  if (script.contains('\u0000')) {
    throw ArgumentError('CLI_INVALID_ARGUMENT');
  }
  return "'${script.replaceAll("'", "'\\''")}'";
}

bool usesAntigravityAcp(AgentProfile profile) => RegExp(
  r'^(?:/[^\s]+/)?agy_acp_server\.par(?:\s|$)',
).hasMatch(profile.acpCommand?.trim() ?? '');

bool usesStandardCodexAcp(AgentProfile profile) =>
    nativeCliKind(profile.cliCommand) == NativeCliKind.codex &&
    RegExp(
      r'^(?:/[^\s]+/)?codex-acp(?:\s+--stdio)?$',
    ).hasMatch(profile.acpCommand?.trim() ?? '');

/// Resolve inside the selected runtime, bypassing aliases and shell functions.
String agentCodexExecutableScript(AgentProfile profile) {
  final cli = cliShellQuote(profile.cliCommand);
  return 'if [ -n "\${BASH_VERSION:-}" ]; then '
      'valhalla_codex_path=\$(type -P -- $cli); else '
      'valhalla_codex_path=\$(command -v -- $cli); fi; '
      'if [ -z "\$valhalla_codex_path" ] || [ ! -x "\$valhalla_codex_path" ]; then '
      'printf "%s\\n" "ACP_CODEX_EXECUTABLE_UNAVAILABLE" >&2; exit 127; fi; '
      'export CODEX_PATH="\$valhalla_codex_path"; ';
}

/// Agent-only interactive initialization; startup banners never enter JSON stdout.
String agentCodexTargetCommand(AgentProfile profile, String command) =>
    _agentTargetCommand(profile, command, protocolSafe: true);

const antigravityAcpLookupCommand =
    r'command -v agy_acp_server.par || { test -x "$HOME/.local/bin/agy_acp_server.par" && printf "%s\n" "$HOME/.local/bin/agy_acp_server.par"; }';

/// Standard Codex ACP must use the same executable as independent CLI queries.
/// Explicit custom launch scripts keep their own runtime/environment semantics.
String agentAcpLaunchCommand(AgentProfile profile, {String? initialModelId}) {
  final command = profile.acpCommand?.trim();
  if (command == null || command.isEmpty) {
    throw StateError('AGENT_ACP_COMMAND_MISSING');
  }
  var script = command;
  if (RegExp(
    r'^(?:/[^\s]+/)?agy_acp_server\.par(?:\s+--uid=)?$',
  ).hasMatch(command)) {
    final executable = command.split(RegExp(r'\s+')).first;
    final lookup = executable == 'agy_acp_server.par'
        ? antigravityAcpLookupCommand
        : 'command -v ${cliShellQuote(executable)}';
    script =
        'valhalla_agy_acp_path=\$($lookup) || exit 127; '
        'if [ "\$(uname -s)" = Linux ]; then '
        'exec "\$valhalla_agy_acp_path" --uid=; else '
        'exec "\$valhalla_agy_acp_path"; fi';
  }
  if (usesStandardCodexAcp(profile)) {
    if (initialModelId != null &&
        (initialModelId.isEmpty ||
            initialModelId.length > 256 ||
            RegExp(r'[\s\x00-\x1f\x7f]').hasMatch(initialModelId))) {
      throw StateError('ACP_CODEX_INITIAL_MODEL_INVALID');
    }
    final binary = cliShellQuote(command.split(RegExp(r'\s+')).first);
    script =
        '${agentCodexExecutableScript(profile)}'
        'printf "Valhalla ACP Codex executable: %s\\n" "\$CODEX_PATH" >&2; '
        '"\$CODEX_PATH" --version >&2 || exit 127; '
        'printf "Valhalla Codex HOME: %s; CODEX_HOME: %s\\n" '
        '"\$HOME" "\${CODEX_HOME:-<default>}" >&2; '
        'printf "Valhalla Codex CODEX_CONFIG present: %s; MODEL_PROVIDER present: %s\\n" '
        '"\${CODEX_CONFIG:+yes}" "\${MODEL_PROVIDER:+yes}" >&2; '
        'if [ -n "\${BASH_VERSION:-}" ]; then '
        'valhalla_acp_path=\$(type -P -- $binary); else '
        'valhalla_acp_path=\$(command -v -- $binary); fi; '
        'if [ -z "\$valhalla_acp_path" ] || [ ! -x "\$valhalla_acp_path" ]; then '
        'printf "%s\\n" "ACP_CODEX_ADAPTER_UNAVAILABLE" >&2; exit 127; fi; '
        'printf "Valhalla Codex ACP executable: %s\\n" "\$valhalla_acp_path" >&2; '
        '${initialModelId == null ? '' : _codexInitialModelScript(initialModelId)}'
        'exec "\$valhalla_acp_path"${command.endsWith(' --stdio') ? ' --stdio' : ''}';
    return agentCodexTargetCommand(profile, script);
  }
  return agentTargetCommand(
    profile,
    profile.executionTarget == 'docker'
        ? script
        : 'bash -l -c ${_agentScriptQuote(script)}',
  );
}

String _codexInitialModelScript(String model) {
  // Only this verified adapter contract consumes CODEX_CONFIG before thread/start.
  const merge = r'''try {
const value = process.env.CODEX_CONFIG ? JSON.parse(process.env.CODEX_CONFIG) : {};
if (!value || typeof value !== 'object' || Array.isArray(value)) throw 0;
process.stdout.write(JSON.stringify({...value, model: process.argv[1]}));
} catch (_) { process.stderr.write('ACP_CODEX_CONFIG_INVALID\n'); process.exit(78); }''';
  return 'set +x; valhalla_acp_version=\$("\$valhalla_acp_path" --version 2>/dev/null); '
      'printf "Valhalla Codex ACP version: %s\\n" "\$valhalla_acp_version" >&2; '
      'case "\$valhalla_acp_version" in '
      '${cliShellQuote('@agentclientprotocol/codex-acp 2.0.0')}) '
      'if [ -n "\${BASH_VERSION:-}" ]; then '
      'valhalla_node_path=\$(type -P node); else valhalla_node_path=\$(command -v node); fi; '
      '[ -x "\$valhalla_node_path" ] || { printf "%s\\n" "ACP_CODEX_CONFIG_REQUIRES_NODE" >&2; exit 127; }; '
      'CODEX_CONFIG=\$("\$valhalla_node_path" -e ${_agentScriptQuote(merge)} -- ${cliShellQuote(model)}) || exit \$?; '
      'export CODEX_CONFIG; '
      'printf "%s\\n" "Valhalla Codex initial model override applied" >&2;; '
      '*) printf "%s\\n" "Valhalla Codex initial model override unsupported by this adapter version" >&2;; '
      'esac; ';
}

/// Builds the remote command for an agent's configured execution location.
/// Docker's container argument is always quoted and ACP/JSON transports never
/// receive a PTY. Interactive callers explicitly request one.
String agentTargetCommand(
  AgentProfile profile,
  String command, {
  bool interactive = false,
}) => _agentTargetCommand(profile, command, interactive: interactive);

String _agentTargetCommand(
  AgentProfile profile,
  String command, {
  bool interactive = false,
  bool protocolSafe = false,
}) {
  final payload = protocolSafe
      ? 'set +x; unset HISTFILE; '
            'if [ -n "\${BASH_VERSION:-}" ]; then set +o history; fi; '
            'exec 1>&3 3>&-; $command'
      : command;
  if (profile.executionTarget == 'host') {
    if (!protocolSafe) return command;
    final interactive = 'exec bash -ic ${_agentScriptQuote(payload)}';
    return 'bash -l -c ${_agentScriptQuote(interactive)} 3>&1 1>&2';
  }
  if (profile.executionTarget != 'docker' ||
      !{'id', 'name'}.contains(profile.containerBinding)) {
    throw StateError('AGENT_TARGET_INVALID');
  }
  final reference = profile.containerReference?.trim();
  if (reference == null ||
      reference.isEmpty ||
      !RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.-]*$').hasMatch(reference)) {
    throw StateError('AGENT_CONTAINER_INVALID');
  }
  final user = profile.containerUser?.trim();
  if (user != null &&
      user.isNotEmpty &&
      !RegExp(
        r'^(?:[A-Za-z_][A-Za-z0-9_.-]*|[0-9]+)(?::(?:[A-Za-z_][A-Za-z0-9_.-]*|[0-9]+))?$',
      ).hasMatch(user)) {
    throw StateError('AGENT_CONTAINER_USER_INVALID');
  }
  // Use /bin/sh as the stable entrypoint and prefer Bash when present. This
  // keeps Debian/BusyBox containers working while retaining .bashrc PATH setup
  // for images that provide Bash.
  final bash = '/bin/bash -ic ${_agentScriptQuote(payload)}';
  final shellScript =
      '${protocolSafe ? 'exec 3>&1 1>&2; ' : ''}'
      // docker exec --user changes uid, but can retain the image's HOME.
      // Resolve the selected user's home before Bash reads its startup files.
      '${user == null || user.isEmpty ? '' : r'''valhalla_uid=$(id -u); valhalla_home=$(awk -F: -v uid="$valhalla_uid" '$3 == uid {print $6; exit}' /etc/passwd); if [ -n "$valhalla_home" ]; then export HOME="$valhalla_home"; fi; '''}'
      'if [ -x /bin/bash ]; then exec $bash; else exec /bin/sh -lc ${_agentScriptQuote(payload)}; fi';
  return 'docker exec ${interactive ? '-it' : '-i'} '
      '${user == null || user.isEmpty ? '' : '--user ${cliShellQuote(user)} '}'
      '${cliShellQuote(reference)} /bin/sh ${protocolSafe ? '-c' : '-lc'} ${_agentScriptQuote(shellScript)}';
}
