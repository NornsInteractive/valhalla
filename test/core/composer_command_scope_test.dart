import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/data/models/chat_workspace.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/infrastructure/acp/acp_attachment_store.dart';
import 'package:valhalla/infrastructure/acp/acp_client_adapter.dart';

const _server1 = ServerProfile(
  id: 'srv-1',
  name: 'server one',
  host: 'one.test',
  username: 'root',
);

const _server2 = ServerProfile(
  id: 'srv-2',
  name: 'server two',
  host: 'two.test',
  username: 'root',
);

AgentProfile _profile(
  String id, {
  String serverId = 'srv-1',
  String cliCommand = 'cli',
  String executionTarget = 'host',
  String? containerReference,
  String? containerUser,
}) => AgentProfile(
  id: id,
  serverId: serverId,
  name: id,
  description: 'test agent',
  cliCommand: cliCommand,
  acpCommand: 'acp --stdio',
  executionTarget: executionTarget,
  containerReference: containerReference,
  containerUser: containerUser,
);

String _keyFor(ServerProfile server, AgentProfile profile) =>
    jsonEncode([server.id, profile.id, chatExecutionKey(profile)]);

class _FakeActiveServer extends ActiveServerNotifier {
  _FakeActiveServer(this._server);

  ServerProfile? _server;

  @override
  ServerProfile? build() => _server;

  void switchTo(ServerProfile? next) {
    _server = next;
    state = next;
  }
}

class _FakeAiChat extends AiChatNotifier {
  _FakeAiChat(this._profile);

  AgentProfile? _profile;

  @override
  AiChatState build() => AiChatState(activeAgentProfile: _profile);

  /// Test-only state seeding; production methods still run against it.
  void debugSetState(AiChatState next) {
    state = next;
  }

  void selectProfile(AgentProfile? profile) {
    _profile = profile;
    state = state.copyWith(
      activeAgentProfile: profile,
      clearActiveAgent: profile == null,
    );
  }

  void setWorkingDirectory(String? directory) {
    state = state.copyWith(
      draftWorkingDirectory: directory,
      clearDraftWorkingDirectory: directory == null,
    );
  }
}

class _MemoryAttachmentStore extends AcpAttachmentStore {
  @override
  Future<ChatAttachment> save(
    String name,
    String mimeType,
    Uint8List bytes, {
    String? uri,
  }) async => ChatAttachment(
    id: name,
    name: name,
    mimeType: mimeType,
    sizeBytes: bytes.length,
    uri: uri,
  );
}

Future<LocalStorageService> _storage() async {
  SharedPreferences.setMockInitialValues({});
  return LocalStorageService(await SharedPreferences.getInstance());
}

ProviderContainer _container({
  required LocalStorageService storage,
  required _FakeActiveServer server,
  required _FakeAiChat chat,
  AcpAttachmentStore? attachmentStore,
}) => ProviderContainer(
  overrides: [
    localStorageServiceProvider.overrideWithValue(storage),
    activeServerProvider.overrideWith(() => server),
    aiChatProvider.overrideWith(() => chat),
    acpAttachmentStoreProvider.overrideWithValue(
      attachmentStore ?? _MemoryAttachmentStore(),
    ),
  ],
);

Matcher get _targetChanged => throwsA(
  isA<StateError>().having(
    (error) => error.message,
    'message',
    'ACP_TARGET_CHANGED',
  ),
);

