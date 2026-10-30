"""End-to-end tests for register_windows_release.py using synthetic artifacts.

Hard constraints honoured by this suite:
  * no real tmux / sockets / sessions,
  * no git mutation (only the two read-only git probes are mocked),
  * no network, no real release state — everything lives in a TemporaryDirectory.

Every artifact, report, ZIP, PE and MSIX below is synthesized on the fly.
"""
import contextlib
import hashlib
import io
import json
import struct
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import register_windows_release as rwr

COMMIT = 'a' * 40
VERSION = '1.0.24'
BUILD = 1025
IDENTITY = {
    'Name': 'Norns.Valhalla-',
    'Publisher': 'CN=257586C2-E7B0-47F3-BAED-A744A66748A1',
    'PublisherDisplayName': 'Norns',
    'DisplayName': 'Valhalla-服务器运维管理工具',
}


def sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()


def sha256_path(path):
    return sha256_bytes(Path(path).read_bytes())


def build_pe32plus(signed=False, machine=0x8664, magic=0x20B,
                   num_rva_sizes=16, extra_opt_bytes=0):
    """Build a minimal but structurally genuine PE32+ image.

    Genuine PE32+ layout: DOS header (e_lfanew @ offset 60) -> "PE\\0\\0" ->
    20-byte COFF header -> optional header. NumberOfRvaAndSizes lives at
    optional-header offset 108 and the data directories begin at a FIXED
    optional-header offset 112 (NOT at opt_start + SizeOfOptionalHeader). The
    Security (certificate table) directory is data-directory index 4, i.e.
    optional-header offset 112 + 4*8 = 144.

    `extra_opt_bytes` pads the END of the optional header (after the data
    directories) so SizeOfOptionalHeader is larger than the genuine minimum.
    This is exactly the trap a previous bug fell into: it computed the
    data-directory start as opt_start + SizeOfOptionalHeader, which with padding
    points into the zeroed tail and misreads a signed file as unsigned (or vice
    versa). The fixed parser reads the fixed offset 144, independent of padding.
    """
    e_lfanew = 0x80
    opt_start = e_lfanew + 24
    sec_dir = opt_start + 112 + 4 * 8          # fixed offset of Security directory
    base_opt = sec_dir + 8                     # size needed to cover Security dir
    size_of_opt = base_opt + extra_opt_bytes
    cert_offset = opt_start + size_of_opt
    total = cert_offset + (0x200 if signed else 0)
    data = bytearray(total)
    data[0:2] = b'MZ'
    struct.pack_into('<I', data, 60, e_lfanew)                       # e_lfanew
    data[e_lfanew:e_lfanew + 4] = b'PE\x00\x00'                      # PE signature
    struct.pack_into('<H', data, e_lfanew + 4, machine)              # Machine
    struct.pack_into('<H', data, e_lfanew + 6, 1)                   # NumberOfSections
    struct.pack_into('<H', data, e_lfanew + 20, size_of_opt)         # SizeOfOptionalHeader
    struct.pack_into('<H', data, e_lfanew + 22, 0x0022)              # Characteristics
    struct.pack_into('<H', data, opt_start, magic)                  # PE32+/PE32 magic
    struct.pack_into('<I', data, opt_start + 108, num_rva_sizes)    # NumberOfRvaAndSizes
    sec_rva = cert_offset if signed else 0
    sec_size = 0x200 if signed else 0
    struct.pack_into('<I', data, sec_dir, sec_rva)
    struct.pack_into('<I', data, sec_dir + 4, sec_size)
    if signed:
        data[cert_offset:cert_offset + 0x200] = b'\x00' * 0x200
    return bytes(data)


def build_windows_zip(extra_entries=None, duplicate=None):
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, 'w', zipfile.ZIP_DEFLATED) as zf:
        zf.writestr('valhalla.exe', b'MZ-placeholder')
        zf.writestr('flutter_windows.dll', b'dll-bytes')
        zf.writestr('data/icudtl.dat', b'icu-bytes')
        zf.writestr('data/flutter_assets/AssetManifest.json', b'{}')
        if duplicate:
            zf.writestr(duplicate, b'duplicate-second')
        for name, content in (extra_entries or []):
            zf.writestr(name, content)
    return buf.getvalue()


