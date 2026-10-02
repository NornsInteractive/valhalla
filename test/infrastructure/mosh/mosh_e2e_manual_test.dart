// Mosh 手动端到端测试: 对真实 mosh-server 验证 MoshSessionService
// 的 bootstrap (含 locale 回退) + SSP 数据面。
//
// 默认跳过。需要真实环境 (WSL/Linux 服务器: mosh + openssh-server,
// root 免密公钥, sshd 运行中) 时以环境变量开启:
//
//   VALHALLA_MOSH_E2E=1 VALHALLA_MOSH_HOST=172.30.242.84 \
//   VALHALLA_MOSH_KEY=C:/Users/<u>/.ssh/id_rsa \
//   flutter test test/infrastructure/mosh/mosh_e2e_manual_test.dart
//
// WSL 保活: wsl -d Ubuntu -u root -- bash -c "service ssh start; sleep 900" &
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dartssh2/dartssh2.dart';

import 'package:valhalla/infrastructure/mosh/mosh_session_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';

/// 最小 SshCommandExecutor 适配器: 只服务 bootstrap 所需的 getClient。
class _ProbeExecutor implements SshCommandExecutor {
  _ProbeExecutor(this.client);

  final SSHClient client;

  @override
  bool isConnected(String serverId) => !client.isClosed;

  @override
  SSHClient? getClient(String serverId) => client;

  @override
  Future<SSHExecutionResult> executeWithLoginShell(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) async {
    final session = await client.execute('bash -l -c "$command"');
    final stdoutText = await session.stdout.map(utf8.decode).join();
    final stderrText = await session.stderr.map(utf8.decode).join();
    return SSHExecutionResult(
      stdout: stdoutText,
      stderr: stderrText,
      exitCode: session.exitCode ?? -1,
    );
  }

  @override
  Stream<SSHExecutionChunk> executeStreaming(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) {
    throw UnimplementedError('probe does not need streaming');
  }
}

void main() {
  final enabled = Platform.environment['VALHALLA_MOSH_E2E'] == '1';
  final host = Platform.environment['VALHALLA_MOSH_HOST'] ?? '172.30.242.84';
  final keyPath = Platform.environment['VALHALLA_MOSH_KEY'] ??
      '${Platform.environment['USERPROFILE']!}\\.ssh\\id_rsa';

  test(
    'real mosh-server e2e: bootstrap with locale fallback + UDP round-trip',
    () async {
      final keyPem = await File(keyPath).readAsString();
      final socket = await SSHSocket.connect(
        host,
        22,
        timeout: Duration(seconds: 10),
      );
      final client = SSHClient(
        socket,
        username: 'root',
        identities: SSHKeyPair.fromPem(keyPem),
        onPasswordRequest: () => '',
      );
      // ignore: avoid_print
      print('[1] SSH connected to $host');

      final service = MoshSessionService(_ProbeExecutor(client));
      final result = await service.bootstrap(
        MoshBootstrapRequest(serverId: 'probe', host: host),
      );

      expect(result, isA<MoshBootstrapSuccess>(), reason: 'bootstrap 应成功');
      final endpoint = (result as MoshBootstrapSuccess).endpoint;
      // ignore: avoid_print
      print(
        '[2] bootstrap OK (locale=${(result).locale}) '
        'udp=${endpoint.host}:${endpoint.port}',
      );

      final handle = await service.connect(endpoint, columns: 100, rows: 30);
      final got = Completer<String>();
      final sub = handle.stdout.listen((bytes) {
        final text = utf8.decode(bytes, allowMalformed: true);
        if (!got.isCompleted && text.contains('E2E_MOSH_OK')) {
          got.complete(text);
        }
      });
      handle.errors.listen((e) {
        // ignore: avoid_print
        print('[err] $e');
      });

      // 等登录 shell 提示符后发送标记命令。
      await Future<void>.delayed(Duration(seconds: 4));
      handle.send(utf8.encode('echo E2E_MOSH_OK\r'));
      final marker = await got.future.timeout(Duration(seconds: 20));
      // ignore: avoid_print
      print('[4] round-trip OK: '
          '${marker.replaceAll(RegExp(r'\s+'), ' ').trim()}');

      await handle.dispose();
      await sub.cancel();
      client.close();
    },
    timeout: Timeout(Duration(minutes: 2)),
    skip: enabled ? false : '需要 VALHALLA_MOSH_E2E=1 与真实 mosh-server',
  );
}
