#!/usr/bin/env python3
"""Isolated stdlib unittest coverage for assets/runtime/acp_broker.py.

No production Agent, no real servers, no network ports. Each fixture owns a
temp HOME; every spawned PID is tracked and only those exact PIDs are killed.
"""
from __future__ import annotations

import base64
import hashlib
import json
import os
import pathlib
import select
import signal
import sqlite3
import stat
import subprocess
import sys
import tempfile
import time
import unittest

BROKER = (
    pathlib.Path(__file__).resolve().parents[2]
    / "assets"
    / "runtime"
    / "acp_broker.py"
)

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

    def _start_attach(self, argv: list, after_seq: int = 0) -> subprocess.Popen:
        config = {"key": self.key, "argv": argv, "afterSeq": after_seq}
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

    def _serve_pid(self) -> int:
        pid = self._journal_meta("pid")
        self.assertIsInstance(pid, int)
        self.serve_pids.append(pid)
        return pid

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

if __name__ == "__main__":
    unittest.main(verbosity=2)
