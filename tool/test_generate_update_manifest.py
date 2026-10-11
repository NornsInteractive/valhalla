"""Self-checks for tool/generate_update_manifest.py.

Runs entirely offline: artifacts are temp files created by the test, the
Android aapt/apksigner tools are mocked, and hashes are computed by the
production code itself and compared against independently computed values.

No device, SDK, build, or network access is required or performed.
"""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

MODULE_PATH = Path(__file__).resolve().parent / "generate_update_manifest.py"
_spec = importlib.util.spec_from_file_location("generate_update_manifest", MODULE_PATH)
manifest_module = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(manifest_module)

VERSION = "1.2.3"
BUILD = 42
COMMIT = "a" * 40
CERT = "1a" * 32


def apk_badging(package="com.antigravity.valhalla.valhalla", version_code=None,
                version_name=VERSION):
    """Version codes must satisfy version_code % 1000 == BUILD."""
    code = BUILD + 1000 * 7 if version_code is None else version_code
    return (f"package: name='{package}' versionCode='{code}' "
            f"versionName='{version_name}'\n")


def apksigner_output(*digests):
    if len(digests) == 1:
        return f"Signer #1 certificate SHA-256 digest: {digests[0]}\n"
    body = "".join(f"Signer #{i} certificate SHA-256 digest: {d}\n"
                   for i, d in enumerate(digests, start=1))
    return body


def fake_tool_response(command, **kwargs):
    """Mock for subprocess.run covering both aapt and apksigner calls."""
    args = command
    tool = Path(args[0]).name
    if tool == "aapt":
        return subprocess.CompletedProcess(args, 0, stdout=apk_badging(), stderr="")
    if tool == "apksigner":
        return subprocess.CompletedProcess(args, 0, stdout=apksigner_output(CERT), stderr="")
    raise AssertionError(f"unexpected tool invocation: {args}")


def write_artifact(directory, name, payload=b"artifact-bytes"):
    path = Path(directory) / name
    path.write_bytes(payload)
    return path


class ManifestTestBase(unittest.TestCase):
    def setUp(self):
        self._temp = tempfile.TemporaryDirectory(prefix="update-manifest-")
        self.addCleanup(self._temp.cleanup)
        self.directory = Path(self._temp.name)
        self.run_patch = mock.patch.object(
            manifest_module.subprocess, "run", side_effect=fake_tool_response)
        self.run_mock = self.run_patch.start()
        self.addCleanup(self.run_patch.stop)
        # which() must resolve per tool name, since the fake runner dispatches
        # on the resolved path.
        self.which_patch = mock.patch.object(
            manifest_module.shutil, "which",
            side_effect=lambda name: f"/opt/android/{name}")
        self.which_patch.start()
        self.addCleanup(self.which_patch.stop)

    def build(self, version=VERSION, build=BUILD, commit=COMMIT):
        return manifest_module.manifest(self.directory, version, build, commit)


class PlatformDetectionTests(ManifestTestBase):
    def test_platform_for_recognizes_supported_artifacts(self):
        expected = {
            "Valhalla-1.2.3-android-arm64-v8a.apk": ("android", "arm64-v8a"),
            "Valhalla-1.2.3-android-armeabi-v7a.apk": ("android", "armeabi-v7a"),
            "Valhalla-1.2.3-android-x86_64.apk": ("android", "x86_64"),
            "Valhalla-1.2.3-windows-x64.zip": ("windows", "x64"),
            "Valhalla-1.2.3-linux-x64.tar.gz": ("linux", "x64"),
            "Valhalla-1.2.3-macos-universal.zip": ("macos", "universal"),
        }
        for name, target in expected.items():
            self.assertEqual(manifest_module.platform_for(name), target, name)

    def test_platform_for_rejects_unknown_and_unsigned_variants(self):
        for name in ("random-notes.txt", "notes-v1.2.3-android-arm64-v8a.apk",
                     "Valhalla-1.2.3-linux-arm64.tar.gz",
                     "Valhalla-1.2.3-android-mips.apk",
                     "Valhalla-1.2.3-windows-x86.zip"):
            self.assertIsNone(manifest_module.platform_for(name), name)

    def test_directory_without_supported_artifacts_is_rejected(self):
        write_artifact(self.directory, "readme.txt", b"hello")
        with self.assertRaises(ValueError) as ctx:
            self.build()
        self.assertIn("No compatible release artifacts", str(ctx.exception))


