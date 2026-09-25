import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/infrastructure/cli/agent_execution_target.dart';

AgentProfile _profile({
  String target = 'host',
  String binding = 'id',
  String? reference,
  String? user,
}) => AgentProfile(
  id: 'agent',
  serverId: 'server',
  name: 'Agent',
  description: '',
  cliCommand: 'codex',
  executionTarget: target,
  containerBinding: binding,
  containerReference: reference,
  containerUser: user,
);

void main() {
  test('host target leaves the validated command unchanged', () {
    expect(
      agentTargetCommand(_profile(), 'codex app-server'),
      'codex app-server',
    );
  });

  test('docker target quotes the reference and uses no PTY by default', () {
    final command = agentTargetCommand(
      _profile(target: 'docker', reference: 'web.api'),
      'codex app-server',
    );
    expect(command, contains("docker exec -i 'web.api' /bin/sh -lc"));
    expect(command, contains('/bin/bash -ic'));
    expect(command, contains('/bin/sh -lc'));
  });

  test('interactive docker target requests a PTY', () {
    expect(
      agentTargetCommand(
        _profile(target: 'docker', reference: 'web'),
        'codex',
        interactive: true,
      ),
      contains("docker exec -it 'web' /bin/sh -lc"),
    );
  });

  test('docker target rejects absent or unsafe container references', () {
    expect(
      () => agentTargetCommand(_profile(target: 'docker'), 'codex'),
      throwsStateError,
    );
    expect(
      () => agentTargetCommand(
        _profile(target: 'docker', reference: 'web;rm'),
        'codex',
      ),
      throwsStateError,
    );
  });

  test('docker target uses an explicit user and rejects unsafe values', () {
    final command = agentTargetCommand(
      _profile(target: 'docker', reference: 'web', user: 'dev:1000'),
      'codex',
    );
    expect(
      command,
      contains("docker exec -i --user 'dev:1000' 'web' /bin/sh -lc"),
    );
    expect(
      () => agentTargetCommand(
        _profile(target: 'docker', reference: 'web', user: 'dev;id'),
        'codex',
      ),
      throwsStateError,
    );
  });
}
