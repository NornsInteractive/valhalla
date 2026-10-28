"""User-owned stdio ACP broker. SSH clients detach; only explicit cancel stops turns."""
import base64
import fcntl
import hashlib
import importlib.util
import json
import os
import pathlib
import queue
import re
import signal
import shutil
import socket
import sqlite3
import subprocess
import sys
import threading
import time

VERSION = 2
RETENTION = 7 * 86400
MAX_LINE = 32 * 1024 * 1024
TERMINAL_STATES = {"completed", "failed", "cancelled", "exited", "expired", "retired"}


def existing_directory(key):
    if not isinstance(key, str) or not re.fullmatch(r"[a-f0-9]{64}", key):
        raise ValueError("ACP_RUNTIME_ID_INVALID")
    root = pathlib.Path.home() / ".local/share/valhalla/acp-runtime-v1"
    target = root / key
    for path in (root, target):
        if path.is_symlink() or (path.exists() and path.stat().st_uid != os.getuid()):
            raise ValueError("ACP_RUNTIME_PATH_UNSAFE")
    return target


def read_meta(folder):
    journal = folder / "journal.sqlite3"
    for path in (journal, folder / "journal.sqlite3-wal", folder / "journal.sqlite3-shm"):
        if path.is_symlink() or (path.exists() and path.stat().st_uid != os.getuid()):
            raise ValueError("ACP_RUNTIME_PATH_UNSAFE")
    if not journal.exists():
        return {}
    with sqlite3.connect(journal.as_uri() + "?mode=ro", uri=True, timeout=2) as db:
        return {key: json.loads(value) for key, value in db.execute("SELECT key,value FROM meta")}


def process_identity(pid):
    try:
        path = pathlib.Path("/proc") / str(int(pid))
        if path.stat().st_uid != os.getuid():
            return None
        stat = (path / "stat").read_text().rsplit(")", 1)[1].split()
        if stat[0] == 'Z':
            return None
        return {"pid": int(pid), "parent": int(stat[1]), "group": int(stat[2]),
            "started": stat[19], "argv": (path / "cmdline").read_bytes().split(b"\0")[:-1]}
    except (OSError, ValueError, TypeError):
        return None



def live_group(group):
    members = []
    for path in pathlib.Path("/proc").iterdir():
        if not path.name.isdigit():
            continue
        try:
            fields = (path / "stat").read_text().rsplit(")", 1)[1].split()
            if int(fields[2]) == group and fields[0] != "Z":
                if path.stat().st_uid != os.getuid():
                    raise ValueError("ACP_RUNTIME_OWNERSHIP_UNVERIFIED")
                members.append(int(path.name))
        except (FileNotFoundError, ProcessLookupError):
            continue
    return members


def stop_owned_group(identity):
    group = identity["group"]
    if not live_group(group):
        return
    current = process_identity(identity["pid"])
    if current is None or any(current[key] != identity[key] for key in ("pid", "group", "started")):
        raise ValueError("ACP_RUNTIME_OWNERSHIP_UNVERIFIED")
    # Keep checking descendants after the verified group leader has exited.
    for sig in (signal.SIGTERM, signal.SIGKILL):
        try:
            os.killpg(group, sig)
        except ProcessLookupError:
            return
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            if not live_group(group):
                return
            time.sleep(.05)
    raise ValueError("ACP_RUNTIME_STOP_TIMEOUT")


def inspect_runtime(key):
    folder = existing_directory(key)
    meta = read_meta(folder)
    result = {"runtimeKey": key, "state": meta.get("state", "missing"),
        "alive": False, "childAlive": False, "protocolVersion": 1,
        "sessionId": meta.get("sessionId"), "turnId": meta.get("turnId")}
    address = folder.parent / (key[:24] + ".sock")
    try:
        with socket.socket(socket.AF_UNIX) as client:
            client.settimeout(3)
            client.connect(str(address))
            client.sendall(encode({"action": "inspect"}))
            frame = json.loads(client.makefile("rb").readline(MAX_LINE + 1))
            if frame.get("type") in ("status", "management"):
                return {**result, **frame, "alive": True,
                    "childAlive": frame.get("childAlive", not meta.get("agentExited", False))}
    except (OSError, ValueError):
        pass
    return result


