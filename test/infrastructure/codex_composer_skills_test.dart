import 'dart:convert';

import 'package:acpd/acpd.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/agent_composer_item.dart';
import 'package:valhalla/infrastructure/cli/codex_native_client.dart';

import '../support/fake_acp_transport.dart';

/// 契约 3：CodexNativeClient.skills/list 的真实 data[].skills[] 解析。
///
/// 只驱动内存传输对，不启动任何远端进程。
void main() {
  CodexNativeClient clientFor(FakeAcpPair pair, Map<String, dynamic> result) {
    pair.agent.onReceive = (wire) {
      for (final message in TransportFrame.decode(wire).messages) {
        if (message is! RpcRequest) continue;
        pair.agent.send(
          TransportFrame.single(RpcResponse(id: message.id, result: result)),
        );
      }
    };
    return CodexNativeClient(Connection(pair.client));
  }

  test(
    '解析 data[].skills[]，过滤 enabled=false 并采用 interface.displayName',
    () async {
      final pair = FakeAcpPair();
      addTearDown(pair.close);
      final client = clientFor(pair, {
        'data': [
          {
            'id': 'bundle-a',
            'skills': [
              {
                'name': 'review',
                'description': 'Review a diff',
                'interface': {'displayName': 'Review'},
              },
              {
                'name': 'off',
                'enabled': false,
                'interface': {'displayName': 'Disabled'},
              },
              {
                'name': 'plain',
                'interface': {'displayName': 'Plain'},
              },
            ],
          },
          {
            'id': 'bundle-b',
            'skills': [
              {
                'name': 'review',
                'interface': {'displayName': 'Review duplicate'},
              },
              {'name': 'other', 'description': 'Other skill'},
            ],
          },
        ],
      });

      await client.initialize();
      final catalog = await client.composerCatalog(cwd: '/work/repo');

      expect(catalog.skills.map((skill) => skill.id), [
        'review',
        'plain',
        'other',
      ], reason: '启用的技能按出现顺序去重');
      expect(catalog.skills.first.label, 'Review');
      expect(catalog.skills.first.insertion, r'$review');
      expect(catalog.skills.first.description, 'Review a diff');
      expect(
        catalog.skills.map((skill) => skill.label),
        isNot(contains('Disabled')),
        reason: 'enabled=false 必须被过滤',
      );
      expect(
        catalog.skills.map((skill) => skill.label),
        isNot(contains('Review duplicate')),
        reason: '同名技能不得重复',
      );
      expect(catalog.skills.map((skill) => skill.kind).toSet(), {
        AgentComposerItemKind.skill,
      });
      expect(catalog.commands, isEmpty, reason: 'TUI 斜杠命令不得被发明成技能');

      final calls = pair.sentToAgent.map(jsonDecode).toList();
      final skillsCall =
          calls.firstWhere((call) => call['method'] == 'skills/list')
              as Map<String, dynamic>;
      expect(skillsCall['params'], {
        'cwds': ['/work/repo'],
        'forceReload': true,
      }, reason: '必须强制重载并带上当前工作目录');
      expect(
        calls.map((call) => call['method']),
        containsAll(['initialize', 'skills/list']),
      );
      expect(
        calls.map((call) => call['method']),
        isNot(
          anyElement(
            isIn([
              'session/new',
              'session/load',
              'session/resume',
              'session/prompt',
              'thread/list',
            ]),
          ),
        ),
        reason: '目录发现不得顺带列举线程或建立会话',
      );
    },
  );

  test('缺失 interface 时回落到 id，缺失 cwd 时不带 cwds', () async {
    final pair = FakeAcpPair();
    addTearDown(pair.close);
    final client = clientFor(pair, {
      'data': [
        {
          'skills': [
            {'name': 'bare'},
          ],
        },
      ],
    });

    await client.initialize();
    final catalog = await client.composerCatalog();

    expect(catalog.skills.single.label, 'bare');
    expect(catalog.skills.single.insertion, r'$bare');

    final calls = pair.sentToAgent.map(jsonDecode).toList();
    final skillsCall =
        calls.firstWhere((call) => call['method'] == 'skills/list')
            as Map<String, dynamic>;
    expect(skillsCall['params'], {'forceReload': true});
  });

  test('旧的扁平 data[] 条目仍被容忍', () async {
    final pair = FakeAcpPair();
    addTearDown(pair.close);
    final client = clientFor(pair, {
      'data': [
        {'name': 'legacy-a', 'description': 'Legacy A'},
        {
          'name': 'legacy-b',
          'interface': {'displayName': 'Legacy B'},
        },
        {'name': 'legacy-off', 'enabled': false},
      ],
    });

    await client.initialize();
    final catalog = await client.composerCatalog(cwd: '/tmp');

    expect(catalog.skills.map((skill) => skill.id), ['legacy-a', 'legacy-b']);
    expect(catalog.skills.last.label, 'Legacy B');
  });

  test('name 缺失时回落到 id/skill，空 id 被丢弃', () async {
    final pair = FakeAcpPair();
    addTearDown(pair.close);
    final client = clientFor(pair, {
      'data': [
        {
          'skills': [
            {'id': 'by-id'},
            {'skill': 'by-skill'},
            {'description': 'no identifier'},
            {'name': ''},
          ],
        },
      ],
    });

    await client.initialize();
    final catalog = await client.composerCatalog(cwd: '/tmp');

    expect(catalog.skills.map((skill) => skill.id), ['by-id', 'by-skill']);
  });

  test('data 不是列表时报固定无效响应码', () async {
    final pair = FakeAcpPair();
    addTearDown(pair.close);
    final client = clientFor(pair, {'data': 'nope'});

    await client.initialize();

    await expectLater(
      client.composerCatalog(cwd: '/tmp'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'AGENT_SKILLS_INVALID_RESPONSE',
        ),
      ),
    );
  });

  test('缺 data 字段同样报固定无效响应码', () async {
    final pair = FakeAcpPair();
    addTearDown(pair.close);
    final client = clientFor(pair, <String, dynamic>{});

    await client.initialize();

    await expectLater(
      client.composerCatalog(cwd: '/tmp'),
      throwsA(isA<FormatException>()),
    );
  });
}
