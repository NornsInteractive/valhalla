/// Runs inside the selected container; file contents travel over stdin, not argv.
const acpWorkspaceEditorScript = r'''
import hashlib, json, os, stat, sys, tempfile
LIMIT = 1024 * 1024

def snapshot(path):
    target = os.path.realpath(path)
    before = os.stat(target)
    if not stat.S_ISREG(before.st_mode) or before.st_size > LIMIT:
        raise ValueError('ACP_FILE_NOT_EDITABLE')
    with open(target, 'rb') as stream:
        data = stream.read(LIMIT + 1)
        after = os.fstat(stream.fileno())
    revision = lambda s: [s.st_dev, s.st_ino, s.st_size, s.st_mtime_ns, s.st_ctime_ns, s.st_mode, s.st_uid, s.st_gid]
    if len(data) > LIMIT or revision(before) != revision(after) or revision(after) != revision(os.stat(target)) or target != os.path.realpath(path):
        raise ValueError('ACP_FILE_EDIT_CONFLICT')
    if b'\0' in data:
        raise ValueError('ACP_FILE_NOT_EDITABLE')
    content = data.decode('utf-8', errors='strict')
    return dict(path=path, targetPath=target, content=content,
        revision=json.dumps([revision(after), hashlib.sha256(data).hexdigest()], separators=(',', ':')))

def main():
    request = json.loads(sys.stdin.buffer.read(4 * LIMIT + 65536))
    path = request['path']
    if not path.startswith('/') or any(c in path for c in '\0\r\n'):
        raise ValueError('ACP_FILE_PATH_INVALID')
    current = snapshot(path)
    if request['operation'] == 'read':
        return current
    if request['operation'] != 'save':
        raise ValueError('ACP_FILE_OPERATION_INVALID')
    if current['revision'] != request['revision'] or current['targetPath'] != request['targetPath']:
        raise ValueError('ACP_FILE_EDIT_CONFLICT')
    data = request['content'].encode('utf-8')
    if len(data) > LIMIT or b'\0' in data:
        raise ValueError('ACP_FILE_NOT_EDITABLE')
    original = os.stat(current['targetPath'])
    fd, temp = tempfile.mkstemp(prefix='.valhalla-edit-', dir=os.path.dirname(current['targetPath']))
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
            os.fchown(stream.fileno(), original.st_uid, original.st_gid)
            os.fchmod(stream.fileno(), stat.S_IMODE(original.st_mode))
        checked = snapshot(path)
        if checked['revision'] != current['revision'] or checked['targetPath'] != current['targetPath']:
            raise ValueError('ACP_FILE_EDIT_CONFLICT')
        # shortcut: external writers can race the final check/rename; locking requires cooperation.
        os.replace(temp, current['targetPath'])
        return dict(saved=True)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)

try:
    print(json.dumps(main(), ensure_ascii=True))
except Exception as error:
    code = str(error) if isinstance(error, ValueError) and str(error).startswith('ACP_') else 'ACP_FILE_EDITOR_UNAVAILABLE'
    print(json.dumps(dict(error=code)))
    sys.exit(1)
''';