def legacy_retire(folder, meta, stop_running):
    if meta.get("state") in ("running", "waiting_permission") and not stop_running:
        raise ValueError("ACP_RUNTIME_TURN_IN_PROGRESS")
    child = meta.get("childIdentity")
    if isinstance(child, dict):
        stop_owned_group(child)
    pid = meta.get("pid")
    observed = process_identity(pid)
    if observed is None:
        if pid is not None:
            try:
                os.kill(int(pid), 0)
            except ProcessLookupError:
                return
            raise ValueError("ACP_RUNTIME_OWNERSHIP_UNVERIFIED")
        return
    argv = observed["argv"]
    if len(argv) < 4 or argv[-2:] != [b"serve", os.fsencode(folder)]:
        if meta.get("state") in TERMINAL_STATES:
            return  # The recorded PID has been reused; never signal its new owner.
        raise ValueError("ACP_RUNTIME_OWNERSHIP_UNVERIFIED")
    children = pathlib.Path(f"/proc/{pid}/task/{pid}/children").read_text().split()
    for child_pid in children:
        child = process_identity(child_pid)
        if child is None or child["parent"] != pid or child["group"] != child["pid"]:
            raise ValueError("ACP_RUNTIME_OWNERSHIP_UNVERIFIED")
        if process_identity(pid) != observed or process_identity(child_pid) != child:
            raise ValueError("ACP_RUNTIME_OWNERSHIP_UNVERIFIED")
        stop_owned_group(child)
    if process_identity(pid) == observed:
        os.kill(pid, signal.SIGTERM)


def manage_runtime(command):
    key, action = command["key"], command.get("action", "inspect")
    folder = existing_directory(key)
    if action == "inspect":
        return inspect_runtime(key)
    if action not in ("retire", "purge"):
        raise ValueError("ACP_RUNTIME_COMMAND_INVALID")
    if not folder.exists():
        return {"runtimeKey": key, "state": "missing"}
    # Reject links before making a connection or removing anything.
    for path in folder.iterdir():
        if path.is_symlink() or path.is_dir() or path.stat().st_uid != os.getuid():
            raise ValueError("ACP_RUNTIME_PATH_UNSAFE")
    # Management retire/purge is a mutating operation when the runtime belongs
    # to a workspace.  Read-only inspect above is always allowed; a stale
    # device cannot stop another device's Agent.  Legacy runtimes are unchanged.
    config = runtime_config(folder)
    if not workspace_control_allowed(config, workspace_control_context(command),
                                     renew=True):
        raise ValueError("WORKSPACE_CONTROL_LOST")
    status = inspect_runtime(key)
    if status["state"] in ("running", "waiting_permission") and not command.get("stopRunning", False):
        raise ValueError("ACP_RUNTIME_TURN_IN_PROGRESS")
    if status["alive"] and status.get("protocolVersion", 1) >= 2:
        with socket.socket(socket.AF_UNIX) as client:
            client.settimeout(10)
            client.connect(str(folder.parent / (key[:24] + ".sock")))
            context = workspace_control_context(command)
            client.sendall(encode({
                "action": "retire",
                "stopRunning": command.get("stopRunning", False),
                "deviceId": context["deviceId"],
                "controlToken": context["token"],
                "controlGeneration": context["generation"],
            }))
            result = json.loads(client.makefile("rb").readline(MAX_LINE + 1))
            if result.get("error"):
                raise ValueError(result["error"])
    else:
        legacy_retire(folder, read_meta(folder), command.get("stopRunning", False))
    lock_path = folder / "lock"
    with lock_path.open("a") as lock:
        deadline = time.monotonic() + 5
        while True:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.monotonic() >= deadline:
                    raise ValueError("ACP_RUNTIME_STOP_TIMEOUT")
                time.sleep(.05)
        if action == "purge":
            # Only one verified private runtime directory; never an Agent's history.
            address = folder.parent / (key[:24] + ".sock")
            if address.exists():
                if address.is_symlink() or not address.is_socket() or address.stat().st_uid != os.getuid():
                    raise ValueError("ACP_RUNTIME_PATH_UNSAFE")
                address.unlink()
            shutil.rmtree(folder)
        else:
            journal = folder / "journal.sqlite3"
            if journal.exists():
                with sqlite3.connect(journal) as db:
                    db.execute("INSERT OR REPLACE INTO meta VALUES('state',?)", (json.dumps("retired"),))
    return {"runtimeKey": key, "state": "purged" if action == "purge" else "retired"}


