import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/security/agent_command_validator.dart';
import 'package:valhalla/data/models/builtin_agent_preset.dart';

/// The built-in AGY readiness probe must be a syntactically executable shell
/// command, print exactly one structured result and never echo credential
/// material. Real `python3` runs, but every execution pins an isolated
/// `GEMINI_HOME` fixture: `HOME`/`CODEX_HOME` are never repurposed and the real
/// `~/.gemini` is never read. The legacy `~/.gemini` default is proven from the
/// command source (§test) instead of by launching it without `GEMINI_HOME`.
const _fakeToken = 'FAKE-NOT-A-REAL-TOKEN';

Future<Directory> _isolatedGeminiHome() =>
    Directory.systemTemp.createTemp('agy-gemini-home-');

Future<void> _seed(
  Directory geminiHome,
  String relative,
  String content,
) async {
  final file = File('${geminiHome.path}/$relative');
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
}

/// The only environment override these fixtures apply.
///
/// Passing `HOME` would repurpose the process home and could reach the real
/// `~/.gemini`, so it is deliberately absent — as is `CODEX_HOME`.
Map<String, String> _probeEnvironment(Directory geminiHome) => {
  'GEMINI_HOME': geminiHome.path,
};

/// Runs the production probe against the isolated [geminiHome] fixture.
Future<Map<String, dynamic>> _probe(Directory geminiHome) async {
  final environment = _probeEnvironment(geminiHome);
  expect(
    environment.keys.toSet(),
    {'GEMINI_HOME'},
    reason: 'fixtures must never override HOME or CODEX_HOME',
  );
  final result = await Process.run('/bin/bash', [
    '-lc',
    kAntigravityLoginCheckCommand,
  ], environment: environment);
  expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');
  expect(result.stderr.toString(), isEmpty);
  expect(result.stdout.toString(), isNot(contains(_fakeToken)));
  final decoded = jsonDecode(result.stdout as String);
  expect(decoded, isA<Map<String, dynamic>>());
  final map = decoded as Map<String, dynamic>;
  expect(map['scope'], 'antigravity-acp');
  // The probe also reports where it looked. These are nonsecret paths used by
  // diagnostics; they must be present and inside the fixture home.
  expect(map.keys.toSet(), {
    'scope',
    'state',
    'authType',
    'credentialDirectory',
    'home',
  });
  expect(map['home'], isNotEmpty, reason: 'diagnostics report the probe home');
  expect(
    map['credentialDirectory'] as String,
    startsWith(geminiHome.path),
    reason: 'credentials are only ever read under the fixture GEMINI_HOME',
  );
  expect(
    const {'missing', 'saved', 'unknown'},
    contains(map['state']),
    reason: 'state must stay within the accepted vocabulary',
  );
  return map;
}

void main() {
  late List<Directory> geminiHomes;

  setUp(() {
    geminiHomes = [];
  });

  tearDown(() async {
    for (final dir in geminiHomes) {
      if (dir.existsSync()) await dir.delete(recursive: true);
    }
  });

  Future<Directory> newGeminiHome() async {
    final dir = await _isolatedGeminiHome();
    geminiHomes.add(dir);
    return dir;
  }

  test('the preset probe passes the shell command validator', () {
    expect(
      kAntigravityLoginCheckCommand.trim(),
      startsWith('python3 -c '),
      reason: 'the probe must stay a single interpreter invocation',
    );
    expect(
      () => AgentCommandValidator.validate(kAntigravityLoginCheckCommand),
      returnsNormally,
    );
  });

  test(
    'legacy ~/.gemini default is proven from source, never by overriding HOME',
    () {
      expect(
        kAntigravityLoginCheckCommand,
        contains('os.environ.get("GEMINI_HOME")'),
        reason: 'GEMINI_HOME must win over the legacy default',
      );
      expect(
        kAntigravityLoginCheckCommand,
        contains('pathlib.Path.home()/".gemini"'),
        reason:
            'the legacy default is Path.home()/.gemini, asserted here instead '
            'of by executing the probe with a fabricated HOME',
      );
      expect(kAntigravityLoginCheckCommand, isNot(contains('CODEX_HOME')));
      expect(
        kAntigravityLoginCheckCommand,
        isNot(contains('environ.get("HOME"')),
        reason: 'the probe must not read HOME directly',
      );
    },
  );

  test(
    'reports missing on a gemini home with no Antigravity credentials',
    () async {
      final geminiHome = await newGeminiHome();

      final result = await _probe(geminiHome);

      expect(result['state'], 'missing');
      expect(result['authType'], isNull);
    },
  );

  test('reports saved when the ACP token file is readable', () async {
    final geminiHome = await newGeminiHome();
    await _seed(geminiHome, 'antigravity-acp/acp_token.json', _fakeToken);

    final result = await _probe(geminiHome);

    expect(result['state'], 'saved');
    expect(result['authType'], isNull);
  });

  test('reports unknown when the auth type alone is configured', () async {
    final geminiHome = await newGeminiHome();
    await _seed(
      geminiHome,
      'antigravity-acp/settings.json',
      '{"auth":{"type":"gemini-api-key"}}',
    );

    final result = await _probe(geminiHome);

    expect(result['state'], 'unknown');
    expect(result['authType'], 'gemini-api-key');
  });

  test('reports saved for the oauth-business token file', () async {
    final geminiHome = await newGeminiHome();
    await _seed(
      geminiHome,
      'antigravity-acp/settings.json',
      '{"auth":{"type":"oauth-business"}}',
    );
    await _seed(
      geminiHome,
      'antigravity-acp/acp_business_token.json',
      _fakeToken,
    );

    final result = await _probe(geminiHome);

    expect(result['state'], 'saved');
    expect(result['authType'], 'oauth-business');
  });

  test(
    'GEMINI_HOME alone selects the fixture, not any inherited home',
    () async {
      final withToken = await newGeminiHome();
      await _seed(withToken, 'antigravity-acp/acp_token.json', _fakeToken);
      final empty = await newGeminiHome();

      final saved = await _probe(withToken);
      final missing = await _probe(empty);

      expect(saved['state'], 'saved');
      expect(
        missing['state'],
        'missing',
        reason:
            'two isolated GEMINI_HOME fixtures disagree, so the selection key '
            'is GEMINI_HOME itself and no parent home leaked in',
      );
    },
  );
}
