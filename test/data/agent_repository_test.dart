import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/repositories/agent_repository.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';

AgentProfile _profile(String id, String serverId) => AgentProfile(
  id: id,
  serverId: serverId,
  name: id,
  description: 'desc',
  cliCommand: 'cli',
  acpCommand: 'acp',
);

Future<AgentRepository> _repository({Map<String, dynamic>? initial}) async {
  SharedPreferences.setMockInitialValues(
    (initial ?? {}).cast<String, Object>(),
  );
  final prefs = await SharedPreferences.getInstance();
  return AgentRepository(LocalStorageService(prefs));
}

void main() {
  test('AgentProfile JSON roundtrip preserves fields', () {
    final profile = AgentProfile(
      id: 'a',
      serverId: 's',
      name: 'Agent',
      description: 'Desc',
      cliCommand: 'run',
      acpCommand: 'acp',
      installCommand: 'install',
      loginCheckCommand: 'whoami',
      loginCommand: 'login',
      createdAt: DateTime.parse('2025-01-01T00:00:00Z'),
      updatedAt: DateTime.parse('2025-01-02T00:00:00Z'),
    );
    expect(AgentProfile.fromJson(profile.toJson()), profile);
  });

  test('repository isolates records by server', () async {
    final repository = await _repository();
    await repository.save(_profile('a', 's1'));
    await repository.save(_profile('b', 's2'));
    expect(repository.getAll('s1').map((e) => e.id), ['a']);
    expect(repository.find('s1', 'b'), isNull);
  });

  test('save updates and delete removes a profile', () async {
    final repository = await _repository();
    await repository.save(_profile('a', 's'));
    await repository.save(_profile('a', 's').copyWith(name: 'updated'));
    expect(repository.find('s', 'a')!.name, 'updated');
    await repository.delete('s', 'a');
    expect(repository.getAll('s'), isEmpty);
  });

  test('empty and malformed storage return empty lists', () async {
    expect((await _repository()).getAll('s'), isEmpty);
    expect(
      (await _repository(initial: {'valhalla_agents_v1': '{bad'})).getAll('s'),
      isEmpty,
    );
  });

  test(
    'legacy agent types migrate to stable built-in IDs without changing sessions',
    () async {
      final rawSessions = jsonEncode([
        {
          'id': 'session',
          'title': 'history',
          'agentType': 'codex',
          'createdAt': '2025-01-01T00:00:00.000Z',
          'updatedAt': '2025-01-01T00:00:00.000Z',
          'messages': [],
        },
        {
          'id': 'agy-session',
          'title': 'agy',
          'agentType': 'agy',
          'createdAt': '2025-01-01T00:00:00.000Z',
          'updatedAt': '2025-01-01T00:00:00.000Z',
          'messages': [],
        },
      ]);
      final repository = await _repository(
        initial: {'valhalla_chat_sessions_v1': rawSessions},
      );
      final profiles = repository.getAll('server');
      expect(
        profiles.map((p) => p.id),
        containsAll(['builtin-codex', 'builtin-agy']),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('valhalla_chat_sessions_v1'), rawSessions);
    },
  );

  test(
    'migrates all legacy values to explicit presets exactly once per server',
    () async {
      final raw = jsonEncode([
        for (final type in [
          'claudeCode',
          'Claude CodeX',
          'codex',
          'OpenAI Codex',
          'openCode',
          'OpenCode ACP',
          'agy',
        ])
          {
            'id': type,
            'title': type,
            'agentType': type,
            'createdAt': '2025-01-01T00:00:00.000Z',
            'updatedAt': '2025-01-01T00:00:00.000Z',
            'messages': [],
          },
      ]);
      final repository = await _repository(
        initial: {'valhalla_chat_sessions_v1': raw},
      );
      final first = repository.getAll('server');
      expect(first.map((p) => p.id).toSet(), {
        'builtin-claude-code',
        'builtin-codex',
        'builtin-opencode',
        'builtin-agy',
      });
      expect(
        first.firstWhere((p) => p.id == 'builtin-claude-code').cliCommand,
        'claude',
      );
      expect(
        first.firstWhere((p) => p.id == 'builtin-claude-code').acpCommand,
        'claude-code-acp',
      );
      expect(repository.getAll('other'), isEmpty);
      await repository.delete('server', 'builtin-codex');
      expect(
        repository.getAll('server').map((p) => p.id),
        isNot(contains('builtin-codex')),
      );
    },
  );

  test('migrated profiles carry full install and login commands', () async {
    final raw = jsonEncode([
      {
        'id': 's',
        'title': 's',
        'agentType': 'codex',
        'createdAt': '2025-01-01T00:00:00.000Z',
        'updatedAt': '2025-01-01T00:00:00.000Z',
        'messages': [],
      },
    ]);
    final repository = await _repository(
      initial: {'valhalla_chat_sessions_v1': raw},
    );

    final codex = repository.getAll('server').single;

    expect(codex.id, 'builtin-codex');
    expect(codex.installCommand, 'npm install -g @openai/codex');
    expect(
      codex.acpInstallCommand,
      'npm install -g @agentclientprotocol/codex-acp',
    );
    expect(codex.loginCheckCommand, 'codex login status');
    expect(codex.loginCommand, 'codex login');
  });

  test('backfills missing commands for an existing builtin profile', () async {
    final repository = await _repository();
    await repository.save(
      AgentProfile(
        id: 'builtin-codex',
        serverId: 's',
        name: 'OpenAI Codex',
        description: 'desc',
        cliCommand: 'codex',
        acpCommand: 'codex-acp --stdio',
      ),
    );

    final codex = repository.find('s', 'builtin-codex')!;

    expect(codex.installCommand, 'npm install -g @openai/codex');
    expect(
      codex.acpInstallCommand,
      'npm install -g @agentclientprotocol/codex-acp',
    );
    expect(codex.loginCommand, 'codex login');
  });

  test('backfill also covers suffixed builtin ids', () async {
    final repository = await _repository();
    await repository.save(
      AgentProfile(
        id: 'builtin-opencode-a1b2c3',
        serverId: 's',
        name: 'OpenCode ACP',
        description: 'desc',
        cliCommand: 'opencode',
        acpCommand: 'opencode --acp',
      ),
    );

    final profile = repository.find('s', 'builtin-opencode-a1b2c3')!;

    expect(profile.installCommand, 'npm install -g opencode-ai');
    expect(profile.loginCommand, 'opencode auth login');
  });

  test('backfill never overwrites user-supplied commands', () async {
    final repository = await _repository();
    await repository.save(
      AgentProfile(
        id: 'builtin-codex',
        serverId: 's',
        name: 'OpenAI Codex',
        description: 'desc',
        cliCommand: 'codex',
        acpCommand: 'codex-acp --stdio',
        installCommand: 'my-custom-installer',
        loginCommand: 'my-custom-login',
      ),
    );

    final codex = repository.find('s', 'builtin-codex')!;

    expect(codex.installCommand, 'my-custom-installer');
    expect(codex.loginCommand, 'my-custom-login');
    // Still fills the fields the user left empty.
    expect(
      codex.acpInstallCommand,
      'npm install -g @agentclientprotocol/codex-acp',
    );
  });

  test('backfill never touches custom agents', () async {
    final repository = await _repository();
    await repository.save(_profile('custom-abc123', 's'));

    final custom = repository.find('s', 'custom-abc123')!;

    expect(custom.installCommand, isNull);
    expect(custom.acpInstallCommand, isNull);
    expect(custom.loginCommand, isNull);
  });

  test('backfill is idempotent and does not rewrite on later reads', () async {
    final repository = await _repository();
    await repository.save(
      AgentProfile(
        id: 'builtin-agy',
        serverId: 's',
        name: 'Antigravity AGY',
        description: 'desc',
        cliCommand: 'agy',
        acpCommand: 'agy --acp',
      ),
    );

    final first = repository.find('s', 'builtin-agy')!;
    expect(first.installCommand, isNotNull);

    final prefs = await SharedPreferences.getInstance();
    final rawAfterFirst = prefs.getString('valhalla_agents_v1');

    // Second read must not rewrite storage.
    repository.getAll('s');
    expect(prefs.getString('valhalla_agents_v1'), rawAfterFirst);
    expect(prefs.getBool('valhalla_agents_install_backfill_v1_complete'), true);
  });

  test('legacy migration ignores malformed session entries', () async {
    final repository = await _repository(
      initial: {
        'valhalla_chat_sessions_v1': '[null, {"agentType":"codex"}, 2]',
      },
    );
    expect(repository.getAll('server').single.id, 'builtin-codex');
  });

  group('acp command repair', () {
    Future<AgentRepository> withAcp(String id, String acpCommand) async {
      final repository = await _repository();
      await repository.save(
        AgentProfile(
          id: id,
          serverId: 's',
          name: id,
          description: 'desc',
          cliCommand: 'cli',
          acpCommand: acpCommand,
        ),
      );
      return repository;
    }

    test('rewrites every known-bogus builtin acp command', () async {
      const cases = {
        'builtin-claude-code': ('claude-code-acp --stdio', 'claude-code-acp'),
        'builtin-codex': ('codex-acp --stdio', 'codex-acp'),
        'builtin-opencode': ('opencode --acp', 'opencode acp'),
      };

      for (final entry in cases.entries) {
        final repository = await withAcp(entry.key, entry.value.$1);
        final repaired = repository.find('s', entry.key)!;
        expect(
          repaired.acpCommand,
          entry.value.$2,
          reason: '${entry.key} should be repaired',
        );
      }
    });

    test(
      'clears the bogus acp command for agy which has no ACP mode',
      () async {
        final repository = await withAcp('builtin-agy', 'agy --acp');

        expect(repository.find('s', 'builtin-agy')!.acpCommand, isNull);
      },
    );

    test('repairs suffixed builtin ids too', () async {
      final repository = await withAcp(
        'builtin-codex-0420',
        'codex-acp --stdio',
      );

      expect(
        repository.find('s', 'builtin-codex-0420')!.acpCommand,
        'codex-acp',
      );
    });

    test('never overwrites a user-supplied acp command', () async {
      final repository = await withAcp(
        'builtin-codex',
        'my-own-acp-wrapper --flag',
      );

      expect(
        repository.find('s', 'builtin-codex')!.acpCommand,
        'my-own-acp-wrapper --flag',
      );
    });

    test('never touches custom agents', () async {
      final repository = await withAcp('custom-xyz', 'codex-acp --stdio');

      expect(
        repository.find('s', 'custom-xyz')!.acpCommand,
        'codex-acp --stdio',
      );
    });

    test('is idempotent and marks completion', () async {
      final repository = await withAcp('builtin-codex', 'codex-acp --stdio');

      expect(repository.find('s', 'builtin-codex')!.acpCommand, 'codex-acp');

      final prefs = await SharedPreferences.getInstance();
      final rawAfterFirst = prefs.getString('valhalla_agents_v1');

      repository.getAll('s');
      expect(prefs.getString('valhalla_agents_v1'), rawAfterFirst);
      expect(prefs.getBool('valhalla_agents_acp_repair_v1_complete'), true);
    });

    test('preserves all other fields when repairing', () async {
      final repository = await _repository();
      final original = AgentProfile(
        id: 'builtin-codex',
        serverId: 's',
        name: 'My Codex',
        description: 'custom desc',
        cliCommand: 'my-codex',
        acpCommand: 'codex-acp --stdio',
        installCommand: 'my-install',
        acpInstallCommand: 'my-acp-install',
        loginCheckCommand: 'my-check',
        loginCommand: 'my-login',
        createdAt: DateTime.parse('2025-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2025-01-02T00:00:00Z'),
      );
      await repository.save(original);

      final repaired = repository.find('s', 'builtin-codex')!;

      expect(repaired.acpCommand, 'codex-acp');
      expect(repaired.name, 'My Codex');
      expect(repaired.description, 'custom desc');
      expect(repaired.cliCommand, 'my-codex');
      expect(repaired.installCommand, 'my-install');
      expect(repaired.acpInstallCommand, 'my-acp-install');
      expect(repaired.loginCheckCommand, 'my-check');
      expect(repaired.loginCommand, 'my-login');
      expect(repaired.createdAt, original.createdAt);
      expect(repaired.updatedAt, original.updatedAt);
    });
  });

  test(
    'does not mark migration complete when legacy source is absent',
    () async {
      final repository = await _repository();
      expect(repository.getAll('server'), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'valhalla_chat_sessions_v1',
        jsonEncode([
          {
            'id': 's',
            'title': 's',
            'agentType': 'codex',
            'createdAt': '2025-01-01T00:00:00.000Z',
            'updatedAt': '2025-01-01T00:00:00.000Z',
            'messages': [],
          },
        ]),
      );
      expect(
        repository.getAll('server').map((p) => p.id),
        contains('builtin-codex'),
      );
    },
  );

  test(
    'migrates legacy types even when server already has a profile',
    () async {
      final repository = await _repository();
      await repository.save(_profile('custom', 'server'));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'valhalla_chat_sessions_v1',
        jsonEncode([
          {
            'id': 's',
            'title': 's',
            'agentType': 'codex',
            'createdAt': '2025-01-01T00:00:00.000Z',
            'updatedAt': '2025-01-01T00:00:00.000Z',
            'messages': [],
          },
        ]),
      );
      expect(
        repository.getAll('server').map((p) => p.id),
        contains('builtin-codex'),
      );
    },
  );
}
