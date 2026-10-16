import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/logging/sanitizer.dart';
import '../../core/utils/shell_quote.dart';
import '../../data/models/agent_profile.dart';
import '../../data/models/agent_update.dart';
import '../../data/models/server_profile.dart';
import '../cli/agent_execution_target.dart';
import '../ssh/ssh_client_manager.dart';
import '../acp/acp_client_adapter.dart';
import '../acp/acp_ssh_transport.dart';

typedef AgentUpdateJsonLoader = Future<Map<String, dynamic>> Function(Uri uri);

/// Checks never install packages, start an agent session, or read credentials.
class AgentUpdateService {
  AgentUpdateService(
    this.ssh, {
    AgentUpdateJsonLoader? loadJson,
    DateTime Function()? now,
  }) : _loadJson = loadJson ?? _httpJson,
       _now = now ?? DateTime.now;

  final SshCommandExecutor ssh;
  final AgentUpdateJsonLoader _loadJson;
  final DateTime Function() _now;
  static const probeTimeout = Duration(seconds: 25);
  static const updateTimeout = Duration(minutes: 10);
  static const _marker = '__VALHALLA_AGENT_UPDATE_V1__';
  static const _packages = {
    'codex': '@openai/codex',
    'claude': '@anthropic-ai/claude-code',
    'opencode': 'opencode-ai',
    'codex-acp': '@agentclientprotocol/codex-acp',
    'claude-code-acp': '@zed-industries/claude-code-acp',
    'claude-agent-acp': '@agentclientprotocol/claude-agent-acp',
  };
  final Map<Uri, (DateTime, Map<String, dynamic>)> _catalogCache = {};
  final Map<Uri, Future<Map<String, dynamic>>> _catalogPending = {};