class HashingTests(ManifestTestBase):
    def test_digest_and_size_match_the_actual_bytes_on_disk(self):
        payload = b"linux-tarball-contents"
        path = write_artifact(self.directory, "Valhalla-1.2.3-linux-x64.tar.gz", payload)

        result = self.build()

        self.assertEqual(result["artifacts"][0]["size"], len(payload))
        self.assertEqual(result["artifacts"][0]["size"], path.stat().st_size)
        self.assertEqual(result["artifacts"][0]["sha256"],
                         hashlib.sha256(payload).hexdigest())

    def test_empty_artifact_is_rejected(self):
        write_artifact(self.directory, "Valhalla-1.2.3-linux-x64.tar.gz", b"")
        with self.assertRaises(ValueError) as ctx:
            self.build()
        self.assertIn("Empty artifact", str(ctx.exception))

    def test_manifest_envelope_shape(self):
        write_artifact(self.directory, "Valhalla-1.2.3-windows-x64.zip", b"zip-bytes")

        result = self.build()

        self.assertEqual(result["schemaVersion"], 1)
        self.assertEqual(result["version"], VERSION)
        self.assertEqual(result["buildNumber"], BUILD)
        self.assertEqual(result["sourceCommit"], COMMIT)
        self.assertEqual(len(result["artifacts"]), 1)
        self.assertNotIn("androidVersionCode", result["artifacts"][0])

    def test_artifacts_are_sorted_by_name(self):
        write_artifact(self.directory, "Valhalla-1.2.3-windows-x64.zip")
        write_artifact(self.directory, "Valhalla-1.2.3-linux-x64.tar.gz")
        write_artifact(self.directory, "Valhalla-1.2.3-macos-universal.zip")

        names = [a["name"] for a in self.build()["artifacts"]]

        self.assertEqual(names, sorted(names))

    def test_android_tools_are_not_invoked_for_non_android_artifacts(self):
        write_artifact(self.directory, "Valhalla-1.2.3-macos-universal.zip")

        self.build()

        self.run_mock.assert_not_called()


class DuplicatePlatformTests(ManifestTestBase):
    def test_two_artifacts_for_same_platform_and_arch_are_rejected(self):
        write_artifact(self.directory, "Valhalla-1.2.3-android-arm64-v8a.apk")
        write_artifact(self.directory, "Valhalla-1.2.3-android-arm64-v8a-signed-7.apk")

        with self.assertRaises(ValueError) as ctx:
            self.build()

        self.assertIn("Ambiguous artifact", str(ctx.exception))

    def test_distinct_architectures_are_all_accepted(self):
        write_artifact(self.directory, "Valhalla-1.2.3-android-arm64-v8a.apk")
        write_artifact(self.directory, "Valhalla-1.2.3-android-armeabi-v7a.apk")
        write_artifact(self.directory, "Valhalla-1.2.3-android-x86_64.apk")

        artifacts = self.build()["artifacts"]

        # Order follows sorted file names, not architecture collation.
        self.assertEqual([a["architecture"] for a in artifacts],
                         ["arm64-v8a", "armeabi-v7a", "x86_64"])

    def test_symlinked_artifact_is_rejected(self):
        target = write_artifact(self.directory, "Valhalla-1.2.3-linux-x64.tar.gz")
        link = self.directory / "Valhalla-1.2.3-windows-x64.zip"
        link.symlink_to(target)

        with self.assertRaises(ValueError) as ctx:
            self.build()

        self.assertIn("Ambiguous artifact", str(ctx.exception))


