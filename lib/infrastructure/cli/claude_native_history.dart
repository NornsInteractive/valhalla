import 'dart:convert';
import '../../core/utils/shell_quote.dart';
import '../../data/models/native_cli_session.dart';
import '../../data/models/agent_profile.dart';
import 'agent_execution_target.dart';
import '../ssh/ssh_client_manager.dart';

/// One-shot official SDK reads; no private history database or daemon.
class ClaudeNativeHistory {
  final SshCommandExecutor executor;
  final String serverId;
  final AgentProfile? profile;
  ClaudeNativeHistory(this.executor, this.serverId, {this.profile});
  String _target(String command) =>
      profile == null ? command : agentTargetCommand(profile!, command);
  static const installCommand =
      r'npm install --prefix "$HOME/.local/share/valhalla/claude-history" @anthropic-ai/claude-agent-sdk';
  Future<Object?> _read(String expression) async {
    final code =
        'const sdk = await import(process.env.HOME + "/.local/share/valhalla/claude-history/node_modules/@anthropic-ai/claude-agent-sdk/sdk.mjs"); console.log(JSON.stringify(await $expression));';
    final result = await executor.executeWithLoginShell(
      serverId,
      _target('node --input-type=module -e ${cliShellQuote(code)}'),
    );
    if (!result.isSuccess) {
      throw StateError(
        result.exitCode == 127
            ? 'CLI_HISTORY_RUNTIME_MISSING'
            : result.stderr.contains('ERR_MODULE_NOT_FOUND')
            ? 'CLI_HISTORY_SDK_MISSING'
            : 'CLI_HISTORY_READ_FAILED',
      );
    }
    return jsonDecode(result.stdout);
  }

  Future<NativeCliPage> list({String? cwd}) async {
    final options = jsonEncode({if (cwd != null && cwd.isNotEmpty) 'dir': cwd});
    final raw = await _read('sdk.listSessions($options)') as List;
    return NativeCliPage(
      raw
          .map(
            (s) => NativeCliSession(
              id: s['sessionId'] as String,
              title: (s['customTitle'] ?? s['summary'] ?? s['sessionId'])
                  .toString(),
              cwd: s['cwd'] as String?,
              updatedAt: DateTime.fromMillisecondsSinceEpoch(
                (s['lastModified'] as num).toInt(),
              ),
            ),
          )
          .toList(),
    );
  }

  Future<NativeCliMessagePage> readPage(
    String id, {
    String? cursor,
    required int limit,
  }) async {
    final offset = cursor == null ? null : int.parse(cursor);
    final raw =
        await _read(
              'Promise.resolve(sdk.getSessionMessages(${jsonEncode(id)})).then(all => { '
              'const end = ${offset == null ? 'all.length' : 'Math.min(all.length, $offset)'}; '
              'const start = Math.max(0, end - $limit); '
              'return {messages: all.slice(start, end), olderCursor: start > 0 ? String(start) : null}; '
              '})',
            )
            as Map;
    final messages = (raw['messages'] as List).map((m) {
      final content = m['message']?['content'];
      final text = content is String
          ? content
          : content is List
          ? content
                .where((p) => p['type'] == 'text')
                .map((p) => p['text'])
                .join('\n')
          : '';
      return NativeCliMessage(
        id: m['uuid'] as String,
        role: m['type'] as String,
        text: text,
      );
    }).toList();
    return NativeCliMessagePage(
      messages,
      olderCursor: raw['olderCursor'] as String?,
    );
  }

  Future<void> install() async {
    final result = await executor.executeWithLoginShell(
      serverId,
      _target(installCommand),
      timeout: const Duration(minutes: 5),
    );
    if (!result.isSuccess) throw StateError('CLI_HISTORY_SDK_INSTALL_FAILED');
  }
}
