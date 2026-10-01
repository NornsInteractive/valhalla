import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/infrastructure/cli/codex_account_models.dart';
import 'package:valhalla/infrastructure/cli/codex_model_authorization.dart';

/// 嵌入式 Node OAuth 运行时的**真实执行**证明。
///
/// 被测脚本不是从源码里抠出来的字符串常量，而是和生产完全一样地经假 SSH
/// （`CodexModelAuthorization.authorize`）与 `CodexAccountModels.command`
/// 发出的 base64 命令里解出来的；随后在 Node 里真正跑一遍。
///
/// 安全边界：文件系统全部是内存假 fs，`fetch` 全部是内存假端点，`require`
/// 只允许 fs/path/os/crypto/readline 且 fs 指向假实现，`process` 是假对象。
/// 只有原生 `crypto` 是真的（每次运行现生成一对临时 RSA 密钥当 JWKS）。
/// 没有任何真实凭据、真实文件、真实网络、真实 SSH 或推理。
///
/// 该运行器先由本测试写入 /tmp/opencode/lmd-node/ 再执行；它自身也只读写
/// /tmp 下由本测试创建的文件。
const _runnerSource = r''''use strict';
/* Mocked-fs / mocked-fetch runner for the embedded Codex authorization scripts.
 * No real filesystem, no real network, no real credentials: every require('fs')
 * call, every global fetch and every readline interface is stubbed in-process.
 * Native crypto stays real (ephemeral RSA keys generated per run). */
const vm = require('vm');
const nodeCrypto = require('crypto');
const nodePath = require('path');
const nodeFs = require('fs');

const scenario = process.argv[2];
const target = nodeFs.readFileSync(process.argv[3], 'utf8');

const UID = 1000;
const HOME = '/vh';
const CODEX_HOME = HOME + '/.codex';
const CKEY = 'credkey-test';
const AUTH_DIR = HOME + '/.config/valhalla/model-auth/' + CKEY;
const AUTH_FILE = AUTH_DIR + '/credentials.json';
const LOCK_FILE = AUTH_FILE + '.lock';
const CODEX_AUTH = CODEX_HOME + '/auth.json';
const REDIRECT = 'http://127.0.0.1:5555/auth/callback';
const DISCOVERY = 'https://auth.openai.com/.well-known/openid-configuration';
const JWKS_URI = 'https://auth.openai.com/.well-known/jwks';
const TOKEN_URL = 'https://auth.openai.com/api/accounts/oauth/token';
const MODELS_URL = 'https://api.openai.com/v1/models';
const ISSUER = 'https://auth.openai.com';
const KID = 'kid-runner';
const SECRETS = ['AT-NEW', 'RT-NEW', 'OLD-AT', 'OLD-RT', 'codex-at'];

const ACCOUNT_A = { sub: 'sub-account-a', account_id: 'acct-a' };
const ACCOUNT_B = { sub: 'sub-account-b', account_id: 'acct-b' };

function accountKeyOf(id) {
  return nodeCrypto
    .createHash('sha256')
    .update(id.sub + ':' + String(id.account_id || ''))
    .digest('hex');
}
const KEY_A_HASH = accountKeyOf(ACCOUNT_A);
const KEY_B_HASH = accountKeyOf(ACCOUNT_B);

const keys = nodeCrypto.generateKeyPairSync('rsa', { modulusLength: 2048 });
const otherKeys = nodeCrypto.generateKeyPairSync('rsa', { modulusLength: 2048 });
const jwks = {
  keys: [
    Object.assign({}, keys.publicKey.export({ format: 'jwk' }), {
      kid: KID,
      use: 'sig',
      alg: 'RS256',
    }),
  ],
};

function b64url(text) {
  return Buffer.from(text).toString('base64url');
}
function signJwt(claims, opts) {
  opts = opts || {};
  const header = { alg: 'RS256', kid: opts.kid === undefined ? KID : opts.kid };
  const head = b64url(JSON.stringify(header));
  const body = b64url(JSON.stringify(claims));
  const signer = opts.key || keys.privateKey;
  const sig = nodeCrypto.sign('RSA-SHA256', Buffer.from(head + '.' + body), signer);
  return head + '.' + body + '.' + b64url(sig);
}
function nowSec() {
  return Math.floor(Date.now() / 1000);
}

/* ---------------------------------------------------------------- fake fs */
const store = new Map();
const ops = [];
const fdMap = new Map();
let onLockCreate = null;

function ensureDir(p, mode) {
  const parts = p.split('/').filter(Boolean);
  let cur = '';
  for (const part of parts) {
    cur += '/' + part;
    if (!store.has(cur)) store.set(cur, { kind: 'dir', mode: mode, uid: UID });
  }
}
function putFile(p, data, mode, uid) {
  store.set(p, {
    kind: 'file',
    data: Buffer.isBuffer(data) ? data : Buffer.from(String(data)),
    mode: mode,
    uid: uid === undefined ? UID : uid,
  });
}
function putDir(p, mode) {
  store.set(p, { kind: 'dir', mode: mode, uid: UID });
}
function putLink(p, target) {
  store.set(p, { kind: 'link', target: target, mode: 0o777, uid: UID });
}
function failWith(code, message) {
  const e = new Error(message);
  e.code = code;
  return e;
}
function statOf(p) {
  const entry = store.get(p);
  if (!entry) {
    throw failWith('ENOENT', "ENOENT: no such file or directory, lstat '" + p + "'");
  }
  return {
    mode: entry.mode,
    uid: entry.uid,
    isFile: function () { return entry.kind === 'file'; },
    isDirectory: function () { return entry.kind === 'dir'; },
    isSymbolicLink: function () { return entry.kind === 'link'; },
  };
}

const fsStub = {
  lstatSync: function (p) {
    ops.push({ op: 'lstat', path: p });
    return statOf(p);
  },
  readFileSync: function (p, enc) {
    ops.push({ op: 'read', path: p });
    const entry = store.get(p);
    if (!entry) {
      throw failWith('ENOENT', "ENOENT: no such file or directory, open '" + p + "'");
    }
    if (entry.kind !== 'file') {
      throw failWith('EISDIR', 'EISDIR: illegal operation on a directory, read');
    }
    return enc === undefined || enc === 'utf8' ? entry.data.toString('utf8') : entry.data;
  },
  mkdirSync: function (p, opts) {
    ops.push({ op: 'mkdir', path: p, mode: opts && opts.mode });
    ensureDir(p, (opts && opts.mode) || 0o700);
  },
  writeFileSync: function (p, data, opts) {
    const flag = (opts && opts.flag) || 'w';
    const mode = opts && opts.mode !== undefined ? opts.mode : 0o666;
    ops.push({ op: 'write', path: p, mode: mode, flag: flag });
    if (flag.indexOf('x') !== -1 && store.has(p)) {
      throw failWith('EEXIST', 'EEXIST: file already exists');
    }
    putFile(p, data, mode);
  },
  renameSync: function (from, to) {
    ops.push({ op: 'rename', from: from, to: to });
    const entry = store.get(from);
    if (!entry) throw failWith('ENOENT', 'ENOENT: no such file or directory');
    store.delete(from);
    store.set(to, entry);
  },
  unlinkSync: function (p) {
    ops.push({ op: 'unlink', path: p });
    if (!store.has(p)) {
      throw failWith('ENOENT', "ENOENT: no such file or directory, unlink '" + p + "'");
    }
    store.delete(p);
  },
  openSync: function (p, flags, mode) {
    const resolved = mode === undefined ? 0o666 : mode;
    ops.push({ op: 'open', path: p, flag: flags, mode: resolved });
    if (flags.indexOf('x') !== -1 && store.has(p)) {
      throw failWith('EEXIST', 'EEXIST: file already exists');
    }
    putFile(p, '', resolved);
    if (p === LOCK_FILE && onLockCreate) {
      const cb = onLockCreate;
      onLockCreate = null;
      cb();
    }
    const fd = fdMap.size + 10;
    fdMap.set(fd, p);
    return fd;
  },
  closeSync: function (fd) {
    ops.push({ op: 'close', fd: fd });
    fdMap.delete(fd);
  },
};

/* -------------------------------------------------------------- fake fetch */
const fetchLog = [];
let fetchHandler = function (url) {
  throw failWith('ENOMOCK', 'no fetch handler registered for ' + url);
};

/* --------------------------------------------------------------- sandbox */
let outLines = [];
let lineHandler = null;
let bodyFactory = null;

function responseBody(chunks) {
  if (!bodyFactory) throw new Error('context not built');
  return bodyFactory(chunks.map(function (chunk) { return Buffer.from(chunk); }));
}
function jsonResponse(value) {
  return { ok: true, status: 200, body: responseBody([Buffer.from(JSON.stringify(value))]) };
}
function statusResponse(status) {
  return { ok: false, status: status, body: responseBody([]) };
}
function fakeFetch(url, options) {
  fetchLog.push({ url: String(url), options: options || {} });
  return Promise.resolve(fetchHandler(String(url), options || {}));
}

function buildContext() {
  const sandbox = {
    require: function (name) {
      if (name === 'fs') return fsStub;
      if (name === 'path') return nodePath;
      if (name === 'os') return { homedir: function () { return HOME; } };
      if (name === 'crypto') return nodeCrypto;
      if (name === 'readline') {
        return {
          createInterface: function () {
            return {
              on: function (event, cb) {
                if (event === 'line') lineHandler = cb;
              },
              close: function () {},
            };
          },
        };
      }
      throw new Error('require blocked by runner: ' + name);
    },
    process: {
      argv: ['node', CKEY],
      env: { CODEX_HOME: CODEX_HOME },
      getuid: function () { return UID; },
      stdout: {
        write: function (chunk) {
          outLines.push(String(chunk));
          return true;
        },
      },
      stdin: {},
      once: function () {},
      on: function () {},
      exit: function () {},
      exitCode: 0,
    },
    Buffer: Buffer,
    URL: URL,
    URLSearchParams: URLSearchParams,
    AbortSignal: AbortSignal,
    fetch: fakeFetch,
    setTimeout: setTimeout,
    clearTimeout: clearTimeout,
  };
  const ctx = vm.createContext(sandbox);
  bodyFactory = vm.runInContext(
    '(chunks) => (async function* () { for (const c of chunks) yield Buffer.from(c); })()',
    ctx
  );
  return ctx;
}

/* --------------------------------------------------------------- helpers */
function parsedOut() {
  return outLines.map(function (line) {
    try {
      return JSON.parse(line);
    } catch (e) {
      return { raw: line };
    }
  });
}
function lastOut() {
  const all = parsedOut();
  return all.length ? all[all.length - 1] : null;
}
function sleep(ms) {
  return new Promise(function (resolve) { setTimeout(resolve, ms); });
}
async function waitForOutput(predicate, ms) {
  const deadline = Date.now() + (ms || 5000);
  while (Date.now() < deadline) {
    const all = parsedOut();
    for (const entry of all) {
      if (predicate(entry)) return entry;
    }
    await sleep(10);
  }
  return null;
}
async function pushLine(message) {
  if (!lineHandler) throw new Error('readline line handler was never registered');
  await lineHandler(JSON.stringify(message));
}
function tokenFetches() {
  return fetchLog.filter(function (e) { return e.url === TOKEN_URL; });
}
function modelsFetches() {
  return fetchLog.filter(function (e) { return e.url === MODELS_URL; });
}
function tokenBody(entry) {
  const params = new URLSearchParams(String(entry.options.body || ''));
  const out = {};
  params.forEach(function (value, key) { out[key] = value; });
  return out;
}
function readCredential() {
  const entry = store.get(AUTH_FILE);
  if (!entry || entry.kind !== 'file') return null;
  return {
    mode: entry.mode.toString(8),
    uid: entry.uid,
    value: JSON.parse(entry.data.toString('utf8')),
  };
}
function sha256b64url(text) {
  return nodeCrypto.createHash('sha256').update(text).digest('base64url');
}
function stdoutLeaksToken() {
  for (const line of outLines) {
    for (const secret of SECRETS) {
      if (line.indexOf(secret) !== -1) return true;
    }
  }
  return false;
}
function recordedOps(kinds) {
  return ops.filter(function (entry) { return kinds.indexOf(entry.op) !== -1; });
}

/* ------------------------------------------------------ scenario fixtures */
function seedCodexAuth(id) {
  ensureDir(CODEX_HOME, 0o700);
  putFile(
    CODEX_AUTH,
    JSON.stringify({
      auth_mode: 'chatgpt',
      tokens: {
        id_token: signJwt({ iss: ISSUER, aud: 'codex-cli', sub: id.sub, exp: nowSec() + 3600 }),
        access_token: 'codex-at',
        account_id: id.account_id,
      },
    }),
    0o600
  );
}
function expiredRecord() {
  return {
    client_id: 'client-1',
    subject: ACCOUNT_A.sub,
    codex_account_key: KEY_A_HASH,
    access_token: 'OLD-AT',
    refresh_token: 'OLD-RT',
    id_token: 'OLD-ID',
    scopes: ['openid', 'profile', 'chatgpt.tokens.use.direct'],
    expires_at: Date.now() - 3600000,
  };
}
function previousRecord(clientId) {
  return {
    client_id: clientId,
    subject: ACCOUNT_A.sub,
    codex_account_key: KEY_A_HASH,
    access_token: 'OLD-AT',
    refresh_token: 'OLD-RT',
    id_token: 'OLD-ID',
    scopes: ['chatgpt.tokens.use.direct'],
    expires_at: Date.now() + 3600000,
  };
}
function seedCredential(record, mode, uid, asLink) {
  ensureDir(AUTH_DIR, 0o700);
  if (asLink) {
    putLink(AUTH_FILE, '/elsewhere/credentials.json');
    return;
  }
  putFile(AUTH_FILE, JSON.stringify(record), mode === undefined ? 0o600 : mode, uid);
}

const tokenState = {
  nonce: null,
  clientId: 'client-1',
  idTokenOverride: null,
  scope: null,
  tokenStatus: 200,
  discoveryOverride: null,
};

function standardFetch(url) {
  if (url === DISCOVERY) {
    return jsonResponse(
      tokenState.discoveryOverride || {
        issuer: ISSUER,
        authorization_endpoint: ISSUER + '/authorize',
        jwks_uri: JWKS_URI,
      }
    );
  }
  if (url === JWKS_URI) return jsonResponse(jwks);
  if (url === TOKEN_URL) {
    if (tokenState.tokenStatus !== 200) return statusResponse(tokenState.tokenStatus);
    const claims = {
      iss: ISSUER,
      aud: tokenState.clientId,
      azp: tokenState.clientId,
      sub: ACCOUNT_A.sub,
      exp: nowSec() + 3600,
    };
    if (tokenState.nonce !== null) claims.nonce = tokenState.nonce;
    return jsonResponse({
      access_token: 'AT-NEW',
      refresh_token: 'RT-NEW',
      token_type: 'Bearer',
      expires_in: 3600,
      scope: tokenState.scope || 'openid profile chatgpt.tokens.use.direct',
      id_token: tokenState.idTokenOverride || signJwt(claims),
    });
  }
  if (url === MODELS_URL) {
    return jsonResponse({
      models: [
        { slug: 'gpt-5-codex', display_name: 'Codex', visibility: 'list' },
        { slug: 'hidden', display_name: 'Hidden', visibility: 'none' },
      ],
    });
  }
  throw failWith('EBLOCKED', 'unexpected fetch blocked by runner: ' + url);
}

function setupAuthorize() {
  tokenState.nonce = null;
  tokenState.clientId = 'client-1';
  tokenState.idTokenOverride = null;
  tokenState.scope = null;
  tokenState.tokenStatus = 200;
  tokenState.discoveryOverride = null;

  seedCodexAuth(ACCOUNT_A);
  if (scenario === 'authorize_client_mismatch') {
    seedCredential(previousRecord('client-A'));
  } else if (scenario === 'authorize_rebind_failed_exchange') {
    seedCodexAuth(ACCOUNT_B);
    seedCredential(previousRecord('client-A'));
    tokenState.tokenStatus = 401;
  } else if (scenario === 'authorize_same_account_failed_exchange') {
    seedCredential(previousRecord('client-A'));
    tokenState.tokenStatus = 401;
  }
  if (scenario === 'authorize_missing_grant') tokenState.scope = 'openid profile email';
  if (scenario === 'authorize_endpoint_blocked') {
    tokenState.discoveryOverride = {
      issuer: ISSUER,
      authorization_endpoint: ISSUER + '/authorize',
      jwks_uri: 'https://evil.example/jwks',
    };
  } else if (scenario === 'authorize_endpoint_insecure') {
    tokenState.discoveryOverride = {
      issuer: ISSUER,
      authorization_endpoint: 'http://auth.openai.com/authorize',
      jwks_uri: JWKS_URI,
    };
  }
  fetchHandler = standardFetch;
}

function authorizeClientId() {
  if (scenario === 'authorize_client_mismatch') return 'client-B';
  if (
    scenario === 'authorize_rebind_failed_exchange' ||
    scenario === 'authorize_same_account_failed_exchange'
  ) {
    return 'client-A';
  }
  return 'client-1';
}

function setupRefresh() {
  seedCodexAuth(ACCOUNT_A);
  if (scenario === 'storage_unsafe_mode') {
    seedCredential(expiredRecord(), 0o644);
  } else if (scenario === 'storage_unsafe_owner') {
    seedCredential(expiredRecord(), 0o600, 999);
  } else if (scenario === 'storage_symlink') {
    seedCredential(expiredRecord(), 0o600, UID, true);
  } else if (scenario === 'storage_dir_unsafe_write') {
    seedCredential(expiredRecord());
    putDir(AUTH_DIR, 0o777);
  } else {
    seedCredential(expiredRecord());
  }
  if (scenario === 'refresh_post_lock_account_rebind') {
    onLockCreate = function () {
      const current = JSON.parse(store.get(AUTH_FILE).data.toString('utf8'));
      current.codex_account_key = KEY_B_HASH;
      current.subject = ACCOUNT_B.sub;
      putFile(AUTH_FILE, JSON.stringify(current), 0o600);
    };
  } else if (scenario === 'refresh_post_lock_scope_rebind') {
    onLockCreate = function () {
      const current = JSON.parse(store.get(AUTH_FILE).data.toString('utf8'));
      current.scopes = ['openid', 'profile'];
      putFile(AUTH_FILE, JSON.stringify(current), 0o600);
    };
  }
  tokenState.nonce = null;
  tokenState.clientId = 'client-1';
  tokenState.idTokenOverride = null;
  tokenState.scope = null;
  tokenState.tokenStatus = 200;
  fetchHandler = standardFetch;
}

async function driveAuthorize(report) {
  await pushLine({ redirectUri: REDIRECT });
  const authorization = await waitForOutput(function (m) { return !!m.authorizationUrl; }, 5000);
  report.authorization = authorization;
  if (!authorization || typeof authorization.authorizationUrl !== 'string') return report;

  const url = new URL(authorization.authorizationUrl);
  tokenState.nonce = url.searchParams.get('nonce');
  tokenState.clientId = authorizeClientId();
  report.authUrlChecks = {
    protocol: url.protocol,
    host: url.host,
    redirectUri: url.searchParams.get('redirect_uri'),
    resource: url.searchParams.get('resource'),
    state: url.searchParams.get('state'),
    nonce: tokenState.nonce,
    codeChallengeMethod: url.searchParams.get('code_challenge_method'),
    codeChallenge: url.searchParams.get('code_challenge'),
    urlClientId: url.searchParams.get('client_id'),
  };

  const clientId = tokenState.clientId;
  let callback =
    REDIRECT +
    '?state=' + encodeURIComponent(url.searchParams.get('state')) +
    '&code=authcode-1' +
    '&client_id=' + clientId;
  if (scenario === 'authorize_state_mismatch') {
    callback = REDIRECT + '?state=wrong-state&code=authcode-1&client_id=' + clientId;
  } else if (scenario === 'authorize_declined') {
    callback =
      REDIRECT +
      '?state=' + encodeURIComponent(url.searchParams.get('state')) +
      '&error=access_denied' +
      '&client_id=' + clientId;
  }

  if (scenario === 'authorize_bad_signature') {
    tokenState.idTokenOverride = signJwt(
      {
        iss: ISSUER, aud: clientId, azp: clientId,
        sub: ACCOUNT_A.sub, exp: nowSec() + 3600, nonce: tokenState.nonce,
      },
      { key: otherKeys.privateKey }
    );
  } else if (scenario === 'authorize_bad_audience') {
    tokenState.idTokenOverride = signJwt({
      iss: ISSUER, aud: 'someone-else', azp: 'someone-else',
      sub: ACCOUNT_A.sub, exp: nowSec() + 3600, nonce: tokenState.nonce,
    });
  } else if (scenario === 'authorize_expired') {
    tokenState.idTokenOverride = signJwt({
      iss: ISSUER, aud: clientId, azp: clientId,
      sub: ACCOUNT_A.sub, exp: nowSec() - 3600, nonce: tokenState.nonce,
    });
  } else if (scenario === 'authorize_bad_nonce') {
    tokenState.idTokenOverride = signJwt({
      iss: ISSUER, aud: clientId, azp: clientId,
      sub: ACCOUNT_A.sub, exp: nowSec() + 3600, nonce: 'not-the-nonce',
    });
  } else if (scenario === 'authorize_bad_subject') {
    tokenState.idTokenOverride = signJwt({
      iss: ISSUER, aud: clientId, azp: clientId,
      sub: 'someone-else', exp: nowSec() + 3600, nonce: tokenState.nonce,
    });
  }

  await pushLine({ callbackUrl: callback });
  return report;
}

async function main() {
  const isAuthorize = scenario.indexOf('authorize_') === 0;
  if (isAuthorize) setupAuthorize();
  else setupRefresh();
  const credentialBefore = readCredential();

  const ctx = buildContext();
  vm.runInContext(target, ctx, { filename: 'target.js' });

  const report = {
    scenario: scenario,
    target: isAuthorize ? 'authorize' : 'account-models',
    credentialBefore: credentialBefore,
  };

  if (isAuthorize) {
    await driveAuthorize(report);
    const requests = tokenFetches();
    report.tokenRequests = requests.map(tokenBody);
    report.tokenFetchCount = requests.length;
    if (report.tokenRequests.length && report.authUrlChecks) {
      report.pkceMatches =
        sha256b64url(report.tokenRequests[0].code_verifier || '') ===
        (report.authUrlChecks.codeChallenge || '');
      report.pkceVerifierDiffers =
        (report.tokenRequests[0].code_verifier || '') !==
        (report.authUrlChecks.codeChallenge || '');
    }
  } else {
    report.result = await waitForOutput(
      function (m) { return !!m.error || !!m.models || !!m.accountKey; },
      6000
    );
    report.tokenFetchCount = tokenFetches().length;
    report.modelsFetchCount = modelsFetches().length;
  }

  report.messages = parsedOut();
  report.final = lastOut();
  report.credentialAfter = readCredential();
  report.stdoutLeaksToken = stdoutLeaksToken();
  report.fileOps = recordedOps(['write', 'rename', 'unlink', 'open']);
  report.tempLeftovers = Array.from(store.keys()).filter(function (p) {
    return p.indexOf('.tmp') !== -1;
  });
  report.lockLeft = store.has(LOCK_FILE);
  report.fetchedUrls = fetchLog.map(function (entry) { return entry.url; });
  return report;
}

main()
  .then(function (report) {
    process.stdout.write('@@RESULT@@' + JSON.stringify(report) + '\n');
  })
  .catch(function (error) {
    process.stdout.write(
      '@@RESULT@@' +
        JSON.stringify({ scenario: scenario, fatal: String((error && error.stack) || error) }) +
        '\n'
    );
    process.exitCode = 1;
  });
''';

