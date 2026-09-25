import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/storage/local_storage_service.dart';
import '../../data/storage/secure_storage_service.dart';
import '../../data/repositories/server_repository.dart';
import '../../data/repositories/command_repository.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/agent_repository.dart';
import '../../infrastructure/ssh/ssh_host_key_verifier.dart';
import '../../infrastructure/ssh/ssh_client_manager.dart';
import '../services/keep_alive_service.dart';

/// 运行时初始化的 LocalStorage 注入
final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  throw UnimplementedError(
    'LocalStorageService must be initialized before runApp',
  );
});

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final serverRepositoryProvider = Provider<ServerRepository>((ref) {
  final local = ref.watch(localStorageServiceProvider);
  final secure = ref.watch(secureStorageServiceProvider);
  return ServerRepository(local, secure);
});

final commandRepositoryProvider = Provider<CommandRepository>((ref) {
  final local = ref.watch(localStorageServiceProvider);
  return CommandRepository(local);
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final local = ref.watch(localStorageServiceProvider);
  return ChatRepository(local);
});

final agentRepositoryProvider = Provider<AgentRepository>((ref) {
  return AgentRepository(ref.watch(localStorageServiceProvider));
});

final sshHostKeyVerifierProvider = Provider<SSHHostKeyVerifier>((ref) {
  final local = ref.watch(localStorageServiceProvider);
  return SSHHostKeyVerifier(local);
});

final sshClientManagerProvider = Provider<SSHClientManager>((ref) {
  final verifier = ref.watch(sshHostKeyVerifierProvider);
  final manager = SSHClientManager(verifier);
  ref.onDispose(manager.dispose);
  return manager;
});

/// 前台服务保活能力的 Dart 侧实现。
///
/// Android 平台上使用 [MethodChannelKeepAliveService] 对接原生前台服务与通知；
/// 桌面平台上使用 [DesktopKeepAliveService] 进行安全降级（静默 no-op / 返回 false）。
final keepAliveServiceProvider = Provider<KeepAliveService>((ref) {
  if (!kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
    return const DesktopKeepAliveService();
  }
  return const MethodChannelKeepAliveService();
});
