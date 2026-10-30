#!/usr/bin/env python3
"""Register already-built, verified Windows artifacts into a local release workdir."""
import argparse
import json
import pathlib
import shutil
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_PRIOR_COUNT = 17


def sha256_file(path):
    import hashlib
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def is_regular_nonsymlink(path):
    return path.is_file() and not path.is_symlink()


def _normalize_zip_entry(name):
    """Normalize a ZIP/MSIX member name and reject unsafe paths.

    Windows-generated archives may legitimately use backslash separators, so we
    normalize them to forward slashes for all safety checks and required-entry
    lookups. Rejects NUL/control characters, absolute paths (POSIX root, drive
    letters, UNC), Windows reserved device names, and ``..`` traversal. Returns
    the normalized name, or raises RuntimeError.
    """
    if not isinstance(name, str) or '\x00' in name:
        raise RuntimeError(f'Invalid archive entry name: {name!r}')
    if any(ord(c) < 0x20 for c in name):
        raise RuntimeError(f'Control character in archive entry: {name!r}')
    normalized = name.replace('\\', '/')
    wp = pathlib.PureWindowsPath(normalized)
    if wp.is_absolute():
        raise RuntimeError(f'Absolute path in archive: {name!r}')
    if wp.drive:
        raise RuntimeError(f'Drive path in archive: {name!r}')
    if wp.is_reserved():
        raise RuntimeError(f'Reserved device name in archive: {name!r}')
    if '..' in normalized.split('/'):
        raise RuntimeError(f'Path traversal in archive: {name!r}')
    return normalized


def is_exe_unsigned_from_pe(path):
    """Independently verify a PE/EXE file has no signing certificate via the Security Data Directory.

    Returns True if the file appears unsigned (security directory size == 0),
    False if signed (security directory size > 0), and raises RuntimeError if the file
    is not a valid PE executable or is not PE32+ x64.

    Genuine PE32+ layout: DOS header (e_lfanew @ offset 60) -> "PE\\0\\0" ->
    20-byte COFF IMAGE_FILE_HEADER -> optional header. The optional header begins
    at pe_offset + 24. Within it:
      * NumberOfRvaAndSizes is at optional-header offset 108 (4 bytes).
      * The data directories begin at a FIXED optional-header offset 112 — NOT at
        opt_start + SizeOfOptionalHeader. SizeOfOptionalHeader merely declares how
        many bytes the optional header occupies (normally 240) and includes the
        data directories; it does not point to their start.
      * The Security (certificate table) directory is IMAGE_DIRECTORY_ENTRY index 4,
        i.e. optional-header offset 112 + 4*8 = 144. Each entry is 8 bytes:
        VirtualAddress (file offset of the certificate table) then Size.
    """
    import struct
    data = path.read_bytes()
    if len(data) < 64:
        raise RuntimeError(f'File too small to be a PE: {path.name}')
    # MZ signature check
    if data[0:2] != b'MZ':
        raise RuntimeError(f'Not a PE file: {path.name}')
    # Offset to PE header (e_lfanew) at bytes 60-63
    pe_offset = struct.unpack('<I', data[60:64])[0]
    if pe_offset < 4 or pe_offset + 4 > len(data):
        raise RuntimeError(f'Invalid PE offset: {path.name}')
    # PE signature "PE\0\0"
    if data[pe_offset:pe_offset + 4] != b'PE\x00\x00':
        raise RuntimeError(f'Missing PE signature: {path.name}')
    # COFF IMAGE_FILE_HEADER starts right after the 4-byte PE signature.
    # Machine is at COFF+0, i.e. pe_offset + 4.
    machine = struct.unpack('<H', data[pe_offset + 4:pe_offset + 6])[0]
    if machine != 0x8664:  # IMAGE_FILE_MACHINE_AMD64
        raise RuntimeError(f'Unsupported PE machine: 0x{machine:04x}, expected x64 PE32+')
    # SizeOfOptionalHeader is a 2-byte field at COFF+16, i.e. pe_offset + 20.
    size_of_opt = struct.unpack('<H', data[pe_offset + 20:pe_offset + 22])[0]
    # Optional header starts at pe_offset + 24 (PE signature + 20-byte COFF header).
    opt_start = pe_offset + 24
    # The declared optional header must fit inside the file.
    if opt_start + size_of_opt > len(data):
        raise RuntimeError(f'Truncated optional header: {path.name}')
    # The optional header must be large enough to actually contain the data
    # directories we are about to read (Security directory ends at offset 152).
    if size_of_opt < 152:
        raise RuntimeError(f'Optional header too small: {size_of_opt}')
    # PE32+ magic 0x20B at optional-header offset 0.
    magic = struct.unpack('<H', data[opt_start:opt_start + 2])[0]
    if magic != 0x20B:
        raise RuntimeError(f'Not a PE32+ image (magic 0x{magic:04x}): {path.name}')
    # NumberOfRvaAndSizes at optional-header offset 108; must include Security (index 4).
    num_rva = struct.unpack('<I', data[opt_start + 108:opt_start + 112])[0]
    if num_rva < 5:
        raise RuntimeError(f'PE32+ data directory count too small: {num_rva}')
    # Data directories begin at the FIXED optional-header offset 112, and the
    # Security directory is index 4, i.e. optional-header offset 112 + 4*8 = 144.
    # (Do NOT use opt_start + size_of_opt here — that is the classic bug.)
    sec_dir_offset = opt_start + 112 + 4 * 8
    if sec_dir_offset + 8 > len(data):
        raise RuntimeError(f'Cannot read PE security directory at {path.name}')
    sec_dir_rva = struct.unpack('<I', data[sec_dir_offset:sec_dir_offset + 4])[0]
    sec_dir_size = struct.unpack('<I', data[sec_dir_offset + 4:sec_dir_offset + 8])[0]
    if sec_dir_rva > 0 or sec_dir_size > 0:
        return False  # signed: certificate table present
    return True  # unsigned (security directory absent or empty)


