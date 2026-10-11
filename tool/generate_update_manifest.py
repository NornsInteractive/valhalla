"""Create the public update manifest from verified, final release artifacts."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess


def android_tool(name):
    found = shutil.which(name)
    if found:
        return found
    root = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
    candidates = list(Path(root, "build-tools").glob(f"*/{name}")) if root else []
    if not candidates:
        raise ValueError(f"Android {name} is required to inspect APK identity")
    return str(max(candidates, key=lambda p: tuple(int(n) for n in re.findall(r"\d+", p.parent.name))))


def platform_for(name):
    value = name.lower()
    if not value.startswith("valhalla-"):
        return None
    match = re.search(r"-android-(armeabi-v7a|arm64-v8a|x86_64)(?:-signed-\d+)?\.apk$", value)
    if match:
        return "android", match[1]
    for platform, arch, suffix in (("windows", "x64", ".zip"), ("linux", "x64", ".tar.gz"),
                                   ("macos", "universal", ".zip")):
        if re.search(rf"-{platform}-{arch}(?:-unsigned)?(?:-\d+)?{re.escape(suffix)}$", value):
            return platform, arch
    return None


def manifest(directory, version, build, commit):
    if not re.fullmatch(r"\d+\.\d+\.\d+", version) or not 0 < build < 1000 or not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("Stable version, positive build number and full source commit are required")
    artifacts = []
    identities = set()
    for file in sorted(directory.iterdir()):
        target = platform_for(file.name)
        if target is None or not file.is_file():
            continue
        if file.is_symlink() or target in identities:
            raise ValueError(f"Ambiguous artifact: {file.name}")
        identities.add(target)
        with file.open("rb") as stream:
            digest = hashlib.file_digest(stream, "sha256").hexdigest()
        record = {"name": file.name, "platform": target[0], "architecture": target[1],
                  "size": file.stat().st_size, "sha256": digest}
        if record["size"] <= 0:
            raise ValueError(f"Empty artifact: {file.name}")
        if target[0] == "android":
            badging = subprocess.run([android_tool("aapt"), "dump", "badging", str(file)],
                                     check=True, capture_output=True, text=True).stdout
            identity = re.search(r"package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'", badging)
            if identity is None or identity[1] != "com.antigravity.valhalla.valhalla" or identity[3] != version:
                raise ValueError(f"APK identity mismatch: {file.name}")
            if int(identity[2]) % 1000 != build:
                raise ValueError(f"APK build number mismatch: {file.name}")
            output = subprocess.run([android_tool("apksigner"), "verify", "--print-certs", str(file)],
                                    check=True, capture_output=True, text=True).stdout
            certificates = set(re.findall(r"certificate SHA-256 digest: ([0-9a-fA-F]{64})", output))
            if len(certificates) != 1:
                raise ValueError(f"APK signer identity missing or ambiguous: {file.name}")
            record.update(androidVersionCode=int(identity[2]),
                          androidCertificateSha256=certificates.pop().lower())
        artifacts.append(record)
    if not artifacts:
        raise ValueError("No compatible release artifacts found")
    return {"schemaVersion": 1, "version": version, "buildNumber": build,
            "sourceCommit": commit, "artifacts": artifacts}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--pubspec", type=Path, default=Path("pubspec.yaml"))
    parser.add_argument("--source-commit", required=True)
    args = parser.parse_args()
    match = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$", args.pubspec.read_text(), re.MULTILINE)
    if match is None:
        parser.error("pubspec requires stable version+build")
    result = manifest(args.directory, match[1], int(match[2]), args.source_commit)
    output = args.directory / "update.json"
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (args.directory / "update.json.sha256").write_text(
        hashlib.sha256(output.read_bytes()).hexdigest() + "  update.json\n", encoding="ascii")


if __name__ == "__main__":
    main()
