#!/usr/bin/env python3
"""Focused coverage for assets/runtime/workspace_nas.py.

The helper is exercised against a real workspace store in an isolated HOME.
It is the server half of the NAS workspace protocol, so these tests pin the
query/filter/sort/group/paging and tombstone semantics the Dart client uses.
"""
import importlib.util
import json
import os
import pathlib
import sqlite3
import tempfile
import unittest
import uuid

RUNTIME = pathlib.Path(__file__).resolve().parents[2] / "assets" / "runtime"


def _load(name):
    spec = importlib.util.spec_from_file_location(name, RUNTIME / (name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


ws = _load("workspace_store")
wn = _load("workspace_nas")
wn._store = ws


class WorkspaceNasTests(unittest.TestCase):
    def setUp(self):
        self.td = tempfile.TemporaryDirectory(prefix="wnas_")
        self.home = pathlib.Path(self.td.name)
        self.old_home = os.environ.get("HOME")
        os.environ["HOME"] = str(self.home)
        ws.ROOT = self.home / ".local/share/valhalla/workspace-v1"
        wn._store = ws
        self.device = str(uuid.uuid4())
        self.assertTrue(ws.handle({"op": "bootstrap", "deviceId": self.device})["ok"])
        self.source = "source-a"

    def tearDown(self):
        if self.old_home is None:
            os.environ.pop("HOME", None)
        else:
            os.environ["HOME"] = self.old_home
        self.td.cleanup()

    def commit(self, records, device=None):
        return ws.handle({
            "op": "commit",
            "deviceId": device or self.device,
            "operationId": str(uuid.uuid4()),
            "records": records,
        })

    def media(self, path, *, kind="image", modified=1000, title=None,
              artist=None, album=None, folder=None, size=100, base=0,
              deleted=False):
        value = {
            "type": "media", "sourceId": self.source, "path": path,
            "kind": kind, "sizeBytes": size, "modifiedEpoch": modified,
            "title": title, "artist": artist, "album": album,
            "folder": folder or path.rsplit("/", 1)[0] or "/",
            "sortName": (title or path.rsplit("/", 1)[-1]).lower(),
        }
        return {"kind": "nas_media", "id": "media/%s/%s" % (self.source, abs(hash(path))),
                "value": value, "baseVersion": base, "deleted": deleted}

    def call(self, request):
        return wn.handle({"sourceId": self.source, **request})

    # -- totals / filters / paging ---------------------------------------
    def test_totals_and_filters_are_whole_library_not_first_page(self):
        records = []
        for i in range(450):
            kind = "image" if i < 300 else ("video" if i < 400 else "audio")
            records.append(self.media(
                "/lib/%s/f%03d.bin" % (kind, i), kind=kind,
                modified=1000 + i, title="Item %03d" % i,
                artist="Artist A" if i % 2 == 0 else "Artist B",
                album="Album %d" % (i % 3), size=100 + i))
        self.assertTrue(self.commit(records)["ok"])

        totals = self.call({"op": "nas_totals"})["totals"]
        self.assertEqual(totals, {
            "total": 450, "images": 300, "videos": 100,
            "audio": 50, "favorites": 0,
        })
        self.assertEqual(self.call({"op": "nas_count", "kind": "video"})["count"], 100)
        self.assertEqual(
            self.call({"op": "nas_count", "folder": "/lib/image"})["count"], 300)
        self.assertEqual(
            self.call({"op": "nas_count", "artist": "Artist A"})["count"], 225)
        self.assertEqual(
            self.call({"op": "nas_count", "search": "Item 04"})["count"], 10)

        first = self.call({"op": "nas_query", "limit": 200})
        self.assertEqual(len(first["records"]), 200)
        self.assertTrue(first["hasMore"])
        second = self.call({
            "op": "nas_query", "limit": 200,
            "cursor": first["nextCursor"],
        })
        third = self.call({
            "op": "nas_query", "limit": 200,
            "cursor": second["nextCursor"],
        })
        self.assertEqual(len(second["records"]), 200)
        self.assertEqual(len(third["records"]), 50)
        self.assertFalse(third["hasMore"])
        paths = [r["path"] for r in first["records"] + second["records"] + third["records"]]
        self.assertEqual(len(set(paths)), 450)

    def test_sort_and_group_counts(self):
        self.assertTrue(self.commit([
            self.media("/a/one.jpg", modified=10, title="Zulu", size=300,
                       artist="A", album="X"),
            self.media("/a/two.jpg", modified=20, title="Alpha", size=100,
                       artist="A", album="X"),
            self.media("/b/three.jpg", modified=30, title="Mike", size=200,
                       artist="B", album="Y"),
        ])["ok"])
        by_name = self.call({
            "op": "nas_query", "sortKey": "name", "ascending": True, "limit": 10,
        })
        self.assertEqual([r["title"] for r in by_name["records"]],
                         ["Alpha", "Mike", "Zulu"])
        by_size = self.call({
            "op": "nas_query", "sortKey": "size", "ascending": False, "limit": 10,
        })
        self.assertEqual([r["sizeBytes"] for r in by_size["records"]],
                         [300, 200, 100])
        artists = self.call({"op": "nas_groups", "group": "artist", "limit": 10})
        self.assertEqual({g["key"]: g["count"] for g in artists["groups"]},
                         {"A": 2, "B": 1})
        folders = self.call({"op": "nas_groups", "group": "folder", "limit": 10})
        self.assertEqual({g["key"]: g["count"] for g in folders["groups"]},
                         {"/a": 2, "/b": 1})
        albums = self.call({"op": "nas_groups", "group": "album", "limit": 10})
        self.assertEqual({g["name"]: g["count"] for g in albums["groups"]},
                         {"X": 2, "Y": 1})

    # -- favorite / playlist / playback across devices -------------------
    def test_favorite_playlist_and_playback_survive_media_tombstone(self):
        other = str(uuid.uuid4())
        self.assertTrue(self.commit([
            self.media("/m/a.mp3", kind="audio", modified=1),
            self.media("/m/b.mp3", kind="audio", modified=2),
        ])["ok"])
        self.assertTrue(self.commit([
            {"kind": "nas_media", "id": "favorite/%s/a" % self.source,
             "value": {"type": "favorite", "sourceId": self.source,
                       "path": "/m/a.mp3", "value": True, "updatedEpoch": 50},
             "baseVersion": 0, "deleted": False},
            {"kind": "nas_media", "id": "playback/%s/a" % self.source,
             "value": {"type": "playback", "sourceId": self.source,
                       "path": "/m/a.mp3", "positionMillis": 1234,
                       "durationMillis": 9999, "updatedEpoch": 60},
             "baseVersion": 0, "deleted": False},
            {"kind": "nas_media", "id": "playlist/%s/p1" % self.source,
             "value": {"type": "playlist", "sourceId": self.source,
                       "playlistId": "p1", "name": "Mix",
                       "createdEpoch": 10},
             "baseVersion": 0, "deleted": False},
            {"kind": "nas_media", "id": "playlist_item/%s/p1/a" % self.source,
             "value": {"type": "playlist_item", "sourceId": self.source,
                       "playlistId": "p1", "path": "/m/a.mp3", "position": 0},
             "baseVersion": 0, "deleted": False},
        ], device=other)["ok"])

        favorites = self.call({"op": "nas_query", "favoritesOnly": True})
        self.assertEqual([r["path"] for r in favorites["records"]], ["/m/a.mp3"])
        playlists = self.call({"op": "nas_playlists"})["playlists"]
        self.assertEqual(playlists, [{"id": "p1", "name": "Mix",
                                      "createdEpoch": 10, "itemCount": 1}])
        items = self.call({"op": "nas_playlist_items", "playlistId": "p1"})
        self.assertEqual([r["path"] for r in items["records"]], ["/m/a.mp3"])
        playback = self.call({"op": "nas_playback", "paths": ["/m/a.mp3"]})
        self.assertEqual(playback["playback"]["/m/a.mp3"]["positionMillis"], 1234)

        # A media tombstone from another device must not erase favorite,
        # playlist membership or playback state.
        current = ws.handle({
            "op": "snapshot", "kind": "nas_media", "prefix": "media/%s/" % self.source,
            "limit": 10,
        })["records"]
        base = next(r["version"] for r in current
                    if r["value"]["path"] == "/m/a.mp3")
        tombstone = self.media("/m/a.mp3", kind="audio", modified=1,
                               base=base, deleted=True)
        self.assertTrue(self.commit([tombstone])["ok"])
        self.assertEqual(self.call({"op": "nas_count"})["count"], 1)
        self.assertEqual(self.call({"op": "nas_playback",
                                    "paths": ["/m/a.mp3"]})["playback"]["/m/a.mp3"]["positionMillis"], 1234)
        # The favorite row itself remains; it simply has no media to join.
        self.assertEqual(self.call({"op": "nas_query", "favoritesOnly": True})["records"], [])

    def test_bounded_index_catches_up_over_multiple_batches(self):
        records = [
            self.media("/big/f%04d.bin" % i, kind="image", modified=i)
            for i in range(1200)
        ]
        for start in range(0, len(records), 500):
            self.assertTrue(self.commit(records[start:start + 500])["ok"])
        self.assertEqual(self.call({"op": "nas_totals"})["totals"]["total"], 1200)
        self.assertEqual(self.call({"op": "nas_count"})["count"], 1200)

    def test_index_is_derived_and_store_is_not_modified(self):
        self.assertTrue(self.commit([self.media("/x/a.jpg")])["ok"])
        self.assertEqual(self.call({"op": "nas_count"})["count"], 1)
        with sqlite3.connect(ws.ROOT / ws.DB_NAME) as conn:
            tables = {row[0] for row in conn.execute(
                "SELECT name FROM sqlite_master WHERE type='table'")}
        self.assertNotIn("nas_media", tables)
        self.assertTrue((ws.ROOT / wn.INDEX_NAME).exists())

    def test_unknown_operation_is_reported(self):
        self.assertEqual(wn.handle({"op": "nas_nope"})["error"],
                         "WORKSPACE_OP_UNKNOWN")


if __name__ == "__main__":
    unittest.main()
