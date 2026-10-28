#!/usr/bin/env python3
"""Isolated stdlib unittest coverage for assets/runtime/acp_broker.py.

No production Agent, no real servers, no network ports. Each fixture owns a
temp HOME; every spawned PID is tracked and only those exact PIDs are killed.
"""
from __future__ import annotations

import base64
import hashlib
import importlib.util
import json
import os
import pathlib
import select
import signal
import sqlite3
import stat
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import unittest

BROKER = (
    pathlib.Path(__file__).resolve().parents[2]
    / "assets"
    / "runtime"
    / "acp_broker.py"
)
WORKSPACE_SOURCE = (
    pathlib.Path(__file__).resolve().parents[2]
    / "assets"
    / "runtime"
    / "workspace_store.py"
)

BROKER_SPEC = importlib.util.spec_from_file_location("acp_broker", BROKER)
acp_broker = importlib.util.module_from_spec(BROKER_SPEC)
BROKER_SPEC.loader.exec_module(acp_broker)

FAKE_AGENT = r'''
import json, os, sys, time

cfg = json.loads(sys.argv[1])
with open(cfg["pidFile"], "w") as handle:
    handle.write(str(os.getpid()))
    handle.flush()
    os.fsync(handle.fileno())


def emit(obj):
    sys.stdout.write(json.dumps(obj, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def bump(path):
    with open(path, "a") as handle:
        handle.write("x\n")
        handle.flush()


for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    frame = json.loads(line)
    method = frame.get("method")
    rpc_id = frame.get("id")
    if method == "initialize":
        emit({"jsonrpc": "2.0", "id": rpc_id,
              "result": {"protocolVersion": "v1"}})
    elif method == "session/new":
        emit({"jsonrpc": "2.0", "id": rpc_id,
              "result": {"sessionId": cfg["sessionId"]}})
    elif method == "session/prompt":
        bump(cfg["promptCountFile"])
        chunks = int(cfg.get("chunks", 0))
        delay = float(cfg.get("chunkDelay", 0.0))
        for index in range(chunks):
            emit({"jsonrpc": "2.0", "method": "session/update", "params": {
                "sessionId": cfg["sessionId"],
                "update": {
                    "sessionUpdate": "agent_message_chunk",
                    "content": {"type": "text", "text": "chunk-%d" % index},
                }}})
            if delay:
                time.sleep(delay)
        if cfg.get("permission"):
            emit({"jsonrpc": "2.0", "method": "session/request_permission",
                  "id": "perm-1", "params": {
                      "sessionId": cfg["sessionId"],
                      "toolCall": {"toolCallId": "call-1", "title": "test",
                                   "kind": "execute", "status": "pending"},
                      "options": [{"optionId": "allow", "name": "Allow",
                                   "kind": "allow_once"}]}})
            answered = False
            for response_line in sys.stdin:
                response_line = response_line.strip()
                if not response_line:
                    continue
                response = json.loads(response_line)
                if response.get("id") == "perm-1" and "method" not in response:
                    bump(cfg["permissionAnswerFile"])
                    answered = True
                    emit({"jsonrpc": "2.0", "id": rpc_id, "result": {
                        "stopReason": "end_turn",
                        "permissionAnswer": response.get("result")}})
                    if cfg.get("exitAfterPrompt"):
                        sys.exit(0)
                    break
            if not answered:
                break
        else:
            emit({"jsonrpc": "2.0", "id": rpc_id,
                  "result": {"stopReason": "end_turn"}})
            if cfg.get("exitAfterPrompt"):
                sys.exit(0)
    elif method is None and "id" in frame:
        bump(cfg["strayAnswerFile"])
'''


