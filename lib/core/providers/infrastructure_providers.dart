import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/acp/agent_environment_service.dart';
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
  return AgentEnvironmentService(ref.watch(sshClientManagerProvider));
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
