"""Server-side workspace store. Stdio JSON protocol (one request line -> one response line).

Security notes:
- Record ids are opaque database identifiers: bounded at 2048 characters and
  free of control characters.  They are *not* filesystem paths, so ``/`` is
  legal (config/preference/draft ids embed it).
- The only filesystem names derived from user input are 64-char hex blob
  hashes; every directory component is re-verified (owner, no symlink).
- All read/check/write sequences for commit and leases happen inside a single
  ``BEGIN IMMEDIATE`` transaction.  Conflicts roll back before responding.
"""
from __future__ import annotations

import base64
import hashlib
import json
import os
import pathlib
import re
import sqlite3
import stat
import time
import uuid

SCHEMA_VERSION = 1
COMPONENT_VERSION = 2
ROOT = pathlib.Path.home() / ".local/share/valhalla/workspace-v1"
DB_NAME = "store.sqlite3"
BLOBS_DIR = "blobs"
CHUNKS_DIR = "chunks"

MAX_VALUE_BYTES = 256 * 1024
MAX_BLOB_CHUNK = 256 * 1024
MAX_BLOB_CHUNKS = 4096
MAX_BLOB_SIZE = 1024 * 1024 * 1024
MAX_ID_LEN = 2048
MAX_OP_ID_LEN = 2048
MAX_PAGE_LIMIT = 200
MAX_BATCH_RECORDS = 500
MAX_REQUEST_BYTES = 8 * 1024 * 1024
# A page of 200 records x 256 KiB would exceed the root Dart client's 4 MiB
# response cap.  Keep the serialized page (records/events only) below 1 MiB and
# let callers follow the cursor for the rest.  A single record is always
# included even when it is close to the 256 KiB value limit, so records are
# never split and never silently skipped.
MAX_RESPONSE_BYTES = 1024 * 1024
RESPONSE_OVERHEAD_BYTES = 64 * 1024
MAX_PAGE_BYTES = MAX_RESPONSE_BYTES - RESPONSE_OVERHEAD_BYTES
LEASE_TTL = 60

ALLOWED_KINDS = {
    "agent", "preference", "config", "draft", "chat_session",
    "chat_message", "chat_tool", "nas_media",
}

# ---------------------------------------------------------------------------
# Schema-aware allowlists copied from lib/data/workspace/workspace_config_codec.dart
# and lib/data/storage/local_storage_service.dart.  Anything not listed here is
# rejected; there is deliberately no "contains password" text scan because
# ordinary chat/agent text must never be rejected by substring heuristics.
# ---------------------------------------------------------------------------
CONFIG_ITEM_PREFIXES = ("agent", "command", "nas_source")
CONFIG_MAP_KEYS = frozenset({
    "valhalla_chat_run_defaults_v1",
    "valhalla_cli_run_settings_v1",
    "valhalla_chat_launch_preferences_v1",
    "valhalla_chat_last_sessions_v1",
    "valhalla_acp_sessions_v1",
    "valhalla_nas_scan_configs_v1",
    "valhalla_nas_last_scans_v1",
})
CONFIG_SCOPED_PREFIXES = (
    "valhalla_file_bookmarks::",
    "valhalla_recent_directories::",
    "valhalla_default_agent_acp::",
    "valhalla_default_agent_cli::",
    "valhalla_share_agent_sessions::",
    "valhalla_container_shell::",
    "valhalla_terminal_history_v1::",
    "valhalla_terminal_history_v2::",
    "valhalla_terminal_default_v1::",
    "valhalla_terminal_default_v2::",
    "valhalla_terminal_sockets_v1::",
    "valhalla_composer_v1::",
    "valhalla_chat_workspace_v1::",
    "valhalla_app_center_v1::",
    "valhalla_agent_update_v1::",
)
CONFIG_SPECIAL_IDS = frozenset({"valhalla_app_center_v1::sources::global"})

PREFERENCE_KEYS = frozenset({
    "valhalla_theme_mode_v1",
    "valhalla_accent_color_v1",
    "valhalla_accent_color_v2::light",
    "valhalla_accent_color_v2::dark",
    "valhalla_accent_color_v2::amoled",
    "valhalla_locale_v1",
    "valhalla_bottom_navigation_v1",
    "valhalla_dashboard_quick_sections_v1",
    "valhalla_startup_section_v1",
    "valhalla_experimental_features_v1",
    "valhalla_terminal_use_tmux_v1",
    "valhalla_terminal_font_size_v1",
    "valhalla_terminal_pinned_keys_v1",
    "valhalla_terminal_accessory_v2",
    "valhalla_terminal_grid_v1",
    "valhalla_terminal_grid_v2",
    "valhalla_update_auto_v1",
    "valhalla_cli_history_page_size_v1",
    "valhalla_file_sort_key_v1",
    "valhalla_file_sort_asc_v1",
    "valhalla_file_show_hidden_v1",
    "valhalla_remote_file_toolbar_actions_v1",
    "valhalla_file_path_display_mode_v1",
    "valhalla_picker_path_display_mode_v1",
    "valhalla_file_view_mode_v1",
    "valhalla_nas_open_policies_v1",
    "valhalla_app_store_view_mode_v1",
})

DRAFT_PREFIX = "valhalla_chat_draft_v1::"
FILE_DRAFT_PREFIX = "file/"
MAX_DRAFT_PATH_LEN = 4096
_CONTROL_RE = re.compile(r"[\x00-\x1f\x7f]")
_HASH_RE = re.compile(r"[a-f0-9]{64}")
_RUNTIME_RE = re.compile(r"[a-f0-9]{64}")


def _fail(code, **extra):
    out = {"ok": False, "error": code}
    out.update(extra)
    return out


def _ok(**extra):
    out = {"ok": True}
    out.update(extra)
    return out


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
def _opaque_id(value, *, max_len=MAX_ID_LEN):
    """Database ids may contain '/' and '::' but are length/control bounded."""
    if not isinstance(value, str) or not value or len(value) > max_len:
        return False
    return _CONTROL_RE.search(value) is None


def _config_id_ok(rid):
    if rid in CONFIG_SPECIAL_IDS:
        return True
    if any(rid.startswith(prefix) and len(rid) > len(prefix)
           for prefix in CONFIG_SCOPED_PREFIXES):
        return True
    for prefix in CONFIG_ITEM_PREFIXES:
        if rid.startswith(prefix + "/") and len(rid) > len(prefix) + 1:
            return True
    for key in CONFIG_MAP_KEYS:
        if rid.startswith(key + "/") and len(rid) > len(key) + 1:
            return True
    return False


def _preference_id_ok(rid):
    if "/" not in rid:
        return False
    device_class, key = rid.split("/", 1)
    if not device_class or len(device_class) > 64 or _CONTROL_RE.search(device_class):
        return False
    return key in PREFERENCE_KEYS


def _draft_id_parts(rid):
    if "/" not in rid:
        return None, None
    device_id, key = rid.split("/", 1)
    if not device_id or len(device_id) > 128 or _CONTROL_RE.search(device_id):
        return None, None
    return device_id, key