def find_report(windows_dir):
    candidates = []
    for path in sorted(windows_dir.glob('*.json')):
        try:
            data = json.loads(path.read_text())
        except Exception:
            continue
        if isinstance(data, dict) and any(k in data for k in ('version', 'build', 'buildNumber', 'build_number', 'sourceCommit', 'source_commit', 'artifacts', 'files', 'packages')):
            candidates.append((path, data))
    if len(candidates) != 1:
        raise RuntimeError(f'Expected exactly one trusted delegated report JSON, found {len(candidates)}')
    return candidates[0]


def get_field(data, *names):
    for name in names:
        if isinstance(data, dict) and name in data:
            return data[name]
    return None


def flatten_artifacts(report):
    for key in ('artifacts', 'files', 'packages', 'windows'):
        value = get_field(report, key)
        if isinstance(value, list):
            return value
    return []


def artifact_name(entry):
    return get_field(entry, 'fileName', 'filename', 'file_name', 'name')


def artifact_size(entry):
    return get_field(entry, 'size', 'file_size', 'fileSize')


def artifact_sha(entry):
    return get_field(entry, 'sha256', 'sha256sum', 'file_sha256', 'sha')


def is_unsigned_entry(entry, filename, report):
    for key in ('signed', 'isSigned', 'is_signed'):
        val = get_field(entry, key)
        if val is not None:
            return val is False or str(val).lower() in {'false', 'unsigned', 'no'}
    status = get_field(entry, 'signatureStatus', 'signature_status', 'signature', 'status')
    if status is not None and 'unsigned' in str(status).lower():
        return True
    for key in ('unsigned', 'unsignedArtifacts', 'unsigned_artifacts', 'unsignedFiles'):
        val = get_field(report, key)
        if isinstance(val, list) and filename in val:
            return True
        if isinstance(val, str) and filename in val:
            return True
    global_status = get_field(report, 'signatureStatus', 'signature_status')
    if isinstance(global_status, str) and 'unsigned' in global_status.lower():
        return True
    return False