void main() {
  test(
    'namespace changes with server, agent, docker target and user',
    () async {
      final storage = await _storage();
      final server = _FakeActiveServer(_server1);
      final host = _profile('agent-1');
      final chat = _FakeAiChat(host);
      final container = _container(
        storage: storage,
        server: server,
        chat: chat,
      );
      addTearDown(container.dispose);

      final notifier = container.read(aiChatProvider.notifier);
      final hostKey = _keyFor(_server1, host);
      expect(notifier.commandPreferenceKey, hostKey);

      final otherAgent = _profile('agent-2');
      chat.selectProfile(otherAgent);
      expect(notifier.commandPreferenceKey, _keyFor(_server1, otherAgent));
      expect(notifier.commandPreferenceKey, isNot(hostKey));

      final agentOnServer2 = _profile('agent-2', serverId: 'srv-2');
      server.switchTo(_server2);
      chat.selectProfile(agentOnServer2);
      final serverKey = _keyFor(_server2, agentOnServer2);
      expect(notifier.commandPreferenceKey, serverKey);
      expect(
        notifier.commandPreferenceKey,
        isNot(_keyFor(_server1, otherAgent)),
      );

      final docker = agentOnServer2.copyWith(
        executionTarget: 'docker',
        containerReference: 'container-1',
      );
      chat.selectProfile(docker);
      final dockerKey = _keyFor(_server2, docker);
      expect(notifier.commandPreferenceKey, dockerKey);
      expect(notifier.commandPreferenceKey, isNot(serverKey));

      final dockerUser = docker.copyWith(containerUser: 'root');
      chat.selectProfile(dockerUser);
      expect(notifier.commandPreferenceKey, _keyFor(_server2, dockerUser));
      expect(notifier.commandPreferenceKey, isNot(dockerKey));
    },
  );

  test('CLI upgrade and working directory do not change the key', () async {
    final storage = await _storage();
    final server = _FakeActiveServer(_server1);
    final profile = _profile('agent-1');
    final chat = _FakeAiChat(profile);
    final container = _container(storage: storage, server: server, chat: chat);
    addTearDown(container.dispose);

    final notifier = container.read(aiChatProvider.notifier);
    final original = notifier.commandPreferenceKey;
    expect(original, _keyFor(_server1, profile));

    chat.selectProfile(profile.copyWith(cliCommand: 'cli-upgraded'));
    expect(notifier.commandPreferenceKey, original);

    chat.setWorkingDirectory('/srv/project');
    expect(notifier.commandPreferenceKey, original);

    chat.setWorkingDirectory('/srv/another-project');
    expect(notifier.commandPreferenceKey, original);
  });

  test('stale expectedScopeKey is rejected before any write', () async {
    final storage = await _storage();
    final server = _FakeActiveServer(_server1);
    final profile = _profile('agent-1');
    final chat = _FakeAiChat(profile);
    final container = _container(storage: storage, server: server, chat: chat);
    addTearDown(container.dispose);

    final notifier = container.read(aiChatProvider.notifier);
    final staleKey = notifier.commandPreferenceKey!;

    chat.selectProfile(_profile('agent-2'));
    expect(notifier.commandPreferenceKey, isNot(staleKey));

    await expectLater(
      notifier.setCommandFavorite(
        'skill:review',
        true,
        expectedScopeKey: staleKey,
      ),
      _targetChanged,
    );
    await expectLater(
      notifier.recordCommandUse('skill:review', expectedScopeKey: staleKey),
      _targetChanged,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getKeys().where((key) => key.startsWith('valhalla_composer_v1::')),
      isEmpty,
    );
    expect(notifier.commandPreferences.favorites, isEmpty);
    expect(notifier.commandPreferences.recent, isEmpty);
  });

  test(
    'mismatched profile server yields null key and empty defaults',
    () async {
      final storage = await _storage();
      final server = _FakeActiveServer(_server1);
      final chat = _FakeAiChat(_profile('agent-1', serverId: 'srv-2'));
      final container = _container(
        storage: storage,
        server: server,
        chat: chat,
      );
      addTearDown(container.dispose);

      final notifier = container.read(aiChatProvider.notifier);
      expect(notifier.commandPreferenceKey, isNull);
      expect(notifier.commandPreferences.favorites, isEmpty);
      expect(notifier.commandPreferences.recent, isEmpty);

      await expectLater(
        notifier.setCommandFavorite(
          'skill:review',
          true,
          expectedScopeKey: 'anything',
        ),
        _targetChanged,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where(
          (key) => key.startsWith('valhalla_composer_v1::'),
        ),
        isEmpty,
      );
    },
  );

  test('missing server or missing profile yields null key', () async {
    final withoutServerStorage = await _storage();
    final withoutServer = _container(
      storage: withoutServerStorage,
      server: _FakeActiveServer(null),
      chat: _FakeAiChat(_profile('agent-1')),
    );
    addTearDown(withoutServer.dispose);
    final withoutServerNotifier = withoutServer.read(aiChatProvider.notifier);
    expect(withoutServerNotifier.commandPreferenceKey, isNull);
    expect(withoutServerNotifier.commandPreferences.favorites, isEmpty);
    expect(withoutServerNotifier.commandPreferences.recent, isEmpty);

    final withoutProfileStorage = await _storage();
    final withoutProfile = _container(
      storage: withoutProfileStorage,
      server: _FakeActiveServer(_server1),
      chat: _FakeAiChat(null),
    );
    addTearDown(withoutProfile.dispose);
    final withoutProfileNotifier = withoutProfile.read(aiChatProvider.notifier);
    expect(withoutProfileNotifier.commandPreferenceKey, isNull);
    expect(withoutProfileNotifier.commandPreferences.favorites, isEmpty);
    expect(withoutProfileNotifier.commandPreferences.recent, isEmpty);
  });

  test('writes and reads are scoped to the current key', () async {
    final storage = await _storage();
    final server = _FakeActiveServer(_server1);
    final profile = _profile('agent-1');
    final chat = _FakeAiChat(profile);
    final container = _container(storage: storage, server: server, chat: chat);
    addTearDown(container.dispose);

    final notifier = container.read(aiChatProvider.notifier);
    final key = notifier.commandPreferenceKey!;

    await notifier.setCommandFavorite(
      'skill:review',
      true,
      expectedScopeKey: key,
    );
    await notifier.recordCommandUse('command:review', expectedScopeKey: key);

    final written = notifier.commandPreferences;
    expect(written.favorites, {'skill:review'});
    expect(written.recent, ['command:review']);

    chat.selectProfile(_profile('agent-2'));
    expect(notifier.commandPreferences.favorites, isEmpty);
    expect(notifier.commandPreferences.recent, isEmpty);

    chat.selectProfile(profile);
    final restored = notifier.commandPreferences;
    expect(restored.favorites, {'skill:review'});
    expect(restored.recent, ['command:review']);
  });

  test(
    'clearDraftWorkingDirectory resets the directory but keeps text and attachments',
    () async {
      final storage = await _storage();
      final server = _FakeActiveServer(_server1);
      final profile = _profile('agent-1');
      final chat = _FakeAiChat(profile);
      final container = _container(
        storage: storage,
        server: server,
        chat: chat,
      );
      addTearDown(container.dispose);
      final notifier = container.read(aiChatProvider.notifier);

      notifier.setDraftWorkingDirectory('/srv/project');
      notifier.updateDraftText('unsent draft');
      chat.debugSetState(
        container
            .read(aiChatProvider)
            .copyWith(
              attachments: [
                AcpPromptAttachment(
                  name: 'notes.txt',
                  mimeType: 'text/plain',
                  bytes: Uint8List.fromList([1, 2, 3]),
                ),
              ],
            ),
      );

      expect(
        container.read(aiChatProvider).draftWorkingDirectory,
        '/srv/project',
      );

      notifier.clearDraftWorkingDirectory();

      final after = container.read(aiChatProvider);
      expect(after.draftWorkingDirectory, isNull);
      expect(after.draftText, 'unsent draft');
      expect(after.attachments, hasLength(1));
      expect(after.attachments.single.name, 'notes.txt');
      expect(after.attachments.single.bytes, [1, 2, 3]);

      await Future<void>.delayed(const Duration(milliseconds: 500));
      await pumpEventQueue();

      final saved = storage.getChatDraft('srv-1::agent-1::draft');
      expect(saved, isNotNull);
      expect(saved!['directory'], isNull);
      expect(saved['text'], 'unsent draft');
      final savedAttachments = saved['attachments'] as List;
      expect(savedAttachments, hasLength(1));
      expect(savedAttachments.single['name'], 'notes.txt');
    },
  );

  test(
    'clearDraftWorkingDirectory is rejected while busy or in a session',
    () async {
      final storage = await _storage();

      final busyStates = <String, AiChatState Function(AiChatState)>{
        'generating': (state) => state.copyWith(isGenerating: true),
        'authenticating': (state) => state.copyWith(isAuthenticating: true),
        'loading settings': (state) => state.copyWith(isLoadingSettings: true),
        'applying settings': (state) =>
            state.copyWith(isApplyingSettings: true),
      };

      for (final entry in busyStates.entries) {
        final chat = _FakeAiChat(_profile('agent-1'));
        final container = _container(
          storage: storage,
          server: _FakeActiveServer(_server1),
          chat: chat,
        );
        final notifier = container.read(aiChatProvider.notifier);
        chat.debugSetState(
          entry.value(
            container
                .read(aiChatProvider)
                .copyWith(draftWorkingDirectory: '/srv/project'),
          ),
        );
        final before = container.read(aiChatProvider);

        notifier.clearDraftWorkingDirectory();

        expect(
          identical(container.read(aiChatProvider), before),
          isTrue,
          reason: entry.key,
        );
        expect(
          container.read(aiChatProvider).draftWorkingDirectory,
          '/srv/project',
          reason: entry.key,
        );
        expect(storage.getChatDraft('srv-1::agent-1::draft'), isNull);
        container.dispose();
      }

      final chat = _FakeAiChat(_profile('agent-1'));
      final container = _container(
        storage: storage,
        server: _FakeActiveServer(_server1),
        chat: chat,
      );
      final notifier = container.read(aiChatProvider.notifier);
      final session = ChatSession(
        id: 'session-1',
        title: 'existing',
        serverId: 'srv-1',
        workingDirectory: '/srv/project',
        agentId: 'agent-1',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      chat.debugSetState(
        container
            .read(aiChatProvider)
            .copyWith(
              sessions: [session],
              activeSessionId: session.id,
              draftWorkingDirectory: '/srv/project',
            ),
      );
      final before = container.read(aiChatProvider);

      notifier.clearDraftWorkingDirectory();

      expect(identical(container.read(aiChatProvider), before), isTrue);
      expect(
        container.read(aiChatProvider).draftWorkingDirectory,
        '/srv/project',
      );
      expect(storage.getChatDraft('srv-1::agent-1::draft'), isNull);
      container.dispose();
    },
  );

  test('commandPreferenceKey is unchanged by clearing the directory', () async {
    final storage = await _storage();
    final server = _FakeActiveServer(_server1);
    final profile = _profile('agent-1');
    final chat = _FakeAiChat(profile);
    final container = _container(storage: storage, server: server, chat: chat);
    addTearDown(container.dispose);
    final notifier = container.read(aiChatProvider.notifier);

    chat.debugSetState(
      container
          .read(aiChatProvider)
          .copyWith(draftWorkingDirectory: '/srv/project'),
    );
    final before = notifier.commandPreferenceKey;
    expect(before, _keyFor(_server1, profile));

    notifier.clearDraftWorkingDirectory();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await pumpEventQueue();

    expect(container.read(aiChatProvider).draftWorkingDirectory, isNull);
    expect(notifier.commandPreferenceKey, before);
  });
}
