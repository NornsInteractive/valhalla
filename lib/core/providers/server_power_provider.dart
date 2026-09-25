import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../infrastructure/system/server_power_service.dart';
import 'infrastructure_providers.dart';
import 'server_provider.dart';
import 'storage_providers.dart';
export '../../infrastructure/system/server_power_service.dart'
    show ServerPowerPhase, ServerPowerAction;

class ServerPowerState {
  final String? serverId;
  final ServerPowerPhase phase;
  final String? errorCode;
  final String? bootId;
  final ServerPowerAction action;
  const ServerPowerState({
    this.serverId,
    this.phase = ServerPowerPhase.idle,
    this.errorCode,
    this.bootId,
    this.action = ServerPowerAction.reboot,
  });
}

final serverPowerServiceProvider = Provider(
  (ref) => ServerPowerService(ref.watch(sshCommandExecutorProvider)),
);
final serverPowerProvider =
    NotifierProvider<ServerPowerNotifier, ServerPowerState>(
      ServerPowerNotifier.new,
    );

class ServerPowerNotifier extends Notifier<ServerPowerState> {
  int _epoch = 0;
  @override
  ServerPowerState build() {
    _epoch++;
    ref.listen(serverConnectionProvider.select((s) => s.isConnected), (
      before,
      connected,
    ) {
      if (before != true &&
          connected &&
          (state.phase == ServerPowerPhase.accepted ||
              state.phase == ServerPowerPhase.unknown)) {
        if (state.action == ServerPowerAction.reboot) {
          verifyReboot();
        } else {
          state = ServerPowerState(serverId: state.serverId);
        }
      }
    });
    final identity = ref.watch(
      activeServerProvider.select(
        (s) => (s?.id, s?.host, s?.port, s?.username),
      ),
    );
    return ServerPowerState(serverId: identity.$1);
  }

  Future<void> reboot({
    required String expectedServerId,
    String? sudoPassword,
  }) async {
    await _submit(
      expectedServerId: expectedServerId,
      sudoPassword: sudoPassword,
      action: ServerPowerAction.reboot,
    );
  }

  Future<void> shutdown({
    required String expectedServerId,
    String? sudoPassword,
  }) async {
    await _submit(
      expectedServerId: expectedServerId,
      sudoPassword: sudoPassword,
      action: ServerPowerAction.shutdown,
    );
  }

  Future<void> _submit({
    required String expectedServerId,
    String? sudoPassword,
    required ServerPowerAction action,
  }) async {
    if (state.phase == ServerPowerPhase.submitting ||
        state.phase == ServerPowerPhase.accepted ||
        state.phase == ServerPowerPhase.unknown) {
      return;
    }
    if (state.serverId != expectedServerId ||
        !ref.read(serverConnectionProvider).isConnected) {
      state = ServerPowerState(
        serverId: state.serverId,
        phase: ServerPowerPhase.failed,
        errorCode: action == ServerPowerAction.reboot
            ? 'REBOOT_SERVER_CHANGED'
            : 'SHUTDOWN_SERVER_CHANGED',
        action: action,
      );
      return;
    }
    final epoch = ++_epoch;
    bool current() =>
        ref.mounted && epoch == _epoch && state.serverId == expectedServerId;
    state = ServerPowerState(
      serverId: expectedServerId,
      phase: ServerPowerPhase.submitting,
      action: action,
    );
    String? saved;
    try {
      saved =
          sudoPassword ??
          await ref
              .read(serverRepositoryProvider)
              .getSudoPassword(expectedServerId);
    } catch (_) {
      if (current()) {
        state = ServerPowerState(
          serverId: expectedServerId,
          phase: ServerPowerPhase.failed,
          errorCode: action == ServerPowerAction.reboot
              ? 'REBOOT_CREDENTIAL_READ_FAILED'
              : 'SHUTDOWN_CREDENTIAL_READ_FAILED',
          action: action,
        );
      }
      return;
    }
    if (!current()) return;
    final service = ref.read(serverPowerServiceProvider);
    final result = action == ServerPowerAction.reboot
        ? await service.reboot(
            expectedServerId,
            sudoPassword: saved,
            isCurrent: current,
          )
        : await service.shutdown(
            expectedServerId,
            sudoPassword: saved,
            isCurrent: current,
          );
    if (!current()) return;
    state = ServerPowerState(
      serverId: expectedServerId,
      phase: result.phase,
      errorCode: result.errorCode,
      bootId: result.bootId,
      action: action,
    );
  }

  Future<void> verifyReboot() async {
    final before = state;
    final epoch = _epoch;
    if (before.serverId == null ||
        before.bootId == null ||
        before.action != ServerPowerAction.reboot) {
      return;
    }
    try {
      final after = await ref
          .read(serverPowerServiceProvider)
          .readBootId(before.serverId!);
      if (!ref.mounted || epoch != _epoch) return;
      if (after != null && after != before.bootId) {
        state = ServerPowerState(
          serverId: before.serverId,
          phase: ServerPowerPhase.verified,
          bootId: before.bootId,
          action: before.action,
        );
      }
    } catch (_) {
      if (ref.mounted && epoch == _epoch) {
        state = ServerPowerState(
          serverId: before.serverId,
          phase: before.phase,
          bootId: before.bootId,
          errorCode: 'REBOOT_VERIFY_FAILED',
          action: before.action,
        );
      }
    }
  }
}
