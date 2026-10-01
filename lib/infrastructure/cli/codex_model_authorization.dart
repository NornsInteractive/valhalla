import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dartssh2/dartssh2.dart';

import '../../core/utils/shell_quote.dart';
import '../../data/models/agent_profile.dart';
import 'agent_execution_target.dart';

/// Browser authorization uses a phone-local loopback callback. The code is
/// forwarded over SSH; token exchange, validation and storage stay remote.
/// This never writes Codex's auth.json or performs inference.
class CodexModelAuthorization {
  static String credentialKey(AgentProfile profile) => sha256
      .convert(utf8.encode('${profile.serverId}::${profile.id}'))
      .toString();

  /// Shared remote runtime uses Node's native HTTPS/crypto/fs APIs, not an
  /// unpublished npm package or a hand-written JWT signature algorithm.
  static const runtime = r'''
const fs = require('fs'), path = require('path'), os = require('os'), crypto = require('crypto');
const emit = value => process.stdout.write(JSON.stringify(value) + '\n');
const fail = code => { throw new Error(code); };
const home = process.env.CODEX_HOME || path.join(os.homedir(), '.codex');
const authFile = path.join(os.homedir(), '.config', 'valhalla', 'model-auth', process.argv[1], 'credentials.json');
const endpoint = 'https://auth.openai.com/api/accounts/oauth/token';
const resource = 'https://api.openai.com/v1';
const safeError = error => /^AGENT_MODEL_[A-Z_]+$/.test(error.message || '') ? error.message : 'AGENT_MODEL_AUTH_FAILED';
async function jsonRequest(url, options = {}) {
  const parsed = new URL(url);
  if (parsed.protocol !== 'https:' || !['auth.openai.com', 'api.openai.com'].includes(parsed.host)) fail('AGENT_MODEL_ENDPOINT_INVALID');
  let response;
  try { response = await fetch(url, {...options, redirect: 'error', signal: AbortSignal.timeout(15000)}); }
  catch { fail('AGENT_MODEL_NETWORK_FAILURE'); }
  if (!response.ok) {
    fail(response.status === 401 ? 'AGENT_MODEL_AUTH_EXPIRED'
      : response.status === 403 ? 'AGENT_MODEL_ACCESS_DENIED'
      : response.status === 429 ? 'AGENT_MODEL_RATE_LIMITED' : 'AGENT_MODEL_HTTP_FAILURE');
  }
  let size = 0; const chunks = [];
  for await (const chunk of response.body) {
    size += chunk.length;
    if (size > 2097152) fail('AGENT_MODEL_RESPONSE_TOO_LARGE');
    chunks.push(chunk);
  }
  try { return JSON.parse(Buffer.concat(chunks).toString('utf8')); }
  catch { fail('AGENT_MODEL_INVALID_RESPONSE'); }
}
function codexIdentity() {
  // Used only to bind discovery to the selected CLI account, not to prove
  // authentication. The independent ID token is verified against OpenAI JWKS.
  try {
    const auth = JSON.parse(fs.readFileSync(path.join(home, 'auth.json'), 'utf8'));
    if ((auth.auth_mode != null && auth.auth_mode !== 'chatgpt') || !auth.tokens) fail('AGENT_MODEL_AUTH_UNSUPPORTED');
    const id = JSON.parse(Buffer.from(auth.tokens.id_token.split('.')[1], 'base64url').toString('utf8'));
    if (typeof id.sub !== 'string' || !id.sub) fail('AGENT_MODEL_AUTH_UNAVAILABLE');
    return {subject: id.sub, accessToken: auth.tokens.access_token,
      accountKey: crypto.createHash('sha256').update(id.sub + ':' + String(auth.tokens.account_id || '')).digest('hex')};
  } catch (error) { fail(safeError(error) === 'AGENT_MODEL_AUTH_UNSUPPORTED' ? error.message : 'AGENT_MODEL_AUTH_UNAVAILABLE'); }
}
function loadRecord() {
  try {
    const stat = fs.lstatSync(authFile);
    if (!stat.isFile() || (stat.mode & 0o077) || stat.uid !== process.getuid()) fail('AGENT_MODEL_AUTH_STORAGE_UNSAFE');
    return JSON.parse(fs.readFileSync(authFile, 'utf8'));
  } catch (error) {
    if (error.code === 'ENOENT') return null;
    fail(safeError(error));
  }
}
function writeRecord(record) {
  fs.mkdirSync(path.dirname(authFile), {recursive: true, mode: 0o700});
  const directory = fs.lstatSync(path.dirname(authFile));
  if (!directory.isDirectory() || (directory.mode & 0o077) || directory.uid !== process.getuid()) fail('AGENT_MODEL_AUTH_STORAGE_UNSAFE');
  const temporary = authFile + '.' + crypto.randomUUID() + '.tmp';
  try { fs.writeFileSync(temporary, JSON.stringify(record), {mode: 0o600, flag: 'wx'}); fs.renameSync(temporary, authFile); }
  finally { try { fs.unlinkSync(temporary); } catch {} }
}
let heldLock;
function releaseLock() {
  if (!heldLock) return;
  const lock = heldLock; heldLock = undefined;
  try { fs.closeSync(lock.handle); } catch {}
  try { fs.unlinkSync(lock.path); } catch {}
}
async function withCredentialLock(action) {
  const lock = authFile + '.lock';
  try { heldLock = {handle: fs.openSync(lock, 'wx', 0o600), path: lock}; }
  catch { fail('AGENT_MODEL_AUTH_BUSY'); }
  try { return await action(); } finally { releaseLock(); }
}
for (const signal of ['SIGTERM', 'SIGHUP', 'SIGINT']) {
  process.once(signal, () => { releaseLock(); process.exit(1); });
}
async function verifyIdentity(token, clientId, nonce) {
  if (typeof token !== 'string') fail('AGENT_MODEL_IDENTITY_INVALID');
  const parts = token.split('.');
  if (parts.length !== 3) fail('AGENT_MODEL_IDENTITY_INVALID');
  let header, claims;
  try { header = JSON.parse(Buffer.from(parts[0], 'base64url')); claims = JSON.parse(Buffer.from(parts[1], 'base64url')); }
  catch { fail('AGENT_MODEL_IDENTITY_INVALID'); }
  if (header.alg !== 'RS256' || typeof header.kid !== 'string' || header.crit) fail('AGENT_MODEL_IDENTITY_INVALID');
  const discovery = await jsonRequest('https://auth.openai.com/.well-known/openid-configuration');
  if (discovery.issuer !== 'https://auth.openai.com') fail('AGENT_MODEL_IDENTITY_INVALID');
  const jwks = await jsonRequest(discovery.jwks_uri);
  const key = jwks.keys?.find(k => k.kid === header.kid && k.kty === 'RSA' && (!k.use || k.use === 'sig') && (!k.alg || k.alg === 'RS256'));
  if (!key || !crypto.verify('RSA-SHA256', Buffer.from(parts[0] + '.' + parts[1]), crypto.createPublicKey({key, format: 'jwk'}), Buffer.from(parts[2], 'base64url'))) fail('AGENT_MODEL_IDENTITY_INVALID');
  const audiences = Array.isArray(claims.aud) ? claims.aud : [claims.aud];
  if (claims.iss !== discovery.issuer || !audiences.includes(clientId)
      || (audiences.length > 1 && claims.azp !== clientId)
      || !Number.isFinite(claims.exp) || claims.exp <= Date.now()/1000
      || (Number.isFinite(claims.nbf) && claims.nbf > Date.now()/1000 + 60)
      || typeof claims.sub !== 'string' || !claims.sub
      || (nonce !== undefined && claims.nonce !== nonce)) fail('AGENT_MODEL_IDENTITY_INVALID');
  return claims;
}
async function storeTokens(data, clientId, expectedSubject, nonce, previous = {}) {
  const scopes = typeof data.scope === 'string' ? data.scope.split(/\s+/) : previous.scopes;
  if (!Array.isArray(scopes) || !scopes.includes('chatgpt.tokens.use.direct')) fail('AGENT_MODEL_PLAN_PERMISSION_REQUIRED');
  if (typeof data.access_token !== 'string' || !data.access_token || String(data.token_type).toLowerCase() !== 'bearer'
      || !Number.isFinite(data.expires_in) || data.expires_in <= 0) fail('AGENT_MODEL_AUTH_INVALID_RESPONSE');
  const identity = await verifyIdentity(data.id_token || previous.id_token, clientId, nonce);
  if (identity.sub !== expectedSubject) fail('AGENT_MODEL_ACCOUNT_MISMATCH');
  const record = {...previous, client_id: clientId, subject: identity.sub,
    access_token: data.access_token, refresh_token: data.refresh_token || previous.refresh_token,
    id_token: data.id_token || previous.id_token, scopes,
    expires_at: Date.now() + data.expires_in * 1000};
  writeRecord(record);
  return record;
}
async function accessToken(identity = codexIdentity()) {
  let record = loadRecord();
  if (!record?.access_token) return identity.accessToken;
  if (record.subject !== identity.subject) fail('AGENT_MODEL_ACCOUNT_MISMATCH');
  if (record.codex_account_key && record.codex_account_key !== identity.accountKey) fail('AGENT_MODEL_ACCOUNT_MISMATCH');
  if (!Array.isArray(record.scopes) || !record.scopes.includes('chatgpt.tokens.use.direct')) fail('AGENT_MODEL_PLAN_PERMISSION_REQUIRED');
  if (record.expires_at > Date.now() + 60000) return record.access_token;
  // Serialize rotating refresh tokens across app processes; never steal a lock.
  return withCredentialLock(async () => {
    record = loadRecord();
    if (!record || record.subject !== identity.subject
        || (record.codex_account_key && record.codex_account_key !== identity.accountKey)) fail('AGENT_MODEL_ACCOUNT_MISMATCH');
    if (!Array.isArray(record.scopes) || !record.scopes.includes('chatgpt.tokens.use.direct')) fail('AGENT_MODEL_PLAN_PERMISSION_REQUIRED');
    if (record.expires_at > Date.now() + 60000) return record.access_token;
    if (!record.refresh_token) fail('AGENT_MODEL_AUTH_EXPIRED');
    const data = await jsonRequest(endpoint, {method: 'POST', headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: new URLSearchParams({grant_type: 'refresh_token', client_id: record.client_id, refresh_token: record.refresh_token, resource})});
    record = await storeTokens(data, record.client_id, identity.subject, undefined, record);
    return record.access_token;
  });
}
''';

