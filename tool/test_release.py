import unittest
from unittest.mock import patch
from release import Release, next_version, normalize, virtual_placeholder


class ReleaseTests(unittest.TestCase):
    def test_patch_and_build_increment(self):
        self.assertEqual(next_version('1.0.13+14'), '1.0.14+15')
        self.assertEqual(next_version('2.3.99+998'), '2.3.100+999')

    def test_invalid_or_overlapping_native_codes_rejected(self):
        for value in ['1.0.1', '1.0.1-beta+1', '1.0.1+0', '1.0.1+999', '1.0.1+1000', 'x']:
            with self.subTest(value=value), self.assertRaises(ValueError):
                next_version(value)

    def test_history_comparison_ignores_only_counters(self):
        self.assertEqual(normalize([{'id': 'old', 'download_count': 1, 'packages': [{'download_count': 2}]}]),
                         normalize([{'id': 'old', 'download_count': 3, 'packages': [{'download_count': 4}]}]))
        self.assertNotEqual(normalize({'file_sha256': 'one'}), normalize({'file_sha256': 'two'}))

    def test_resume_accepts_only_committed_automation_changes_after_build(self):
        release = Release.__new__(Release)
        release.state = {'source': 'old', 'built': True}
        with patch('release.subprocess.check_output', side_effect=['new\n', '', 'tool/release.py\ndocs/README.md\n']), patch('release.subprocess.run') as run:
            release.validate_source()
            run.assert_called_once()
        for changed in ['lib/main.dart\n', 'pubspec.yaml\n']:
            with patch('release.subprocess.check_output', side_effect=['new\n', '', changed]), patch('release.subprocess.run'), self.assertRaises(RuntimeError):
                release.validate_source()

    def test_resume_rejects_dirty_tree(self):
        release = Release.__new__(Release)
        release.state = {'source': 'same', 'built': True}
        with patch('release.subprocess.check_output', side_effect=['same\n', ' M tool/release.py']), self.assertRaises(RuntimeError):
            release.validate_source()

    def test_virtual_fallback_is_not_a_registered_package(self):
        empty = {'id': 'pkg_def_ver_new', 'version_id': 'ver_new', 'file_size': 0}
        self.assertTrue(virtual_placeholder(empty))
        self.assertFalse(virtual_placeholder({**empty, 'id': 'pkg_real'}))
        self.assertFalse(virtual_placeholder({**empty, 'file_sha256': 'not-empty'}))


if __name__ == '__main__':
    unittest.main()
