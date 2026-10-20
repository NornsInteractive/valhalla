"""One-release staging and audit; never publishes or changes application code."""
from pathlib import Path, PurePosixPath
import datetime
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import zipfile

REPO = Path(__file__).resolve().parents[1]
WORK = Path(os.environ['VALHALLA_RELEASE_WORK']).resolve()
VERSION = os.environ['VALHALLA_RELEASE_VERSION']
BUILD = int(os.environ['VALHALLA_RELEASE_BUILD'])
STAGE = WORK / 'artifacts'
LOGS = WORK / 'logs'
CERT = '73dc6d178bbd7aba1ef85dd18b266ad491ae000c08915b9ee62cfc8383a92c7d'
sys.path.insert(0, str(REPO / 'tool'))
from generate_update_manifest import android_tool

def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def run(name, args):
    completed = subprocess.run(args, cwd=REPO, capture_output=True, text=True,
                               env={**os.environ, 'LC_ALL': 'C'})
    (LOGS / name).write_text(completed.stdout + completed.stderr)
    if completed.returncode:
        raise RuntimeError(f'{name}: exit {completed.returncode}; inspect local log')
    return completed.stdout + completed.stderr

def fresh(source, step):
    start = datetime.datetime.fromisoformat((LOGS / f'{step}.start').read_text().strip().replace('Z', '+00:00'))
    assert source.stat().st_mtime >= start.timestamp(), f'Stale output: {source}'

def copy(source, name):
    target = STAGE / name
    shutil.copy2(source, target)
    assert digest(source) == digest(target)
    return target

for step in ['analyze', 'manifest-tests', 'terminal-tests', 'apk', 'aab', 'linux', 'source-unchanged', 'clean-tree']:
    assert (LOGS / f'{step}.exit').read_text().strip() == '0', step
assert 'No issues found' in (LOGS / 'analyze.log').read_text()
events = [json.loads(line) for line in (LOGS / 'terminal-tests.log').read_text().splitlines() if line.startswith('{')]
done = [e for e in events if e.get('type') == 'testDone' and not e.get('hidden')]
assert len(done) > 0 and all(e.get('result') == 'success' and not e.get('skipped') for e in done)
assert any(e.get('type') == 'done' and e.get('success') is True for e in events)
assert '\nOK' in (LOGS / 'manifest-tests.log').read_text()
assert not STAGE.exists(), 'Stage must be new; do not overwrite frozen assets'
STAGE.mkdir()
source_commit = (WORK / 'source-commit.txt').read_text().strip()
assert re.fullmatch('[0-9a-f]{40}', source_commit)
assert source_commit == subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=REPO, text=True).strip()
identities = []
for abi, code in [('arm64-v8a', 2000 + BUILD), ('armeabi-v7a', 1000 + BUILD), ('x86_64', 4000 + BUILD)]:
    original = REPO / f'build/app/outputs/flutter-apk/app-{abi}-release.apk'
    fresh(original, 'apk')
    apk = copy(original, f'valhalla-v{VERSION}-android-{abi}-signed-{BUILD}.apk')
    signature = run(f'{abi}-signature.log', [android_tool('apksigner'), 'verify', '--verbose', '--print-certs', str(apk)])
    certs = {value.lower() for value in re.findall(r'certificate SHA-256 digest: ([0-9a-fA-F]{64})', signature)}
    assert certs == {CERT}, f'Certificate mismatch: {abi}'
    badging = run(f'{abi}-badging.log', [android_tool('aapt'), 'dump', 'badging', str(apk)])
    package = re.search(r"package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'", badging)
    assert package and (package[1], int(package[2]), package[3]) == ('com.norns.valhalla', code, VERSION)
    assert re.search(r"native-code:\s*'" + re.escape(abi) + r"'\s*(?:\n|$)", badging)
    identities.append(dict(abi=abi, code=code, size=apk.stat().st_size, sha256=digest(apk)))
