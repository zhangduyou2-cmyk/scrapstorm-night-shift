"""Build infrastructure regressions, without network or real user game settings."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("run_tests", ROOT / "tools/run_tests.py")
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class TestResultHandling(unittest.TestCase):
    def test_success_requires_completed_assertions(self):
        self.assertEqual(runner.summarize('WORLD TESTS: 22 checks, 0 failures', 0), (22, True))
        self.assertEqual(runner.summarize('AUDIO_TEST {"checks":12,"failures":[]}', 0), (12, True))
        for text in ('Godot Engine started', '{"checks":0,"failures":[]}', 'SCRIPT ERROR: parse error'):
            self.assertFalse(runner.summarize(text, 0)[1])

    def test_false_exit_zero_and_reported_failures_fail(self):
        for text in ('{"checks":12,"failures":["save failed"]}', '12 checks\nERROR: load failed', '12 checks\nObjectDB instances leaked', '{"checks":12,"passed":false}'):
            self.assertFalse(runner.summarize(text, 0)[1])
        self.assertFalse(runner.summarize('12 checks', 1)[1])

    def test_unavailable_engine_is_a_failure(self):
        output, code = runner.execute([str(ROOT / 'nonexistent-godot.exe')], 1)
        self.assertEqual(code, 127)
        self.assertIn('PROCESS START FAILED', output)


class TestInstallerGuards(unittest.TestCase):
    def run_setup(self, extra):
        shell = shutil.which('powershell.exe')
        self.assertIsNotNone(shell, 'Supported Windows test runner requires PowerShell')
        return subprocess.run([shell, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
                               str(ROOT / 'tools/setup_godot.ps1'), *extra], capture_output=True,
                              text=True, encoding='utf-8', errors='replace', timeout=60,
                              env={key: value for key, value in os.environ.items() if key.lower() != 'psmodulepath'})

    def test_unreviewed_version_is_rejected(self):
        result = self.run_setup(['-Version', '4.0'])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('differs from', result.stdout + result.stderr)

    def test_corrupt_cached_archive_is_not_extracted(self):
        lock = json.loads((ROOT / 'tools/godot.lock.json').read_text(encoding='utf-8-sig'))
        with tempfile.TemporaryDirectory(prefix='scrapstorm corrupt archive ') as directory:
            archive = Path(directory) / lock['archives']['engine']['name']
            archive.write_bytes(b'incomplete download')
            result = self.run_setup(['-DownloadDirectory', directory])
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Archive size mismatch', result.stdout + result.stderr)
            # Correct byte count must still fail the actual SHA check, before unzip.
            with archive.open('wb') as stream:
                stream.truncate(lock['archives']['engine']['bytes'])
            result = self.run_setup(['-DownloadDirectory', directory])
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('SHA256 mismatch', result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
