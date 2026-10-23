"""User-owned stdio ACP broker. SSH clients detach; only explicit cancel stops turns."""
import base64
import fcntl
import hashlib
import json
import os
import pathlib
import queue
import re
import signal
import socket
import sqlite3
import subprocess
import sys
import threading
import time

VERSION = 1
RETENTION = 7 * 86400
MAX_LINE = 32 * 1024 * 1024


def encode(value):
    return (json.dumps(value, ensure_ascii=False, separators=(",", ":")) + "\n").encode()


def directory(key):
    if not re.fullmatch(r"[a-f0-9]{64}", key):
        raise ValueError("ACP_RUNTIME_ID_INVALID")
    root = pathlib.Path.home() / ".local/share/valhalla/acp-runtime-v1"
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    if root.is_symlink() or root.stat().st_uid != os.getuid():
        raise ValueError("ACP_RUNTIME_PATH_UNSAFE")
    os.chmod(root, 0o700)
    target = root / key
    target.mkdir(exist_ok=True, mode=0o700)
    if target.is_symlink() or target.stat().st_uid != os.getuid():
        raise ValueError("ACP_RUNTIME_PATH_UNSAFE")
    return target


class Broker:
    def __init__(self, folder):
        self.folder = folder
        self.lock_file = (folder / "lock").open("a")
        fcntl.flock(self.lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
        self.lock = threading.RLock()
        self.db = sqlite3.connect(folder / "journal.sqlite3", check_same_thread=False, isolation_level=None)
        self.db.execute("PRAGMA journal_mode=WAL")
        self.db.execute("PRAGMA synchronous=FULL")
        self.db.execute("CREATE TABLE IF NOT EXISTS events(seq INTEGER PRIMARY KEY, payload TEXT NOT NULL)")
        self.db.execute("CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)")
        self.config = json.loads((folder / "config.json").read_text())
        self.waiters = {}
        self.requests = {}
        self.pending_permissions = {}
        self.clients = set()
        self.next_id = 0
        self.child = None
        self.set_meta("state", "ready")
        self.set_meta("pid", os.getpid())
        self.socket_path = str(folder.parent / (folder.name[:24] + ".sock"))
        if len(self.socket_path.encode()) >= 104:
            raise ValueError("ACP_RUNTIME_SOCKET_PATH_TOO_LONG")
        self.server = socket.socket(socket.AF_UNIX)
        try:
            os.unlink(self.socket_path)
        except FileNotFoundError:
            pass
        self.server.bind(self.socket_path)
        os.chmod(self.socket_path, 0o600)
        self.server.listen(8)
        self.server.settimeout(1)
        self.child = subprocess.Popen(self.config["argv"], stdin=subprocess.PIPE,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, close_fds=True, start_new_session=True)
        threading.Thread(target=self.read_agent, daemon=True).start()
        threading.Thread(target=self.drain_stderr, daemon=True).start()

    def get_meta(self, key, default=None):
        row = self.db.execute("SELECT value FROM meta WHERE key=?", (key,)).fetchone()
        return json.loads(row[0]) if row else default

    def set_meta(self, key, value):
        self.db.execute("INSERT OR REPLACE INTO meta VALUES(?,?)", (key, json.dumps(value)))

    def event(self, payload):
        payload = {**payload, "turnId": self.get_meta("turnId")}
        cursor = self.db.execute("INSERT INTO events(payload) VALUES(?)", (json.dumps(payload),))
        return cursor.lastrowid

    def snapshot(self):
        return {"type": "status", "runtimeKey": self.folder.name,
            "state": self.get_meta("state"), "turnId": self.get_meta("turnId"),
            "sessionId": self.get_meta("sessionId"),
            "seq": self.db.execute("SELECT COALESCE(MAX(seq),0) FROM events").fetchone()[0]}

    def send_agent(self, frame):
        self.child.stdin.write(encode(frame))
        self.child.stdin.flush()

    def update_settings(self, value):
        result = self.get_meta("sessionResult", {})
        if isinstance(value.get("configOptions"), list):
            result["configOptions"] = value["configOptions"]
        if isinstance(value.get("currentModeId"), str):
            result["modes"] = {**result.get("modes", {}), "currentModeId": value["currentModeId"]}
        self.set_meta("sessionResult", result)

    def drain_stderr(self):
        # Login URLs/tokens may appear here. Never journal stderr or credentials.
        for line in self.child.stderr:
            text = line[:16384].decode("utf-8", errors="replace")
            with self.lock:
                for responses in list(self.clients):
                    if responses.qsize() < 256:
                        responses.put({"type": "stderr", "text": text})

    def rpc(self, command, responses):
        frame = command["frame"]
        if isinstance(frame, list):
            for item in frame:
                self.rpc({**command, "frame": item}, responses)
            return
        if not isinstance(frame, dict):
            raise ValueError("ACP_RUNTIME_FRAME_INVALID")
        method = frame.get("method")
        rpc_id = frame.get("id")
        with self.lock:
            if method is None:
                if rpc_id in self.pending_permissions:
                    self.pending_permissions.pop(rpc_id)
                    self.send_agent(frame)
                    if not self.pending_permissions:
                        self.set_meta("state", "running")
                return
            if "id" not in frame:
                if method == "session/cancel":
                    self.set_meta("cancelRequested", True)
                    for permission_id in list(self.pending_permissions):
                        self.send_agent({"jsonrpc": "2.0", "id": permission_id,
                            "result": {"outcome": {"outcome": "cancelled"}}})
                    self.pending_permissions.clear()
                    self.send_agent(frame)
                return
            if method == "initialize" and self.get_meta("initialize") is not None:
                responses.put({"type": "frame", "frame": {"jsonrpc": "2.0", "id": rpc_id,
                    "result": self.get_meta("initialize")}})
                return
            session_id = self.get_meta("sessionId")
            if method in ("session/new", "session/load", "session/resume") and session_id:
                requested = frame.get("params", {}).get("sessionId")
                if method != "session/new" and requested != session_id:
                    raise ValueError("ACP_RUNTIME_SESSION_MISMATCH")
                result = dict(self.get_meta("sessionResult", {}))
                if method == "session/new":
                    result["sessionId"] = session_id
                else:
                    result.pop("sessionId", None)
                responses.put({"type": "frame", "frame": {"jsonrpc": "2.0", "id": rpc_id, "result": result}})
                return
            turn_id = command.get("turnId")
            if method == "session/prompt":
                if self.child.poll() is not None:
                    raise ValueError("ACP_RUNTIME_AGENT_EXITED")
                if not isinstance(turn_id, str) or not re.fullmatch(r"[\w-]{1,100}", turn_id):
                    raise ValueError("ACP_RUNTIME_TURN_INVALID")
                input_hash = hashlib.sha256(encode(frame.get("params", {}))).hexdigest()
                previous_hash = self.get_meta("input:" + turn_id)
                if previous_hash is not None and previous_hash != input_hash:
                    raise ValueError("ACP_RUNTIME_IDEMPOTENCY_CONFLICT")
                previous = self.get_meta("turn:" + turn_id)
                if previous is not None:
                    responses.put({"type": "frame", "turnId": turn_id, "frame":
                        {**previous, "id": rpc_id}, "afterSeq": self.snapshot()["seq"]})
                    return
                if self.get_meta("state") in ("running", "waiting_permission"):
                    if self.get_meta("turnId") == turn_id:
                        existing = next((key for key, value in self.requests.items()
                            if value[0] == "session/prompt"), None)
                        if existing is not None:
                            self.waiters.setdefault(existing, []).append((responses, rpc_id))
                            return
                    raise ValueError("ACP_RUNTIME_TURN_IN_PROGRESS")
                self.set_meta("turnId", turn_id)
                self.set_meta("input:" + turn_id, input_hash)
                self.set_meta("state", "running")
                self.set_meta("cancelRequested", False)
                self.set_meta("finishedAt", None)
            self.next_id += 1
            wire_id = "valhalla-" + str(self.next_id)
            self.requests[wire_id] = (method, turn_id,
                frame.get("params", {}) if method == "session/set_mode" else {})
            self.waiters[wire_id] = [(responses, rpc_id)]
            self.send_agent({**frame, "id": wire_id})

    def read_agent(self):
        try:
            while True:
                line = self.child.stdout.readline(MAX_LINE + 1)
                if not line:
                    break
                if len(line) > MAX_LINE:
                    raise ValueError("ACP_RUNTIME_FRAME_TOO_LARGE")
                frame = json.loads(line)
                if not isinstance(frame, dict):
                    raise ValueError("ACP_RUNTIME_FRAME_INVALID")
                with self.lock:
                    if "method" not in frame and frame.get("id") in self.requests:
                        wire_id = frame["id"]
                        method, turn_id, params = self.requests.pop(wire_id)
                        if "result" in frame:
                            if method == "initialize":
                                self.set_meta("initialize", frame["result"])
                            if method in ("session/new", "session/load", "session/resume"):
                                result = frame["result"]
                                session_id = result.get("sessionId") or self.config.get("sessionId")
                                if session_id:
                                    self.set_meta("sessionId", session_id)
                                self.set_meta("sessionResult", result)
                            if method == "session/set_config_option":
                                self.update_settings(frame["result"])
                            if method == "session/set_mode":
                                self.update_settings({"currentModeId": params.get("modeId")})
                        if method == "session/prompt":
                            cancelled = self.get_meta("cancelRequested", False) or frame.get("result", {}).get("stopReason") == "cancelled"
                            self.pending_permissions.clear()
                            self.set_meta("state", "cancelled" if cancelled else "failed" if "error" in frame else "completed")
                            self.set_meta("finishedAt", time.time())
                            self.set_meta("turn:" + turn_id, frame)
                            completed_seq = self.event({"type": "turn", "state": self.get_meta("state"),
                                "result": frame.get("result"), "error": frame.get("error")})
                        for responses, request_id in self.waiters.pop(wire_id, []):
                            responses.put({"type": "frame", "turnId": turn_id,
                                "afterSeq": completed_seq if method == "session/prompt" else 0,
                                "frame": {**frame, "id": request_id}})
                    elif "method" in frame:
                        method = frame["method"]
                        if method == "session/update":
                            update = frame.get("params", {}).get("update", {})
                            if update.get("sessionUpdate") in ("config_option_update", "current_mode_update"):
                                self.update_settings(update)
                        if method == "session/request_permission":
                            self.pending_permissions[frame["id"]] = frame
                            self.set_meta("state", "waiting_permission")
                        # Authentication events stay transient and are never persisted.
                        if not method.startswith("_auth/"):
                            self.event({"type": "frame", "frame": frame})
                        else:
                            for responses in self.clients:
                                responses.put({"type": "frame", "frame": frame})
        except Exception:
            pass
        finally:
            try:
                with self.lock:
                    self.set_meta("agentExited", True)
                    if self.get_meta("state") not in ("completed", "failed", "cancelled", "expired"):
                        self.set_meta("state", "exited")
                        self.set_meta("finishedAt", time.time())
                        self.event({"type": "turn", "state": "exited", "error": "ACP_RUNTIME_AGENT_EXITED"})
                    for waiters in self.waiters.values():
                        for responses, request_id in waiters:
                            responses.put({"type": "frame", "frame": {"jsonrpc": "2.0", "id": request_id,
                                "error": {"code": -32001, "message": "ACP_RUNTIME_AGENT_EXITED"}}})
                    self.waiters.clear()
            except sqlite3.Error:
                with self.lock:
                    for responses in self.clients:
                        responses.put({"type": "runtime_error", "error": "ACP_RUNTIME_JOURNAL_FAILED"})
            finally:
                if self.child.poll() is None:
                    self.stop_agent()

    def stop_agent(self):
        try:
            os.killpg(self.child.pid, signal.SIGTERM)
            self.child.wait(timeout=3)
        except subprocess.TimeoutExpired:
            os.killpg(self.child.pid, signal.SIGKILL)
            self.child.wait(timeout=3)
        except ProcessLookupError:
            pass

    def client(self, connection):
        responses = queue.Queue()
        with self.lock:
            self.clients.add(responses)
        stopped = threading.Event()
        reader = connection.makefile("rb")
        try:
            hello = json.loads(reader.readline(MAX_LINE + 1))
            cursor = hello.get("afterSeq", 0)
            if not isinstance(cursor, int) or cursor < 0:
                raise ValueError("ACP_RUNTIME_CURSOR_INVALID")
            def writer():
                nonlocal cursor
                caught_up = False
                sent_permissions = set()
                delayed = []
                try:
                    with self.lock:
                        status = self.snapshot()
                        pending = list(self.pending_permissions.values())
                    connection.sendall(encode(status))
                    while not stopped.is_set():
                        for _ in range(32):
                            try:
                                delayed.append(responses.get_nowait())
                            except queue.Empty:
                                break
                        with self.lock:
                            rows = self.db.execute("SELECT seq,payload FROM events WHERE seq>? ORDER BY seq LIMIT 100", (cursor,)).fetchall()
                            idle_status = self.snapshot() if not rows else None
                        for seq, payload in rows:
                            value = json.loads(payload)
                            frame = value.get("frame", {})
                            if frame.get("method") == "session/request_permission":
                                with self.lock:
                                    pending_now = frame["id"] in self.pending_permissions
                                if not pending_now:
                                    cursor = seq
                                    continue
                                sent_permissions.add(frame["id"])
                            connection.sendall(encode({**value, "seq": seq}))
                            cursor = seq
                        remaining = []
                        for response in delayed:
                            if response.get("afterSeq", 0) <= cursor:
                                connection.sendall(encode(response))
                            else:
                                remaining.append(response)
                        delayed = remaining
                        if not rows and not caught_up:
                            status = {**idle_status, "seq": cursor}
                            connection.sendall(encode({**status, "type": "caught_up"}))
                            for frame in pending:
                                with self.lock:
                                    still_pending = frame["id"] in self.pending_permissions
                                if still_pending and frame["id"] not in sent_permissions:
                                    connection.sendall(encode({"type": "frame", "frame": frame,
                                        "turnId": status["turnId"]}))
                            caught_up = True
                        if not rows:
                            stopped.wait(.05)
                except (OSError, ValueError):
                    stopped.set()
                    try:
                        connection.shutdown(socket.SHUT_RDWR)
                    except OSError:
                        pass
            thread = threading.Thread(target=writer, daemon=True)
            thread.start()
            for line in reader:
                if len(line) > MAX_LINE:
                    break
                try:
                    self.rpc(json.loads(line), responses)
                except Exception as error:
                    responses.put({"type": "runtime_error", "error": str(error) if isinstance(error, ValueError) else "ACP_RUNTIME_REQUEST_FAILED"})
        except (OSError, ValueError):
            pass
        finally:
            stopped.set()
            with self.lock:
                self.clients.discard(responses)
            connection.close()

    def serve(self):
        while True:
            try:
                connection, _ = self.server.accept()
                threading.Thread(target=self.client, args=(connection,), daemon=True).start()
            except socket.timeout:
                with self.lock:
                    finished = self.get_meta("finishedAt")
                    if self.get_meta("state") in ("completed", "failed", "cancelled", "exited") and finished and time.time() - finished > RETENTION:
                        self.set_meta("state", "expired")
                        self.db.execute("DELETE FROM events")
                        self.db.execute("DELETE FROM meta WHERE key LIKE 'turn:%'")
                        self.db.execute("PRAGMA wal_checkpoint(TRUNCATE)")
                        self.db.execute("VACUUM")
                        self.stop_agent()
                        return


def attach(config):
    folder = directory(config["key"])
    config_file = folder / "config.json"
    launch_identity = config.get("targetIdentity") or hashlib.sha256(encode(config["argv"])).hexdigest()
    if config_file.exists():
        previous = json.loads(config_file.read_text())
        if previous["launchIdentity"] != launch_identity:
            raise ValueError("ACP_RUNTIME_TARGET_CHANGED")
    else:
        fd = os.open(config_file, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "w") as out:
            json.dump({**config, "launchIdentity": launch_identity}, out)
    address = str(folder.parent / (folder.name[:24] + ".sock"))
    client = socket.socket(socket.AF_UNIX)
    try:
        client.connect(address)
    except (FileNotFoundError, ConnectionRefusedError):
        # Existing journals are not permission to repeat a lost running command.
        if (folder / "journal.sqlite3").exists():
            raise ValueError("ACP_RUNTIME_PROCESS_EXITED")
        subprocess.Popen([sys.executable, str(pathlib.Path(__file__).resolve()), "serve", str(folder)],
            stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            start_new_session=True, close_fds=True)
        for _ in range(100):
            try:
                client.connect(address)
                break
            except (FileNotFoundError, ConnectionRefusedError):
                time.sleep(.05)
        else:
            raise ValueError("ACP_RUNTIME_START_FAILED")
    client.sendall(encode({"afterSeq": config.get("afterSeq", 0)}))
    def incoming():
        try:
            for line in sys.stdin.buffer:
                if len(line) > MAX_LINE:
                    break
                client.sendall(line)
        finally:
            try:
                client.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
    threading.Thread(target=incoming, daemon=True).start()
    for line in client.makefile("rb"):
        message = json.loads(line)
        if message.get("type") == "stderr":
            sys.stderr.write(message.get("text", ""))
            sys.stderr.flush()
        else:
            sys.stdout.buffer.write(line)
            sys.stdout.buffer.flush()


if __name__ == "__main__":
    os.umask(0o077)
    try:
        if sys.argv[1] == "probe":
            if sys.version_info < (3, 9) or not hasattr(socket, "AF_UNIX"):
                raise ValueError("ACP_RUNTIME_UNSUPPORTED")
            print(json.dumps({"version": VERSION, "python": list(sys.version_info[:3])}))
        elif sys.argv[1] == "serve":
            Broker(pathlib.Path(sys.argv[2])).serve()
        elif sys.argv[1] == "attach":
            attach(json.loads(base64.b64decode(sys.argv[2])))
        else:
            raise ValueError("ACP_RUNTIME_COMMAND_INVALID")
    except Exception as error:
        print(json.dumps({"type": "runtime_error", "error": str(error) if isinstance(error, ValueError) else "ACP_RUNTIME_FAILED"}), flush=True)
        sys.exit(1)