def _file_draft_hash(rid):
    """Return the id hash for ``<device>/file/<hash>`` drafts, else None.

    The hash identifies the per-device *path* draft (a stable slot derived from
    the device's remote path).  It is deliberately independent of any blob
    content hash stored in the value: replacing the file behind the same path
    updates the value/digest without changing the record id.
    """
    _, key = _draft_id_parts(rid)
    if key is None or not key.startswith(FILE_DRAFT_PREFIX):
        return None
    value = key[len(FILE_DRAFT_PREFIX):]
    return value if _HASH_RE.fullmatch(value) else None


def _draft_id_ok(rid):
    device_id, key = _draft_id_parts(rid)
    if device_id is None:
        return False
    if key.startswith(DRAFT_PREFIX) and len(key) > len(DRAFT_PREFIX):
        return True
    # Typed file draft: <device>/file/<sha256>.  Arbitrary path-shaped ids are
    # rejected; the remote path lives in the typed value, never in the id.
    return _file_draft_hash(rid) is not None


def _file_draft_value_ok(value, device_id):
    if not isinstance(value, dict) or value.get("type") != "file":
        return False
    if value.get("deviceId") != device_id:
        return False
    path = value.get("path")
    if not isinstance(path, str) or not path or len(path) > MAX_DRAFT_PATH_LEN \
            or _CONTROL_RE.search(path):
        return False
    digest = value.get("digest")
    if not isinstance(digest, str) or not _HASH_RE.fullmatch(digest):
        return False
    # A blob reference is optional, but every accepted spelling must be a
    # content hash; secret-store keys or filesystem paths are never valid.
    # The blob hash is independent of the id hash: the id identifies the path
    # draft slot, the value identifies the content currently attached to it.
    for key in ("blobHash", "blobRef", "hash"):
        if key in value:
            ref = value[key]
            if not isinstance(ref, str) or not _HASH_RE.fullmatch(ref):
                return False
    if "blob" in value:
        blob = value["blob"]
        if not isinstance(blob, dict):
            return False
        ref = blob.get("hash")
        if not isinstance(ref, str) or not _HASH_RE.fullmatch(ref):
            return False
        if "size" in blob:
            size = blob["size"]
            if isinstance(size, bool) or not isinstance(size, int) or size < 0:
                return False
    return True


def _validate_record(r):
    if not isinstance(r, dict):
        return None, "WORKSPACE_RECORD_INVALID"
    kind = r.get("kind")
    rid = r.get("id")
    if kind not in ALLOWED_KINDS:
        return None, "WORKSPACE_KIND_UNKNOWN"
    if not _opaque_id(rid):
        return None, "WORKSPACE_ID_INVALID"
    if kind == "config" and not _config_id_ok(rid):
        return None, "WORKSPACE_KEY_INVALID"
    if kind == "preference" and not _preference_id_ok(rid):
        return None, "WORKSPACE_KEY_INVALID"
    if kind == "draft" and not _draft_id_ok(rid):
        return None, "WORKSPACE_ID_INVALID"
    value = r.get("value", None)
    if kind == "draft":
        file_hash = _file_draft_hash(rid)
        if file_hash is not None:
            device_id, _ = _draft_id_parts(rid)
            if not (r.get('deleted') is True and value is None) and not _file_draft_value_ok(value, device_id):
                return None, "WORKSPACE_VALUE_INVALID"
    try:
        encoded = json.dumps(value, ensure_ascii=False)
    except Exception:
        return None, "WORKSPACE_VALUE_INVALID"
    if len(encoded.encode("utf-8")) > MAX_VALUE_BYTES:
        return None, "WORKSPACE_VALUE_TOO_LARGE"
    deleted = bool(r.get("deleted", False))
    base = r.get("baseVersion", 0)
    if isinstance(base, bool) or not isinstance(base, int) or base < 0:
        return None, "WORKSPACE_BASE_VERSION_INVALID"
    return {"kind": kind, "id": rid, "value": value,
            "deleted": deleted, "baseVersion": base}, None


def _page_limit(value, default=100):
    if isinstance(value, bool) or not isinstance(value, int) or value < 1:
        return default
    return min(value, MAX_PAGE_LIMIT)


def _fit_page(items, budget=MAX_PAGE_BYTES):
    """Return how many leading ``items`` fit in the serialized page budget.

    At least one item is always returned, so a single maximum-size record is
    never split.  Callers fetch ``limit + 1`` rows and compare the result with
    the fetched length to decide ``hasMore``.
    """
    used = 2  # brackets of the JSON array
    count = 0
    for item in items:
        encoded = json.dumps(item, ensure_ascii=False,
                             separators=(",", ":")).encode("utf-8")
        extra = len(encoded) + (2 if count else 0)  # comma between items
        if count and used + extra > budget:
            break
        used += extra
        count += 1
    return count


def _like_escape(value):
    return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


def _storage_error(exc):
    text = str(exc).lower()
    if "locked" in text or "busy" in text:
        return "WORKSPACE_STORAGE_BUSY"
    if "disk is full" in text or "no space" in text or "full" in text:
        return "WORKSPACE_STORAGE_FULL"
    return "WORKSPACE_STORAGE_FAILED"


# ---------------------------------------------------------------------------
# Filesystem guards
# ---------------------------------------------------------------------------
def _root_chain():
    home = pathlib.Path.home()
    root = ROOT
    try:
        rel = root.relative_to(home)
    except ValueError:
        return [root]
    chain = [home]
    for part in rel.parts:
        chain.append(chain[-1] / part)
    return chain


def _check_existing(path, *, directory=False, strict=False):
    try:
        st = path.lstat()
    except FileNotFoundError:
        return False
    if stat.S_ISLNK(st.st_mode):
        raise ValueError("WORKSPACE_PATH_UNSAFE")
    if directory and not stat.S_ISDIR(st.st_mode):
        raise ValueError("WORKSPACE_PATH_UNSAFE")
    if not directory and not stat.S_ISREG(st.st_mode):
        raise ValueError("WORKSPACE_PATH_UNSAFE")
    if st.st_uid != os.getuid():
        raise ValueError("WORKSPACE_PATH_UNSAFE")
    if strict and (st.st_mode & 0o077):
        os.chmod(path, 0o700 if directory else 0o600)
    return True


def _safe_root():
    for path in _root_chain():
        _check_existing(path, directory=True)
    return ROOT


def _strict_dir(path):
    try:
        st = path.lstat()
    except FileNotFoundError:
        path.mkdir(mode=0o700)
        st = path.lstat()
    if stat.S_ISLNK(st.st_mode) or not stat.S_ISDIR(st.st_mode):
        raise ValueError("WORKSPACE_PATH_UNSAFE")
    if st.st_uid != os.getuid():
        raise ValueError("WORKSPACE_PATH_UNSAFE")
    if st.st_mode & 0o077:
        os.chmod(path, 0o700)
    return path


def _ensure_dirs():
    for path in _root_chain():
        if not _check_existing(path, directory=True):
            path.mkdir(mode=0o700)
        # Only the workspace-owned directories are forced to 0700; $HOME and
        # ~/.local keep the user's existing modes.
        _check_existing(path, directory=True)
    _strict_dir(ROOT)
    _strict_dir(ROOT / BLOBS_DIR)
    _strict_dir(ROOT / CHUNKS_DIR)
    return ROOT