class AndroidIdentityTests(ManifestTestBase):
    def test_valid_apk_records_version_code_and_certificate(self):
        write_artifact(self.directory, "Valhalla-1.2.3-android-arm64-v8a.apk")

        artifact = self.build()["artifacts"][0]

        self.assertEqual(artifact["platform"], "android")
        self.assertEqual(artifact["architecture"], "arm64-v8a")
        self.assertEqual(artifact["androidVersionCode"], BUILD + 1000 * 7)
        self.assertEqual(artifact["androidCertificateSha256"], CERT)

    def test_wrong_package_is_rejected(self):
        write_artifact(self.directory, "Valhalla-1.2.3-android-arm64-v8a.apk")
        self.run_mock.side_effect = lambda command, **kw: subprocess.CompletedProcess(
            command, 0,
            stdout=apk_badging(package="com.example.other") if
            Path(command[0]).name == "aapt" else apksigner_output(CERT), stderr="")

        with self.assertRaises(ValueError) as ctx:
            self.build()
        self.assertIn("APK identity mismatch", str(ctx.exception))

    def test_version_name_drift_is_rejected(self):
        write_artifact(self.directory, "Valhalla-1.2.3-android-arm64-v8a.apk")
        self.run_mock.side_effect = lambda command, **kw: subprocess.CompletedProcess(
            command, 0,
            stdout=apk_badging(version_name="9.9.9") if
            Path(command[0]).name == "aapt" else apksigner_output(CERT), stderr="")

        with self.assertRaises(ValueError) as ctx:
            self.build()
        self.assertIn("APK identity mismatch", str(ctx.exception))

    def test_build_number_drift_is_rejected(self):
        write_artifact(self.directory, "Valhalla-1.2.3-android-arm64-v8a.apk")
        self.run_mock.side_effect = lambda command, **kw: subprocess.CompletedProcess(
            command, 0,
            stdout=apk_badging(version_code=BUILD + 8) if
            Path(command[0]).name == "aapt" else apksigner_output(CERT), stderr="")

        with self.assertRaises(ValueError) as ctx:
            self.build()
        self.assertIn("APK build number mismatch", str(ctx.exception))

    def test_ambiguous_signer_is_rejected(self):
        write_artifact(self.directory, "Valhalla-1.2.3-android-arm64-v8a.apk")
        self.run_mock.side_effect = lambda command, **kw: subprocess.CompletedProcess(
            command, 0,
            stdout=apk_badging() if Path(command[0]).name == "aapt"
            else apksigner_output(CERT, "2b" * 32), stderr="")

        with self.assertRaises(ValueError) as ctx:
            self.build()
        self.assertIn("signer identity", str(ctx.exception))

    def test_missing_signer_digest_is_rejected(self):
        write_artifact(self.directory, "Valhalla-1.2.3-android-arm64-v8a.apk")
        self.run_mock.side_effect = lambda command, **kw: subprocess.CompletedProcess(
            command, 0,
            stdout=apk_badging() if Path(command[0]).name == "aapt" else "Signer #1\n",
            stderr="")

        with self.assertRaises(ValueError) as ctx:
            self.build()
        self.assertIn("signer identity", str(ctx.exception))

    def test_unreadable_badging_output_is_rejected(self):
        write_artifact(self.directory, "Valhalla-1.2.3-android-arm64-v8a.apk")
        self.run_mock.side_effect = lambda command, **kw: subprocess.CompletedProcess(
            command, 0, stdout="no package line here", stderr="")

        with self.assertRaises(ValueError) as ctx:
            self.build()
        self.assertIn("APK identity mismatch", str(ctx.exception))


