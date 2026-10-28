#!/usr/bin/env python3
"""Focused regression coverage for assets/runtime/workspace_store.py.

Every test owns an isolated temp HOME.  Concurrency tests use real child
processes (not threads) so the same SQLite file is opened by separate PIDs.
"""
import base64
import hashlib
import importlib.util
import json
import os
import pathlib
import sqlite3
import stat
import subprocess
import sys
import tempfile
import time
import unittest
import uuid

MODULE = pathlib.Path(__file__).resolve().parents[2] / "assets" / "runtime" / "workspace_store.py"
SPEC = importlib.util.spec_from_file_location("workspace_store", MODULE)
ws = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ws)

RUNNER = r'''
import importlib.util, json, os, sys, time
module_path, request_path, go_path, ready_path = sys.argv[1:5]
open(ready_path, "w").close()
while not os.path.exists(go_path):
    time.sleep(0.001)
spec = importlib.util.spec_from_file_location("workspace_store_child", module_path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
with open(request_path) as handle:
    request = json.load(handle)
sys.stdout.write(json.dumps(module.handle(request)) + "\n")
sys.stdout.flush()
'''


class WorkspaceStoreTests(unittest.TestCase):
    def setUp(self):
        self.td = tempfile.TemporaryDirectory(prefix="ws_")
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

    # -- helpers ---------------------------------------------------------
    def call(self, req):
        return ws.handle(req)

    def bootstrap(self):
        r = self.call({"op": "bootstrap", "deviceId": self.device})
        self.assertTrue(r["ok"], r)
        return r

    def commit(self, records, op=None, device=None):
        return self.call({
            "op": "commit", "deviceId": device or self.device,
            "operationId": op or str(uuid.uuid4()), "records": records,
        })

    def config(self, rid, value=1, base=0, deleted=False):
        return {"kind": "config", "id": rid, "value": value,
                "baseVersion": base, "deleted": deleted}

    def _protocol(self, req):
        proc = subprocess.run(
            [sys.executable, str(MODULE)],
            input=(json.dumps(req) + "\n").encode(),
            capture_output=True,
            env={**os.environ, "HOME": str(self.home)},
            timeout=30,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr.decode())
        return json.loads(proc.stdout)

    def _concurrent(self, requests):
        runner = self.home / "runner.py"
        runner.write_text(RUNNER)
        go = self.home / "go"
        processes = []
        for index, request in enumerate(requests):
            req_path = self.home / ("request-%d.json" % index)
            req_path.write_text(json.dumps(request))
            ready = self.home / ("ready-%d" % index)
            proc = subprocess.Popen(
                [sys.executable, str(runner), str(MODULE), str(req_path),
                 str(go), str(ready)],
                stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env={**os.environ, "HOME": str(self.home)},
            )
            processes.append((proc, ready))
        deadline = time.time() + 20
        for _, ready in processes:
            while not ready.exists():
                if time.time() > deadline:
                    self.fail("child process never became ready")
                time.sleep(0.01)
        go.write_text("go")
        results = []
        for proc, _ in processes:
            out, err = proc.communicate(timeout=30)
            self.assertEqual(proc.returncode, 0, err.decode())
            results.append(json.loads(out))
        return results

    # -- discovery / bootstrap / schema ---------------------------------
    def test_discover_before_bootstrap_creates_nothing(self):
        r = self.call({"op": "discover", "deviceId": self.device})
        self.assertTrue(r["ok"])
        self.assertFalse(r["exists"])
        self.assertFalse(ws.ROOT.exists(), "discover must not create the store")

    def test_bootstrap_discover_permissions(self):
        os.chmod(self.home, 0o755)
        b = self.bootstrap()
        self.assertEqual(stat.S_IMODE(self.home.stat().st_mode), 0o755,
                         "bootstrap must not chmod the user's home")
        self.assertIn("workspaceId", b)
        d = self.call({"op": "discover", "deviceId": self.device})
        self.assertTrue(d["exists"])
        self.assertEqual(d["workspaceId"], b["workspaceId"])
        self.assertEqual(stat.S_IMODE(ws.ROOT.stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE((ws.ROOT / "blobs").stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE((ws.ROOT / "chunks").stat().st_mode), 0o700)
        db = ws.ROOT / ws.DB_NAME
        self.assertEqual(stat.S_IMODE(db.stat().st_mode), 0o600)
        for suffix in ("-wal", "-shm"):
            path = ws.ROOT / (ws.DB_NAME + suffix)
            if path.exists():
                self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)

    def test_discover_does_not_create_schema_on_empty_database(self):
        ws._ensure_dirs()
        db = ws.ROOT / ws.DB_NAME
        sqlite3.connect(db).close()
        r = self.call({"op": "discover", "deviceId": self.device})
        self.assertTrue(r["ok"])
        self.assertFalse(r["exists"])
        conn = sqlite3.connect(db)
        try:
            tables = {row[0] for row in conn.execute(
                "SELECT name FROM sqlite_master WHERE type='table'")}
        finally:
            conn.close()
        self.assertNotIn("meta", tables)

    def test_future_schema_is_refused_not_downgraded(self):
        self.bootstrap()
        conn = sqlite3.connect(ws.ROOT / ws.DB_NAME)
        try:
            conn.execute("UPDATE meta SET value=? WHERE key='schema'",
                         (json.dumps(2),))
            conn.commit()
        finally:
            conn.close()
        self.assertEqual(self.call({"op": "discover"})["error"],
                         "WORKSPACE_SCHEMA_UNSUPPORTED")
        r = self.commit([self.config("agent/a", {"name": "x"})])
        self.assertFalse(r["ok"])
        self.assertEqual(r["error"], "WORKSPACE_SCHEMA_UNSUPPORTED")

    # -- CAS / idempotency ----------------------------------------------
    def test_commit_create_conflict_retry(self):
        self.bootstrap()
        r = self.commit([self.config("agent/a", {"name": "one"})], op="op1")
        self.assertTrue(r["ok"], r)
        version = r["records"][0]["version"]
        r2 = self.commit([self.config("agent/a", {"name": "two"})], op="op2")
        self.assertFalse(r2["ok"])
        self.assertEqual(r2["error"], "WORKSPACE_CONFLICT")
        self.assertEqual(r2["records"][0]["version"], version)
        r3 = self.commit([self.config("agent/a", {"name": "two"}, base=version)],
                         op="op3")
        self.assertTrue(r3["ok"], r3)

    def test_idempotency_same_and_different_payload(self):
        self.bootstrap()
        records = [self.config("agent/a", {"name": "x"})]
        r1 = self.commit(records, op="same-op")
        r2 = self.commit(records, op="same-op")
        self.assertTrue(r1["ok"] and r2["ok"])
        self.assertEqual(r1["revision"], r2["revision"])
        r3 = self.commit([self.config("agent/a", {"name": "y"})], op="same-op")
        self.assertFalse(r3["ok"])
        self.assertEqual(r3["error"], "WORKSPACE_OPERATION_CONFLICT")

    def test_same_operation_id_from_another_device_is_a_conflict(self):
        self.bootstrap()
        records = [self.config("agent/a", {"name": "x"})]
        self.assertTrue(self.commit(records, op="shared")["ok"])
        other = self.commit(records, op="shared", device=str(uuid.uuid4()))
        self.assertFalse(other["ok"])
        self.assertEqual(other["error"], "WORKSPACE_OPERATION_CONFLICT")

    def test_concurrent_processes_same_version_cas(self):
        self.bootstrap()
        requests = []
        for index in range(8):
            requests.append({
                "op": "commit", "deviceId": str(uuid.uuid4()),
                "operationId": "race-%d" % index,
                "records": [self.config("agent/race", {"winner": index})],
            })
        results = self._concurrent(requests)
        winners = [r for r in results if r.get("ok")]
        losers = [r for r in results if not r.get("ok")]
        self.assertEqual(len(winners), 1, results)
        self.assertEqual(len(losers), 7, results)
        for loser in losers:
            self.assertEqual(loser["error"], "WORKSPACE_CONFLICT")
        changes = self.call({"op": "changes", "after": 0,
                             "kinds": ["config"], "limit": 10})
        self.assertEqual(changes["records"][0]["value"],
                         winners[0]["records"][0]["value"])

    def test_delete_tombstone(self):
        self.bootstrap()
        rid = "%s/valhalla_chat_draft_v1::draft-1" % self.device
        r = self.commit([{"kind": "draft", "id": rid, "value": {"t": 1},
                          "baseVersion": 0, "deleted": False}])
        self.assertTrue(r["ok"], r)
        version = r["records"][0]["version"]
        r2 = self.commit([{"kind": "draft", "id": rid, "value": None,
                           "baseVersion": version, "deleted": True}])
        self.assertTrue(r2["ok"], r2)
        self.assertTrue(r2["records"][0]["deleted"])
        ch = self.call({"op": "changes", "after": 0, "limit": 10})
        self.assertTrue(any(x["deleted"] for x in ch["records"]))

    # -- ids and allowlists ---------------------------------------------
    def test_slash_ids_and_all_allowlist_shapes(self):
        self.bootstrap()
        device = str(uuid.uuid4())
        records = [
            self.config("agent/" + str(uuid.uuid4()), {"name": "a"}),
            self.config("command/" + str(uuid.uuid4()), {"name": "c"}),
            self.config("nas_source/" + str(uuid.uuid4()), {"name": "n"}),
            self.config("valhalla_chat_run_defaults_v1/abc", {"model": "m"}),
            self.config("valhalla_file_bookmarks::srv::/home/x", ["/a"]),
            self.config("valhalla_app_center_v1::sources::global", []),
            {"kind": "preference", "id": "phone/valhalla_theme_mode_v1",
             "value": {"key": "valhalla_theme_mode_v1", "value": "dark"},
             "baseVersion": 0, "deleted": False},
            {"kind": "draft",
             "id": device + "/valhalla_chat_draft_v1::chat-1",
             "value": {"key": "valhalla_chat_draft_v1::chat-1",
                       "deviceId": device, "value": {"string": "hello"}},
             "baseVersion": 0, "deleted": False},
            {"kind": "chat_message", "id": "session-1/message-1",
             "value": {"text": "a message containing password text is fine"},
             "baseVersion": 0, "deleted": False},
        ]
        r = self.commit(records)
        self.assertTrue(r["ok"], r)
        self.assertEqual(len(r["records"]), len(records))

    def test_forbidden_preference_and_secret_config_keys(self):
        self.bootstrap()
        bad = [
            {"kind": "preference", "id": "phone/valhalla_servers_v1",
             "value": 1, "baseVersion": 0, "deleted": False},
            {"kind": "preference", "id": "phone/valhalla_ssh_private_key_v1",
             "value": 1, "baseVersion": 0, "deleted": False},
            self.config("valhalla_servers_v1/abc", 1),
            self.config("valhalla_ssh_private_key_v1", 1),
            self.config("valhalla_credentials_v1/abc", 1),
        ]
        for record in bad:
            r = self.commit([record])
            self.assertFalse(r["ok"], record)
            self.assertEqual(r["error"], "WORKSPACE_KEY_INVALID", record)

    def test_long_and_control_character_ids(self):
        self.bootstrap()
        long_ok = "agent/" + "a" * (ws.MAX_ID_LEN - len("agent/"))
        self.assertTrue(self.commit([self.config(long_ok, 1)])["ok"])
        too_long = "agent/" + "a" * (ws.MAX_ID_LEN - len("agent/") + 1)
        r = self.commit([self.config(too_long, 1)])
        self.assertEqual(r["error"], "WORKSPACE_ID_INVALID")
        r2 = self.commit([self.config("agent/bad\x01id", 1)])
        self.assertEqual(r2["error"], "WORKSPACE_ID_INVALID")
        # Opaque ids are not filesystem paths; traversal text is stored as-is.
        self.assertTrue(self.commit([self.config("agent/../etc/passwd", 1)])["ok"])

    # -- changes / snapshot pagination ----------------------------------
    def test_changes_kind_filter_advances_cursor_and_skips_history(self):
        self.bootstrap()
        self.assertTrue(self.commit([self.config("agent/a", 1)], op="v1")["ok"])
        self.assertTrue(self.commit([{"kind": "chat_message", "id": "s/m",
                                      "value": "history", "baseVersion": 0,
                                      "deleted": False}], op="v2")["ok"])
        self.assertTrue(self.commit([self.config("agent/b", 2)], op="v3")["ok"])
        first = self.call({"op": "changes", "after": 0,
                           "kinds": ["config"], "limit": 1})
        self.assertTrue(first["ok"], first)
        self.assertEqual([r["id"] for r in first["records"]], ["agent/a"])
        self.assertTrue(first["hasMore"])
        self.assertEqual(first["revision"], 1)
        second = self.call({"op": "changes", "after": first["revision"],
                            "kinds": ["config"], "limit": 1})
        self.assertEqual([r["id"] for r in second["records"]], ["agent/b"])
        self.assertFalse(second["hasMore"])
        self.assertEqual(second["revision"], 3)
        none = self.call({"op": "changes", "after": second["revision"],
                          "kinds": ["config"], "limit": 10})
        self.assertEqual(none["records"], [])
        self.assertEqual(none["revision"], 3)

    def test_changes_without_filter_still_returns_all_kinds(self):
        self.bootstrap()
        self.commit([self.config("agent/a", 1),
                     {"kind": "chat_message", "id": "s/m", "value": 2,
                      "baseVersion": 0, "deleted": False},
                     {"kind": "preference", "id": "phone/valhalla_locale_v1",
                      "value": {"key": "valhalla_locale_v1", "value": "zh"},
                      "baseVersion": 0, "deleted": False}])
        ch = self.call({"op": "changes", "after": 0, "limit": 10})
        self.assertEqual({r["kind"] for r in ch["records"]},
                         {"config", "chat_message", "preference"})

    def test_snapshot_prefix_and_next_cursor_scopes_messages(self):
        self.bootstrap()
        records = []
        for rid in ("sess-1/m1", "sess-1/m2", "sess-2/m1"):
            records.append({"kind": "chat_message", "id": rid, "value": rid,
                            "baseVersion": 0, "deleted": False})
        self.assertTrue(self.commit(records)["ok"])
        page = self.call({"op": "snapshot", "kind": "chat_message",
                          "prefix": "sess-1/", "afterId": "", "limit": 1})
        self.assertEqual([r["id"] for r in page["records"]], ["sess-1/m1"])
        self.assertTrue(page["hasMore"])
        self.assertEqual(page["nextCursor"], "sess-1/m1")
        page2 = self.call({"op": "snapshot", "kind": "chat_message",
                           "prefix": "sess-1/", "afterId": page["nextCursor"],
                           "limit": 5})
        self.assertEqual([r["id"] for r in page2["records"]], ["sess-1/m2"])
        self.assertFalse(page2["hasMore"])
        self.assertEqual(page2["nextCursor"], "sess-1/m2")

    def test_page_and_batch_bounds(self):
        self.bootstrap()
        records = [self.config("agent/%d" % i, i) for i in range(ws.MAX_PAGE_LIMIT + 20)]
        self.assertTrue(self.commit(records)["ok"])
        r = self.call({"op": "changes", "after": 0, "limit": 100000})
        self.assertTrue(r["ok"])
        self.assertEqual(len(r["records"]), ws.MAX_PAGE_LIMIT)
        self.assertTrue(r["hasMore"])
        batch = [self.config("agent/b%d" % i, i) for i in range(ws.MAX_BATCH_RECORDS + 1)]
        self.assertEqual(self.commit(batch)["error"], "WORKSPACE_BATCH_TOO_LARGE")

    def test_oversized_stdin_request_is_rejected(self):
        proc = subprocess.run(
            [sys.executable, str(MODULE)],
            input=b"x" * (ws.MAX_REQUEST_BYTES + 10) + b"\n",
            capture_output=True,
            env={**os.environ, "HOME": str(self.home)},
            timeout=30,
        )
        self.assertEqual(proc.returncode, 0)
        self.assertEqual(json.loads(proc.stdout)["error"],
                         "WORKSPACE_REQUEST_TOO_LARGE")

    # -- leases ----------------------------------------------------------
    def test_lease_acquire_requires_token_same_device_and_hides_token(self):
        self.bootstrap()
        sid = "sess1"
        a = self.call({"op": "lease", "sessionId": sid, "deviceId": self.device,
                       "action": "acquire"})
        self.assertTrue(a["ok"], a)
        token, gen = a["token"], a["generation"]
        # Same device without proof must not silently renew/overwrite.
        no_token = self.call({"op": "lease", "sessionId": sid,
                              "deviceId": self.device, "action": "acquire"})
        self.assertEqual(no_token["error"], "WORKSPACE_LEASE_INVALID")
        wrong = self.call({"op": "lease", "sessionId": sid,
                           "deviceId": self.device, "action": "acquire",
                           "token": "wrong", "generation": gen})
        self.assertEqual(wrong["error"], "WORKSPACE_LEASE_INVALID")
        # Same device with proof renews the same generation/token.
        same = self.call({"op": "lease", "sessionId": sid,
                          "deviceId": self.device, "action": "acquire",
                          "token": token, "generation": gen})
        self.assertTrue(same["ok"], same)
        self.assertEqual((same["token"], same["generation"]), (token, gen))
        # Another device gets the owner id but never the token.
        other = str(uuid.uuid4())
        held = self.call({"op": "lease", "sessionId": sid, "deviceId": other,
                          "action": "acquire"})
        self.assertEqual(held["error"], "WORKSPACE_CONTROL_HELD")
        self.assertEqual(held["ownerDeviceId"], self.device)
        self.assertNotIn("token", held)
        # renew requires token and generation
        self.assertEqual(self.call({"op": "lease", "sessionId": sid,
                                    "deviceId": self.device, "action": "renew"})["error"],
                         "WORKSPACE_LEASE_INVALID")
        rn = self.call({"op": "lease", "sessionId": sid, "deviceId": self.device,
                        "action": "renew", "token": token, "generation": gen})
        self.assertTrue(rn["ok"], rn)
        checked = self.call({"op": "check_control", "sessionId": sid,
                             "deviceId": self.device, "token": token,
                             "generation": gen, "renew": True})
        self.assertTrue(checked["ok"] and checked["allowed"], checked)
        self.assertGreater(checked["expiresAt"], rn["expiresAt"])
        self.assertTrue(ws.check_control(sid, self.device, token, gen, renew=True))
        self.assertFalse(ws.check_control(sid, self.device, token, gen + 1))
        self.assertFalse(ws.check_control(sid, other, token, gen))

    def test_lease_release_keeps_generation_monotonic(self):
        self.bootstrap()
        sid = "sess-release"
        a = self.call({"op": "lease", "sessionId": sid, "deviceId": self.device,
                       "action": "acquire"})
        gen = a["generation"]
        self.assertEqual(self.call({"op": "lease", "sessionId": sid,
                                    "deviceId": self.device, "action": "release"})["error"],
                         "WORKSPACE_LEASE_INVALID")
        rel = self.call({"op": "lease", "sessionId": sid, "deviceId": self.device,
                         "action": "release", "token": a["token"],
                         "generation": gen})
        self.assertTrue(rel["ok"], rel)
        self.assertFalse(ws.check_control(sid, self.device, a["token"], gen))
        b = self.call({"op": "lease", "sessionId": sid, "deviceId": self.device,
                       "action": "acquire"})
        self.assertTrue(b["ok"], b)
        self.assertGreater(b["generation"], gen)

    def test_takeover_invalidates_old_token_and_old_release(self):
        self.bootstrap()
        sid = "sess-takeover"
        a = self.call({"op": "lease", "sessionId": sid, "deviceId": self.device,
                       "action": "acquire"})
        other = str(uuid.uuid4())
        to = self.call({"op": "lease", "sessionId": sid, "deviceId": other,
                        "action": "takeover"})
        self.assertTrue(to["ok"], to)
        self.assertGreater(to["generation"], a["generation"])
        self.assertFalse(ws.check_control(sid, self.device, a["token"],
                                          a["generation"]))
        stale_release = self.call({"op": "lease", "sessionId": sid,
                                   "deviceId": self.device, "action": "release",
                                   "token": a["token"], "generation": a["generation"]})
        self.assertEqual(stale_release["error"], "WORKSPACE_LEASE_INVALID")
        self.assertTrue(ws.check_control(sid, other, to["token"], to["generation"]))

    def test_concurrent_processes_only_one_lease_winner(self):
        self.bootstrap()
        requests = []
        for index in range(8):
            requests.append({"op": "lease", "sessionId": "race-session",
                             "deviceId": "device-%d" % index, "action": "acquire"})
        results = self._concurrent(requests)
        winners = [r for r in results if r.get("ok")]
        losers = [r for r in results if not r.get("ok")]
        self.assertEqual(len(winners), 1, results)
        self.assertEqual(len(losers), 7, results)
        for loser in losers:
            self.assertEqual(loser["error"], "WORKSPACE_CONTROL_HELD")
            self.assertNotIn("token", loser)

    # -- filesystem guards ----------------------------------------------
    def test_symlinked_intermediate_directory_is_rejected(self):
        outside = self.home / "outside"
        outside.mkdir()
        (self.home / ".local").symlink_to(outside, target_is_directory=True)
        r = self.call({"op": "bootstrap", "deviceId": self.device})
        self.assertFalse(r["ok"])
        self.assertEqual(r["error"], "WORKSPACE_PATH_UNSAFE")

    def test_symlinked_blobs_and_chunks_directories_are_rejected(self):
        self.bootstrap()
        outside = self.home / "outside"
        outside.mkdir()
        for name in ("blobs", "chunks"):
            path = ws.ROOT / name
            path.rmdir()
            path.symlink_to(outside, target_is_directory=True)
            data = b"abc"
            h = hashlib.sha256(data).hexdigest()
            r = self.call({"op": "blob_put", "hash": h, "chunkIndex": 0,
                           "totalChunks": 1,
                           "data": base64.b64encode(data).decode()})
            self.assertFalse(r["ok"], name)
            self.assertEqual(r["error"], "WORKSPACE_PATH_UNSAFE")
            path.unlink()
            path.mkdir(mode=0o700)

    def test_symlinked_sqlite_file_is_rejected(self):
        self.bootstrap()
        db = ws.ROOT / ws.DB_NAME
        real = self.home / "elsewhere.sqlite3"
        db.rename(real)
        db.symlink_to(real)
        r = self.call({"op": "discover"})
        self.assertFalse(r["ok"])
        self.assertEqual(r["error"], "WORKSPACE_PATH_UNSAFE")

    # -- blobs -----------------------------------------------------------
    def test_blob_chunk_roundtrip_and_reuse(self):
        self.bootstrap()
        data = os.urandom(1000)
        h = hashlib.sha256(data).hexdigest()
        chunk_size = 300
        total = (len(data) + chunk_size - 1) // chunk_size
        for index in range(total):
            part = data[index * chunk_size:(index + 1) * chunk_size]
            r = self.call({"op": "blob_put", "hash": h, "chunkIndex": index,
                           "totalChunks": total,
                           "data": base64.b64encode(part).decode(),
                           "totalSize": len(data)})
            self.assertTrue(r["ok"], r)
        self.assertTrue(self.call({"op": "blob_has", "hash": h})["exists"])
        got = bytearray()
        offset = 0
        while True:
            page = self.call({"op": "blob_get", "hash": h, "offset": offset,
                              "length": 256})
            self.assertTrue(page["ok"], page)
            chunk = base64.b64decode(page["data"])
            got += chunk
            offset += len(chunk)
            if page["eof"]:
                break
        self.assertEqual(bytes(got), data)
        reuse = self.call({"op": "blob_put", "hash": h, "chunkIndex": 0,
                           "totalChunks": 1, "data": ""})
        self.assertTrue(reuse["ok"])
        self.assertTrue(reuse["reused"])
        self.assertFalse(any((ws.ROOT / "chunks").iterdir()))
        self.assertFalse(any(p.name.endswith(".tmp") or ".tmp." in p.name
                             for p in (ws.ROOT / "blobs").iterdir()))

    def test_blob_bounds_and_atomic_failure_cleanup(self):
        self.bootstrap()
        data = b"hello"
        h = hashlib.sha256(data).hexdigest()
        oversized = "A" * (((ws.MAX_BLOB_CHUNK + 2) // 3) * 4 + 16)
        self.assertEqual(self.call({"op": "blob_put", "hash": h,
                                    "data": oversized})["error"],
                         "WORKSPACE_BLOB_CHUNK_TOO_LARGE")
        self.assertEqual(self.call({"op": "blob_put", "hash": h,
                                    "chunkIndex": 1, "totalChunks": 1,
                                    "data": ""})["error"],
                         "WORKSPACE_CHUNK_INVALID")
        self.assertEqual(self.call({"op": "blob_put", "hash": h,
                                    "totalChunks": ws.MAX_BLOB_CHUNKS + 1,
                                    "data": ""})["error"],
                         "WORKSPACE_CHUNK_INVALID")
        wrong_hash = "0" * 64
        bad = self.call({"op": "blob_put", "hash": wrong_hash, "chunkIndex": 0,
                         "totalChunks": 1,
                         "data": base64.b64encode(data).decode()})
        self.assertEqual(bad["error"], "WORKSPACE_BLOB_HASH_MISMATCH")
        bad_size = self.call({"op": "blob_put", "hash": h, "chunkIndex": 0,
                              "totalChunks": 1,
                              "data": base64.b64encode(data).decode(),
                              "totalSize": len(data) + 1})
        self.assertEqual(bad_size["error"], "WORKSPACE_BLOB_SIZE_MISMATCH")
        self.assertFalse((ws.ROOT / "blobs" / wrong_hash).exists())
        self.assertFalse(any(".tmp." in p.name
                             for p in (ws.ROOT / "blobs").iterdir()))
        ok = self.call({"op": "blob_put", "hash": h, "chunkIndex": 0,
                        "totalChunks": 1,
                        "data": base64.b64encode(data).decode()})
        self.assertTrue(ok["ok"], ok)
        self.assertEqual(self.call({"op": "blob_get", "hash": h,
                                    "offset": 6})["error"],
                         "WORKSPACE_BLOB_OFFSET_INVALID")

    # -- runtime events --------------------------------------------------
    def test_runtime_events_are_never_truncated(self):
        self.bootstrap()
        rk = "a" * 64
        now = time.time()
        conn = sqlite3.connect(ws.ROOT / ws.DB_NAME)
        try:
            conn.executemany(
                "INSERT INTO runtime_events(runtime_key,payload,created_at) VALUES(?,?,?)",
                [(rk, json.dumps({"n": i}), now) for i in range(10005)],
            )
            conn.commit()
        finally:
            conn.close()
        seq = ws.append_runtime_event(rk, {"n": "last"})
        self.assertEqual(seq, 10006)
        conn = sqlite3.connect(ws.ROOT / ws.DB_NAME)
        try:
            count = conn.execute(
                "SELECT COUNT(*) FROM runtime_events WHERE runtime_key=?",
                (rk,)).fetchone()[0]
        finally:
            conn.close()
        self.assertEqual(count, 10006)
        collected = []
        after = 0
        while True:
            page = self.call({"op": "runtime_events", "runtimeKey": rk,
                              "afterSeq": after, "limit": 200})
            self.assertTrue(page["ok"], page)
            collected.extend(event["seq"] for event in page["events"])
            after = collected[-1] if collected else after
            if not page["hasMore"]:
                break
        self.assertEqual(len(collected), 10006)
        self.assertEqual(collected[0], 1)
        self.assertEqual(collected[-1], 10006)

    def test_runtime_catalog_registration(self):
        self.bootstrap()
        rk = "b" * 64
        self.assertTrue(ws.register_runtime(rk, session_id="s", device_id="d",
                                            scope="scope", meta={"x": 1}))
        catalog = self.call({"op": "runtime_catalog"})
        self.assertEqual(catalog["runtimes"][0]["runtimeKey"], rk)
        self.assertEqual(catalog["runtimes"][0]["meta"], {"x": 1})
        self.assertIn("agentId", catalog["runtimes"][0])

    # -- response page budget -------------------------------------------
    def test_changes_page_budget_never_splits_or_skips_large_records(self):
        self.bootstrap()
        payload = "x" * (200 * 1024)
        records = [self.config("agent/big-%02d" % i, {"text": payload})
                   for i in range(8)]
        self.assertTrue(self.commit(records)["ok"])
        seen = []
        after = 0
        pages = 0
        while True:
            page = self.call({"op": "changes", "after": after,
                              "kinds": ["config"], "limit": 200})
            self.assertTrue(page["ok"], page)
            encoded = json.dumps(page, ensure_ascii=False,
                                 separators=(",", ":"))
            self.assertLessEqual(len(encoded.encode("utf-8")),
                                 ws.MAX_RESPONSE_BYTES)
            self.assertTrue(page["records"])
            for record in page["records"]:
                self.assertEqual(len(record["value"]["text"]), len(payload))
                seen.append(record["id"])
            if not page["hasMore"]:
                break
            after = page["revision"]
            pages += 1
            self.assertLess(pages, 20, "cursor did not advance")
        self.assertGreaterEqual(pages, 1, "budget must force a second page")
        self.assertEqual(seen, ["agent/big-%02d" % i for i in range(8)])

    def test_snapshot_page_budget_keeps_a_single_max_record_whole(self):
        self.bootstrap()
        payload = "y" * (250 * 1024)
        records = [{"kind": "chat_message", "id": "sess-big/m%02d" % i,
                    "value": {"text": payload}, "baseVersion": 0,
                    "deleted": False} for i in range(6)]
        self.assertTrue(self.commit(records)["ok"])
        first = self.call({"op": "snapshot", "kind": "chat_message",
                           "prefix": "sess-big/", "limit": 200})
        self.assertTrue(first["ok"], first)
        self.assertGreaterEqual(len(first["records"]), 1)
        self.assertLess(len(first["records"]), 6)
        self.assertTrue(first["hasMore"])
        encoded = json.dumps(first, ensure_ascii=False, separators=(",", ":"))
        self.assertLessEqual(len(encoded.encode("utf-8")), ws.MAX_RESPONSE_BYTES)
        for record in first["records"]:
            self.assertEqual(len(record["value"]["text"]), len(payload))
        # A one-record page is never truncated, even at the value limit.
        one = self.call({"op": "snapshot", "kind": "chat_message",
                         "prefix": "sess-big/", "limit": 1})
        self.assertEqual(len(one["records"]), 1)
        self.assertEqual(len(one["records"][0]["value"]["text"]), len(payload))
        self.assertTrue(one["hasMore"])
        # Follow the cursor to prove nothing is skipped.
        seen = list(first["records"])
        cursor = first["nextCursor"]
        while first["hasMore"]:
            first = self.call({"op": "snapshot", "kind": "chat_message",
                               "prefix": "sess-big/", "afterId": cursor,
                               "limit": 200})
            self.assertTrue(first["ok"], first)
            seen.extend(first["records"])
            cursor = first["nextCursor"]
        self.assertEqual([r["id"] for r in seen],
                         ["sess-big/m%02d" % i for i in range(6)])

    # -- descending snapshot --------------------------------------------
    def test_snapshot_descending_latest_first_and_prefix_scoped(self):
        self.bootstrap()
        records = [{"kind": "chat_message", "id": "sess-a/m%02d" % i,
                    "value": {"n": i}, "baseVersion": 0, "deleted": False}
                   for i in range(10)]
        records.append({"kind": "chat_message", "id": "sess-b/m99",
                        "value": {"n": 99}, "baseVersion": 0, "deleted": False})
        self.assertTrue(self.commit(records)["ok"])
        first = self.call({"op": "snapshot", "kind": "chat_message",
                           "prefix": "sess-a/", "descending": True, "limit": 3})
        self.assertEqual([r["id"] for r in first["records"]],
                         ["sess-a/m09", "sess-a/m08", "sess-a/m07"])
        self.assertTrue(first["hasMore"])
        self.assertEqual(first["nextCursor"], "sess-a/m07")
        second = self.call({"op": "snapshot", "kind": "chat_message",
                            "prefix": "sess-a/", "descending": True,
                            "afterId": first["nextCursor"], "limit": 20})
        self.assertEqual([r["id"] for r in second["records"]],
                         ["sess-a/m06", "sess-a/m05", "sess-a/m04",
                          "sess-a/m03", "sess-a/m02", "sess-a/m01",
                          "sess-a/m00"])
        self.assertFalse(second["hasMore"])

    def test_snapshot_descending_kindless_cursor(self):
        self.bootstrap()
        self.commit([
            self.config("agent/a", 1),
            {"kind": "chat_message", "id": "s/m", "value": 2,
             "baseVersion": 0, "deleted": False},
            {"kind": "preference", "id": "phone/valhalla_locale_v1",
             "value": {"key": "valhalla_locale_v1", "value": "zh"},
             "baseVersion": 0, "deleted": False},
        ])
        first = self.call({"op": "snapshot", "descending": True, "limit": 2})
        self.assertEqual([r["kind"] for r in first["records"]],
                         ["preference", "config"])
        self.assertTrue(first["hasMore"])
        second = self.call({"op": "snapshot", "descending": True,
                            "afterId": first["nextCursor"], "limit": 2})
        self.assertEqual([r["kind"] for r in second["records"]],
                         ["chat_message"])
        self.assertFalse(second["hasMore"])

    def test_snapshot_before_id_matches_actual_chat_client_query(self):
        """Reproduce workspace_chat_sync.dart tail + upward walk exactly."""
        self.bootstrap()
        sid = "session-1"
        # Client ids: <sessionId>/<12-digit sequence>/<messageId>.
        records = [{"kind": "chat_message",
                    "id": "%s/%012d/m%d" % (sid, seq, seq),
                    "value": {"n": seq}, "baseVersion": 0, "deleted": False}
                   for seq in range(1, 76)]
        records.append({"kind": "chat_message", "id": "other/000000000999/x",
                        "value": {"n": 999}, "baseVersion": 0,
                        "deleted": False})
        self.assertTrue(self.commit(records)["ok"])
        # fetchMessageTail(session, limit: 50) -> descending + prefix.
        tail = self.call({"op": "snapshot", "kind": "chat_message",
                          "prefix": sid + "/", "limit": 50,
                          "descending": True})
        self.assertTrue(tail["ok"], tail)
        self.assertEqual([r["id"] for r in tail["records"]],
                         ["%s/%012d/m%d" % (sid, seq, seq)
                          for seq in range(75, 25, -1)])
        self.assertTrue(tail["hasMore"])
        # fetchMessagesBefore(26) -> beforeId is the padded sequence prefix,
        # an exclusive upper bound that also excludes that whole sequence.
        older = self.call({"op": "snapshot", "kind": "chat_message",
                           "prefix": sid + "/", "limit": 50,
                           "descending": True,
                           "beforeId": "%s/%012d/" % (sid, 26)})
        self.assertTrue(older["ok"], older)
        self.assertEqual([r["id"] for r in older["records"]],
                         ["%s/%012d/m%d" % (sid, seq, seq)
                          for seq in range(25, 0, -1)])
        self.assertFalse(older["hasMore"])
        # Both cursors at once is an explicit request error, not a silent pick.
        both = self.call({"op": "snapshot", "kind": "chat_message",
                          "prefix": sid + "/", "limit": 5,
                          "descending": True,
                          "afterId": "%s/%012d/" % (sid, 50),
                          "beforeId": "%s/%012d/" % (sid, 26)})
        self.assertFalse(both["ok"])
        self.assertEqual(both["error"], "WORKSPACE_REQUEST_INVALID")

    def test_snapshot_exact_id_lookup_does_not_match_prefix_siblings(self):
        """fetchSession sends kind=chat_session,id=<sid>,limit:1."""
        self.bootstrap()
        self.assertTrue(self.commit([
            {"kind": "chat_session", "id": "sess", "value": {"n": 1},
             "baseVersion": 0, "deleted": False},
            {"kind": "chat_session", "id": "sess-longer", "value": {"n": 2},
             "baseVersion": 0, "deleted": False},
        ])["ok"])
        exact = self.call({"op": "snapshot", "kind": "chat_session",
                           "id": "sess-longer", "limit": 1})
        self.assertTrue(exact["ok"], exact)
        self.assertEqual([r["id"] for r in exact["records"]], ["sess-longer"])
        missing = self.call({"op": "snapshot", "kind": "chat_session",
                             "id": "sess", "limit": 1})
        self.assertEqual([r["id"] for r in missing["records"]], ["sess"])
        absent = self.call({"op": "snapshot", "kind": "chat_session",
                            "id": "nope", "limit": 1})
        self.assertEqual(absent["records"], [])

    # -- runtime catalog filters ----------------------------------------
    def test_runtime_catalog_filters_by_session_and_agent_with_indexes(self):
        self.bootstrap()
        rk1, rk2, rk3 = "c" * 64, "d" * 64, "e" * 64
        self.assertTrue(ws.register_runtime(rk1, session_id="s1", device_id="d1",
                                            scope="sc", meta={"x": 1},
                                            agent_id="agent-1"))
        self.assertTrue(ws.register_runtime(rk2, session_id="s2", device_id="d2",
                                            scope="sc", agent_id="agent-1"))
        self.assertTrue(ws.register_runtime(rk3, session_id="s1", device_id="d3",
                                            scope="sc", agent_id="agent-2"))
        by_session = self.call({"op": "runtime_catalog", "sessionId": "s1"})
        self.assertEqual({r["runtimeKey"] for r in by_session["runtimes"]},
                         {rk1, rk3})
        by_agent = self.call({"op": "runtime_catalog", "agentId": "agent-1"})
        self.assertEqual({r["runtimeKey"] for r in by_agent["runtimes"]},
                         {rk1, rk2})
        both = self.call({"op": "runtime_catalog", "sessionId": "s1",
                          "agentId": "agent-1"})
        self.assertEqual([r["runtimeKey"] for r in both["runtimes"]], [rk1])
        self.assertEqual(both["runtimes"][0]["agentId"], "agent-1")
        limited = self.call({"op": "runtime_catalog", "limit": 1})
        self.assertEqual(len(limited["runtimes"]), 1)
        conn = sqlite3.connect(ws.ROOT / ws.DB_NAME)
        try:
            names = {row[0] for row in conn.execute(
                "SELECT name FROM sqlite_master WHERE type='index'")}
        finally:
            conn.close()
        for name in ("runtimes_session_seen", "runtimes_agent_seen",
                     "runtimes_last_seen"):
            self.assertIn(name, names)

    # -- draft shapes ----------------------------------------------------
    def test_draft_accepts_typed_file_shape_and_rejects_arbitrary_ids(self):
        self.bootstrap()
        device = str(uuid.uuid4())
        h = "a" * 64
        good = {"kind": "draft", "id": device + "/file/" + h,
                "value": {"type": "file", "deviceId": device,
                          "path": "/srv/report.pdf", "digest": h,
                          "blob": {"hash": h, "size": 123}},
                "baseVersion": 0, "deleted": False}
        r = self.commit([good])
        self.assertTrue(r["ok"], r)
        # The id hash identifies the per-device PATH draft, not the blob
        # content.  A different (but valid) content hash is accepted under the
        # same id so replacing the file behind a path keeps the draft slot.
        other = "b" * 64
        replaced = {"kind": "draft", "id": device + "/file/" + h,
                    "value": {"type": "file", "deviceId": device,
                              "path": "/srv/report.pdf", "digest": other,
                              "blobHash": other},
                    "baseVersion": 1, "deleted": False}
        r = self.commit([replaced])
        self.assertTrue(r["ok"], r)
        self.assertEqual(r["records"][0]["id"], device + "/file/" + h)
        # The path is metadata only; it is never opened as a filesystem path.
        self.assertFalse((self.home / "srv/report.pdf").exists())
        bad_values = [
            {"type": "file", "deviceId": device, "path": "/x",
             "digest": "z" * 64},
            {"type": "file", "deviceId": "other", "path": "/x", "digest": h},
            {"type": "file", "deviceId": device, "path": "/x\x01y",
             "digest": h},
            {"type": "text", "deviceId": device, "path": "/x", "digest": h},
            {"type": "file", "deviceId": device, "path": "/x", "digest": h,
             "blob": {"hash": "nothex"}},
            {"type": "file", "deviceId": device, "path": "/x", "digest": h,
             "blobRef": "not-a-hash"},
        ]
        for value in bad_values:
            bad = {"kind": "draft", "id": device + "/file/" + h,
                   "value": value, "baseVersion": 0, "deleted": False}
            r = self.commit([bad])
            self.assertFalse(r["ok"], value)
            self.assertEqual(r["error"], "WORKSPACE_VALUE_INVALID", value)
        for rid in (device + "/file/../../etc/passwd",
                    device + "/valhalla_credentials_v1::x",
                    device + "/file/abc"):
            r = self.commit([{"kind": "draft", "id": rid, "value": {},
                              "baseVersion": 0, "deleted": False}])
            self.assertFalse(r["ok"], rid)
            self.assertEqual(r["error"], "WORKSPACE_ID_INVALID", rid)

    # -- nas media -------------------------------------------------------
    def test_nas_media_accepts_opaque_ids_and_snapshot_prefix(self):
        self.bootstrap()
        ids = ["media/srv/../../clip.mp4", "srv2/movie:1",
               "opaque id with spaces"]
        records = [{"kind": "nas_media", "id": rid, "value": {"id": rid},
                    "baseVersion": 0, "deleted": False} for rid in ids]
        self.assertTrue(self.commit(records)["ok"])
        page = self.call({"op": "snapshot", "kind": "nas_media",
                          "prefix": "media/", "descending": True, "limit": 50})
        self.assertEqual([r["id"] for r in page["records"]],
                         ["media/srv/../../clip.mp4"])
        other = self.call({"op": "snapshot", "kind": "nas_media",
                           "prefix": "srv2/"})
        self.assertEqual([r["id"] for r in other["records"]], ["srv2/movie:1"])


if __name__ == "__main__":
    unittest.main()
