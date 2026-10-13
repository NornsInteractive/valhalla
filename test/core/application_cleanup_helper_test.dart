import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/services/application_cleanup_helper.dart';

Future<Directory> _isolatedFixture() =>
    Directory.systemTemp.createTemp('cleanup-helper-fixture-');

Future<void> _writePy(Directory fixture, String name, String content) async {
  final file = File('${fixture.path}/$name');
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
}

Future<void> _seedFixture(Directory fixture) async {
  final script = ApplicationCleanupHelper.script;
  final marker = 'try:\n    sys.exit(main())';
  final idx = script.lastIndexOf(marker);
  if (idx == -1) {
    throw Exception('Footer marker not found in script');
  }
  final helperPy = script.substring(0, idx);
  await _writePy(fixture, 'helper.py', helperPy);
}

Future<Map<String, dynamic>> _runPy(
  Directory fixture,
  String code,
  Map<String, dynamic> args,
) async {
  final argsJson = jsonEncode(args);
  final script =
      '''
import sys, json, os
sys.path.insert(0, "${fixture.path}")
from helper import *

args = json.loads(sys.argv[1])
$code
''';
  final result = await Process.run(
    'python3',
    ['-c', script, argsJson],
    workingDirectory: fixture.path,
    runInShell: false,
  );
  if (result.exitCode != 0) {
    throw Exception(
      'Python failed: ${result.stderr}\nstdout: ${result.stdout}',
    );
  }
  return jsonDecode(result.stdout.toString().trim()) as Map<String, dynamic>;
}

// Real ownership/configuration, descriptor traversal, inspect and cleanup code;
// Docker, host machine-id and mount inventory are controlled external fixtures.
const _inspectionFixture = r'''
import helper as h, contextlib, io, time, builtins
from pathlib import Path
h.DEADLINE = time.monotonic() + 30
os.environ.pop('DOCKER_HOST', None)
os.environ.pop('DOCKER_CONTEXT', None)
base = Path(args['base'])
home = base / 'home'
control = home / '.local/share/valhalla/app-center'
data = base / 'data'
child = data / 'cache'
database = data / 'database'
outside = base / 'outside.txt'
ident = 'a' * 32
directory = control / 'deployments' / ident
task = control / 'tasks' / ('b' * 32)
for item in (directory, task, child, database, base / 'docker-root'):
    item.mkdir(parents=True, exist_ok=True)
(data / 'unmounted.txt').write_text('unmounted sentinel')
(child / 'cache.txt').write_text('cache sentinel')
(database / 'database.txt').write_text('database sentinel')
outside.write_text('outside sentinel')
app = {'id': ident, 'project': 'valhalla-app-' + ident, 'directory': str(directory)}
mounts = [
    {'service': 'web', 'source': str(child), 'target': '/cache'},
    {'service': 'web', 'source': str(database), 'target': '/database'},
]
config = {'name': 'fixture', 'dataRoot': str(data), 'mounts': mounts}
compose = {'services': {'web': {'image': 'fixture', 'volumes': [
    {'type': 'bind', 'source': item['source'], 'target': item['target']}
    for item in mounts
]}}}
(directory / '.valhalla-app-owner').write_text(ident)
def save_config():
    (directory / 'configuration.json').write_text(json.dumps(config))
    (directory / 'compose.json').write_text(json.dumps(compose))
save_config()
request = {'app': app, 'home': str(home), 'controlRoot': str(control),
    'targetIdentity': 'a' * 32 + '|fixture-daemon',
    'taskDirectory': str(task), 'uid': os.getuid(), 'gid': os.getgid()}
h.open = lambda filename, *args, **kwargs: io.StringIO('a' * 32) if filename == '/etc/machine-id' else builtins.open(filename, *args, **kwargs)
records = [('fixture-device', '/', '/')]
h.mount_records = lambda: records
container_rows = []
volume_rows = {}
removed_volumes = []
volume_in_use = False
def docker_command(command, failure_code='INSPECTION_INCOMPLETE'):
    if command == ['docker', 'info', '--format', '{{.ID}}']:
        return 'fixture-daemon'
    if command == ['docker', 'info', '--format', '{{.DockerRootDir}}']:
        return str(base / 'docker-root')
    if command[:3] == ['docker', 'context', 'inspect']:
        return 'unix:///var/run/docker.sock'
    if command[:2] == ['docker', 'compose']:
        assert command[2:4] == ['--project-name', app['project']]
        return json.dumps(compose)
    if command == ['docker', 'ps', '-aq', '--no-trunc']:
        return '\n'.join(item['Id'] for item in container_rows)
    if command[:2] == ['docker', 'inspect']:
        return json.dumps([item for item in container_rows if item['Id'] in command[2:]])
    if command == ['docker', 'volume', 'ls', '--format', '{{.Name}}']:
        return '\n'.join(volume_rows)
    if command[:3] == ['docker', 'volume', 'inspect']:
        return json.dumps([volume_rows[command[3]]])
    if command[:4] == ['docker', 'volume', 'rm', '--']:
        assert failure_code == 'VOLUME_DELETE_FAILED'
        if volume_in_use:
            h.fail(failure_code)
        removed_volumes.append(command[4])
        del volume_rows[command[4]]
        return command[4]
    raise AssertionError('unexpected command: ' + repr(command))
h.command = docker_command
def target(snapshot, location):
    return next(item for item in snapshot['targets'] if item['source'] == str(location))
def approval(snapshot, paths):
    selected = [target(snapshot, location)['key'] for location in paths]
    return dict(request, snapshot=snapshot, selectedKeys=selected, acknowledgedRiskKeys=selected)
def clean(selected_request):
    with contextlib.redirect_stdout(io.StringIO()):
        code = h.cleanup(selected_request)
    return {'code': code, 'results': json.loads((task / 'cleanup.json').read_text())['results']}
''';

