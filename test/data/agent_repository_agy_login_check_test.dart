import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/builtin_agent_preset.dart';
import 'package:valhalla/data/repositories/agent_repository.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';

/// AGY readiness-probe migration contract: the probe must be repaired even when
/// every one-shot backfill marker is already complete, and it must never
/// overwrite a user-supplied probe, a customized CLI or a custom agent.
const _allComplete = {
  'valhalla_agents_install_backfill_v1_complete': true,
  'valhalla_agents_acp_repair_v1_complete': true,
};

Future<AgentRepository> _repository({Map<String, dynamic>? initial}) async {
  SharedPreferences.setMockInitialValues(
    (initial ?? {}).cast<String, Object>(),
  );
  final prefs = await SharedPreferences.getInstance();
  return AgentRepository(LocalStorageService(prefs));
}

AgentProfile _agy({
  String id = 'builtin-agy',
  String cliCommand = 'agy',
  String? loginCheckCommand,
}) => AgentProfile(
  id: id,
  serverId: 's',
  name: 'AGY',
  description: 'desc',
  cliCommand: cliCommand,
  acpCommand: 'agy_acp_server.par',
  loginCommand: 'agy',
  loginCheckCommand: loginCheckCommand,
);

void main() {
  group('AGY readiness probe migration', () {
    test(
      'fills the probe when every one-shot migration is already complete',
      () async {
        final repository = await _repository(initial: _allComplete);
        await repository.save(_agy());

        expect(
          repository.find('s', 'builtin-agy')!.loginCheckCommand,
          kAntigravityLoginCheckCommand,
          reason: 'the auth repair must not be gated on the backfill marker',
        );
      },
    );

    test('fills the probe for suffixed builtin ids too', () async {
      final repository = await _repository(initial: _allComplete);
      await repository.save(_agy(id: 'builtin-agy-7f21'));

      expect(
        repository.find('s', 'builtin-agy-7f21')!.loginCheckCommand,
        kAntigravityLoginCheckCommand,
      );
    });

    test('does not rewrite storage once the probe has been filled', () async {
      final repository = await _repository(initial: _allComplete);
      await repository.save(_agy());
      expect(
        repository.find('s', 'builtin-agy')!.loginCheckCommand,
        kAntigravityLoginCheckCommand,
      );

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('valhalla_agents_v1');
      repository.getAll('s');
      expect(prefs.getString('valhalla_agents_v1'), stored);
    });

    test('never overwrites a user-supplied readiness probe', () async {
      final repository = await _repository(initial: _allComplete);
      await repository.save(_agy(loginCheckCommand: 'my-custom-probe'));

      expect(
        repository.find('s', 'builtin-agy')!.loginCheckCommand,
        'my-custom-probe',
      );
    });

    test('applies no probe when the CLI command was customized', () async {
      final repository = await _repository(initial: _allComplete);
      await repository.save(_agy(cliCommand: 'my-agy'));

      expect(repository.find('s', 'builtin-agy')!.loginCheckCommand, isNull);
    });

    test('never touches custom agents', () async {
      final repository = await _repository(initial: _allComplete);
      await repository.save(_agy(id: 'custom-agy'));

      expect(repository.find('s', 'custom-agy')!.loginCheckCommand, isNull);
    });

    test('fills the probe on a fresh install as well', () async {
      final repository = await _repository();
      await repository.save(_agy());

      expect(
        repository.find('s', 'builtin-agy')!.loginCheckCommand,
        kAntigravityLoginCheckCommand,
      );
    });

    test('keeps the probe alongside the repaired ACP command', () async {
      final repository = await _repository(initial: _allComplete);
      await repository.save(
        _agy().copyWith(acpCommand: 'agy --acp', acpInstallCommand: ''),
      );

      final repaired = repository.find('s', 'builtin-agy')!;
      expect(repaired.acpCommand, 'agy_acp_server.par');
      expect(repaired.loginCheckCommand, kAntigravityLoginCheckCommand);
      expect(repaired.loginCommand, 'agy');
    });
  });
}
