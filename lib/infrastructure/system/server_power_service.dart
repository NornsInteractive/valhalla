import '../ssh/ssh_client_manager.dart';

enum ServerPowerPhase {
  idle,
  submitting,
  accepted,
  unknown,
  failed,
  passwordRequired,
  verified,
}

enum ServerPowerAction { reboot, shutdown }

class ServerPowerOutcome {
  final ServerPowerPhase phase;
  final String? bootId;
  final String? errorCode;
  const ServerPowerOutcome(this.phase, {this.bootId, this.errorCode});
}

class ServerPowerService {
  final SshCommandExecutor executor;
  ServerPowerService(this.executor);
  static const rebootScript =
      'if command -v systemctl >/dev/null 2>&1; then exec systemctl reboot; else exec shutdown -r now; fi';
  static const shutdownScript =
      'if command -v systemctl >/dev/null 2>&1; then exec systemctl poweroff; else exec shutdown -h now; fi';

  Future<String?> readBootId(String serverId) async {
    final result = await executor.executeWithLoginShell(
      serverId,
      'cat /proc/sys/kernel/random/boot_id',
    );
    return result.isSuccess &&
            RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
              caseSensitive: false,
            ).hasMatch(result.stdout.trim())
        ? result.stdout.trim()
        : null;
  }

  Future<ServerPowerOutcome> reboot(
    String serverId, {
    String? sudoPassword,
    required bool Function() isCurrent,
  }) async {
    return _executePower(
      serverId,
      action: ServerPowerAction.reboot,
      sudoPassword: sudoPassword,
      isCurrent: isCurrent,
    );
  }

  Future<ServerPowerOutcome> shutdown(
    String serverId, {
    String? sudoPassword,
    required bool Function() isCurrent,
  }) async {
    return _executePower(
      serverId,
      action: ServerPowerAction.shutdown,
      sudoPassword: sudoPassword,
      isCurrent: isCurrent,
    );
  }

  Future<ServerPowerOutcome> _executePower(
    String serverId, {
    required ServerPowerAction action,
    String? sudoPassword,
    required bool Function() isCurrent,
  }) async {
    final prefix = action == ServerPowerAction.reboot ? 'REBOOT' : 'SHUTDOWN';
    if (sudoPassword != null && RegExp(r'[\r\n\x00]').hasMatch(sudoPassword)) {
      return ServerPowerOutcome(
        ServerPowerPhase.failed,
        errorCode: '${prefix}_PASSWORD_INVALID',
      );
    }
    if (!executor.isConnected(serverId)) {
      return const ServerPowerOutcome(
        ServerPowerPhase.failed,
        errorCode: 'SSH_DISCONNECTED',
      );
    }
    String? bootId;
    var dispatched = false;
    try {
      bootId = await readBootId(serverId);
      final identity = await executor.executeWithLoginShell(serverId, 'id -u');
      if (!identity.isSuccess ||
          !RegExp(r'^\d+$').hasMatch(identity.stdout.trim())) {
        return ServerPowerOutcome(
          ServerPowerPhase.failed,
          bootId: bootId,
          errorCode: '${prefix}_IDENTITY_FAILED',
        );
      }
      if (!isCurrent() || !executor.isConnected(serverId)) {
        return ServerPowerOutcome(
          ServerPowerPhase.failed,
          bootId: bootId,
          errorCode: '${prefix}_SERVER_CHANGED',
        );
      }
      final root = identity.stdout.trim() == '0';
      final command =
          "sh -c '${action == ServerPowerAction.reboot ? rebootScript : shutdownScript}'";
      dispatched = true;
      final result = await executor.executeWithLoginShell(
        serverId,
        !root && sudoPassword == null
            ? 'LC_ALL=C sudo -n -- $command'
            : command,
        sudoPassword: root ? null : sudoPassword,
      );
      if (result.isSuccess) {
        return ServerPowerOutcome(ServerPowerPhase.accepted, bootId: bootId);
      }
      if (!root &&
          sudoPassword == null &&
          result.stderr.toLowerCase().contains('password')) {
        return ServerPowerOutcome(
          ServerPowerPhase.passwordRequired,
          bootId: bootId,
          errorCode: '${prefix}_PASSWORD_REQUIRED',
        );
      }
      return ServerPowerOutcome(
        result.exitCode < 0
            ? ServerPowerPhase.unknown
            : ServerPowerPhase.failed,
        bootId: bootId,
        errorCode: result.exitCode < 0
            ? '${prefix}_RESULT_UNKNOWN'
            : '${prefix}_PERMISSION_OR_COMMAND_FAILED',
      );
    } catch (_) {
      return ServerPowerOutcome(
        dispatched ? ServerPowerPhase.unknown : ServerPowerPhase.failed,
        bootId: bootId,
        errorCode: dispatched
            ? '${prefix}_RESULT_UNKNOWN'
            : '${prefix}_PROBE_FAILED',
      );
    }
  }
}