void main() {
  late List<Directory> fixtures;

  setUp(() {
    fixtures = [];
  });

  tearDown(() async {
    for (final dir in fixtures) {
      if (dir.existsSync()) await dir.delete(recursive: true);
    }
  });

  Future<Directory> newFixture() async {
    final dir = await _isolatedFixture();
    fixtures.add(dir);
    await _seedFixture(dir);
    return dir;
  }

  Future<Map<String, dynamic>> inspectScenario(String code) async {
    final fixture = await newFixture();
    return _runPy(fixture, '$_inspectionFixture\n$code', {
      'base': fixture.path,
    });
  }

  group('explicit advanced cleanup', () {
    test(
      'retry can rediscover only previously selected anonymous volumes',
      () async {
        final result = await inspectScenario(r'''
request['allowAdvancedCleanup'] = True
container_rows.append({'Id': 'd' * 64, 'Config': {'Labels': {
    'com.valhalla.app.instance': app['id'], 'com.docker.compose.project': app['project'],
    'com.docker.compose.service': 'web'}}, 'Mounts': [
    {'Type': 'volume', 'Name': 'selected-volume', 'Destination': '/selected', 'RW': True},
    {'Type': 'volume', 'Name': 'kept-volume', 'Destination': '/kept', 'RW': True}]})
for name in ['selected-volume', 'kept-volume']:
    volume_rows[name] = {'Name': name, 'Driver': 'local', 'CreatedAt': '2026-10-13T00:00:00Z'}
snapshot = h.inspect(request)
approved = approval(snapshot, ['selected-volume'])
(task / 'cleanup-request.json').write_text(json.dumps(approved))
(task / 'uninstall-complete').write_text('1')
(task / 'state').write_text('failed\n76\n')
(task / 'identity').write_text('1\n00000000-0000-0000-0000-000000000000\n0\n')
container_rows.clear()
retry = dict(request, cleanupOnly=True, previousTask=str(task), previousTaskId='b' * 32)
fresh = h.inspect(retry)
assert target(fresh, 'selected-volume')['blockedReason'] is None
assert not any(item['source'] == 'kept-volume' for item in fresh['targets'])
retry.update(snapshot=fresh, selectedKeys=[target(fresh, 'selected-volume')['key']],
    acknowledgedRiskKeys=[target(fresh, 'selected-volume')['key']])
result = clean(retry)
result.update(removed=removed_volumes, kept='kept-volume' in volume_rows)
print(json.dumps(result))
''');
        expect(result['code'], 0);
        expect(result['removed'], ['selected-volume']);
        expect(result['kept'], isTrue);
      },
    );
    test(
      'anonymous volume survives Compose down in the pinned cleanup snapshot',
      () async {
        final result = await inspectScenario(r'''
request['allowAdvancedCleanup'] = True
container_rows.append({'Id': 'd' * 64, 'Config': {'Labels': {
    'com.valhalla.app.instance': app['id'], 'com.docker.compose.project': app['project'],
    'com.docker.compose.service': 'web'}}, 'Mounts': [
    {'Type': 'volume', 'Name': 'anonymous-volume', 'Destination': '/anonymous', 'RW': True}]})
volume_rows['anonymous-volume'] = {'Name': 'anonymous-volume', 'Driver': 'local',
    'Mountpoint': str(base / 'docker-root/volumes/anonymous-volume/_data'),
    'CreatedAt': '2026-10-13T00:00:00Z', 'Labels': None, 'Options': None}
snapshot = h.inspect(request)
value = target(snapshot, 'anonymous-volume')
assert value['serviceTargets'] == ['web:/anonymous'] and 'external' in value['risks']
container_rows.clear()
result = clean(approval(snapshot, ['anonymous-volume']))
result.update(removed=removed_volumes, data_exists=data.exists())
print(json.dumps(result))
''');
        expect(result['code'], 0);
        expect(result['removed'], ['anonymous-volume']);
        expect(result['data_exists'], isTrue);
      },
    );

    test(
      'lack of directory permission is reported separately and remains unselectable',
      () async {
        final result = await inspectScenario(r'''
request['allowAdvancedCleanup'] = True
original_open = h.open_dir
def denied(path):
    if path == str(child):
        raise PermissionError('fixture permission denied')
    return original_open(path)
h.open_dir = denied
print(json.dumps(target(h.inspect(request), child)))
''');
        expect(result['blockedReason'], 'APP_CENTER_CLEANUP_PERMISSION_DENIED');
      },
    );
    test(
      'shared paths require acknowledgement and only selected data is deleted',
      () async {
        final result = await inspectScenario(r'''
container_rows.append({'Id': 'c' * 64, 'Config': {'Labels': {}}, 'Mounts': [
    {'Type': 'bind', 'Source': str(child), 'Destination': '/shared'}]})
assert target(h.inspect(request), child)['blockedReason'] == 'APP_CENTER_CLEANUP_SHARED_PATH'
request['allowAdvancedCleanup'] = True
snapshot = h.inspect(request)
value = target(snapshot, child)
assert value['blockedReason'] is None and 'shared' in value['risks']
assert value['references'] == ['bind:' + str(child)]
unauthorized = approval(snapshot, [child])
unauthorized['acknowledgedRiskKeys'] = []
denied = clean(unauthorized)
assert denied['code'] == 76 and (child / 'cache.txt').exists()
result = clean(approval(snapshot, [child]))
result.update(child_exists=child.exists(), kept=(database / 'database.txt').read_text(),
    outside=outside.read_text(), container_count=len(container_rows))
print(json.dumps(result))
''');
        expect(result['code'], 0);
        expect(result['results'].single['outcome'], 'removed');
        expect(result['child_exists'], isFalse);
        expect(result['kept'], 'database sentinel');
        expect(result['outside'], 'outside sentinel');
        expect(result['container_count'], 1);
      },
    );

    test(
      'new sharing after preview invalidates deletion without losing data',
      () async {
        final result = await inspectScenario(r'''
request['allowAdvancedCleanup'] = True
snapshot = h.inspect(request)
container_rows.append({'Id': 'c' * 64, 'Config': {'Labels': {}}, 'Mounts': [
    {'Type': 'bind', 'Source': str(child), 'Destination': '/new-reference'}]})
result = clean(approval(snapshot, [child]))
result['sentinel'] = (child / 'cache.txt').read_text()
print(json.dumps(result))
''');
        expect(result['code'], 76);
        expect(
          result['results'].single['reasonCode'],
          'APP_CENTER_CLEANUP_PATH_CHANGED',
        );
        expect(result['sentinel'], 'cache sentinel');
      },
    );

    test(
      'application system subdirectory can be selected but OS root stays blocked',
      () async {
        final result = await inspectScenario(r'''
system = base / 'etc'
system.mkdir()
child.rename(system / 'app-data')
config['mounts'][0]['source'] = str(system / 'app-data')
compose['services']['web']['volumes'][0]['source'] = str(system / 'app-data')
save_config()
h.system_paths = lambda: [str(system)]
request['allowAdvancedCleanup'] = True
snapshot = h.inspect(request)
value = target(snapshot, system / 'app-data')
assert value['blockedReason'] is None and 'system' in value['risks']
config['dataRoot'] = str(system)
save_config()
root = target(h.inspect(request), system)
assert root['blockedReason'] == 'APP_CENTER_CLEANUP_CRITICAL_PATH'
config['dataRoot'] = str(data)
save_config()
result = clean(approval(snapshot, [system / 'app-data']))
result.update(system_exists=system.exists(), child_exists=(system / 'app-data').exists())
print(json.dumps(result))
''');
        expect(result['code'], 0);
        expect(result['system_exists'], isTrue);
        expect(result['child_exists'], isFalse);
      },
    );

    test(
      'verified retired applications do not falsely protect retained data',
      () async {
        final result = await inspectScenario(r'''
other_id = 'c' * 32
other = control / 'deployments' / other_id
other.mkdir()
(other / '.valhalla-app-owner').write_text(other_id)
(other / 'configuration.json').write_text(json.dumps({'dataRoot': str(child), 'mounts': []}))
before = target(h.inspect(request), child)['blockedReason']
(other / 'deployment.uninstalled.json').write_text(json.dumps({'id': other_id,
    'project': 'valhalla-app-' + other_id, 'directory': str(other)}))
after = target(h.inspect(request), child)['blockedReason']
(other / 'deployment.json').write_text('{}')
live = target(h.inspect(request), child)['blockedReason']
print(json.dumps({'before': before, 'after': after, 'live': live}))
''');
        expect(result['before'], 'APP_CENTER_CLEANUP_SHARED_PATH');
        expect(result['after'], isNull);
        expect(result['live'], 'APP_CENTER_CLEANUP_SHARED_PATH');
      },
    );

    for (final mode in ['selected', 'in-use', 'recreated', 'absent']) {
      test(
        'Docker volume $mode is handled by Docker, never filesystem removal',
        () async {
          final result = await inspectScenario('''
compose['services']['web']['volumes'].append({'type': 'volume', 'source': 'cache', 'target': '/volume'})
compose['volumes'] = {'cache': {'name': 'fixture-volume'}}
save_config()
volume_rows['fixture-volume'] = {'Name': 'fixture-volume', 'Driver': 'local',
    'Mountpoint': str(base / 'docker-root/volumes/fixture-volume/_data'),
    'Scope': 'local', 'CreatedAt': '2026-10-13T00:00:00Z',
    'Labels': {'com.docker.compose.project': app['project']}, 'Options': None}
default = target(h.inspect(request), 'fixture-volume')
assert default['blockedReason'] == 'APP_CENTER_CLEANUP_VOLUME_PROTECTED'
request['allowAdvancedCleanup'] = True
snapshot = h.inspect(request)
value = target(snapshot, 'fixture-volume')
assert value['kind'] == 'volume' and value['risks'] == ['volume'] and value['blockedReason'] is None
volume_in_use = '$mode' == 'in-use'
if '$mode' == 'recreated':
    volume_rows['fixture-volume']['CreatedAt'] = '2026-10-13T00:00:01Z'
if '$mode' == 'absent':
    del volume_rows['fixture-volume']
result = clean(approval(snapshot, ['fixture-volume']))
result.update(removed=removed_volumes, root_exists=data.exists(),
    sentinel=(child / 'cache.txt').read_text())
print(json.dumps(result))
''');
          final success = mode == 'selected' || mode == 'absent';
          expect(result['code'], success ? 0 : 76);
          expect(result['root_exists'], isTrue);
          expect(result['sentinel'], 'cache sentinel');
          expect(
            result['removed'],
            mode == 'selected' ? ['fixture-volume'] : isEmpty,
          );
          if (mode == 'in-use') {
            expect(
              result['results'].single['reasonCode'],
              'APP_CENTER_CLEANUP_VOLUME_DELETE_FAILED',
            );
          } else if (mode == 'recreated') {
            expect(
              result['results'].single['reasonCode'],
              'APP_CENTER_CLEANUP_PATH_CHANGED',
            );
          } else {
            expect(
              result['results'].single['outcome'],
              mode == 'absent' ? 'alreadyAbsent' : 'removed',
            );
          }
        },
      );
    }
  });

  group('whole data root real inspect and cleanup', () {
    for (final mode in ['root', 'child', 'both']) {
      test('$mode selection removes only authorized top-level trees', () async {
        final result = await inspectScenario('''
snapshot = h.inspect(request)
root = target(snapshot, data)
assert root['isDataRoot'] and root['blockedReason'] is None
assert root['risks'] == ['legacy']
paths = {'root': [data], 'child': [child], 'both': [data, child]}['$mode']
result = clean(approval(snapshot, paths))
result.update(root_exists=data.exists(), child_exists=child.exists(),
    database_exists=database.exists(), unmounted_exists=(data / 'unmounted.txt').exists(),
    outside=outside.read_text())
print(json.dumps(result))
''');
        expect(result['code'], 0);
        final removed = result['results'] as List;
        expect(removed, hasLength(1));
        expect(removed.single['outcome'], 'removed');
        expect(result['root_exists'], mode == 'child');
        expect(result['child_exists'], false);
        expect(result['database_exists'], mode == 'child');
        expect(result['unmounted_exists'], mode == 'child');
        expect(result['outside'], 'outside sentinel');
      });
    }

    test(
      'root and same-path bind are one target; named volumes stay protected',
      () async {
        final result = await inspectScenario(r'''
config['mounts'].append({'service': 'web', 'source': str(data), 'target': '/all'})
compose['services']['web']['volumes'].extend([
    {'type': 'bind', 'source': str(data), 'target': '/all'},
    {'type': 'volume', 'source': 'fixture-volume', 'target': '/volume'},
])
save_config()
snapshot = h.inspect(request)
roots = [item for item in snapshot['targets'] if item['source'] == str(data)]
volume = target(snapshot, 'fixture-volume')
print(json.dumps({'roots': roots, 'volume': volume}))
''');
        final roots = result['roots'] as List;
        expect(roots, hasLength(1));
        expect(roots.single['isDataRoot'], true);
        expect(roots.single['serviceTargets'], ['web:/all']);
        expect(roots.single['blockedReason'], isNull);
        expect(
          result['volume']['blockedReason'],
          'APP_CENTER_CLEANUP_VOLUME_PROTECTED',
        );
      },
    );

    for (final name in ['.ssh', '.gnupg']) {
      for (final type in ['directory', 'file', 'link']) {
        test(
          'unmounted $name $type blocks preview and direct removal',
          () async {
            final result = await inspectScenario('''
private = data / 'unmounted' / '$name'
private.parent.mkdir()
if '$type' == 'directory':
    private.mkdir()
    (private / 'secret').write_text('private sentinel')
elif '$type' == 'file':
    private.write_text('private sentinel')
else:
    private.symlink_to(outside)
snapshot = h.inspect(request)
root = target(snapshot, data)
try:
    h.remove_directory(root)
    execution = 'unexpected success'
except h.Blocked as error:
    execution = str(error)
print(json.dumps({'reason': root['blockedReason'], 'execution': execution,
    'private': private.exists(), 'unmounted': (data / 'unmounted.txt').exists(),
    'outside': outside.read_text()}))
''');
            expect(result['reason'], 'APP_CENTER_CLEANUP_PROTECTED_PATH');
            expect(result['execution'], 'APP_CENTER_CLEANUP_PROTECTED_PATH');
            expect(result['private'], true);
            expect(result['unmounted'], true);
            expect(result['outside'], 'outside sentinel');
          },
        );
      }
    }

    for (final change in [
      'protected',
      'identity',
      'sharing',
      'target',
      'config',
    ]) {
      test('$change introduced after preview retains every sentinel', () async {
        final result = await inspectScenario('''
snapshot = h.inspect(request)
approved = approval(snapshot, [data])
if '$change' == 'protected':
    (data / '.ssh').mkdir()
    (data / '.ssh' / 'secret').write_text('private sentinel')
elif '$change' == 'identity':
    data.rename(base / 'old-data')
    data.mkdir()
    (data / 'replacement').write_text('replacement sentinel')
elif '$change' == 'sharing':
    container_rows.append({'Id': 'f' * 64, 'Config': {'Labels': {}},
        'Mounts': [{'Type': 'bind', 'Source': str(child), 'Destination': '/cache', 'RW': True}]})
elif '$change' == 'config':
    config['name'] = 'changed-after-preview'
    save_config()
else:
    approved['targetIdentity'] = 'f' * 32 + '|fixture-daemon'
result = clean(approved)
result.update(root_exists=data.exists(), outside=outside.read_text())
print(json.dumps(result))
''');
        expect(result['code'], 76);
        expect(result['root_exists'], true);
        expect(result['outside'], 'outside sentinel');
        expect((result['results'] as List).single['outcome'], 'retained');
      });
    }

    test(
      'protected descendant introduced after removal preflight still survives',
      () async {
        final result = await inspectScenario(r'''
snapshot = h.inspect(request)
root = target(snapshot, data)
original = h.empty_directory
injected = False
private = data / 'late-child' / '.ssh'
def changing_tree(fd, root_mount, budget, deadline, source, expected, links, readonly=False):
    global injected
    result = original(fd, root_mount, budget, deadline, source, expected, links, readonly=readonly)
    if readonly and len(links) == 1 and not injected:
        private.mkdir(parents=True)
        (private / 'key').write_text('late private sentinel')
        injected = True
    return result
h.empty_directory = changing_tree
try:
    h.remove_directory(root)
    error = 'unexpected success'
except h.Blocked as blocked:
    error = str(blocked)
print(json.dumps({'error': error, 'private': (private / 'key').read_text(),
    'outside': outside.read_text(), 'root': data.exists()}))
''');
        expect(result['error'], 'APP_CENTER_CLEANUP_PROTECTED_PATH');
        expect(result['private'], 'late private sentinel');
        expect(result['outside'], 'outside sentinel');
        expect(result['root'], true);
      },
    );

    test(
      'configured symlink child blocks whole root but cannot traverse outside',
      () async {
        final result = await inspectScenario(r'''
child.rename(base / 'original-cache')
child.symlink_to(base / 'original-cache', target_is_directory=True)
snapshot = h.inspect(request)
print(json.dumps({'root': target(snapshot, data)['blockedReason'],
    'child': target(snapshot, child)['blockedReason'],
    'sentinel': (base / 'original-cache' / 'cache.txt').read_text()}))
''');
        expect(result['root'], 'APP_CENTER_CLEANUP_SYMLINK_PATH');
        expect(result['child'], 'APP_CENTER_CLEANUP_SYMLINK_PATH');
        expect(result['sentinel'], 'cache sentinel');
      },
    );

    test(
      'empty selection and missing legacy risk acknowledgement never authorize root',
      () async {
        final result = await inspectScenario(r'''
snapshot = h.inspect(request)
selected = approval(snapshot, [data])
errors = []
for attempt in [dict(selected, selectedKeys=[]), dict(selected, acknowledgedRiskKeys=[])]:
    try:
        h.selected_snapshot(attempt, h.inspect(request))
        errors.append('unexpected success')
    except h.Blocked as error:
        errors.append(str(error))
print(json.dumps({'errors': errors, 'sentinel': (data / 'unmounted.txt').read_text()}))
''');
        expect(result['errors'], [
          'APP_CENTER_CLEANUP_SELECTION_INVALID',
          'APP_CENTER_CLEANUP_ACKNOWLEDGEMENT_REQUIRED',
        ]);
        expect(result['sentinel'], 'unmounted sentinel');
      },
    );

    for (final alias in ['exact', 'ancestor', 'descendant']) {
      test(
        'external $alias backing alias blocks preview and removal',
        () async {
          final result = await inspectScenario('''
snapshot = h.inspect(request)
root = target(snapshot, data)
backing = {'exact': data, 'ancestor': base, 'descendant': child}['$alias']
records.append(('fixture-device', str(backing), str(base / 'export')))
current = h.inspect(request)
try:
    h.remove_directory(root)
    execution = 'unexpected success'
except h.Blocked as error:
    execution = str(error)
print(json.dumps({'reason': target(current, data)['blockedReason'], 'execution': execution,
    'unmounted': (data / 'unmounted.txt').read_text(), 'outside': outside.read_text()}))
''');
          expect(result['reason'], 'APP_CENTER_CLEANUP_SHARED_PATH');
          expect(result['execution'], 'APP_CENTER_CLEANUP_SHARED_PATH');
          expect(result['unmounted'], 'unmounted sentinel');
          expect(result['outside'], 'outside sentinel');
        },
      );
    }

    test(
      'ordinary ancestor mounts and unrelated filesystems do not block root',
      () async {
        final result = await inspectScenario(r'''
records.extend([
    ('fixture-device', str(base), str(base)),
    ('other-device', str(data), str(base / 'other-filesystem')),
    ('fixture-device', str(base / 'unrelated'), str(base / 'export')),
])
snapshot = h.inspect(request)
print(json.dumps({'reason': target(snapshot, data)['blockedReason'],
    'cleanup': clean(approval(snapshot, [data]))}))
''');
        expect(result['reason'], isNull);
        expect(result['cleanup']['code'], 0);
      },
    );

    test(
      'shared managed directory and nested mount cannot be bypassed via root',
      () async {
        final result = await inspectScenario(r'''
other = control / 'deployments' / ('c' * 32)
other.mkdir()
(other / '.valhalla-app-owner').write_text('c' * 32)
(other / 'configuration.json').write_text(json.dumps({'dataRoot': str(child), 'mounts': []}))
shared = h.inspect(request)
(other / 'configuration.json').write_text(json.dumps({'dataRoot': str(base / 'other-data'), 'mounts': []}))
records.append(('mount-device', '/', str(child)))
mounted = h.inspect(request)
print(json.dumps({'shared': target(shared, data)['blockedReason'],
    'mounted': target(mounted, data)['blockedReason']}))
''');
        expect(result['shared'], 'APP_CENTER_CLEANUP_SHARED_PATH');
        expect(result['mounted'], 'APP_CENTER_CLEANUP_MOUNTPOINT_PROTECTED');
      },
    );

    test(
      'retry cannot expand root-only approval or repeat completed cleanup',
      () async {
        final result = await inspectScenario(r'''
snapshot = h.inspect(request)
approved = approval(snapshot, [data])
(task / 'cleanup-request.json').write_text(json.dumps(approved))
(task / 'uninstall-complete').write_text('1')
(task / 'state').write_text('failed\n76\n')
# A different boot makes the original worker provably inactive without touching processes.
(task / 'identity').write_text('1\n00000000-0000-0000-0000-000000000000\n0\n')
retry = dict(approved, cleanupOnly=True, previousTask=str(task), previousTaskId='b' * 32)
h.guard_retry(retry)
expanded = dict(retry, selectedKeys=[target(snapshot, child)['key']])
errors = []
for attempt in [expanded]:
    try:
        h.guard_retry(attempt)
        errors.append('unexpected success')
    except h.Blocked as error:
        errors.append(str(error))
(task / 'cleanup.json').write_text(json.dumps({'results': [
    {'key': target(snapshot, data)['key'], 'outcome': 'removed'}
]}))
try:
    h.guard_retry(retry)
    errors.append('unexpected success')
except h.Blocked as error:
    errors.append(str(error))
print(json.dumps({'errors': errors, 'outside': outside.read_text()}))
''');
        expect(result['errors'], [
          'APP_CENTER_CLEANUP_SELECTION_INVALID',
          'APP_CENTER_CLEANUP_SELECTION_INVALID',
        ]);
        expect(result['outside'], 'outside sentinel');
      },
    );
  });

  group('ApplicationCleanupHelper Python runtime regression', () {
    test('open_dir and normalized work on fixture paths', () async {
      final fixture = await newFixture();
      final target = Directory('${fixture.path}/target');
      await target.create(recursive: true);
      await File('${target.path}/child.txt').writeAsString('content');

      final result = await _runPy(
        fixture,
        '''
norm = normalized(args["target"])
fd = open_dir(norm)
print(json.dumps({"ok": True, "fd": fd}, separators=(",", ":")))
''',
        {'target': '${fixture.path}/target'},
      );
      expect(result['ok'], isTrue);
      expect(result['fd'], isA<int>());
    });

    test(
      'remove_directory safe leaf removes its contents; sibling sentinel remains',
      () async {
        final fixture = await newFixture();
        final leaf = Directory('${fixture.path}/leaf');
        await leaf.create(recursive: true);
        await File('${leaf.path}/file1.txt').writeAsString('data1');
        await File('${leaf.path}/file2.txt').writeAsString('data2');
        final subdir = Directory('${leaf.path}/subdir');
        await subdir.create(recursive: true);
        await File('${subdir.path}/nested.txt').writeAsString('nested');

        final sentinel = File('${fixture.path}/sentinel.txt');
        await sentinel.writeAsString('protected');

        final result = await _runPy(
          fixture,
          '''
norm = normalized(args["leaf"])
parent_fd = open_dir(os.path.dirname(norm))
name = os.path.basename(norm)
fd = os.open(name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC, dir_fd=parent_fd)
ident = identity(fd)
os.close(fd)
os.close(parent_fd)
outcome = remove_directory({"source": norm, "identity": ident})
print(json.dumps({"outcome": outcome}, separators=(",", ":")))
''',
          {'leaf': '${fixture.path}/leaf'},
        );

        expect(result['outcome'], 'removed');
        expect(leaf.existsSync(), isFalse);
        expect(sentinel.existsSync(), isTrue);
        expect(await sentinel.readAsString(), 'protected');
      },
    );

    test(
      'nested symlink unlinked but external sibling sentinel survives',
      () async {
        final fixture = await newFixture();
        final leaf = Directory('${fixture.path}/leaf');
        await leaf.create(recursive: true);
        await File('${leaf.path}/file.txt').writeAsString('data');

        final external = Directory('${fixture.path}/external');
        await external.create(recursive: true);
        await File(
          '${external.path}/sentinel.txt',
        ).writeAsString('external-protected');

        final linkToExternal = Link('${fixture.path}/link-to-external');
        await linkToExternal.create(external.path);

        final nestedLink = Link('${leaf.path}/nested-link');
        await nestedLink.create(external.path);

        final result = await _runPy(
          fixture,
          '''
norm = normalized(args["leaf"])
parent_fd = open_dir(os.path.dirname(norm))
name = os.path.basename(norm)
fd = os.open(name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC, dir_fd=parent_fd)
ident = identity(fd)
os.close(fd)
os.close(parent_fd)
outcome = remove_directory({"source": norm, "identity": ident})
print(json.dumps({"outcome": outcome}, separators=(",", ":")))
''',
          {'leaf': '${fixture.path}/leaf'},
        );

        expect(result['outcome'], 'removed');
        expect(
          await File('${external.path}/sentinel.txt').readAsString(),
          'external-protected',
        );
        expect(await linkToExternal.target(), external.path);
        expect(await linkToExternal.exists(), isTrue);
      },
    );

    test('selected symlink target rejected with leaf identity', () async {
      final fixture = await newFixture();
      final leaf = Directory('${fixture.path}/leaf');
      await leaf.create(recursive: true);
      await File('${leaf.path}/file.txt').writeAsString('data');

      final linkToLeaf = Link('${fixture.path}/link-to-leaf');
      await linkToLeaf.create(leaf.path);

      final result = await _runPy(
        fixture,
        '''
norm_leaf = normalized(args["leaf"])
norm_link = normalized(args["link"])
parent_fd = open_dir(os.path.dirname(norm_leaf))
name = os.path.basename(norm_leaf)
fd = os.open(name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC, dir_fd=parent_fd)
try:
    ident = identity(fd)
finally:
    os.close(fd)
    os.close(parent_fd)
try:
    outcome = remove_directory({"source": norm_link, "identity": ident})
    print(json.dumps({"outcome": outcome, "error": "unexpected_success"}, separators=(",", ":")))
except OSError as e:
    print(json.dumps({"outcome": "failed", "errno": e.errno}, separators=(",", ":")))
except Exception as e:
    print(json.dumps({"outcome": "failed", "error": str(e)}, separators=(",", ":")))
''',
        {
          'leaf': '${fixture.path}/leaf',
          'link': '${fixture.path}/link-to-leaf',
        },
      );

      expect(result['outcome'], 'failed');
      expect([20, 40], contains(result['errno']));
      expect(leaf.existsSync(), isTrue);
      expect(await File('${leaf.path}/file.txt').readAsString(), 'data');
      expect(await linkToLeaf.target(), leaf.path);
      expect(await linkToLeaf.exists(), isTrue);
    });

    test(
      'replaced inode target fails closed with PATH_CHANGED; both sentinels survive',
      () async {
        final fixture = await newFixture();
        final leaf = Directory('${fixture.path}/leaf');
        await leaf.create(recursive: true);
        await File('${leaf.path}/file.txt').writeAsString('data');

        final sentinel = File('${fixture.path}/sentinel.txt');
        await sentinel.writeAsString('protected');

        final result = await _runPy(
          fixture,
          '''
norm = normalized(args["leaf"])
parent_fd = open_dir(os.path.dirname(norm))
name = os.path.basename(norm)
fd = os.open(name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC, dir_fd=parent_fd)
ident = identity(fd)
os.close(fd)
os.close(parent_fd)

os.rename(norm, norm + "_old")
new_leaf = os.path.join(os.path.dirname(norm), "leaf")
os.mkdir(new_leaf)
with open(os.path.join(new_leaf, "file.txt"), "w") as f:
    f.write("other")

try:
    outcome = remove_directory({"source": norm, "identity": ident})
    print(json.dumps({"outcome": outcome, "error": "unexpected_success"}, separators=(",", ":")))
except Exception as e:
    print(json.dumps({"outcome": "failed", "error": str(e)}, separators=(",", ":")))
''',
          {'leaf': '${fixture.path}/leaf'},
        );

        expect(result['outcome'], 'failed');
        expect(result['error'], contains('PATH_CHANGED'));
        expect(
          await File('${fixture.path}/leaf_old/file.txt').readAsString(),
          'data',
        );
        expect(
          await File('${fixture.path}/leaf/file.txt').readAsString(),
          'other',
        );
        expect(sentinel.existsSync(), isTrue);
        expect(await sentinel.readAsString(), 'protected');
      },
    );

    test(
      'descriptor detachment: renamed child fd blocked with PATH_CHANGED; both sentinels survive',
      () async {
        final fixture = await newFixture();
        final root = Directory('${fixture.path}/root');
        await root.create(recursive: true);
        final child = Directory('${root.path}/child');
        await child.create(recursive: true);
        await File(
          '${child.path}/original.txt',
        ).writeAsString('original-sentinel');

        final result = await _runPy(
          fixture,
          '''
import os, json
norm_root = normalized(args["root"])
norm_child = os.path.join(norm_root, "child")
renamed_child = os.path.join(os.path.dirname(norm_root), "child_renamed")

root_fd = open_dir(norm_root)
child_fd = os.open("child", os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC, dir_fd=root_fd)
try:
    root_ident = identity(root_fd)
    links = [(root_fd, "child", child_fd)]

    os.rename(norm_child, renamed_child)
    os.mkdir(norm_child)
    with open(os.path.join(norm_child, "replacement.txt"), "w") as f:
        f.write("replacement-sentinel")

    try:
        empty_directory(child_fd, root_ident["mountId"], [0], time.monotonic() + 60, norm_root, root_ident, links)
        print(json.dumps({"outcome": "unexpected_success"}, separators=(",", ":")))
    except Blocked as e:
        print(json.dumps({"outcome": "blocked", "error": str(e)}, separators=(",", ":")))
    except Exception as e:
        print(json.dumps({"outcome": "failed", "error": str(e)}, separators=(",", ":")))
finally:
    try:
        os.close(child_fd)
    except Exception:
        pass
    try:
        os.close(root_fd)
    except Exception:
        pass
''',
          {'root': '${fixture.path}/root'},
        );

        expect(result['outcome'], 'blocked');
        expect(result['error'], 'APP_CENTER_CLEANUP_PATH_CHANGED');
        expect(
          await File(
            '${fixture.path}/child_renamed/original.txt',
          ).readAsString(),
          'original-sentinel',
        );
        expect(
          await File(
            '${fixture.path}/root/child/replacement.txt',
          ).readAsString(),
          'replacement-sentinel',
        );
      },
    );
  });

  group('containers() inspect record Mounts validation', () {
    const id =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

    Future<Map<String, dynamic>> runContainers(Map<String, dynamic> row) async {
      final fixture = await newFixture();
      return _runPy(
        fixture,
        '''
import helper as h

def fake_command(argv):
    if argv == ["docker", "ps", "-aq", "--no-trunc"]:
        return "$id\\n"
    if argv == ["docker", "inspect", "$id"]:
        return json.dumps(args["rows"])
    raise RuntimeError("unexpected docker command: %r" % (argv,))

h.command = fake_command
try:
    rows = h.containers()
    print(json.dumps({"rows": rows}, separators=(",", ":")))
except h.Blocked as e:
    print(json.dumps({"error": str(e)}, separators=(",", ":")))
''',
        {
          'rows': [row],
        },
      );
    }

    final invalidCases = <String, Map<String, dynamic>>{
      'Mounts missing': {'Id': id},
      'Mounts null': {'Id': id, 'Mounts': null},
      'Mounts not list object': {'Id': id, 'Mounts': <String, dynamic>{}},
      'Mounts null entry (nonMap)': {
        'Id': id,
        'Mounts': <dynamic>[null],
      },
      'Mounts entry missing Type': {
        'Id': id,
        'Mounts': [
          {'Source': '/fixture/data', 'Destination': '/data'},
        ],
      },
      'Mounts entry missing Source': {
        'Id': id,
        'Mounts': [
          {'Type': 'bind', 'Destination': '/data'},
        ],
      },
    };

    invalidCases.forEach((name, row) {
      test('rejects $name with INSPECTION_INCOMPLETE', () async {
        final result = await runContainers(row);
        expect(result['error'], 'APP_CENTER_CLEANUP_INSPECTION_INCOMPLETE');
      });
    });

    test('accepts empty Mounts and preserves exact row', () async {
      final row = <String, dynamic>{'Id': id, 'Mounts': <dynamic>[]};
      final result = await runContainers(row);
      expect(result['error'], isNull);
      expect(result['rows'], [row]);
    });

    test('accepts bind mount entry and preserves exact row', () async {
      final row = <String, dynamic>{
        'Id': id,
        'Mounts': [
          {
            'Type': 'bind',
            'Source': '/fixture/data',
            'Destination': '/data',
            'RW': true,
          },
        ],
      };
      final result = await runContainers(row);
      expect(result['error'], isNull);
      expect(result['rows'], [row]);
    });
  });
}