def _guard_sqlite_files():
    for suffix in ("", "-wal", "-shm"):
        path = ROOT / (DB_NAME + suffix)
        try:
            st = path.lstat()
        except FileNotFoundError:
            continue
        if stat.S_ISLNK(st.st_mode) or not stat.S_ISREG(st.st_mode):
            raise ValueError("WORKSPACE_PATH_UNSAFE")
        if st.st_uid != os.getuid():
            raise ValueError("WORKSPACE_PATH_UNSAFE")
        if st.st_mode & 0o077:
            os.chmod(path, 0o600)


def _connect(create=False, readonly=False):
    root = _safe_root()
    db = root / DB_NAME
    if db.is_symlink():
        raise ValueError("WORKSPACE_PATH_UNSAFE")
    if not create and not db.exists():
        raise ValueError("WORKSPACE_NOT_BOOTSTRAPPED")
    _guard_sqlite_files()
    if readonly:
        conn = sqlite3.connect(db.as_uri() + "?mode=ro", uri=True,
                               timeout=10, isolation_level=None)
    else:
        old_umask = os.umask(0o077)
        try:
            conn = sqlite3.connect(str(db), timeout=10, isolation_level=None)
            conn.execute("PRAGMA journal_mode=WAL")
            conn.execute("PRAGMA synchronous=FULL")
        finally:
            os.umask(old_umask)
    conn.row_factory = sqlite3.Row
    _guard_sqlite_files()
    return conn


def _init_schema(conn):
    conn.executescript("""
    CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS records(
        kind TEXT NOT NULL,
        id TEXT NOT NULL,
        value TEXT NOT NULL,
        version INTEGER NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0,
        updated_at REAL NOT NULL,
        PRIMARY KEY(kind, id)
    );
    CREATE TABLE IF NOT EXISTS operations(
        op_id TEXT PRIMARY KEY,
        payload_hash TEXT NOT NULL,
        result TEXT NOT NULL,
        created_at REAL NOT NULL
    );
    CREATE TABLE IF NOT EXISTS leases(
        session_id TEXT PRIMARY KEY,
        device_id TEXT NOT NULL,
        token TEXT NOT NULL,
        generation INTEGER NOT NULL,
        expires_at REAL NOT NULL
    );
    CREATE TABLE IF NOT EXISTS runtimes(
        runtime_key TEXT PRIMARY KEY,
        device_id TEXT,
        session_id TEXT,
        agent_id TEXT,
        scope TEXT,
        registered_at REAL NOT NULL,
        last_seen REAL NOT NULL,
        meta TEXT
    );
    CREATE TABLE IF NOT EXISTS runtime_events(
        seq INTEGER PRIMARY KEY AUTOINCREMENT,
        runtime_key TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at REAL NOT NULL
    );
    CREATE INDEX IF NOT EXISTS runtime_events_key_seq
        ON runtime_events(runtime_key, seq);
    CREATE TABLE IF NOT EXISTS chat_session_catalog(
        id TEXT PRIMARY KEY,
        session_updated_at TEXT NOT NULL DEFAULT '',
        agent_id TEXT,
        participants TEXT NOT NULL DEFAULT '[]',
        title TEXT NOT NULL DEFAULT '',
        deleted INTEGER NOT NULL DEFAULT 0,
        version INTEGER NOT NULL DEFAULT 0
    );
    CREATE INDEX IF NOT EXISTS chat_session_catalog_recent
        ON chat_session_catalog(session_updated_at DESC, id ASC);
    """)
    _ensure_column(conn, "runtimes", "agent_id", "TEXT")
    conn.executescript("""
    CREATE INDEX IF NOT EXISTS runtimes_session_seen
        ON runtimes(session_id, last_seen DESC);
    CREATE INDEX IF NOT EXISTS runtimes_agent_seen
        ON runtimes(agent_id, last_seen DESC);
    CREATE INDEX IF NOT EXISTS runtimes_last_seen
        ON runtimes(last_seen DESC);
    """)
    # Rebuild only metadata; never materialize transcripts during an upgrade.
    # The backfill runs inside a single write transaction (BEGIN IMMEDIATE) so
    # it is atomic and race-safe: only one writer can hold the write lock, and
    # the meta flag is set within the same transaction.  A concurrent bootstrap
    # either observes the finished catalog or runs its own copy (idempotent via
    # PRIMARY KEY / INSERT OR IGNORE), so the flag insert can never raise a
    # UNIQUE violation.  Malformed record values are skipped rather than
    # aborting the whole upgrade, and fetchmany keeps memory bounded regardless
    # of how many chat sessions an older store holds.
    try:
        conn.execute("BEGIN IMMEDIATE")
        if not conn.execute(
                "SELECT 1 FROM meta WHERE key='chat_catalog_v1'").fetchone():
            cursor = conn.execute(
                "SELECT id,value,version,deleted FROM records "
                "WHERE kind='chat_session'")
            while True:
                rows = cursor.fetchmany(100)
                if not rows:
                    break
                for row in rows:
                    try:
                        value = json.loads(row['value'])
                    except Exception:
                        value = {}
                    if not isinstance(value, dict):
                        value = {}
                    participants = value.get('participantAgentIds', [])
                    if not isinstance(participants, list):
                        participants = []
                    conn.execute(
                        "INSERT OR IGNORE INTO chat_session_catalog"
                        "(id,session_updated_at,agent_id,participants,title,deleted,version) "
                        "VALUES(?,?,?,?,?,?,?)",
                        (row['id'],
                         str(value.get('updatedAt') or value.get('updated') or ''),
                         value.get('agentId') or value.get('agent_id'),
                         json.dumps(participants, ensure_ascii=False),
                         value.get('title') or '',
                         row['deleted'], row['version']))
            conn.execute(
                "INSERT OR IGNORE INTO meta(key,value) VALUES('chat_catalog_v1','1')")
        conn.commit()
    except Exception:
        try:
            conn.rollback()
        except Exception:
            pass
        raise
    conn.commit()


def _ensure_column(conn, table, column, decl):
    columns = {row["name"] for row in conn.execute(
        "PRAGMA table_info(%s)" % table).fetchall()}
    if column not in columns:
        conn.execute("ALTER TABLE %s ADD COLUMN %s %s" % (table, column, decl))


def _ensure_runtime_schema(conn):
    """Idempotent upgrade for stores bootstrapped before agent_id/indexes."""
    _ensure_column(conn, "runtimes", "agent_id", "TEXT")
    conn.execute("CREATE INDEX IF NOT EXISTS runtimes_session_seen "
                 "ON runtimes(session_id, last_seen DESC)")
    conn.execute("CREATE INDEX IF NOT EXISTS runtimes_agent_seen "
                 "ON runtimes(agent_id, last_seen DESC)")
    conn.execute("CREATE INDEX IF NOT EXISTS runtimes_last_seen "
                 "ON runtimes(last_seen DESC)")


def _read_schema(conn):
    try:
        row = conn.execute("SELECT value FROM meta WHERE key='schema'").fetchone()
    except sqlite3.OperationalError:
        return None
    if not row:
        return None
    try:
        return json.loads(row[0])
    except Exception:
        return None


def _require_schema(conn):
    schema = _read_schema(conn)
    if schema is None:
        raise ValueError("WORKSPACE_NOT_BOOTSTRAPPED")
    if schema != SCHEMA_VERSION:
        raise ValueError("WORKSPACE_SCHEMA_UNSUPPORTED")