/// 假文件根：被测脚本可见的一切路径都在这里，绝不会落到真实 HOME。
const _sandboxRoot = '/vh';
const _workDir = '/tmp/opencode/lmd-node';

const _nodeCandidates = <String>[
  'node',
  '/opt/nvm/versions/node/v24.16.0/bin/node',
  '/usr/local/bin/node',
  '/usr/bin/node',
];

/// 允许被测脚本触达的全部 https 端点。
const _allowedEndpoints = <String>{
  'https://auth.openai.com/.well-known/openid-configuration',
  'https://auth.openai.com/.well-known/jwks',
  'https://auth.openai.com/api/accounts/oauth/token',
  'https://api.openai.com/v1/models',
};

const _keyA = 'sub-account-a';
const _accountKeyA =
    '99fac8fe9c0388500343a4fd158a462773020be7282c97e7137119652f6076b1';

String? _nodeExecutable;

void main() {
  final runnerPath = '$_workDir/runner.js';
  final authorizePath = '$_workDir/authorize.js';
  final modelsPath = '$_workDir/models.js';

  AgentProfile profile() => AgentProfile(
    id: 'builtin-codex',
    serverId: 'srv-1',
    name: 'codex',
    description: 'codex',
    cliCommand: 'codex',
    acpCommand: 'acp --stdio',
    executionTarget: 'host',
    containerBinding: 'name',
  );

  setUpAll(() async {
    final dir = await Directory(_workDir).create(recursive: true);
    expect(dir.path, _workDir);
    File(runnerPath).writeAsStringSync(_runnerSource);

    // 与生产完全一致地取回授权脚本：假 SSH + 本机回环回调。
    final session = _FakeSession();
    session.onStdinLine = (_) =>
        session.pushLine(jsonEncode({'error': 'AGENT_MODEL_AUTH_DECLINED'}));
    final ssh = _FakeSsh(session);
    try {
      await CodexModelAuthorization.authorize(
        ssh,
        profile(),
        openBrowser: (_) async {},
      ).timeout(const Duration(seconds: 10));
    } catch (_) {
      // 预期以固定错误码结束；这里只要取回命令。
    }
    expect(ssh.commands, hasLength(1));
    final authorize = _decodeScript(ssh.commands.single);
    final models = _decodeScript(CodexAccountModels.command(profile()));

    expect(
      authorize,
      startsWith(CodexModelAuthorization.runtime),
      reason: '授权脚本必须以共享运行时开头',
    );
    expect(
      models,
      startsWith(CodexModelAuthorization.runtime),
      reason: '账户模型脚本必须以共享运行时开头',
    );
    File(authorizePath).writeAsStringSync(authorize);
    File(modelsPath).writeAsStringSync(models);
  });

  group('授权脚本：Node vm 里的真实执行', () {
    test('成功授权：RS256 校验、PKCE 单次、0600 原子写入、令牌不回传 stdout', () async {
      final report = await _run('authorize_ok', authorizePath);
      _expectSandboxed(report);

      final authorization = report['authorization'] as Map<String, dynamic>;
      expect(
        authorization['authorizationUrl'],
        startsWith('https://auth.openai.com/authorize?'),
      );

      final checks = report['authUrlChecks'] as Map<String, dynamic>;
      expect(checks['protocol'], 'https:');
      expect(checks['host'], 'auth.openai.com');
      expect(
        checks['redirectUri'],
        'http://127.0.0.1:5555/auth/callback',
        reason: '回调必须固定为本机回环与固定路径',
      );
      expect(checks['resource'], 'https://api.openai.com/v1');
      expect(checks['codeChallengeMethod'], 'S256');
      expect(checks['state'], isNotEmpty);
      expect(checks['nonce'], isNotEmpty);
      expect(checks['codeChallenge'], isNotEmpty);

      final requests = (report['tokenRequests'] as List)
          .cast<Map<String, dynamic>>();
      expect(requests, hasLength(1));
      expect(requests.single['grant_type'], 'authorization_code');
      expect(requests.single['client_id'], 'client-1');
      expect(requests.single['code'], isNotEmpty);
      expect(requests.single['code_verifier'], isNotEmpty);
      expect(
        report['pkceMatches'],
        isTrue,
        reason: 'code_verifier 必须真是 code_challenge 的 SHA-256',
      );
      expect(
        report['pkceVerifierDiffers'],
        isTrue,
        reason: 'verifier 不得直接等于 challenge（否则 PKCE 退化为恒等）',
      );

      final stored = _stored(report);
      expect(_mode(report), '600');
      expect(stored['client_id'], 'client-1');
      expect(stored['subject'], _keyA);
      expect(stored['codex_account_key'], _accountKeyA);
      expect(stored['access_token'], 'AT-NEW');
      expect(stored['refresh_token'], 'RT-NEW');
      expect(stored['scopes'], contains('chatgpt.tokens.use.direct'));

      final ops = _ops(report);
      expect(
        _opsWhere(ops, kind: 'open', suffix: 'credentials.json.lock'),
        hasLength(1),
        reason: '必须以 wx 排他锁包裹交换',
      );
      expect(
        ops.any(
          (op) =>
              op['op'] == 'open' &&
              op['flag'] == 'wx' &&
              op['mode'] == 384 &&
              op['path'] is String &&
              (op['path'] as String).endsWith('credentials.json.lock'),
        ),
        isTrue,
      );
      expect(
        _opsWhere(ops, kind: 'write').any(
          (op) =>
              (op['path'] as String).endsWith('.tmp') &&
              op['flag'] == 'wx' &&
              op['mode'] == 384,
        ),
        isTrue,
        reason: '凭据必须经 0600 + wx 临时文件写入',
      );
      expect(
        _opsWhere(
          ops,
          kind: 'rename',
        ).any((op) => (op['to'] as String).endsWith('/credentials.json')),
        isTrue,
        reason: '最终落盘必须是 rename 而不是直接覆盖写',
      );
      expect(
        ops.any(
          (op) =>
              op['op'] == 'write' &&
              op['path'] is String &&
              (op['path'] as String).endsWith('/credentials.json'),
        ),
        isFalse,
        reason: '绝不能直接 writeFileSync(credentials.json)',
      );
      expect(
        _opsWhere(ops, kind: 'unlink', suffix: 'credentials.json.lock'),
        hasLength(1),
        reason: '锁必须释放',
      );
      expect(_record(report, 'credentialAfter')['uid'], 1000);
    });

    test('回调 state 不匹配：拒绝且根本不发起令牌交换', () async {
      final report = await _run('authorize_state_mismatch', authorizePath);
      _expectSandboxed(report);
      expect(_error(report), 'AGENT_MODEL_CALLBACK_INVALID');
      expect(report['tokenFetchCount'], 0);
      expect(report['credentialAfter'], isNull);
      expect(_credentialTouched(_ops(report)), isEmpty);
      expect(_lockOps(_ops(report)), isEmpty);
    });

    test('用户拒绝授权：拒绝且不写任何凭据', () async {
      final report = await _run('authorize_declined', authorizePath);
      _expectSandboxed(report);
      expect(_error(report), 'AGENT_MODEL_AUTH_DECLINED');
      expect(report['tokenFetchCount'], 0);
      expect(report['credentialAfter'], isNull);
      expect(_credentialTouched(_ops(report)), isEmpty);
      expect(_lockOps(_ops(report)), isEmpty);
    });

    test('回调 client_id 与已签发记录不符：拒绝且旧凭据原封不动', () async {
      final report = await _run('authorize_client_mismatch', authorizePath);
      _expectSandboxed(report);
      expect(_error(report), 'AGENT_MODEL_CLIENT_MISMATCH');
      expect(report['tokenFetchCount'], 0);
      expect(
        _credentialTouched(_ops(report)),
        isEmpty,
        reason: '校验失败必须发生在凭据写入之前',
      );
      expect(_lockOps(_ops(report)), isEmpty, reason: '失败前不得拿到排他锁');
      final stored = _stored(report);
      expect(stored['access_token'], 'OLD-AT');
      expect(stored['refresh_token'], 'OLD-RT');
    });

    for (final entry in const <String, String>{
      'authorize_bad_signature': '签名密钥不对',
      'authorize_bad_audience': 'audience 不是本 client',
      'authorize_expired': 'exp 已过期',
      'authorize_bad_nonce': 'nonce 不是本次请求的',
    }.entries) {
      test('${entry.key}：拒绝 ${entry.value}，且不落任何令牌', () async {
        final report = await _run(entry.key, authorizePath);
        _expectSandboxed(report);
        expect(_error(report), 'AGENT_MODEL_IDENTITY_INVALID');
        expect(report['tokenFetchCount'], 1);
        final stored = _stored(report);
        expect(stored.containsKey('access_token'), isFalse);
        expect(stored.containsKey('refresh_token'), isFalse);
        expect(stored['subject'], _keyA);
        expect(stored['codex_account_key'], _accountKeyA);
      });
    }

    test('id_token 主体与当前 Codex 账号不符：ACCOUNT_MISMATCH 且不落令牌', () async {
      final report = await _run('authorize_bad_subject', authorizePath);
      _expectSandboxed(report);
      expect(_error(report), 'AGENT_MODEL_ACCOUNT_MISMATCH');
      expect(report['tokenFetchCount'], 1);
      expect(_stored(report).containsKey('access_token'), isFalse);
    });

    test('缺 chatgpt.tokens.use.direct 直接授权：PLAN_PERMISSION_REQUIRED', () async {
      final report = await _run('authorize_missing_grant', authorizePath);
      _expectSandboxed(report);
      expect(_error(report), 'AGENT_MODEL_PLAN_PERMISSION_REQUIRED');
      expect(report['tokenFetchCount'], 1);
      expect(_stored(report).containsKey('access_token'), isFalse);
    });

    test('换绑账号后交换失败：旧 access_token 必须被丢弃', () async {
      final report = await _run(
        'authorize_rebind_failed_exchange',
        authorizePath,
      );
      _expectSandboxed(report);
      expect(_error(report), 'AGENT_MODEL_AUTH_EXPIRED');
      expect(report['tokenFetchCount'], 1);
      final stored = _stored(report);
      expect(
        stored.containsKey('access_token'),
        isFalse,
        reason: '换绑后的注册记录必须先丢掉旧 access_token 再交换',
      );
      expect(stored.containsKey('refresh_token'), isFalse);
      expect(stored['subject'], isNot(_keyA));
      expect(stored['client_id'], 'client-A');
      expect(stored['codex_account_key'], isNot(_accountKeyA));
    });

    test('同账号交换失败：绑定未变，旧令牌保留且没有新令牌写入', () async {
      final report = await _run(
        'authorize_same_account_failed_exchange',
        authorizePath,
      );
      _expectSandboxed(report);
      expect(_error(report), 'AGENT_MODEL_AUTH_EXPIRED');
      expect(report['tokenFetchCount'], 1);
      final stored = _stored(report);
      expect(stored['access_token'], 'OLD-AT');
      expect(stored['refresh_token'], 'OLD-RT');
      expect(stored['codex_account_key'], _accountKeyA);
    });

    test('JWKS 指向白名单外主机：先拒绝，绝不发起该 fetch', () async {
      final report = await _run('authorize_endpoint_blocked', authorizePath);
      _expectSandboxed(report);
      expect(_error(report), 'AGENT_MODEL_ENDPOINT_INVALID');
      expect(
        _fetched(report).any((url) => url.contains('evil.example')),
        isFalse,
        reason: '白名单外的主机必须在 fetch 之前就被拒绝',
      );
      expect(_stored(report).containsKey('access_token'), isFalse);
    });

    test('发现文档给 http 端点：拒绝且不发任何浏览器 URL', () async {
      final report = await _run('authorize_endpoint_insecure', authorizePath);
      _expectSandboxed(report);
      expect(_error(report), 'AGENT_MODEL_ENDPOINT_INVALID');
      expect(report['authorization'], isNull);
      expect(report['tokenFetchCount'], 0);
      expect(report['credentialAfter'], isNull);
      expect(_fetched(report), [
        'https://auth.openai.com/.well-known/openid-configuration',
      ]);
    });
  });

  group('账户模型脚本：Node vm 里的真实执行', () {
    test('刷新成功：原子 0600 写入、排他锁、只返回 list 可见模型', () async {
      final report = await _run('refresh_ok_atomic_write', modelsPath);
      _expectSandboxed(report);

      final result = report['result'] as Map<String, dynamic>;
      expect(result['accountKey'], _accountKeyA);
      expect(result['models'], <Map<String, Object?>>[
        {'slug': 'gpt-5-codex', 'display_name': 'Codex', 'visibility': 'list'},
      ]);
      expect(report['tokenFetchCount'], 1);
      expect(report['modelsFetchCount'], 1);

      final stored = _stored(report);
      expect(stored['access_token'], 'AT-NEW');
      expect(stored['refresh_token'], 'RT-NEW');
      expect(_mode(report), '600');

      final ops = _ops(report);
      expect(
        _opsWhere(ops, kind: 'open', suffix: 'credentials.json.lock'),
        hasLength(1),
      );
      expect(
        _opsWhere(
          ops,
          kind: 'write',
        ).where((op) => (op['path'] as String).endsWith('.tmp')),
        hasLength(1),
        reason: '必须走临时文件',
      );
      expect(
        _opsWhere(
          ops,
          kind: 'rename',
        ).any((op) => (op['to'] as String).endsWith('/credentials.json')),
        isTrue,
        reason: '最终落盘必须是 rename',
      );
      expect(
        ops.any(
          (op) =>
              op['op'] == 'write' &&
              op['path'] is String &&
              (op['path'] as String).endsWith('/credentials.json'),
        ),
        isFalse,
        reason: '绝不能直接 writeFileSync(credentials.json)',
      );
      expect(
        _opsWhere(ops, kind: 'unlink', suffix: '.tmp'),
        hasLength(1),
        reason: '临时文件必须清理',
      );
      expect(
        _opsWhere(ops, kind: 'unlink', suffix: 'credentials.json.lock'),
        hasLength(1),
        reason: '锁必须释放',
      );
    });

    test('锁内 reread 到账号换绑：在网络请求之前拒绝', () async {
      final report = await _run('refresh_post_lock_account_rebind', modelsPath);
      _expectSandboxed(report);
      final result = report['result'] as Map<String, dynamic>;
      expect(result['error'], 'AGENT_MODEL_ACCOUNT_MISMATCH');
      expect(result['accountKey'], _accountKeyA);
      expect(
        report['tokenFetchCount'],
        0,
        reason: '绑定变化必须在发起令牌请求之前被锁内 reread 拦住',
      );
      expect(report['modelsFetchCount'], 0);
      expect(_stored(report)['subject'], isNot(_keyA));
    });

    test('锁内 reread 到 scope 失去直连授权：拒绝且不发网络请求', () async {
      final report = await _run('refresh_post_lock_scope_rebind', modelsPath);
      _expectSandboxed(report);
      final result = report['result'] as Map<String, dynamic>;
      expect(result['error'], 'AGENT_MODEL_PLAN_PERMISSION_REQUIRED');
      expect(report['tokenFetchCount'], 0);
      expect(report['modelsFetchCount'], 0);
      expect(_stored(report)['scopes'], <String>['openid', 'profile']);
    });

    test('凭据文件 0644：拒绝、零网络、零写入', () async {
      final report = await _run('storage_unsafe_mode', modelsPath);
      _expectSandboxed(report);
      final result = report['result'] as Map<String, dynamic>;
      expect(result['error'], 'AGENT_MODEL_AUTH_STORAGE_UNSAFE');
      expect(_record(report, 'credentialBefore')['mode'], '644');
      expect(report['tokenFetchCount'], 0);
      expect(report['modelsFetchCount'], 0);
      expect(_ops(report), isEmpty);
    });

    test('凭据文件属主不是当前 uid：拒绝、零网络、零写入', () async {
      final report = await _run('storage_unsafe_owner', modelsPath);
      _expectSandboxed(report);
      final result = report['result'] as Map<String, dynamic>;
      expect(result['error'], 'AGENT_MODEL_AUTH_STORAGE_UNSAFE');
      expect(_record(report, 'credentialBefore')['uid'], 999);
      expect(report['tokenFetchCount'], 0);
      expect(_ops(report), isEmpty);
    });

    test('凭据文件是符号链接：拒绝、零网络、零写入', () async {
      final report = await _run('storage_symlink', modelsPath);
      _expectSandboxed(report);
      final result = report['result'] as Map<String, dynamic>;
      expect(result['error'], 'AGENT_MODEL_AUTH_STORAGE_UNSAFE');
      expect(report['tokenFetchCount'], 0);
      expect(report['credentialAfter'], isNull);
      expect(_ops(report), isEmpty);
    });

    test('凭据目录 0777：写入前拒绝，临时文件与 rename 都不发生', () async {
      final report = await _run('storage_dir_unsafe_write', modelsPath);
      _expectSandboxed(report);
      final result = report['result'] as Map<String, dynamic>;
      expect(result['error'], 'AGENT_MODEL_AUTH_STORAGE_UNSAFE');
      expect(report['modelsFetchCount'], 0);
      final ops = _ops(report);
      expect(_opsWhere(ops, kind: 'write'), isEmpty);
      expect(_opsWhere(ops, kind: 'rename'), isEmpty);
      expect(_stored(report)['access_token'], 'OLD-AT');
      expect(
        _opsWhere(ops, kind: 'unlink', suffix: 'credentials.json.lock'),
        hasLength(1),
        reason: '锁仍必须释放',
      );
    });
  });
}

