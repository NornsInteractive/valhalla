import unittest
from release import next_version, normalize


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


if __name__ == '__main__':
    unittest.main()
