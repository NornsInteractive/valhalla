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

import '../support/fake_acp_transport.dart';

/// 「活动任务不得阻止已存消息加载」的回归测试。
///
/// 一轮远端 prompt 被挂住（= 恢复中的任务正在生成）时，切换到另一个只有
/// 本地持久化记录的会话，它的消息必须照常从 SQLite 读出来。全程使用内存里
/// 的假 ACP 传输：不连真实 SSH、不碰真实 tmux。
const _agentId = 'builtin-codex';

AgentProfile _profile(String id) => AgentProfile(
  id: id,
  serverId: 'srv-1',
  name: id,
  description: 'test agent',
  cliCommand: 'cli',
  acpCommand: 'acp --stdio',
);

class _ReadyRegistry extends AgentRegistryNotifier {
  @override
  AgentRegistryState build() => AgentRegistryState(
    serverId: 'srv-1',
    agents: [
      AgentRuntimeState(
        profile: _profile(_agentId),
        status: AgentEnvironmentStatus(
          kind: AgentEnvironmentStatusKind.ready,
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

class _ConnectedConnection extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() => const ServerConnectionState(
    status: ConnectionStateEnum.connected,
    activeServerId: 'srv-1',
  );
}

class _FakeSshManager extends SSHClientManager {
  _FakeSshManager(LocalStorageService storage)
    : super(SSHHostKeyVerifier(storage));

  @override
  SSHClient? getClient(String serverId) => _FakeSshClient();
}

class _FakeSshClient implements SSHClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

Future<ChatRepository> _seededRepository(
  LocalStorageService storage,
  List<ChatSession> sessions,
) async {
  final directory = Directory.systemTemp.createTempSync(
    'valhalla_generating_history_',
  );
  addTearDown(() async {
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

void main() {
  test('恢复中的任务生成时，另一个会话的已存消息仍然加载', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorageService(await SharedPreferences.getInstance());
    final repository = await _seededRepository(storage, [
      _session('session-a', ['cold question', 'cold answer']),
      _session('session-b', ['second question']),
    ]);
    final pairs = <FakeAcpPair>[];
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        chatRepositoryProvider.overrideWithValue(repository),
        agentRegistryProvider.overrideWith(() => _ReadyRegistry()),
        activeServerProvider.overrideWith(_StubActiveServer.new),
        serverConnectionProvider.overrideWith(() => _ConnectedConnection()),
        sshClientManagerProvider.overrideWithValue(_FakeSshManager(storage)),
        acpTransportFactoryProvider.overrideWithValue((
          _,
          _, {
          String? initialModelId,
        }) async {
          final pair = FakeAcpPair(sessionId: 'remote-1')..holdPrompt = true;
          pairs.add(pair);
          return pair.client;
        }),
      ],
    );
    addTearDown(container.dispose);
    await _settle(container);

    final notifier = container.read(aiChatProvider.notifier);
    final cold = container.read(aiChatProvider);
    expect(cold.activeSessionId, 'session-a');
    expect(cold.activeSession!.messages.map((m) => m.content), [
      'cold question',
      'cold answer',
    ]);
    final untouched = cold.sessions.firstWhere((s) => s.id == 'session-b');
    expect(
      untouched.messages,
      isEmpty,
      reason: '前提：listSessions 不带消息，未选中的会话在内存里还是空的',
    );

    // 一轮远端 prompt 被挂住：任务正在生成。
    final sending = notifier.sendMessage('long running turn');
    final transportDeadline = DateTime.now().add(const Duration(seconds: 10));
    while (pairs.isEmpty) {
      if (DateTime.now().isAfter(transportDeadline)) {
        fail('ACP transport never created');
      }
      await pumpEventQueue();
    }
    final pair = pairs.single;
    await pair.promptReceived.timeout(
      const Duration(seconds: 10),
      onTimeout: () => fail('远端没有收到 prompt'),
    );
    await _settle(container);
    expect(
      container.read(aiChatProvider).isGenerating,
      isTrue,
      reason: '前提：运行中的任务正在生成',
    );

    // 读另一个会话的本地历史：活动任务不得把这次加载挡掉。
    await notifier.selectSession('session-b');
    await _settle(container);

    final after = container.read(aiChatProvider);
    expect(after.activeSessionId, 'session-b');
    expect(
      after.activeSession!.messages.map((m) => m.content),
      ['second question'],
      reason: '已存消息必须在任务生成期间加载出来',
    );
    expect(after.isLoadingMessages, isFalse);
    expect(after.isLoadingSessions, isFalse);
    expect(after.lastErrorCode, isNull);
    expect(after.serverRun, isNotNull, reason: '加载历史不能把还在生成的任务取消掉');
    expect(after.serverRun!.sessionId, 'session-a');

    // 显式收尾，避免把一个悬空的远端 turn 留给后续测试。
    pair.finishHeldPrompt();
    await sending.timeout(
      const Duration(seconds: 10),
      onTimeout: () => fail('prompt 收尾后 sendMessage 仍未返回'),
    );
    await _settle(container);
    expect(container.read(aiChatProvider).lastErrorCode, isNull);
    expect(container.read(aiChatProvider).lastErrorCode, isNull);
  });
}