def active_runtimes(scope, exclude=None, probe=True):
    root = existing_directory("0" * 64).parent
    if not root.exists():
        return []
    active = []
    for path in root.iterdir():
        if not re.fullmatch(r"[a-f0-9]{64}", path.name) or path.name == exclude:
            continue
        folder = existing_directory(path.name)
        config_file = folder / "config.json"
        if config_file.is_symlink():
            raise ValueError("ACP_RUNTIME_PATH_UNSAFE")
        try:
            config = json.loads(config_file.read_text())
            if config.get("serverScope") not in (None, scope):
                continue
            meta = read_meta(folder)
            if meta.get("state") in ("running", "waiting_permission"):
                active.append(inspect_runtime(path.name) if probe else
                    {"runtimeKey": path.name, "state": meta["state"]})
        except FileNotFoundError:
            continue
    return active


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



def workspace_module():
    try:
        path = pathlib.Path.home() / ".local/share/valhalla/workspace-v1/store.py"
        if not path.is_file() or path.is_symlink():
            return None
        if path.stat().st_uid != os.getuid():
            return None
        spec = importlib.util.spec_from_file_location("valhalla_workspace_store", path)
        if spec is None or spec.loader is None:
            return None
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        return mod
    except Exception:
        return None


def workspace_enabled(config):
    return isinstance(config.get("workspaceSessionId"), str) and bool(config.get("workspaceSessionId"))


def workspace_control_context(source):
    """Extract lease credentials from an attach hello or manage command."""
    if not isinstance(source, dict):
        return {"deviceId": None, "token": None, "generation": None}
    token = source.get("controlToken")
    generation = source.get("controlGeneration")
    if token is None:
        token = source.get("token")
    if generation is None:
        generation = source.get("generation")
    return {
        "deviceId": source.get("workspaceDeviceId") or source.get("deviceId"),
        "token": token,
        "generation": generation,
    }


def workspace_control_allowed(config, control, renew=False):
    """Fail-closed lease check for code paths that run outside a Broker.

    Read-only inspection never calls this; management writes and mutating
    frames do.  A lost lease only refuses the write, it never signals the Agent.
    """
    if not workspace_enabled(config):
        return True
    session_id = config.get("workspaceSessionId")
    if not isinstance(session_id, str) or not session_id:
        return False
    device_id = control.get("deviceId") if isinstance(control, dict) else None
    token = control.get("token") if isinstance(control, dict) else None
    generation = control.get("generation") if isinstance(control, dict) else None
    if not isinstance(device_id, str) or not device_id:
        return False
    if not isinstance(token, str) or not token:
        return False
    if isinstance(generation, bool) or not isinstance(generation, int):
        return False
    module = workspace_module()
    if module is None:
        return False
    try:
        return bool(module.check_control(session_id, device_id, token,
                                         generation, renew=renew))
    except Exception:
        return False


def runtime_config(folder):
    path = folder / "config.json"
    if path.is_symlink():
        raise ValueError("ACP_RUNTIME_PATH_UNSAFE")
    try:
        return json.loads(path.read_text())
    except FileNotFoundError:
        return {}
    except (OSError, ValueError):
        raise ValueError("ACP_RUNTIME_PATH_UNSAFE")


