import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from release import Release, main, next_version, normalize, virtual_placeholder


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


class BuildOnlyTests(unittest.TestCase):
    def _invoke(self, flags, built):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            resume = root / 'resume'
            resume.mkdir()
            with patch('release.ROOT', root), \
                 patch('release.os.chdir') as chdir, \
                 patch('release.Release') as release_class, \
                 patch.object(sys, 'argv', ['release.py', '--resume', str(resume), *flags]):
                instance = release_class.return_value
                instance.state = {'built': built}
                main()
            chdir.assert_called_once_with(root)
            release_class.assert_called_once_with(resume)
            instance.validate_source.assert_called_once_with()
            return instance

    def test_build_only_builds_unbuilt_and_never_publishes(self):
        instance = self._invoke(['--build-only'], built=False)
        instance.build_packages.assert_called_once_with()
        instance.github.assert_not_called()
        instance.distribution.assert_not_called()
        instance.verify.assert_not_called()

    def test_build_only_skips_rebuild_when_already_built(self):
        instance = self._invoke(['--build-only'], built=True)
        instance.build_packages.assert_not_called()
        instance.github.assert_not_called()
        instance.distribution.assert_not_called()
        instance.verify.assert_not_called()

    def test_resume_without_flag_publishes_without_rebuild(self):
        instance = self._invoke([], built=True)
        instance.build_packages.assert_not_called()
        instance.github.assert_called_once_with()
        instance.distribution.assert_called_once_with()
        instance.verify.assert_called_once_with()


if __name__ == '__main__':
    unittest.main()