  static const _authorize = r'''
const readline = require('readline');
const input = readline.createInterface({input: process.stdin});
let pending, processing = false;
input.on('line', async line => {
  if (processing) return; processing = true;
  try {
    const message = JSON.parse(line);
    if (!pending) {
      const redirect = new URL(message.redirectUri);
      if (redirect.protocol !== 'http:' || redirect.hostname !== '127.0.0.1'
          || !redirect.port || redirect.pathname !== '/auth/callback' || redirect.search || redirect.hash) fail('AGENT_MODEL_CALLBACK_INVALID');
      const identity = codexIdentity(), previous = loadRecord();
      fs.mkdirSync(path.dirname(authFile), {recursive: true, mode: 0o700});
      const hostFile = path.join(path.dirname(authFile), 'host-id');
      let host;
      try { host = fs.readFileSync(hostFile, 'utf8'); }
      catch { host = 'urn:uuid:' + crypto.randomUUID(); fs.writeFileSync(hostFile, host, {mode: 0o600, flag: 'wx'}); }
      const state = crypto.randomBytes(32).toString('base64url'), nonce = crypto.randomBytes(32).toString('base64url');
      const verifier = crypto.randomBytes(32).toString('base64url');
      const issuedClient = previous?.client_id;
      const clientId = issuedClient || 'dynamic_agent_client';
      const discovery = await jsonRequest('https://auth.openai.com/.well-known/openid-configuration');
      const url = new URL(discovery.authorization_endpoint);
      if (url.protocol !== 'https:' || url.host !== 'auth.openai.com') fail('AGENT_MODEL_ENDPOINT_INVALID');
      url.search = new URLSearchParams({client_id: clientId, ext_agent_host_id: host,
        response_type: 'code', redirect_uri: redirect.toString(), resource, state, nonce,
        scope: 'openid profile email offline_access resource.invoke chatgpt.tokens.use.direct',
        code_challenge_method: 'S256', code_challenge: crypto.createHash('sha256').update(verifier).digest('base64url'),
        ...(!issuedClient ? {agent_name_hint: 'Valhalla'} : {})}).toString();
      pending = {state, nonce, verifier, issuedClient, identity, previous, redirect: redirect.toString()};
      emit({authorizationUrl: url.toString()});
    } else {
      const callback = new URL(message.callbackUrl);
      const base = new URL(pending.redirect);
      if (callback.origin !== base.origin || callback.pathname !== base.pathname || callback.hash
          || callback.searchParams.get('state') !== pending.state) fail('AGENT_MODEL_CALLBACK_INVALID');
      if (callback.searchParams.has('error')) fail('AGENT_MODEL_AUTH_DECLINED');
      const suppliedClient = callback.searchParams.get('client_id');
      if (pending.issuedClient && suppliedClient && suppliedClient !== pending.issuedClient) fail('AGENT_MODEL_CLIENT_MISMATCH');
      const clientId = suppliedClient || pending.issuedClient;
      const code = callback.searchParams.get('code');
      if (!clientId || clientId === 'dynamic_agent_client' || !code) fail('AGENT_MODEL_AUTH_INVALID_RESPONSE');
      await withCredentialLock(async () => {
        const current = loadRecord();
        if (current?.client_id && current.client_id !== clientId) fail('AGENT_MODEL_CLIENT_MISMATCH');
        const sameAccount = current?.subject === pending.identity.subject
          && current?.codex_account_key === pending.identity.accountKey;
        const registration = {...(sameAccount ? current : {}), client_id: clientId, subject: pending.identity.subject,
          codex_account_key: pending.identity.accountKey};
        // Persist the issued registration before exchanging its single-use code.
        writeRecord(registration);
        const data = await jsonRequest(endpoint, {method: 'POST', headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: new URLSearchParams({grant_type: 'authorization_code', client_id: clientId, code,
            code_verifier: pending.verifier, redirect_uri: pending.redirect, resource})});
        await storeTokens(data, clientId, pending.identity.subject, pending.nonce, registration);
      });
      emit({authorized: true}); input.close();
    }
  } catch (error) { emit({error: safeError(error)}); input.close(); }
  finally { processing = false; }
});
''';

