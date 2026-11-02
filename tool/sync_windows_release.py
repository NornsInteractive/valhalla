#!/usr/bin/env python3
"""Wait for GitHub Actions Windows build, download artifacts (zip, msix, exe), update GitHub release and Yggdrasil."""
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.parse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TAG = "v1.0.38"
VERSION = "1.0.38"
BUILD = 39
APP = "com.norns.valhalla"
REPOSITORY = "NornsInteractive/valhalla"
MCP = "https://ygg.norns.cc.cd/api/mcp"


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()


def mcp(name: str, args: dict):
    headers = {"Content-Type": "application/json", "Accept": "application/json, text/event-stream"}
    if os.environ.get("YGG_TOKEN"):
        headers["Authorization"] = "Bearer " + os.environ["YGG_TOKEN"]
    body = {"jsonrpc": "2.0", "id": time.time_ns(), "method": "tools/call", "params": {"name": name, "arguments": args}}
    command = ["curl", "--fail-with-body", "--silent", "--show-error", "--max-time", "90", MCP]
    config = "".join("header = " + json.dumps(k + ": " + v) + "\n" for k, v in headers.items())
    payload = Path(f"/tmp/mcp-req-{time.time_ns()}.json")
    payload.write_text(json.dumps(body))
    try:
        command += ["--config", "-", "--data-binary", "@" + str(payload)]
        response = subprocess.run(command, input=config, capture_output=True, text=True)
        if response.returncode:
            raise RuntimeError(f"MCP HTTP transport failed: {response.stderr}")
        raw = response.stdout
        raw = json.loads(raw) if raw.lstrip().startswith("{") else next(
            json.loads(line[5:].strip()) for line in raw.splitlines() if line.startswith("data: {")
        )
        if raw.get("error") or raw.get("result", {}).get("isError"):
            raise RuntimeError(f"MCP error: {raw}")
        result = json.loads(next(c["text"] for c in raw["result"]["content"] if c["type"] == "text"))
        if result.get("error") or result.get("success") is False:
            raise RuntimeError(f"MCP business error: {result}")
        return result
    finally:
        payload.unlink(missing_ok=True)


def get_latest_run_id() -> str:
    out = subprocess.check_output(
        ["gh", "run", "list", "--workflow=windows-build.yml", "--limit=1", "--json=databaseId"],
        text=True,
    )
    runs = json.loads(out)
    if not runs:
        raise RuntimeError("No workflow runs found")
    return str(runs[0]["databaseId"])


def wait_for_run(run_id: str):
    print(f"Waiting for Windows build in run {run_id}...", flush=True)
    while True:
        raw = subprocess.check_output(
            ["gh", "run", "view", run_id, "--json", "jobs,runNumber,status,conclusion"],
            text=True,
        )
        data = json.loads(raw)
        run_number = str(data["runNumber"])
        jobs = data.get("jobs", [])
        win_job = next((j for j in jobs if j.get("name") == "Windows x64 release"), None)
        if not win_job:
            print(f"Waiting for Windows job to be scheduled in run {run_id}...", flush=True)
            time.sleep(15)
            continue

        status = win_job.get("status")
        conclusion = win_job.get("conclusion")
        steps = win_job.get("steps", [])
        current_step = next((s["name"] for s in reversed(steps) if s.get("status") == "in_progress"), "waiting")
        print(f"[{time.strftime('%X')}] Status: {status}, Conclusion: {conclusion}, Step: {current_step}", flush=True)

        if status == "completed":
            if conclusion != "success":
                raise RuntimeError(f"Windows build job failed with conclusion: {conclusion}")
            print(f"Windows build job succeeded! (run {run_number})", flush=True)
            return run_number

        time.sleep(20)


