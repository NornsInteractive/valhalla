#!/usr/bin/env python3
"""Regression coverage for the chat_session catalog and its bootstrap backfill.

The catalog lets a Dart worker page through chat-session *metadata* (title,
agent, participants, updatedAt, tombstone flag) without materializing
transcripts.  It is maintained live on every commit and rebuilt from existing
records during a store upgrade (bootstrap).

Every test owns an isolated temp HOME and a temp module ROOT, so the real user
store is never touched.  Records are seeded with randomized ids and strictly
chronological ISO-8601 updatedAt values, which is what the Dart sync side emits
(ChatSession.toJson -> updatedAt.toIso8601String()).
"""
import json
import os
import pathlib
import secrets
import sqlite3
import tempfile
import threading
import unittest
import uuid
from datetime import datetime, timedelta

import importlib.util

MODULE = pathlib.Path(__file__).resolve().parents[2] / "assets" / "runtime" / "workspace_store.py"
SPEC = importlib.util.spec_from_file_location("workspace_store", MODULE)
ws = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ws)

BASE_DT = datetime(2024, 1, 1, 0, 0, 0)


class WorkspaceChatCatalogTests(unittest.TestCase):
    def setUp(self):
        self.td = tempfile.TemporaryDirectory(prefix="ws_catalog_")
        self.home = pathlib.Path(self.td.name)
        self.old_home = os.environ.get("HOME")
        os.environ["HOME"] = str(self.home)
        ws.ROOT = self.home / ".local/share/valhalla/workspace-v1"
        self.device = str(uuid.uuid4())

    def tearDown(self):
        if self.old_home is None:
            os.environ.pop("HOME", None)
        else:
            os.environ["HOME"] = self.old_home
        self.td.cleanup()

    # -- helpers --------------------------------------------------------
    def call(self, req):
        return ws.handle(req)

    def bootstrap(self):
        r = self.call({"op": "bootstrap", "deviceId": self.device})
        self.assertTrue(r["ok"], r)
        return r

    def commit(self, records, device=None):
        return self.call({
            "op": "commit", "deviceId": device or self.device,
            "operationId": str(uuid.uuid4()), "records": records,
        })

    def raw(self):
        return sqlite3.connect(str(ws.ROOT / ws.DB_NAME), timeout=15)

    def _simulate_precatalog_store(self):
        """Drop the catalog table + flag so a later bootstrap must backfill."""
        conn = self.raw()
        conn.execute("DROP TABLE IF EXISTS chat_session_catalog")
        conn.execute("DELETE FROM meta WHERE key='chat_catalog_v1'")
        conn.commit()
        conn.close()

    def seed(self, specs):
        """Commit chat_session records from ``specs`` and return their metadata.

        Ensures the store is bootstrapped first (commit requires an existing db).
        """
        self.bootstrap()

        records = []
        metas = []
        for i, spec in enumerate(specs):
            sid = "session/" + uuid.uuid4().hex
            updated = (BASE_DT + timedelta(seconds=i)).strftime("%Y-%m-%dT%H:%M:%SZ")
            agent = spec.get("agent", "agent/default")
            participants = spec.get("participants", [agent])
            title = spec.get("title", "Session %d %s" % (i, secrets.token_hex(4)))
            value = {
                "id": sid, "title": title, "agentId": agent,
                "participantAgentIds": participants, "updatedAt": updated,
                "messages": [{"role": "user", "text": "hello"}],
            }
            if spec.get("big"):
                value["messages"] = [{"role": "user", "text": "x" * 20000} for _ in range(2)]
            deleted = bool(spec.get("deleted", False))
            records.append({"kind": "chat_session", "id": sid, "value": value,
                            "baseVersion": 0, "deleted": deleted})
            metas.append({"id": sid, "updatedAt": updated, "agent": agent,
                          "participants": participants, "title": title,
                          "deleted": deleted})
        r = self.commit(records)
        self.assertTrue(r["ok"], r)
        return metas

    # -- tests ----------------------------------------------------------
    def test_page1_latest_not_lexicographic_id(self):
        metas = self.seed([{} for _ in range(260)])
        page = self.call({"op": "chat_catalog", "descending": True, "limit": 100})
        self.assertTrue(page["ok"], page)
        ids = [r["id"] for r in page["records"]]
        upds = [r["value"]["updatedAt"] for r in page["records"]]
        # First record must be the chronologically latest, not the lexicographically
        # smallest/largest id.
        self.assertEqual(upds[0], max(m["updatedAt"] for m in metas))
        expected = [m["id"] for m in sorted(
            metas, key=lambda m: (m["updatedAt"], m["id"]), reverse=True)]
        self.assertEqual(ids, expected[:100])
        # The ordering is genuinely by updatedAt, so it differs from a pure id
        # lexicographic ordering (ids are random).
        id_desc = sorted((m["id"] for m in metas), reverse=True)
        self.assertNotEqual(ids, id_desc[:100])

    def test_cursor_no_duplicates_no_skips(self):
        metas = self.seed([{} for _ in range(260)])
        all_ids = {m["id"] for m in metas}
        collected = []  # (id, updatedAt)
        cursor = ""
        while True:
            page = self.call({"op": "chat_catalog", "descending": True,
                              "limit": 13, "cursor": cursor})
            self.assertTrue(page["ok"], page)
            if not page["records"]:
                break
            for r in page["records"]:
                collected.append((r["id"], r["value"]["updatedAt"]))
            if not page["hasMore"]:
                break
            cursor = page["nextCursor"]
        ids = [c[0] for c in collected]
        self.assertEqual(len(ids), len(set(ids)),
                         "duplicate ids across pages")
        self.assertEqual(set(ids), all_ids, "coverage mismatch")
        # Strictly monotonic descending by (updatedAt, id).
        prev = None
        for cid, upd in collected:
            key = (upd, cid)
            if prev is not None:
                self.assertTrue(prev >= key, "ordering not monotonic")
            prev = key

    def test_agent_participant_filter(self):
        specs = []
        for i in range(40):
            if i < 10:
                specs.append({"agent": "agent/A", "participants": ["agent/A"]})
            elif i < 20:
                specs.append({"agent": "agent/B", "participants": ["agent/B"]})
            elif i < 30:
                specs.append({"agent": "agent/Z", "participants": ["agent/Z"]})
            else:
                # agent Z but lists agent A as a participant -> must match A query
                specs.append({"agent": "agent/Z", "participants": ["agent/A", "agent/X"]})
        metas = self.seed(specs)
        page = self.call({"op": "chat_catalog", "agentId": "agent/A", "limit": 200})
        self.assertTrue(page["ok"], page)
        got = {r["id"] for r in page["records"]}
        expected = {m["id"] for m in metas
                    if m["agent"] == "agent/A" or "agent/A" in m["participants"]}
        self.assertEqual(got, expected)
        self.assertEqual(len(expected), 20)  # 10 owned + 10 participants

    def test_title_query_filter(self):
        specs = []
        for i in range(30):
            title = "Alpha sync notes %d" % i if i % 3 == 0 else "Beta notes %d" % i
            specs.append({"title": title})
        metas = self.seed(specs)
        page = self.call({"op": "chat_catalog", "query": "alpha", "limit": 200})
        self.assertTrue(page["ok"], page)
        got = {r["id"] for r in page["records"]}
        expected = {m["id"] for m in metas if "alpha" in m["title"].lower()}
        self.assertEqual(got, expected)
        # Combined agent + query still works.
        combined = self.call({"op": "chat_catalog", "agentId": "agent/default",
                              "query": "alpha", "limit": 200})
        self.assertTrue(combined["ok"], combined)
        self.assertEqual({r["id"] for r in combined["records"]}, expected)

    def test_byte_budget_respected(self):
        metas = self.seed([{"big": True} for _ in range(50)])
        page = self.call({"op": "chat_catalog", "limit": 200})
        self.assertTrue(page["ok"], page)
        self.assertTrue(page["hasMore"], "byte budget must cap the page")
        self.assertLess(len(page["records"]), len(metas))
        encoded = sum(len(json.dumps(r, ensure_ascii=False).encode()) for r in page["records"])
        self.assertLessEqual(encoded, ws.MAX_PAGE_BYTES)
        # Walking still covers every session (budget defers tail, never drops).
        collected = []
        cursor = ""
        while True:
            p = self.call({"op": "chat_catalog", "limit": 200, "cursor": cursor})
            if not p["records"]:
                break
            collected.extend(r["id"] for r in p["records"])
            if not p["hasMore"]:
                break
            cursor = p["nextCursor"]
        self.assertEqual(set(collected), {m["id"] for m in metas})

    def test_tombstones_returned(self):
        specs = [{"deleted": (i % 5 == 0)} for i in range(40)]
        metas = self.seed(specs)
        page = self.call({"op": "chat_catalog", "limit": 200})
        self.assertTrue(page["ok"], page)
        deleted_ids = {m["id"] for m in metas if m["deleted"]}
        seen = {r["id"] for r in page["records"] if r["deleted"]}
        self.assertTrue(deleted_ids.issubset(seen),
                        "tombstoned sessions must be surfaced for the client")
        # The Dart worker can find a specific tombstone by id.
        tomb = next(m["id"] for m in metas if m["deleted"])
        snap = self.call({"op": "snapshot", "kind": "chat_session", "id": tomb, "limit": 1})
        self.assertTrue(snap["ok"], snap)
        self.assertTrue(any(r["id"] == tomb and r["deleted"] for r in snap["records"]))

    def test_catalog_stores_metadata_not_transcript(self):
        metas = self.seed([{} for _ in range(10)])
        conn = self.raw()
        cols = [r[1] for r in conn.execute(
            "PRAGMA table_info(chat_session_catalog)").fetchall()]
        self.assertEqual(set(cols), {"id", "session_updated_at", "agent_id",
                                     "participants", "title", "deleted", "version"})
        self.assertNotIn("value", cols)
        self.assertNotIn("messages", cols)
        row = conn.execute(
            "SELECT participants,title,agent_id,session_updated_at "
            "FROM chat_session_catalog WHERE id=?", (metas[0]["id"],)).fetchone()
        self.assertEqual(json.loads(row[0]), metas[0]["participants"])
        self.assertEqual(row[1], metas[0]["title"])
        self.assertEqual(row[2], metas[0]["agent"])
        self.assertEqual(row[3], metas[0]["updatedAt"])
        conn.close()

    def test_backfill_bootstrap_from_preexisting_records(self):
        self.bootstrap()
        metas = self.seed([{} for _ in range(260)])
        # Snapshot identity before the upgrade path runs.
        conn = self.raw()
        before_records = {r[0]: (r[1], r[2], r[3]) for r in conn.execute(
            "SELECT id,value,version,deleted FROM records WHERE kind='chat_session'")}
        wsid = conn.execute("SELECT value FROM meta WHERE key='workspaceId'").fetchone()[0]
        user = conn.execute("SELECT value FROM meta WHERE key='user'").fetchone()[0]
        rev_before = ws._current_revision(conn)
        conn.close()
        # Simulate a store that predates the catalog table.
        self._simulate_precatalog_store()
        self.bootstrap()  # must rebuild the catalog from existing records
        conn = self.raw()
        n = conn.execute("SELECT COUNT(*) FROM chat_session_catalog").fetchone()[0]
        self.assertEqual(n, len(metas))
        for r in conn.execute(
                "SELECT id,value,version,deleted FROM records WHERE kind='chat_session'"):
            self.assertIn(r[0], before_records)
            self.assertEqual((r[1], r[2], r[3]), before_records[r[0]])
        self.assertEqual(conn.execute("SELECT value FROM meta WHERE key='workspaceId'").fetchone()[0], wsid)
        self.assertEqual(conn.execute("SELECT value FROM meta WHERE key='user'").fetchone()[0], user)
        self.assertEqual(ws._current_revision(conn), rev_before)
        self.assertEqual(
            conn.execute("SELECT COUNT(*) FROM meta WHERE key='chat_catalog_v1'").fetchone()[0], 1)
        conn.close()
        # Idempotent: re-running the upgrade must not duplicate or change anything.
        self._simulate_precatalog_store()
        self.bootstrap()
        conn = self.raw()
        self.assertEqual(conn.execute("SELECT COUNT(*) FROM chat_session_catalog").fetchone()[0], len(metas))
        conn.close()

    def test_backfill_atomic_and_race_safe(self):
        self.bootstrap()
        metas = self.seed([{} for _ in range(90)])
        self._simulate_precatalog_store()
        results, errors = [], []

        def run():
            try:
                results.append(ws.handle({"op": "bootstrap", "deviceId": self.device}))
            except Exception as exc:  # pragma: no cover - exercised by threads
                errors.append(exc)

        t1 = threading.Thread(target=run)
        t2 = threading.Thread(target=run)
        t1.start(); t2.start(); t1.join(); t2.join()
        self.assertEqual(errors, [])
        for r in results:
            self.assertTrue(r["ok"], r)
        conn = self.raw()
        self.assertEqual(conn.execute("SELECT COUNT(*) FROM chat_session_catalog").fetchone()[0], len(metas))
        self.assertEqual(conn.execute("SELECT COUNT(*) FROM meta WHERE key='chat_catalog_v1'").fetchone()[0], 1)
        conn.close()

    def test_backfill_tolerates_malformed_record(self):
        self.bootstrap()
        metas = self.seed([{} for _ in range(30)])
        conn = self.raw()
        conn.execute(
            "INSERT INTO records(kind,id,value,version,deleted,updated_at) "
            "VALUES('chat_session',?,?,?,?,?)",
            ("session/broken", "{not valid json", 31, 0, 0.0))
        conn.commit(); conn.close()
        self._simulate_precatalog_store()
        r = self.bootstrap()
        self.assertTrue(r["ok"], r)
        conn = self.raw()
        self.assertEqual(conn.execute("SELECT COUNT(*) FROM chat_session_catalog").fetchone()[0], len(metas) + 1)
        self.assertEqual(conn.execute(
            "SELECT session_updated_at FROM chat_session_catalog WHERE id='session/broken'").fetchone()[0], "")
        conn.close()

    def test_changes_include_chat_session_metadata(self):
        metas = self.seed([{} for _ in range(3)])
        ch = self.call({"op": "changes", "after": 0, "kinds": ["chat_session"], "limit": 50})
        self.assertTrue(ch["ok"], ch)
        ids = {r["id"] for r in ch["records"]}
        self.assertTrue({m["id"] for m in metas}.issubset(ids))
        for r in ch["records"]:
            if r["id"] in {m["id"] for m in metas}:
                self.assertIn("title", r["value"])


if __name__ == "__main__":
    unittest.main()