def _meta_get(conn, key, default=None):
    row = conn.execute("SELECT value FROM meta WHERE key=?", (key,)).fetchone()
    if not row:
        return default
    try:
        return json.loads(row["value"])
    except Exception:
        return default


def _meta_set(conn, key, value):
    conn.execute("INSERT OR REPLACE INTO meta VALUES(?,?)", (key, json.dumps(value)))


def _current_revision(conn):
    return int(_meta_get(conn, "revision", 0))


def _user():
    try:
        import pwd
        return pwd.getpwuid(os.getuid()).pw_name
    except Exception:
        return os.environ.get("USER", "user")


def _record_out(row):
    try:
        val = json.loads(row["value"])
    except Exception:
        val = None
    return {
        "kind": row["kind"], "id": row["id"], "value": val,
        "version": row["version"], "deleted": bool(row["deleted"]),
    }


# ---------------------------------------------------------------------------
# Request handling
# ---------------------------------------------------------------------------
def handle(request):
    try:
        return _handle(request)
    except ValueError as exc:
        text = str(exc)
        return _fail(text if text.startswith("WORKSPACE_") else "WORKSPACE_FAILED")
    except sqlite3.OperationalError as exc:
        return _fail(_storage_error(exc))
    except sqlite3.DatabaseError:
        return _fail("WORKSPACE_STORAGE_FAILED")
    except Exception:
        return _fail("WORKSPACE_FAILED")


def _handle(request):
    if not isinstance(request, dict):
        return _fail("WORKSPACE_REQUEST_INVALID")
    op = request.get("op")
    if not isinstance(op, str):
        return _fail("WORKSPACE_OP_INVALID")

    if op == "bootstrap":
        device_id = request.get("deviceId")
        if not _opaque_id(device_id, max_len=128):
            return _fail("WORKSPACE_DEVICE_INVALID")
        _ensure_dirs()
        conn = _connect(create=True)
        try:
            schema = _read_schema(conn)
            if schema is not None and schema != SCHEMA_VERSION:
                return _fail("WORKSPACE_SCHEMA_UNSUPPORTED")
            _init_schema(conn)
            ws = _meta_get(conn, "workspaceId")
            if not ws:
                ws = str(uuid.uuid4())
                _meta_set(conn, "workspaceId", ws)
                _meta_set(conn, "schema", SCHEMA_VERSION)
                _meta_set(conn, "revision", 0)
                _meta_set(conn, "user", _user())
                conn.commit()
            _guard_sqlite_files()
            return _ok(workspaceId=ws, schema=SCHEMA_VERSION, component=COMPONENT_VERSION,
                       revision=_current_revision(conn),
                       user=_meta_get(conn, "user", _user()))
        finally:
            conn.close()

    if op == "discover":
        _safe_root()
        if not (ROOT / DB_NAME).exists():
            return _ok(exists=False)
        conn = _connect(create=False, readonly=True)
        try:
            schema = _read_schema(conn)
            if schema is None:
                return _ok(exists=False)
            if schema != SCHEMA_VERSION:
                return _fail("WORKSPACE_SCHEMA_UNSUPPORTED")
            ws = _meta_get(conn, "workspaceId")
            if not ws:
                return _ok(exists=False)
            return _ok(exists=True, workspaceId=ws, schema=schema, component=COMPONENT_VERSION,
                       revision=_current_revision(conn),
                       user=_meta_get(conn, "user", _user()))
        finally:
            conn.close()

    conn = _connect(create=False)
    try:
        _require_schema(conn)
        return _handle_db(request, op, conn)
    finally:
        conn.close()


