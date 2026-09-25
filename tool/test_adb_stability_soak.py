"""Offline regression: python3 -m unittest discover -s tool -p 'test_adb_stability_soak.py'."""
import json
import pathlib
import subprocess
import tempfile
import unittest
from unittest import mock
import xml.etree.ElementTree as ET

import adb_stability_soak as soak


SUCCESS = f"UI hierchary dumped to: {soak.DUMP_PATH}"
FRESH = '<hierarchy><node text="fresh" /></hierarchy>'


class FakeDump:
    def __init__(self, attempts):
        self.attempts = iter(attempts)
        self.file = '<hierarchy><node text="stale" /></hierarchy>'
        self.calls = []

    def __call__(self, *command, **kwargs):
        self.calls.append(command)
        assert 0 < kwargs["timeout"] <= 8
        if command[:3] == ("shell", "rm", "-f"):
            self.file = None
            return ""
        if command[:3] == ("shell", "uiautomator", "dump"):
            assert self.file is None, "Previous dump was not removed"
            assert kwargs["include_stderr"]
            output, self.file = next(self.attempts)
            return output
        if command[:3] == ("shell", "test", "-s"):
            if not self.file:
                raise subprocess.CalledProcessError(1, command)
            return ""
        if command[:2] == ("exec-out", "cat"):
            return self.file
        raise AssertionError(command)


class SoakChecksTest(unittest.TestCase):
    @mock.patch.object(soak.time, "sleep")
    def test_exit_zero_errors_never_read_old_xml(self, _):
        for message in ("ERROR: could not get idle state", "ERROR: null root node"):
            with self.subTest(message=message):
                fake = FakeDump([(SUCCESS + "\n" + message, FRESH)] * 3)
                with self.assertRaisesRegex(RuntimeError, "Fresh UI dump failed"):
                    soak.dump_nodes(fake)
                self.assertEqual(3, sum(c[:2] == ("shell", "rm") for c in fake.calls))
                self.assertFalse(any(c[:2] == ("exec-out", "cat") for c in fake.calls))

    @mock.patch.object(soak.time, "sleep")
    def test_success_requires_new_nonempty_hierarchy(self, _):
        for payload in (None, "<hierarchy />", "null", "<wrong><node /></wrong>"):
            with self.subTest(payload=payload):
                fake = FakeDump([(SUCCESS, payload)] * 3)
                with self.assertRaisesRegex(RuntimeError, "Fresh UI dump failed"):
                    soak.dump_nodes(fake)
        fake = FakeDump([("ERROR: null root node", None), (SUCCESS, FRESH)])
        self.assertEqual("fresh", soak.dump_nodes(fake)[0].get("text"))

    def test_route_requires_app_bar_title_not_menu_or_bottom_label(self):
        menu = ET.Element("node", {"content-desc": "更多功能", "package": soak.PACKAGE,
                                  "clickable": "true", "bounds": "[0,96][224,320]"})
        title = ET.Element("node", {"content-desc": "仪表盘", "package": soak.PACKAGE,
                                   "clickable": "false", "bounds": "[224,162][344,254]"})
        soak.require_route([menu, title], soak.ROUTES[0])
        with self.assertRaisesRegex(RuntimeError, "Page title"):
            soak.require_route([menu, title], soak.ROUTES[1])
        for attrs in ({"clickable": "true"}, {"bounds": "[224,2800][344,2900]"}):
            other = ET.Element("node", {**title.attrib, **attrs})
            with self.assertRaisesRegex(RuntimeError, "Page title"):
                soak.require_route([menu, other], soak.ROUTES[0])

    def test_initial_dump_failure_writes_failed_result_without_adb(self):
        with tempfile.TemporaryDirectory() as directory:
            with mock.patch("sys.argv", ["soak", "--expected-server", "fixture",
                                         "--output", directory]), \
                    mock.patch.object(soak.subprocess, "run", return_value=
                                      subprocess.CompletedProcess([], 0, b"device", b"")), \
                    mock.patch.object(soak, "dump_nodes", side_effect=RuntimeError("bad dump")):
                with self.assertRaisesRegex(RuntimeError, "bad dump"):
                    soak.main()
            result = json.loads((pathlib.Path(directory) / "result.json").read_text())
            self.assertEqual("failed", result["status"])
            self.assertEqual(0, result["cycles"])


if __name__ == "__main__":
    unittest.main()
