#!/usr/bin/env python3
"""Server-side NAS index for the Valhalla workspace.

This is a standalone stdio helper, like ``workspace_store.py``: one JSON
request line in, one JSON response line out.  It owns a *derived* index file
(``nas-index.sqlite3``) next to ``store.sqlite3`` and never mutates the store.
The store remains the only durable source of truth; this index is rebuilt from
``records`` where ``kind='nas_media'`` in bounded batches.

Root coordination (see ``build/workspace-sync/nas-integration.md``):
- copy this file next to ``workspace_store.py``;
- dispatch ``nas_*`` operations to ``workspace_nas.handle(request)``.

No network listener is created.  Media bytes, thumbnails, downloads and
credentials never reach this helper.
"""
from __future__ import annotations

import json
import os
import pathlib
import re
import sqlite3
import stat
import sys
import urllib.parse

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
try:  # Installed beside store.py; repository tests use workspace_store.py.
    import store as _store
except ImportError:
    import workspace_store as _store

INDEX_NAME = "nas-index.sqlite3"
MAX_PAGE_LIMIT = 200
MAX_BATCH = 500
MAX_PATHS = 600

_SYNC_BATCH = 500
_MAX_SYNC_BATCHES = 512

_CONTROL_RE = re.compile(r"[\x00-\x1f\x7f]")


def _fail(code, **extra):
    out = {"ok": False, "error": code}
    out.update(extra)
    return out


def _ok(**extra):
    out = {"ok": True}
    out.update(extra)
    return out


# ---------------------------------------------------------------------------
# Index storage
# ---------------------------------------------------------------------------
def _index_path(root):
    return root / INDEX_NAME


def _guard(path, *, directory=False):
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
    return True


def _connect_index(root):
    root = _store._safe_root()
    path = _index_path(root)
    for entry in (path, pathlib.Path(str(path)+"-wal"), pathlib.Path(str(path)+"-shm")):
        if _guard(entry) and (entry.stat().st_mode & 0o077):
            os.chmod(entry, 0o600)
    old_umask = os.umask(0o077)
    try:
        conn = sqlite3.connect(str(path), timeout=10, isolation_level=None)
    finally:
        os.umask(old_umask)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=FULL")
    conn.execute("PRAGMA busy_timeout=10000")
    _init_index(conn)
    _guard(path)
    return conn