def build_raw_zip(entries):
    """Build a ZIP from explicit (name, content) pairs with NO separator normalization."""
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, 'w', zipfile.ZIP_DEFLATED) as zf:
        for name, content in entries:
            zf.writestr(name, content)
    return buf.getvalue()


def build_windows_zip_backslash():
    """A Windows-style ZIP that legitimately uses backslash separators."""
    return build_raw_zip([
        ('valhalla.exe', b'MZ-placeholder'),
        ('flutter_windows.dll', b'dll-bytes'),
        ('data\\icudtl.dat', b'icu-bytes'),
        ('data\\flutter_assets\\AssetManifest.json', b'{}'),
    ])


def build_msix(identity=None, version=f'{VERSION}.0', signed=False, extra_entries=None):
    ident = dict(IDENTITY)
    if identity:
        ident.update(identity)
    manifest = (
        '<?xml version="1.0" encoding="utf-8"?>'
        '<Package xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10">'
        f'<Identity Name="{ident["Name"]}" Publisher="{ident["Publisher"]}" '
        f'Version="{version}" ProcessorArchitecture="x64" />'
        '<Properties>'
        f'<DisplayName>{ident["DisplayName"]}</DisplayName>'
        f'<PublisherDisplayName>{ident["PublisherDisplayName"]}</PublisherDisplayName>'
        '</Properties>'
        '</Package>'
    )
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, 'w', zipfile.ZIP_DEFLATED) as zf:
        zf.writestr('AppxManifest.xml', manifest)
        zf.writestr('AppxBlockMap.xml', '<BlockMap/>')
        if signed:
            zf.writestr('AppxSignature.p7x', b'signature')
        for name, content in (extra_entries or []):
            zf.writestr(name, content)
    return buf.getvalue()


def _immutable_names(version=VERSION, build=BUILD):
    return [
        f'valhalla-v{version}-android-arm64-v8a-signed-{build}.apk',
        f'valhalla-v{version}-android-armeabi-v7a-signed-{build}.apk',
        f'valhalla-v{version}-android-x86_64-signed-{build}.apk',
        f'valhalla-v{version}-android-signed.aab',
        f'valhalla-v{version}-android-BUILD-INFO.txt',
        f'valhalla-v{version}-linux-x64-BUILD-INFO.txt',
        f'valhalla-v{version}-linux-x64.tar.gz',
    ]


def _initial_update(version, build, source, art, imm):
    entries = []
    for name, platform, arch in (
        (imm[0], 'android', 'arm64-v8a'),
        (imm[1], 'android', 'armeabi-v7a'),
        (imm[2], 'android', 'x86_64'),
        (imm[6], 'linux', 'x64'),
    ):
        data = (art / name).read_bytes()
        entries.append({'name': name, 'platform': platform, 'architecture': arch,
                        'size': len(data), 'sha256': sha256_bytes(data)})
    return {'schemaVersion': 1, 'version': version, 'buildNumber': build,
            'sourceCommit': source, 'artifacts': entries}