/// 运行一个场景并解出 `@@RESULT@@` 报告行。
Future<Map<String, dynamic>> _run(String scenario, String scriptPath) async {
  final executable = await _resolveNode();
  final ProcessResult result;
  try {
    result = await Process.run(executable, [
      '$_workDir/runner.js',
      scenario,
      scriptPath,
    ]).timeout(const Duration(seconds: 60));
  } on ProcessException catch (error) {
    throw StateError('Node 安全证明不可用（无法启动 $executable）：$error');
  } on TimeoutException {
    throw StateError('Node 安全证明不可用：场景 $scenario 超时');
  }
  expect(
    result.exitCode,
    0,
    reason:
        '场景 $scenario 必须成功执行\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}',
  );

  const marker = '@@RESULT@@';
  final lines = (result.stdout as String)
      .split('\n')
      .where((line) => line.startsWith(marker))
      .toList();
  expect(
    lines,
    hasLength(1),
    reason: '场景 $scenario 必须恰好输出一行报告\nstdout:\n${result.stdout}',
  );
  final decoded = jsonDecode(lines.single.substring(marker.length));
  expect(
    decoded,
    isA<Map<String, dynamic>>(),
    reason: '报告必须是 JSON 对象\n${lines.single}',
  );
  return decoded as Map<String, dynamic>;
}