def sync_artifacts(run_id: str, run_number: str):
    artifact_dir = ROOT / "build" / f"windows-artifacts-v{VERSION}"
    if artifact_dir.exists():
        shutil.rmtree(artifact_dir)
    artifact_dir.mkdir(parents=True, exist_ok=True)

    artifact_name = f"valhalla-windows-x64-{run_number}"
    print(f"Downloading artifact {artifact_name}...", flush=True)
    subprocess.run(["gh", "run", "download", run_id, "-n", artifact_name, "-D", str(artifact_dir)], check=True)

    # Find all artifacts
    downloaded_files = list(artifact_dir.iterdir())
    print(f"Downloaded files: {[f.name for f in downloaded_files]}", flush=True)

    files_to_upload = []

    # Handle zip
    raw_zip = artifact_dir / f"valhalla-windows-x64-{run_number}.zip"
    if raw_zip.exists():
        actual_sha = sha256_file(raw_zip)
        raw_sha_file = artifact_dir / f"{raw_zip.name}.sha256"
        if raw_sha_file.exists():
            expected = raw_sha_file.read_text().split()[0].strip().lower()
            if actual_sha != expected:
                raise RuntimeError(f"ZIP SHA mismatch: {actual_sha} != {expected}")
        versioned_zip = artifact_dir / f"valhalla-v{VERSION}-windows-x64.zip"
        versioned_sha = artifact_dir / f"valhalla-v{VERSION}-windows-x64.zip.sha256"
        shutil.copy2(raw_zip, versioned_zip)
        versioned_sha.write_text(f"{actual_sha}  {versioned_zip.name}\n")
        files_to_upload.extend([versioned_zip, versioned_sha])

    # Handle msix
    for msix in artifact_dir.glob("*.msix"):
        actual_sha = sha256_file(msix)
        msix_sha_file = artifact_dir / f"{msix.name}.sha256"
        if msix_sha_file.exists():
            expected = msix_sha_file.read_text().split()[0].strip().lower()
            if actual_sha != expected:
                raise RuntimeError(f"MSIX SHA mismatch: {actual_sha} != {expected}")
        else:
            msix_sha_file.write_text(f"{actual_sha}  {msix.name}\n")
        files_to_upload.extend([msix, msix_sha_file])

    # Handle exe installer
    for exe in artifact_dir.glob("*.exe"):
        actual_sha = sha256_file(exe)
        exe_sha_file = artifact_dir / f"{exe.name}.sha256"
        if exe_sha_file.exists():
            expected = exe_sha_file.read_text().split()[0].strip().lower()
            if actual_sha != expected:
                raise RuntimeError(f"EXE SHA mismatch: {actual_sha} != {expected}")
        else:
            exe_sha_file.write_text(f"{actual_sha}  {exe.name}\n")
        files_to_upload.extend([exe, exe_sha_file])

    print(f"Files to upload to GitHub Release {TAG}: {[f.name for f in files_to_upload]}", flush=True)
    subprocess.run(
        ["gh", "release", "upload", TAG, *[str(f) for f in files_to_upload], "--repo", REPOSITORY, "--clobber"],
        check=True,
    )
    print("GitHub release assets uploaded successfully.", flush=True)

    # Update update.json and SHA256SUMS.txt
    evidence_dir = ROOT / "build" / "local-packages" / f"v{VERSION}-release" / "artifacts"
    if evidence_dir.exists():
        update_json_path = evidence_dir / "update.json"
        if update_json_path.exists():
            update_data = json.loads(update_json_path.read_text())
            # Keep non-windows or update windows
            existing_artifacts = [a for a in update_data.get("artifacts", []) if not (a.get("platform") == "windows" and a.get("architecture") == "x64")]
            for f in files_to_upload:
                if f.name.endswith(".zip") or f.name.endswith(".msix") or f.name.endswith(".exe"):
                    pkg_format = "msix" if f.name.endswith(".msix") else ("exe" if f.name.endswith(".exe") else "zip")
                    existing_artifacts.append({
                        "name": f.name,
                        "platform": "windows",
                        "architecture": "x64",
                        "format": pkg_format,
                        "size": f.stat().st_size,
                        "sha256": sha256_file(f),
                    })
            update_data["artifacts"] = existing_artifacts
            update_json_path.write_text(json.dumps(update_data, indent=2) + "\n")
            (evidence_dir / "update.json.sha256").write_text(f"{sha256_file(update_json_path)}  update.json\n")

            # Copy files to evidence dir
            for f in files_to_upload:
                shutil.copy2(f, evidence_dir / f.name)

            # Rebuild SHA256SUMS.txt
            primary_files = sorted(f for f in evidence_dir.iterdir() if f.is_file() and not f.name.endswith(".sha256") and f.name != "SHA256SUMS.txt")
            shasums_path = evidence_dir / "SHA256SUMS.txt"
            shasums_path.write_text("".join(f"{sha256_file(f)}  {f.name}\n" for f in primary_files))

            print("Uploading updated update.json and SHA256SUMS.txt...", flush=True)
            subprocess.run([
                "gh", "release", "upload", TAG,
                str(update_json_path),
                str(evidence_dir / "update.json.sha256"),
                str(shasums_path),
                "--repo", REPOSITORY,
                "--clobber"
            ], check=True)

    print("\nAll artifacts synced successfully!")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-id", default=None)
    args = parser.parse_args()

    os.chdir(ROOT)
    run_id = args.run_id or get_latest_run_id()
    run_number = wait_for_run(run_id)
    sync_artifacts(run_id, run_number)


if __name__ == "__main__":
    main()
