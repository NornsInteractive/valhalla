#!/usr/bin/env python3
"""Local Android/Linux release. New versions only; resumable, never clobbers assets."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
REPOSITORY = 'NornsInteractive/valhalla'
APP = 'com.norns.valhalla'
MCP = 'https://ygg.norns.cc.cd/api/mcp'


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def next_version(value):
    match = re.fullmatch(r'(\d+)\.(\d+)\.(\d+)\+(\d+)', value)
    if not match or not 0 < int(match[4]) < 999:
        raise ValueError('Expected stable version+build, build must remain below 1000')
    return f'{match[1]}.{match[2]}.{int(match[3])+1}+{int(match[4])+1}'


def normalize(value):
    if isinstance(value, dict):
        return {k: normalize(v) for k, v in value.items() if k != 'download_count'}
    if isinstance(value, list):
        return [normalize(v) for v in value]
    return value


def virtual_placeholder(package):
    return (package['id'] == 'pkg_def_' + package['version_id']
            and not any(package.get(k) for k in ['file_key', 'external_url', 'file_sha256', 'file_size', 'download_count']))


class Release:
    def __init__(self, work):
        self.work = work
        self.state_file = work / 'state.json'
        self.state = json.loads(self.state_file.read_text())
        self.version, build = self.state['version'].split('+')
        self.build = int(build)
        self.tag = 'v' + self.version
        self.logs = work / 'logs'
        self.logs.mkdir(exist_ok=True)

    def save(self):
        temp = self.state_file.with_suffix('.tmp')
        temp.write_text(json.dumps(self.state, indent=2) + '\n')
        temp.replace(self.state_file)

    def run(self, name, command, env=None):
        print(name, flush=True)
        (self.logs / (name + '.start')).write_text(time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()))
        (self.logs / (name + '.command')).write_text(' '.join(command))
        with (self.logs / (name + '.log')).open('w') as log:
            result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, env=env)
        (self.logs / (name + '.end')).write_text(time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()))
        (self.logs / (name + '.exit')).write_text(str(result.returncode) + '\n')
        if result.returncode:
            raise RuntimeError(f'{name} failed ({result.returncode}); see {self.logs / (name + ".log")}')

    def gh(self, path, method='GET', data=None):
        command = ['gh', 'api', '-X', method, '-H', 'Cache-Control: no-cache', path]
        if data is not None:
            command += ['--input', '-']
        result = subprocess.run(command, input=json.dumps(data) if data is not None else None,
                                capture_output=True, text=True, check=True)
        return json.loads(result.stdout)

    def mcp(self, name, args):
        headers = {'Content-Type': 'application/json', 'Accept': 'application/json, text/event-stream'}
        if os.environ.get('YGG_TOKEN'):
            headers['Authorization'] = 'Bearer ' + os.environ['YGG_TOKEN']
        body = dict(jsonrpc='2.0', id=time.time_ns(), method='tools/call', params=dict(name=name, arguments=args))
        command = ['curl', '--fail-with-body', '--silent', '--show-error', '--max-time', '90', MCP]
        # Pass optional credentials through stdin config, never process argv/logs.
        config = ''.join('header = ' + json.dumps(k + ': ' + v) + '\n' for k, v in headers.items())
        payload = self.work / 'mcp-request.json'
        payload.write_text(json.dumps(body))
        command += ['--config', '-', '--data-binary', '@' + str(payload)]
        response = subprocess.run(command, input=config, capture_output=True, text=True)
        if response.returncode:
            raise RuntimeError('MCP HTTP transport failed; stop and inspect access, do not retry writes blindly')
        raw = response.stdout
        raw = json.loads(raw) if raw.lstrip().startswith('{') else next(
            json.loads(line[5:].strip()) for line in raw.splitlines() if line.startswith('data: {'))
        evidence = self.work / f'mcp-{time.time_ns()}-{name}.json'
        evidence.write_text(json.dumps(raw, ensure_ascii=False, indent=2))
        if raw.get('error') or raw['result'].get('isError'):
            raise RuntimeError(f'MCP error; see {evidence}')
        result = json.loads(next(c['text'] for c in raw['result']['content'] if c['type'] == 'text'))
        if result.get('error') or result.get('success') is False:
            raise RuntimeError(f'MCP business error; see {evidence}')
        return result

    def details(self):
        return self.mcp('ygg_get_app_details', {'app_id': APP})

    def versions(self):
        return [v for v in self.details()['versions'] if v['version_name'] == self.state['version']]

    def validate_source(self):
        actual = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
        if subprocess.check_output(['git', 'status', '--porcelain'], text=True):
            raise RuntimeError('Release source changed or worktree dirty; do not resume with different source')
        if actual != self.state.get('source'):
            subprocess.run(['git', 'merge-base', '--is-ancestor', self.state['source'], actual], check=True)
            changed = subprocess.check_output(['git', 'diff', '--name-only', self.state['source'], actual], text=True).splitlines()
            if not self.state.get('built') or any(not p.startswith(('tool/', 'docs/', 'agent-workflow/')) for p in changed):
                raise RuntimeError('Cannot resume with changed product source')

    def build_packages(self):
        self.validate_source()
        # Preserve failed-stage evidence; never overwrite a frozen or published stage.
        for directory in ['artifacts', 'linux-stage']:
            path = self.work / directory
            if path.exists():
                path.rename(self.work / f'{directory}-failed-{time.time_ns()}')
        env = dict(os.environ)
        env.update(VALHALLA_RELEASE_WORK=str(self.work), VALHALLA_RELEASE_VERSION=self.version,
                   VALHALLA_RELEASE_BUILD=str(self.build))
        signing = Path(env.get('VALHALLA_SIGN_DIR', '/home/dev/.local/share/valhalla-signing'))
        password = (signing / 'android-release.password').read_text().strip()
        if not password:
            raise RuntimeError('Empty signing password')
        env.update(VALHALLA_ANDROID_KEYSTORE=str(signing / 'android-release.p12'),
                   VALHALLA_ANDROID_STORE_PASSWORD=password, VALHALLA_ANDROID_KEY_PASSWORD=password,
                   VALHALLA_ANDROID_KEY_ALIAS='valhalla')
        env.pop('VALHALLA_CI_UNSIGNED', None)
        gradle = self.work / 'gradle-home'
        gradle.mkdir(exist_ok=True)
        for name in ['caches', 'wrapper']:
            target = Path('/home/dev/.gradle') / name
            if not (gradle / name).exists():
                (gradle / name).symlink_to(target, target_is_directory=True)
        env['GRADLE_USER_HOME'] = str(gradle)
        files = subprocess.check_output(['git', 'ls-files', '-z', 'lib', 'android', 'linux', 'assets', 'packages', 'pubspec.yaml', 'pubspec.lock']).decode().split('\0')
        snapshot = {p: sha(ROOT / p) for p in files if p}
        (self.work / 'source-commit.txt').write_text(self.state['source'] + '\n')
        (self.work / 'source-before.sha256').write_text(''.join(f'{h}  {p}\n' for p, h in snapshot.items()))
        self.run('generate', ['flutter', 'gen-l10n'])
        self.run('analyze', ['flutter', 'analyze', '--no-pub'])
        self.run('manifest-tests', ['python3', '-m', 'unittest', 'discover', '-s', 'tool', '-p', 'test_generate_update_manifest.py'])
        self.run('release-tests', ['python3', '-m', 'unittest', 'discover', '-s', 'tool', '-p', 'test_release.py'])
        tests = sorted(str(p.relative_to(ROOT)) for p in (ROOT / 'test').rglob('*terminal*test.dart'))
        tests += sorted(str(p.relative_to(ROOT)) for p in (ROOT / 'test').rglob('*tmux*test.dart'))
        # Include the shared-canvas and input regressions, not unrelated app feature suites.
        tests += ['test/features/shared_terminal_canvas_test.dart', 'test/core/l10n_key_parity_test.dart']
        self.run('terminal-tests', ['flutter', 'test', '--no-pub', '--machine', *sorted(set(tests))])
        self.run('apk', ['flutter', 'build', 'apk', '--release', '--split-per-abi', '--target', 'lib/main.dart'], env)
        self.run('aab', ['flutter', 'build', 'appbundle', '--release', '--target', 'lib/main.dart'], env)
        self.run('linux', ['flutter', 'build', 'linux', '--release', '--target', 'lib/main.dart'])
        self.run('source-unchanged', ['sha256sum', '-c', str(self.work / 'source-before.sha256')])
        self.run('clean-tree', ['git', 'diff', '--exit-code'])
        self.run('freeze', ['python3', 'tool/release_freeze.py'], env)
        self.state['built'] = True
        self.save()

    def github(self):
        frozen = json.loads((self.work / 'frozen-assets.json').read_text())
        for item in frozen:
            file = self.work / 'artifacts' / item['name']
            if file.stat().st_size != item['size'] or sha(file) != item['sha256']:
                raise RuntimeError('Frozen asset changed')
        self.run('push', ['git', 'push', 'origin', 'HEAD:main'])
        head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
        if self.gh(f'repos/{REPOSITORY}/commits/main')['sha'] != head:
            raise RuntimeError('Remote main mismatch')
        releases = self.gh(f'repos/{REPOSITORY}/releases?per_page=100&_fresh={time.time_ns()}')
        matches = [r for r in releases if r['tag_name'] == self.tag]
        if len(matches) > 1:
            raise RuntimeError('Duplicate GitHub release')
        if not matches:
            if self.state.get('github_create_attempted'):
                raise RuntimeError('Uncertain creation; inspect remote before clearing attempted marker')
            self.state['github_create_attempted'] = True
            self.save()
            release = self.gh(f'repos/{REPOSITORY}/releases', 'POST', dict(
                tag_name=self.tag, target_commitish=self.state['source'], draft=True,
                name=f'Valhalla {self.tag} — Norns Interactive', body=self.state['notes']))
        else:
            release = matches[0]
        if release['target_commitish'] != self.state['source']:
            raise RuntimeError('Existing release source mismatch')
        rid = release['id']
        for item in sorted(frozen, key=lambda a: a['name'] == 'update.json'):
            matches = [a for a in release['assets'] if a['name'] == item['name']]
            if matches:
                if matches[0]['digest'] != 'sha256:' + item['sha256'] or matches[0]['size'] != item['size']:
                    raise RuntimeError('Existing asset mismatch; never overwrite')
            elif release['draft']:
                self.run('upload-' + item['name'], ['gh', 'release', 'upload', self.tag, '--repo', REPOSITORY, str(self.work / 'artifacts' / item['name'])])
            else:
                raise RuntimeError('Published release missing asset')
        current = self.gh(f'repos/{REPOSITORY}/releases/{rid}')
        expected = {a['name']: (a['size'], 'sha256:' + a['sha256']) for a in frozen}
        actual = {a['name']: (a['size'], a['digest']) for a in current['assets'] if a['state'] == 'uploaded'}
        if actual != expected:
            raise RuntimeError('GitHub asset audit failed')
        if current['draft']:
            self.gh(f'repos/{REPOSITORY}/releases/{rid}', 'PATCH', {'draft': False, 'make_latest': 'true'})
        self.state['github'] = True
        self.save()

    def distribution(self):
        manifest = json.loads((self.work / 'artifacts/update.json').read_text())
        versions = self.versions()
        if not versions:
            if self.state.get('ygg_create_attempted'):
                raise RuntimeError('Uncertain MCP create; inspect remote, do not retry blindly')
            baseline = self.details()
            (self.work / 'distribution-before.json').write_text(json.dumps(baseline, indent=2))
            if any(v['version_code'] >= 2000 + self.build for v in baseline['versions']):
                raise RuntimeError('Distribution version code is not increasing')
            self.state['ygg_create_attempted'] = True
            self.save()
            self.mcp('ygg_publish_version', dict(app_id=APP, version_code=2000+self.build,
                version_name=self.state['version'], channel='staging-' + self.tag, use_proxy=True,
                platform='android', arch='arm64-v8a', min_version_code=0, is_force_update=False,
                changelog=self.state['notes']))
            versions = self.versions()
        if len(versions) != 1:
            raise RuntimeError('Distribution version not unique')
        version = versions[0]
        self.state['ygg_id'] = version['id']
        self.save()
        if not self.state.get('ygg'):
            self.mcp('ygg_update_version', {'version_id': version['id'], 'is_published': False})
        for artifact in manifest['artifacts']:
            version = self.versions()[0]
            arch = 'x86_64' if artifact['platform'] == 'linux' else artifact['architecture']
            expected = dict(platform=artifact['platform'], arch=arch, file_name=artifact['name'],
                file_size=artifact['size'], file_sha256=artifact['sha256'], use_proxy=True,
                external_url=f'https://github.com/{REPOSITORY}/releases/download/{self.tag}/{artifact["name"]}')
            matches = [p for p in version['packages'] if p['platform'] == expected['platform'] and p['arch'] == arch and not virtual_placeholder(p)]
            for package in matches:
                if all(package.get(k) == v for k, v in expected.items()):
                    continue
                # Only the brand-new empty record created by this batch; never files/history.
                if (self.state.get('ygg_create_attempted') and not version['is_published']
                    and not any(package.get(k) for k in ['file_key', 'external_url', 'file_sha256', 'file_size', 'download_count'])):
                    (self.work / f'empty-placeholder-{package["id"]}.json').write_text(json.dumps(package, indent=2))
                    self.mcp('ygg_delete_version_package', {'package_id': package['id']})
                else:
                    raise RuntimeError('Existing distribution package mismatch; no deletion permitted')
            remaining = [p for p in self.versions()[0]['packages'] if p['platform'] == expected['platform'] and p['arch'] == arch and not virtual_placeholder(p)]
            if not remaining:
                self.mcp('ygg_add_version_package', dict(version_id=version['id'], **expected))
        version = self.versions()[0]
        if len(version['packages']) != 4:
            raise RuntimeError('Expected exactly four distribution packages')
        arm = next(p for p in version['packages'] if p['platform'] == 'android' and p['arch'] == 'arm64-v8a')
        self.mcp('ygg_update_version', dict(version_id=version['id'], channel='default', is_published=True, use_proxy=True,
            external_url=arm['external_url'], file_name=arm['file_name']))
        self.state['ygg'] = True
        self.save()

    def verify(self):
        import urllib.parse
        version = self.versions()[0]
        frozen = {a['name']: a for a in json.loads((self.work / 'frozen-assets.json').read_text())}
        for package in version['packages']:
            query = urllib.parse.urlencode(dict(app_id=APP, version_code=0, channel='default', platform=package['platform'], arch=package['arch']))
            response = subprocess.run(['curl', '--fail', '--silent', '--show-error', '--max-time', '60',
                'https://ygg.norns.cc.cd/api/v1/app/latest?' + query], capture_output=True, text=True, check=True)
            data = json.loads(response.stdout)['data']
            if data['latest_version_name'] != self.state['version']:
                raise RuntimeError('Public latest mismatch')
            matches = [p for p in data['packages'] if p['id'] == package['id']]
            if (len(matches) != 1 or not matches[0]['use_proxy']
                or matches[0]['platform'] != package['platform'] or matches[0]['arch'] != package['arch']):
                raise RuntimeError('Public package mismatch')
            url = matches[0]['download_url']
            if urllib.parse.urlsplit(url).hostname != 'ygg.norns.cc.cd':
                raise RuntimeError('Download does not use distribution proxy')
            target = self.work / ('download-' + package['file_name'])
            self.run('download-' + package['arch'] + '-' + package['platform'], ['curl', '--fail', '--silent', '--show-error', '--max-time', '300', '-o', str(target), url])
            expected = frozen[package['file_name']]
            if target.stat().st_size != expected['size'] or sha(target) != expected['sha256']:
                raise RuntimeError('Proxy full-file hash mismatch')
            for start in [0, (expected['size']//2//65536)*65536]:
                part = self.work / f'range-{package["id"]}-{start}'
                header = part.with_suffix('.headers')
                self.run('range-' + package['id'] + '-' + str(start), ['curl', '--fail', '--silent', '--show-error', '--max-time', '90', '-H', f'Range: bytes={start}-{start+65535}', '-D', str(header), '-o', str(part), url])
                if f'content-range: bytes {start}-{start+65535}/{expected["size"]}' not in header.read_text().lower():
                    raise RuntimeError('Range unsupported')
                with target.open('rb') as stream:
                    stream.seek(start)
                    if part.read_bytes() != stream.read(65536):
                        raise RuntimeError('Range bytes mismatch')
        baseline = json.loads((self.work / 'distribution-before.json').read_text())
        if normalize(baseline['versions']) != normalize([v for v in self.details()['versions'] if v['id'] != version['id']]):
            raise RuntimeError('Historical distribution versions changed')
        tag = subprocess.check_output(['git', 'ls-remote', 'origin', 'refs/tags/' + self.tag], text=True).split()[0]
        if tag != self.state['source']:
            raise RuntimeError('Git tag mismatch')
        if self.gh(f'repos/{REPOSITORY}/actions/runs?head_sha={self.state["source"]}')['total_count']:
            raise RuntimeError('Unexpected Actions run')
        self.state['verified'] = True
        self.save()
        print(f'Published and verified: https://github.com/{REPOSITORY}/releases/tag/{self.tag}\nhttps://ygg.norns.cc.cd/d/{APP}', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--notes-file', type=Path)
    parser.add_argument('--files', nargs='+', help='Explicit current-batch source files to commit; never git add .')
    parser.add_argument('--resume', type=Path, help='Existing release evidence directory')
    parser.add_argument('--build-only', action='store_true', help='Build and freeze locally; publish later with --resume')
    args = parser.parse_args()
    os.chdir(ROOT)
    lock_path = ROOT / 'build/local-packages/release.lock'
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        if args.resume:
            work = args.resume.resolve()
        else:
            if not args.files or not args.notes_file:
                parser.error('New release requires --files and --notes-file')
            if subprocess.check_output(['git', 'diff', '--cached', '--name-only'], text=True).strip():
                raise RuntimeError('Index already contains changes; preserve and resolve before release')
            for file in args.files:
                path = (ROOT / file).resolve()
                if not path.is_file() or not path.is_relative_to(ROOT) or any(x in path.parts for x in ['.git', 'build']) or path.suffix in ['.p12', '.jks', '.keystore']:
                    raise RuntimeError('Unsafe commit path')
            pubspec = ROOT / 'pubspec.yaml'
            text = pubspec.read_text()
            match = re.search(r'^version:\s*(\S+)\s*$', text, re.M)
            version = next_version(match[1])
            work = ROOT / 'build/local-packages' / ('v' + version.split('+')[0] + '-release')
            work.mkdir(exist_ok=False)
            notes = args.notes_file.read_text()
            state = dict(version=version, notes=notes, files=args.files)
            (work / 'state.json').write_text(json.dumps(state, indent=2))
            pubspec.write_text(text[:match.start(1)] + version + text[match.end(1):])
            subprocess.run(['git', 'add', '--', 'pubspec.yaml', *args.files], check=True)
            # Refuse unrelated modifications, including untracked source, instead of silently publishing them.
            if subprocess.check_output(['git', 'diff', '--name-only'], text=True).strip() or subprocess.check_output(['git', 'ls-files', '--others', '--exclude-standard'], text=True).strip():
                raise RuntimeError('Unselected changes remain; inspect index and resume preparation manually')
            subprocess.run(['git', 'commit', '-m', f'release: {version} [skip ci]'], check=True)
            state['source'] = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
            (work / 'state.json').write_text(json.dumps(state, indent=2))
        release = Release(work)
        release.validate_source()
        if not release.state.get('built'):
            release.build_packages()
        if args.build_only:
            print(f'Local build complete; no publication performed. Resume after acceptance: {work}', flush=True)
            return
        release.github()
        release.distribution()
        release.verify()


if __name__ == '__main__':
    main()