original_aab = REPO / 'build/app/outputs/bundle/release/app-release.aab'
fresh(original_aab, 'aab')
aab = copy(original_aab, f'valhalla-v{VERSION}-android-signed.aab')
run('aab-signature.log', ['jarsigner', '-J-Duser.language=en', '-verify', '-verbose', '-certs', str(aab)])
aab_cert = run('aab-certificate.log', ['keytool', '-J-Duser.language=en', '-printcert', '-jarfile', str(aab)])
assert {value.replace(':', '').lower() for value in re.findall(r'SHA256:\s*([0-9A-Fa-f:]{64,95})', aab_cert)} == {CERT}
password = (Path(os.environ.get('VALHALLA_SIGN_DIR', '/home/dev/.local/share/valhalla-signing')) / 'android-release.password').read_bytes().strip()
private_payload = re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----\r?\n(?:[A-Za-z0-9+/=]{20,}\r?\n){2,}')
def audit_payload(name, data):
    base = PurePosixPath(name).name.lower()
    assert not base.endswith(('.p12', '.jks', '.keystore'))
    assert base not in {'android-release.password', 'antigravity-oauth-token', 'auth.json', '.env'}
    assert password not in data and not private_payload.search(data), f'Sensitive payload in {name}'
for archive in list(STAGE.glob('*.apk')) + list(STAGE.glob('*.aab')):
    with zipfile.ZipFile(archive) as zipped:
        names = zipped.namelist()
        assert len(names) == len(set(names)), f'Duplicate ZIP entries: {archive.name}'
        assert zipped.testzip() is None
        for entry in zipped.infolist():
            path = PurePosixPath(entry.filename)
            assert not path.is_absolute() and '..' not in path.parts
            if not entry.is_dir():
                audit_payload(entry.filename, zipped.read(entry))
    print(f'ZIP, signature, identity and payload OK: {archive.name}', flush=True)

runtime = REPO / 'build/linux/x64/release/bundle'
linux_version = runtime / 'data/flutter_assets/version.json'
fresh(linux_version, 'linux')
version_data = json.loads(linux_version.read_text())
assert version_data['version'] == VERSION and version_data['build_number'] == str(BUILD)
fresh(runtime / 'lib/libapp.so', 'linux')
print(f'Linux version.json freshly regenerated as {VERSION}+{BUILD}; product AOT is fresh.', flush=True)
linux_stage = WORK / 'linux-stage/valhalla'
shutil.copytree(runtime, linux_stage, symlinks=True)
kernel_blob = linux_stage / 'data/flutter_assets/kernel_blob.bin'
if kernel_blob.exists():
    evidence = WORK / 'excluded-stale-kernel_blob.bin'
    assert not evidence.exists()
    shutil.move(kernel_blob, evidence)
license_dir = linux_stage / 'licenses'
license_dir.mkdir(exist_ok=True)
for relative in ['LICENSE', 'NOTICE', 'packages/xterm/LICENSE', 'packages/xterm/NOTICE',
                 'packages/dartssh2/LICENSE', 'packages/valhalla_smb/NOTICE']:
    shutil.copy2(REPO / relative, license_dir / relative.replace('/', '-'))
runtime_count = 0
for original in runtime.rglob('*'):
    if original.is_file() and original.relative_to(runtime).as_posix() != 'data/flutter_assets/kernel_blob.bin':
        staged = linux_stage / original.relative_to(runtime)
        assert digest(original) == digest(staged)
        runtime_count += 1
for file in linux_stage.rglob('*'):
    if file.is_symlink():
        assert file.resolve().is_relative_to(linux_stage.resolve())
    if file.is_file():
        audit_payload(file.relative_to(linux_stage).as_posix(), file.read_bytes())
assert os.access(linux_stage / 'valhalla', os.X_OK)
elf = run('linux-elf.log', ['file', str(linux_stage / 'valhalla')])
assert 'ELF 64-bit' in elf and 'x86-64' in elf
for index, binary in enumerate([linux_stage / 'valhalla', *sorted((linux_stage / 'lib').glob('*.so*'))]):
    assert os.access(binary, os.R_OK)
    output = run(f'linux-ldd-{index}.log', ['ldd', str(binary)])
    assert 'not found' not in output, binary.name
