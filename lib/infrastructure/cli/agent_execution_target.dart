import '../../core/utils/shell_quote.dart';
import '../../data/models/agent_profile.dart';

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
