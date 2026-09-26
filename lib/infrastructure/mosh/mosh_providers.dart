import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/infrastructure_providers.dart';
import 'mosh_session_service.dart';

/// Mosh 会话服务。
///
/// 与 infrastructure_providers.dart 里的其他基础设施服务保持同一模式：
/// 只依赖 SshCommandExecutor 接缝，测试可直接注入假实现。
/// （SPEC-0003 Phase 1 不允许改 infrastructure_providers.dart，先落在
/// mosh/ 内；Phase 3 接 UI 时如需可挪过去。）
final moshSessionServiceProvider = Provider<MoshSessionService>((ref) {
  return MoshSessionService(ref.watch(sshCommandExecutorProvider));
});