Future<String> _resolveNode() async {
  if (_nodeExecutable != null) return _nodeExecutable!;
  final failures = <String>[];
  for (final candidate in _nodeCandidates) {
    try {
      final probe = await Process.run(candidate, [
        '--version',
      ]).timeout(const Duration(seconds: 20));
      if (probe.exitCode == 0) {
        _nodeExecutable = candidate;
        return candidate;
      }
      failures.add('$candidate -> exit ${probe.exitCode}');
    } catch (error) {
      failures.add('$candidate -> $error');
    }
  }
  throw StateError(
    'Node 安全证明不可用：本机没有可执行的 node，绝不允许把静态断言当成安全通过'
    '\n${failures.join('\n')}',
  );
}

String _error(Map<String, dynamic> report) {
  final result = report['result'];
  final finalMessage = report['final'];
  final error =
      (result is Map ? result['error'] : null) ??
      (finalMessage is Map ? finalMessage['error'] : null);
  expect(error, isA<String>(), reason: '报告必须携带固定错误码：$report');
  return error! as String;
}

Map<String, dynamic> _stored(Map<String, dynamic> report) {
  final node = report['credentialAfter'];
  expect(node, isA<Map<String, dynamic>>(), reason: '场景必须写过凭据：$report');
  final value = (node as Map<String, dynamic>)['value'];
  expect(value, isA<Map<String, dynamic>>(), reason: '凭据必须是 JSON 对象');
  return value! as Map<String, dynamic>;
}