def _handle_db(request, op, conn):
    if op == "changes":
        after = request.get("after", 0)
        if isinstance(after, bool) or not isinstance(after, int) or after < 0:
            return _fail("WORKSPACE_CURSOR_INVALID")
        limit = _page_limit(request.get("limit", 100))
        kinds = request.get("kinds")
        params = [after]
        clause = ""
        if kinds is not None:
            if not isinstance(kinds, list) or not kinds or len(kinds) > len(ALLOWED_KINDS):
                return _fail("WORKSPACE_KINDS_INVALID")
            normalized = []
            for kind in kinds:
                if kind not in ALLOWED_KINDS:
                    return _fail("WORKSPACE_KIND_UNKNOWN")
                if kind not in normalized:
                    normalized.append(kind)
            clause = " AND kind IN (%s)" % ",".join("?" * len(normalized))
            params.extend(normalized)
        params.append(limit + 1)
        rows = conn.execute(
            "SELECT kind,id,value,version,deleted FROM records "
            "WHERE version>?%s ORDER BY version LIMIT ?" % clause,
            tuple(params),
        ).fetchall()
        candidates = [_record_out(r) for r in rows[:limit]]
        count = _fit_page(candidates)
        records = candidates[:count]
        has_more = len(rows) > count
        revision = records[-1]["version"] if records else _current_revision(conn)
        return _ok(records=records, revision=revision, hasMore=has_more)

    if op == "snapshot":
        kind = request.get("kind")
        after_id = request.get("afterId", "")
        before_id = request.get("beforeId", "")
        exact_id = request.get("id")
        limit = _page_limit(request.get("limit", 100))
        prefix = request.get("prefix")
        descending = request.get("descending", False)
        if not isinstance(descending, bool):
            return _fail("WORKSPACE_CURSOR_INVALID")
        if kind is not None and kind not in ALLOWED_KINDS:
            return _fail("WORKSPACE_KIND_UNKNOWN")
        if not isinstance(after_id, str) or len(after_id) > MAX_ID_LEN * 2 \
                or _CONTROL_RE.search(after_id):
            return _fail("WORKSPACE_CURSOR_INVALID")
        if not isinstance(before_id, str) or len(before_id) > MAX_ID_LEN * 2 \
                or _CONTROL_RE.search(before_id):
            return _fail("WORKSPACE_CURSOR_INVALID")
        if after_id and before_id:
            # Direction-specific cursors are mutually exclusive.
            return _fail("WORKSPACE_REQUEST_INVALID")
        if exact_id is not None and not _opaque_id(exact_id):
            return _fail("WORKSPACE_ID_INVALID")
        if prefix is not None and (not isinstance(prefix, str)
                                   or len(prefix) > MAX_ID_LEN
                                   or _CONTROL_RE.search(prefix)):
            return _fail("WORKSPACE_PREFIX_INVALID")
        like = None if prefix is None else _like_escape(prefix) + "%"
        compare = "<" if descending else ">"
        order = "DESC" if descending else "ASC"
        # `beforeId` walks upward from the newest page; `afterId` walks
        # forward.  Accepting `afterId` while descending preserves the older
        # reverse-cursor spelling used by early clients.
        cursor = (before_id or after_id) if descending else after_id
        # An empty cursor means "from the beginning" ascending and "from the
        # end" descending; never use the empty string as a SQL bound.
        bounded = cursor != ""
        if kind is not None:
            sql = "SELECT kind,id,value,version,deleted FROM records WHERE kind=?"
            params = [kind]
            if bounded:
                sql += " AND id%s?" % compare
                params.append(cursor)
            if exact_id is not None:
                sql += " AND id=?"
                params.append(exact_id)
            if like is not None:
                sql += " AND id LIKE ? ESCAPE '\\'"
                params.append(like)
            sql += " ORDER BY id %s LIMIT ?" % order
        else:
            sql = "SELECT kind,id,value,version,deleted FROM records WHERE 1=1"
            params = []
            if bounded:
                sql += " AND (kind||':'||id)%s?" % compare
                params.append(cursor)
            if exact_id is not None:
                sql += " AND id=?"
                params.append(exact_id)
            if like is not None:
                sql += " AND id LIKE ? ESCAPE '\\'"
                params.append(like)
            sql += " ORDER BY kind %s,id %s LIMIT ?" % (order, order)
        params.append(limit + 1)
        rows = conn.execute(sql, tuple(params)).fetchall()
        candidates = [_record_out(r) for r in rows[:limit]]
        count = _fit_page(candidates)
        records = candidates[:count]
        has_more = len(rows) > count
        if records:
            next_cursor = records[-1]["id"] if kind is not None else \
                records[-1]["kind"] + ":" + records[-1]["id"]
        else:
            next_cursor = cursor
        return _ok(records=records, revision=_current_revision(conn),
                   hasMore=has_more, nextCursor=next_cursor)

    if op == "chat_catalog":
        limit = _page_limit(request.get("limit", 100))
        cursor = request.get("cursor", "")
        if not isinstance(cursor, str) or len(cursor) > MAX_ID_LEN * 4:
            return _fail("WORKSPACE_CURSOR_INVALID")
        agent_id = request.get("agentId")
        if agent_id is not None and not _opaque_id(agent_id, max_len=MAX_ID_LEN):
            return _fail("WORKSPACE_AGENT_INVALID")
        query = request.get("query", "")
        if not isinstance(query, str) or len(query) > 512:
            return _fail("WORKSPACE_QUERY_INVALID")
        descending = request.get("descending", True)
        if not isinstance(descending, bool):
            return _fail("WORKSPACE_CURSOR_INVALID")
        order_dir = "DESC" if descending else "ASC"
        compare = "<" if descending else ">"
        params = []
        where = "WHERE 1=1"
        if agent_id is not None:
            where += " AND (agent_id=? OR EXISTS(SELECT 1 FROM json_each(participants) WHERE value=?))"
            params.extend([agent_id, agent_id])
        if query:
            where += " AND instr(lower(title), lower(?)) > 0"
            params.append(query)
        # cursor composite: session_updated_at\x00id
        if cursor:
            parts = cursor.split("\\x00", 1)
            if len(parts) != 2:
                return _fail("WORKSPACE_CURSOR_INVALID")
            cur_updated, cur_id = parts
            where += " AND (session_updated_at%s? OR (session_updated_at=? AND id%s?))" % (compare, compare)
            params.extend([cur_updated, cur_updated, cur_id])
        sql = ("SELECT c.id FROM chat_session_catalog c %s "
               "ORDER BY c.session_updated_at %s, c.id %s LIMIT ?" % (where, order_dir, order_dir))
        params.append(limit + 1)
        ids = [r[0] for r in conn.execute(sql, tuple(params)).fetchall()]
        has_more = len(ids) > limit
        page_ids = ids[:limit]
        # fetch records
        records = []
        for sid in page_ids:
            row = conn.execute(
                "SELECT kind,id,value,version,deleted FROM records WHERE kind=? AND id=?",
                ("chat_session", sid),
            ).fetchone()
            if row is not None:
                records.append(_record_out(row))
        count = _fit_page(records)
        records = records[:count]
        has_more = has_more or len(page_ids) > count
        if records:
            last = records[-1]
            # need updated_at for last; query catalog
            cat = conn.execute(
                "SELECT session_updated_at FROM chat_session_catalog WHERE id=?",
                (last["id"],),
            ).fetchone()
            last_updated = cat[0] if cat else ""
            next_cursor = "%s\\x00%s" % (last_updated, last["id"])
        else:
            next_cursor = cursor
        return _ok(records=records, revision=_current_revision(conn),
                   hasMore=has_more, nextCursor=next_cursor)

    if op == "commit":
        device_id = request.get("deviceId")
        if not _opaque_id(device_id, max_len=128):
            return _fail("WORKSPACE_DEVICE_INVALID")
        op_id = request.get("operationId")
        if not _opaque_id(op_id, max_len=MAX_OP_ID_LEN):
            return _fail("WORKSPACE_OPID_INVALID")
        records_in = request.get("records")
        if not isinstance(records_in, list):
            return _fail("WORKSPACE_RECORDS_INVALID")
        if len(records_in) > MAX_BATCH_RECORDS:
            return _fail("WORKSPACE_BATCH_TOO_LARGE")
        parsed = []
        for r in records_in:
            pr, err = _validate_record(r)
            if err:
                return _fail(err)
            parsed.append(pr)
        payload_hash = hashlib.sha256(
            json.dumps({"deviceId": device_id, "records": records_in},
                       sort_keys=True, ensure_ascii=False).encode("utf-8")
        ).hexdigest()

        # Every read/check/write below is inside one write transaction.
        conn.execute("BEGIN IMMEDIATE")
        try:
            row = conn.execute(
                "SELECT payload_hash,result FROM operations WHERE op_id=?", (op_id,)
            ).fetchone()
            if row:
                if row["payload_hash"] != payload_hash:
                    conn.rollback()
                    return _fail("WORKSPACE_OPERATION_CONFLICT")
                try:
                    res = json.loads(row["result"])
                except Exception:
                    res = {"revision": _current_revision(conn)}
                conn.commit()
                return _ok(**res)

            conflicts = []
            for pr in parsed:
                cur = conn.execute(
                    "SELECT version,value,deleted FROM records WHERE kind=? AND id=?",
                    (pr["kind"], pr["id"]),
                ).fetchone()
                cur_ver = cur["version"] if cur else 0
                if cur_ver != pr["baseVersion"]:
                    cur_val = None
                    cur_del = False
                    if cur:
                        try:
                            cur_val = json.loads(cur["value"])
                        except Exception:
                            cur_val = None
                        cur_del = bool(cur["deleted"])
                    conflicts.append({
                        "kind": pr["kind"], "id": pr["id"], "value": cur_val,
                        "version": cur_ver, "deleted": cur_del,
                    })
            if conflicts:
                revision = _current_revision(conn)
                conn.rollback()
                return _fail("WORKSPACE_CONFLICT", records=conflicts,
                             revision=revision)

            rev = _current_revision(conn)
            changed = []
            for pr in parsed:
                rev += 1
                conn.execute(
                    "INSERT OR REPLACE INTO records(kind,id,value,version,deleted,updated_at) "
                    "VALUES(?,?,?,?,?,?)",
                    (pr["kind"], pr["id"],
                     json.dumps(pr["value"], ensure_ascii=False),
                     rev, 1 if pr["deleted"] else 0, time.time()),
                )
                changed.append({
                    "kind": pr["kind"], "id": pr["id"], "value": pr["value"],
                    "version": rev, "deleted": pr["deleted"],
                })
            for pr in parsed:
                if pr["kind"] != "chat_session":
                    continue
                value = pr["value"] if isinstance(pr["value"], dict) else {}
                session_updated_at = str(value.get("updatedAt") or value.get("updated") or "")
                agent_id = value.get("agentId") or value.get("agent_id")
                participants = value.get("participantAgentIds")
                if not isinstance(participants, list):
                    participants = []
                title = value.get("title") or ""
                conn.execute(
                    "INSERT OR REPLACE INTO chat_session_catalog"
                    "(id,session_updated_at,agent_id,participants,title,deleted,version) "
                    "VALUES(?,?,?,?,?,?,?)",
                    (pr["id"], session_updated_at, agent_id,
                     json.dumps(participants, ensure_ascii=False),
                     title, 1 if pr["deleted"] else 0, rev),
                )
            _meta_set(conn, "revision", rev)
            result = {"records": changed, "revision": rev}
            conn.execute(
                "INSERT INTO operations(op_id,payload_hash,result,created_at) VALUES(?,?,?,?)",
                (op_id, payload_hash, json.dumps(result), time.time()),
            )
            conn.commit()
        except sqlite3.OperationalError as exc:
            conn.rollback()
            return _fail(_storage_error(exc))
        except Exception:
            conn.rollback()
            return _fail("WORKSPACE_STORAGE_FAILED")
        _guard_sqlite_files()
        return _ok(**result)

    if op == "lease":
        return _lease(request, conn)

    if op == "check_control":
        session_id = request.get("sessionId")
        device_id = request.get("deviceId")
        token = request.get("token")
        generation = request.get("generation")
        renew = request.get("renew", False)
        if not isinstance(renew, bool):
            renew = False
        if not _opaque_id(session_id, max_len=256):
            return _fail("WORKSPACE_SESSION_INVALID")
        if not _opaque_id(device_id, max_len=128):
            return _fail("WORKSPACE_DEVICE_INVALID")
        if not isinstance(token, str) or not token or len(token) > 256:
            return _fail("WORKSPACE_TOKEN_INVALID")
        if isinstance(generation, bool) or not isinstance(generation, int):
            return _fail("WORKSPACE_GENERATION_INVALID")
        conn.execute("BEGIN IMMEDIATE")
        try:
            row = conn.execute(
                "SELECT device_id,token,generation,expires_at FROM leases WHERE session_id=?",
                (session_id,),
            ).fetchone()
            now = time.time()
            allowed = bool(row is not None and row["device_id"] == device_id
                           and row["token"] == token
                           and row["generation"] == generation
                           and row["expires_at"] > now)
            expires = None
            if allowed:
                expires = row["expires_at"]
                if renew:
                    expires = now + LEASE_TTL
                    conn.execute("UPDATE leases SET expires_at=? WHERE session_id=?",
                                 (expires, session_id))
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        return _ok(allowed=allowed, expiresAt=expires, generation=generation)

    if op == "register_runtime":
        rk = request.get("runtimeKey")
        if not isinstance(rk, str) or not _RUNTIME_RE.fullmatch(rk):
            return _fail("WORKSPACE_RUNTIME_KEY_INVALID")
        _ensure_runtime_schema(conn)
        now = time.time()
        conn.execute("BEGIN IMMEDIATE")
        try:
            _upsert_runtime(conn, rk, request.get("deviceId"),
                            request.get("sessionId"), request.get("scope"),
                            request.get("meta", {}), now,
                            agent_id=request.get("agentId"))
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        return _ok(runtimeKey=rk)

    if op == "runtime_events":
        rk = request.get("runtimeKey")
        if not isinstance(rk, str) or not _RUNTIME_RE.fullmatch(rk):
            return _fail("WORKSPACE_RUNTIME_KEY_INVALID")
        after = request.get("afterSeq", 0)
        if isinstance(after, bool) or not isinstance(after, int) or after < 0:
            after = 0
        limit = _page_limit(request.get("limit", 100))
        rows = conn.execute(
            "SELECT seq,runtime_key,payload FROM runtime_events "
            "WHERE runtime_key=? AND seq>? ORDER BY seq LIMIT ?",
            (rk, after, limit + 1),
        ).fetchall()
        candidates = []
        for r in rows[:limit]:
            try:
                payload = json.loads(r["payload"])
            except Exception:
                payload = None
            candidates.append({"seq": r["seq"], "runtimeKey": r["runtime_key"],
                               "payload": payload})
        count = _fit_page(candidates)
        events = candidates[:count]
        has_more = len(rows) > count
        latest = conn.execute(
            "SELECT COALESCE(MAX(seq),0) FROM runtime_events WHERE runtime_key=?",
            (rk,),
        ).fetchone()[0]
        return _ok(events=events, hasMore=has_more, latestSeq=latest)

    if op == "runtime_catalog":
        _ensure_runtime_schema(conn)
        filters = []
        params = []
        runtime_key = request.get('runtimeKey')
        if runtime_key is not None:
            if not isinstance(runtime_key, str) or not _RUNTIME_RE.fullmatch(runtime_key):
                return _fail('WORKSPACE_RUNTIME_KEY_INVALID')
            filters.append('runtime_key=?')
            params.append(runtime_key)
        session_id = request.get("sessionId")
        if session_id is not None:
            if not _opaque_id(session_id, max_len=256):
                return _fail("WORKSPACE_SESSION_INVALID")
            filters.append("session_id=?")
            params.append(session_id)
        agent_id = request.get("agentId")
        if agent_id is not None:
            if not _opaque_id(agent_id, max_len=256):
                return _fail("WORKSPACE_ID_INVALID")
            filters.append("agent_id=?")
            params.append(agent_id)
        device_id = request.get("deviceId")
        if device_id is not None:
            if not _opaque_id(device_id, max_len=128):
                return _fail("WORKSPACE_DEVICE_INVALID")
            filters.append("device_id=?")
            params.append(device_id)
        scope = request.get("scope")
        if scope is not None:
            if not _opaque_id(scope, max_len=256):
                return _fail("WORKSPACE_ID_INVALID")
            filters.append("scope=?")
            params.append(scope)
        limit = _page_limit(request.get("limit", 100))
        where = (" WHERE " + " AND ".join(filters)) if filters else ""
        params.append(limit)
        rows = conn.execute(
            "SELECT runtime_key,device_id,session_id,agent_id,scope,"
            "registered_at,last_seen,meta FROM runtimes%s "
            "ORDER BY last_seen DESC, runtime_key DESC LIMIT ?" % where,
            tuple(params),
        ).fetchall()
        items = []
        for r in rows:
            try:
                meta = json.loads(r["meta"]) if r["meta"] else {}
            except Exception:
                meta = {}
            items.append({
                "runtimeKey": r["runtime_key"], "deviceId": r["device_id"],
                "sessionId": r["session_id"], "agentId": r["agent_id"],
                "scope": r["scope"],
                "registeredAt": r["registered_at"], "lastSeen": r["last_seen"],
                "meta": meta,
            })
        return _ok(runtimes=items)

    if op == "append_runtime_event":
        rk = request.get("runtimeKey")
        if not isinstance(rk, str) or not _RUNTIME_RE.fullmatch(rk):
            return _fail("WORKSPACE_RUNTIME_KEY_INVALID")
        payload = request.get("payload")
        try:
            encoded = json.dumps(payload, ensure_ascii=False)
        except Exception:
            return _fail("WORKSPACE_VALUE_INVALID")
        if len(encoded.encode("utf-8")) > MAX_VALUE_BYTES:
            return _fail("WORKSPACE_VALUE_TOO_LARGE")
        now = time.time()
        conn.execute("BEGIN IMMEDIATE")
        try:
            cur = conn.execute(
                "INSERT INTO runtime_events(runtime_key,payload,created_at) VALUES(?,?,?)",
                (rk, encoded, now),
            )
            seq = cur.lastrowid
            _upsert_runtime(conn, rk, None, None, None, {}, now, update_only=True)
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        return _ok(seq=seq)

    if op == "blob_put":
        try:
            return _blob_put(request)
        except OSError as exc:
            return _fail(_storage_error(exc))
    if op == "blob_get":
        try:
            return _blob_get(request)
        except OSError as exc:
            return _fail(_storage_error(exc))
    if op == "blob_has":
        try:
            return _blob_has(request)
        except OSError as exc:
            return _fail(_storage_error(exc))

    return _fail("WORKSPACE_OP_UNKNOWN")


