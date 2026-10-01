import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../../data/models/agent_profile.dart';
import '../../data/models/chat_run_settings.dart';
import 'codex_model_authorization.dart';

class ModelCatalogQueryException implements Exception {
  final String code;
  final String? accountKey;
  const ModelCatalogQueryException(this.code, this.accountKey);
  @override
  String toString() => code;
}

/// Credentials and HTTPS stay in the selected agent's runtime. Only model
/// metadata or a fixed error code may cross SSH; never raw HTTP/auth responses.
class CodexAccountModels {
  static const _script =
      CodexModelAuthorization.runtime +
      r'''
(async () => {
  let identity;
  try {
    identity = codexIdentity();
    const token = await accessToken(identity);
    if (typeof token !== 'string' || !token) fail('AGENT_MODEL_AUTH_UNAVAILABLE');
    const result = await jsonRequest('https://api.openai.com/v1/models', {
      headers: {Authorization: 'Bearer ' + token}
    });
    if (!Array.isArray(result.models)) {
      emit({error: 'AGENT_MODEL_ACCOUNT_CATALOG_UNAVAILABLE', accountKey: identity.accountKey}); return;
    }
    const current = codexIdentity();
    if (current.accountKey !== identity.accountKey) {
      emit({error: 'AGENT_MODEL_ACCOUNT_MISMATCH', accountKey: current.accountKey}); return;
    }
    emit({accountKey: identity.accountKey, models: result.models.filter(m => m && m.visibility === 'list'
      && typeof m.slug === 'string' && typeof m.display_name === 'string')
      .map(m => ({slug: m.slug, display_name: m.display_name, visibility: 'list'}))});
  } catch (error) { emit({error: safeError(error), accountKey: identity?.accountKey}); }
})().catch(() => emit({error: 'AGENT_MODEL_QUERY_FAILED'}));
''';

  static String command(AgentProfile profile) {
    return CodexModelAuthorization.remoteCommand(profile, _script);
  }

  static AgentRuntimeCapabilities parse(Map<String, dynamic> response) {
    final key = response['accountKey'];
    final accountKey = key is String && RegExp(r'^[a-f0-9]{64}$').hasMatch(key)
        ? key
        : null;
    final error = response['error'];
    if (error is String && RegExp(r'^AGENT_MODEL_[A-Z_]+$').hasMatch(error)) {
      throw ModelCatalogQueryException(error, accountKey);
    }
    final raw = response['models'];
    if (raw is! List) {
      throw const FormatException('AGENT_MODEL_INVALID_RESPONSE');
    }
    final seen = <String>{};
    return AgentRuntimeCapabilities(
      catalogAccountKey: accountKey,
      models: [
        for (final model in raw)
          if (model is Map &&
              model['visibility'] == 'list' &&
              model['slug'] is String &&
              (model['slug'] as String).isNotEmpty &&
              model['display_name'] is String &&
              seen.add(model['slug'] as String))
            ChatSettingOption(
              model['slug'] as String,
              model['display_name'] as String,
            ),
      ],
      supportsStructuredSettings: true,
    );
  }

  static Future<AgentRuntimeCapabilities> query(
    SSHClient ssh,
    AgentProfile profile,
  ) async {
    var expired = false;
    final opening = ssh.execute(command(profile)).then((session) {
      if (expired) session.close();
      return session;
    });
    final SSHSession session;
    try {
      session = await opening.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      expired = true;
      rethrow;
    }
    final stderr = session.stderr.listen((_) {}, onError: (Object _) {});
    try {
      final bytes = BytesBuilder(copy: false);
      await (() async {
        await for (final chunk in session.stdout) {
          // ponytail: 2MiB metadata ceiling; add paging only if the API supplies it.
          if (bytes.length + chunk.length > 2 * 1024 * 1024) {
            throw StateError('AGENT_MODEL_RESPONSE_TOO_LARGE');
          }
          bytes.add(chunk);
        }
        await session.done;
      })().timeout(const Duration(seconds: 25));
      if (session.exitCode != 0) {
        throw StateError('AGENT_MODEL_RUNTIME_UNAVAILABLE');
      }
      // Interactive container startup may print a banner. Accept only the
      // fixed result shape, not other stdout or stderr from shell initialization.
      for (final line in utf8.decode(bytes.takeBytes()).split('\n').reversed) {
        if (!line.trimLeft().startsWith('{')) continue;
        final value = jsonDecode(line);
        if (value is Map<String, dynamic> &&
            (value.containsKey('models') || value.containsKey('error'))) {
          return parse(value);
        }
      }
      throw const FormatException('AGENT_MODEL_INVALID_RESPONSE');
    } finally {
      session.close();
      await stderr.cancel();
    }
  }
}
