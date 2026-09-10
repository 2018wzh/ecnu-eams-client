import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('release', Path(__file__).resolve().parents[1] / 'release.py')
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleaseTests(unittest.TestCase):
    def test_tag_and_package_versions_must_match(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'app').mkdir()
            (root / 'packages/eams_core').mkdir(parents=True)
            (root / 'app/pubspec.yaml').write_text('version: 1.2.3-beta.1+17\n')
            core = root / 'packages/eams_core/pubspec.yaml'
            core.write_text('version: 1.2.3-beta.1\n')
            self.assertEqual(release.metadata(root, 'refs/tags/v1.2.3-beta.1'), {'version': '1.2.3-beta.1', 'build_number': '17', 'prerelease': 'true'})
            for tag in ('refs/tags/v1.2.4', 'refs/tags/v1.2.3-beta.1+17', 'refs/tags/not-a-version'):
                with self.assertRaises(ValueError):
                    release.metadata(root, tag)
            core.write_text('version: 1.2.2\n')
            with self.assertRaises(ValueError):
                release.metadata(root, '')

    def test_missing_empty_or_unexpected_assets_prevent_release(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            with self.assertRaises(ValueError):
                release.checksums(directory, '1.0.0')
            suffixes = ['android-armeabi-v7a.apk', 'android-arm64-v8a.apk', 'android-x86_64.apk', 'android.aab', 'windows-x64.zip', 'linux-x64.tar.gz', 'macos-arm64.zip', 'web.zip', 'cli-windows-x64.zip', 'cli-linux-x64.tar.gz', 'cli-macos-arm64.tar.gz']
            for suffix in suffixes:
                (directory / f'ecnu-eams-1.0.0-{suffix}').write_bytes(b'artifact')
            release.checksums(directory, '1.0.0')
            self.assertEqual(len((directory / 'SHA256SUMS').read_text().splitlines()), 11)
            accidental = directory / 'signing-key.jks'
            accidental.write_bytes(b'not-for-publication')
            with self.assertRaises(ValueError):
                release.checksums(directory, '1.0.0')
            accidental.unlink()
            (directory / 'ecnu-eams-1.0.0-android.aab').write_bytes(b'')
            with self.assertRaises(ValueError):
                release.checksums(directory, '1.0.0')


if __name__ == '__main__':
    unittest.main()