  static String remoteCommand(AgentProfile profile, String script) {
    final encoded = base64.encode(utf8.encode(script));
    final command =
        'exec node -e ${cliShellQuote('eval(Buffer.from("$encoded", "base64").toString("utf8"))')} ${cliShellQuote(credentialKey(profile))}';
    return agentTargetCommand(
      profile,
      profile.executionTarget == 'docker'
          ? command
          : 'bash -l -c ${cliShellQuote(command)}',
    );
  }

  static Future<void> authorize(
    SSHClient ssh,
    AgentProfile profile, {
    required Future<void> Function(Uri url) openBrowser,
    Future<void>? cancelled,
  }) async {
    final callback = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirect = Uri.parse(
      'http://127.0.0.1:${callback.port}/auth/callback',
    );
    SSHSession? process;
    StreamSubscription<List<int>>? stderr;
    StreamSubscription<String>? stdout;
    final completed = Completer<void>();
    // Cancellation or a fast remote failure can precede SSH setup's await.
    // Observe now; the awaited original future still carries the same error.
    unawaited(
      completed.future.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
    String? expectedState;
    var callbackAccepted = false;
    var wasCancelled = false;
    unawaited(
      cancelled?.then((_) {
        wasCancelled = true;
        process?.close();
        if (!completed.isCompleted) {
          completed.completeError(StateError('AGENT_MODEL_AUTH_CANCELLED'));
        }
      }),
    );
    try {
      var expired = false;
      final opening = ssh
          .execute(remoteCommand(profile, '$runtime\n$_authorize'))
          .then((session) {
            if (expired) session.close();
            return session;
          });
      try {
        process = await opening.timeout(const Duration(seconds: 15));
      } on TimeoutException {
        expired = true;
        rethrow;
      }
      final channel = process;
      if (wasCancelled) throw StateError('AGENT_MODEL_AUTH_CANCELLED');
      stderr = channel.stderr.listen((_) {}, onError: (Object _) {});
      stdout = channel.stdout
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (!line.trimLeft().startsWith('{') || completed.isCompleted) {
                return;
              }
              try {
                final message = jsonDecode(line);
                if (message is! Map) return;
                if (message['authorizationUrl'] is String) {
                  final url = Uri.parse(message['authorizationUrl'] as String);
                  if (wasCancelled ||
                      url.scheme != 'https' ||
                      url.host != 'auth.openai.com' ||
                      expectedState != null ||
                      url.queryParameters['redirect_uri'] !=
                          redirect.toString() ||
                      url.queryParameters['resource'] !=
                          'https://api.openai.com/v1') {
                    throw StateError('AGENT_MODEL_ENDPOINT_INVALID');
                  }
                  expectedState = url.queryParameters['state'];
                  if (expectedState == null || expectedState!.isEmpty) {
                    throw StateError('AGENT_MODEL_CALLBACK_INVALID');
                  }
                  unawaited(
                    Future<void>.sync(() => openBrowser(url)).catchError((
                      Object _,
                    ) {
                      if (!completed.isCompleted) {
                        completed.completeError(
                          StateError('AGENT_MODEL_BROWSER_FAILED'),
                        );
                      }
                    }),
                  );
                } else if (message['authorized'] == true) {
                  completed.complete();
                } else if (message['error'] is String) {
                  final code = message['error'] as String;
                  completed.completeError(
                    StateError(
                      RegExp(r'^AGENT_MODEL_[A-Z_]+$').hasMatch(code)
                          ? code
                          : 'AGENT_MODEL_AUTH_FAILED',
                    ),
                  );
                }
              } catch (error) {
                if (!completed.isCompleted) {
                  completed.completeError(
                    StateError(
                      error is StateError &&
                              (error.message ==
                                      'AGENT_MODEL_ENDPOINT_INVALID' ||
                                  error.message ==
                                      'AGENT_MODEL_CALLBACK_INVALID')
                          ? error.message
                          : 'AGENT_MODEL_AUTH_FAILED',
                    ),
                  );
                }
              }
            },
            onError: (Object _) {
              if (!completed.isCompleted) {
                completed.completeError(StateError('AGENT_MODEL_AUTH_FAILED'));
              }
            },
            onDone: () {
              if (!completed.isCompleted) {
                completed.completeError(StateError('AGENT_MODEL_AUTH_FAILED'));
              }
            },
          );
      callback.listen((request) async {
        try {
          final valid =
              !callbackAccepted &&
              expectedState != null &&
              request.method == 'GET' &&
              request.uri.path == redirect.path &&
              request.uri.queryParameters['state'] == expectedState;
          request.response.statusCode = valid
              ? HttpStatus.ok
              : HttpStatus.badRequest;
          if (valid) {
            callbackAccepted = true;
            final url = redirect.replace(query: request.uri.query).toString();
            channel.stdin.add(
              utf8.encode('${jsonEncode({'callbackUrl': url})}\n'),
            );
          }
          await request.response.close();
        } catch (_) {
          if (!completed.isCompleted) {
            completed.completeError(StateError('AGENT_MODEL_AUTH_FAILED'));
          }
        }
      });
      channel.stdin.add(
        utf8.encode('${jsonEncode({'redirectUri': redirect.toString()})}\n'),
      );
      await Future.any([
        completed.future,
        if (cancelled != null)
          cancelled.then((_) => throw StateError('AGENT_MODEL_AUTH_CANCELLED')),
      ]).timeout(const Duration(minutes: 5));
    } finally {
      process?.close();
      await stderr?.cancel();
      await stdout?.cancel();
      await callback.close(force: true);
    }
  }
}