Map<String, dynamic> _record(Map<String, dynamic> report, String name) {
  final node = report[name];
  return node is Map<String, dynamic> ? node : <String, dynamic>{};
}

String? _mode(Map<String, dynamic> report) =>
    _record(report, 'credentialAfter')['mode'] as String?;

List<Map<String, dynamic>> _ops(Map<String, dynamic> report) =>
    (report['fileOps'] as List).cast<Map<String, dynamic>>();

List<Map<String, dynamic>> _opsWhere(
  List<Map<String, dynamic>> ops, {
  required String kind,
  String? suffix,
}) => ops.where((op) {
  if (op['op'] != kind) return false;
  if (suffix == null) return true;
  final path = op['path'] ?? op['to'];
  return path is String && path.endsWith(suffix);
}).toList();

/// 涉及 credentials.json 的写操作（host-id 属于正常的第一步落地）。
List<Map<String, dynamic>> _credentialTouched(List<Map<String, dynamic>> ops) =>
    ops.where((op) {
      final path = (op['path'] ?? op['from'] ?? op['to'] ?? '') as String;
      return path.contains('credentials.json');
    }).toList();

List<Map<String, dynamic>> _lockOps(List<Map<String, dynamic>> ops) =>
    ops.where((op) {
      final path = (op['path'] ?? op['from'] ?? op['to'] ?? '') as String;
      return path.endsWith('credentials.json.lock');
    }).toList();