def build_fixture(root, *, version=VERSION, build=BUILD, source=COMMIT,
                  exe_bytes=None, zip_bytes=None, msix_bytes=None,
                  report_identity=None, report_mutator=None,
                  frozen_mutator=None, frozen_count_override=None):
    work = root / 'work'
    windows = root / 'windows'
    art = work / 'artifacts'
    art.mkdir(parents=True)
    windows.mkdir(parents=True)

    imm = _immutable_names(version, build)
    for name in imm:
        (art / name).write_bytes(f'immutable::{name}'.encode('utf-8'))

    exe = exe_bytes if exe_bytes is not None else build_pe32plus(False)
    zipb = zip_bytes if zip_bytes is not None else build_windows_zip()
    msix = msix_bytes if msix_bytes is not None else build_msix(version=f'{version}.0')
    exe_name = f'valhalla-{version}-windows-x64-setup.exe'
    zip_name = f'valhalla-v{version}-windows-x64.zip'
    msix_name = f'valhalla-{version}.0-windows-x64-store.msix'
    (windows / exe_name).write_bytes(exe)
    (windows / zip_name).write_bytes(zipb)
    (windows / msix_name).write_bytes(msix)

    update = _initial_update(version, build, source, art, imm)
    (art / 'update.json').write_text(json.dumps(update, ensure_ascii=False, indent=2) + '\n')

    primaries = imm + ['update.json']
    for name in primaries:
        data = (art / name).read_bytes()
        (art / f'{name}.sha256').write_text(f'{sha256_bytes(data)}  {name}\n')
    sums = ''.join(f'{sha256_bytes((art / name).read_bytes())}  {name}\n' for name in primaries)
    (art / 'SHA256SUMS.txt').write_text(sums)

    frozen = [{'name': p.name, 'size': p.stat().st_size, 'sha256': sha256_path(p)}
              for p in sorted(art.iterdir())]
    if frozen_count_override is not None:
        frozen = frozen[:frozen_count_override]
    if frozen_mutator:
        frozen_mutator(frozen)
    (work / 'frozen-assets.json').write_text(json.dumps(frozen, indent=2) + '\n')

    state = {'version': f'{version}+{build}', 'source': source, 'built': True}
    (work / 'state.json').write_text(json.dumps(state, indent=2) + '\n')

    ident = dict(IDENTITY)
    if report_identity:
        ident.update(report_identity)
    report = {
        'version': version,
        'buildNumber': build,
        'sourceCommit': source,
        'artifacts': [
            {'fileName': exe_name, 'size': len(exe), 'sha256': sha256_bytes(exe), 'signed': False},
            {'fileName': zip_name, 'size': len(zipb), 'sha256': sha256_bytes(zipb), 'signed': False},
            {'fileName': msix_name, 'size': len(msix), 'sha256': sha256_bytes(msix), 'signed': False},
        ],
        'msixManifest': {**ident, 'Version': f'{version}.0', 'Architecture': 'x64'},
    }
    if report_mutator:
        report_mutator(report)
    (windows / 'windows-build-report.json').write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + '\n')

    return {
        'work': work,
        'windows': windows,
        'frozen': json.loads((work / 'frozen-assets.json').read_text()),
        'state': json.loads((work / 'state.json').read_text()),
        'art_hashes': {p.name: sha256_path(p) for p in art.iterdir()},
        'exe_name': exe_name,
        'zip_name': zip_name,
        'msix_name': msix_name,
    }


def fake_git(cmd, **kwargs):
    """Only the two read-only git probes are mocked; everything else raises."""
    if isinstance(cmd, (list, tuple)):
        if 'rev-parse' in cmd:
            return COMMIT + '\n'
        if '--porcelain' in cmd:
            return ''
    raise AssertionError(f'unexpected subprocess call: {cmd!r}')


def call_main(work, windows):
    out = io.StringIO()
    with mock.patch('register_windows_release.subprocess.check_output', fake_git):
        with contextlib.redirect_stdout(out):
            rwr.main(['--release', str(work), '--windows-dir', str(windows)])
    return out.getvalue()