class SourceAndBuildValidationTests(ManifestTestBase):
    def setUp(self):
        super().setUp()
        write_artifact(self.directory, "Valhalla-1.2.3-linux-x64.tar.gz")

    def test_prerelease_version_is_rejected(self):
        for version in ("1.2.3-rc1", "1.2", "v1.2.3", "1.2.3.4", "latest", ""):
            with self.subTest(version=version):
                with self.assertRaises(ValueError):
                    self.build(version=version)

    def test_invalid_build_numbers_are_rejected(self):
        for build in (0, -1, 1000, 5000):
            with self.subTest(build=build):
                with self.assertRaises(ValueError):
                    self.build(build=build)

    def test_invalid_source_commits_are_rejected(self):
        for commit in ("a" * 39, "a" * 41, "z" * 40, "HEAD", " " * 40):
            with self.subTest(commit=commit):
                with self.assertRaises(ValueError):
                    self.build(commit=commit)

    def test_source_commit_must_be_lowercase_hex(self):
        with self.assertRaises(ValueError):
            self.build(commit=("A" * 40))


class CommandLineTests(ManifestTestBase):
    def test_main_writes_manifest_and_matching_checksum_file(self):
        payload = b"payload-for-cli"
        write_artifact(self.directory, "Valhalla-1.2.3-linux-x64.tar.gz", payload)
        pubspec = self.directory / "pubspec.yaml"
        pubspec.write_text(f"name: valhalla\nversion: {VERSION}+{BUILD}\n", encoding="utf-8")

        argv = ["generate_update_manifest.py", str(self.directory),
                "--pubspec", str(pubspec), "--source-commit", COMMIT]
        with mock.patch.object(sys, "argv", argv):
            manifest_module.main()

        out = self.directory / "update.json"
        checksum = self.directory / "update.json.sha256"
        self.assertTrue(out.exists())
        self.assertTrue(checksum.exists())

        written = out.read_bytes()
        self.assertEqual(
            checksum.read_text(encoding="ascii"),
            f"{hashlib.sha256(written).hexdigest()}  update.json\n")
        self.assertEqual(
            json.loads(written)["artifacts"][0]["sha256"],
            hashlib.sha256(payload).hexdigest())

    def test_main_rejects_prerelease_pubspec_version(self):
        pubspec = self.directory / "pubspec.yaml"
        pubspec.write_text("name: valhalla\nversion: 1.2.3-rc1+42\n", encoding="utf-8")

        argv = ["generate_update_manifest.py", str(self.directory),
                "--pubspec", str(pubspec), "--source-commit", COMMIT]
        with mock.patch.object(sys, "argv", argv):
            with mock.patch.object(sys, "stderr"):
                with self.assertRaises(SystemExit):
                    manifest_module.main()

        self.assertFalse((self.directory / "update.json").exists())


class AndroidToolResolutionTests(unittest.TestCase):
    def test_android_tool_prefers_path_lookup(self):
        with mock.patch.object(manifest_module.shutil, "which",
                               return_value="/usr/bin/aapt"):
            self.assertEqual(manifest_module.android_tool("aapt"), "/usr/bin/aapt")

    def test_android_tool_falls_back_to_build_tools_directory(self):
        with tempfile.TemporaryDirectory(prefix="fake-sdk-") as sdk:
            for version in ("33.0.0", "34.0.0"):
                build_tools = Path(sdk, "build-tools", version)
                build_tools.mkdir(parents=True)
                (build_tools / "aapt").write_text("#!/bin/sh\n", encoding="utf-8")
            with mock.patch.object(manifest_module.shutil, "which", return_value=None):
                with mock.patch.dict(os.environ, {"ANDROID_HOME": sdk}, clear=False):
                    os.environ.pop("ANDROID_SDK_ROOT", None)
                    resolved = manifest_module.android_tool("aapt")
        self.assertIn("34.0.0", resolved)

    def test_android_tool_raises_when_sdk_is_absent(self):
        with mock.patch.object(manifest_module.shutil, "which", return_value=None):
            with mock.patch.dict(os.environ, {"ANDROID_HOME": "", "ANDROID_SDK_ROOT": ""},
                                 clear=False):
                with self.assertRaises(ValueError) as ctx:
                    manifest_module.android_tool("aapt")
        self.assertIn("aapt", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()