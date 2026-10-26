import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/data/models/chat_workspace.dart';

final _now = DateTime.utc(2026, 10, 26);

ChatSession _session(
  String id, {
  String? serverId = 'server-1',
  String directory = '/proj',
  String? executionKey = 'exec-1',
  String? agentId = 'agent-1',
}) => ChatSession(
  id: id,
  title: 'Session $id',
  serverId: serverId,
  workingDirectory: directory,
  executionKey: executionKey,
  agentId: agentId,
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  group('ChatWorkspace - grouping', () {
    test('two servers and two execution environments yield three groups', () {
      final workspaces = ChatWorkspace.group([
        _session('a'),
        _session('b'),
        _session('c', executionKey: 'exec-2'),
        _session('d', serverId: 'server-2'),
      ]);

      expect(workspaces, hasLength(3));

      final primary = workspaces.singleWhere(
        (workspace) =>
            workspace.key == jsonEncode(['server-1', 'exec-1', '/proj']),
      );
      expect(primary.serverId, 'server-1');
      expect(primary.executionKey, 'exec-1');
      expect(primary.directory, '/proj');
      expect(primary.sessions.map((session) => session.id), ['a', 'b']);
    });

    test('same execution key on different servers stays isolated', () {
      final workspaces = ChatWorkspace.group([
        _session('a', serverId: 'server-1'),
        _session('b', serverId: 'server-2'),
      ]);
      expect(workspaces, hasLength(2));
      expect(workspaces.map((workspace) => workspace.serverId).toSet(), {
        'server-1',
        'server-2',
      });
    });

    test('sessions without a server are not grouped', () {
      final workspaces = ChatWorkspace.group([
        _session('a', serverId: null),
        _session('b'),
      ]);
      expect(workspaces, hasLength(1));
      expect(workspaces.single.sessions.single.id, 'b');
    });

    test('absolute working directory is normalized', () {
      final workspaces = ChatWorkspace.group([
        _session('a', directory: '/proj//sub//'),
      ]);
      expect(workspaces.single.directory, '/proj/sub');
    });

    test('relative working directory falls back to dot', () {
      final workspaces = ChatWorkspace.group([
        _session('a', directory: 'relative/path'),
      ]);
      expect(workspaces.single.directory, '.');
    });
  });

  group('ChatWorkspace - server and container isolation', () {
    AgentProfile profile({
      String executionTarget = 'host',
      String containerBinding = 'name',
      String? containerReference,
      String? containerUser,
      String cliCommand = 'claude --acp',
    }) => AgentProfile(
      id: 'profile',
      serverId: 'server-1',
      name: 'Agent',
      description: 'Test agent',
      cliCommand: cliCommand,
      executionTarget: executionTarget,
      containerBinding: containerBinding,
      containerReference: containerReference,
      containerUser: containerUser,
      createdAt: _now,
      updatedAt: _now,
    );

    test('container identity changes the execution key', () {
      final first = profile(
        executionTarget: 'docker',
        containerBinding: 'id',
        containerReference: 'container-a',
        containerUser: '1000',
      );
      final second = first.copyWith(containerReference: 'container-b');
      final sameContainerNewCli = first.copyWith(cliCommand: 'codex --acp');

      expect(chatExecutionKey(first), isNot(chatExecutionKey(second)));
      expect(chatExecutionKey(first), chatExecutionKey(sameContainerNewCli));
    });

    test('host and container sessions produce separate groups', () {
      final host = profile();
      final dockerA = profile(
        executionTarget: 'docker',
        containerReference: 'container-a',
      );
      final dockerB = dockerA.copyWith(containerReference: 'container-b');

      final workspaces = ChatWorkspace.group([
        _session('host', executionKey: chatExecutionKey(host)),
        _session('docker-a', executionKey: chatExecutionKey(dockerA)),
        _session('docker-b', executionKey: chatExecutionKey(dockerB)),
      ]);

      expect(workspaces, hasLength(3));
      expect(workspaces.map((workspace) => workspace.executionKey).toSet(), {
        chatExecutionKey(host),
        chatExecutionKey(dockerA),
        chatExecutionKey(dockerB),
      });
    });
  });

  group('ChatWorkspace - legacy JSON', () {
    test(
      'legacy session JSON keeps agent id without inventing execution key',
      () {
        final session = ChatSession.fromJson({
          'id': 'legacy-1',
          'title': 'Legacy session',
          'serverId': 'server-1',
          'workingDirectory': '/proj//sub//',
          'agentType': 'codex',
          'createdAt': _now.toIso8601String(),
          'updatedAt': _now.toIso8601String(),
          'messages': <dynamic>[],
        });

        expect(session.agentId, 'builtin-codex');
        expect(session.executionKey, isNull);

        final workspace = ChatWorkspace.group([session]).single;
        expect(workspace.executionKey, 'legacy:builtin-codex');
        expect(workspace.directory, '/proj/sub');
        expect(
          workspace.key,
          jsonEncode(['server-1', 'legacy:builtin-codex', '/proj/sub']),
        );
      },
    );

    test(
      'session JSON roundtrip preserves execution key and workspace identity',
      () {
        final original = ChatSession.fromJson({
          'id': 'session-1',
          'title': 'Session',
          'serverId': 'server-2',
          'workingDirectory': '/srv/app',
          'executionKey': chatExecutionKey(
            AgentProfile(
              id: 'profile',
              serverId: 'server-2',
              name: 'Agent',
              description: 'Test agent',
              cliCommand: 'claude --acp',
              executionTarget: 'docker',
              containerReference: 'container-x',
              createdAt: _now,
              updatedAt: _now,
            ),
          ),
          'agentId': 'builtin-codex',
          'createdAt': _now.toIso8601String(),
          'updatedAt': _now.toIso8601String(),
          'messages': <dynamic>[],
        });

        final restored = ChatSession.fromJson(original.toJson());
        expect(restored.executionKey, original.executionKey);
        expect(restored.agentId, original.agentId);

        final workspace = ChatWorkspace.group([restored]).single;
        expect(workspace.serverId, 'server-2');
        expect(workspace.executionKey, original.executionKey);
        expect(workspace.directory, '/srv/app');
        expect(
          workspace.key,
          jsonEncode(['server-2', original.executionKey, '/srv/app']),
        );
      },
    );
  });
}