  static Future<Map<String, dynamic>> _httpJson(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 15));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode != 200) {
        throw AgentUpdateException(
          'AGENT_UPDATE_CATALOG_FAILED',
          'HTTP ${response.statusCode}',
        );
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 20))) {
        bytes.addAll(chunk);
        if (bytes.length > 1024 * 1024) {
          throw const AgentUpdateException('AGENT_UPDATE_CATALOG_TOO_LARGE');
        }
      }
      final text = utf8.decode(bytes);
      if (uri.host == 'downloads.claude.ai' &&
          {'latest', 'stable'}.contains(uri.pathSegments.last)) {
        return {'version': text.trim()};
      }
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        throw const AgentUpdateException('AGENT_UPDATE_CATALOG_INVALID');
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _catalog(Uri uri, {required bool force}) {
    final pending = _catalogPending[uri];
    if (pending != null) return pending;
    final cached = _catalogCache[uri];
    if (!force &&
        cached != null &&
        _now().difference(cached.$1) < const Duration(hours: 1)) {
      return Future.value(cached.$2);
    }
    late final Future<Map<String, dynamic>> future;
    future = _loadJson(uri)
        .then((value) {
          _catalogCache[uri] = (_now(), value);
          return value;
        })
        .whenComplete(() {
          if (identical(_catalogPending[uri], future)) {
            _catalogPending.remove(uri);
          }
        });
    return _catalogPending[uri] = future;
  }

  String _target(AgentProfile profile, String command) =>
      _cliName(profile) == 'codex'
      ? agentCodexTargetCommand(profile, command)
      : agentTargetCommand(
          profile,
          'unset HISTFILE; if [ -n "\${BASH_VERSION:-}" ]; then set +o history; fi; set +x;\n$command',
        );

  static String _cliName(AgentProfile profile) =>
      profile.cliCommand.split('/').last;
  static String _acpName(AgentProfile profile) {
    final command = profile.acpCommand?.trim() ?? '';
    if (command == 'opencode acp') return 'opencode';
    if (RegExp(r'^(?:/[^\s]+/)?codex-acp(?:\s+--stdio)?$').hasMatch(command)) {
      return 'codex-acp';
    }
    if (RegExp(
      r'^(?:/[^\s]+/)?agy_acp_server\.par(?:\s+--uid=)?$',
    ).hasMatch(command)) {
      return 'agy_acp_server.par';
    }
    if (!RegExp(r'^[A-Za-z0-9_./+-]+$').hasMatch(command)) return '';
    return command.split('/').last;
  }

  Future<_Runtime> _probe(ServerProfile server, AgentProfile profile) async {
    if (!ssh.isConnected(server.id)) {
      throw const AgentUpdateException('SSH_DISCONNECTED');
    }
    if (!RegExp(r'^[A-Za-z0-9_./+-]+$').hasMatch(profile.cliCommand)) {
      throw const AgentUpdateException('AGENT_UPDATE_CUSTOM_COMMAND');
    }
    String? containerId;
    var target = profile;
    if (profile.executionTarget == 'docker') {
      // Validate configured reference/user before any command construction.
      agentTargetCommand(profile, 'true');
      final result = await ssh.executeWithLoginShell(
        server.id,
        'docker inspect --format ${cliShellQuote('{{.Id}} {{.State.Running}}')} ${cliShellQuote(profile.containerReference!)}',
        timeout: probeTimeout,
      );
      final match = RegExp(
        r'^([a-f0-9]{64}) true$',
      ).firstMatch(result.stdout.trim());
      if (!result.isSuccess || match == null) {
        throw const AgentUpdateException('AGENT_UPDATE_CONTAINER_UNAVAILABLE');
      }
      containerId = match[1]!;
      target = profile.copyWith(
        containerBinding: 'id',
        containerReference: containerId,
      );
    }
    final acpName = _acpName(profile);
    final acp = acpName.isEmpty
        ? ''
        : profile.acpCommand!.split(RegExp(r'\s+')).first;
    final script = _probeScript(
      profile.cliCommand,
      acp,
      {'codex', 'claude', 'opencode', 'agy'}.contains(_cliName(profile)),
    );
    final command = _target(target, script);
    final result = await ssh.executeWithLoginShell(
      server.id,
      command,
      timeout: probeTimeout,
    );
    if (!result.isSuccess) {
      throw AgentUpdateException(
        'AGENT_UPDATE_PROBE_FAILED',
        _tail(result.stderr),
      );
    }
    final values = <String, String>{};
    for (final line in result.stdout.split('\n')) {
      if (!line.startsWith(_marker)) continue;
      final fields = line.substring(_marker.length).split('\t');
      if (fields.length == 2) values[fields[0]] = fields[1];
    }
    if (!RegExp(r'^\d+$').hasMatch(values['uid'] ?? '') ||
        !(values['home']?.startsWith('/') ?? false)) {
      throw const AgentUpdateException('AGENT_UPDATE_PROBE_INVALID');
    }
    if (acpName == 'codex-acp' &&
        values['acpPath']?.startsWith('/') == true &&
        _version(values['acpPackageVersion']) == null) {
      final client = ssh.getClient(server.id);
      if (client != null) {
        try {
          final info = await _readAcpVersion(
            server.id,
            target,
            values['acpPath']!,
          );
          values['acpProtocolVersion'] = info.$2 ?? '';
          values['acpProtocolName'] = info.$1 ?? '';
        } catch (_) {
          values['acpProtocolVersion'] = '';
        }
      }
    }
    return _Runtime(
      target,
      containerId,
      values,
      LogSanitizer.sanitize(
        'target: ${profile.executionTarget}${containerId == null ? '' : ' $containerId'}\nuser: ${values['uid']}\nCLI: ${values['cliPath']}\nACP: ${values['acpPath']}\nACP version: ${values['acpPackageVersion'] ?? values['acpProtocolVersion'] ?? 'unknown'}\nACP package: ${values['acpPackage'] ?? 'standalone'}\n${_tail(result.stderr)}',
      ),
    );
  }

  Future<(String?, String?)> _readAcpVersion(
    String serverId,
    AgentProfile profile,
    String executable,
  ) async {
    final client = ssh.getClient(serverId);
    if (client == null) throw const AgentUpdateException('SSH_DISCONNECTED');
    var finished = false;
    final opening = client.execute(
      _target(profile, 'exec ${cliShellQuote(executable)}'),
    );
    unawaited(
      opening.then((session) {
        if (finished) session.close();
      }, onError: (Object _) {}),
    );
    ACPClientAdapter? adapter;
    void Function()? closeSession;
    try {
      final session = await opening.timeout(probeTimeout);
      closeSession = session.close;
      adapter = ACPClientAdapter(
        profile: profile,
        transport: AcpSshTransport(session),
        requestTimeout: const Duration(seconds: 8),
      );
      await adapter.initializeOnly().timeout(const Duration(seconds: 10));
      return (adapter.agentInfo?.name, adapter.agentInfo?.version);
    } finally {
      finished = true;
      adapter?.dispose();
      closeSession?.call();
    }
  }

  static String _probeScript(String cli, String acp, bool versionSupported) =>
      r'''
set -eu
export DISABLE_AUTOUPDATER=1 OPENCODE_DISABLE_AUTOUPDATE=1 AGY_CLI_DISABLE_AUTO_UPDATE=true
valhalla_update_emit() { printf '__VALHALLA_AGENT_UPDATE_V1__%s\t%s\n' "$1" "$2"; }
valhalla_update_find() { if [ -n "${BASH_VERSION:-}" ]; then type -P -- "$1" 2>/dev/null || true; else command -v -- "$1" 2>/dev/null || true; fi; }
valhalla_update_cli=$(valhalla_update_find ''' +
      cliShellQuote(cli) +
      r''')
valhalla_update_acp=$(valhalla_update_find ''' +
      cliShellQuote(acp) +
      r''')
''' +
      (acp.split('/').last == 'agy_acp_server.par'
          ? r'''
if [ -z "$valhalla_update_acp" ] && [ -x "$HOME/.local/bin/agy_acp_server.par" ]; then valhalla_update_acp="$HOME/.local/bin/agy_acp_server.par"; fi
'''
          : '') +
      r'''
valhalla_update_emit uid "$(id -u)"
valhalla_update_emit home "$HOME"
valhalla_update_emit os "$(uname -s)"
valhalla_update_emit arch "$(uname -m)"
valhalla_update_emit cliPath "$valhalla_update_cli"
valhalla_update_emit acpPath "$valhalla_update_acp"
if [ -n "$valhalla_update_cli" ]; then valhalla_update_emit cliCanonical "$(readlink -f "$valhalla_update_cli" 2>/dev/null || printf '%s' "$valhalla_update_cli")"; fi
if [ -n "$valhalla_update_acp" ]; then valhalla_update_emit acpCanonical "$(readlink -f "$valhalla_update_acp" 2>/dev/null || printf '%s' "$valhalla_update_acp")"; fi
valhalla_update_emit libc "$(if [ -f /lib/libc.musl-x86_64.so.1 ] || [ -f /lib/libc.musl-aarch64.so.1 ]; then printf musl; else printf native; fi)"
''' +
      'if [ ${versionSupported ? '1' : '0'} = 1 ] && [ -n "\$valhalla_update_cli" ]; then\n' +
      r'''
  valhalla_update_version=$("$valhalla_update_cli" --version 2>/dev/null | head -n 1) || valhalla_update_version=''
  valhalla_update_emit cliVersion "$valhalla_update_version"
fi
valhalla_update_npm=$(valhalla_update_find npm)
valhalla_update_root=''
if [ -n "$valhalla_update_npm" ]; then
  valhalla_update_root=$("$valhalla_update_npm" root -g 2>/dev/null) || valhalla_update_root=''
  valhalla_update_emit npmPath "$valhalla_update_npm"
  valhalla_update_emit npmRoot "$valhalla_update_root"
  valhalla_update_emit npmPrefix "$("$valhalla_update_npm" prefix -g 2>/dev/null || true)"
fi
if command -v node >/dev/null 2>&1; then
node - "$valhalla_update_cli" "$valhalla_update_acp" "$valhalla_update_root" <<'VALHALLA_UPDATE_NODE'
const fs=require('fs'),p=require('path');
const emit=(k,v)=>{if(typeof v==='string'&&!/[\r\n\t]/.test(v))process.stdout.write('__VALHALLA_AGENT_UPDATE_V1__'+k+'\t'+v+'\n')};
emit('nodeVersion',process.versions.node);
const root=process.argv[4]&&fs.existsSync(process.argv[4])?fs.realpathSync(process.argv[4]):'';
for(const [key,file] of [['cli',process.argv[2]],['acp',process.argv[3]]]) {
  if(!file||!fs.existsSync(file))continue;
  const real=fs.realpathSync(file); emit(key+'Canonical',real);
  let dir=p.dirname(real);
  for(let i=0;i<8;i++) {
    const meta=p.join(dir,'package.json');
    if(fs.existsSync(meta)) {
      try {const data=JSON.parse(fs.readFileSync(meta,'utf8')); if(data.name&&data.version&&data.bin){const bins=typeof data.bin==='string'?[data.bin]:Object.values(data.bin);if(bins.some(b=>typeof b==='string'&&p.resolve(dir,b)===real)){emit(key+'Package',data.name);emit(key+'PackageVersion',data.version);if(root&&dir.startsWith(root+p.sep))emit(key+'NpmOwned','yes');break;}}}catch{}
    }
    const parent=p.dirname(dir); if(parent===dir)break;dir=parent;
  }
}
VALHALLA_UPDATE_NODE
fi
if [ "$valhalla_update_acp" = "$HOME/.local/bin/agy_acp_server.par" ] && [ -f "$valhalla_update_acp" ]; then
  valhalla_update_managed=$(sed -n 's|^exec "\$HOME/.local/share/valhalla/antigravity-acp/\([0-9][0-9.]*\)/agy_acp_server.par" "\$@"$|\1|p' "$valhalla_update_acp")
  if [ "$(wc -l < "$valhalla_update_acp" | tr -d ' ')" = 2 ]; then valhalla_update_emit agyAcpVersion "$valhalla_update_managed"; fi
  if [ -n "$valhalla_update_managed" ] && command -v python3 >/dev/null 2>&1; then
    python3 - "$HOME/.local/share/valhalla/antigravity-acp/$valhalla_update_managed" "$valhalla_update_managed" <<'VALHALLA_UPDATE_MANAGED'
import json,pathlib,sys
try:
 root=pathlib.Path(sys.argv[1]); record=json.loads((root/'valhalla-install.json').read_text())
 if record.get('version')==sys.argv[2] and all((root/name).is_file() and (root/name).stat().st_size==record['files'][name]['size'] for name in ('agy_acp_server.par','localharness_external')):
  print('__VALHALLA_AGENT_UPDATE_V1__agyAcpVerified\tyes')
except Exception: pass
VALHALLA_UPDATE_MANAGED
  fi
fi
if command -v python3 >/dev/null 2>&1; then
  valhalla_update_emit python3 yes
  python3 - <<'VALHALLA_UPDATE_NATIVE'
import json,os,pathlib
p=pathlib.Path(os.environ.get('CLAUDE_CONFIG_DIR') or str(pathlib.Path.home()/'.claude'))/'settings.json'
channel='latest'
try:
 if p.is_file():
  data=json.loads(p.read_text()); channel=data.get('autoUpdatesChannel','latest')
  if data.get('minimumVersion') or data.get('requiredMaximumVersion') or data.get('requiredMinimumVersion'): channel='managed'
 if pathlib.Path('/etc/claude-code/managed-settings.json').exists() or pathlib.Path('/Library/Application Support/ClaudeCode/managed-settings.json').exists(): channel='managed'
except Exception: channel='unknown'
if channel in ('latest','stable'): print('__VALHALLA_AGENT_UPDATE_V1__claudeChannel\t'+channel)
VALHALLA_UPDATE_NATIVE
fi
if command -v curl >/dev/null 2>&1; then valhalla_update_emit curl yes; fi
''';

  Future<AgentUpdateReport> check(
    ServerProfile server,
    AgentProfile profile, {
    bool force = false,
  }) async {
    final runtime = await _probe(server, profile);
    return AgentUpdateReport(
      agentId: profile.id,
      targetKey: agentUpdateTargetKey(server, profile),
      checkedAt: _now(),
      components: await _components(profile, runtime, force: force),
      diagnosticLog: runtime.diagnostics,
    );
  }

  Future<AgentUpdatePlan> prepare(
    ServerProfile server,
    AgentProfile profile, {
    Set<AgentUpdateComponent>? components,
  }) async {
    final runtime = await _probe(server, profile);
    final available = (await _components(profile, runtime, force: true))
        .where(
          (item) =>
              item.canUpdate &&
              (components == null || components.contains(item.component)),
        )
        .toList(growable: false);
    if (available.isEmpty) {
      throw const AgentUpdateException('AGENT_UPDATE_NOT_AVAILABLE');
    }
    return AgentUpdatePlan(
      server: server,
      profile: profile,
      targetKey: agentUpdateTargetKey(server, profile),
      preparedAt: _now(),
      runtimeIdentity: runtime.identity,
      resolvedContainerId: runtime.containerId,
      components: available,
    );
  }

  Future<List<AgentComponentUpdate>> _components(
    AgentProfile profile,
    _Runtime runtime, {
    required bool force,
  }) async {
    final result = <AgentComponentUpdate>[];
    for (final component in AgentUpdateComponent.values) {
      if (component == AgentUpdateComponent.acp &&
          (profile.acpCommand?.trim().isNotEmpty != true)) {
        continue;
      }
      final name = component == AgentUpdateComponent.cli
          ? _cliName(profile)
          : _acpName(profile);
      if (component == AgentUpdateComponent.acp &&
          name == 'opencode' &&
          _cliName(profile) == 'opencode') {
        continue;
      }
      try {
        result.add(
          await _component(profile, runtime, component, name, force: force),
        );
      } catch (error) {
        result.add(
          AgentComponentUpdate(
            component: component,
            status: AgentUpdateStatus.error,
            reasonCode: error is AgentUpdateException
                ? error.code
                : 'AGENT_UPDATE_CHECK_FAILED',
          ),
        );
      }
    }
    return result;
  }

  Future<AgentComponentUpdate> _component(
    AgentProfile profile,
    _Runtime runtime,
    AgentUpdateComponent component,
    String name, {
    required bool force,
  }) async {
    final key = component.name;
    final path = runtime.values['${key}Path'] ?? '';
    final installed = component == AgentUpdateComponent.cli
        ? _version(runtime.values['cliVersion'])
        : _version(runtime.values['acpPackageVersion']) ??
              _version(runtime.values['acpProtocolVersion']) ??
              _version(runtime.values['agyAcpVersion']);
    AgentComponentUpdate unavailable(
      String reason, {
      String? latest,
      String? source,
    }) => AgentComponentUpdate(
      component: component,
      status: AgentUpdateStatus.unsupported,
      installedVersion: installed,
      latestVersion: latest,
      source: source,
      reasonCode: reason,
    );
    if (name.isEmpty ||
        !{..._packages.keys, 'agy', 'agy_acp_server.par'}.contains(name)) {
      return unavailable('AGENT_UPDATE_CUSTOM_COMMAND');
    }
    if (path.isEmpty) {
      return AgentComponentUpdate(
        component: component,
        status: AgentUpdateStatus.missing,
        reasonCode: 'AGENT_UPDATE_COMPONENT_MISSING',
      );
    }
    if (component == AgentUpdateComponent.acp && name == 'codex-acp') {
      final metadata = await _catalog(
        Uri.https(
          'registry.npmjs.org',
          '/@agentclientprotocol/codex-acp/latest',
        ),
        force: force,
      );
      if (metadata['name'] != '@agentclientprotocol/codex-acp') {
        throw const AgentUpdateException('AGENT_UPDATE_CATALOG_INVALID');
      }
      final latest = _stableVersion(metadata['version']);
      final package = runtime.values['acpPackage'];
      final officialNpm =
          package == '@agentclientprotocol/codex-acp' &&
          (runtime.values['acpCanonical']?.startsWith(
                '${runtime.values['npmRoot']}/',
              ) ??
              false);
      if (!officialNpm) {
        final managedRoot =
            '${runtime.values['home']}/.local/share/valhalla/codex-acp/';
        if (package == '@agentclientprotocol/codex-acp' &&
            path.startsWith(managedRoot) &&
            compareAgentVersions(installed, latest) == 0) {
          return AgentComponentUpdate(
            component: component,
            status: AgentUpdateStatus.current,
            installedVersion: installed,
            latestVersion: latest,
            source: package,
          );
        }
        if (runtime.values['npmPath']?.startsWith('/') != true ||
            runtime.values['nodeVersion'] == null) {
          return unavailable(
            'AGENT_UPDATE_TOOLS_MISSING',
            latest: latest,
            source: '@agentclientprotocol/codex-acp',
          );
        }
        final minimum = RegExp(r'>=\s*(\d+)')
            .firstMatch(
              (metadata['engines'] as Map?)?['node']?.toString() ?? '',
            )
            ?.group(1);
        if (minimum != null &&
            (int.tryParse(runtime.values['nodeVersion']!.split('.').first) ??
                    0) <
                int.parse(minimum)) {
          return unavailable(
            'AGENT_UPDATE_NODE_UNSUPPORTED',
            latest: latest,
            source: '@agentclientprotocol/codex-acp',
          );
        }
        final prefix =
            '${runtime.values['home']}/.local/share/valhalla/codex-acp/$latest';
        return AgentComponentUpdate(
          component: component,
          status: AgentUpdateStatus.available,
          installedVersion: installed,
          latestVersion: latest,
          source: '@agentclientprotocol/codex-acp',
          reasonCode: 'AGENT_UPDATE_CODEX_ADAPTER_MIGRATION',
          replacementAcpCommand: '$prefix/node_modules/.bin/codex-acp',
          command:
              'npm_config_engine_strict=true ${cliShellQuote(runtime.values['npmPath']!)} install --prefix ${cliShellQuote(prefix)} --registry https://registry.npmjs.org -- ${cliShellQuote('@agentclientprotocol/codex-acp@$latest')}',
        );
      }
    }
    final expected = _packages[name];
    final npmOwned =
        expected != null &&
        runtime.values['${key}Package'] == expected &&
        (runtime.values['npmPath']?.startsWith('/') ?? false) &&
        (runtime.values['npmPrefix']?.startsWith('/') ?? false);
    if (npmOwned) {
      final migration =
          name == 'claude-code-acp' &&
          profile.acpCommand == 'claude-code-acp' &&
          profile.acpInstallCommand ==
              'npm install -g @zed-industries/claude-code-acp';
      if (name == 'claude-code-acp' && !migration) {
        return unavailable('AGENT_UPDATE_LEGACY_CUSTOM_ADAPTER');
      }
      final package = migration
          ? '@agentclientprotocol/claude-agent-acp'
          : expected;
      final metadata = await _catalog(
        Uri.https('registry.npmjs.org', '/$package/latest'),
        force: force,
      );
      final latest = _stableVersion(metadata['version']);
      if (metadata['name'] != package) {
        throw const AgentUpdateException('AGENT_UPDATE_CATALOG_INVALID');
      }
      final engine =
          (metadata['engines'] is Map
                  ? (metadata['engines'] as Map)['node']
                  : null)
              ?.toString();
      final minimumMajor = engine == null
          ? null
          : RegExp(r'>=\s*(\d+)').firstMatch(engine)?.group(1);
      final nodeMajor = int.tryParse(
        (runtime.values['nodeVersion'] ?? '').split('.').first,
      );
      if (minimumMajor != null &&
          (nodeMajor == null || nodeMajor < int.parse(minimumMajor))) {
        return unavailable(
          'AGENT_UPDATE_NODE_UNSUPPORTED',
          latest: latest,
          source: package,
        );
      }
      final order = compareAgentVersions(latest, installed);
      if (order == null) {
        return unavailable(
          'AGENT_UPDATE_VERSION_UNKNOWN',
          latest: latest,
          source: package,
        );
      }
      final command =
          'npm_config_engine_strict=true ${cliShellQuote(runtime.values['npmPath']!)} install -g --prefix ${cliShellQuote(runtime.values['npmPrefix']!)} --registry https://registry.npmjs.org -- ${cliShellQuote('$package@$latest')}';
      return AgentComponentUpdate(
        component: component,
        installedVersion: installed,
        latestVersion: latest,
        source: package,
        status: migration || order > 0
            ? AgentUpdateStatus.available
            : AgentUpdateStatus.current,
        command: migration || order > 0 ? command : null,
        migratesClaudeAdapter: migration,
      );
    }
    if (name == 'opencode' &&
        path == '${runtime.values['home']}/.opencode/bin/opencode') {
      final metadata = await _catalog(
        Uri.https('registry.npmjs.org', '/opencode-ai/latest'),
        force: force,
      );
      final latest = _stableVersion(metadata['version']);
      final order = compareAgentVersions(latest, installed);
      if (order == null) {
        return unavailable('AGENT_UPDATE_VERSION_UNKNOWN', latest: latest);
      }
      return AgentComponentUpdate(
        component: component,
        installedVersion: installed,
        latestVersion: latest,
        source: 'opencode-native',
        status: order > 0
            ? AgentUpdateStatus.available
            : AgentUpdateStatus.current,
        command: order > 0
            ? '${cliShellQuote(path)} upgrade ${cliShellQuote(latest)} --method curl'
            : null,
      );
    }
    final canonical = runtime.values['cliCanonical'] ?? '';
    if (name == 'claude' &&
        path == '${runtime.values['home']}/.local/bin/claude' &&
        canonical.startsWith(
          '${runtime.values['home']}/.local/share/claude/versions/',
        ) &&
        {'latest', 'stable'}.contains(runtime.values['claudeChannel'])) {
      final metadata = await _catalog(
        Uri.parse(
          'https://downloads.claude.ai/claude-code-releases/${runtime.values['claudeChannel']}',
        ),
        force: force,
      );
      final latest = _stableVersion(metadata['version']);
      final order = compareAgentVersions(latest, installed);
      if (order == null) {
        return unavailable('AGENT_UPDATE_VERSION_UNKNOWN', latest: latest);
      }
      return AgentComponentUpdate(
        component: component,
        installedVersion: installed,
        latestVersion: latest,
        source: 'claude-native-${runtime.values['claudeChannel']}',
        status: order > 0
            ? AgentUpdateStatus.available
            : AgentUpdateStatus.current,
        command: order > 0
            ? '${cliShellQuote(path)} install ${cliShellQuote(latest)}'
            : null,
      );
    }
    if (name == 'agy' &&
        path == '${runtime.values['home']}/.local/bin/agy' &&
        runtime.values['cliCanonical'] == path) {
      final platform = _agyPlatform(runtime);
      if (platform == null) {
        return unavailable('AGENT_UPDATE_PLATFORM_UNSUPPORTED');
      }
      final metadata = await _catalog(
        Uri.parse(
          'https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/$platform.json',
        ),
        force: force,
      );
      final latest = _stableVersion(metadata['version']);
      final order = compareAgentVersions(latest, installed);
      if (order == null) {
        return unavailable('AGENT_UPDATE_VERSION_UNKNOWN', latest: latest);
      }
      if (order <= 0) {
        return AgentComponentUpdate(
          component: component,
          installedVersion: installed,
          latestVersion: latest,
          source: 'antigravity-cli',
          status: AgentUpdateStatus.current,
        );
      }
      final url = Uri.tryParse(metadata['url']?.toString() ?? '');
      final digest = metadata['sha512']?.toString() ?? '';
      if (url == null ||
          url.scheme != 'https' ||
          url.host != 'storage.googleapis.com' ||
          url.userInfo.isNotEmpty ||
          url.hasQuery ||
          url.hasFragment ||
          !url.path.startsWith(
            '/antigravity-public/antigravity-cli/$latest-',
          ) ||
          !RegExp(r'^[a-fA-F0-9]{128}$').hasMatch(digest)) {
        throw const AgentUpdateException('AGENT_UPDATE_CATALOG_INVALID');
      }
      return AgentComponentUpdate(
        component: component,
        installedVersion: installed,
        latestVersion: latest,
        source: 'antigravity-cli',
        status: AgentUpdateStatus.available,
        command: '${cliShellQuote(path)} update',
        catalogIdentity: jsonEncode([
          latest,
          url.toString(),
          digest.toLowerCase(),
        ]),
      );
    }
    if (name == 'agy_acp_server.par' &&
        runtime.values['agyAcpVersion']?.isNotEmpty == true) {
      final metadata = await _catalog(
        Uri.parse(
          'https://raw.githubusercontent.com/agentclientprotocol/registry/main/antigravity-acp/agent.json',
        ),
        force: force,
      );
      if (metadata['id'] != 'antigravity-acp') {
        throw const AgentUpdateException('AGENT_UPDATE_CATALOG_INVALID');
      }
      final latest = _stableVersion(metadata['version']);
      final order = compareAgentVersions(latest, installed);
      if (order == null) {
        return unavailable('AGENT_UPDATE_VERSION_UNKNOWN', latest: latest);
      }
      if (order <= 0) {
        return AgentComponentUpdate(
          component: component,
          status: AgentUpdateStatus.current,
          installedVersion: installed,
          latestVersion: latest,
          source: 'antigravity-acp',
        );
      }
      if (runtime.values['python3'] != 'yes' ||
          runtime.values['curl'] != 'yes') {
        return unavailable('AGENT_UPDATE_TOOLS_MISSING', latest: latest);
      }
      final platform = _acpPlatform(runtime);
      final distribution = metadata['distribution'];
      final binary = distribution is Map ? distribution['binary'] : null;
      final entry = binary is Map ? binary[platform] : null;
      final archive = entry is Map
          ? Uri.tryParse(entry['archive']?.toString() ?? '')
          : null;
      final releaseOs = runtime.values['os'] == 'Darwin' ? 'darwin' : 'linux';
      final releaseArch = {'aarch64', 'arm64'}.contains(runtime.values['arch'])
          ? 'arm64'
          : 'x86_64';
      final expectedPath =
          '/agy-extensions/releases/${releaseOs == 'darwin' ? 'macos' : 'linux'}/agy-acp-server-$latest-$releaseOs-$releaseArch.zip';
      if (archive == null ||
          archive.scheme != 'https' ||
          archive.host != 'dl.google.com' ||
          archive.hasQuery ||
          archive.hasFragment ||
          archive.userInfo.isNotEmpty ||
          archive.path != expectedPath) {
        return unavailable('AGENT_UPDATE_PLATFORM_UNSUPPORTED', latest: latest);
      }
      return AgentComponentUpdate(
        component: component,
        status: AgentUpdateStatus.available,
        installedVersion: installed,
        latestVersion: latest,
        source: 'antigravity-acp',
        command: _agyAcpInstall(latest, archive),
      );
    }
    return unavailable('AGENT_UPDATE_INSTALL_SOURCE_UNKNOWN');
  }

  /// The caller holds its environment lease and checks live identity/busy state.
  Future<AgentProfile> apply(
    AgentUpdatePlan plan, {
    required bool Function() isCurrent,
    required void Function(String) onLog,
  }) async {
    if (!isCurrent() ||
        _now().difference(plan.preparedAt) > const Duration(minutes: 15)) {
      throw const AgentUpdateException('AGENT_UPDATE_PLAN_EXPIRED');
    }
    final runtime = await _probe(plan.server, plan.profile);
    if (!isCurrent() ||
        runtime.identity != plan.runtimeIdentity ||
        runtime.containerId != plan.resolvedContainerId) {
      throw const AgentUpdateException('AGENT_UPDATE_TARGET_CHANGED');
    }
    var profile = plan.profile;
    for (final item in plan.components) {
      if (!isCurrent() || !item.canUpdate) {
        throw const AgentUpdateException('AGENT_UPDATE_TARGET_CHANGED');
      }
      if (item.source == 'antigravity-cli') {
        final metadata = await _catalog(
          Uri.parse(
            'https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/${_agyPlatform(runtime)}.json',
          ),
          force: true,
        );
        if (item.catalogIdentity !=
            jsonEncode([
              metadata['version'],
              metadata['url'],
              metadata['sha512']?.toString().toLowerCase(),
            ])) {
          throw const AgentUpdateException('AGENT_UPDATE_TARGET_CHANGED');
        }
        if (!isCurrent()) {
          throw const AgentUpdateException('AGENT_UPDATE_TARGET_CHANGED');
        }
      }
      final command = '${_identityGuard(runtime)}\n${item.command!}';
      onLog(
        'target: ${profile.executionTarget}; user: ${runtime.values['uid']}\ncommand: ${item.command}\n',
      );
      int? exitCode;
      await for (final chunk in ssh.executeStreaming(
        plan.server.id,
        _target(runtime.profile, command),
        timeout: updateTimeout,
      )) {
        if (chunk.exitCode != null) exitCode = chunk.exitCode;
        if (chunk.text.isNotEmpty) onLog(LogSanitizer.sanitize(chunk.text));
      }
      if (exitCode != 0) {
        throw AgentUpdateException(
          'AGENT_UPDATE_EXECUTION_FAILED',
          'exit ${exitCode ?? 'unknown'}',
        );
      }
      if (!isCurrent()) {
        throw const AgentUpdateException('AGENT_UPDATE_TARGET_CHANGED');
      }
      if (item.migratesClaudeAdapter) {
        profile = profile.copyWith(
          acpCommand: 'claude-agent-acp',
          acpInstallCommand:
              'npm install -g @agentclientprotocol/claude-agent-acp',
        );
      }
      if (item.replacementAcpCommand != null) {
        profile = profile.copyWith(
          acpCommand: item.replacementAcpCommand,
          acpInstallCommand: item.command,
        );
      }
      final after = await _probe(plan.server, profile);
      if (after.containerId != runtime.containerId ||
          after.values['uid'] != runtime.values['uid'] ||
          after.values['home'] != runtime.values['home']) {
        throw const AgentUpdateException('AGENT_UPDATE_TARGET_CHANGED');
      }
      final actual = item.component == AgentUpdateComponent.cli
          ? _version(after.values['cliVersion'])
          : _version(after.values['acpPackageVersion']) ??
                _version(after.values['acpProtocolVersion']) ??
                _version(after.values['agyAcpVersion']);
      final order = compareAgentVersions(actual, item.latestVersion);
      if (order == null || order < 0) {
        throw const AgentUpdateException('AGENT_UPDATE_VERSION_UNCHANGED');
      }
      if (item.replacementAcpCommand != null) {
        final info = await _readAcpVersion(
          plan.server.id,
          after.profile,
          item.replacementAcpCommand!,
        );
        if (compareAgentVersions(info.$2, item.latestVersion) != 0) {
          throw const AgentUpdateException('AGENT_UPDATE_RUNTIME_INVALID');
        }
      }
      if (item.source == 'antigravity-acp' &&
          after.values['agyAcpVerified'] != 'yes') {
        throw const AgentUpdateException('AGENT_UPDATE_RUNTIME_INVALID');
      }
      onLog('${item.component.name}: verified $actual\n');
    }
    return profile;
  }

  static String _identityGuard(_Runtime runtime) =>
      'set -eu\n[ "\$(id -u)" = ${cliShellQuote(runtime.values['uid']!)} ] && '
      '[ "\$HOME" = ${cliShellQuote(runtime.values['home']!)} ] || { printf "%s\\n" AGENT_UPDATE_TARGET_CHANGED >&2; exit 73; }';

  static String? _version(String? text) => RegExp(
    r'(?:^|\s)v?(\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?(?:\+[A-Za-z0-9.-]+)?)(?:\s|$)',
  ).firstMatch(text ?? '')?.group(1);
  static String _stableVersion(Object? version) {
    final value = version is String ? version : '';
    if (compareAgentVersions(value, value) == null) {
      throw const AgentUpdateException('AGENT_UPDATE_CATALOG_INVALID');
    }
    return value;
  }

  static String? _agyPlatform(_Runtime runtime) {
    final os = switch (runtime.values['os']) {
      'Linux' => 'linux',
      'Darwin' => 'darwin',
      _ => null,
    };
    final arch = switch (runtime.values['arch']) {
      'x86_64' || 'amd64' => 'amd64',
      'aarch64' || 'arm64' => 'arm64',
      _ => null,
    };
    if (os == null || arch == null) return null;
    return '${os}_$arch${os == 'linux' && runtime.values['libc'] == 'musl' ? '_musl' : ''}';
  }

  static String? _acpPlatform(_Runtime runtime) {
    final os = switch (runtime.values['os']) {
      'Linux' => 'linux',
      'Darwin' => 'darwin',
      _ => null,
    };
    final arch = switch (runtime.values['arch']) {
      'x86_64' || 'amd64' => 'x86_64',
      'aarch64' || 'arm64' => 'aarch64',
      _ => null,
    };
    return os == null || arch == null ? null : '$os-$arch';
  }

  static String _tail(String text) => LogSanitizer.sanitize(
    text.split('\n').reversed.take(8).toList().reversed.join('\n'),
  );

  static String _agyAcpInstall(String version, Uri archive) =>
      r'''
set -eu
valhalla_root="$HOME/.local/share/valhalla/antigravity-acp"
mkdir -p "$valhalla_root" "$HOME/.local/bin"
'''
      'valhalla_destination="\$valhalla_root/$version"\n'
      'test ! -e "\$valhalla_destination" || { printf "%s\\n" AGENT_UPDATE_VERSION_DIRECTORY_EXISTS >&2; exit 73; }\n'
      'valhalla_tmp=\$(mktemp -d "\$valhalla_root/.update.XXXXXX")\n'
      'curl --proto "=https" --tlsv1.2 -f --retry 2 --connect-timeout 20 --max-filesize 4294967296 ${cliShellQuote(archive.toString())} -o "\$valhalla_tmp/archive.zip"\n'
      r'''
python3 - "$valhalla_tmp/archive.zip" "$valhalla_tmp/runtime" <<'VALHALLA_ACP_UNZIP'
import pathlib,shutil,stat,sys,zipfile
with zipfile.ZipFile(sys.argv[1]) as archive:
 members=archive.infolist(); total=sum(i.file_size for i in members)
 if len(members)>20000 or total>8589934592 or total+104857600>shutil.disk_usage(pathlib.Path(sys.argv[1]).parent).free: raise SystemExit('AGENT_UPDATE_ARCHIVE_TOO_LARGE')
 for item in archive.infolist():
  path=pathlib.PurePosixPath(item.filename)
  mode=stat.S_IFMT(item.external_attr>>16)
  if path.is_absolute() or '..' in path.parts or '\x5c' in item.filename or mode not in (0,stat.S_IFREG,stat.S_IFDIR) or item.flag_bits&1: raise SystemExit('AGENT_UPDATE_ARCHIVE_INVALID')
  if item.file_size>max(1048576,item.compress_size*500): raise SystemExit('AGENT_UPDATE_ARCHIVE_TOO_LARGE')
 archive.extractall(sys.argv[2])
VALHALLA_ACP_UNZIP
test -f "$valhalla_tmp/runtime/agy_acp_server.par"
test -f "$valhalla_tmp/runtime/localharness_external"
chmod u+x "$valhalla_tmp/runtime/agy_acp_server.par" "$valhalla_tmp/runtime/localharness_external"
'''
      'python3 - "\$valhalla_tmp/runtime" ${cliShellQuote(version)} <<\'VALHALLA_ACP_MANIFEST\'\n'
      r'''
import hashlib,json,pathlib,sys
root=pathlib.Path(sys.argv[1]); files={}
for name in ('agy_acp_server.par','localharness_external'):
 path=root/name; digest=hashlib.sha256()
 with path.open('rb') as source:
  for chunk in iter(lambda: source.read(1048576), b''): digest.update(chunk)
 files[name]={'size':path.stat().st_size,'sha256':digest.hexdigest()}
(root/'valhalla-install.json').write_text(json.dumps({'version':sys.argv[2],'files':files}))
VALHALLA_ACP_MANIFEST
test ! -e "$valhalla_destination"
mv "$valhalla_tmp/runtime" "$valhalla_destination"
test -x "$valhalla_destination/agy_acp_server.par"
test -x "$valhalla_destination/localharness_external"
'''
      'printf "%s\\n" "#!/bin/sh" \'exec "\$HOME/.local/share/valhalla/antigravity-acp/$version/agy_acp_server.par" "\$@"\' > "\$valhalla_tmp/launcher"\n'
      r'''
chmod u+x "$valhalla_tmp/launcher"
mv "$valhalla_tmp/launcher" "$HOME/.local/bin/agy_acp_server.par"
rm -- "$valhalla_tmp/archive.zip"
rmdir -- "$valhalla_tmp"
# Preserve the previous runtime and failed-download evidence for recovery.
''';
}

class _Runtime {
  final AgentProfile profile;
  final String? containerId;
  final Map<String, String> values;
  final String diagnostics;
  _Runtime(this.profile, this.containerId, this.values, this.diagnostics);
  String get identity => jsonEncode([
    containerId,
    for (final key in [
      'uid',
      'home',
      'cliPath',
      'acpPath',
      'cliCanonical',
      'acpCanonical',
      'cliVersion',
      'cliPackageVersion',
      'acpPackageVersion',
      'acpProtocolVersion',
      'agyAcpVersion',
      'npmPath',
      'npmRoot',
      'npmPrefix',
    ])
      values[key],
  ]);
}
