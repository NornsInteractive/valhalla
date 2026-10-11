import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/agent_registry_provider.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';

import '../support/temp_chat_db.dart';

/// 草稿写入的存储替身：前 [failures] 次 `saveChatDraft` 抛错，之后正常。
///
/// SharedPreferences 的 mock 不会失败，要验证「一次写失败之后还能写」
/// 只能在这一层注入失败。
class _FlakyDraftStorage extends LocalStorageService {
  _FlakyDraftStorage(super.prefs, this.failures);

  int failures;
  final saved = <String, Map<String, dynamic>>{};

  @override
  Future<void> saveChatDraft(String key, Map<String, dynamic> value) async {
    if (failures > 0) {
      failures--;
      throw StateError('CHAT_DRAFT_SAVE_FAILED');
    }
    saved[key] = value;
  }
}

class _FakeRegistry extends AgentRegistryNotifier {
  static final profile = AgentProfile(
    id: 'builtin-codex',
    serverId: 'srv-1',
    name: 'codex',
    description: 'desc',
    cliCommand: 'cli',
    acpCommand: 'acp --stdio',
  );

  @override
  AgentRegistryState build() => AgentRegistryState(
    serverId: 'srv-1',
    agents: [
      AgentRuntimeState(
        profile: profile,
        status: AgentEnvironmentStatus(
          kind: AgentEnvironmentStatusKind.ready,
          checkedAt: DateTime.utc(2026),
        ),
      ),
    ],
  );
}

class _FakeSshManager extends SSHClientManager {
  _FakeSshManager(LocalStorageService storage)
    : super(SSHHostKeyVerifier(storage));
}

class _Disconnected extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() =>
      const ServerConnectionState(status: ConnectionStateEnum.disconnected);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<ProviderContainer> container(_FlakyDraftStorage storage) async {
    final c = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        tempChatRepositoryOverride(),
        agentRegistryProvider.overrideWith(_FakeRegistry.new),
        serverConnectionProvider.overrideWith(_Disconnected.new),
        sshClientManagerProvider.overrideWith(
          (ref) => _FakeSshManager(ref.read(localStorageServiceProvider)),
        ),
        acpTransportFactoryProvider.overrideWithValue((_, _) {
          throw StateError('this test must not create a transport');
        }),
      ],
    );
    return c;
  }

  test(
    'a failed checkpoint does not poison the next debounced draft save',
    () async {
      // 草稿写入串在同一条 `_draftSaveChain` 上。如果 checkpoint 失败时把
      // 失败的 future 留进链里，之后**每一次**去抖保存都会被短路跳过，
      // 用户从此再也存不住草稿——重启就丢内容。
      late _FlakyDraftStorage storage;
      final flakyStorage = _FlakyDraftStorage(prefs, 1);
      final c = await container(flakyStorage);
      storage = flakyStorage;
      addTearDown(c.dispose);
      final notifier = c.read(aiChatProvider.notifier);
      await pumpEventQueue();

      await notifier.checkpoint();
      await pumpEventQueue();
      expect(
        c.read(aiChatProvider).lastErrorCode,
        contains('CHAT_SAVE_FAILED'),
        reason: '失败的 checkpoint 必须如实报出来，不能静默吞掉',
      );
      expect(storage.saved, isEmpty);

      notifier.updateDraftText('typed after the failure');
      await Future<void>.delayed(const Duration(milliseconds: 700));
      await pumpEventQueue();

      expect(
        storage.saved.values.single['text'],
        'typed after the failure',
        reason: '一次失败不能让后续去抖保存永久失效',
      );
    },
  );

  test(
    'repeated checkpoint failures still leave later saves working',
    () async {
      late _FlakyDraftStorage storage;
      final flakyStorage = _FlakyDraftStorage(prefs, 3);
      final c = await container(flakyStorage);
      storage = flakyStorage;
      addTearDown(c.dispose);
      final notifier = c.read(aiChatProvider.notifier);
      await pumpEventQueue();

      for (var i = 0; i < 3; i++) {
        await notifier.checkpoint();
        await pumpEventQueue();
      }
      expect(storage.saved, isEmpty);

      notifier.updateDraftText('eventually saved');
      await Future<void>.delayed(const Duration(milliseconds: 700));
      await pumpEventQueue();

      expect(storage.saved.values.single['text'], 'eventually saved');
    },
  );
}