flutter_version = run('flutter-version.log', ['flutter', '--version'])
tool_revision = subprocess.check_output(['git', '-C', '/opt/flutter', 'rev-parse', 'HEAD'], text=True).strip()
lines = [
    'Norns Interactive', f'Valhalla {VERSION}+{BUILD} — new version release',
    f'Source commit: {source_commit}', f'Tag: v{VERSION} (new tag, exact source commit)',
    f'Tag target source commit: {source_commit}',
    'New Release and tag; existing versions remain unmodified. Source archives and binaries refer to the same source commit.',
    f'Android applicationId: com.norns.valhalla', f'Android certificate SHA256: {CERT}',
    f'Flutter SDK git: {tool_revision}', flutter_version.strip(),
    'APK identities: ' + json.dumps(identities),
    f'AAB SHA256: {digest(aab)}',
    f'Validation: {len(done)} focused Flutter tests passed; update manifest tests passed; flutter analyze no issues.',
    'Jarsigner warnings: self-signed/untrusted chain, no timestamp and any ZIP manifest/POSIX warnings are retained in local logs.',
    'Changes: see release-notes.md and tagged source.',
    'Existing preferences and modifier chords preserved; backward compatibility maintained.',
    f'Native codes: arm64={2000+BUILD}, armv7={1000+BUILD}, x86_64={4000+BUILD}; catalog={2000+BUILD}.',
    'Not tested this release: ADB device installation, ARM physical devices, Linux GUI, live production agent prompts.',
    f'Linux runtime files compared against build output: {runtime_count}; stale debug kernel_blob excluded from staged copy only.',
    'Linux fresh version.json checked against release version and AOT timestamps verified against current build start.',
]
for step in ['apk', 'aab', 'linux']:
    lines.append(f'{step}: {(LOGS / (step + ".command")).read_text().strip()}; start={(LOGS / (step + ".start")).read_text().strip()}; end={(LOGS / (step + ".end")).read_text().strip()}; exit=0')
info = '\n'.join(lines) + '\n'
for platform in ['android', 'linux-x64']:
    (STAGE / f'valhalla-v{VERSION}-{platform}-BUILD-INFO.txt').write_text(info)
(linux_stage / 'BUILD-INFO.txt').write_text(info)
tar_path = STAGE / f'valhalla-v{VERSION}-linux-x64.tar.gz'
with tarfile.open(tar_path, 'w:gz') as archive:
    archive.add(linux_stage, arcname='valhalla', recursive=True)
with tarfile.open(tar_path) as archive:
    for member in archive:
        path = PurePosixPath(member.name)
        assert not path.is_absolute() and '..' not in path.parts
        assert member.isfile() or member.isdir() or member.issym() or member.islnk()
        if member.issym() or member.islnk():
            assert not PurePosixPath(member.linkname).is_absolute() and '..' not in PurePosixPath(member.linkname).parts
run('manifest-generation.log', ['python3', 'tool/generate_update_manifest.py', str(STAGE),
                              '--pubspec', 'pubspec.yaml', '--source-commit', source_commit])
primary = sorted(file for file in STAGE.iterdir() if not file.name.endswith('.sha256'))
assert len(primary) == 8
checksums = []
for file in primary:
    line = f'{digest(file)}  {file.name}\n'
    checksums.append(line)
    (STAGE / f'{file.name}.sha256').write_text(line)
(STAGE / 'SHA256SUMS.txt').write_text(''.join(checksums))
assets = sorted(STAGE.iterdir())
assert len(assets) == 17
frozen = [{'name': file.name, 'size': file.stat().st_size, 'sha256': digest(file)} for file in assets]
(WORK / 'frozen-assets.json').write_text(json.dumps(frozen, indent=2) + '\n')
(WORK / 'audit.json').write_text(json.dumps(dict(source=source_commit, apk=identities, aab_sha256=digest(aab),
    runtime_files=runtime_count, frozen_files=len(frozen), certificate=CERT,
    completed_utc=datetime.datetime.now(datetime.timezone.utc).isoformat()), indent=2) + '\n')
run('checksum-verification.log',
    ['bash', '-c', 'cd "$1" && sha256sum -c SHA256SUMS.txt', 'valhalla-check', str(STAGE)])
print(json.dumps(dict(artifacts=17, runtime_files=runtime_count, source=source_commit, result='verified and frozen')))