def _upsert_runtime(conn, rk, device_id, session_id, scope, meta, now,
                    update_only=False, agent_id=None):
    if update_only:
        conn.execute(
            "INSERT INTO runtimes(runtime_key,registered_at,last_seen,meta) "
            "VALUES(?,?,?,?) ON CONFLICT(runtime_key) DO UPDATE SET "
            "last_seen=excluded.last_seen",
            (rk, now, now, "{}"),
        )
        return
    try:
        meta_text = json.dumps(meta if meta is not None else {})
    except Exception:
        meta_text = "{}"
    conn.execute(
        """INSERT INTO runtimes(runtime_key,device_id,session_id,agent_id,scope,
                                registered_at,last_seen,meta)
           VALUES(?,?,?,?,?,?,?,?)
           ON CONFLICT(runtime_key) DO UPDATE SET
             device_id=excluded.device_id, session_id=excluded.session_id,
             agent_id=COALESCE(excluded.agent_id, runtimes.agent_id),
             scope=excluded.scope, last_seen=excluded.last_seen, meta=excluded.meta""",
        (rk, device_id, session_id, agent_id, scope, now, now, meta_text),
    )


def _lease(request, conn):
    session_id = request.get("sessionId")
    if not _opaque_id(session_id, max_len=256):
        return _fail("WORKSPACE_SESSION_INVALID")
    action = request.get("action")
    if action not in ("acquire", "renew", "takeover", "release"):
        return _fail("WORKSPACE_LEASE_ACTION_INVALID")
    device_id = request.get("deviceId")
    if not _opaque_id(device_id, max_len=128):
        return _fail("WORKSPACE_DEVICE_INVALID")
    token = request.get("token")
    generation = request.get("generation")

    conn.execute("BEGIN IMMEDIATE")
    try:
        row = conn.execute(
            "SELECT device_id,token,generation,expires_at FROM leases WHERE session_id=?",
            (session_id,),
        ).fetchone()
        now = time.time()

        def bad_token():
            conn.rollback()
            return _fail("WORKSPACE_LEASE_INVALID")

        if action == "acquire":
            active = row is not None and row["expires_at"] > now
            if active and row["device_id"] != device_id:
                conn.rollback()
                return _fail("WORKSPACE_CONTROL_HELD", ownerDeviceId=row["device_id"])
            if active:
                # Same device must prove it still owns the current lease.
                if not isinstance(token, str) or not token \
                        or token != row["token"]:
                    return bad_token()
                if isinstance(generation, bool) or not isinstance(generation, int) \
                        or generation != row["generation"]:
                    return bad_token()
                expires = now + LEASE_TTL
                conn.execute("UPDATE leases SET expires_at=? WHERE session_id=?",
                             (expires, session_id))
                conn.commit()
                return _ok(ownerDeviceId=device_id, token=row["token"],
                           expiresAt=expires, generation=row["generation"])
            gen = (row["generation"] if row else 0) + 1
            new_token = str(uuid.uuid4())
            expires = now + LEASE_TTL
            conn.execute(
                "INSERT OR REPLACE INTO leases(session_id,device_id,token,generation,expires_at) "
                "VALUES(?,?,?,?,?)",
                (session_id, device_id, new_token, gen, expires),
            )
            conn.commit()
            return _ok(ownerDeviceId=device_id, token=new_token,
                       expiresAt=expires, generation=gen)

        if action == "takeover":
            gen = (row["generation"] if row else 0) + 1
            new_token = str(uuid.uuid4())
            expires = now + LEASE_TTL
            conn.execute(
                "INSERT OR REPLACE INTO leases(session_id,device_id,token,generation,expires_at) "
                "VALUES(?,?,?,?,?)",
                (session_id, device_id, new_token, gen, expires),
            )
            conn.commit()
            return _ok(ownerDeviceId=device_id, token=new_token,
                       expiresAt=expires, generation=gen)

        if action == "renew":
            if row is None or row["device_id"] != device_id:
                return bad_token()
            if not isinstance(token, str) or not token or token != row["token"]:
                return bad_token()
            if isinstance(generation, bool) or not isinstance(generation, int) \
                    or generation != row["generation"]:
                return bad_token()
            if row["expires_at"] <= now:
                conn.rollback()
                return _fail("WORKSPACE_LEASE_EXPIRED")
            expires = now + LEASE_TTL
            conn.execute("UPDATE leases SET expires_at=? WHERE session_id=?",
                         (expires, session_id))
            conn.commit()
            return _ok(ownerDeviceId=device_id, token=token,
                       expiresAt=expires, generation=generation)

        # release
        if row is None or row["device_id"] != device_id:
            return bad_token()
        if not isinstance(token, str) or not token or token != row["token"]:
            return bad_token()
        if isinstance(generation, bool) or not isinstance(generation, int) \
                or generation != row["generation"]:
            return bad_token()
        # Keep the row (and its generation) as an expired tombstone.  Reusing
        # generation numbers would let a stale writer look current again.
        conn.execute("UPDATE leases SET expires_at=0 WHERE session_id=?",
                     (session_id,))
        conn.commit()
        return _ok(ownerDeviceId=device_id, released=True)
    except Exception:
        conn.rollback()
        raise


