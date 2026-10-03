import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';

import '../../core/utils/shell_quote.dart';
import '../../data/models/agent_profile.dart';
import '../../data/models/chat_run_settings.dart';
import 'agent_execution_target.dart';

/// Independent CLI discovery. No ACP session or prompt is created. The CLI
/// account may differ from ACP, so the catalog is not an entitlement check.
class AgyModelCatalog {
  static List<ChatSettingOption> parse(String output) {
    final clean = output.replaceAll(RegExp(r'\x1b\[[0-?]*[ -/]*[@-~]'), '');
    final models = <String, ChatSettingOption>{};
    for (final line in const LineSplitter().convert(clean)) {
      final match = RegExp(
        r'^(gemini-[A-Za-z0-9._-]+)\s+(.+)$',
      ).firstMatch(line.trim());
      if (match == null) continue;
      // Official AgY ACP currently accepts Gemini models, unlike the CLI
      // catalog which also lists other vendors. Keep full reasoning suffixes.
      final id = match.group(1)!;
      models[id] = ChatSettingOption(id, match.group(2)!.trim());
    }
    if (models.isEmpty) throw StateError('AGENT_MODEL_CATALOG_EMPTY');
    return models.values.toList();
  }

  static Future<AgentRuntimeCapabilities> query(
    SSHClient client,
    AgentProfile profile,
  ) async {
    final command = '${cliShellQuote(profile.cliCommand)} models';
    final launch = agentTargetCommand(
      profile,
      profile.executionTarget == 'docker'
          ? command
          : 'bash -l -c ${cliShellQuote(command)}',
    );
    SSHSession? session;
    var expired = false;
    try {
      return await (() async {
        final opened = await client.execute(launch);
        session = opened;
        if (expired) {
          opened.close();
          throw StateError('AGENT_MODEL_QUERY_TIMEOUT');
        }
        final results = await Future.wait<Object?>([
          opened.stdout.cast<List<int>>().transform(utf8.decoder).fold<String>(
            '',
            (output, chunk) {
              if (output.length + chunk.length > 256 * 1024) {
                throw StateError('AGENT_MODEL_CATALOG_TOO_LARGE');
              }
              return output + chunk;
            },
          ),
          opened.stderr.drain<void>(),
          opened.done,
          opened.stdin.close(),
        ], eagerError: true);
        if (opened.exitCode != 0) throw StateError('AGENT_MODEL_QUERY_FAILED');
        return AgentRuntimeCapabilities(
          models: parse(results.first as String),
          supportsStructuredSettings: true,
        );
      })().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw StateError('AGENT_MODEL_QUERY_TIMEOUT');
    } finally {
      expired = true;
      session?.close();
    }
  }
}
