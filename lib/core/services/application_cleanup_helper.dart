/// Linux-only, fail-closed cleanup helper. It is shipped only to a confirmed
/// uninstall task; inspection runs the same code without filesystem mutations.
/// Paths come from installed Compose/configuration, never from a UI text field.
class ApplicationCleanupHelper {
  static const script = r'''
import base64, hashlib, json, os, pwd, re, selectors, signal, stat, subprocess, sys, time

LIMIT = 2 * 1024 * 1024
DEADLINE = None
class Blocked(Exception):
    pass

def fail(code):
    raise Blocked('APP_CENTER_CLEANUP_' + code)

def remaining():
    value = DEADLINE - time.monotonic() if DEADLINE is not None else 85
    if value <= 0:
        fail('CLEANUP_LIMIT')
    return value

def normalized(value):
    if not isinstance(value, str) or not value.startswith('/') or value.startswith('//') or value == '/' or len(value) > 4096 or any(chr(code) in value for code in (0, 13, 10)) or os.path.normpath(value) != value:
        fail('PATH_INVALID')
    return value

def within(parent, child):
    return child == parent or child.startswith(parent.rstrip('/') + '/')

def overlaps(a, b):
    return within(a, b) or within(b, a)

def open_dir(value):
    if value != '/':
        normalized(value)
    fd = os.open('/', os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC)
    if value == '/':
        return fd
    try:
        for component in value.strip('/').split('/'):
            next_fd = os.open(component, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC, dir_fd=fd)
            os.close(fd)
            fd = next_fd
        return fd
    except BaseException:
        os.close(fd)
        raise

def read_file(value, limit=LIMIT):
    parent = open_dir(os.path.dirname(value))
    fd = None
    try:
        fd = os.open(os.path.basename(value), os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC, dir_fd=parent)
        if not stat.S_ISREG(os.fstat(fd).st_mode):
            fail('INSPECTION_INCOMPLETE')
        chunks, size = [], 0
        while True:
            chunk = os.read(fd, min(65536, limit + 1 - size))
            if not chunk:
                break
            chunks.append(chunk)
            size += len(chunk)
            if size > limit:
                fail('INSPECTION_INCOMPLETE')
        return b''.join(chunks)
    finally:
        if fd is not None:
            os.close(fd)
        os.close(parent)

def command(args, failure_code='INSPECTION_INCOMPLETE'):
    # No shell expansion, arbitrary executable, URL or user command is accepted.
    deadline = time.monotonic() + min(25, remaining())
    process = subprocess.Popen(args, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, start_new_session=True)
    selector = selectors.DefaultSelector()
    chunks, size = [], 0
    try:
        descriptor = process.stdout.fileno()
        os.set_blocking(descriptor, False)
        selector.register(descriptor, selectors.EVENT_READ)
        while True:
            timeout = min(deadline - time.monotonic(), remaining())
            if timeout <= 0:
                fail('INSPECTION_INCOMPLETE')
            if not selector.select(timeout):
                fail('INSPECTION_INCOMPLETE')
            try:
                chunk = os.read(descriptor, min(65536, 16 * LIMIT + 1 - size))
            except BlockingIOError:
                continue
            if not chunk:
                break
            size += len(chunk)
            if size > 16 * LIMIT:
                fail('INSPECTION_INCOMPLETE')
            chunks.append(chunk)
        code = process.wait(timeout=max(0.001, min(deadline - time.monotonic(), remaining())))
    finally:
        selector.close()
        if process.poll() is None:
            # Only this helper's readonly command process group, never a
            # container, server daemon, previous task or user shell.
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                pass
        process.stdout.close()
    if code != 0:
        fail(failure_code)
    return b''.join(chunks).decode('utf-8').strip()

def mount_id(fd):
    with open('/proc/self/fdinfo/' + str(fd), 'r') as stream:
        for line in stream:
            if line.startswith('mnt_id:'):
                return line.split(':', 1)[1].strip()
    fail('CAPABILITY_UNAVAILABLE')

def identity(fd):
    info = os.fstat(fd)
    return {'device': str(info.st_dev), 'inode': str(info.st_ino), 'mountId': mount_id(fd)}

def capabilities():
    if sys.platform != 'linux' or sys.version_info < (3, 8) or not hasattr(os, 'O_NOFOLLOW') or not hasattr(os, 'O_DIRECTORY'):
        fail('CAPABILITY_UNAVAILABLE')
    if any(fn not in os.supports_dir_fd for fn in (os.open, os.stat, os.unlink, os.rmdir, os.rename)) or any(fn not in os.supports_fd for fn in (os.listdir, os.scandir)):
        fail('CAPABILITY_UNAVAILABLE')
    fd = os.open('/', os.O_RDONLY | os.O_DIRECTORY)
    try:
        mount_id(fd)
    finally:
        os.close(fd)

def guard_target(request):
    host, daemon = request['targetIdentity'].split('|', 1)
    with open('/etc/machine-id', 'r') as stream:
        if stream.read().strip() != host:
            fail('TARGET_CHANGED')
    if os.environ.get('DOCKER_HOST') or os.environ.get('DOCKER_CONTEXT'):
        fail('TARGET_CHANGED')
    if command(['docker', 'info', '--format', '{{.ID}}']) != daemon:
        fail('TARGET_CHANGED')
    request['_dockerRoot'] = normalized(command(['docker', 'info', '--format', '{{.DockerRootDir}}']))
    if not command(['docker', 'context', 'inspect', '--format', '{{.Endpoints.docker.Host}}']).startswith('unix:///'):
        fail('TARGET_CHANGED')

def mount_records():
    result = []
    with open('/proc/self/mountinfo', 'r') as stream:
        for line in stream:
            remaining()
            fields = line.split()
            if len(fields) < 7:
                fail('INSPECTION_INCOMPLETE')
            decode = lambda value: re.sub(r'\\([0-7]{3})', lambda match: chr(int(match[1], 8)), value)
            result.append((fields[2], decode(fields[3]), decode(fields[4])))
            if len(result) > 20000:
                fail('INSPECTION_INCOMPLETE')
    return result

def filesystem_path(source, records):
    matches = [item for item in records if within(item[2], source)]
    if not matches:
        fail('INSPECTION_INCOMPLETE')
    # mountinfo retains covered bind layers too. Longest-prefix alone cannot
    # identify the visible layer when any ancestor is overmounted; never guess.
    if len({item[2] for item in matches}) != len(matches):
        fail('INSPECTION_INCOMPLETE')
    device, root, point = max(matches, key=lambda item: len(item[2]))
    return device, os.path.normpath(os.path.join(root, os.path.relpath(source, point)))

def guard_mount_aliases(source, records, allow_shared=False):
    device, backing = filesystem_path(source, records)
    aliases = []
    for other_device, other_root, point in records:
        remaining()
        # Normal ancestor mounts carry this path; a separate mount exporting
        # any of its backing subtree is an outside reference, even without Docker.
        if not within(point, source) and device == other_device and overlaps(backing, other_root):
            if not allow_shared:
                fail('SHARED_PATH')
            aliases.append('mount:' + point)
    return sorted(aliases)

def system_paths():
    return ['/etc', '/usr', '/bin', '/sbin', '/lib', '/lib64', '/boot']

def protected_paths(request):
    exact = {'/', '/home', '/root', '/var', '/opt', '/srv', '/mnt', '/media', '/data', '/tmp', request['home'], request['home'] + '/.config', request['home'] + '/.local', request['home'] + '/.local/share', request['home'] + '/.cache'}
    exact.update(request.get('_homes', []))
    trees = ['/etc', '/usr', '/bin', '/sbin', '/lib', '/lib64', '/proc', '/sys', '/dev', '/run', '/boot', '/var/lib/docker', '/var/lib/containerd', '/var/lib/valhalla-native-jellyfin', request['controlRoot'], request['_dockerRoot']]
    if request.get('allowAdvancedCleanup') is True:
        # Application subdirectories may be explicitly approved, never whole
        # OS roots, runtime trees, Docker storage or this manager's own records.
        exact.update(system_paths())
        trees = [root for root in trees if root not in system_paths()]
    return exact, trees

def protected(source, request, location, protection):
    exact, trees = protected_paths(request)
    if source in exact or any(within(source, root) for root in exact if root != '/') or any(overlaps(source, root) for root in trees):
        return True
    exact_locations, tree_locations = protection
    if any(location[0] == other[0] and within(location[1], other[1]) for other in exact_locations) or any(location[0] == other[0] and overlaps(location[1], other[1]) for other in tree_locations):
        return True
    return any(part in {'.ssh', '.gnupg'} for value in (source, location[1]) for part in value.split('/'))

def owned_files(request):
    app = request['app']
    expected = request['controlRoot'] + '/deployments/' + app['id']
    if not re.fullmatch('[a-f0-9]{32}', app['id']) or app['directory'] != expected or app['project'] != 'valhalla-app-' + app['id']:
        fail('OWNERSHIP_CHANGED')
    if read_file(expected + '/.valhalla-app-owner', 128).decode() != app['id']:
        fail('OWNERSHIP_CHANGED')
    config_bytes = read_file(expected + '/configuration.json')
    compose_bytes = read_file(expected + '/compose.json')
    fingerprint = hashlib.sha256(config_bytes + bytes([0]) + compose_bytes + bytes([0]) + request['targetIdentity'].encode()).hexdigest()
    return json.loads(config_bytes), fingerprint

def previous_worker_inactive(directory):
    recorded = read_file(directory + '/identity', 512).decode().splitlines()
    if len(recorded) != 3:
        fail('RETRY_UNAVAILABLE')
    pid, boot, started = recorded
    if not re.fullmatch('[1-9][0-9]*', pid) or not re.fullmatch('[a-fA-F0-9-]{36}', boot) or not started.isdigit():
        fail('RETRY_UNAVAILABLE')
    current_boot = read_file('/proc/sys/kernel/random/boot_id', 128).decode().strip()
    if current_boot != boot:
        return True
    try:
        process = read_file('/proc/' + pid + '/stat', 8192).decode()
    except FileNotFoundError:
        return True
    # comm may itself contain spaces or parentheses. Fields after its final
    # close paren start with state (field 3); starttime is field 22.
    fields = process.rsplit(') ', 1)[-1].split()
    if len(fields) < 20 or not fields[19].isdigit():
        fail('RETRY_UNAVAILABLE')
    return fields[0] == 'Z' or fields[19] != started

def guard_retry(request):
    if not request.get('cleanupOnly'):
        return
    app = request['app']
    previous = request['previousTask']
    expected = request['controlRoot'] + '/tasks/' + request['previousTaskId']
    if previous != expected or not re.fullmatch('[a-f0-9]{32}', request['previousTaskId']):
        fail('SELECTION_INVALID')
    if os.path.lexists(app['directory'] + '/deployment.json'):
        fail('OWNERSHIP_CHANGED')
    state = read_file(previous + '/state', 512).decode().splitlines()
    if read_file(previous + '/uninstall-complete', 8) != b'1' or not state or state[0] not in ('failed', 'checking', 'applying') or not previous_worker_inactive(previous):
        fail('RETRY_UNAVAILABLE')
    old_request = json.loads(read_file(previous + '/cleanup-request.json'))
    if old_request['app'] != app or old_request['targetIdentity'] != request['targetIdentity']:
        fail('TARGET_CHANGED')
    allowed = set(old_request['selectedKeys'])
    try:
        previous_results = json.loads(read_file(previous + '/cleanup.json'))
        allowed -= {item['key'] for item in previous_results['results'] if item['outcome'] in ('removed', 'alreadyAbsent')}
    except FileNotFoundError:
        pass
    if any(key not in allowed for key in request.get('selectedKeys', [])):
        fail('SELECTION_INVALID')
    return [item for item in old_request['snapshot']['targets'] if item['key'] in allowed]

def other_managed_references(request):
    root = request['controlRoot'] + '/deployments'
    fd = open_dir(root)
    try:
        entries = os.listdir(fd)
        if len(entries) > 1000:
            fail('INSPECTION_INCOMPLETE')
        refs = []
        for name in entries:
            remaining()
            if name == request['app']['id']:
                continue
            if not re.fullmatch('[a-f0-9]{32}', name):
                fail('INSPECTION_INCOMPLETE')
            directory = root + '/' + name
            if read_file(directory + '/.valhalla-app-owner', 128).decode() != name:
                fail('INSPECTION_INCOMPLETE')
            if not os.path.lexists(directory + '/deployment.json') and os.path.lexists(directory + '/deployment.uninstalled.json'):
                archived = json.loads(read_file(directory + '/deployment.uninstalled.json'))
                if archived.get('id') != name or archived.get('project') != 'valhalla-app-' + name or archived.get('directory') != directory:
                    fail('INSPECTION_INCOMPLETE')
                # The worker archives this record only after Compose down.
                # Real remaining container references are inspected separately.
                continue
            config = json.loads(read_file(directory + '/configuration.json'))
            for source in [config.get('dataRoot')] + [entry.get('source') for entry in config.get('mounts', [])]:
                normalized(source)
                refs.extend([source, os.path.realpath(source)])
        return refs
    finally:
        os.close(fd)

def containers():
    ids = command(['docker', 'ps', '-aq', '--no-trunc']).splitlines()
    if len(ids) > 2000 or any(not re.fullmatch('[a-f0-9]{64}', value) for value in ids):
        fail('INSPECTION_INCOMPLETE')
    result = []
    for start in range(0, len(ids), 32):
        remaining()
        chunk = ids[start:start + 32]
        rows = json.loads(command(['docker', 'inspect'] + chunk))
        if not isinstance(rows, list) or len(rows) != len(chunk) or any(not isinstance(row, dict) for row in rows) or {row.get('Id') for row in rows} != set(chunk):
            fail('INSPECTION_INCOMPLETE')
        for row in rows:
            mounts = row.get('Mounts')
            if not isinstance(mounts, list):
                fail('INSPECTION_INCOMPLETE')
            for mount in mounts:
                if not isinstance(mount, dict) or not isinstance(mount.get('Type'), str) or not mount['Type'] or not isinstance(mount.get('Destination'), str) or not mount['Destination'].startswith('/'):
                    fail('INSPECTION_INCOMPLETE')
                if mount['Type'] == 'bind' and (not isinstance(mount.get('Source'), str) or not mount['Source'].startswith('/')):
                    fail('INSPECTION_INCOMPLETE')
        result.extend(rows)
    return result

def inspect(request):
    remaining()
    capabilities()
    guard_target(request)
    previous_targets = guard_retry(request) or []
    accounts = pwd.getpwall()
    if len(accounts) > 10000:
        fail('INSPECTION_INCOMPLETE')
    advanced = request.get('allowAdvancedCleanup') is True
    request['_homes'] = [account.pw_dir for account in accounts if account.pw_dir.startswith('/') and (not advanced or account.pw_uid >= 1000 or account.pw_name == 'root')]
    config, fingerprint = owned_files(request)
    app = request['app']
    compose = json.loads(command(['docker', 'compose', '--project-name', app['project'], '-f', app['directory'] + '/compose.json', 'config', '--format', 'json']))
    configured = {(item['service'], item['target']): item['source'] for item in config.get('mounts', [])}
    targets = {}
    def add(kind, source, reference, readonly, reason=None):
        key = hashlib.sha256((kind + chr(0) + source).encode()).hexdigest()
        value = targets.setdefault(key, {'key': key, 'source': source, 'serviceTargets': [], 'readOnly': True, 'isDataRoot': False, 'risks': [], 'blockedReason': reason, 'identity': {}, 'references': [], '_kind': kind})
        if reference and reference not in value['serviceTargets']:
            value['serviceTargets'].append(reference)
        value['readOnly'] = value['readOnly'] and readonly
        if reason:
            value['blockedReason'] = reason
        return value
    data_root = normalized(config['dataRoot'])
    root_target = add('bind', data_root, None, True)
    root_target['isDataRoot'] = True
    volume_references = {}
    for service, definition in compose.get('services', {}).items():
        for volume in definition.get('volumes', []):
            if not isinstance(volume, dict):
                fail('INSPECTION_INCOMPLETE')
            kind, source, target = volume.get('type'), volume.get('source', ''), volume.get('target', '')
            if kind != 'bind':
                definition = compose.get('volumes', {}).get(source, {})
                volume_name = definition.get('name') or source
                add(kind or 'volume', volume_name or service + ':' + target, service + ':' + target, volume.get('read_only', False), None if advanced and kind == 'volume' and volume_name else 'APP_CENTER_CLEANUP_VOLUME_PROTECTED')
                continue
            value = add('bind', source, service + ':' + target, volume.get('read_only', False))
            if configured.get((service, target)) != source:
                value['blockedReason'] = 'APP_CENTER_CLEANUP_CONFIG_CHANGED'
    if not root_target['serviceTargets']:
        root_target['readOnly'] = False
    refs = other_managed_references(request)
    for container in containers():
        labels = (container.get('Config') or {}).get('Labels') or {}
        own = labels.get('com.valhalla.app.instance') == app['id'] and labels.get('com.docker.compose.project') == app['project']
        service = labels.get('com.docker.compose.service', '')
        for mount in container.get('Mounts', []):
            source, target, kind = mount.get('Source', ''), mount.get('Destination', ''), mount.get('Type')
            if own:
                expected_source = configured.get((service, target))
                if expected_source is not None and (kind != 'bind' or expected_source != source):
                    fail('CONFIG_CHANGED')
                if kind != 'bind':
                    add(kind or 'volume', mount.get('Name') or source or service + ':' + target, service + ':' + target, not mount.get('RW', True), None if advanced and kind == 'volume' and mount.get('Name') else 'APP_CENTER_CLEANUP_VOLUME_PROTECTED')
                elif configured.get((service, target)) != source:
                    fail('CONFIG_CHANGED')
            elif kind == 'bind':
                normalized(source)
                refs.extend([source, os.path.realpath(source)])
            elif kind == 'volume' and mount.get('Name'):
                volume_references.setdefault(mount['Name'], []).append('container:' + container['Id'])
    if advanced:
        authorized_targets = [old for old in request.get('snapshot', {}).get('targets', []) if old['key'] in request.get('selectedKeys', [])]
        for old in authorized_targets + previous_targets:
            if old.get('kind') == 'volume':
                value = add('volume', old['source'], None, old.get('readOnly', False))
                for reference in old.get('serviceTargets', []):
                    if reference not in value['serviceTargets']:
                        value['serviceTargets'].append(reference)
    records = mount_records()
    mounted = [item[2] for item in records]
    reference_locations = [filesystem_path(reference, records) for reference in refs]
    exact, trees = protected_paths(request)
    # Protected paths can themselves be bind aliases. Compare both sides in
    # the same filesystem coordinates so a backing path cannot bypass the
    # control-root, home, runtime or Docker data protections.
    protection = ([filesystem_path(os.path.realpath(path), records) for path in exact], [filesystem_path(os.path.realpath(path), records) for path in trees])
    system_locations = [filesystem_path(os.path.realpath(root), records) for root in system_paths()]
    volume_names = set()
    if advanced and any(value['_kind'] == 'volume' and not value['blockedReason'] for value in targets.values()):
        names = command(['docker', 'volume', 'ls', '--format', '{{.Name}}']).splitlines()
        if len(names) > 20000:
            fail('INSPECTION_INCOMPLETE')
        volume_names = set(names)
    if len(targets) > 128:
        fail('INSPECTION_INCOMPLETE')
    for value in targets.values():
        remaining()
        if value['_kind'] == 'volume' and advanced and not value['blockedReason']:
            name = value['source']
            if not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9_.-]{0,254}', name):
                value['blockedReason'] = 'APP_CENTER_CLEANUP_VOLUME_PROTECTED'
                continue
            if name not in volume_names:
                value['blockedReason'] = 'APP_CENTER_CLEANUP_ALREADY_ABSENT'
                continue
            try:
                rows = json.loads(command(['docker', 'volume', 'inspect', name]))
                if not isinstance(rows, list) or len(rows) != 1 or not isinstance(rows[0], dict) or rows[0].get('Name') != name:
                    fail('INSPECTION_INCOMPLETE')
                info = rows[0]
                stable = {key: info.get(key) for key in ('Name', 'Driver', 'Mountpoint', 'Scope', 'CreatedAt', 'Labels', 'Options')}
                value['identity'] = {'fingerprint': hashlib.sha256(json.dumps(stable, sort_keys=True).encode()).hexdigest()}
                value['risks'] = ['volume']
                if (info.get('Labels') or {}).get('com.docker.compose.project') != app['project']:
                    value['risks'].append('external')
                value['references'] = sorted(set(volume_references.get(name, [])))
                if value['references']:
                    value['risks'].append('shared')
            except (Blocked, ValueError, OSError) as error:
                value['blockedReason'] = str(error) if isinstance(error, Blocked) else 'APP_CENTER_CLEANUP_INSPECTION_INCOMPLETE'
            value['serviceTargets'].sort()
            continue
        if value['_kind'] != 'bind':
            continue
        source = value['source']
        try:
            normalized(source)
            location = filesystem_path(source, records)
            if protected(source, request, location, protection):
                fail('CRITICAL_PATH' if advanced else 'PROTECTED_PATH')
            if os.path.realpath(source) != source:
                fail('SYMLINK_PATH')
            if any(within(source, mount) for mount in mounted):
                fail('MOUNTPOINT_PROTECTED')
            aliases = guard_mount_aliases(source, records, allow_shared=advanced)
            shared = [other for other, other_location in zip(refs, reference_locations) if overlaps(source, other) or location[0] == other_location[0] and overlaps(location[1], other_location[1])]
            if shared and not advanced:
                fail('SHARED_PATH')
            value['references'] = sorted(set(aliases + ['bind:' + other for other in shared]))
            if not value['isDataRoot'] and any(other['_kind'] == 'bind' and other['source'] != source and within(source, other['source']) for other in targets.values()):
                fail('OVERLAPPING_MOUNT')
            fd = open_dir(source)
            try:
                value['identity'] = identity(fd)
                try:
                    empty_directory(fd, mount_id(fd), [0], time.monotonic() + remaining(), source, value['identity'], [], readonly=True)
                except (FileNotFoundError, NotADirectoryError):
                    # A disappearing descendant is not proof the selected root
                    # is absent, nor permission to skip the remaining preflight.
                    fail('PATH_CHANGED')
            finally:
                os.close(fd)
            # Existing installations have no durable data ownership marker.
            # Acknowledgement authorizes this exact task, never future cleanup.
            value['risks'] = ['legacy']
            if value['references']:
                value['risks'].append('shared')
            if advanced and any(location[0] == root[0] and within(root[1], location[1]) for root in system_locations):
                value['risks'].append('system')
            if not within(data_root, source):
                value['risks'].append('external')
            if value['readOnly'] or re.search(r'(^|/)(media|photos|pictures|videos|music|movies)(/|$)', source, re.I):
                value['risks'].append('media')
        except FileNotFoundError:
            value['blockedReason'] = 'APP_CENTER_CLEANUP_ALREADY_ABSENT'
        except NotADirectoryError:
            value['blockedReason'] = 'APP_CENTER_CLEANUP_NOT_DIRECTORY'
        except PermissionError:
            value['blockedReason'] = 'APP_CENTER_CLEANUP_PERMISSION_DENIED'
        except (OSError, Blocked) as error:
            value['blockedReason'] = str(error) if isinstance(error, Blocked) else 'APP_CENTER_CLEANUP_INSPECTION_INCOMPLETE'
        value['serviceTargets'].sort()
    # Whole-root approval includes every contained mount's risks; a protected
    # child cannot become deletable merely by selecting its parent instead.
    for value in targets.values():
        if value is root_target or value['_kind'] != 'bind' or not within(data_root, value['source']):
            continue
        for risk in value['risks']:
            if risk not in root_target['risks']:
                root_target['risks'].append(risk)
        if (value['readOnly'] or re.search(r'(^|/)(media|photos|pictures|videos|music|movies)(/|$)', value['source'], re.I)) and 'media' not in root_target['risks']:
            root_target['risks'].append('media')
        reason = value.get('blockedReason')
        if reason and reason not in ('APP_CENTER_CLEANUP_ALREADY_ABSENT', 'APP_CENTER_CLEANUP_OVERLAPPING_MOUNT') and not root_target['blockedReason']:
            root_target['blockedReason'] = reason
    for value in targets.values():
        value['kind'] = value.pop('_kind')
    return {'fingerprint': fingerprint, 'targets': sorted(targets.values(), key=lambda item: (not item['isDataRoot'], item['source'], item['key']))}

def selected_snapshot(request, current, allow_absent=False, keys=None):
    expected = request['snapshot']
    if current['fingerprint'] != expected['fingerprint']:
        fail('CONFIG_CHANGED')
    now = {item['key']: item for item in current['targets']}
    before = {item['key']: item for item in expected['targets']}
    selected = request['selectedKeys'] if keys is None else keys
    if not selected or len(selected) != len(set(selected)):
        fail('SELECTION_INVALID')
    for key in selected:
        old, value = before.get(key), now.get(key)
        if not old or not value or old.get('blockedReason') or not old.get('identity'):
            fail('SELECTION_INVALID')
        if old.get('risks') and key not in request.get('acknowledgedRiskKeys', []):
            fail('ACKNOWLEDGEMENT_REQUIRED')
        if value.get('blockedReason') == 'APP_CENTER_CLEANUP_ALREADY_ABSENT' and allow_absent:
            continue
        if value.get('blockedReason') or value['source'] != old['source'] or value['identity'] != old['identity'] or value['serviceTargets'] != old['serviceTargets'] or value.get('kind', 'bind') != old.get('kind', 'bind') or value.get('references', []) != old.get('references', []) or set(value.get('risks', [])) - set(old.get('risks', [])):
            fail('PATH_CHANGED')
    return before, now

def store_results(request, results):
    directory = request['taskDirectory']
    fd = open_dir(directory)
    name = '.cleanup-' + str(os.getpid()) + '-' + str(time.monotonic_ns())
    output = None
    try:
        output = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=fd)
        raw = json.dumps({'uninstallCompleted': True, 'results': results}, separators=(',', ':')).encode()
        if len(raw) > 1024 * 1024:
            fail('RESULT_TOO_LARGE')
        with os.fdopen(output, 'wb', closefd=False) as stream:
            stream.write(raw)
            stream.flush()
            os.fsync(output)
        if os.geteuid() == 0:
            os.fchown(output, request['uid'], request['gid'])
        os.close(output)
        output = None
        os.rename(name, 'cleanup.json', src_dir_fd=fd, dst_dir_fd=fd)
        os.fsync(fd)
    finally:
        if output is not None:
            os.close(output)
        os.close(fd)

def assert_attached(source, expected, links):
    # An open fd alone is not proof that a directory is still inside the
    # selected tree: another process can rename it while we hold that fd.
    # Reopen the selected lexical path without following any symlink, then
    # verify every live parent/name -> child association before each mutation.
    root = open_dir(source)
    try:
        if identity(root) != expected:
            fail('PATH_CHANGED')
    finally:
        os.close(root)
    for parent, name, child in links:
        linked = os.stat(name, dir_fd=parent, follow_symlinks=False)
        opened = os.fstat(child)
        if not stat.S_ISDIR(linked.st_mode) or (linked.st_dev, linked.st_ino) != (opened.st_dev, opened.st_ino) or mount_id(child) != expected['mountId']:
            fail('PATH_CHANGED')

def empty_directory(fd, root_mount, budget, deadline, source, expected, links, readonly=False):
    assert_attached(source, expected, links)
    if mount_id(fd) != root_mount:
        fail('MOUNTPOINT_PROTECTED')
    if len(links) > 128:
        fail('CLEANUP_LIMIT')
    with os.scandir(fd) as entries:
        names = []
        for entry in entries:
            remaining()
            if entry.name in {'.ssh', '.gnupg'}:
                fail('PROTECTED_PATH')
            names.append(entry.name)
            if len(names) > 1000000 - budget[0]:
                fail('CLEANUP_LIMIT')
    for name in names:
        remaining()
        if name in {'.ssh', '.gnupg'}:
            fail('PROTECTED_PATH')
        budget[0] += 1
        if budget[0] > 1000000 or time.monotonic() > deadline:
            fail('CLEANUP_LIMIT')
        assert_attached(source, expected, links)
        info = os.stat(name, dir_fd=fd, follow_symlinks=False)
        if stat.S_ISDIR(info.st_mode):
            child = os.open(name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC, dir_fd=fd)
            try:
                opened = os.fstat(child)
                if (opened.st_dev, opened.st_ino) != (info.st_dev, info.st_ino):
                    fail('PATH_CHANGED')
                child_links = links + [(fd, name, child)]
                empty_directory(child, root_mount, budget, deadline, source, expected, child_links, readonly=readonly)
                assert_attached(source, expected, child_links)
                current = os.stat(name, dir_fd=fd, follow_symlinks=False)
                if (current.st_dev, current.st_ino) != (opened.st_dev, opened.st_ino):
                    fail('PATH_CHANGED')
                if not readonly:
                    os.rmdir(name, dir_fd=fd)
            finally:
                os.close(child)
        else:
            # unlink never follows a symlink. No file outside this open directory
            # is traversed, even if the entry is concurrently replaced by a link.
            assert_attached(source, expected, links)
            if not readonly:
                os.unlink(name, dir_fd=fd)

def remove_directory(value, allow_advanced=False):
    source = value['source']
    parent = open_dir(os.path.dirname(source))
    fd = None
    try:
        name = os.path.basename(source)
        try:
            fd = os.open(name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC, dir_fd=parent)
        except FileNotFoundError:
            return 'alreadyAbsent'
        if identity(fd) != value['identity']:
            fail('PATH_CHANGED')
        records = mount_records()
        if mount_id(parent) != mount_id(fd) or any(within(source, point) for _, _, point in records):
            fail('MOUNTPOINT_PROTECTED')
        aliases = guard_mount_aliases(source, records, allow_shared=allow_advanced and 'shared' in value.get('risks', []))
        if not set(aliases).issubset(set(value.get('references', []))):
            fail('PATH_CHANGED')
        links = [(parent, name, fd)]
        empty_directory(fd, mount_id(fd), [0], time.monotonic() + remaining(), source, value['identity'], links, readonly=True)
        aliases = guard_mount_aliases(source, mount_records(), allow_shared=allow_advanced and 'shared' in value.get('risks', []))
        if not set(aliases).issubset(set(value.get('references', []))):
            fail('PATH_CHANGED')
        empty_directory(fd, mount_id(fd), [0], time.monotonic() + 600, source, value['identity'], links)
        assert_attached(source, value['identity'], links)
        current = os.stat(name, dir_fd=parent, follow_symlinks=False)
        original = os.fstat(fd)
        if (current.st_dev, current.st_ino) != (original.st_dev, original.st_ino):
            fail('PATH_CHANGED')
        os.rmdir(name, dir_fd=parent)
        return 'removed'
    finally:
        if fd is not None:
            os.close(fd)
        os.close(parent)

def cleanup(request):
    expected = {item['key']: item for item in request['snapshot']['targets']}
    selected = request['selectedKeys']
    # The request retains the full authorization, but remove overlapping trees
    # only once. A retry is restricted to the resulting top-level targets.
    selected = [key for key in selected if not any(other != key and expected[other].get('kind', 'bind') == 'bind' and expected[key].get('kind', 'bind') == 'bind' and within(expected[other]['source'], expected[key]['source']) for other in selected)]
    results = [{'key': key, 'source': expected[key]['source'], 'outcome': 'pending'} for key in selected]
    store_results(request, results)
    failed = False
    for result in results:
        deleting = False
        try:
            # Fresh complete sharing/mount/target inspection before EACH target.
            current = inspect(request)
            selected_snapshot(request, current, allow_absent=True, keys=[result['key']])
            guard_target(request)
            deleting = True
            value = expected[result['key']]
            if any(item['key'] == result['key'] and item.get('blockedReason') == 'APP_CENTER_CLEANUP_ALREADY_ABSENT' for item in current['targets']):
                result['outcome'] = 'alreadyAbsent'
            elif value.get('kind', 'bind') == 'volume':
                if request.get('allowAdvancedCleanup') is not True or 'volume' not in value.get('risks', []):
                    fail('SELECTION_INVALID')
                command(['docker', 'volume', 'rm', '--', value['source']], failure_code='VOLUME_DELETE_FAILED')
                result['outcome'] = 'removed'
            else:
                result['outcome'] = remove_directory(value, allow_advanced=request.get('allowAdvancedCleanup') is True)
        except Blocked as error:
            result.update(outcome='failed' if deleting else 'retained', reasonCode=str(error))
            failed = True
        except (OSError, ValueError, subprocess.SubprocessError, RecursionError):
            # Only remove_directory's absent-root check proves idempotent
            # success. Missing ownership files or disappearing children must
            # not be reported as a completely removed target.
            result.update(outcome='failed' if deleting else 'retained', reasonCode='APP_CENTER_CLEANUP_DELETE_FAILED' if deleting else 'APP_CENTER_CLEANUP_INSPECTION_INCOMPLETE')
            failed = True
        print(result['outcome'] + ': ' + result['source'], flush=True)
        store_results(request, results)
    return 76 if failed else 0

def main():
    global DEADLINE
    mode = sys.argv[1]
    # One bounded budget includes inventory, every selected target and actual
    # traversal. Partial results still persist after expiration; no blind kill
    # or rollback promise, and no unbounded Docker loop holding server.lock.
    DEADLINE = time.monotonic() + (600 if mode == 'cleanup' else 85)
    request = json.loads(read_file(sys.argv[2])) if mode in ('validate', 'cleanup') else json.loads(base64.b64decode(sys.argv[2], validate=True))
    if mode == 'inspect':
        try:
            value = inspect(request)
        except (Blocked, OSError, ValueError, subprocess.SubprocessError) as error:
            value = {'fingerprint': '', 'targets': [], 'inspectionError': str(error) if isinstance(error, Blocked) else 'APP_CENTER_CLEANUP_INSPECTION_INCOMPLETE'}
        print(json.dumps(value, separators=(',', ':')))
        return 0
    if mode == 'validate':
        selected_snapshot(request, inspect(request))
        return 0
    if mode == 'cleanup':
        return cleanup(request)
    fail('SELECTION_INVALID')

try:
    sys.exit(main())
except (Blocked, OSError, ValueError, subprocess.SubprocessError) as error:
    print(str(error) if isinstance(error, Blocked) else 'APP_CENTER_CLEANUP_INSPECTION_INCOMPLETE', file=sys.stderr)
    sys.exit(75)
''';
}