def find_msix_identity(report):
    for key in ('msixManifest', 'msix_manifest', 'manifest', 'identity', 'msix', 'storeIdentity', 'store_identity'):
        val = get_field(report, key)
        if isinstance(val, dict):
            nested = find_msix_identity(val)
            if nested is not None:
                return nested
            if any(k in val for k in ('Name', 'Publisher', 'PublisherDisplayName', 'DisplayName', 'Version', 'Architecture', 'ProcessorArchitecture')):
                return val
    if isinstance(report, dict):
        for v in report.values():
            if isinstance(v, dict):
                r = find_msix_identity(v)
                if r is not None:
                    return r
            if isinstance(v, list):
                for item in v:
                    if isinstance(item, dict):
                        r = find_msix_identity(item)
                        if r is not None:
                            return r
    return None


def validate_msix_zip(path, expected_identity, expected_version_msix):
    with zipfile.ZipFile(path) as zf:
        if zf.testzip() is not None:
            raise RuntimeError('MSIX zip failed integrity test')
        names = zf.namelist()
        seen = set()
        for name in names:
            norm = _normalize_zip_entry(name)
            if norm in seen:
                raise RuntimeError(f'Duplicate MSIX entry (normalized): {name}')
            seen.add(norm)
            info = zf.getinfo(name)
            mode = (info.external_attr >> 16) & 0xFFFF
            if (mode & 0xF000) == 0xA000:
                raise RuntimeError(f'Symlink in MSIX: {name}')
        if 'AppxManifest.xml' not in seen:
            raise RuntimeError('MSIX missing AppxManifest.xml')
        if 'AppxSignature.p7x' in seen:
            raise RuntimeError('MSIX must be unsigned (AppxSignature.p7x present)')
        manifest_data = zf.read('AppxManifest.xml')
        root_el = ET.fromstring(manifest_data)
        identity_el = None
        for el in root_el.iter():
            if el.tag.split('}')[-1] == 'Identity':
                identity_el = el
                break
        if identity_el is None:
            raise RuntimeError('MSIX manifest missing Identity')
        name = identity_el.get('Name')
        publisher = identity_el.get('Publisher')
        version = identity_el.get('Version')
        arch = identity_el.get('ProcessorArchitecture')
        if name != expected_identity['Name']:
            raise RuntimeError(f'MSIX Name mismatch: {name}')
        if publisher != expected_identity['Publisher']:
            raise RuntimeError(f'MSIX Publisher mismatch: {publisher}')
        if version != expected_version_msix:
            raise RuntimeError(f'MSIX version mismatch: {version}')
        if arch != 'x64':
            raise RuntimeError(f'MSIX architecture mismatch: {arch}')
        pdn_elements = [el for el in root_el.iter() if el.tag.split('}')[-1] == 'PublisherDisplayName']
        if not pdn_elements or pdn_elements[0].text != expected_identity['PublisherDisplayName']:
            raise RuntimeError('MSIX PublisherDisplayName mismatch')
        display_candidates = [el.text for el in root_el.iter() if el.tag.split('}')[-1] == 'DisplayName']
        if expected_identity['DisplayName'] not in display_candidates:
            raise RuntimeError('MSIX DisplayName mismatch')


