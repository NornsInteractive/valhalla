import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/core/providers/agent_registry_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/repositories/chat_repository.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';

/// 冷启动本地历史的回归测试：SQLite 里已经存在会话，但 Agent registry
/// 还没就绪（或还没探测出任何 Agent）。全程不连真实 SSH、不建 ACP 传输。
const _agentId = 'builtin-codex';

AgentProfile _profile(String id) => AgentProfile(
  id: id,
  serverId: 'srv-1',
  name: id,
  description: 'test agent',
  cliCommand: 'cli',
  acpCommand: 'acp --stdio',
);

/// 就绪集合与 Agent 列表都可以在测试里改动，用来模拟延迟的 registry 引导。
class _MutableRegistry extends AgentRegistryNotifier {
  _MutableRegistry({
    List<AgentProfile> profiles = const [],
    Set<String> ready = const {},
  }) : profiles = [...profiles],
       readyIds = {...ready};

  List<AgentProfile> profiles;
  final Set<String> readyIds;

  void publish(List<AgentProfile> next, {Set<String> ready = const {}}) {
    profiles = [...next];
    readyIds
      ..clear()
      ..addAll(ready);
    ref.invalidateSelf();
  }

  void markReady(String agentId) {
    readyIds.add(agentId);
    ref.invalidateSelf();
  }

  @override
  AgentRegistryState build() => AgentRegistryState(
    serverId: 'srv-1',
    agents: [
      for (final profile in profiles)
        AgentRuntimeState(
          profile: profile,
          status: AgentEnvironmentStatus(
            kind: readyIds.contains(profile.id)
                ? AgentEnvironmentStatusKind.ready
                : AgentEnvironmentStatusKind.cliMissing,
            checkedAt: DateTime.utc(2026),
          ),
        ),
    ],
  );
}

class _StubActiveServer extends ActiveServerNotifier {
  @override
  ServerProfile? build() => const ServerProfile(
    id: 'srv-1',
    name: 'test server',
    host: 'example.test',
    username: 'root',
  );
}

/// 记录每一次 SSH 客户端索取：冷恢复不允许它发生。
class _SpySshManager extends SSHClientManager {
  _SpySshManager(LocalStorageService storage)
    : super(SSHHostKeyVerifier(storage));

  final requested = <String>[];

  @override
  SSHClient? getClient(String serverId) {
    requested.add(serverId);
    throw StateError('cold history must not open SSH for $serverId');
  }
}

class _StaticConnection extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() =>
      const ServerConnectionState(status: ConnectionStateEnum.disconnected);
}

ChatMessage _message(String id, String content) => ChatMessage(
  id: id,
  agentId: _agentId,
  role: MessageRole.user,
  content: content,
  createdAt: DateTime.utc(2026, 10, 20),
);

ChatSession _session(String id, List<String> contents) => ChatSession(
  id: id,
  title: id,
  serverId: 'srv-1',
  agentId: _agentId,
  createdAt: DateTime.utc(2026, 10, 20),
  updatedAt: DateTime.utc(2026, 10, 21),
  messages: [
    for (var index = 0; index < contents.length; index++)
      _message('$id-$index', contents[index]),
  ],
  totalMessageCount: contents.length,
);

/// 等历史加载真正结束：先触发一次读，否则 build 排下的刷新 microtask 还没
/// 跑，`isLoadingSessions` 仍然是 false 就直接返回，断言踩在加载之前。
Future<void> _settle(ProviderContainer container) async {
  container.read(aiChatProvider);
  await pumpEventQueue();
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (container.read(aiChatProvider).isLoadingSessions ||
      container.read(aiChatProvider).isLoadingMessages) {
    if (DateTime.now().isAfter(deadline)) {
      fail('history loading never settled');
    }
    await pumpEventQueue();
  }
}