class BrokerTestCase(unittest.TestCase):
    def setUp(self):
        self._temp = tempfile.TemporaryDirectory(prefix="valhalla_acp_broker_")
        self.home = pathlib.Path(self._temp.name)
        self._old_home = os.environ.get("HOME")
        os.environ["HOME"] = str(self.home)
        self.spawned_pids: list[int] = []
        self.spawned_procs: list[subprocess.Popen] = []
        self.serve_pids: list[int] = []
        self.agent_pid_files: list[pathlib.Path] = []
        self.session_id = "sess-" + hashlib.sha256(
            self.home.name.encode()
        ).hexdigest()[:8]
        self.agent_script = self.home / "fake_acp_agent.py"
        self.agent_script.write_text(FAKE_AGENT)
        self.prompt_count_file = self.home / "prompts.count"
        self.permission_answer_file = self.home / "permission_answers.count"
        self.stray_answer_file = self.home / "stray_answers.count"
        self.key = hashlib.sha256(
            ("broker-test-" + self.home.name).encode()
        ).hexdigest()

    def tearDown(self):
        # Cleanup ONLY exact PIDs this fixture spawned or discovered via its
        # own journal/pidfile. Never pkill by pattern.
        for pid in reversed(self.spawned_pids):
            self._kill_exact(pid)
        for pid in reversed(self.serve_pids):
            self._kill_exact(pid)
        for proc in reversed(self.spawned_procs):
            self._stop_attach(proc)
        for pid_file in self.agent_pid_files:
            if pid_file.exists():
                try:
                    self._kill_exact(int(pid_file.read_text().strip()))
                except (ValueError, OSError):
                    pass
        if self._old_home is None:
            os.environ.pop("HOME", None)
        else:
            os.environ["HOME"] = self._old_home
        self._temp.cleanup()

    @staticmethod
    def _kill_exact(pid: int):
        try:
            os.kill(pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        except PermissionError:
            pass
        try:
            os.waitpid(pid, 0)
        except ChildProcessError:
            pass
        except OSError:
            pass

    @staticmethod
    def _close_proc_pipes(proc: subprocess.Popen):
        for stream in (proc.stdin, proc.stdout, proc.stderr):
            try:
                if stream is not None:
                    stream.close()
            except (OSError, ValueError):
                pass

    def _stop_attach(self, proc: subprocess.Popen, timeout: float = 5.0):
        try:
            proc.kill()
        except OSError:
            pass
        try:
            proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            try:
                proc.kill()
            except OSError:
                pass
            try:
                proc.wait(timeout=timeout)
            except (subprocess.TimeoutExpired, OSError):
                pass
        self._close_proc_pipes(proc)

    def _agent_config(self, *, chunks: int = 0, chunk_delay: float = 0.0,
                      permission: bool = False,
                      exit_after_prompt: bool = False) -> list:
        pid_file = self.home / ("agent-%d.pid" % len(self.agent_pid_files))
        self.agent_pid_files.append(pid_file)
        return [
            sys.executable,
            str(self.agent_script),
            json.dumps({
                "sessionId": self.session_id,
                "pidFile": str(pid_file),
                "promptCountFile": str(self.prompt_count_file),
                "permissionAnswerFile": str(self.permission_answer_file),
                "strayAnswerFile": str(self.stray_answer_file),
                "chunks": chunks,
                "chunkDelay": chunk_delay,
                "permission": permission,
                "exitAfterPrompt": exit_after_prompt,
            }),
        ]

    def _runtime_root(self) -> pathlib.Path:
        return self.home / ".local/share/valhalla/acp-runtime-v1"

    def _folder(self) -> pathlib.Path:
        return self._runtime_root() / self.key

    def _socket_path(self) -> pathlib.Path:
        return self._runtime_root() / (self.key[:24] + ".sock")

    def _start_attach(self, argv: list, after_seq: int = 0,
                      extra: dict | None = None) -> subprocess.Popen:
        config = {"key": self.key, "argv": argv, "afterSeq": after_seq}
        config.update(extra or {})
        payload = base64.b64encode(
            json.dumps(config, separators=(",", ":")).encode()
        ).decode()
        proc = subprocess.Popen(
            [sys.executable, str(BROKER), "attach", payload],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            bufsize=0,
            cwd=str(self.home),
            env={**os.environ, "HOME": str(self.home)},
        )
        self.spawned_pids.append(proc.pid)
        self.spawned_procs.append(proc)
        return proc

    def _send(self, proc: subprocess.Popen, frame: dict, turn_id: str | None = None):
        command = {"frame": frame}
        if turn_id is not None:
            command["turnId"] = turn_id
        line = json.dumps(command, separators=(",", ":")) + "\n"
        proc.stdin.write(line.encode())
        proc.stdin.flush()

    def _read_frames(self, proc: subprocess.Popen, predicate, timeout: float = 12.0):
        frames = []
        deadline = time.time() + timeout
        while time.time() < deadline:
            remaining = max(0.0, deadline - time.time())
            ready, _, _ = select.select([proc.stdout], [], [], remaining)
            if not ready:
                break
            raw = proc.stdout.readline()
            if not raw:
                break
            frame = json.loads(raw)
            frames.append(frame)
            if predicate(frame):
                return frames
        raise AssertionError(
            "timed out waiting for frame; saw %d frames: %r" % (len(frames), frames)
        )

    def _read_until_caught_up(self, proc: subprocess.Popen, timeout: float = 12.0):
        return self._read_frames(
            proc, lambda f: f.get("type") == "caught_up", timeout=timeout
        )

    def _collect_frames(self, proc: subprocess.Popen, timeout: float = 2.0):
        frames = []
        deadline = time.time() + timeout
        while time.time() < deadline:
            remaining = max(0.0, deadline - time.time())
            ready, _, _ = select.select([proc.stdout], [], [], remaining)
            if not ready:
                break
            raw = proc.stdout.readline()
            if not raw:
                break
            try:
                frames.append(json.loads(raw))
            except json.JSONDecodeError:
                break
        return frames

    def _journal_meta(self, key_field: str):
        db_path = self._folder() / "journal.sqlite3"
        self.assertTrue(db_path.exists(), "journal missing at %s" % db_path)
        conn = sqlite3.connect(db_path)
        try:
            row = conn.execute(
                "SELECT value FROM meta WHERE key=?", (key_field,)
            ).fetchone()
        finally:
            conn.close()
        return json.loads(row[0]) if row else None

    def _folder_for_key(self, key: str) -> pathlib.Path:
        return self._runtime_root() / key

    def _handshake_attach(self, proc: subprocess.Popen, key: str, rpc_prefix: str = "init"):
        self._send(proc, {
            "jsonrpc": "2.0", "id": rpc_prefix + "-init", "method": "initialize",
            "params": {},
        })
        self._read_frames(
            proc,
            lambda f: f.get("type") == "frame"
            and f.get("frame", {}).get("id") == rpc_prefix + "-init",
        )
        self._send(proc, {
            "jsonrpc": "2.0", "id": rpc_prefix + "-new", "method": "session/new",
            "params": {},
        })
        self._read_frames(
            proc,
            lambda f: f.get("type") == "frame"
            and f.get("frame", {}).get("id") == rpc_prefix + "-new",
        )

    def _send_attach(self, proc: subprocess.Popen, frame: dict, turn_id: str | None = None):
        command = {"frame": frame}
        if turn_id is not None:
            command["turnId"] = turn_id
        line = json.dumps(command, separators=(",", ":")) + "\n"
        proc.stdin.write(line.encode())
        proc.stdin.flush()

    def _wait_attach_meta(self, key: str, key_field: str, expected, timeout: float = 12.0):
        folder = self._folder_for_key(key)
        deadline = time.time() + timeout
        last = None
        while time.time() < deadline:
            db_path = folder / "journal.sqlite3"
            if db_path.exists():
                conn = sqlite3.connect(db_path)
                try:
                    row = conn.execute(
                        "SELECT value FROM meta WHERE key=?", (key_field,)
                    ).fetchone()
                    last = json.loads(row[0]) if row else None
                finally:
                    conn.close()
            if last == expected:
                return last
            time.sleep(0.05)
        raise AssertionError(
            "meta %s for key %s never became %r (last=%r)" % (key_field, key[:8], expected, last)
        )

    def _journal_events(self) -> list[dict]:
        db_path = self._folder() / "journal.sqlite3"
        self.assertTrue(db_path.exists(), "journal missing at %s" % db_path)
        conn = sqlite3.connect(db_path)
        try:
            rows = conn.execute("SELECT payload FROM events ORDER BY seq").fetchall()
        finally:
            conn.close()
        return [json.loads(row[0]) for row in rows]

    def _event_count(self) -> int:
        db_path = self._folder() / "journal.sqlite3"
        if not db_path.exists():
            return 0
        conn = sqlite3.connect(db_path)
        try:
            return conn.execute("SELECT COUNT(*) FROM events").fetchone()[0]
        finally:
            conn.close()

    def _backdate_finished_at(self, seconds_ago: float):
        db_path = self._folder() / "journal.sqlite3"
        self.assertTrue(db_path.exists(), "journal missing at %s" % db_path)
        conn = sqlite3.connect(db_path)
        try:
            value = json.dumps(time.time() - seconds_ago)
            conn.execute(
                "INSERT OR REPLACE INTO meta VALUES(?,?)", ("finishedAt", value)
            )
            conn.commit()
        finally:
            conn.close()

    def _set_meta_sqlite(self, key: str, value):
        db_path = self._folder() / "journal.sqlite3"
        self.assertTrue(db_path.exists(), "journal missing at %s" % db_path)
        conn = sqlite3.connect(db_path)
        try:
            conn.execute(
                "INSERT OR REPLACE INTO meta VALUES(?,?)", (key, json.dumps(value))
            )
            conn.commit()
        finally:
            conn.close()

    def _wait_meta(self, key_field: str, expected, timeout: float = 12.0):
        deadline = time.time() + timeout
        last = None
        while time.time() < deadline:
            last = self._journal_meta(key_field)
            if last == expected:
                return last
            time.sleep(0.05)
        raise AssertionError(
            "meta %s never became %r (last=%r)" % (key_field, expected, last)
        )

    def _meta_for_key(self, key: str, key_field: str):
        db_path = self._folder_for_key(key) / "journal.sqlite3"
        self.assertTrue(db_path.exists(), "journal missing at %s" % db_path)
        conn = sqlite3.connect(db_path)
        try:
            row = conn.execute(
                "SELECT value FROM meta WHERE key=?", (key_field,)
            ).fetchone()
        finally:
            conn.close()
        return json.loads(row[0]) if row else None

    def _serve_pid_for_key(self, key: str) -> int:
        pid = self._meta_for_key(key, "pid")
        self.assertIsInstance(pid, int)
        self.serve_pids.append(pid)
        return pid

    def _serve_pid(self) -> int:
        pid = self._journal_meta("pid")
        self.assertIsInstance(pid, int)
        self.serve_pids.append(pid)
        return pid

    def _shutdown_direct_broker(self, broker):
        try:
            broker.stop_agent()
        finally:
            broker.agent_reader.join(timeout=10.0)
            reader_alive = broker.agent_reader.is_alive()
            broker.release_scope()
            try:
                broker.server.close()
            except OSError:
                pass
            try:
                os.unlink(broker.socket_path)
            except FileNotFoundError:
                pass
            with broker.lock:
                broker.db.close()
                broker.lock_file.close()
        self.assertFalse(reader_alive, "broker.agent_reader still alive after stop")

    def _make_v1_runtime(self, key: str, *, state: str, pid: int,
                         argv: list | None = None,
                         server_scope: str | None = None,
                         child_identity: dict | None = None,
                         extra_meta: dict | None = None) -> pathlib.Path:
        folder = self._runtime_root() / key
        folder.mkdir(parents=True, mode=0o700, exist_ok=True)
        config = {
            "key": key,
            "argv": argv or [sys.executable, "-c", "pass"],
            "launchIdentity": "v1-identity",
        }
        if server_scope is not None:
            config["serverScope"] = server_scope
        (folder / "config.json").write_text(json.dumps(config))
        conn = sqlite3.connect(folder / "journal.sqlite3")
        try:
            conn.execute(
                "CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)"
            )
            conn.execute(
                "INSERT INTO meta VALUES('state',?)", (json.dumps(state),)
            )
            conn.execute(
                "INSERT INTO meta VALUES('pid',?)", (json.dumps(pid),)
            )
            if child_identity is not None:
                conn.execute(
                    "INSERT INTO meta VALUES('childIdentity',?)",
                    (json.dumps(child_identity),),
                )
            for meta_key, meta_value in (extra_meta or {}).items():
                conn.execute(
                    "INSERT INTO meta VALUES(?,?)",
                    (meta_key, json.dumps(meta_value)),
                )
            conn.commit()
        finally:
            conn.close()
        return folder

    def _spawn_fixture(self, argv: list, *, new_session: bool = True) -> subprocess.Popen:
        proc = subprocess.Popen(
            argv,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=new_session,
        )
        self.spawned_pids.append(proc.pid)
        self.spawned_procs.append(proc)
        return proc

    @staticmethod
    def _identity_for_child(proc: subprocess.Popen) -> dict:
        identity = acp_broker.process_identity(proc.pid)
        if identity is None:
            raise AssertionError("fixture process %d has no identity" % proc.pid)
        return {key: identity[key] for key in ("pid", "group", "started")}

    def _fake_serve_argv(self, folder: pathlib.Path) -> list:
        return [
            sys.executable,
            "-c",
            "import time; time.sleep(60)",
            "serve",
            str(folder),
        ]

    def _assert_alive(self, pid: int):
        os.kill(pid, 0)

    def _assert_dead(self, pid: int, timeout: float = 5.0):
        deadline = time.time() + timeout
        while time.time() < deadline:
            try:
                os.kill(pid, 0)
            except ProcessLookupError:
                return
            time.sleep(0.05)
        raise AssertionError("pid %d still alive" % pid)

    def _assert_no_live_process(self, pid: int, timeout: float = 5.0):
        deadline = time.time() + timeout
        while time.time() < deadline:
            if acp_broker.process_identity(pid) is None:
                return
            time.sleep(0.05)
        raise AssertionError("pid %d still has a live process identity" % pid)

    def _wait_file(self, path: pathlib.Path, timeout: float = 5.0):
        deadline = time.time() + timeout
        while time.time() < deadline:
            if path.exists():
                return
            time.sleep(0.02)
        raise AssertionError("fixture file %s never appeared" % path)

    def _count_lines(self, path: pathlib.Path) -> int:
        if not path.exists():
            return 0
        return len([line for line in path.read_text().splitlines() if line])

    def _handshake(self, proc: subprocess.Popen, rpc_prefix: str):
        self._send(proc, {
            "jsonrpc": "2.0", "id": rpc_prefix + "-init", "method": "initialize",
            "params": {},
        })
        self._read_frames(
            proc,
            lambda f: f.get("type") == "frame"
            and f.get("frame", {}).get("id") == rpc_prefix + "-init",
        )
        self._send(proc, {
            "jsonrpc": "2.0", "id": rpc_prefix + "-new", "method": "session/new",
            "params": {},
        })
        self._read_frames(
            proc,
            lambda f: f.get("type") == "frame"
            and f.get("frame", {}).get("id") == rpc_prefix + "-new",
        )

    def _chunk_text(self, frame: dict):
        update = (
            frame.get("frame", {}).get("params", {}).get("update", {})
        )
        content = update.get("content") or {}
        return content.get("text")

    def _is_chunk_event(self, frame: dict, text: str) -> bool:
        return (
            frame.get("type") == "frame"
            and "seq" in frame
            and frame.get("frame", {}).get("method") == "session/update"
            and self._chunk_text(frame) == text
        )

    def _is_turn_event(self, frame: dict) -> bool:
        return frame.get("type") == "turn" and "seq" in frame

    def test_permissions_paths_are_0700_and_0600(self):
        argv = self._agent_config(chunks=0)
        proc = self._start_attach(argv)
        self._handshake(proc, "path")
        self._wait_meta("state", "ready")
        self._serve_pid()
        root = self._runtime_root()
        folder = self._folder()
        config_file = folder / "config.json"
        socket_path = self._socket_path()
        self.assertTrue(root.is_dir())
        self.assertTrue(folder.is_dir())
        self.assertTrue(config_file.is_file())
        self.assertTrue(socket_path.exists())
        self.assertEqual(stat.S_IMODE(root.stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE(folder.stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE(config_file.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(socket_path.stat().st_mode), 0o600)
        self._stop_attach(proc)

    def test_timed_chunks_survive_attach_death_and_reconnect_cursor(self):
        argv = self._agent_config(chunks=4, chunk_delay=0.25)
        proc = self._start_attach(argv)
        self._handshake(proc, "live")
        self._send(proc, {
            "jsonrpc": "2.0", "id": "live-prompt", "method": "session/prompt",
            "params": {"sessionId": self.session_id, "prompt": [{"type": "text", "text": "go"}]},
        }, turn_id="turn-chunks")
        # Wait for the first journaled chunk, then kill the attach client while
        # the fake ACP worker is still emitting timed chunks.
        seen = self._read_frames(proc, lambda f: self._is_chunk_event(f, "chunk-0"))
        cursor = seen[-1]["seq"]
        serve_pid = self._serve_pid()
        self._stop_attach(proc)
        # Closing attach must not stop the worker.
        self._assert_alive(serve_pid)
        self._wait_meta("state", "completed")
        self.assertEqual(self._journal_meta("turnId"), "turn-chunks")
        self.assertGreaterEqual(cursor, 1)

        # Reconnect after the cursor observed mid-stream: only the missing
        # frames are replayed.
        proc2 = self._start_attach(argv, after_seq=cursor)
        frames = self._read_until_caught_up(proc2)
        chunk_texts = [
            self._chunk_text(f) for f in frames if self._is_chunk_event(f, self._chunk_text(f) or "")
        ]
        self.assertEqual(chunk_texts, ["chunk-1", "chunk-2", "chunk-3"])
        self.assertTrue(any(self._is_turn_event(f) for f in frames))
        self.assertFalse(any(self._is_chunk_event(f, "chunk-0") for f in frames))
        for frame in frames:
            if "seq" in frame:
                self.assertGreater(frame["seq"], cursor)
        self.assertEqual(self._count_lines(self.prompt_count_file), 1)
        self._stop_attach(proc2)

    def test_prompt_idempotency_with_turn_id(self):
        argv = self._agent_config(chunks=1, chunk_delay=0.05)
        proc = self._start_attach(argv)
        self._handshake(proc, "idem")
        self._serve_pid()
        prompt = {
            "jsonrpc": "2.0", "id": "idem-prompt-1", "method": "session/prompt",
            "params": {"sessionId": self.session_id, "prompt": [{"type": "text", "text": "one"}]},
        }
        self._send(proc, prompt, turn_id="turn-idem")
        frames = self._read_frames(
            proc,
            lambda f: f.get("type") == "frame"
            and f.get("turnId") == "turn-idem"
            and f.get("frame", {}).get("id") == "idem-prompt-1"
            and "result" in f.get("frame", {}),
        )
        self.assertTrue(any(
            f.get("type") == "frame"
            and f.get("turnId") == "turn-idem"
            and f.get("frame", {}).get("id") == "idem-prompt-1"
            and "result" in f.get("frame", {})
            for f in frames
        ), frames)
        self.assertEqual(self._count_lines(self.prompt_count_file), 1)
        self._stop_attach(proc)

        # Same turnId + same params on a fresh attach replays the stored
        # result; the fake ACP subprocess is never prompted a second time.
        proc2 = self._start_attach(argv)
        self._send(proc2, {
            "jsonrpc": "2.0", "id": "idem-prompt-2", "method": "session/prompt",
            "params": {"sessionId": self.session_id, "prompt": [{"type": "text", "text": "one"}]},
        }, turn_id="turn-idem")
        frames = self._read_frames(
            proc2,
            lambda f: f.get("type") == "frame"
            and f.get("turnId") == "turn-idem"
            and f.get("frame", {}).get("id") == "idem-prompt-2"
            and "result" in f.get("frame", {}),
        )
        replayed_candidates = [
            f for f in frames
            if f.get("type") == "frame"
            and f.get("turnId") == "turn-idem"
            and f.get("frame", {}).get("id") == "idem-prompt-2"
        ]
        self.assertTrue(replayed_candidates, frames)
        replayed = replayed_candidates[-1]["frame"]
        self.assertIn("result", replayed)
        self.assertEqual(replayed["result"].get("stopReason"), "end_turn")
        self.assertEqual(self._count_lines(self.prompt_count_file), 1)
        self.assertEqual(self._count_lines(self.stray_answer_file), 0)

        # A different prompt under the same turnId is an explicit conflict,
        # not a silent second run and not a silent replay.
        self._send(proc2, {
            "jsonrpc": "2.0", "id": "idem-prompt-3", "method": "session/prompt",
            "params": {"sessionId": self.session_id, "prompt": [{"type": "text", "text": "different"}]},
        }, turn_id="turn-idem")
        conflict_frames = self._read_frames(
            proc2,
            lambda f: f.get("type") == "runtime_error"
            and "IDEMPOTENCY_CONFLICT" in f.get("error", ""),
        )
        conflict = [f for f in conflict_frames if f.get("type") == "runtime_error" and "IDEMPOTENCY_CONFLICT" in f.get("error", "")]
        self.assertTrue(conflict, conflict_frames)
        self.assertIn("ACP_RUNTIME_IDEMPOTENCY_CONFLICT", conflict[-1]["error"])
        self.assertEqual(self._count_lines(self.prompt_count_file), 1)
        self._stop_attach(proc2)

    def test_permission_pending_across_detach_with_single_explicit_answer(self):
        argv = self._agent_config(chunks=1, chunk_delay=0.05, permission=True)
        proc = self._start_attach(argv)
        self._handshake(proc, "perm")
        self._send(proc, {
            "jsonrpc": "2.0", "id": "perm-prompt", "method": "session/prompt",
            "params": {"sessionId": self.session_id, "prompt": [{"type": "text", "text": "run"}]},
        }, turn_id="turn-perm")
        self._read_frames(
            proc,
            lambda f: f.get("type") == "frame"
            and f.get("frame", {}).get("method") == "session/request_permission"
            and f.get("frame", {}).get("id") == "perm-1",
        )
        self._wait_meta("state", "waiting_permission")
        serve_pid = self._serve_pid()

        # Detach while the permission is pending; the worker must keep waiting.
        self._stop_attach(proc)
        self._assert_alive(serve_pid)
        self.assertEqual(self._journal_meta("state"), "waiting_permission")
        self.assertEqual(self._count_lines(self.permission_answer_file), 0)

        # Reconnect: the pending permission is still on the worker. It is
        # visible as a journaled frame and redelivered after catch-up.
        proc2 = self._start_attach(argv)
        frames = self._read_frames(
            proc2,
            lambda f: f.get("type") == "frame"
            and f.get("frame", {}).get("method") == "session/request_permission"
            and f.get("frame", {}).get("id") == "perm-1",
        )
        self.assertEqual(frames[-1].get("turnId"), "turn-perm")
        self._read_until_caught_up(proc2)

        # One explicit answer is forwarded exactly once. The prompt waiter may
        # still belong to the dead first attach; the durable turn event is what
        # a reconnecting client observes.
        self._send(proc2, {
            "jsonrpc": "2.0", "id": "perm-1",
            "result": {"outcome": {"outcome": "selected", "optionId": "allow"}},
        })
        self._read_frames(
            proc2,
            lambda f: f.get("type") == "turn"
            and f.get("state") == "completed"
            and f.get("turnId") == "turn-perm",
        )
        self._wait_meta("state", "completed")
        self.assertEqual(self._count_lines(self.permission_answer_file), 1)

        # A second answer for the same permission id must not reach the agent.
        self._send(proc2, {
            "jsonrpc": "2.0", "id": "perm-1",
            "result": {"outcome": {"outcome": "selected", "optionId": "allow"}},
        })
        time.sleep(0.3)
        self.assertEqual(self._count_lines(self.permission_answer_file), 1)
        self._stop_attach(proc2)

    def test_dead_process_fails_attach_without_restart(self):
        argv = self._agent_config(chunks=0)
        proc = self._start_attach(argv)
        self._handshake(proc, "dead")
        serve_pid = self._serve_pid()
        self._assert_alive(serve_pid)
        self._stop_attach(proc)

        os.kill(serve_pid, signal.SIGKILL)
        self._assert_dead(serve_pid)
        self.assertEqual(self._journal_meta("pid"), serve_pid)

        payload = base64.b64encode(json.dumps({
            "key": self.key, "argv": argv, "afterSeq": 0,
        }, separators=(",", ":")).encode()).decode()
        result = subprocess.run(
            [sys.executable, str(BROKER), "attach", payload],
            capture_output=True,
            text=True,
            timeout=15,
            env={**os.environ, "HOME": str(self.home)},
            input="",
        )
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("ACP_RUNTIME_PROCESS_EXITED", result.stdout)
        # No restart: the recorded serve pid stays dead and no new serve pid
        # replaces it in the journal.
        self._assert_dead(serve_pid)
        self.assertEqual(self._journal_meta("pid"), serve_pid)
        self.assertEqual(self._count_lines(self.prompt_count_file), 0)

    def test_closing_attach_does_not_stop_worker(self):
        argv = self._agent_config(chunks=0)
        proc = self._start_attach(argv)
        self._handshake(proc, "close")
        serve_pid = self._serve_pid()
        self._stop_attach(proc)
        self._assert_alive(serve_pid)

        proc2 = self._start_attach(argv)
        self._handshake(proc2, "close2")
        self._send(proc2, {
            "jsonrpc": "2.0", "id": "close-prompt", "method": "session/prompt",
            "params": {"sessionId": self.session_id, "prompt": [{"type": "text", "text": "after-close"}]},
        }, turn_id="turn-close")
        self._read_frames(
            proc2,
            lambda f: f.get("type") == "frame"
            and f.get("frame", {}).get("id") == "close-prompt"
            and "result" in f.get("frame", {}),
        )
        self.assertEqual(self._count_lines(self.prompt_count_file), 1)
        self._stop_attach(proc2)



    def test_session_cancel_while_pending_permission_ends_cancelled(self):
        argv = self._agent_config(chunks=1, chunk_delay=0.05, permission=True)
        proc = self._start_attach(argv)
        self._handshake(proc, "cancelperm")
        self._serve_pid()
        self._send(proc, {
            "jsonrpc": "2.0", "id": "cp-prompt", "method": "session/prompt",
            "params": {"sessionId": self.session_id, "prompt": [{"type": "text", "text": "run"}]},
        }, turn_id="turn-cancelperm")
        self._read_frames(
            proc,
            lambda f: f.get("type") == "frame"
            and f.get("frame", {}).get("method") == "session/request_permission"
            and f.get("frame", {}).get("id") == "perm-1",
        )
        self._wait_meta("state", "waiting_permission")

        # Explicit cancel while permission is pending.
        self._send(proc, {"jsonrpc": "2.0", "method": "session/cancel", "params": {}})
        self._read_frames(
            proc,
            lambda f: f.get("type") == "turn"
            and f.get("state") == "cancelled"
            and f.get("turnId") == "turn-cancelperm",
        )
        self._wait_meta("state", "cancelled")
        self.assertEqual(self._count_lines(self.permission_answer_file), 1)

        # A later answer for the same permission id must not reach the agent.
        self._send(proc, {
            "jsonrpc": "2.0", "id": "perm-1",
            "result": {"outcome": {"outcome": "selected", "optionId": "allow"}},
        })
        time.sleep(0.3)
        self.assertEqual(self._count_lines(self.permission_answer_file), 1)
        self._stop_attach(proc)

    def test_terminal_turn_journal_precedes_prompt_rpc_response(self):
        argv = self._agent_config(chunks=0)
        proc = self._start_attach(argv)
        self._handshake(proc, "order")
        self._serve_pid()
        self._send(proc, {
            "jsonrpc": "2.0", "id": "order-prompt", "method": "session/prompt",
            "params": {"sessionId": self.session_id, "prompt": [{"type": "text", "text": "go"}]},
        }, turn_id="turn-order")
        frames = self._read_frames(
            proc,
            lambda f: f.get("type") == "frame"
            and f.get("frame", {}).get("id") == "order-prompt"
            and "result" in f.get("frame", {}),
        )
        self.assertTrue(any(
            f.get("type") == "frame"
            and f.get("frame", {}).get("id") == "order-prompt"
            and "result" in f.get("frame", {})
            for f in frames
        ), frames)
        turn_idx = next(
            i for i, f in enumerate(frames) if f.get("type") == "turn"
        )
        resp_idx = next(
            i for i, f in enumerate(frames)
            if f.get("type") == "frame"
            and f.get("frame", {}).get("id") == "order-prompt"
            and "result" in f.get("frame", {})
        )
        self.assertLess(turn_idx, resp_idx)
        self._stop_attach(proc)

    def test_completed_agent_exit_does_not_become_failed_or_exited(self):
        argv = self._agent_config(chunks=0, exit_after_prompt=True)
        proc = self._start_attach(argv)
        self._handshake(proc, "exit")
        self._serve_pid()
        self._send(proc, {
            "jsonrpc": "2.0", "id": "exit-prompt", "method": "session/prompt",
            "params": {"sessionId": self.session_id, "prompt": [{"type": "text", "text": "go"}]},
        }, turn_id="turn-exit")
        frames = self._read_frames(
            proc,
            lambda f: f.get("type") == "frame"
            and f.get("frame", {}).get("id") == "exit-prompt"
            and "result" in f.get("frame", {}),
        )
        self.assertTrue(any(
            f.get("type") == "frame"
            and f.get("frame", {}).get("id") == "exit-prompt"
            and "result" in f.get("frame", {})
            for f in frames
        ), frames)
        deadline = time.time() + 5
        while time.time() < deadline and self._journal_meta("agentExited") is not True:
            time.sleep(0.1)
        self.assertTrue(self._journal_meta("agentExited"))
        self.assertEqual(self._journal_meta("state"), "completed")
        turn_states = [
            e.get("state") for e in self._journal_events() if e.get("type") == "turn"
        ]
        self.assertEqual(turn_states, ["completed"])
        self._stop_attach(proc)

    def test_expired_retention_clears_events_and_turn_result_after_7d(self):
        argv = self._agent_config(chunks=0)
        proc = self._start_attach(argv)
        self._handshake(proc, "ret")
        self._send(proc, {
            "jsonrpc": "2.0", "id": "ret-prompt", "method": "session/prompt",
            "params": {"sessionId": self.session_id, "prompt": [{"type": "text", "text": "go"}]},
        }, turn_id="turn-ret")
        ret_frames = self._read_frames(
            proc,
            lambda f: f.get("type") == "frame"
            and f.get("frame", {}).get("id") == "ret-prompt"
            and "result" in f.get("frame", {}),
        )
        self.assertTrue(any(
            f.get("type") == "frame"
            and f.get("frame", {}).get("id") == "ret-prompt"
            and "result" in f.get("frame", {})
            for f in ret_frames
        ), ret_frames)
        self._wait_meta("state", "completed")
        turn_key = "turn:turn-ret"
        self.assertIsNotNone(self._journal_meta(turn_key))

        self._backdate_finished_at(8 * 86400)
        deadline = time.time() + 8
        last = None
        while time.time() < deadline:
            last = self._journal_meta("state")
            if last == "expired":
                break
            time.sleep(0.2)
        self.assertEqual(last, "expired")
        self.assertEqual(self._event_count(), 0)
        self.assertIsNone(self._journal_meta(turn_key))
        self._stop_attach(proc)

    def test_expired_retention_does_not_expire_waiting_task(self):
        argv = self._agent_config(chunks=0, permission=True)
        proc = self._start_attach(argv)
        self._handshake(proc, "waitret")
        self._send(proc, {
            "jsonrpc": "2.0", "id": "waitret-prompt", "method": "session/prompt",
            "params": {"sessionId": self.session_id, "prompt": [{"type": "text", "text": "run"}]},
        }, turn_id="turn-waitret")
        self._read_frames(
            proc,
            lambda f: f.get("type") == "frame"
            and f.get("frame", {}).get("method") == "session/request_permission"
            and f.get("frame", {}).get("id") == "perm-1",
        )
        self._wait_meta("state", "waiting_permission")
        serve_pid = self._journal_meta("pid")
        self.serve_pids.append(serve_pid)
        events_before = self._event_count()

        self._backdate_finished_at(8 * 86400)
        time.sleep(2.0)
        self.assertEqual(self._journal_meta("state"), "waiting_permission")
        self.assertGreaterEqual(self._event_count(), events_before)

        self._kill_exact(serve_pid)
        self._stop_attach(proc)

    def test_expired_retention_does_not_expire_running_task(self):
        argv = self._agent_config(chunks=1, chunk_delay=5.0)
        proc = self._start_attach(argv)
        self._handshake(proc, "runret")
        self._send(proc, {
            "jsonrpc": "2.0", "id": "runret-prompt", "method": "session/prompt",
            "params": {"sessionId": self.session_id, "prompt": [{"type": "text", "text": "go"}]},
        }, turn_id="turn-runret")
        self._wait_meta("state", "running")
        serve_pid = self._journal_meta("pid")
        self.serve_pids.append(serve_pid)
        events_before = self._event_count()

        self._backdate_finished_at(8 * 86400)
        time.sleep(1.5)
        self.assertEqual(self._journal_meta("state"), "running")
        self.assertGreaterEqual(self._event_count(), events_before)

        self._kill_exact(serve_pid)
        self._stop_attach(proc)

    def test_inspect_reports_runtime_status(self):
        argv = self._agent_config(chunks=0)
        proc = self._start_attach(argv)
        self._handshake(proc, "inspect")
        self._wait_meta("state", "ready")
        serve_pid = self._serve_pid()
        self._stop_attach(proc)

        payload = base64.b64encode(json.dumps({
            "key": self.key, "action": "inspect"
        }, separators=(",", ":")).encode()).decode()
        result = subprocess.run(
            [sys.executable, str(BROKER), "manage", payload],
            capture_output=True, text=True, timeout=10,
            env={**os.environ, "HOME": str(self.home)},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        status = json.loads(result.stdout.strip())
        self.assertEqual(status["runtimeKey"], self.key)
        self.assertEqual(status["state"], "ready")
        self.assertTrue(status["alive"])
        self.assertEqual(status["protocolVersion"], 2)
        self.assertEqual(status["sessionId"], self.session_id)
        self._kill_exact(serve_pid)

    def test_inspect_missing_runtime_returns_missing_state(self):
        fake_key = "0" * 64
        payload = base64.b64encode(json.dumps({
            "key": fake_key, "action": "inspect"
        }, separators=(",", ":")).encode()).decode()
        result = subprocess.run(
            [sys.executable, str(BROKER), "manage", payload],
            capture_output=True, text=True, timeout=10,
            env={**os.environ, "HOME": str(self.home)},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        status = json.loads(result.stdout.strip())
        self.assertEqual(status["runtimeKey"], fake_key)
        self.assertEqual(status["state"], "missing")

    def test_retire_idempotent_on_missing_runtime(self):
        fake_key = "1" * 64
        payload = base64.b64encode(json.dumps({
            "key": fake_key, "action": "retire", "stopRunning": True
        }, separators=(",", ":")).encode()).decode()
        result = subprocess.run(
            [sys.executable, str(BROKER), "manage", payload],
            capture_output=True, text=True, timeout=10,
            env={**os.environ, "HOME": str(self.home)},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        status = json.loads(result.stdout.strip())
        self.assertEqual(status["runtimeKey"], fake_key)
        self.assertEqual(status["state"], "missing")

    def test_retire_running_requires_stop_running(self):
        argv = self._agent_config(chunks=1, chunk_delay=0.2)
        proc = self._start_attach(argv)
        self._handshake(proc, "retirebusy")
        self._send(proc, {
            "jsonrpc": "2.0", "id": "retire-prompt", "method": "session/prompt",
            "params": {"sessionId": self.session_id, "prompt": [{"type": "text", "text": "go"}]},
        }, turn_id="turn-retirebusy")
        self._wait_meta("state", "running")

        payload = base64.b64encode(json.dumps({
            "key": self.key, "action": "retire", "stopRunning": False
        }, separators=(",", ":")).encode()).decode()
        result = subprocess.run(
            [sys.executable, str(BROKER), "manage", payload],
            capture_output=True, text=True, timeout=10,
            env={**os.environ, "HOME": str(self.home)},
        )
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("ACP_RUNTIME_TURN_IN_PROGRESS", result.stdout)

        payload = base64.b64encode(json.dumps({
            "key": self.key, "action": "retire", "stopRunning": True
        }, separators=(",", ":")).encode()).decode()
        result = subprocess.run(
            [sys.executable, str(BROKER), "manage", payload],
            capture_output=True, text=True, timeout=10,
            env={**os.environ, "HOME": str(self.home)},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        status = json.loads(result.stdout.strip())
        self.assertEqual(status["state"], "retired")
        self._wait_meta("state", "retired")
        serve_pid = self._journal_meta("pid")
        self._assert_dead(serve_pid)
        self._stop_attach(proc)

    def test_purge_removes_only_verified_runtime_folder(self):
        argv = self._agent_config(chunks=0)
        proc = self._start_attach(argv)
        self._handshake(proc, "purge")
        self._wait_meta("state", "ready")
        serve_pid = self._serve_pid()
        self._stop_attach(proc)
        self._assert_alive(serve_pid)

        folder = self._folder()
        self.assertTrue(folder.exists())
        socket_path = self._socket_path()
        self.assertTrue(socket_path.exists())

        payload = base64.b64encode(json.dumps({
            "key": self.key, "action": "purge"
        }, separators=(",", ":")).encode()).decode()
        result = subprocess.run(
            [sys.executable, str(BROKER), "manage", payload],
            capture_output=True, text=True, timeout=10,
            env={**os.environ, "HOME": str(self.home)},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        status = json.loads(result.stdout.strip())
        self.assertEqual(status["state"], "purged")
        self.assertFalse(folder.exists(), "runtime folder must be removed")
        self.assertFalse(socket_path.exists(), "socket must be removed")

    def test_purge_rejects_symlinked_or_nonowned_paths(self):
        argv = self._agent_config(chunks=0)
        proc = self._start_attach(argv)
        self._handshake(proc, "purgesafe")
        self._wait_meta("state", "ready")
        serve_pid = self._serve_pid()
        self._stop_attach(proc)

        folder = self._folder()
        malicious = folder / "malicious_link"
        malicious.symlink_to("/etc/passwd")

        payload = base64.b64encode(json.dumps({
            "key": self.key, "action": "purge"
        }, separators=(",", ":")).encode()).decode()
        result = subprocess.run(
            [sys.executable, str(BROKER), "manage", payload],
            capture_output=True, text=True, timeout=10,
            env={**os.environ, "HOME": str(self.home)},
        )
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("ACP_RUNTIME_PATH_UNSAFE", result.stdout)
        self.assertTrue(folder.exists(), "original folder must remain after rejected purge")
        self._kill_exact(serve_pid)

    def test_server_scope_excludes_other_scope_runtimes(self):
        scope_a = "a" * 64
        scope_b = "b" * 64
        argv_a = self._agent_config(chunks=1, chunk_delay=10.0)
        argv_b = self._agent_config(chunks=1, chunk_delay=10.0)
        key_a = scope_a
        key_b = scope_b

        config_a = {"key": key_a, "argv": argv_a, "serverScope": scope_a}
        config_b = {"key": key_b, "argv": argv_b, "serverScope": scope_b}
        procs = []
        for config in (config_a, config_b):
            payload = base64.b64encode(json.dumps(config, separators=(",", ":")).encode()).decode()
            proc = subprocess.Popen(
                [sys.executable, str(BROKER), "attach", payload],
                stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                bufsize=0, cwd=str(self.home), env={**os.environ, "HOME": str(self.home)},
            )
            self.spawned_pids.append(proc.pid)
            self.spawned_procs.append(proc)
            procs.append((proc, config["key"]))
            # Handshake and start a turn to make it "running"
            self._handshake_attach(proc, config["key"])
            self._send_attach(proc, {
                "jsonrpc": "2.0", "id": "scope-prompt", "method": "session/prompt",
                "params": {"sessionId": self.session_id, "prompt": [{"type": "text", "text": "go"}]},
            }, turn_id="turn-scope-" + config["key"][:8])
            self._wait_attach_meta(config["key"], "state", "running")
            self._serve_pid_for_key(config["key"])

        active_a = subprocess.run(
            [sys.executable, str(BROKER), "active", scope_a],
            capture_output=True, text=True, timeout=10,
            env={**os.environ, "HOME": str(self.home)},
        )
        active_b = subprocess.run(
            [sys.executable, str(BROKER), "active", scope_b],
            capture_output=True, text=True, timeout=10,
            env={**os.environ, "HOME": str(self.home)},
        )
        self.assertEqual(active_a.returncode, 0, active_a.stderr)
        self.assertEqual(active_b.returncode, 0, active_b.stderr)
        runtimes_a = json.loads(active_a.stdout.strip())
        runtimes_b = json.loads(active_b.stdout.strip())
        self.assertEqual(len(runtimes_a), 1)
        self.assertEqual(runtimes_a[0]["runtimeKey"], key_a)
        self.assertEqual(len(runtimes_b), 1)
        self.assertEqual(runtimes_b[0]["runtimeKey"], key_b)

        for proc, key in procs:
            self._stop_attach(proc)

    def test_server_scope_v1_runtime_is_treated_as_busy(self):
        scope = "c" * 64
        key_v1 = "d" * 64
        folder_v1 = self._make_v1_runtime(
            key_v1, state="running", pid=999999, server_scope=scope
        )

        argv_v2 = self._agent_config(chunks=0)
        config_v2 = {"key": "e" * 64, "argv": argv_v2, "serverScope": scope}
        payload = base64.b64encode(json.dumps(config_v2, separators=(",", ":")).encode()).decode()
        proc = subprocess.Popen(
            [sys.executable, str(BROKER), "attach", payload],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            bufsize=0, cwd=str(self.home), env={**os.environ, "HOME": str(self.home)},
        )
        self.spawned_pids.append(proc.pid)
        self.spawned_procs.append(proc)
        try:
            self._handshake_attach(proc, config_v2["key"])
            self._serve_pid_for_key(config_v2["key"])
            self._send_attach(proc, {
                "jsonrpc": "2.0", "id": "scope-prompt", "method": "session/prompt",
                "params": {"sessionId": self.session_id, "prompt": [{"type": "text", "text": "go"}]},
            }, turn_id="turn-scope-test")
            frames = self._read_frames(
                proc,
                lambda f: f.get("type") == "runtime_error"
                and "SERVER_BUSY" in f.get("error", ""),
                timeout=5.0,
            )
            self.assertTrue(any("ACP_RUNTIME_SERVER_BUSY" in f.get("error", "") for f in frames))
        finally:
            self._stop_attach(proc)

        import shutil
        shutil.rmtree(folder_v1)

    def test_v1_protocol_version_inspect_shows_v1(self):
        key_v1 = "f" * 64
        folder_v1 = self._make_v1_runtime(
            key_v1,
            state="completed",
            pid=999999,
            extra_meta={"sessionId": "v1-session", "turnId": "v1-turn"},
        )

        payload = base64.b64encode(json.dumps({
            "key": key_v1, "action": "inspect"
        }, separators=(",", ":")).encode()).decode()
        result = subprocess.run(
            [sys.executable, str(BROKER), "manage", payload],
            capture_output=True, text=True, timeout=10,
            env={**os.environ, "HOME": str(self.home)},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        status = json.loads(result.stdout.strip())
        self.assertEqual(status["runtimeKey"], key_v1)
        self.assertEqual(status["state"], "completed")
        self.assertFalse(status["alive"])
        self.assertEqual(status["protocolVersion"], 1)
        self.assertEqual(status["sessionId"], "v1-session")
        self.assertEqual(status["turnId"], "v1-turn")

        import shutil
        shutil.rmtree(folder_v1)

    def test_v1_runtime_can_be_retired_via_manage(self):
        key_v1 = "1" * 64
        folder_v1 = self._make_v1_runtime(
            key_v1, state="completed", pid=999999
        )
        journal = folder_v1 / "journal.sqlite3"

        payload = base64.b64encode(json.dumps({
            "key": key_v1, "action": "retire"
        }, separators=(",", ":")).encode()).decode()
        result = subprocess.run(
            [sys.executable, str(BROKER), "manage", payload],
            capture_output=True, text=True, timeout=10,
            env={**os.environ, "HOME": str(self.home)},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        status = json.loads(result.stdout.strip())
        self.assertEqual(status["state"], "retired")

        meta = acp_broker.read_meta(folder_v1)
        self.assertEqual(meta["state"], "retired")

        import shutil
        shutil.rmtree(folder_v1)

    def test_v1_runtime_running_requires_stop_running_and_kills_exact_pid(self):
        key_v1 = "2" * 64
        folder_v1 = self._runtime_root() / key_v1
        folder_v1.mkdir(parents=True, mode=0o700)
        leader = self._spawn_fixture(self._fake_serve_argv(folder_v1))
        child = self._spawn_fixture([sys.executable, "-c", "import time; time.sleep(60)"])
        child_identity = self._identity_for_child(child)
        self._make_v1_runtime(
            key_v1,
            state="running",
            pid=leader.pid,
            argv=self._fake_serve_argv(folder_v1),
            child_identity=child_identity,
        )
        # Re-create the config with the real leader argv used by ownership checks.
        (folder_v1 / "config.json").write_text(json.dumps({
            "key": key_v1, "argv": self._fake_serve_argv(folder_v1),
            "launchIdentity": "v1-identity"
        }))

        payload = base64.b64encode(json.dumps({
            "key": key_v1, "action": "retire", "stopRunning": False
        }, separators=(",", ":")).encode()).decode()
        result = subprocess.run(
            [sys.executable, str(BROKER), "manage", payload],
            capture_output=True, text=True, timeout=10,
            env={**os.environ, "HOME": str(self.home)},
        )
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("ACP_RUNTIME_TURN_IN_PROGRESS", result.stdout)
        self.assertIsNone(leader.poll())
        self.assertIsNone(child.poll())

        payload = base64.b64encode(json.dumps({
            "key": key_v1, "action": "retire", "stopRunning": True
        }, separators=(",", ":")).encode()).decode()
        result = subprocess.run(
            [sys.executable, str(BROKER), "manage", payload],
            capture_output=True, text=True, timeout=10,
            env={**os.environ, "HOME": str(self.home)},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        status = json.loads(result.stdout.strip())
        self.assertEqual(status["state"], "retired")
        self._assert_no_live_process(child.pid, timeout=5.0)
        leader.wait(timeout=5.0)
        self._assert_no_live_process(leader.pid, timeout=5.0)

        import shutil
        shutil.rmtree(folder_v1)

    def test_v1_runtime_pid_reused_never_signals_new_owner(self):
        key_v1 = "3" * 64
        unrelated = self._spawn_fixture([
            sys.executable, "-c", "import time; time.sleep(60)"
        ])
        folder_v1 = self._make_v1_runtime(
            key_v1, state="completed", pid=unrelated.pid
        )

        payload = base64.b64encode(json.dumps({
            "key": key_v1, "action": "retire", "stopRunning": True
        }, separators=(",", ":")).encode()).decode()
        result = subprocess.run(
            [sys.executable, str(BROKER), "manage", payload],
            capture_output=True, text=True, timeout=10,
            env={**os.environ, "HOME": str(self.home)},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        status = json.loads(result.stdout.strip())
        self.assertEqual(status["state"], "retired")
        self.assertIsNone(unrelated.poll(), "reused PID must not be signalled")

        import shutil
        shutil.rmtree(folder_v1)

    def test_child_process_cleanup_is_exact_pid_only(self):
        argv = self._agent_config(chunks=0, exit_after_prompt=True)
        proc = self._start_attach(argv)
        self._handshake(proc, "childcleanup")
        self._serve_pid()
        self._send(proc, {
            "jsonrpc": "2.0", "id": "child-prompt", "method": "session/prompt",
            "params": {"sessionId": self.session_id, "prompt": [{"type": "text", "text": "go"}]},
        }, turn_id="turn-childcleanup")
        frames = self._read_frames(
            proc,
            lambda f: f.get("type") == "frame"
            and f.get("frame", {}).get("id") == "child-prompt"
            and "result" in f.get("frame", {}),
        )
        deadline = time.time() + 5
        while time.time() < deadline and self._journal_meta("agentExited") is not True:
            time.sleep(0.1)
        self.assertTrue(self._journal_meta("agentExited"))
        child_identity = self._journal_meta("childIdentity")
        self.assertIsNotNone(child_identity)
        child_pid = child_identity["pid"]
        self.assertIsInstance(child_pid, int)
        self._stop_attach(proc)

        self._assert_dead(child_pid, timeout=5.0)

    def test_legacy_retire_verifies_exact_argv_before_kill(self):
        key_v1 = "4" * 64
        folder_v1 = self._runtime_root() / key_v1
        folder_v1.mkdir(parents=True, mode=0o700, exist_ok=True)
        leader = self._spawn_fixture(self._fake_serve_argv(folder_v1))
        child = self._spawn_fixture([
            sys.executable, "-c", "import time; time.sleep(60)"
        ])
        self._make_v1_runtime(
            key_v1,
            state="completed",
            pid=leader.pid,
            argv=self._fake_serve_argv(folder_v1),
            child_identity=self._identity_for_child(child),
        )

        meta = acp_broker.read_meta(folder_v1)
        self.assertEqual(meta["state"], "completed")
        acp_broker.legacy_retire(folder_v1, meta, stop_running=True)

        self._assert_no_live_process(child.pid, timeout=5.0)
        leader.wait(timeout=5.0)
        self._assert_no_live_process(leader.pid, timeout=5.0)

        import shutil
        shutil.rmtree(folder_v1)

    def test_legacy_retire_rejects_mismatched_argv_for_non_terminal_state(self):
        key_v1 = "5" * 64
        unrelated = self._spawn_fixture([
            sys.executable, "-c", "import time; time.sleep(60)"
        ])
        folder_v1 = self._make_v1_runtime(
            key_v1, state="running", pid=unrelated.pid
        )

        meta = acp_broker.read_meta(folder_v1)
        with self.assertRaises(ValueError) as cm:
            acp_broker.legacy_retire(folder_v1, meta, stop_running=True)
        self.assertIn("ACP_RUNTIME_OWNERSHIP_UNVERIFIED", str(cm.exception))
        self.assertIsNone(unrelated.poll(), "unverified process must not be signalled")
        self.assertTrue(folder_v1.exists(), "failed retirement must keep the runtime folder")
        self.assertTrue((folder_v1 / "journal.sqlite3").exists())

        import shutil
        shutil.rmtree(folder_v1)

    def test_legacy_retire_allows_mismatched_argv_for_terminal_state(self):
        key_v1 = "6" * 64
        unrelated = self._spawn_fixture([
            sys.executable, "-c", "import time; time.sleep(60)"
        ])
        folder_v1 = self._make_v1_runtime(
            key_v1, state="completed", pid=unrelated.pid
        )

        meta = acp_broker.read_meta(folder_v1)
        acp_broker.legacy_retire(folder_v1, meta, stop_running=True)
        self.assertIsNone(unrelated.poll(), "reused PID must not be signalled")
        self.assertTrue(folder_v1.exists())

        import shutil
        shutil.rmtree(folder_v1)

    def test_broker_claim_scope_fails_when_v1_active_in_same_scope(self):
        scope = "7" * 64
        key_v1 = "8" * 64
        folder_v1 = self._make_v1_runtime(
            key_v1, state="running", pid=999999, server_scope=scope
        )

        key_v2 = "9" * 64
        folder_v2 = self._runtime_root() / key_v2
        folder_v2.mkdir(parents=True, mode=0o700)
        config_file_v2 = folder_v2 / "config.json"
        config_file_v2.write_text(json.dumps({
            "key": key_v2, "argv": [sys.executable, "-c", "pass"],
            "serverScope": scope, "launchIdentity": "v2-identity"
        }))

        broker = acp_broker.Broker(folder_v2)
        try:
            with self.assertRaises(ValueError) as cm:
                broker.claim_scope("test-turn")
            self.assertIn("ACP_RUNTIME_SERVER_BUSY", str(cm.exception))
        finally:
            self._shutdown_direct_broker(broker)

        import shutil
        shutil.rmtree(folder_v1)
        shutil.rmtree(folder_v2)

    def test_broker_claim_scope_succeeds_when_v1_completed_in_same_scope(self):
        scope = "a" * 64
        key_v1 = "b" * 64
        folder_v1 = self._make_v1_runtime(
            key_v1, state="completed", pid=999999, server_scope=scope
        )

        key_v2 = "c" * 64
        folder_v2 = self._runtime_root() / key_v2
        folder_v2.mkdir(parents=True, mode=0o700)
        config_file_v2 = folder_v2 / "config.json"
        config_file_v2.write_text(json.dumps({
            "key": key_v2, "argv": [sys.executable, "-c", "pass"],
            "serverScope": scope, "launchIdentity": "v2-identity"
        }))

        broker = acp_broker.Broker(folder_v2)
        try:
            broker.claim_scope("test-turn")
            self.assertIsNotNone(broker.scope_file)
        finally:
            self._shutdown_direct_broker(broker)

        import shutil
        shutil.rmtree(folder_v1)
        shutil.rmtree(folder_v2)

    def test_broker_manage_retire_v2_sends_retire_via_socket(self):
        argv = self._agent_config(chunks=0)
        proc = self._start_attach(argv)
        self._handshake(proc, "retirev2")
        self._wait_meta("state", "ready")
        serve_pid = self._serve_pid()
        self._stop_attach(proc)

        payload = base64.b64encode(json.dumps({
            "key": self.key, "action": "retire", "stopRunning": True
        }, separators=(",", ":")).encode()).decode()
        result = subprocess.run(
            [sys.executable, str(BROKER), "manage", payload],
            capture_output=True, text=True, timeout=10,
            env={**os.environ, "HOME": str(self.home)},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        status = json.loads(result.stdout.strip())
        self.assertEqual(status["state"], "retired")
        self._wait_meta("state", "retired")
        self._assert_dead(serve_pid)

    def test_broker_manage_purge_v2_sends_retire_then_removes_folder(self):
        argv = self._agent_config(chunks=0)
        proc = self._start_attach(argv)
        self._handshake(proc, "purgev2")
        self._wait_meta("state", "ready")
        serve_pid = self._serve_pid()
        self._stop_attach(proc)

        payload = base64.b64encode(json.dumps({
            "key": self.key, "action": "purge"
        }, separators=(",", ":")).encode()).decode()
        result = subprocess.run(
            [sys.executable, str(BROKER), "manage", payload],
            capture_output=True, text=True, timeout=10,
            env={**os.environ, "HOME": str(self.home)},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        status = json.loads(result.stdout.strip())
        self.assertEqual(status["state"], "purged")
        self.assertFalse(self._folder().exists())
        self.assertFalse(self._socket_path().exists())

    def test_stop_owned_group_kills_descendant_that_ignores_term(self):
        script = self.home / "term_leader.py"
        script.write_text(r'''
import os, signal, sys, time
pid_file, ready_file = sys.argv[1:3]
child = os.fork()
if child == 0:
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    with open(ready_file, "w") as handle:
        handle.write("ready")
    time.sleep(60)
    os._exit(0)
with open(pid_file, "w") as handle:
    handle.write(str(child))
time.sleep(60)
''')
        pid_file = self.home / "term_leader.pid"
        ready_file = self.home / "term_leader.ready"
        leader = subprocess.Popen(
            [sys.executable, str(script), str(pid_file), str(ready_file)],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        self.spawned_pids.append(leader.pid)
        self.spawned_procs.append(leader)
        child_pid = None
        try:
            self._wait_file(pid_file)
            self._wait_file(ready_file)
            child_pid = int(pid_file.read_text().strip())
            self.spawned_pids.append(child_pid)
            identity = acp_broker.process_identity(leader.pid)
            self.assertIsNotNone(identity)

            acp_broker.stop_owned_group(identity)

            leader.wait(timeout=5.0)
            self._assert_no_live_process(leader.pid, timeout=5.0)
            self._assert_no_live_process(child_pid, timeout=5.0)
        finally:
            if child_pid is not None:
                self._kill_exact(child_pid)
            self._stop_attach(leader)

    def test_manage_refuses_unverified_orphan_without_deleting_directory(self):
        key_v1 = "7" * 64
        folder_v1 = self._runtime_root() / key_v1
        script = self.home / "orphan_leader.py"
        script.write_text(r'''
import os, signal, sys, time
pid_file, ready_file, leave_file = sys.argv[1:4]
child = os.fork()
if child == 0:
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    with open(ready_file, "w") as handle:
        handle.write("ready")
    time.sleep(60)
    os._exit(0)
with open(pid_file, "w") as handle:
    handle.write(str(child))
while not os.path.exists(leave_file):
    time.sleep(0.02)
os._exit(0)
''')
        pid_file = self.home / "orphan.pid"
        ready_file = self.home / "orphan.ready"
        leave_file = self.home / "orphan.leave"
        leader = subprocess.Popen(
            [sys.executable, str(script), str(pid_file), str(ready_file), str(leave_file)],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        self.spawned_pids.append(leader.pid)
        self.spawned_procs.append(leader)
        child_pid = None
        try:
            self._wait_file(pid_file)
            self._wait_file(ready_file)
            child_pid = int(pid_file.read_text().strip())
            self.spawned_pids.append(child_pid)
            child_identity = acp_broker.process_identity(child_pid)
            self.assertIsNotNone(child_identity)
            unverified = {
                "pid": child_pid,
                "group": child_identity["group"],
                "started": "not-the-real-start-time",
            }
            self._make_v1_runtime(
                key_v1,
                state="running",
                pid=leader.pid,
                child_identity=unverified,
            )

            leave_file.write_text("leave")
            leader.wait(timeout=5.0)
            self._assert_no_live_process(leader.pid, timeout=5.0)

            payload = base64.b64encode(json.dumps({
                "key": key_v1, "action": "purge", "stopRunning": True
            }, separators=(",", ":")).encode()).decode()
            result = subprocess.run(
                [sys.executable, str(BROKER), "manage", payload],
                capture_output=True, text=True, timeout=10,
                env={**os.environ, "HOME": str(self.home)},
            )
            self.assertEqual(result.returncode, 1, result.stdout)
            self.assertIn("ACP_RUNTIME_OWNERSHIP_UNVERIFIED", result.stdout)
            self.assertTrue(folder_v1.exists(), "unverified purge must keep the folder")
            self.assertTrue((folder_v1 / "journal.sqlite3").exists())
            self.assertIsNotNone(
                acp_broker.process_identity(child_pid),
                "unverified orphan must not be signalled",
            )
        finally:
            if child_pid is not None:
                self._kill_exact(child_pid)
            self._stop_attach(leader)

        import shutil
        shutil.rmtree(folder_v1)

    # -- workspace fencing ----------------------------------------------
    def _install_workspace_store(self):
        folder = self.home / ".local/share/valhalla/workspace-v1"
        folder.mkdir(parents=True, mode=0o700, exist_ok=True)
        installed = folder / "store.py"
        shutil.copyfile(WORKSPACE_SOURCE, installed)
        os.chmod(installed, 0o600)
        spec = importlib.util.spec_from_file_location(
            "broker_workspace_store_%s" % self.home.name, installed)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        module.ROOT = folder
        return module

    def test_workspace_enabled_rejects_mutations_without_control_token(self):
        store = self._install_workspace_store()
        device = "device-reader"
        sid = "workspace-session"
        self.assertTrue(store.handle({"op": "bootstrap", "deviceId": device})["ok"])
        argv = self._agent_config(chunks=0)
        proc = self._start_attach(argv, extra={
            "workspaceSessionId": sid, "workspaceDeviceId": device,
        })
        self._send(proc, {
            "jsonrpc": "2.0", "id": "nocontrol-init", "method": "initialize",
            "params": {},
        })
        self._read_frames(
            proc, lambda f: f.get("type") == "frame"
            and f.get("frame", {}).get("id") == "nocontrol-init")
        self._send(proc, {
            "jsonrpc": "2.0", "id": "nocontrol-new", "method": "session/new",
            "params": {},
        })
        frames = self._read_frames(
            proc, lambda f: f.get("type") == "runtime_error"
            and f.get("error") == "WORKSPACE_CONTROL_LOST")
        self.assertTrue(any(f.get("error") == "WORKSPACE_CONTROL_LOST"
                            for f in frames), frames)
        self.assertEqual(self._count_lines(self.prompt_count_file), 0)
        self._stop_attach(proc)

    def test_workspace_enabled_mutation_requires_live_control_and_never_kills_agent(self):
        store = self._install_workspace_store()
        device = "device-writer"
        sid = "workspace-session"
        self.assertTrue(store.handle({"op": "bootstrap", "deviceId": device})["ok"])
        lease = store.handle({"op": "lease", "sessionId": sid,
                              "deviceId": device, "action": "acquire"})
        self.assertTrue(lease["ok"], lease)
        argv = self._agent_config(chunks=0)
        proc = self._start_attach(argv, extra={
            "workspaceSessionId": sid, "workspaceDeviceId": device,
            "controlToken": lease["token"],
            "controlGeneration": lease["generation"],
        })
        self._handshake(proc, "ws")
        serve_pid = self._serve_pid()
        self._send(proc, {
            "jsonrpc": "2.0", "id": "ws-prompt-1", "method": "session/prompt",
            "params": {"sessionId": self.session_id,
                       "prompt": [{"type": "text", "text": "one"}]},
        }, turn_id="turn-ws-1")
        self._read_frames(
            proc, lambda f: f.get("type") == "frame"
            and f.get("frame", {}).get("id") == "ws-prompt-1"
            and "result" in f.get("frame", {}))
        self.assertEqual(self._count_lines(self.prompt_count_file), 1)

        takeover = store.handle({"op": "lease", "sessionId": sid,
                                 "deviceId": "device-taker",
                                 "action": "takeover"})
        self.assertTrue(takeover["ok"], takeover)
        self._send(proc, {
            "jsonrpc": "2.0", "id": "ws-prompt-2", "method": "session/prompt",
            "params": {"sessionId": self.session_id,
                       "prompt": [{"type": "text", "text": "two"}]},
        }, turn_id="turn-ws-2")
        frames = self._read_frames(
            proc, lambda f: f.get("type") == "runtime_error"
            and f.get("error") == "WORKSPACE_CONTROL_LOST")
        self.assertTrue(any(f.get("error") == "WORKSPACE_CONTROL_LOST"
                            for f in frames), frames)
        self.assertEqual(self._count_lines(self.prompt_count_file), 1)
        self._assert_alive(serve_pid)
        self._stop_attach(proc)

    # -- workspace lease / protocol regressions -------------------------
    def _run_manage(self, command: dict, timeout: float = 10.0):
        payload = base64.b64encode(
            json.dumps(command, separators=(",", ":")).encode()
        ).decode()
        return subprocess.run(
            [sys.executable, str(BROKER), "manage", payload],
            capture_output=True, text=True, timeout=timeout,
            env={**os.environ, "HOME": str(self.home)},
        )

    def _expire_lease(self, session_id: str):
        db = self.home / ".local/share/valhalla/workspace-v1/store.sqlite3"
        conn = sqlite3.connect(db)
        try:
            conn.execute("UPDATE leases SET expires_at=0 WHERE session_id=?",
                         (session_id,))
            conn.commit()
        finally:
            conn.close()

    def _send_heartbeat(self, proc, device, token, generation):
        line = json.dumps({
            "type": "control_heartbeat", "deviceId": device,
            "controlToken": token, "controlGeneration": generation,
        }, separators=(",", ":")) + "\n"
        proc.stdin.write(line.encode())
        proc.stdin.flush()

    def test_snapshot_reports_legacy_workspace_protocol_zero(self):
        argv = self._agent_config(chunks=0)
        proc = self._start_attach(argv)
        frames = self._read_until_caught_up(proc)
        status = frames[0]
        self.assertEqual(status["type"], "status")
        self.assertEqual(status["protocolVersion"], 2)
        self.assertEqual(status["workspaceProtocol"], 0)
        self.assertNotIn("workspaceSessionId", status)
        self._stop_attach(proc)

    def test_snapshot_reports_workspace_protocol_and_session_when_enabled(self):
        store = self._install_workspace_store()
        device = "device-snapshot"
        sid = "workspace-snapshot"
        self.assertTrue(store.handle({"op": "bootstrap",
                                      "deviceId": device})["ok"])
        lease = store.handle({"op": "lease", "sessionId": sid,
                              "deviceId": device, "action": "acquire"})
        self.assertTrue(lease["ok"], lease)
        argv = self._agent_config(chunks=0)
        proc = self._start_attach(argv, extra={
            "workspaceSessionId": sid, "workspaceDeviceId": device,
            "controlToken": lease["token"],
            "controlGeneration": lease["generation"],
        })
        frames = self._read_until_caught_up(proc)
        status = frames[0]
        self.assertEqual(status["protocolVersion"], 2)
        self.assertEqual(status["workspaceProtocol"], 1)
        self.assertEqual(status["workspaceSessionId"], sid)
        self._stop_attach(proc)

    def test_workspace_lease_expiry_allows_new_owner_and_output_continues(self):
        store = self._install_workspace_store()
        device_a, device_b = "device-a", "device-b"
        sid = "workspace-expiry"
        self.assertTrue(store.handle({"op": "bootstrap",
                                      "deviceId": device_a})["ok"])
        lease = store.handle({"op": "lease", "sessionId": sid,
                              "deviceId": device_a, "action": "acquire"})
        self.assertTrue(lease["ok"], lease)
        argv = self._agent_config(chunks=4, chunk_delay=0.2)
        proc = self._start_attach(argv, extra={
            "workspaceSessionId": sid, "workspaceDeviceId": device_a,
            "controlToken": lease["token"],
            "controlGeneration": lease["generation"],
        })
        self._handshake(proc, "expiry")
        serve_pid = self._serve_pid()
        self._send(proc, {
            "jsonrpc": "2.0", "id": "expiry-1", "method": "session/prompt",
            "params": {"sessionId": self.session_id,
                       "prompt": [{"type": "text", "text": "one"}]},
        }, turn_id="turn-expiry-1")
        self._read_frames(proc, lambda f: self._is_chunk_event(f, "chunk-0"))

        # The device is gone (lease expired); no server-side heartbeat may
        # resurrect it.  A different device can acquire immediately.
        self._expire_lease(sid)
        takeover = store.handle({"op": "lease", "sessionId": sid,
                                 "deviceId": device_b, "action": "acquire"})
        self.assertTrue(takeover["ok"], takeover)
        self.assertGreater(takeover["generation"], lease["generation"])
        self.assertTrue(store.check_control(sid, device_b, takeover["token"],
                                            takeover["generation"]))

        self._send(proc, {
            "jsonrpc": "2.0", "id": "expiry-2", "method": "session/prompt",
            "params": {"sessionId": self.session_id,
                       "prompt": [{"type": "text", "text": "two"}]},
        }, turn_id="turn-expiry-2")
        frames = self._read_frames(
            proc, lambda f: f.get("type") == "frame"
            and f.get("frame", {}).get("id") == "expiry-1")
        self.assertTrue(any(f.get("error") == "WORKSPACE_CONTROL_LOST"
                            for f in frames), frames)
        # The computation kept running after control was lost.
        self.assertTrue(any(self._is_chunk_event(f, "chunk-3")
                            for f in frames), frames)
        self.assertEqual(self._count_lines(self.prompt_count_file), 1)
        self._assert_alive(serve_pid)
        self._stop_attach(proc)

    def test_workspace_readonly_client_observes_events_but_cannot_mutate(self):
        store = self._install_workspace_store()
        device = "device-writer"
        sid = "workspace-readonly"
        self.assertTrue(store.handle({"op": "bootstrap",
                                      "deviceId": device})["ok"])
        lease = store.handle({"op": "lease", "sessionId": sid,
                              "deviceId": device, "action": "acquire"})
        self.assertTrue(lease["ok"], lease)
        argv = self._agent_config(chunks=3, chunk_delay=0.2)
        writer = self._start_attach(argv, extra={
            "workspaceSessionId": sid, "workspaceDeviceId": device,
            "controlToken": lease["token"],
            "controlGeneration": lease["generation"],
        })
        self._handshake(writer, "ro-writer")
        reader = self._start_attach(argv, after_seq=0)
        frames = self._read_until_caught_up(reader)
        self.assertEqual(frames[0]["workspaceProtocol"], 1)
        self.assertEqual(frames[0]["workspaceSessionId"], sid)

        self._send(writer, {
            "jsonrpc": "2.0", "id": "ro-1", "method": "session/prompt",
            "params": {"sessionId": self.session_id,
                       "prompt": [{"type": "text", "text": "one"}]},
        }, turn_id="turn-ro-1")
        observed = self._read_frames(
            reader, lambda f: self._is_chunk_event(f, "chunk-0"))
        self.assertTrue(any(self._is_chunk_event(f, "chunk-0")
                            for f in observed), observed)

        self._send(reader, {
            "jsonrpc": "2.0", "id": "ro-2", "method": "session/prompt",
            "params": {"sessionId": self.session_id,
                       "prompt": [{"type": "text", "text": "two"}]},
        }, turn_id="turn-ro-2")
        denied = self._read_frames(
            reader, lambda f: f.get("type") == "runtime_error"
            and f.get("error") == "WORKSPACE_CONTROL_LOST")
        self.assertTrue(any(f.get("error") == "WORKSPACE_CONTROL_LOST"
                            for f in denied), denied)
        self.assertEqual(self._count_lines(self.prompt_count_file), 1)
        self._read_frames(
            writer, lambda f: f.get("type") == "frame"
            and f.get("frame", {}).get("id") == "ro-1")
        self._stop_attach(reader)
        self._stop_attach(writer)

    def test_workspace_client_heartbeat_renews_only_with_live_token(self):
        store = self._install_workspace_store()
        device = "device-heartbeat"
        sid = "workspace-heartbeat"
        self.assertTrue(store.handle({"op": "bootstrap",
                                      "deviceId": device})["ok"])
        lease = store.handle({"op": "lease", "sessionId": sid,
                              "deviceId": device, "action": "acquire"})
        self.assertTrue(lease["ok"], lease)
        argv = self._agent_config(chunks=0)
        proc = self._start_attach(argv, extra={
            "workspaceSessionId": sid, "workspaceDeviceId": device,
            "controlToken": lease["token"],
            "controlGeneration": lease["generation"],
        })
        self._handshake(proc, "heartbeat")
        serve_pid = self._serve_pid()

        self._send_heartbeat(proc, device, lease["token"],
                             lease["generation"])
        frames = self._read_frames(
            proc, lambda f: f.get("type") == "control_heartbeat")
        self.assertTrue(frames[-1]["allowed"], frames)
        self._send_heartbeat(proc, device, "wrong-token",
                             lease["generation"])
        frames = self._read_frames(
            proc, lambda f: f.get("type") == "control_heartbeat")
        self.assertFalse(frames[-1]["allowed"], frames)
        self._expire_lease(sid)
        self._send_heartbeat(proc, device, lease["token"],
                             lease["generation"])
        frames = self._read_frames(
            proc, lambda f: f.get("type") == "control_heartbeat")
        self.assertFalse(frames[-1]["allowed"], frames)
        self._assert_alive(serve_pid)
        self._stop_attach(proc)

    def test_workspace_manage_retire_requires_live_control(self):
        store = self._install_workspace_store()
        device_a, device_b = "device-a", "device-b"
        sid = "workspace-manage-retire"
        self.assertTrue(store.handle({"op": "bootstrap",
                                      "deviceId": device_a})["ok"])
        lease = store.handle({"op": "lease", "sessionId": sid,
                              "deviceId": device_a, "action": "acquire"})
        self.assertTrue(lease["ok"], lease)
        argv = self._agent_config(chunks=0)
        proc = self._start_attach(argv, extra={
            "workspaceSessionId": sid, "workspaceDeviceId": device_a,
            "controlToken": lease["token"],
            "controlGeneration": lease["generation"],
        })
        self._handshake(proc, "manage")
        serve_pid = self._serve_pid()

        inspected = self._run_manage({"key": self.key, "action": "inspect"})
        self.assertEqual(inspected.returncode, 0, inspected.stderr)
        self.assertEqual(json.loads(inspected.stdout)["state"], "ready")

        denied = self._run_manage({"key": self.key, "action": "retire",
                                   "stopRunning": True})
        self.assertEqual(denied.returncode, 1, denied.stdout)
        self.assertIn("WORKSPACE_CONTROL_LOST", denied.stdout)
        self._assert_alive(serve_pid)

        takeover = store.handle({"op": "lease", "sessionId": sid,
                                 "deviceId": device_b, "action": "takeover"})
        self.assertTrue(takeover["ok"], takeover)
        stale = self._run_manage({
            "key": self.key, "action": "retire", "stopRunning": True,
            "workspaceDeviceId": device_a,
            "controlToken": lease["token"],
            "controlGeneration": lease["generation"],
        })
        self.assertEqual(stale.returncode, 1, stale.stdout)
        self.assertIn("WORKSPACE_CONTROL_LOST", stale.stdout)
        self._assert_alive(serve_pid)

        allowed = self._run_manage({
            "key": self.key, "action": "retire", "stopRunning": True,
            "workspaceDeviceId": device_b,
            "controlToken": takeover["token"],
            "controlGeneration": takeover["generation"],
        })
        self.assertEqual(allowed.returncode, 0, allowed.stdout + allowed.stderr)
        self.assertEqual(json.loads(allowed.stdout)["state"], "retired")
        self._assert_dead(serve_pid)
        self._stop_attach(proc)

    def test_workspace_manage_purge_requires_live_control(self):
        store = self._install_workspace_store()
        device = "device-purge"
        sid = "workspace-manage-purge"
        self.assertTrue(store.handle({"op": "bootstrap",
                                      "deviceId": device})["ok"])
        lease = store.handle({"op": "lease", "sessionId": sid,
                              "deviceId": device, "action": "acquire"})
        self.assertTrue(lease["ok"], lease)
        argv = self._agent_config(chunks=0)
        proc = self._start_attach(argv, extra={
            "workspaceSessionId": sid, "workspaceDeviceId": device,
            "controlToken": lease["token"],
            "controlGeneration": lease["generation"],
        })
        self._handshake(proc, "purge-ws")
        serve_pid = self._serve_pid()

        denied = self._run_manage({"key": self.key, "action": "purge",
                                   "stopRunning": True})
        self.assertEqual(denied.returncode, 1, denied.stdout)
        self.assertIn("WORKSPACE_CONTROL_LOST", denied.stdout)
        self.assertTrue(self._folder().exists())
        self._assert_alive(serve_pid)

        allowed = self._run_manage({
            "key": self.key, "action": "purge", "stopRunning": True,
            "workspaceDeviceId": device,
            "controlToken": lease["token"],
            "controlGeneration": lease["generation"],
        })
        self.assertEqual(allowed.returncode, 0, allowed.stdout + allowed.stderr)
        self.assertEqual(json.loads(allowed.stdout)["state"], "purged")
        self.assertFalse(self._folder().exists())
        self._assert_dead(serve_pid)
        self._stop_attach(proc)

    def test_workspace_manage_process_path_fences_v1_runtime(self):
        """A workspace-enabled v1 runtime with no broker socket must still
        require a live lease before the process kill path runs."""
        store = self._install_workspace_store()
        device_a, device_b = "device-v1-a", "device-v1-b"
        sid = "workspace-v1-manage"
        self.assertTrue(store.handle({"op": "bootstrap",
                                      "deviceId": device_a})["ok"])
        lease = store.handle({"op": "lease", "sessionId": sid,
                              "deviceId": device_a, "action": "acquire"})
        self.assertTrue(lease["ok"], lease)

        key_v1 = "4" * 64
        folder_v1 = self._runtime_root() / key_v1
        folder_v1.mkdir(parents=True, mode=0o700)
        leader = self._spawn_fixture(self._fake_serve_argv(folder_v1))
        child = self._spawn_fixture([sys.executable, "-c", "import time; time.sleep(60)"])
        child_identity = self._identity_for_child(child)
        self._make_v1_runtime(
            key_v1, state="running", pid=leader.pid,
            argv=self._fake_serve_argv(folder_v1),
            child_identity=child_identity,
        )
        (folder_v1 / "config.json").write_text(json.dumps({
            "key": key_v1, "argv": self._fake_serve_argv(folder_v1),
            "launchIdentity": "v1-identity",
            "workspaceSessionId": sid, "workspaceDeviceId": device_a,
        }))

        denied = self._run_manage({"key": key_v1, "action": "retire",
                                   "stopRunning": True})
        self.assertEqual(denied.returncode, 1, denied.stdout)
        self.assertIn("WORKSPACE_CONTROL_LOST", denied.stdout)
        self.assertIsNone(leader.poll())
        self.assertIsNone(child.poll())

        takeover = store.handle({"op": "lease", "sessionId": sid,
                                 "deviceId": device_b, "action": "takeover"})
        self.assertTrue(takeover["ok"], takeover)
        stale = self._run_manage({
            "key": key_v1, "action": "retire", "stopRunning": True,
            "workspaceDeviceId": device_a, "controlToken": lease["token"],
            "controlGeneration": lease["generation"],
        })
        self.assertEqual(stale.returncode, 1, stale.stdout)
        self.assertIn("WORKSPACE_CONTROL_LOST", stale.stdout)
        self.assertIsNone(leader.poll())
        self.assertIsNone(child.poll())

        allowed = self._run_manage({
            "key": key_v1, "action": "retire", "stopRunning": True,
            "workspaceDeviceId": device_b, "controlToken": takeover["token"],
            "controlGeneration": takeover["generation"],
        })
        self.assertEqual(allowed.returncode, 0, allowed.stdout + allowed.stderr)
        self.assertEqual(json.loads(allowed.stdout)["state"], "retired")
        leader.wait(timeout=5.0)
        self._assert_no_live_process(child.pid, timeout=5.0)
        shutil.rmtree(folder_v1)

    def test_broker_fence_renews_lease_in_the_same_check(self):
        calls = []

        class FakeStore:
            @staticmethod
            def check_control(session_id, device_id, token, generation, renew=False):
                calls.append((session_id, device_id, token, generation, renew))
                return True

        broker = object.__new__(acp_broker.Broker)
        broker.config = {"workspaceSessionId": "sess"}
        broker.control_lock = threading.Lock()
        broker.control = {"deviceId": "dev", "token": "tok", "generation": 3}
        original = acp_broker.workspace_module
        acp_broker.workspace_module = lambda: FakeStore
        try:
            self.assertTrue(broker.fence())
        finally:
            acp_broker.workspace_module = original
        self.assertEqual(calls, [("sess", "dev", "tok", 3, True)])

    def test_runtime_bootstrap_meta_is_bounded_and_secret_free(self):
        captured = {}

        class FakeStore:
            @staticmethod
            def register_runtime(runtime_key, session_id=None, device_id=None,
                                 scope=None, meta=None, agent_id=None):
                captured.update(runtime_key=runtime_key, session_id=session_id,
                                device_id=device_id, scope=scope, meta=meta,
                                agent_id=agent_id)

            @staticmethod
            def append_runtime_event(*_a, **_k):
                pass

        broker = object.__new__(acp_broker.Broker)
        broker.folder = type("F", (), {"name": "a" * 64})()
        broker.db = sqlite3.connect(":memory:")
        broker.db.execute(
            "CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)")
        broker.db.execute(
            "INSERT INTO meta VALUES('sessionId', ?)",
            (json.dumps("acp-run-session-xyz"),))
        broker.config = {
            "workspaceSessionId": "ws-sess",
            "workspaceDeviceId": "dev-a",
            "agentId": "agent-7",
            "serverScope": "scope-9",
            "workingDirectory": "/work/dir",
            "title": "Recovered run",
            # Secrets that must never reach the registry metadata.
            "controlToken": "SECRET-TOKEN",
            "controlGeneration": 4,
            "targetIdentity": "leak-me",
            "argv": ["/bin/sh", "-c", "x"],
        }
        original = acp_broker.workspace_module
        acp_broker.workspace_module = lambda: FakeStore
        try:
            broker._register_runtime()
        finally:
            acp_broker.workspace_module = original

        self.assertEqual(captured["runtime_key"], "a" * 64)
        self.assertEqual(captured["agent_id"], "agent-7")
        self.assertEqual(captured["session_id"], "ws-sess")
        meta = captured["meta"]
        self.assertEqual(meta["agentId"], "agent-7")
        self.assertEqual(meta["runtimeKey"], "a" * 64)
        self.assertEqual(meta["workingDirectory"], "/work/dir")
        self.assertEqual(meta["title"], "Recovered run")
        # The ACP runtime session id is learned from the journal meta.
        self.assertEqual(meta["remoteSessionId"], "acp-run-session-xyz")
        for forbidden in ("controlToken", "token", "controlGeneration",
                          "targetIdentity", "argv", "generation"):
            self.assertNotIn(forbidden, meta)

    def test_runtime_catalog_populated_before_first_output(self):
        # Closing the new-device discovery gap: registration must exist right
        # after the runtime starts, not only after the first event/output.
        store = self._install_workspace_store()
        device = "device-start"
        sid = "workspace-start-session"
        self.assertTrue(store.handle({"op": "bootstrap", "deviceId": device})["ok"])
        argv = self._agent_config(chunks=0)
        proc = self._start_attach(argv, extra={
            "workspaceSessionId": sid,
            "workspaceDeviceId": device,
            "agentId": "agent-integration",
            "workingDirectory": "/srv/work",
            "title": "Pre-output run",
        })
        try:
            row = None
            deadline = time.time() + 8.0
            while time.time() < deadline:
                row = store.handle({"op": "runtime_catalog", "sessionId": sid})
                if row.get("ok") and row.get("runtimes"):
                    break
                time.sleep(0.1)
            self.assertTrue(row.get("ok"), row)
            runtimes = row["runtimes"]
            self.assertEqual(len(runtimes), 1, runtimes)
            rt = runtimes[0]
            self.assertEqual(rt["agentId"], "agent-integration")
            self.assertEqual(rt["sessionId"], sid)
            meta = rt["meta"]
            self.assertEqual(meta.get("workingDirectory"), "/srv/work")
            self.assertEqual(meta.get("title"), "Pre-output run")
            self.assertEqual(meta.get("runtimeKey"), self.key)
            self.assertNotIn("controlToken", meta)
        finally:
            self._stop_attach(proc)


if __name__ == "__main__":
    unittest.main(verbosity=2)