List<String> _fetched(Map<String, dynamic> report) =>
    (report['fetchedUrls'] as List).cast<String>();

/// 所有场景共用的沙箱边界断言。
void _expectSandboxed(Map<String, dynamic> report) {
  expect(report['fatal'], isNull, reason: '运行器不得崩溃：$report');
  expect(report['stdoutLeaksToken'], isFalse, reason: '令牌绝不出现在 stdout');
  expect(report['tempLeftovers'], <dynamic>[], reason: '临时文件必须清理干净');
  expect(report['lockLeft'], isFalse, reason: '排他锁必须释放');
  for (final url in _fetched(report)) {
    expect(
      _allowedEndpoints.contains(url),
      isTrue,
      reason: '只能触达白名单端点，实际：$url',
    );
  }
  for (final op in _ops(report)) {
    final path = (op['path'] ?? op['from'] ?? op['to'] ?? '') as String;
    expect(
      path.startsWith('$_sandboxRoot/'),
      isTrue,
      reason: '假文件系统里只允许出现 /vh 下的路径：$op',
    );
  }
}

/// 从远端命令里解出 base64 内联的 Node 脚本。
String _decodeScript(String command) {
  final match = RegExp(
    r'Buffer\.from\("([A-Za-z0-9+/=]+)", "base64"\)',
  ).firstMatch(command);
  expect(match, isNotNull, reason: '脚本必须 base64 内联');
  return utf8.decode(base64.decode(match!.group(1)!));
}