# ---------------------------------------------------------------------------
# Blob storage
# ---------------------------------------------------------------------------
def _blob_dir():
    return _strict_dir(ROOT / BLOBS_DIR)


def _chunk_root():
    return _strict_dir(ROOT / CHUNKS_DIR)


def _hash_arg(request):
    h = request.get("hash")
    if not isinstance(h, str) or not _HASH_RE.fullmatch(h):
        return None, _fail("WORKSPACE_BLOB_HASH_INVALID")
    return h, None


def _regular_file(path):
    try:
        st = path.lstat()
    except FileNotFoundError:
        return False
    if stat.S_ISLNK(st.st_mode) or not stat.S_ISREG(st.st_mode):
        raise ValueError("WORKSPACE_PATH_UNSAFE")
    if st.st_uid != os.getuid():
        raise ValueError("WORKSPACE_PATH_UNSAFE")
    return True


def _read_regular(path, offset=0, length=None):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    try:
        st = os.fstat(fd)
        if not stat.S_ISREG(st.st_mode) or st.st_uid != os.getuid():
            raise ValueError("WORKSPACE_PATH_UNSAFE")
        os.lseek(fd, offset, os.SEEK_SET)
        if length is None:
            length = max(0, st.st_size - offset)
        return os.read(fd, length)
    finally:
        os.close(fd)


