import json
import re
import unittest
from pathlib import Path

TOOL = Path(__file__).resolve().parent
HELPER = TOOL / 'windows_packaging.ps1'
EXE = TOOL / 'package_windows_exe.ps1'
ZIP = TOOL / 'package_windows_zip.ps1'
MSIX = TOOL / 'package_windows_msix.ps1'
ISS = TOOL / 'windows_installer.iss'
IDENTITY = TOOL / 'windows_store_identity.json'


class WindowsPackagingStaticTests(unittest.TestCase):
    def read(self, path):
        return path.read_text(encoding='utf-8')

    def test_store_identity_is_exact(self):
        identity = json.loads(self.read(IDENTITY))
        self.assertEqual(identity, {
            'Name': 'Norns.Valhalla-',
            'Publisher': 'CN=257586C2-E7B0-47F3-BAED-A744A66748A1',
            'PublisherDisplayName': 'Norns',
            'DisplayName': 'Valhalla-服务器运维管理工具',
        })

    def test_packaging_scripts_share_version_helper(self):
        for path in (EXE, ZIP, MSIX):
            with self.subTest(path=path.name):
                text = self.read(path)
                self.assertIn("windows_packaging.ps1", text)
                self.assertIn('Get-ValhallaWindowsVersionInfo', text)
                self.assertIn('Get-ValhallaWindowsArtifactNames', text)

    def test_no_stale_release_version_or_old_builder_paths(self):
        for path in (HELPER, EXE, ZIP, MSIX, ISS):
            with self.subTest(path=path.name):
                text = self.read(path)
                self.assertNotIn('1.0.15', text)
                self.assertNotRegex(text, r'[A-Za-z]:\\Data\\')
                self.assertNotIn('D:\\Data', text)

    def test_expected_artifact_names_are_formulae_not_literals(self):
        helper = self.read(HELPER)
        self.assertIn('$setupBase = "valhalla-$($VersionInfo.Version)-windows-x64-setup"', helper)
        self.assertIn('SetupExe    = "$setupBase.exe"', helper)
        self.assertIn('valhalla-v$($VersionInfo.Version)-windows-x64.zip', helper)
        self.assertIn('valhalla-$($VersionInfo.Msix)-windows-x64-store.msix', helper)
        for path in (EXE, ZIP, MSIX):
            with self.subTest(path=path.name):
                self.assertNotRegex(self.read(path), r'valhalla-v?\d+\.\d+\.\d+')

    def test_installer_version_comes_from_preprocessor_defines(self):
        iss = self.read(ISS)
        self.assertIn('#ifndef ValhallaAppVersion', iss)
        self.assertIn('#error ValhallaAppVersion is required', iss)
        self.assertIn('AppVersion={#ValhallaAppVersion}', iss)
        self.assertIn('VersionInfoVersion={#ValhallaAppVersion}.{#ValhallaAppBuild}', iss)
        self.assertIn('OutputBaseFilename={#ValhallaOutputBaseFilename}', iss)
        self.assertNotRegex(iss, r'AppVersion=\d+\.\d+\.\d+')

    def test_msix_identity_and_manifest_are_data_driven(self):
        text = self.read(MSIX)
        self.assertIn('Get-ValhallaWindowsStoreIdentity', text)
        self.assertIn('New-ValhallaWindowsMsixManifest', text)
        self.assertNotIn("$PackageName = 'Norns.Valhalla-'", text)
        self.assertNotIn('CN=257586C2', text)
        self.assertIn('Refusing to overwrite existing artifact', text)
        self.assertIn('Norns.Valhalla-_sxt4q0tm9x2xr', text)
        helper = self.read(HELPER)
        self.assertIn('Windows.FullTrustApplication', helper)
        self.assertIn('runFullTrust', helper)

    def test_payload_requirements_match_the_real_flutter_bundle(self):
        helper = self.read(HELPER)
        for required in (
            "'valhalla.exe'",
            "'flutter_windows.dll'",
            "'data\\app.so'",
            "'data\\icudtl.dat'",
            "'licenses\\libsmb2\\LICENCE-LGPL-2.1.txt'",
            "'zlib.dll'",
        ):
            with self.subTest(required=required):
                self.assertIn(required, helper)
        self.assertIn("$runtime = @('vcruntime140.dll', 'msvcp140.dll', 'vcruntime140_1.dll')", helper)
        self.assertIn('MissingRuntime', helper)
        self.assertIn('RequireVCRuntime', self.read(EXE))
        self.assertIn('RequireVCRuntime', self.read(MSIX))

    def test_no_signing_or_certificate_generation(self):
        forbidden = (
            'Set-AuthenticodeSignature',
            'New-SelfSignedCertificate',
            'signtool',
            'SignTool',
            'MakeCert',
            'certreq',
            'Import-PfxCertificate',
        )
        for path in (HELPER, EXE, ZIP, MSIX, ISS):
            text = self.read(path)
            for token in forbidden:
                with self.subTest(path=path.name, token=token):
                    self.assertNotIn(token, text)
        self.assertIn('Microsoft signs the package after certification', self.read(MSIX))

    def test_packaging_does_not_overwrite_existing_artifacts(self):
        for path in (EXE, ZIP, MSIX):
            with self.subTest(path=path.name):
                text = self.read(path)
                self.assertIn('Refusing to overwrite existing artifact', text)
                self.assertNotIn('/o', self.read(MSIX) if path == MSIX else '')

    def test_helper_has_no_hardcoded_current_release(self):
        text = self.read(HELPER)
        self.assertNotRegex(text, r"1\.0\.2[0-9]")
        self.assertNotRegex(text, r"version:\s*1\.")


if __name__ == '__main__':
    unittest.main()
