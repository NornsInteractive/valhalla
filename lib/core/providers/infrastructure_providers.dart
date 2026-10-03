import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/acp/agent_environment_service.dart';
import '../../infrastructure/acp/agy_saved_auth_probe.dart';
import '../../infrastructure/acp/acp_ssh_transport.dart';
import '../../infrastructure/cli/agent_execution_target.dart';
import '../../infrastructure/docker/docker_cli_service.dart';
import '../../infrastructure/ssh/ssh_client_manager.dart';
import '../../infrastructure/system/process_service.dart';
import '../../infrastructure/system/disk_usage_service.dart';
import '../../infrastructure/system/service_manager.dart';
import '../../infrastructure/system/system_metrics_sampler.dart';
import '../../infrastructure/system/system_hardware_service.dart';
import '../../infrastructure/nas/nas_scan_service.dart';
import '../../infrastructure/nas/nas_media_proxy_service.dart';
import 'storage_providers.dart';

/// 以接口类型暴露命令执行能力。
///
/// [sshClientManagerProvider] 是具体类，测试替身没法直接 override 成接口实现；
/// 这个 provider 让只依赖「执行远端命令」的消费者（如工具探测）可以在测试里
/// 注入假实现，而不必构造整个 SSHClientManager。
final sshCommandExecutorProvider = Provider<SshCommandExecutor>((ref) {
  return ref.watch(sshClientManagerProvider);
});

final dockerCliServiceProvider = Provider<DockerCliService>((ref) {
  return DockerCliService(ref.watch(sshCommandExecutorProvider));
});

final processServiceProvider = Provider<ProcessService>((ref) {
  return ProcessService(ref.watch(sshClientManagerProvider));
});

final diskUsageServiceProvider = Provider<DiskUsageService>((ref) {
  return DiskUsageService(ref.watch(sshCommandExecutorProvider));
});

final serviceManagerProvider = Provider<ServiceManager>((ref) {
  return ServiceManager(ref.watch(sshClientManagerProvider));
});

final systemMetricsSamplerProvider = Provider<SystemMetricsSampler>((ref) {
  return SystemMetricsSampler(ref.watch(sshClientManagerProvider));
});

final systemHardwareServiceProvider = Provider<SystemHardwareService>((ref) {
  return SystemHardwareService(ref.watch(sshCommandExecutorProvider));
});

final agentEnvironmentServiceProvider = Provider<AgentEnvironmentService>((
  ref,
) {
  final manager = ref.watch(sshClientManagerProvider);
  return AgentEnvironmentService(
    manager,
    validateSavedAuth: (profile, method) async {
      final client = manager.getClient(profile.serverId);
      if (client == null) return AgentAuthenticationStatus.unknown;
      return probeAgySavedAuth(
        profile,
        method,
        () async => AcpSshTransport(
          await client.execute(agentAcpLaunchCommand(profile)),
        ),
      );
    },
  );
});

final nasScanServiceProvider = Provider<NasScanService>((ref) {
  return NasScanService(ref.watch(sshCommandExecutorProvider));
});

final nasMediaProxyServiceProvider = Provider<NasMediaProxyService>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  final service = NasMediaProxyService(
    ref.watch(sshCommandExecutorProvider),
    cacheBudgetBytes: storage.getNasMediaCacheBytes,
  );
  ref.onDispose(service.dispose);
  return service;
});