class PrimitiveTests(unittest.TestCase):
    def test_find_report_requires_single_trusted_json(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / 'a.json').write_text(json.dumps({'version': '1.0.0'}))
            (root / 'b.json').write_text(json.dumps({'version': '1.0.0'}))
            with self.assertRaises(RuntimeError):
                rwr.find_report(root)

    def test_is_regular_nonsymlink_rejects_symlink(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            target = root / 'target.txt'
            target.write_text('x')
            link = root / 'link.txt'
            link.symlink_to(target)
            self.assertFalse(rwr.is_regular_nonsymlink(link))

    def test_pe_unsigned_and_signed_detection(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / 'u.exe'
            p.write_bytes(build_pe32plus(False))
            self.assertTrue(rwr.is_exe_unsigned_from_pe(p))
            p.write_bytes(build_pe32plus(True))
            self.assertFalse(rwr.is_exe_unsigned_from_pe(p))

    def test_pe_invalid_and_wrong_machine(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / 'bad.exe'
            p.write_bytes(b'not a pe' * 20)
            with self.assertRaises(RuntimeError):
                rwr.is_exe_unsigned_from_pe(p)
            p.write_bytes(build_pe32plus(False, machine=0x14C))  # i386, not x64
            with self.assertRaises(RuntimeError):
                rwr.is_exe_unsigned_from_pe(p)


class PeRegressionTests(unittest.TestCase):
    """Regression coverage pinning the correct PE32+ data-directory math.

    These tests specifically defend against the previously-shipped bug where the
    Security directory was read at `opt_start + SizeOfOptionalHeader` instead of
    the fixed optional-header offset 144.
    """

    def test_padded_optional_header_detects_signed(self):
        # With extra optional-header padding the buggy formula
        # (opt_start + SizeOfOptionalHeader) skips past the genuine Security
        # directory and reads the zeroed tail, wrongly reporting a SIGNED file as
        # unsigned. The corrected parser reads the fixed offset 144 and still
        # reports this file as signed.
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / 'pad.exe'
            p.write_bytes(build_pe32plus(True, extra_opt_bytes=64))
            self.assertFalse(rwr.is_exe_unsigned_from_pe(p))

    def test_padded_optional_header_detects_unsigned(self):
        # Symmetric check: a padded UNSIGNED file must still report unsigned.
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / 'pad_u.exe'
            p.write_bytes(build_pe32plus(False, extra_opt_bytes=64))
            self.assertTrue(rwr.is_exe_unsigned_from_pe(p))

    def test_pe32_not_plus_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / 'pe32.exe'
            p.write_bytes(build_pe32plus(False, magic=0x10B))  # 32-bit PE32
            with self.assertRaises(RuntimeError):
                rwr.is_exe_unsigned_from_pe(p)

    def test_pe_invalid_magic_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / 'badmagic.exe'
            p.write_bytes(build_pe32plus(False, magic=0x1234))
            with self.assertRaises(RuntimeError):
                rwr.is_exe_unsigned_from_pe(p)

    def test_pe_missing_signature_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / 'nosig.exe'
            blob = bytearray(build_pe32plus(False))
            blob[0x80:0x80 + 4] = b'XX\x00\x00'  # corrupt "PE\0\0"
            p.write_bytes(bytes(blob))
            with self.assertRaises(RuntimeError):
                rwr.is_exe_unsigned_from_pe(p)

    def test_pe_truncated_optional_header_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / 'trunc.exe'
            # Truncate before the declared optional header fits in the file.
            blob = build_pe32plus(False, extra_opt_bytes=64)
            p.write_bytes(blob[: (0x80 + 24 + 152)])  # cut within optional header
            with self.assertRaises(RuntimeError):
                rwr.is_exe_unsigned_from_pe(p)

    def test_pe_too_few_data_directories_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / 'few.exe'
            p.write_bytes(build_pe32plus(False, num_rva_sizes=3))
            with self.assertRaises(RuntimeError):
                rwr.is_exe_unsigned_from_pe(p)


class EndToEndRegistrationTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)

    def tearDown(self):
        self._tmp.cleanup()

    # --- success + idempotent retry -------------------------------------
    def test_success_then_idempotent(self):
        fx = build_fixture(self.root)
        work, windows = fx['work'], fx['windows']
        pre = dict(fx['art_hashes'])

        out = call_main(work, windows)
        self.assertIn('Registered Windows artifacts', out)

        post = sorted(p.name for p in (work / 'artifacts').iterdir())
        self.assertEqual(len(post), 23)
        for name in (fx['exe_name'], fx['zip_name'], fx['msix_name']):
            self.assertIn(name, post)
            self.assertNotIn(name, pre)

        frozen2 = json.loads((work / 'frozen-assets.json').read_text())
        names2 = {e['name'] for e in frozen2}
        self.assertEqual(len(frozen2), 23)
        self.assertTrue({fx['exe_name'], fx['zip_name'], fx['msix_name']} <= names2)

        # Only update.json / update.json.sha256 / SHA256SUMS.txt may change.
        changed = {n for n, digest in pre.items()
                   if sha256_path(work / 'artifacts' / n) != digest}
        self.assertEqual(changed, {'update.json', 'update.json.sha256', 'SHA256SUMS.txt'})

        upd = json.loads((work / 'artifacts' / 'update.json').read_text())
        winrec = [a for a in upd['artifacts']
                  if a.get('platform') == 'windows' and a.get('architecture') == 'x64']
        self.assertEqual(len(winrec), 1)
        self.assertEqual(winrec[0]['name'], fx['zip_name'])
        self.assertEqual(winrec[0]['sha256'],
                         sha256_path(work / 'artifacts' / fx['zip_name']))
        self.assertEqual(winrec[0]['size'],
                         (work / 'artifacts' / fx['zip_name']).stat().st_size)

        self.assertTrue(
            (work / 'artifacts' / 'update.json.sha256').read_text().startswith(
                sha256_path(work / 'artifacts' / 'update.json')))

        st = json.loads((work / 'state.json').read_text())
        self.assertTrue(st['windows_registered'])
        self.assertEqual(st['windows_files'], [fx['exe_name'], fx['zip_name'], fx['msix_name']])

        # No stage/backup leftovers after a successful commit.
        self.assertFalse(any(p.name.startswith('.artifacts-stage-') for p in work.iterdir()))
        self.assertFalse(any(p.name.startswith('artifacts-pre-windows-') for p in work.iterdir()))
        self.assertFalse((work / 'frozen-assets.pre-windows.json').exists())
        self.assertFalse((work / 'state.pre-windows.json').exists())

        # Idempotent retry: no mutation, reports already-registered.
        snapshot = {p.name: sha256_path(p) for p in (work / 'artifacts').iterdir()}
        out2 = call_main(work, windows)
        self.assertIn('already registered', out2.lower())
        self.assertEqual(snapshot, {p.name: sha256_path(p) for p in (work / 'artifacts').iterdir()})
        self.assertEqual(json.loads((work / 'frozen-assets.json').read_text()), frozen2)

    # --- frozen asset integrity -----------------------------------------
    def test_tampered_frozen_hash_rejected(self):
        def tamper(frozen):
            for entry in frozen:
                if entry['name'].endswith('.apk'):
                    entry['sha256'] = '0' * 64
                    break

        fx = build_fixture(self.root, frozen_mutator=tamper)
        with self.assertRaises(RuntimeError) as ctx:
            call_main(fx['work'], fx['windows'])
        self.assertIn('Frozen asset changed', str(ctx.exception))

    def test_changed_frozen_file_rejected(self):
        fx = build_fixture(self.root)
        apk = next((fx['work'] / 'artifacts').glob('*.apk'))
        apk.write_bytes(b'tampered-content')
        with self.assertRaises(RuntimeError) as ctx:
            call_main(fx['work'], fx['windows'])
        self.assertIn('Frozen asset changed', str(ctx.exception))

    def test_frozen_count_mismatch_rejected(self):
        fx = build_fixture(self.root, frozen_count_override=16)
        with self.assertRaises(RuntimeError) as ctx:
            call_main(fx['work'], fx['windows'])
        self.assertIn('Expected 17 frozen assets', str(ctx.exception))

    # --- EXE / PE --------------------------------------------------------
    def test_invalid_pe_rejected(self):
        fx = build_fixture(self.root, exe_bytes=b'not a pe' * 20)
        with self.assertRaises(RuntimeError) as ctx:
            call_main(fx['work'], fx['windows'])
        self.assertIn('Not a PE file', str(ctx.exception))

    def test_signed_pe_rejected(self):
        fx = build_fixture(self.root, exe_bytes=build_pe32plus(True))
        with self.assertRaises(RuntimeError) as ctx:
            call_main(fx['work'], fx['windows'])
        self.assertIn('EXE is signed', str(ctx.exception))

    # --- MSIX ------------------------------------------------------------
    def test_signed_msix_rejected(self):
        fx = build_fixture(
            self.root, msix_bytes=build_msix(version=f'{VERSION}.0', signed=True))
        with self.assertRaises(RuntimeError) as ctx:
            call_main(fx['work'], fx['windows'])
        self.assertIn('must be unsigned', str(ctx.exception))

    def test_msix_wrong_identity_in_zip_rejected(self):
        bad = build_msix(identity={'Name': 'Wrong.Name'}, version=f'{VERSION}.0')
        fx = build_fixture(self.root, msix_bytes=bad)
        with self.assertRaises(RuntimeError) as ctx:
            call_main(fx['work'], fx['windows'])
        self.assertIn('MSIX Name mismatch', str(ctx.exception))

    def test_report_msix_identity_mismatch_rejected(self):
        fx = build_fixture(self.root, report_identity={'Publisher': 'CN=WRONG'})
        with self.assertRaises(RuntimeError) as ctx:
            call_main(fx['work'], fx['windows'])
        self.assertIn('Report MSIX Publisher mismatch', str(ctx.exception))

    # --- ZIP -------------------------------------------------------------
    def test_zip_traversal_rejected(self):
        bad = build_windows_zip(extra_entries=[('../evil.txt', b'x')])
        fx = build_fixture(self.root, zip_bytes=bad)
        with self.assertRaises(RuntimeError) as ctx:
            call_main(fx['work'], fx['windows'])
        self.assertIn('traversal', str(ctx.exception).lower())

    def test_zip_duplicate_entries_rejected(self):
        bad = build_windows_zip(duplicate='valhalla.exe')
        fx = build_fixture(self.root, zip_bytes=bad)
        with self.assertRaises(RuntimeError) as ctx:
            call_main(fx['work'], fx['windows'])
        self.assertIn('Duplicate zip entry', str(ctx.exception))

    def test_msix_traversal_rejected(self):
        bad = build_msix(version=f'{VERSION}.0', extra_entries=[('../x', b'y')])
        fx = build_fixture(self.root, msix_bytes=bad)
        with self.assertRaises(RuntimeError) as ctx:
            call_main(fx['work'], fx['windows'])
        self.assertIn('traversal', str(ctx.exception).lower())

    # --- backslash / Windows-style archive entries -----------------------
    def test_backslash_zip_payload_accepted(self):
        # A Windows-generated ZIP may legitimately use backslash separators.
        # Validation must normalize them and still succeed end-to-end.
        fx = build_fixture(self.root, zip_bytes=build_windows_zip_backslash())
        out = call_main(fx['work'], fx['windows'])
        self.assertIn('Registered Windows artifacts', out)

    def test_msix_backslash_traversal_rejected(self):
        bad = build_msix(version=f'{VERSION}.0', extra_entries=[('..\\evil.xml', b'y')])
        fx = build_fixture(self.root, msix_bytes=bad)
        with self.assertRaises(RuntimeError) as ctx:
            call_main(fx['work'], fx['windows'])
        self.assertIn('traversal', str(ctx.exception).lower())

    def test_msix_drive_path_rejected(self):
        bad = build_msix(version=f'{VERSION}.0', extra_entries=[('C:\\evil.dll', b'y')])
        fx = build_fixture(self.root, msix_bytes=bad)
        with self.assertRaises(RuntimeError) as ctx:
            call_main(fx['work'], fx['windows'])
        # Drive/UNC paths are caught; the message names either "Drive path" or
        # "Absolute path" depending on parse order, both reject the entry.
        self.assertIn('archive', str(ctx.exception).lower())

    # --- idempotent branch hardening -------------------------------------
    def test_idempotent_tampered_frozen_rejected(self):
        fx = build_fixture(self.root)
        call_main(fx['work'], fx['windows'])  # register once
        # Tamper a registered frozen asset on disk (not the JSON record).
        apk = next((fx['work'] / 'artifacts').glob('*.apk'))
        apk.write_bytes(b'tampered-on-disk')
        with self.assertRaises(RuntimeError) as ctx:
            call_main(fx['work'], fx['windows'])
        self.assertIn('idempotent', str(ctx.exception).lower())
        self.assertIn('Frozen asset changed on idempotent check', str(ctx.exception))

    def test_idempotent_tampered_frozen_json_rejected(self):
        fx = build_fixture(self.root)
        call_main(fx['work'], fx['windows'])  # register once
        # Tamper a frozen record's hash in the JSON (asset still present by name),
        # forcing the idempotent branch's per-asset hash/size validation to fire.
        frozen = json.loads((fx['work'] / 'frozen-assets.json').read_text())
        for entry in frozen:
            if entry['name'].endswith('.exe'):
                entry['sha256'] = '0' * 64
                break
        (fx['work'] / 'frozen-assets.json').write_text(json.dumps(frozen))
        with self.assertRaises(RuntimeError) as ctx:
            call_main(fx['work'], fx['windows'])
        self.assertIn('Frozen asset changed on idempotent check', str(ctx.exception))

    # --- report metadata / hash -----------------------------------------
    def test_report_version_mismatch_rejected(self):
        fx = build_fixture(self.root,
                           report_mutator=lambda r: r.__setitem__('version', '9.9.9'))
        with self.assertRaises(RuntimeError) as ctx:
            call_main(fx['work'], fx['windows'])
        self.assertIn('Report version mismatch', str(ctx.exception))

    def test_report_build_mismatch_rejected(self):
        fx = build_fixture(self.root,
                           report_mutator=lambda r: r.__setitem__('buildNumber', 1))
        with self.assertRaises(RuntimeError) as ctx:
            call_main(fx['work'], fx['windows'])
        self.assertIn('Report build mismatch', str(ctx.exception))

    def test_report_source_mismatch_rejected(self):
        fx = build_fixture(self.root,
                           report_mutator=lambda r: r.__setitem__('sourceCommit', 'b' * 40))
        with self.assertRaises(RuntimeError) as ctx:
            call_main(fx['work'], fx['windows'])
        self.assertIn('Report source commit mismatch', str(ctx.exception))

    def test_report_size_mismatch_rejected(self):
        fx = build_fixture(
            self.root, report_mutator=lambda r: r['artifacts'][0].__setitem__('size', 1))
        with self.assertRaises(RuntimeError) as ctx:
            call_main(fx['work'], fx['windows'])
        self.assertIn('Report size mismatch', str(ctx.exception))

    def test_report_sha_mismatch_rejected(self):
        fx = build_fixture(
            self.root,
            report_mutator=lambda r: r['artifacts'][0].__setitem__('sha256', '0' * 64))
        with self.assertRaises(RuntimeError) as ctx:
            call_main(fx['work'], fx['windows'])
        self.assertIn('Report sha256 mismatch', str(ctx.exception))

    # --- transactional rollback -----------------------------------------
    def test_transaction_rollback_restores_prior_state(self):
        fx = build_fixture(self.root)
        work, windows = fx['work'], fx['windows']
        before_frozen = json.loads((work / 'frozen-assets.json').read_text())
        before_state = json.loads((work / 'state.json').read_text())
        before_names = sorted(fx['art_hashes'])

        real_write = Path.write_text
        flag = {'raised': False}

        def flaky(path, data, *args, **kwargs):
            if path.name == 'state.json' and not flag['raised']:
                flag['raised'] = True
                raise OSError('simulated disk failure')
            return real_write(path, data, *args, **kwargs)

        out = io.StringIO()
        with mock.patch('register_windows_release.subprocess.check_output', fake_git), \
                mock.patch.object(Path, 'write_text', flaky):
            with contextlib.redirect_stdout(out):
                with self.assertRaises(RuntimeError) as ctx:
                    rwr.main(['--release', str(work), '--windows-dir', str(windows)])

        self.assertIn('rolled back', str(ctx.exception))
        self.assertEqual(sorted(p.name for p in (work / 'artifacts').iterdir()), before_names)
        for name, digest in fx['art_hashes'].items():
            self.assertEqual(sha256_path(work / 'artifacts' / name), digest, name)
        self.assertEqual(json.loads((work / 'frozen-assets.json').read_text()), before_frozen)
        self.assertEqual(json.loads((work / 'state.json').read_text()), before_state)
        self.assertFalse(any(p.name.startswith('.artifacts-stage-') for p in work.iterdir()))
        self.assertFalse(any(p.name.startswith('artifacts-pre-windows-') for p in work.iterdir()))
        self.assertFalse((work / 'frozen-assets.pre-windows.json').exists())
        self.assertFalse((work / 'state.pre-windows.json').exists())

    def test_staging_failure_no_partial_publish(self):
        fx = build_fixture(self.root)
        work, windows = fx['work'], fx['windows']
        before_frozen = (work / 'frozen-assets.json').read_text()
        before_state = (work / 'state.json').read_text()
        before_names = sorted(fx['art_hashes'])

        def boom(src, dst, *args, **kwargs):
            raise OSError('copy failed')

        out = io.StringIO()
        with mock.patch('register_windows_release.subprocess.check_output', fake_git), \
                mock.patch('register_windows_release.shutil.copy2', boom):
            with contextlib.redirect_stdout(out):
                with self.assertRaises(OSError):
                    rwr.main(['--release', str(work), '--windows-dir', str(windows)])

        self.assertEqual(sorted(p.name for p in (work / 'artifacts').iterdir()), before_names)
        for name, digest in fx['art_hashes'].items():
            self.assertEqual(sha256_path(work / 'artifacts' / name), digest, name)
        self.assertEqual((work / 'frozen-assets.json').read_text(), before_frozen)
        self.assertEqual((work / 'state.json').read_text(), before_state)
        self.assertFalse(any(p.name.startswith('.artifacts-stage-') for p in work.iterdir()))


class ArchiveSafetyTests(unittest.TestCase):
    """Unit coverage for validate_zip / _normalize_zip_entry path-safety.

    These defend against archive names that bypass the old Linux-only
    PurePosixPath checks: C:\\... drive, \\\\server UNC, ..\\.. traversal written
    with backslashes, same entry via forward+backslash (normalized duplicate),
    and NUL/control characters.
    """

    def _zip(self, d, name, data):
        p = Path(d) / name
        p.write_bytes(data)
        return p

    def test_zip_backslash_traversal_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            z = build_raw_zip([
                ('valhalla.exe', b'x'), ('flutter_windows.dll', b'x'),
                ('data\\icudtl.dat', b'x'),
                ('data\\flutter_assets\\a.json', b'{}'),
                ('..\\evil.txt', b'x')])
            with self.assertRaises(RuntimeError):
                rwr.validate_zip(self._zip(d, 'w.zip', z))

    def test_zip_drive_path_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            z = build_raw_zip([
                ('valhalla.exe', b'x'), ('flutter_windows.dll', b'x'),
                ('data/icudtl.dat', b'x'),
                ('data/flutter_assets/a.json', b'{}'),
                ('C:\\windows\\system32\\evil.dll', b'x')])
            with self.assertRaises(RuntimeError):
                rwr.validate_zip(self._zip(d, 'w.zip', z))

    def test_zip_unc_path_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            z = build_raw_zip([
                ('valhalla.exe', b'x'), ('flutter_windows.dll', b'x'),
                ('data/icudtl.dat', b'x'),
                ('data/flutter_assets/a.json', b'{}'),
                ('\\\\server\\share\\evil.dll', b'x')])
            with self.assertRaises(RuntimeError):
                rwr.validate_zip(self._zip(d, 'w.zip', z))

    def test_zip_normalized_duplicate_rejected(self):
        # Same entry via forward slash and backslash is a normalized duplicate.
        with tempfile.TemporaryDirectory() as d:
            z = build_raw_zip([
                ('valhalla.exe', b'x'), ('flutter_windows.dll', b'x'),
                ('data/icudtl.dat', b'x'),
                ('data\\icudtl.dat', b'x'),
                ('data/flutter_assets/a.json', b'{}')])
            with self.assertRaises(RuntimeError):
                rwr.validate_zip(self._zip(d, 'w.zip', z))

    def test_zip_control_char_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            z = build_raw_zip([
                ('valhalla.exe', b'x'), ('flutter_windows.dll', b'x'),
                ('data/icudtl.dat', b'x'),
                ('data/flutter_assets/a.json', b'{}'),
                ('data/eval\x01.txt', b'x')])
            with self.assertRaises(RuntimeError):
                rwr.validate_zip(self._zip(d, 'w.zip', z))

    def test_zip_backslash_payload_accepted(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / 'w.zip'
            p.write_bytes(build_windows_zip_backslash())
            rwr.validate_zip(p)  # must not raise


if __name__ == '__main__':
    unittest.main()
