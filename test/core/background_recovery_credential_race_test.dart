import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/errors/app_exceptions.dart';
import 'package:valhalla/core/providers/reconnect_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/core/utils/reconnect_backoff.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/repositories/server_repository.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/data/storage/secure_storage_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';

const _server = ServerProfile(
  id: 'a',
  name: 'server-a',
  host: '10.0.0.1',
  port: 22,
  username: 'dev',
);

/// 记录每次 `reconnectClient` 用的是哪一版凭据。
class _RecordingSshManager extends SSHClientManager {
  _RecordingSshManager(LocalStorageService storage)
    : super(SSHHostKeyVerifier(storage));

  final List<({String serverId, String? password, String? privateKey})> calls =
      [];
  bool failNext = false;

  @override
  Future<SSHClient> reconnectClient(
    ServerProfile server, {
    String? password,
    String? privateKey,
    Future<bool> Function(String, String, String)? onConfirmHostKey,
  }) async {
    calls.add((
      serverId: server.id,
      password: password,
      privateKey: privateKey,
    ));
    if (failNext) throw SSHConnectionException('refused');
    throw SSHConnectionException('refused');
  }
}

/// 可控的凭据读取：用来把「凭据还在读」和「用户已经断开」这两个时刻错开。
class _GatedCredentialRepository extends ServerRepository {
  _GatedCredentialRepository(super.local, super.secure);

  final List<String> passwordReads = [];
  final List<String> keyReads = [];
  final List<Completer<void>> pending = [];

  String? password = 'first-secret';
  bool hold = false;

  @override
  Future<String?> getPassword(String serverId) async {
    passwordReads.add(serverId);
    if (!hold) return password;
    final gate = Completer<void>();
    pending.add(gate);
    await gate.future;
    return password;
  }

  @override
  Future<String?> getPrivateKey(String serverId) async {
    keyReads.add(serverId);
    return null;
  }

  void release() {
    for (final gate in pending) {
      if (!gate.isCompleted) gate.complete();
    }
    pending.clear();
  }
}

void main() {
  late LocalStorageService storage;
  late _GatedCredentialRepository repository;
  late _RecordingSshManager ssh;

  Future<ProviderContainer> container() async {
    ssh = _RecordingSshManager(storage);
    repository = _GatedCredentialRepository(storage, SecureStorageService());
    final created = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        serverRepositoryProvider.overrideWithValue(repository),
        sshClientManagerProvider.overrideWithValue(ssh),
        reconnectEnabledProvider.overrideWithValue(true),
      ],
    );
    addTearDown(created.dispose);
    return created;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorageService(await SharedPreferences.getInstance());
  });

  test('凭据还在读取时用户断开：旧凭据不得再用来重连', () async {
    final created = await container();
    final controller = created.read(reconnectControllerProvider)!;
    repository.hold = true;

    controller.start(_server);
    controller.handleTransportDied();
    // provider 里的控制器用真实定时器：退避第一档是 1s。
    await Future<void>.delayed(const Duration(milliseconds: 1300));

    expect(repository.passwordReads, ['a'], reason: '每次尝试都要重新读凭据');
    expect(ssh.calls, isEmpty, reason: '凭据未到之前不得发起连接');

    controller.userDisconnect();
    repository.release();
    await pumpEventQueue();

    expect(ssh.calls, isEmpty, reason: '断开之后才读到的凭据属于过期请求，不能拿去连');
    expect(controller.state.status, ReconnectStatus.idle);
  });

  test('每次重试都重新读取凭据，改密后立刻生效', () async {
    final created = await container();
    final controller = created.read(reconnectControllerProvider)!;

    controller.start(_server);
    controller.handleTransportDied();
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    await pumpEventQueue();
    expect(ssh.calls.single.password, 'first-secret');

    // 用户改了密码：下一次重试必须用新密码，不能缓存旧值。
    repository.password = 'rotated-secret';
    await Future<void>.delayed(const Duration(milliseconds: 2400));
    await pumpEventQueue();

    expect(ssh.calls.length, greaterThanOrEqualTo(2));
    expect(ssh.calls.last.password, 'rotated-secret');
    expect(repository.passwordReads.length, greaterThanOrEqualTo(2));
  });

  test('用户断开后不再读取凭据', () async {
    final created = await container();
    final controller = created.read(reconnectControllerProvider)!;

    controller.start(_server);
    controller.handleTransportDied();
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    final beforeDisconnect = ssh.calls.length;

    controller.userDisconnect();
    await Future<void>.delayed(const Duration(milliseconds: 2400));

    expect(ssh.calls.length, beforeDisconnect, reason: '断开后不得再有连接尝试');
  });
}
