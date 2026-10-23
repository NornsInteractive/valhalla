#!/usr/bin/env python3
"""Isolated ACP force-stop test; always restore the normal, same-signed app."""
import hashlib
import json
from pathlib import Path
import re
import sqlite3
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/acp-device-validation'
APP = 'com.norns.valhalla'
ADB = ['adb', '-s', '127.0.0.1:14251']
FIXTURE = Path('/tmp/vacp-device')
KEY = hashlib.sha256(b'valhalla-device-probe-v1').hexdigest()
RESULT = {'passed': False, 'restored': False, 'errors': []}


def run(args, *, check=True, timeout=60):
    value = subprocess.run(args, cwd=ROOT, capture_output=True, timeout=timeout)
    with (OUT / 'adb-commands.log').open('ab') as log:
        log.write((' '.join(args) + '\n').encode())
        log.write(value.stdout + value.stderr + b'\n')
    if check and value.returncode:
        raise RuntimeError(f'{args[0]} failed ({value.returncode}): '
                           f'{value.stderr.decode(errors="replace")}')
    return value.stdout.decode(errors='replace')


def adb(*args, **kwargs):
    return run(ADB + list(args), **kwargs)


def snapshot():
    path = FIXTURE / '.local/share/valhalla/acp-runtime-v1' / KEY / 'journal.sqlite3'
    with sqlite3.connect(f'file:{path}?mode=ro', uri=True) as db:
        rows = db.execute('SELECT seq,payload FROM events ORDER BY seq').fetchall()
        meta = {key: json.loads(value) for key, value in db.execute('SELECT key,value FROM meta')}
    chunks = []
    for seq, raw in rows:
        update = json.loads(raw).get('frame', {}).get('params', {}).get('update', {})
        if update.get('sessionUpdate') == 'agent_message_chunk':
            chunks.append(update['content']['text'])
    return {'chunks': chunks, 'events': len(rows), 'state': meta.get('state')}


def wait_output(pid, label, predicate, timeout=60):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        log = adb('logcat', '-d', '--pid=' + pid, '-v', 'brief', '-s', 'flutter:I')
        (OUT / f'{label}.logcat').write_text(log)
        values = []
        for line in log.splitlines():
            if 'ACP_DEVICE_PROBE ' in line:
                try:
                    values.append(json.loads(line.split('ACP_DEVICE_PROBE ', 1)[1]))
                except json.JSONDecodeError:
                    pass
        errors = [value['error'] for value in values if 'error' in value]
        if errors:
            raise RuntimeError('Probe: ' + str(errors))
        if predicate(values):
            return values
        time.sleep(.3)
    raise TimeoutError(f'{label}: no expected output from app PID {pid}')


def launch():
    adb('shell', 'am', 'start', '-n', APP + '/.MainActivity')
    for _ in range(30):
        pid = adb('shell', 'pidof', '-s', APP, check=False).strip()
        if pid:
            return pid
        time.sleep(.2)
    raise RuntimeError('App process did not start')


def restore():
    result = subprocess.run(
        [sys.executable, 'tool/acp_device_build.py', '--target', 'app',
         '--version', '1.0.16', '--code', '4017'], cwd=ROOT)
    if result.returncode:
        raise RuntimeError('Normal app restore build failed')
    adb('install', '-r', str(OUT / 'app.apk'), timeout=120)
    adb('shell', 'am', 'force-stop', APP)
    pid = launch()
    time.sleep(3)
    foreground = adb('shell', 'dumpsys', 'activity', 'activities')
    (OUT / 'normal-app-activity.txt').write_text(foreground)
    log = adb('logcat', '-d', '--pid=' + pid, '-v', 'brief')
    (OUT / 'normal-app.logcat').write_text(log)
    (OUT / 'normal-app.png').write_bytes(subprocess.check_output(ADB + ['exec-out', 'screencap', '-p']))
    if not adb('shell', 'pidof', '-s', APP, check=False).strip():
        raise RuntimeError('Restored app exited')
    if 'FATAL EXCEPTION' in log or 'ACP_DEVICE_PROBE' in log:
        raise RuntimeError('Restored app failed startup or still runs probe')
    RESULT['restored'] = True
    adb('reverse', '--remove', 'tcp:54323', check=False)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    activity = adb('shell', 'dumpsys', 'activity', 'activities')
    active = re.search(r'(?:topResumedActivity|mResumedActivity).*?\bu\d+\s+([^/\s]+)/', activity)
    allowed = {APP, 'com.google.android.apps.nexuslauncher', 'com.android.launcher3'}
    if active and active[1] not in allowed:
        raise RuntimeError('Competing foreground app: ' + active[1])
    try:
        if (FIXTURE / 'prompts.count').exists():
            raise RuntimeError('Fixture already used; preserve evidence instead of replaying prompt')
        adb('shell', 'am', 'force-stop', APP)
        adb('reverse', 'tcp:54323', 'tcp:54323')
        adb('install', '-r', str(OUT / 'probe.apk'), timeout=120)
        first_pid = launch()
        wait_output(first_pid, 'before-stop', lambda values: any(
            len(re.findall(r'chunk-\d+', value.get('text', ''))) >= 5 for value in values))
        before = snapshot()
        adb('shell', 'am', 'force-stop', APP)
        if adb('shell', 'pidof', '-s', APP, check=False).strip():
            raise RuntimeError('App process survived force-stop')
        time.sleep(5)
        after = snapshot()
        RESULT.update(before_stop=before, while_stopped=after)
        if len(after['chunks']) <= len(before['chunks']):
            raise RuntimeError('Server output did not advance while app stopped')
        second_pid = launch()
        values = wait_output(second_pid, 'after-restart', lambda values: any(
            value.get('passed') is True for value in values), timeout=75)
        text = next(value['text'] for value in reversed(values) if 'text' in value)
        chunks = re.findall(r'chunk-(\d+)', text)
        if chunks != list(map(str, range(30))):
            raise RuntimeError('Missing, duplicate or unordered replay')
        prompts = (FIXTURE / 'prompts.count').read_text().splitlines()
        if len(prompts) != 1:
            raise RuntimeError('Prompt was repeated')
        RESULT.update(passed=True, prompt_count=len(prompts), chunks=len(chunks),
                      first_pid=first_pid, second_pid=second_pid, final=snapshot())
    except Exception as error:
        RESULT['errors'].append(str(error))
    finally:
        try:
            restore()
        except Exception as error:
            RESULT['errors'].append(str(error))
        (OUT / 'device-result.json').write_text(json.dumps(RESULT, indent=2))
        print(json.dumps(RESULT), flush=True)
    if not RESULT['passed'] or not RESULT['restored']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