def validate_zip(path):
    with zipfile.ZipFile(path) as zf:
        if zf.testzip() is not None:
            raise RuntimeError('Windows zip failed integrity test')
        names = zf.namelist()
        seen = set()
        normalized_names = []
        for name in names:
            norm = _normalize_zip_entry(name)
            if norm in seen:
                raise RuntimeError(f'Duplicate zip entry (normalized): {name}')
            seen.add(norm)
            normalized_names.append(norm)
            info = zf.getinfo(name)
            mode = (info.external_attr >> 16) & 0xFFFF
            if (mode & 0xF000) == 0xA000:
                raise RuntimeError(f'Symlink in zip: {name}')
        required = ['valhalla.exe', 'flutter_windows.dll', 'data/icudtl.dat']
        for req in required:
            if req not in seen:
                raise RuntimeError(f'Windows zip missing {req}')
        if not any(n.startswith('data/flutter_assets/') or n == 'data/flutter_assets' for n in normalized_names):
            raise RuntimeError('Windows zip missing data/flutter_assets')


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--release', type=Path, required=True)
    parser.add_argument('--windows-dir', type=Path, required=True)
    args = parser.parse_args(argv)

    work = args.release.resolve()
    windows_dir = args.windows_dir.resolve()
    if not work.is_dir():
        raise RuntimeError('release workdir not found')
    if not windows_dir.is_dir():
        raise RuntimeError('windows-dir not found')

    state_file = work / 'state.json'
    state = json.loads(state_file.read_text())
    version = state['version'].split('+')[0]
    build = int(state['version'].split('+')[1])
    source = state['source']

    if not state.get('built'):
        raise RuntimeError('Release is not built')

    frozen_path = work / 'frozen-assets.json'
    frozen = json.loads(frozen_path.read_text())
    expected_names = {
        f'valhalla-{version}-windows-x64-setup.exe',
        f'valhalla-v{version}-windows-x64.zip',
        f'valhalla-{version}.0-windows-x64-store.msix',
    }

    # Idempotent check: if Windows already registered, verify and return early.
    if state.get('windows_registered'):
        report_path, report = find_report(windows_dir)
        if not expected_names.issubset({a['name'] for a in frozen}):
            raise RuntimeError('Windows registered but missing expected artifact names in frozen')
        if len(frozen) <= EXPECTED_PRIOR_COUNT:
            raise RuntimeError('Windows registered but frozen asset count unchanged; registration incomplete')
        rv = get_field(report, 'version')
        rb = get_field(report, 'build', 'buildNumber', 'build_number', 'buildNo')
        rc = get_field(report, 'sourceCommit', 'source_commit', 'source', 'commit')
        if rv != version or int(rb) != build or rc != source:
            raise RuntimeError('Report provenance mismatch on idempotent check')
        # Verify every registered frozen asset still exists, is regular (no
        # symlink), and matches its recorded size/sha256. Do NOT accept missing
        # or tampered assets just because a prior run set windows_registered.
        artifacts_dir = work / 'artifacts'
        for item in frozen:
            if not isinstance(item, dict) or 'name' not in item or 'size' not in item or 'sha256' not in item:
                raise RuntimeError('Malformed frozen record on idempotent check')
            f = artifacts_dir / item['name']
            if not f.is_file() or f.is_symlink():
                raise RuntimeError(f'Missing/tampered frozen asset on idempotent check: {item["name"]}')
            if f.stat().st_size != item['size'] or sha256_file(f) != item['sha256']:
                raise RuntimeError(f'Frozen asset changed on idempotent check: {item["name"]}')
        for name in expected_names:
            p = windows_dir / name
            if not is_regular_nonsymlink(p):
                raise RuntimeError(f'Missing Windows file on idempotent check: {name}')
        print(f'Windows artifacts already registered for {version}+{build}')
        return

    for key in ('github', 'github_create_attempted', 'ygg', 'ygg_create_attempted', 'verified'):
        if state.get(key):
            raise RuntimeError(f'Release already advanced ({key}); cannot register Windows')

    actual = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    if subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True):
        raise RuntimeError('Working tree dirty')
    if actual != source:
        raise RuntimeError('Source commit mismatch')

    artifacts_dir = work / 'artifacts'
    if len(frozen) != EXPECTED_PRIOR_COUNT:
        raise RuntimeError(f'Expected {EXPECTED_PRIOR_COUNT} frozen assets, found {len(frozen)}')
    for item in frozen:
        f = artifacts_dir / item['name']
        if not f.is_file() or f.is_symlink():
            raise RuntimeError(f'Frozen asset missing: {item["name"]}')
        if f.stat().st_size != item['size'] or sha256_file(f) != item['sha256']:
            raise RuntimeError(f'Frozen asset changed: {item["name"]}')

    report_path, report = find_report(windows_dir)
    rv = get_field(report, 'version')
    rb = get_field(report, 'build', 'buildNumber', 'build_number', 'buildNo')
    rc = get_field(report, 'sourceCommit', 'source_commit', 'source', 'commit')
    if rv != version:
        raise RuntimeError(f'Report version mismatch: {rv} != {version}')
    if int(rb) != build:
        raise RuntimeError(f'Report build mismatch: {rb} != {build}')
    if rc != source:
        raise RuntimeError(f'Report source commit mismatch: {rc} != {source}')

    exe_name = f'valhalla-{version}-windows-x64-setup.exe'
    zip_name = f'valhalla-v{version}-windows-x64.zip'
    msix_name = f'valhalla-{version}.0-windows-x64-store.msix'
    for name in (exe_name, zip_name, msix_name):
        p = windows_dir / name
        if not is_regular_nonsymlink(p) or p.stat().st_size <= 0:
            raise RuntimeError(f'Missing/invalid Windows file: {name}')

    entries = flatten_artifacts(report)
    entry_map = {}
    for e in entries:
        if not isinstance(e, dict):
            continue
        n = artifact_name(e)
        if n:
            entry_map[n] = e

    for name in (exe_name, zip_name, msix_name):
        if name not in entry_map:
            raise RuntimeError(f'Report missing artifact entry: {name}')
        e = entry_map[name]
        if int(artifact_size(e)) != (windows_dir / name).stat().st_size:
            raise RuntimeError(f'Report size mismatch: {name}')
        if str(artifact_sha(e)).lower() != sha256_file(windows_dir / name):
            raise RuntimeError(f'Report sha256 mismatch: {name}')

    # Independent EXE unsigned check via the PE Security Data Directory.
    # The Security directory is read at the fixed optional-header offset 144
    # (NumberOfRvaAndSizes at 108; data directories begin at 112; index 4). This
    # rejects malformed/truncated PE32+ instead of falling back, satisfying the
    # fail-closed signature requirement.
    exe_path = windows_dir / exe_name
    exe_unsigned = is_exe_unsigned_from_pe(exe_path)
    # exe_unsigned is True -> unsigned; False -> signed (error already raised)
    if not exe_unsigned:
        raise RuntimeError('EXE is signed; only unsigned EXE artifacts accepted')
    if not is_unsigned_entry(entry_map[exe_name], exe_name, report):
        raise RuntimeError('Report does not mark EXE as unsigned')
    if not is_unsigned_entry(entry_map[msix_name], msix_name, report):
        raise RuntimeError('Report does not mark MSIX as unsigned')

    identity = {
        'Name': 'Norns.Valhalla-',
        'Publisher': 'CN=257586C2-E7B0-47F3-BAED-A744A66748A1',
        'PublisherDisplayName': 'Norns',
        'DisplayName': 'Valhalla-服务器运维管理工具',
    }
    identity_file = ROOT / 'tool' / 'windows_store_identity.json'
    if identity_file.is_file():
        loaded = json.loads(identity_file.read_text())
        identity = {k: loaded[k] for k in ('Name', 'Publisher', 'PublisherDisplayName', 'DisplayName')}

    rid = find_msix_identity(report)
    if not isinstance(rid, dict):
        raise RuntimeError('Report missing MSIX manifest identity')

    def g(d, *names):
        for n in names:
            if n in d:
                return d[n]
        return None

    if g(rid, 'Name') != identity['Name']:
        raise RuntimeError('Report MSIX Name mismatch')
    if g(rid, 'Publisher') != identity['Publisher']:
        raise RuntimeError('Report MSIX Publisher mismatch')
    if g(rid, 'PublisherDisplayName') != identity['PublisherDisplayName']:
        raise RuntimeError('Report MSIX PublisherDisplayName mismatch')
    if g(rid, 'DisplayName') != identity['DisplayName']:
        raise RuntimeError('Report MSIX DisplayName mismatch')
    report_msix_version = g(rid, 'Version', 'version')
    if report_msix_version != f'{version}.0':
        raise RuntimeError(f'Report MSIX version mismatch: {report_msix_version}')
    report_arch = g(rid, 'Architecture', 'ProcessorArchitecture', 'architecture')
    if report_arch != 'x64':
        raise RuntimeError(f'Report MSIX architecture mismatch: {report_arch}')

    validate_msix_zip(windows_dir / msix_name, identity, f'{version}.0')
    validate_zip(windows_dir / zip_name)

    stage = work / f'.artifacts-stage-{time.time_ns()}'
    stage.mkdir()
    stage_ref = stage
    committed = False
    backup_dir = None
    try:
        for f in artifacts_dir.iterdir():
            target = stage / f.name
            if f.is_dir():
                shutil.copytree(f, target)
            else:
                shutil.copy2(f, target)
        for name in (exe_name, zip_name, msix_name):
            shutil.copy2(windows_dir / name, stage / name)

        update_path = artifacts_dir / 'update.json'
        update = json.loads(update_path.read_text())
        update['artifacts'] = [a for a in update['artifacts'] if not (a.get('platform') == 'windows' and a.get('architecture') == 'x64')]
        zip_record = {
            'name': zip_name,
            'platform': 'windows',
            'architecture': 'x64',
            'size': (stage / zip_name).stat().st_size,
            'sha256': sha256_file(stage / zip_name),
        }
        update['artifacts'].append(zip_record)
        update['sourceCommit'] = source
        update['version'] = version
        update['buildNumber'] = build
        (stage / 'update.json').write_text(json.dumps(update, ensure_ascii=False, indent=2) + '\n')

        primary = sorted(f for f in stage.iterdir() if f.is_file() and not f.name.endswith('.sha256') and f.name != 'SHA256SUMS.txt')
        for f in primary:
            line = f'{sha256_file(f)}  {f.name}\n'
            (stage / f'{f.name}.sha256').write_text(line)
        checksums = ''.join(f'{sha256_file(f)}  {f.name}\n' for f in primary)
        (stage / 'SHA256SUMS.txt').write_text(checksums)

        for line in checksums.splitlines():
            h, n = line.split('  ', 1)
            if sha256_file(stage / n) != h:
                raise RuntimeError('Checksum verification failed')

        for item in frozen:
            if item['name'] in ('SHA256SUMS.txt', 'update.json', 'update.json.sha256'):
                continue
            f = stage / item['name']
            if not f.is_file() or f.stat().st_size != item['size'] or sha256_file(f) != item['sha256']:
                raise RuntimeError(f'Existing asset changed in stage: {item["name"]}')

        new_frozen = [{'name': f.name, 'size': f.stat().st_size, 'sha256': sha256_file(f)} for f in sorted(stage.iterdir()) if f.is_file()]
        if len(new_frozen) <= EXPECTED_PRIOR_COUNT:
            raise RuntimeError('No new assets staged')

        # --- atomic commit with rollback ---
        backup_frozen = work / 'frozen-assets.pre-windows.json'
        backup_state = work / 'state.pre-windows.json'
        backup_frozen.write_text(frozen_path.read_text())
        backup_state.write_text(state_file.read_text())

        backup_dir = work / f'artifacts-pre-windows-{time.time_ns()}'
        try:
            artifacts_dir.rename(backup_dir)
            stage.rename(artifacts_dir)
            (work / 'frozen-assets.json').write_text(json.dumps(new_frozen, indent=2) + '\n')
            state['windows_registered'] = True
            state['windows_files'] = [exe_name, zip_name, msix_name]
            state_file.write_text(json.dumps(state, indent=2) + '\n')
            committed = True
        except Exception as exc:
            # Restore the pre-registration snapshot. If the new artifacts dir was
            # already put in place, remove it before renaming the backup back.
            if backup_dir.exists():
                if artifacts_dir.exists():
                    shutil.rmtree(artifacts_dir, ignore_errors=True)
                backup_dir.rename(artifacts_dir)
            (work / 'frozen-assets.json').write_text(backup_frozen.read_text())
            (work / 'state.json').write_text(backup_state.read_text())
            for stale in (backup_frozen, backup_state):
                try:
                    stale.unlink()
                except FileNotFoundError:
                    pass
            raise RuntimeError(f'Windows registration failed and rolled back: {exc}') from exc

        print(f'Registered Windows artifacts for {version}+{build}: {len(new_frozen)} frozen assets')
    finally:
        if stage_ref is not None and stage_ref.exists():
            shutil.rmtree(stage_ref, ignore_errors=True)
        if committed and backup_dir is not None:
            shutil.rmtree(backup_dir, ignore_errors=True)
            for stale in (backup_frozen, backup_state):
                try:
                    stale.unlink()
                except FileNotFoundError:
                    pass


if __name__ == '__main__':
    main()