def _init_index(conn):
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS nas_meta(
            key TEXT PRIMARY KEY, value TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS nas_media(
            source_id TEXT NOT NULL, path TEXT NOT NULL, kind TEXT NOT NULL,
            size_bytes INTEGER NOT NULL DEFAULT 0,
            modified_epoch INTEGER NOT NULL DEFAULT 0,
            mime_type TEXT, duration_millis INTEGER, width INTEGER, height INTEGER,
            title TEXT, artist TEXT, album TEXT, album_id TEXT, album_artist TEXT,
            disc_number INTEGER, track_number INTEGER,
            source_path TEXT, folder TEXT NOT NULL DEFAULT '/',
            sort_name TEXT NOT NULL DEFAULT '',
            album_key TEXT NOT NULL DEFAULT '',
            disc_order INTEGER NOT NULL DEFAULT 2147483647,
            track_order INTEGER NOT NULL DEFAULT 2147483647,
            PRIMARY KEY(source_id, path));
        CREATE TABLE IF NOT EXISTS nas_favorite(
            source_id TEXT NOT NULL, path TEXT NOT NULL,
            value INTEGER NOT NULL DEFAULT 0,
            updated_epoch INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY(source_id, path));
        CREATE TABLE IF NOT EXISTS nas_playlist(
            source_id TEXT NOT NULL, playlist_id TEXT NOT NULL,
            name TEXT NOT NULL, created_epoch INTEGER NOT NULL DEFAULT 0,
            deleted INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY(source_id, playlist_id));
        CREATE TABLE IF NOT EXISTS nas_playlist_item(
            source_id TEXT NOT NULL, playlist_id TEXT NOT NULL,
            path TEXT NOT NULL, position INTEGER NOT NULL,
            deleted INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY(source_id, playlist_id, path));
        CREATE TABLE IF NOT EXISTS nas_playback(
            source_id TEXT NOT NULL, path TEXT NOT NULL,
            position_millis INTEGER NOT NULL DEFAULT 0,
            duration_millis INTEGER,
            updated_epoch INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY(source_id, path));
        CREATE INDEX IF NOT EXISTS nas_media_page
            ON nas_media(source_id, modified_epoch DESC, path);
        CREATE INDEX IF NOT EXISTS nas_media_kind_page
            ON nas_media(source_id, kind, modified_epoch DESC, path);
        CREATE INDEX IF NOT EXISTS nas_media_folder
            ON nas_media(source_id, folder, path);
        CREATE INDEX IF NOT EXISTS nas_media_artist
            ON nas_media(source_id, artist, path);
        CREATE INDEX IF NOT EXISTS nas_media_album
            ON nas_media(source_id, album_key, path);
        CREATE INDEX IF NOT EXISTS nas_media_name
            ON nas_media(source_id, sort_name, path);
        CREATE INDEX IF NOT EXISTS nas_media_size
            ON nas_media(source_id, size_bytes, path);
        CREATE INDEX IF NOT EXISTS nas_favorite_value
            ON nas_favorite(source_id, value, path);
        CREATE INDEX IF NOT EXISTS nas_playlist_item_order
            ON nas_playlist_item(source_id, playlist_id, position, path);
        CREATE INDEX IF NOT EXISTS nas_playback_recent
            ON nas_playback(source_id, updated_epoch DESC, path);
        CREATE VIRTUAL TABLE IF NOT EXISTS nas_search USING fts5(
            path, title, artist, album, content='nas_media',
            content_rowid='rowid', tokenize='unicode61', prefix='2 3 4');
        CREATE TRIGGER IF NOT EXISTS nas_search_insert AFTER INSERT ON nas_media BEGIN
            INSERT INTO nas_search(rowid, path, title, artist, album)
            VALUES (new.rowid, new.path, new.title, new.artist, new.album);
        END;
        CREATE TRIGGER IF NOT EXISTS nas_search_delete AFTER DELETE ON nas_media BEGIN
            INSERT INTO nas_search(nas_search, rowid, path, title, artist, album)
            VALUES ('delete', old.rowid, old.path, old.title, old.artist, old.album);
        END;
        CREATE TRIGGER IF NOT EXISTS nas_search_update
        AFTER UPDATE OF path, title, artist, album ON nas_media
        WHEN old.path IS NOT new.path OR old.title IS NOT new.title
          OR old.artist IS NOT new.artist OR old.album IS NOT new.album BEGIN
            INSERT INTO nas_search(nas_search, rowid, path, title, artist, album)
            VALUES ('delete', old.rowid, old.path, old.title, old.artist, old.album);
            INSERT INTO nas_search(rowid, path, title, artist, album)
            VALUES (new.rowid, new.path, new.title, new.artist, new.album);
        END;
        """
    )


def _meta_get(conn, key, default=None):
    row = conn.execute("SELECT value FROM nas_meta WHERE key=?", (key,)).fetchone()
    return default if row is None else row["value"]


def _meta_set(conn, key, value):
    conn.execute(
        "INSERT INTO nas_meta(key,value) VALUES(?,?) "
        "ON CONFLICT(key) DO UPDATE SET value=excluded.value",
        (key, str(value)),
    )


def _reset_index(conn):
    for table in (
        "nas_media",
        "nas_favorite",
        "nas_playlist",
        "nas_playlist_item",
        "nas_playback",
    ):
        conn.execute("DELETE FROM %s" % table)
    conn.execute("INSERT INTO nas_search(nas_search) VALUES('rebuild')")
    _meta_set(conn, "last_version", 0)


# ---------------------------------------------------------------------------
# Value helpers (must match lib/data/repositories/nas_index_repository.dart)
# ---------------------------------------------------------------------------
def _folder(path):
    end = path.rfind("/")
    return "/" if end <= 0 else path[:end]


def _number_order(value):
    return value if isinstance(value, int) and value > 0 else 2147483647


def _sort_name(path, source_path, title):
    name = source_path or path
    label = title if isinstance(title, str) and title else name.rsplit("/", 1)[-1]
    return label.lower()


def _album_key(value, path, folder, source_path):
    stored = value.get("albumKey")
    if isinstance(stored, str) and stored:
        return stored
    album_id = value.get("albumId")
    if isinstance(album_id, str) and album_id.strip():
        return "id:" + urllib.parse.quote(album_id.strip(), safe="")
    title = (value.get("album") or "").strip()
    author = (value.get("albumArtist") or value.get("artist") or "").strip()
    if not title or not author:
        return "folder:" + urllib.parse.quote(folder, safe="")
    return "tags:%s:%s" % (
        urllib.parse.quote(author, safe=""),
        urllib.parse.quote(title, safe=""),
    )


def _record_type(record_id, value):
    if isinstance(value, dict) and isinstance(value.get("type"), str):
        return value["type"]
    head = record_id.split("/", 1)[0]
    return {
        "media": "media",
        "favorite": "favorite",
        "playback": "playback",
        "playlist": "playlist",
        "playlist_item": "playlist_item",
    }.get(head)


def _apply_media(conn, value, deleted):
    source_id = value.get("sourceId")
    path = value.get("path")
    if not isinstance(source_id, str) or not isinstance(path, str):
        return
    if deleted:
        conn.execute(
            "DELETE FROM nas_media WHERE source_id=? AND path=?",
            (source_id, path),
        )
        return
    source_path = value.get("sourcePath")
    folder = value.get("folder")
    if not isinstance(folder, str) or not folder:
        folder = _folder(source_path or path)
    album_key = _album_key(value, path, folder, source_path)
    disc_order = value.get("discOrder")
    track_order = value.get("trackOrder")
    conn.execute(
        """
        INSERT INTO nas_media(
            source_id,path,kind,size_bytes,modified_epoch,mime_type,
            duration_millis,width,height,title,artist,album,album_id,
            album_artist,disc_number,track_number,source_path,folder,
            sort_name,album_key,disc_order,track_order)
        VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        ON CONFLICT(source_id,path) DO UPDATE SET
            kind=excluded.kind,size_bytes=excluded.size_bytes,
            modified_epoch=excluded.modified_epoch,
            mime_type=COALESCE(excluded.mime_type,nas_media.mime_type),
            duration_millis=COALESCE(excluded.duration_millis,nas_media.duration_millis),
            width=COALESCE(excluded.width,nas_media.width),
            height=COALESCE(excluded.height,nas_media.height),
            title=COALESCE(excluded.title,nas_media.title),
            artist=COALESCE(excluded.artist,nas_media.artist),
            album=COALESCE(excluded.album,nas_media.album),
            album_id=COALESCE(excluded.album_id,nas_media.album_id),
            album_artist=COALESCE(excluded.album_artist,nas_media.album_artist),
            disc_number=COALESCE(excluded.disc_number,nas_media.disc_number),
            track_number=COALESCE(excluded.track_number,nas_media.track_number),
            source_path=COALESCE(excluded.source_path,nas_media.source_path),
            folder=excluded.folder,sort_name=excluded.sort_name,
            album_key=excluded.album_key,disc_order=excluded.disc_order,
            track_order=excluded.track_order
        """,
        (
            source_id,
            path,
            value.get("kind") or "image",
            int(value.get("sizeBytes") or 0),
            int(value.get("modifiedEpoch") or 0),
            value.get("mimeType"),
            value.get("durationMillis"),
            value.get("width"),
            value.get("height"),
            value.get("title"),
            value.get("artist"),
            value.get("album"),
            value.get("albumId"),
            value.get("albumArtist"),
            value.get("discNumber"),
            value.get("trackNumber"),
            source_path,
            folder,
            value.get("sortName")
            or _sort_name(path, source_path, value.get("title")),
            album_key,
            _number_order(disc_order if disc_order is not None
                          else value.get("discNumber")),
            _number_order(track_order if track_order is not None
                          else value.get("trackNumber")),
        ),
    )

def _apply_favorite(conn, value, deleted):
    source_id = value.get("sourceId")
    path = value.get("path")
    if not isinstance(source_id, str) or not isinstance(path, str):
        return
    if deleted:
        conn.execute(
            "DELETE FROM nas_favorite WHERE source_id=? AND path=?",
            (source_id, path),
        )
        return
    epoch = int(value.get("updatedEpoch") or 0)
    conn.execute(
        """INSERT INTO nas_favorite(source_id,path,value,updated_epoch)
        VALUES(?,?,?,?)
        ON CONFLICT(source_id,path) DO UPDATE SET
          value=excluded.value, updated_epoch=excluded.updated_epoch
        WHERE nas_favorite.updated_epoch <= excluded.updated_epoch""",
        (source_id, path, 1 if value.get("value") is True else 0, epoch),
    )


def _apply_playback(conn, value, deleted):
    source_id = value.get("sourceId")
    path = value.get("path")
    if not isinstance(source_id, str) or not isinstance(path, str):
        return
    if deleted:
        conn.execute(
            "DELETE FROM nas_playback WHERE source_id=? AND path=?",
            (source_id, path),
        )
        return
    conn.execute(
        """INSERT INTO nas_playback(
              source_id,path,position_millis,duration_millis,updated_epoch)
        VALUES(?,?,?,?,?)
        ON CONFLICT(source_id,path) DO UPDATE SET
          position_millis=excluded.position_millis,
          duration_millis=excluded.duration_millis,
          updated_epoch=excluded.updated_epoch
        WHERE nas_playback.updated_epoch <= excluded.updated_epoch""",
        (
            source_id,
            path,
            int(value.get("positionMillis") or 0),
            value.get("durationMillis"),
            int(value.get("updatedEpoch") or 0),
        ),
    )


def _apply_playlist(conn, value, deleted):
    source_id = value.get("sourceId")
    playlist_id = value.get("playlistId")
    if not isinstance(source_id, str) or not isinstance(playlist_id, str):
        return
    if deleted:
        conn.execute(
            "DELETE FROM nas_playlist_item WHERE source_id=? AND playlist_id=?",
            (source_id, playlist_id),
        )
        conn.execute(
            "DELETE FROM nas_playlist WHERE source_id=? AND playlist_id=?",
            (source_id, playlist_id),
        )
        return
    conn.execute(
        """INSERT INTO nas_playlist(source_id,playlist_id,name,created_epoch,deleted)
        VALUES(?,?,?,?,0)
        ON CONFLICT(source_id,playlist_id) DO UPDATE SET
          name=excluded.name, deleted=0""",
        (
            source_id,
            playlist_id,
            value.get("name") or "",
            int(value.get("createdEpoch") or 0),
        ),
    )


def _apply_playlist_item(conn, value, deleted):
    source_id = value.get("sourceId")
    playlist_id = value.get("playlistId")
    path = value.get("path")
    if (
        not isinstance(source_id, str)
        or not isinstance(playlist_id, str)
        or not isinstance(path, str)
    ):
        return
    if deleted:
        conn.execute(
            """DELETE FROM nas_playlist_item
            WHERE source_id=? AND playlist_id=? AND path=?""",
            (source_id, playlist_id, path),
        )
        return
    conn.execute(
        """INSERT INTO nas_playlist_item(
              source_id,playlist_id,path,position,deleted)
        VALUES(?,?,?,?,0)
        ON CONFLICT(source_id,playlist_id,path) DO UPDATE SET
          position=excluded.position, deleted=0""",
        (source_id, playlist_id, path, int(value.get("position") or 0)),
    )


_APPLIERS = {
    "media": _apply_media,
    "favorite": _apply_favorite,
    "playback": _apply_playback,
    "playlist": _apply_playlist,
    "playlist_item": _apply_playlist_item,
}


def _sync_index(conn):
    """Catch the derived index up in bounded batches. Store stays read-only."""
    store = _store._connect(create=False, readonly=True)
    try:
        workspace = store.execute(
            "SELECT value FROM meta WHERE key='workspaceId'"
        ).fetchone()
        workspace_id = workspace["value"] if workspace else ""
        if _meta_get(conn, "workspace_id") != workspace_id:
            conn.execute("BEGIN IMMEDIATE")
            try:
                _reset_index(conn)
                _meta_set(conn, "workspace_id", workspace_id)
                conn.commit()
            except Exception:
                conn.rollback()
                raise
        last = int(_meta_get(conn, "last_version", 0) or 0)
        caught_up = True
        for _ in range(_MAX_SYNC_BATCHES):
            rows = store.execute(
                "SELECT id,value,version,deleted FROM records "
                "WHERE kind='nas_media' AND version>? ORDER BY version LIMIT ?",
                (last, _SYNC_BATCH),
            ).fetchall()
            if not rows:
                break
            conn.execute("BEGIN IMMEDIATE")
            try:
                for row in rows:
                    record_id = row["id"]
                    deleted = bool(row["deleted"])
                    try:
                        value = json.loads(row["value"]) if row["value"] is not None else None
                    except Exception:
                        value = None
                    if not isinstance(value, dict):
                        if deleted:
                            value = {}
                        else:
                            value = {}
                    kind = _record_type(record_id, value)
                    applier = _APPLIERS.get(kind)
                    if applier is not None:
                        applier(conn, value, deleted)
                    last = row["version"]
                _meta_set(conn, "last_version", last)
                conn.commit()
            except Exception:
                conn.rollback()
                raise
            if len(rows) < _SYNC_BATCH:
                break
        else:
            # Exhausted the bounded batch budget without reaching the end.
            more = store.execute(
                "SELECT 1 FROM records WHERE kind='nas_media' AND version>? LIMIT 1",
                (last,),
            ).fetchone()
            if more is not None:
                caught_up = False
        return caught_up
    finally:
        store.close()


# ---------------------------------------------------------------------------
# Query helpers
# ---------------------------------------------------------------------------
def _page_limit(value, default=200):
    if isinstance(value, bool) or not isinstance(value, int) or value < 1:
        return default
    return min(value, MAX_PAGE_LIMIT)


def _int_or_none(value):
    if isinstance(value, bool) or not isinstance(value, int):
        return None
    return value


def _sort_column(sort_key):
    return {
        "modified": "(-m.modified_epoch)",
        "name": "m.sort_name",
        "size": "m.size_bytes",
    }.get(sort_key or "modified", "(-m.modified_epoch)")


def _sort_forward(sort_key, ascending):
    return (not ascending) if (sort_key or "modified") == "modified" else ascending


def _search_terms(search):
    terms = [t for t in re.split(r"\s+", search.strip()) if t]
    return " AND ".join('"%s"*' % t.replace('"', '""') for t in terms)


def _where(source_id, *, kind=None, search="", favorites_only=False, folder=None,
           artist=None, album=None, album_key=None, modified_from=None,
           modified_before=None):
    clauses = ["m.source_id = ?"]
    values = [source_id]
    if kind:
        clauses.append("m.kind = ?")
        values.append(kind)
    if favorites_only:
        clauses.append(
            "EXISTS (SELECT 1 FROM nas_favorite f WHERE f.source_id=m.source_id "
            "AND f.path=m.path AND f.value=1)"
        )
    for column, value in (
        ("m.folder", folder),
        ("m.artist", artist),
        ("m.album", album),
        ("m.album_key", album_key),
    ):
        if value is not None:
            clauses.append("%s = ?" % column)
            values.append(value)
    if modified_from is not None:
        clauses.append("m.modified_epoch >= ?")
        values.append(modified_from)
    if modified_before is not None:
        clauses.append("m.modified_epoch < ?")
        values.append(modified_before)
    if modified_from is not None and modified_before is not None \
            and modified_before <= modified_from:
        raise ValueError("NAS_DATE_RANGE_INVALID")
    if search.strip():
        clauses.append(
            "m.rowid IN (SELECT rowid FROM nas_search WHERE nas_search MATCH ?)"
        )
        values.append(_search_terms(search))
    return " AND ".join(clauses), values


def _row_item(row):
    return {
        "path": row["path"],
        "kind": row["kind"],
        "sizeBytes": row["size_bytes"],
        "modifiedEpoch": row["modified_epoch"],
        "mimeType": row["mime_type"],
        "durationMillis": row["duration_millis"],
        "width": row["width"],
        "height": row["height"],
        "title": row["title"],
        "artist": row["artist"],
        "album": row["album"],
        "albumId": row["album_id"],
        "albumArtist": row["album_artist"],
        "discNumber": row["disc_number"],
        "trackNumber": row["track_number"],
        "sourcePath": row["source_path"],
        "favorite": row["favorite"] == 1,
        "favoriteEpoch": row["favorite_epoch"],
    }


def _select_sql(where, order, limit_clause):
    return (
        "SELECT m.*, "
        "COALESCE((SELECT value FROM nas_favorite f WHERE f.source_id=m.source_id "
        "AND f.path=m.path),0) AS favorite, "
        "COALESCE((SELECT updated_epoch FROM nas_favorite f "
        "WHERE f.source_id=m.source_id AND f.path=m.path),0) AS favorite_epoch "
        "FROM nas_media m WHERE %s ORDER BY %s %s" % (where, order, limit_clause)
    )


def _cursor_where(sort_key, ascending, before, inclusive, cursor, album_key):
    clauses = []
    values = []
    if album_key is not None:
        disc = _int_or_none(cursor.get("discOrder"))
        track = _int_or_none(cursor.get("trackOrder"))
        path = cursor.get("path")
        if disc is None or track is None or not isinstance(path, str):
            raise ValueError("NAS_SORT_CURSOR_INVALID")
        compare = "<" if before else ">"
        clauses.append(
            "(m.disc_order, m.track_order, m.path) %s%s (?, ?, ?)"
            % (compare, "=" if inclusive else "")
        )
        values.extend([disc, track, path])
        return " AND ".join(clauses), values
    column = _sort_column(sort_key)
    value = cursor.get("sortValue")
    path = cursor.get("path")
    if (sort_key or "modified") == "name":
        if not isinstance(value, str):
            raise ValueError("NAS_SORT_CURSOR_INVALID")
    else:
        if isinstance(value, bool) or not isinstance(value, int):
            raise ValueError("NAS_SORT_CURSOR_INVALID")
    if not isinstance(path, str):
        raise ValueError("NAS_SORT_CURSOR_INVALID")
    forward = _sort_forward(sort_key, ascending)
    compare = ">" if forward != before else "<"
    clauses.append(
        "(%s, m.path) %s%s (?, ?)" % (column, compare, "=" if inclusive else "")
    )
    values.extend([value, path])
    return " AND ".join(clauses), values


def _next_cursor(row, sort_key, album_key):
    sort_value = {
        "modified": -row["modified_epoch"],
        "name": row["sort_name"],
        "size": row["size_bytes"],
    }.get(sort_key or "modified", -row["modified_epoch"])
    return {
        "sortValue": sort_value,
        "path": row["path"],
        "modifiedEpoch": row["modified_epoch"],
        "discOrder": row["disc_order"],
        "trackOrder": row["track_order"],
    }


# ---------------------------------------------------------------------------
# Operations
# ---------------------------------------------------------------------------
def _op_query(conn, request):
    source_id = request.get("sourceId")
    if not isinstance(source_id, str) or not source_id:
        return _fail("WORKSPACE_SOURCE_INVALID")
    sort_key = request.get("sortKey") or "modified"
    if sort_key not in ("modified", "name", "size"):
        return _fail("WORKSPACE_SORT_INVALID")
    ascending = request.get("ascending") is True
    before = request.get("before") is True
    inclusive = request.get("inclusive") is True
    limit = _page_limit(request.get("limit"))
    offset = request.get("offset")
    where, values = _where(
        source_id,
        kind=request.get("kind"),
        search=request.get("search") or "",
        favorites_only=request.get("favoritesOnly") is True,
        folder=request.get("folder"),
        artist=request.get("artist"),
        album=request.get("album"),
        album_key=request.get("albumKey"),
        modified_from=request.get("modifiedFromEpoch"),
        modified_before=request.get("modifiedBeforeEpoch"),
    )
    album_key = request.get("albumKey")
    cursor = request.get("cursor")
    if isinstance(cursor, dict):
        clause, extra = _cursor_where(
            sort_key, ascending, before, inclusive, cursor, album_key
        )
        where = "%s AND %s" % (where, clause)
        values.extend(extra)
    if album_key is not None:
        order = "m.disc_order, m.track_order, m.path"
    else:
        column = _sort_column(sort_key)
        forward = _sort_forward(sort_key, ascending)
        direction = "ASC" if forward != before else "DESC"
        order = "%s %s, m.path %s" % (column, direction, direction)
    if offset is not None:
        if isinstance(offset, bool) or not isinstance(offset, int) or offset < 0:
            return _fail("WORKSPACE_CURSOR_INVALID")
        sql = _select_sql(where, order, "LIMIT ? OFFSET ?")
        rows = conn.execute(sql, (*values, limit + 1, offset)).fetchall()
        more = len(rows) > limit
        selected = rows[:limit]
        return _ok(
            records=[_row_item(row) for row in selected],
            hasMore=more,
            nextCursor=None,
        )
    rows = conn.execute(
        _select_sql(where, order, "LIMIT ?"), (*values, limit + 1)
    ).fetchall()
    more = len(rows) > limit
    selected = list(rows[:limit])
    if before:
        selected.reverse()
    next_cursor = (
        _next_cursor(selected[-1], sort_key, album_key) if selected else None
    )
    return _ok(
        records=[_row_item(row) for row in selected],
        hasMore=more,
        nextCursor=next_cursor,
    )


def _op_count(conn, request):
    source_id = request.get("sourceId")
    if not isinstance(source_id, str) or not source_id:
        return _fail("WORKSPACE_SOURCE_INVALID")
    where, values = _where(
        source_id,
        kind=request.get("kind"),
        search=request.get("search") or "",
        favorites_only=request.get("favoritesOnly") is True,
        folder=request.get("folder"),
        artist=request.get("artist"),
        album=request.get("album"),
        album_key=request.get("albumKey"),
        modified_from=request.get("modifiedFromEpoch"),
        modified_before=request.get("modifiedBeforeEpoch"),
    )
    row = conn.execute(
        "SELECT COUNT(*) AS n FROM nas_media m WHERE %s" % where, values
    ).fetchone()
    return _ok(count=row["n"])


def _op_totals(conn, request):
    source_id = request.get("sourceId")
    if not isinstance(source_id, str) or not source_id:
        return _fail("WORKSPACE_SOURCE_INVALID")
    kinds = {
        row["kind"]: row["n"]
        for row in conn.execute(
            "SELECT kind, COUNT(*) AS n FROM nas_media WHERE source_id=? "
            "GROUP BY kind",
            (source_id,),
        )
    }
    favorites = conn.execute(
        "SELECT COUNT(*) AS n FROM nas_media m WHERE m.source_id=? "
        "AND EXISTS (SELECT 1 FROM nas_favorite f WHERE f.source_id=m.source_id "
        "AND f.path=m.path AND f.value=1)",
        (source_id,),
    ).fetchone()["n"]
    return _ok(
        totals={
            "total": sum(kinds.values()),
            "images": kinds.get("image", 0),
            "videos": kinds.get("video", 0),
            "audio": kinds.get("audio", 0),
            "favorites": favorites,
        }
    )


def _op_groups(conn, request):
    source_id = request.get("sourceId")
    if not isinstance(source_id, str) or not source_id:
        return _fail("WORKSPACE_SOURCE_INVALID")
    group = request.get("group")
    column = {
        "folder": "m.folder",
        "artist": "COALESCE(m.artist, '')",
        "album": "m.album_key",
        "date": "CASE WHEN m.modified_epoch>0 "
        "THEN date(m.modified_epoch,'unixepoch') ELSE '' END",
    }.get(group)
    if column is None:
        return _fail("WORKSPACE_GROUP_INVALID")
    limit = _page_limit(request.get("limit"))
    where, values = _where(
        source_id,
        kind=request.get("kind"),
        search=request.get("search") or "",
        favorites_only=request.get("favoritesOnly") is True,
        folder=request.get("folder"),
        artist=request.get("artist"),
        album_key=request.get("albumKey"),
        modified_from=request.get("modifiedFromEpoch"),
        modified_before=request.get("modifiedBeforeEpoch"),
    )
    after = request.get("after")
    descending = group == "date"
    boundary = ""
    if isinstance(after, str):
        boundary = " AND %s %s ?" % (column, "<" if descending else ">")
        values = [*values, after]
    rows = conn.execute(
        "SELECT %s AS group_key, COUNT(*) AS n, SUM(m.duration_millis) AS total_duration, "
        "MIN(m.path) AS cover_path FROM nas_media m WHERE %s%s "
        "GROUP BY %s ORDER BY %s %s LIMIT ?"
        % (column, where, boundary, column, column, "DESC" if descending else "ASC"),
        (*values, limit),
    ).fetchall()
    out = []
    for row in rows:
        cover = conn.execute(
            "SELECT m.*, COALESCE((SELECT value FROM nas_favorite f "
            "WHERE f.source_id=m.source_id AND f.path=m.path),0) AS favorite, "
            "COALESCE((SELECT updated_epoch FROM nas_favorite f "
            "WHERE f.source_id=m.source_id AND f.path=m.path),0) AS favorite_epoch "
            "FROM nas_media m WHERE m.source_id=? AND m.path=?",
            (source_id, row["cover_path"]),
        ).fetchone()
        key = row["group_key"] or ""
        name = key
        if group == "album" and cover is not None:
            name = (cover["album"] or "").strip() or cover["folder"] or key
        date_from = None
        date_before = None
        if group == "date":
            if key:
                import datetime

                date_from = int(
                    datetime.datetime.strptime(key, "%Y-%m-%d")
                    .replace(tzinfo=datetime.timezone.utc)
                    .timestamp()
                )
                date_before = date_from + 86400
            else:
                date_before = 1
        out.append(
            {
                "name": name,
                "key": key,
                "count": row["n"],
                "representative": _row_item(cover) if cover is not None else None,
                "totalDurationMillis": row["total_duration"],
                "modifiedFromEpoch": date_from,
                "modifiedBeforeEpoch": date_before,
            }
        )
    return _ok(groups=out)


def _op_playlists(conn, request):
    source_id = request.get("sourceId")
    if not isinstance(source_id, str) or not source_id:
        return _fail("WORKSPACE_SOURCE_INVALID")
    limit = _page_limit(request.get("limit"))
    offset = request.get("offset") or 0
    if isinstance(offset, bool) or not isinstance(offset, int) or offset < 0:
        return _fail("WORKSPACE_CURSOR_INVALID")
    rows = conn.execute(
        """SELECT p.playlist_id AS id, p.name, p.created_epoch,
                  (SELECT COUNT(*) FROM nas_playlist_item i
                   WHERE i.source_id=p.source_id AND i.playlist_id=p.playlist_id
                   AND i.deleted=0) AS item_count
           FROM nas_playlist p
           WHERE p.source_id=? AND p.deleted=0
           ORDER BY p.created_epoch, p.name COLLATE NOCASE
           LIMIT ? OFFSET ?""",
        (source_id, limit, offset),
    ).fetchall()
    return _ok(
        playlists=[
            {
                "id": row["id"],
                "name": row["name"],
                "createdEpoch": row["created_epoch"],
                "itemCount": row["item_count"],
            }
            for row in rows
        ]
    )


def _op_playlist_items(conn, request):
    source_id = request.get("sourceId")
    playlist_id = request.get("playlistId")
    if not isinstance(source_id, str) or not isinstance(playlist_id, str):
        return _fail("WORKSPACE_SOURCE_INVALID")
    after = request.get("afterPosition")
    if after is None:
        after = -1
    if isinstance(after, bool) or not isinstance(after, int):
        return _fail("WORKSPACE_CURSOR_INVALID")
    limit = _page_limit(request.get("limit"))
    rows = conn.execute(
        """SELECT m.*, i.position AS playlist_position,
                  COALESCE((SELECT value FROM nas_favorite f
                   WHERE f.source_id=m.source_id AND f.path=m.path),0) AS favorite,
                  COALESCE((SELECT updated_epoch FROM nas_favorite f
                   WHERE f.source_id=m.source_id AND f.path=m.path),0) AS favorite_epoch
           FROM nas_playlist_item i
           JOIN nas_playlist p ON p.source_id=i.source_id
             AND p.playlist_id=i.playlist_id AND p.deleted=0
           JOIN nas_media m ON m.source_id=i.source_id AND m.path=i.path
           WHERE i.source_id=? AND i.playlist_id=? AND i.deleted=0
             AND i.position > ?
           ORDER BY i.position, i.path LIMIT ?""",
        (source_id, playlist_id, after, limit + 1),
    ).fetchall()
    selected = rows[:limit]
    return _ok(
        records=[_row_item(row) for row in selected],
        nextPosition=selected[-1]["playlist_position"] if selected else None,
        hasMore=len(rows) > limit,
    )


def _op_playback(conn, request):
    source_id = request.get("sourceId")
    paths = request.get("paths")
    if not isinstance(source_id, str) or not source_id:
        return _fail("WORKSPACE_SOURCE_INVALID")
    if not isinstance(paths, list) or not paths or len(paths) > MAX_PATHS:
        return _fail("WORKSPACE_PATHS_INVALID")
    if any(not isinstance(p, str) for p in paths):
        return _fail("WORKSPACE_PATHS_INVALID")
    rows = conn.execute(
        "SELECT * FROM nas_playback WHERE source_id=? AND path IN (%s)"
        % ",".join("?" * len(paths)),
        (source_id, *paths),
    ).fetchall()
    return _ok(
        playback={
            row["path"]: {
                "positionMillis": row["position_millis"],
                "durationMillis": row["duration_millis"],
                "updatedEpoch": row["updated_epoch"],
            }
            for row in rows
        }
    )


def _op_recent(conn, request):
    source_id = request.get("sourceId")
    if not isinstance(source_id, str) or not source_id:
        return _fail("WORKSPACE_SOURCE_INVALID")
    kind = request.get("kind") or "video"
    limit = _page_limit(request.get("limit"))
    rows = conn.execute(
        """SELECT m.*,
                  COALESCE((SELECT value FROM nas_favorite f
                   WHERE f.source_id=m.source_id AND f.path=m.path),0) AS favorite,
                  COALESCE((SELECT updated_epoch FROM nas_favorite f
                   WHERE f.source_id=m.source_id AND f.path=m.path),0) AS favorite_epoch
           FROM nas_playback p
           JOIN nas_media m ON m.source_id=p.source_id AND m.path=p.path
           WHERE p.source_id=? AND m.kind=? AND p.position_millis>0
             AND (p.duration_millis IS NULL OR p.duration_millis<=0
               OR p.position_millis < p.duration_millis-3000)
           ORDER BY p.updated_epoch DESC, m.path LIMIT ?""",
        (source_id, kind, limit),
    ).fetchall()
    return _ok(records=[_row_item(row) for row in rows])


_OPERATIONS = {
    "nas_query": _op_query,
    "nas_count": _op_count,
    "nas_totals": _op_totals,
    "nas_groups": _op_groups,
    "nas_playlists": _op_playlists,
    "nas_playlist_items": _op_playlist_items,
    "nas_playback": _op_playback,
    "nas_recent": _op_recent,
}


def handle(request):
    """Handle one decoded request. Importable by workspace_store for dispatch."""
    if not isinstance(request, dict):
        return _fail("WORKSPACE_REQUEST_INVALID")
    op = request.get("op")
    if not isinstance(op, str):
        return _fail("WORKSPACE_OP_INVALID")
    operation = _OPERATIONS.get(op)
    if operation is None:
        return _fail("WORKSPACE_OP_UNKNOWN")
    try:
        _store._safe_root()
        if not (_store.ROOT / _store.DB_NAME).exists():
            return _fail("WORKSPACE_NOT_BOOTSTRAPPED")
        conn = _connect_index(_store.ROOT)
        try:
            ready = _sync_index(conn)
            if not ready:
                return _fail("WORKSPACE_INDEX_NOT_READY")
            return operation(conn, request)
        finally:
            conn.close()
    except ValueError as exc:
        text = str(exc)
        return _fail(text if text.startswith("WORKSPACE_") else "WORKSPACE_FAILED")
    except sqlite3.OperationalError as exc:
        text = str(exc).lower()
        if "locked" in text or "busy" in text:
            return _fail("WORKSPACE_STORAGE_BUSY")
        return _fail("WORKSPACE_STORAGE_FAILED")
    except sqlite3.DatabaseError:
        return _fail("WORKSPACE_STORAGE_FAILED")
    except Exception:
        return _fail("WORKSPACE_FAILED")


def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            request = json.loads(line)
        except Exception:
            print(json.dumps(_fail("WORKSPACE_REQUEST_INVALID")), flush=True)
            continue
        print(json.dumps(handle(request), ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