class _FakeSession implements SSHSession {
  final _out = StreamController<Uint8List>();
  final _err = StreamController<Uint8List>();
  final _in = StreamController<Uint8List>();
  final _done = Completer<void>();

  void Function(String line)? onStdinLine;
  final List<String> stdinLines = [];

  _FakeSession() {
    _in.stream.listen((bytes) {
      final line = utf8.decode(bytes).trim();
      if (line.isEmpty) return;
      stdinLines.add(line);
      onStdinLine?.call(line);
    });
  }

  void pushLine(String line) {
    if (_out.isClosed) return;
    _out.add(Uint8List.fromList(utf8.encode('$line\n')));
  }

  @override
  Stream<Uint8List> get stdout => _out.stream;

  @override
  Stream<Uint8List> get stderr => _err.stream;

  @override
  StreamSink<Uint8List> get stdin => _in.sink;

  @override
  int? get exitCode => null;

  @override
  Future<void> get done => _done.future;

  @override
  void close() {
    if (!_out.isClosed) _out.close();
    if (!_err.isClosed) _err.close();
    if (!_in.isClosed) _in.close();
    if (!_done.isCompleted) _done.complete();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSsh implements SSHClient {
  _FakeSsh(this.session);

  final SSHSession session;
  final List<String> commands = [];

  @override
  Future<SSHSession> execute(
    String command, {
    SSHPtyConfig? pty,
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) {
    commands.add(command);
    return Future<SSHSession>.value(session);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