def is_mutating_frame(frame):
    if not isinstance(frame, dict):
        return False
    method = frame.get("method")
    if method in ("session/prompt", "session/cancel", "session/set_mode",
                  "session/set_config_option", "session/new", "session/load",
                  "session/resume"):
        return True
    if "id" in frame and "method" not in frame:
        return True
    return False



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
        # Register with the workspace store before the child produces any output,
        # so a freshly launched runtime is discoverable even if the launching
        # app exits before the chat_session metadata record is committed.
        self._register_runtime()
        self.waiters = {}
        self.requests = {}
        self.pending_permissions = {}
        self.clients = set()
        self.next_id = 0
        self.child = None
        self.stopping = threading.Event()
        self.scope_file = None
        self.control_lock = threading.Lock()
        self.control = {
            "deviceId": self.config.get("workspaceDeviceId") or self.config.get("deviceId"),
            "token": self.config.get("controlToken"),
            "generation": self.config.get("controlGeneration"),
        }
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
        child_identity = process_identity(self.child.pid)
        if child_identity is not None:
            self.set_meta("childIdentity", {key: child_identity[key] for key in ("pid", "group", "started")})
        self.agent_reader = threading.Thread(target=self.read_agent, daemon=True)
        self.agent_reader.start()
        threading.Thread(target=self.drain_stderr, daemon=True).start()

    def update_control(self, hello):
        """Remember the newest authenticated writer; readers never set a token."""
        if not isinstance(hello, dict):
            return
        token = hello.get("controlToken")
        generation = hello.get("controlGeneration")
        device_id = hello.get("deviceId") or hello.get("workspaceDeviceId")
        if not isinstance(token, str) or not token:
            return
        if isinstance(generation, bool) or not isinstance(generation, int):
            return
        with self.control_lock:
            self.control = {
                "deviceId": device_id or self.config.get("workspaceDeviceId"),
                "token": token,
                "generation": generation,
            }

    def control_snapshot(self):
        with self.control_lock:
            return dict(self.control)

    def fence(self, control=None):
        """Verify the current lease immediately before a mutation.

        The store performs the check and the heartbeat renewal in one
        ``BEGIN IMMEDIATE`` transaction, so a lease cannot expire between the
        validity check and the renewal.  Agents are never stopped when control
        is lost; only the stale writer's request is refused.
        """
        if not workspace_enabled(self.config):
            return True
        session_id = self.config.get("workspaceSessionId")
        if not isinstance(session_id, str) or not session_id:
            return False
        context = control if control is not None else self.control_snapshot()
        device_id = context.get("deviceId")
        token = context.get("token")
        generation = context.get("generation")
        if not isinstance(device_id, str) or not device_id:
            return False
        if not isinstance(token, str) or not token:
            return False
        if isinstance(generation, bool) or not isinstance(generation, int):
            return False
        module = workspace_module()
        if module is None:
            return False
        return bool(module.check_control(session_id, device_id, token,
                                         generation, renew=True))

    def get_meta(self, key, default=None):
        row = self.db.execute("SELECT value FROM meta WHERE key=?", (key,)).fetchone()
        return json.loads(row[0]) if row else default

    def set_meta(self, key, value):
        self.db.execute("INSERT OR REPLACE INTO meta VALUES(?,?)", (key, json.dumps(value)))

    def _runtime_bootstrap(self):
        """Bounded, portable metadata a new device needs to discover/join.

        Only non-secret fields are included. Tokens, control credentials, argv
        and target identity are deliberately excluded.
        """
        meta = {
            "agentId": self.config.get("agentId"),
            "runtimeKey": self.folder.name,
            "workingDirectory": self.config.get("workingDirectory"),
            "title": self.config.get("title"),
        }
        sid = self.get_meta("sessionId") or self.config.get("sessionId")
        if sid:
            meta["remoteSessionId"] = sid
        cid = self.config.get("chatSessionId")
        if cid:
            meta["chatSessionId"] = cid
        return {k: v for k, v in meta.items() if v is not None}

    def _register_runtime(self):
        """Idempotent registration with the workspace store.

        Called once at broker start (before the first agent output) and again on
        every event, so a runtime is discoverable even if the app exits before
        the chat_session metadata record is committed. Credentials are never
        written into the registry.
        """
        if not workspace_enabled(self.config):
            return
        try:
            mod = workspace_module()
            if mod is None:
                return
            sid = self.config.get("workspaceSessionId")
            mod.register_runtime(self.folder.name, session_id=sid,
                                device_id=self.config.get("workspaceDeviceId") or
                                self.config.get("deviceId"),
                                agent_id=self.config.get("agentId"),
                                scope=self.config.get("serverScope"),
                                meta=self._runtime_bootstrap())
        except Exception:
            pass

    def event(self, payload):
        payload = {**payload, "turnId": self.get_meta("turnId")}
        cursor = self.db.execute("INSERT INTO events(payload) VALUES(?)", (json.dumps(payload),))
        seq = cursor.lastrowid
        try:
            mod = workspace_module()
            if mod is not None and workspace_enabled(self.config):
                sid = self.config.get("workspaceSessionId")
                mod.append_runtime_event(self.folder.name, {"seq": seq, "payload": payload})
                mod.register_runtime(self.folder.name, session_id=sid,
                                    device_id=self.config.get("workspaceDeviceId"),
                                    agent_id=self.config.get("agentId"),
                                    scope=self.config.get("serverScope"),
                                    meta=self._runtime_bootstrap())
        except Exception:
            pass
        return seq

    def snapshot(self):
        status = {"type": "status", "runtimeKey": self.folder.name,
            "protocolVersion": VERSION, "alive": True,
            "childAlive": self.child is not None and self.child.poll() is None,
            "state": self.get_meta("state"), "turnId": self.get_meta("turnId"),
            "sessionId": self.get_meta("sessionId"),
            "seq": self.db.execute("SELECT COALESCE(MAX(seq),0) FROM events").fetchone()[0]}
        # Legacy (no workspace) runtimes report protocol 0 and never leak a
        # session id.  Workspace-enabled runtimes add the lease session so a
        # new device can join read-only without guessing.
        if workspace_enabled(self.config):
            status["workspaceProtocol"] = 1
            status["workspaceSessionId"] = self.config.get("workspaceSessionId")
        else:
            status["workspaceProtocol"] = 0
        return status

    def claim_scope(self, turn_id):
        scope = self.config.get("serverScope")
        if scope is None:
            return
        if not isinstance(scope, str) or not re.fullmatch(r"[a-f0-9]{64}", scope):
            raise ValueError("ACP_RUNTIME_SCOPE_INVALID")
        path = self.folder.parent / ("active-" + scope + ".lock")
        fd = os.open(path, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
        stream = os.fdopen(fd, "r+")
        try:
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
            # v1 brokers do not hold the new lock. Treat their unfinished turns as busy.
            if active_runtimes(scope, exclude=self.folder.name, probe=False):
                raise ValueError("ACP_RUNTIME_SERVER_BUSY")
            stream.seek(0)
            stream.truncate()
            stream.write(json.dumps({"runtimeKey": self.folder.name, "turnId": turn_id}))
            stream.flush()
            self.scope_file = stream
        except BlockingIOError:
            stream.close()
            raise ValueError("ACP_RUNTIME_SERVER_BUSY")
        except Exception:
            stream.close()
            raise

    def release_scope(self):
        stream, self.scope_file = self.scope_file, None
        if stream is not None:
            stream.seek(0)
            stream.truncate()
            stream.flush()
            stream.close()

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
                self.claim_scope(turn_id)
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
                            self.release_scope()
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
                    if self.get_meta("state") not in TERMINAL_STATES:
                        self.set_meta("state", "exited")
                        self.set_meta("finishedAt", time.time())
                        self.event({"type": "turn", "state": "exited", "error": "ACP_RUNTIME_AGENT_EXITED"})
                    for waiters in self.waiters.values():
                        for responses, request_id in waiters:
                            responses.put({"type": "frame", "frame": {"jsonrpc": "2.0", "id": request_id,
                                "error": {"code": -32001, "message": "ACP_RUNTIME_AGENT_EXITED"}}})
                    self.waiters.clear()
                    self.release_scope()
            except sqlite3.Error:
                with self.lock:
                    for responses in self.clients:
                        responses.put({"type": "runtime_error", "error": "ACP_RUNTIME_JOURNAL_FAILED"})
            finally:
                if self.child.poll() is None:
                    self.stop_agent()

    def stop_agent(self):
        if self.child is None:
            return
        identity = self.get_meta("childIdentity")
        if identity is not None:
            stop_owned_group(identity)
        elif self.child.poll() is None:
            raise ValueError("ACP_RUNTIME_OWNERSHIP_UNVERIFIED")
        if self.child.poll() is None:
            self.child.wait(timeout=3)

    def client(self, connection):
        responses = queue.Queue()
        with self.lock:
            self.clients.add(responses)
        stopped = threading.Event()
        reader = connection.makefile("rb")
        try:
            hello = json.loads(reader.readline(MAX_LINE + 1))
            if hello.get("action") in ("inspect", "retire"):
                # Inspect stays read-only.  Retire/purge is a management write
                # and must present a live lease when the runtime is workspace
                # enabled; otherwise an old device could stop the Agent.
                if hello["action"] == "retire" and not workspace_control_allowed(
                        self.config, workspace_control_context(hello), renew=True):
                    connection.sendall(encode({"error": "WORKSPACE_CONTROL_LOST"}))
                    return
                with self.lock:
                    status = self.snapshot()
                    if hello["action"] == "retire":
                        if status["state"] in ("running", "waiting_permission") and not hello.get("stopRunning", False):
                            connection.sendall(encode({"error": "ACP_RUNTIME_TURN_IN_PROGRESS"}))
                            return
                if hello["action"] == "retire":
                    try:
                        self.stop_agent()
                    except (ValueError, OSError, subprocess.TimeoutExpired) as error:
                        connection.sendall(encode({"error": str(error) if isinstance(error, ValueError) else "ACP_RUNTIME_STOP_TIMEOUT"}))
                        return
                    with self.lock:
                        if status["state"] in ("running", "waiting_permission"):
                            self.event({"type": "turn", "state": "cancelled"})
                        self.set_meta("state", "retired")
                        self.set_meta("finishedAt", time.time())
                connection.sendall(encode({**status, "type": "management"}))
                if hello["action"] == "retire":
                    self.stopping.set()
                return
            cursor = hello.get("afterSeq", 0)
            if not isinstance(cursor, int) or cursor < 0:
                raise ValueError("ACP_RUNTIME_CURSOR_INVALID")
            self.update_control(hello)
            control = {
                "deviceId": hello.get("deviceId") or hello.get("workspaceDeviceId")
                or self.config.get("workspaceDeviceId"),
                "token": hello.get("controlToken"),
                "generation": hello.get("controlGeneration"),
            }
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
                    while not stopped.is_set() and not self.stopping.is_set():
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
                except (OSError, ValueError, sqlite3.Error):
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
                    command = json.loads(line)
                    if isinstance(command, dict) and command.get("type") == "control_heartbeat":
                        # Client-driven heartbeat: only an attached/foreground
                        # device renews its own lease.  The server never renews
                        # on behalf of a disconnected device.
                        allowed = (not workspace_enabled(self.config)) or self.fence(
                            workspace_control_context(command))
                        responses.put({"type": "control_heartbeat",
                                       "allowed": bool(allowed)})
                        continue
                    frame = command.get("frame") if isinstance(command, dict) else None
                    if (isinstance(frame, dict) and is_mutating_frame(frame)
                            and workspace_enabled(self.config)):
                        if not self.fence(control):
                            responses.put({"type": "runtime_error", "error": "WORKSPACE_CONTROL_LOST"})
                            continue
                    self.rpc(command, responses)
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
        try:
            while not self.stopping.is_set():
                try:
                    connection, _ = self.server.accept()
                    threading.Thread(target=self.client, args=(connection,), daemon=True).start()
                except socket.timeout:
                    with self.lock:
                        finished = self.get_meta("finishedAt")
                        expired = self.get_meta("state") in TERMINAL_STATES and finished and time.time() - finished > RETENTION
                        if expired:
                            self.set_meta("state", "expired")
                            self.db.execute("DELETE FROM events")
                            self.db.execute("DELETE FROM meta WHERE key LIKE 'turn:%'")
                            self.db.execute("PRAGMA wal_checkpoint(TRUNCATE)")
                            self.db.execute("VACUUM")
                    if expired:
                        return
        finally:
            self.stopping.set()
            self.stop_agent()
            self.agent_reader.join(timeout=3)
            self.release_scope()
            self.server.close()
            try:
                os.unlink(self.socket_path)
            except FileNotFoundError:
                pass
            self.db.close()
            self.lock_file.close()


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
    hello = {"afterSeq": config.get("afterSeq", 0)}
    for key in ("deviceId", "workspaceDeviceId", "controlToken", "controlGeneration"):
        if key in config:
            hello[key] = config[key]
    client.sendall(encode(hello))
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
        elif sys.argv[1] == "manage":
            print(json.dumps(manage_runtime(json.loads(base64.b64decode(sys.argv[2])))))
        elif sys.argv[1] == "active":
            print(json.dumps(active_runtimes(sys.argv[2])))
        else:
            raise ValueError("ACP_RUNTIME_COMMAND_INVALID")
    except Exception as error:
        print(json.dumps({"type": "runtime_error", "error": str(error) if isinstance(error, ValueError) else "ACP_RUNTIME_FAILED"}), flush=True)
        sys.exit(1)