def _write_file(path, data):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "wb") as out:
        out.write(data)
        out.flush()
        os.fsync(out.fileno())
    os.chmod(path, 0o600)


def _blob_put(request):
    h, err = _hash_arg(request)
    if err:
        return err
    chunk_index = request.get("chunkIndex", 0)
    total_chunks = request.get("totalChunks", 1)
    if isinstance(chunk_index, bool) or not isinstance(chunk_index, int) or chunk_index < 0:
        return _fail("WORKSPACE_CHUNK_INVALID")
    if isinstance(total_chunks, bool) or not isinstance(total_chunks, int) \
            or total_chunks < 1 or total_chunks > MAX_BLOB_CHUNKS:
        return _fail("WORKSPACE_CHUNK_INVALID")
    if chunk_index >= total_chunks:
        return _fail("WORKSPACE_CHUNK_INVALID")
    total_size = request.get("totalSize")
    if total_size is not None:
        if isinstance(total_size, bool) or not isinstance(total_size, int) \
                or total_size < 0 or total_size > MAX_BLOB_SIZE:
            return _fail("WORKSPACE_BLOB_SIZE_INVALID")
    data_b64 = request.get("data", "")
    if not isinstance(data_b64, str):
        return _fail("WORKSPACE_BLOB_DATA_INVALID")
    if len(data_b64) > ((MAX_BLOB_CHUNK + 2) // 3) * 4 + 8:
        return _fail("WORKSPACE_BLOB_CHUNK_TOO_LARGE")
    try:
        chunk_bytes = base64.b64decode(data_b64, validate=True)
    except Exception:
        return _fail("WORKSPACE_BLOB_DATA_INVALID")
    if len(chunk_bytes) > MAX_BLOB_CHUNK:
        return _fail("WORKSPACE_BLOB_CHUNK_TOO_LARGE")

    blobs = _blob_dir()
    final_path = blobs / h
    if _regular_file(final_path):
        return _ok(hash=h, complete=True, size=final_path.stat().st_size, reused=True)

    part_dir = _strict_dir(_chunk_root() / h)
    _write_file(part_dir / str(chunk_index), chunk_bytes)

    for index in range(total_chunks):
        if not _regular_file(part_dir / str(index)):
            return _ok(hash=h, complete=False, received=chunk_index)

    tmp = blobs / (h + ".tmp." + uuid.uuid4().hex)
    try:
        digest = hashlib.sha256()
        written = 0
        fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        with os.fdopen(fd, "wb") as out:
            for index in range(total_chunks):
                chunk = _read_regular(part_dir / str(index))
                written += len(chunk)
                if written > MAX_BLOB_SIZE:
                    raise ValueError("WORKSPACE_BLOB_TOO_LARGE")
                digest.update(chunk)
                out.write(chunk)
            out.flush()
            os.fsync(out.fileno())
        if total_size is not None and written != total_size:
            raise ValueError("WORKSPACE_BLOB_SIZE_MISMATCH")
        if digest.hexdigest() != h:
            raise ValueError("WORKSPACE_BLOB_HASH_MISMATCH")
        os.replace(tmp, final_path)
        os.chmod(final_path, 0o600)
        try:
            dir_fd = os.open(str(blobs), os.O_RDONLY | os.O_DIRECTORY)
            try:
                os.fsync(dir_fd)
            finally:
                os.close(dir_fd)
        except OSError:
            pass
    except ValueError as exc:
        try:
            tmp.unlink(missing_ok=True)
        except OSError:
            pass
        text = str(exc)
        if text.startswith("WORKSPACE_"):
            return _fail(text)
        return _fail("WORKSPACE_STORAGE_FAILED")
    except OSError:
        try:
            tmp.unlink(missing_ok=True)
        except OSError:
            pass
        return _fail("WORKSPACE_STORAGE_FAILED")

    for index in range(total_chunks):
        try:
            (part_dir / str(index)).unlink()
        except OSError:
            pass
    try:
        part_dir.rmdir()
    except OSError:
        pass
    return _ok(hash=h, complete=True, size=final_path.stat().st_size)


def _blob_get(request):
    h, err = _hash_arg(request)
    if err:
        return err
    final_path = _blob_dir() / h
    if not _regular_file(final_path):
        return _fail("WORKSPACE_BLOB_NOT_FOUND")
    size = final_path.stat().st_size
    offset = request.get("offset", 0)
    length = request.get("length", MAX_BLOB_CHUNK)
    if isinstance(offset, bool) or not isinstance(offset, int) or offset < 0:
        return _fail("WORKSPACE_BLOB_OFFSET_INVALID")
    if offset > size:
        return _fail("WORKSPACE_BLOB_OFFSET_INVALID")
    if isinstance(length, bool) or not isinstance(length, int) or length < 1:
        length = MAX_BLOB_CHUNK
    length = min(length, MAX_BLOB_CHUNK, max(0, size - offset))
    chunk = _read_regular(final_path, offset, length)
    return _ok(hash=h, data=base64.b64encode(chunk).decode(), size=size,
               offset=offset, eof=offset + len(chunk) >= size)


def _blob_has(request):
    h, err = _hash_arg(request)
    if err:
        return err
    final_path = _blob_dir() / h
    if _regular_file(final_path):
        return _ok(hash=h, exists=True, size=final_path.stat().st_size)
    return _ok(hash=h, exists=False)


# ---------------------------------------------------------------------------
# Broker integration helpers
# ---------------------------------------------------------------------------
def check_control(session_id, device_id, token, generation, renew=False):
    response = handle({
        "op": "check_control", "sessionId": session_id, "deviceId": device_id,
        "token": token, "generation": generation, "renew": renew,
    })
    return bool(response.get("ok") and response.get("allowed"))


def register_runtime(runtime_key, session_id=None, device_id=None, scope=None,
                     meta=None, agent_id=None):
    response = handle({
        "op": "register_runtime", "runtimeKey": runtime_key,
        "sessionId": session_id, "deviceId": device_id,
        "agentId": agent_id, "scope": scope, "meta": meta or {},
    })
    return bool(response.get("ok"))


def append_runtime_event(runtime_key, payload):
    response = handle({
        "op": "append_runtime_event", "runtimeKey": runtime_key, "payload": payload,
    })
    return response.get("seq") if response.get("ok") else None


def main():
    import sys
    os.umask(0o077)
    raw = sys.stdin.buffer.readline(MAX_REQUEST_BYTES + 1)
    if len(raw) > MAX_REQUEST_BYTES:
        resp = _fail("WORKSPACE_REQUEST_TOO_LARGE")
    else:
        try:
            req = json.loads(raw.decode("utf-8")) if raw.strip() else {}
        except Exception:
            req = None
        resp = handle(req) if req is not None else _fail("WORKSPACE_REQUEST_INVALID")
    sys.stdout.write(json.dumps(resp, ensure_ascii=False, separators=(",", ":")) + "\n")
    sys.stdout.flush()


if __name__ == "__main__":
    main()
