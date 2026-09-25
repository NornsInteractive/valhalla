#!/usr/bin/env python3
"""Exercise navigation on the isolated test server without clearing app data.

Select the disposable server in the app first. This is a navigation/lifecycle
soak, not a substitute for the individual functional acceptance cases.
"""
import argparse
import json
import pathlib
import re
import subprocess
import time
import xml.etree.ElementTree as ET

PACKAGE = "com.antigravity.valhalla.valhalla"
DUMP_PATH = "/sdcard/valhalla-soak.xml"
MORE_LABELS = ("更多功能", "More features", "More")
ROUTES = [
    ("仪表盘", "Dashboard"), ("智能会话", "AI Ops"),
    ("SSH终端", "Terminal"), ("远程文件", "SFTP Files"),
    ("容器管理", "Docker"), ("系统运维", "System"),
    ("快捷运维", "Commands"), ("系统设置", "Settings"),
    ("CLI 智能会话", "CLI Chat"), ("NAS 媒体库", "NAS Media"),
]


def matches(node, labels):
    return any(node.get("text") == label or node.get("content-desc") == label
               for label in labels)


def bounds(node):
    values = tuple(map(int, re.findall(r"-?\d+", node.get("bounds", ""))))
    return values if len(values) == 4 else (0, 0, 0, 0)


def dump_nodes(run):
    """Never read a previous dump, including when uiautomator exits 0 on error."""
    deadline = time.monotonic() + 28
    last_error = None

    def bounded(*command, **kwargs):
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError("UI dump exceeded its 28 second budget")
        return run(*command, timeout=min(8, remaining), **kwargs)

    for attempt in range(3):
        try:
            bounded("shell", "rm", "-f", DUMP_PATH)
            output = bounded("shell", "uiautomator", "dump", DUMP_PATH,
                             include_stderr=True)
            if (re.search(r"error:|could not get idle state|null root", output, re.I)
                    or not re.search(r"UI hier(?:archy|chary) dumped to:\s*"
                                     + re.escape(DUMP_PATH), output, re.I)):
                raise RuntimeError(f"uiautomator did not report success: {output[:300]}")
            bounded("shell", "test", "-s", DUMP_PATH)
            root = ET.fromstring(bounded("exec-out", "cat", DUMP_PATH))
            nodes = list(root.iter("node"))
            if root.tag != "hierarchy" or not nodes:
                raise ValueError("UI dump contains no hierarchy nodes")
            return nodes
        except (subprocess.SubprocessError, OSError, ValueError, ET.ParseError,
                RuntimeError) as error:
            last_error = error
            if attempt == 2 or time.monotonic() >= deadline:
                break
            time.sleep(min(0.25, max(0, deadline - time.monotonic())))
    raise RuntimeError(f"Fresh UI dump failed: {last_error}") from last_error


def require_route(nodes, route):
    # A drawer item or an unselected bottom-nav label is not proof of arrival.
    menus = [node for node in nodes if matches(node, MORE_LABELS)
             and node.get("package") == PACKAGE and node.get("clickable") == "true"]
    for menu in menus:
        _, top, right, bottom = bounds(menu)
        for node in nodes:
            left, y1, x2, y2 = bounds(node)
            if (matches(node, route) and node.get("package") == PACKAGE
                    and node.get("clickable") != "true"
                    and x2 > left >= right and top <= y1 < y2 <= bottom):
                return
    raise RuntimeError(f"Page title did not confirm route: {route[0]}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serial", default="192.168.1.145:14251")
    parser.add_argument("--expected-server", required=True)
    parser.add_argument("--minutes", type=float, default=30)
    parser.add_argument("--cycles", type=int, default=20)
    parser.add_argument("--output", type=pathlib.Path,
                        default=pathlib.Path("build/app-stability-validation/soak"))
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    adb = ["adb", "-s", args.serial]

    def run(*command, binary=False, timeout=35, include_stderr=False):
        result = subprocess.run(adb + list(command), check=True,
                                capture_output=True, timeout=timeout)
        output = result.stdout
        if include_stderr:
            output += b"\n" + result.stderr
        return output if binary else output.decode(errors="replace").strip()

    def nodes():
        return dump_nodes(run)

    def tap(labels):
        for node in nodes():
            if matches(node, labels) and node.get("clickable") == "true":
                x1, y1, x2, y2 = bounds(node)
                if x2 > x1 and y2 > y1:
                    run("shell", "input", "tap", str((x1+x2)//2), str((y1+y2)//2))
                    return
        raise RuntimeError(f"Visible control not found: {labels}")

    def navigate(route):
        tap(MORE_LABELS)
        tap(route)
        require_route(nodes(), route)

    pid = ""
    start = time.monotonic()
    cycle = 0
    samples = []
    result = {"serial": args.serial, "status": "running"}
    try:
        if run("get-state") != "device":
            raise RuntimeError("ADB device is not online")
        run("shell", "am", "start", "-n", f"{PACKAGE}/.MainActivity")
        navigate(ROUTES[0])
        if not any(matches(node, (args.expected_server,)) for node in nodes()):
            raise RuntimeError("Select the isolated test server first; existing servers are read-only")
        pid = run("shell", "pidof", PACKAGE)
        if not pid:
            raise RuntimeError("App process is not running")
        result["pid"] = pid
        start = time.monotonic()
        while cycle < args.cycles or time.monotonic() - start < args.minutes * 60:
            for route in ROUTES:
                navigate(route)
                if run("shell", "pidof", PACKAGE) != pid:
                    raise RuntimeError(f"Process changed while opening {route[0]}")
                with (args.output / "timeline.jsonl").open("a") as stream:
                    stream.write(json.dumps({"seconds": round(time.monotonic()-start, 1),
                                             "cycle": cycle, "route": route[0],
                                             "titleConfirmed": True}, ensure_ascii=False)+"\n")
            run("shell", "input", "keyevent", "KEYCODE_HOME")
            run("shell", "am", "start", "-n", f"{PACKAGE}/.MainActivity")
            info = run("shell", "dumpsys", "meminfo", PACKAGE)
            match = re.search(r"TOTAL PSS:\s+(\d+)", info)
            samples.append({"seconds": round(time.monotonic()-start),
                            "pssKiB": int(match[1]) if match else None})
            cycle += 1
            print(f"cycle={cycle} elapsed={time.monotonic()-start:.0f}s", flush=True)
        result["status"] = "navigation_completed_requires_log_review"
    except Exception as error:
        result.update(status="failed", error=str(error))
        raise
    finally:
        result.update(cycles=cycle, seconds=round(time.monotonic()-start), memory=samples)
        (args.output / "result.json").write_text(json.dumps(result, indent=2))
        for name, command in {
            "app-logcat": ("logcat", f"--pid={pid}", "-d", "-v", "threadtime"),
            "exit-info": ("shell", "dumpsys", "activity", "exit-info", PACKAGE),
            "last-anr": ("shell", "dumpsys", "activity", "lastanr"),
        }.items():
            if name == "app-logcat" and not pid:
                continue
            try:
                (args.output / f"{name}.txt").write_text(run(*command, timeout=10))
            except (subprocess.SubprocessError, OSError):
                pass  # Device loss is already recorded in result.json.


if __name__ == "__main__":
    main()