/// 写入一批会话后返回一个**全新**的 repository：provider 拿到的是另一个
/// 实例，磁盘上的 SQLite 是两者之间唯一的共享状态，即真正的冷启动。
Future<ChatRepository> _seededRepository(
  LocalStorageService storage,
  List<ChatSession> sessions,
) async {
  final directory = Directory.systemTemp.createTempSync(
    'valhalla_cold_history_',
  );
  addTearDown(() async {
    // SQLite 可能还在落 WAL：短暂重试后再删，避免 ENOTEMPTY 污染断言。
    for (var attempt = 0; directory.existsSync() && attempt < 6; attempt++) {
      try {
        directory.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  });
  final path = '${directory.path}/chat.sqlite3';
  final seeder = ChatRepository(storage, databasePath: path);
  for (final session in sessions) {
    await seeder.saveSession(session);
  }
  return ChatRepository(storage, databasePath: path);
}

Future<ProviderContainer> _coldContainer({
  required LocalStorageService storage,
  required ChatRepository repository,
  required _MutableRegistry registry,
  required _SpySshManager ssh,
}) async {
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage),
      chatRepositoryProvider.overrideWithValue(repository),
      agentRegistryProvider.overrideWith(() => registry),
      activeServerProvider.overrideWith(_StubActiveServer.new),
      serverConnectionProvider.overrideWith(() => _StaticConnection()),
      sshClientManagerProvider.overrideWithValue(ssh),
      acpTransportFactoryProvider.overrideWithValue((
        _,
        _, {
        String? initialModelId,
      }) {
        throw StateError('cold history must not start an ACP transport');
      }),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('registry 未就绪时冷启动仍显示已持久化的历史与消息', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorageService(await SharedPreferences.getInstance());
    final repository = await _seededRepository(storage, [
      _session('session-a', ['cold question', 'cold answer']),
    ]);
    final registry = _MutableRegistry(profiles: [_profile(_agentId)]);
    final ssh = _SpySshManager(storage);
    final container = await _coldContainer(
      storage: storage,
      repository: repository,
      registry: registry,
      ssh: ssh,
    );
    await _settle(container);

    final state = container.read(aiChatProvider);
    expect(state.readyAgents, isEmpty, reason: '前提：registry 还没就绪');
    expect(
      state.activeAgentProfile?.id,
      _agentId,
      reason: '已配置但未就绪的 Agent 仍然可以承载本地历史',
    );
    expect(state.sessions.map((s) => s.id), ['session-a']);
    expect(state.activeSessionId, 'session-a');
    expect(state.activeSession!.messages.map((m) => m.content), [
      'cold question',
      'cold answer',
    ]);
    expect(state.isLoadingSessions, isFalse);
    expect(state.isLoadingMessages, isFalse);
    expect(state.lastErrorCode, isNull);
    expect(ssh.requested, isEmpty, reason: '冷恢复不得索取 SSH 连接');
  });

  test('registry 引导完全延迟：先无 Agent，随后发布时补上历史与消息', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorageService(await SharedPreferences.getInstance());
    final repository = await _seededRepository(storage, [
      _session('session-a', ['cold question', 'cold answer']),
    ]);
    final registry = _MutableRegistry();
    final ssh = _SpySshManager(storage);
    final container = await _coldContainer(
      storage: storage,
      repository: repository,
      registry: registry,
      ssh: ssh,
    );
    await _settle(container);

    final before = container.read(aiChatProvider);
    expect(before.activeAgentProfile, isNull, reason: '前提：registry 还没发布');
    expect(before.sessions, isEmpty);
    expect(before.activeSession, isNull);

    registry.publish([_profile(_agentId)]);
    await _settle(container);

    final after = container.read(aiChatProvider);
    expect(after.activeAgentProfile?.id, _agentId);
    expect(after.sessions.map((s) => s.id), ['session-a']);
    expect(after.activeSessionId, 'session-a');
    expect(after.activeSession!.messages.map((m) => m.content), [
      'cold question',
      'cold answer',
    ]);
    expect(after.lastErrorCode, isNull);
    expect(ssh.requested, isEmpty);
  });

  test('registry 从空到就绪的延迟期间，选择与消息不被后续就绪事件冲掉', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorageService(await SharedPreferences.getInstance());
    final repository = await _seededRepository(storage, [
      _session('session-a', ['cold question', 'cold answer']),
      _session('session-b', ['second question']),
    ]);
    final registry = _MutableRegistry(profiles: [_profile(_agentId)]);
    final ssh = _SpySshManager(storage);
    final container = await _coldContainer(
      storage: storage,
      repository: repository,
      registry: registry,
      ssh: ssh,
    );
    await _settle(container);

    final notifier = container.read(aiChatProvider.notifier);
    await notifier.selectSession('session-b');
    await _settle(container);
    expect(
      container
          .read(aiChatProvider)
          .activeSession!
          .messages
          .map((m) => m.content),
      ['second question'],
    );

    // 安装完成让 Agent 变成 ready：registry 变化不得清掉选择与已存消息。
    registry.markReady(_agentId);
    await _settle(container);

    final after = container.read(aiChatProvider);
    expect(after.readyAgents.map((a) => a.id), [_agentId]);
    expect(after.activeAgentProfile?.id, _agentId);
    expect(after.activeSessionId, 'session-b');
    expect(after.activeSession!.messages.map((m) => m.content), [
      'second question',
    ]);
    expect(after.lastErrorCode, isNull);
    expect(ssh.requested, isEmpty);
  });
}
