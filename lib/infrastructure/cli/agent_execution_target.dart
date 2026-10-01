import '../../core/utils/shell_quote.dart';
import '../../data/models/agent_profile.dart';
import '../../data/models/native_cli_session.dart';

/// Standard Codex ACP must use the same executable as independent CLI queries.
/// Explicit custom launch scripts keep their own runtime/environment semantics.
String agentAcpLaunchCommand(AgentProfile profile) {
  final command = profile.acpCommand?.trim();
  if (command == null || command.isEmpty) {
    throw StateError('AGENT_ACP_COMMAND_MISSING');
  }
  var script = command;
  if (nativeCliKind(profile.cliCommand) == NativeCliKind.codex &&
      RegExp(r'^(?:/[^\s]+/)?codex-acp(?:\s+--stdio)?$').hasMatch(command)) {
    final cli = cliShellQuote(profile.cliCommand);
    // Bash aliases are interactive conveniences, not spawnable executables.
    // Resolve inside the target shell, never against the phone or Docker host.
    script =
        'if [ -n "\${BASH_VERSION:-}" ]; then '
        'valhalla_codex_path=\$(type -P -- $cli); else '
        'valhalla_codex_path=\$(command -v -- $cli); fi; '
        'if [ -z "\$valhalla_codex_path" ] || [ ! -x "\$valhalla_codex_path" ]; then '
        'printf "%s\\n" "ACP_CODEX_EXECUTABLE_UNAVAILABLE" >&2; exit 127; fi; '
        'export CODEX_PATH="\$valhalla_codex_path"; '
        'printf "Valhalla ACP Codex executable: %s\\n" "\$CODEX_PATH" >&2; '
        '"\$CODEX_PATH" --version >&2 || exit 127; '
        'exec $command';
  }
  return agentTargetCommand(
    profile,
    profile.executionTarget == 'docker'
        ? script
        : 'bash -l -c ${cliShellQuote(script)}',
  );
}

/// Builds the remote command for an agent's configured execution location.
/// Docker's container argument is always quoted and ACP/JSON transports never
/// receive a PTY. Interactive callers explicitly request one.
String agentTargetCommand(
  AgentProfile profile,
  String command, {
  bool interactive = false,
}) {
  if (profile.executionTarget == 'host') return command;
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
  final bash = '/bin/bash -ic ${cliShellQuote(command)}';
  final shellScript =
      'if [ -x /bin/bash ]; then exec $bash; else exec /bin/sh -lc ${cliShellQuote(command)}; fi';
  return 'docker exec ${interactive ? '-it' : '-i'} '
      '${user == null || user.isEmpty ? '' : '--user ${cliShellQuote(user)} '}'
      '${cliShellQuote(reference)} /bin/sh -lc ${cliShellQuote(shellScript)}';
}
