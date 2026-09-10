"""Export-package validation with isolated dummy files, never real release outputs."""
from __future__ import annotations

import contextlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import package_web
import package_windows
from package_common import digest, validate_export_manifest


class PackageManifestTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="package-manifest-test-")
        self.base = Path(self.temporary.name)

    def tearDown(self):
        self.temporary.cleanup()

    def fixture(self, platform):
        module = package_windows if platform == "Windows" else package_web
        root = self.base / platform
        root.mkdir()
        (root / "project.godot").write_text('config/version="0.5.1"\n', encoding="utf-8")
        source = root / "exports" / ("windows-v0.5.1" if platform == "Windows" else "web")
        source.mkdir(parents=True)
        members = module.FILES if platform == "Windows" else module.RUNTIME + module.NOTICES
        for name in members:
            (source / name).write_bytes(("Isolated packaging fixture: " + name).encode())
        for name in ("CREDITS.md", "PRIVACY.md", "README-PLAY.txt", "THIRD_PARTY_NOTICES.md"):
            (root / name).write_bytes((source / name).read_bytes())
        if platform == "Windows":
            for name in ("Play.cmd", "Play.ps1"):
                (root / name).write_bytes((source / name).read_bytes())
        rows = [{"name": name, "bytes": (source / name).stat().st_size, "sha256": digest(source / name)} for name in members if name != "build-manifest.json"]
        # Export-only import descriptors can be described without being shipped.
        rows.append({"name": "index.png.import", "bytes": 3, "sha256": "a" * 64})
        manifest = {"project_version": "0.5.1", "files": rows}
        (source / "build-manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        artifacts = root / "artifacts"
        artifacts.mkdir()
        output = artifacts / f"Scrapstorm-Night-Shift-v0.5.1-{platform}.zip"
        return module, root, source, members, manifest, output

    def run_package(self, module, root):
        with mock.patch.object(module, "ROOT", root), contextlib.redirect_stdout(io.StringIO()):
            module.main()

    def test_both_packages_validate_and_do_not_ship_extra_manifest_members(self):
        for platform in ("Windows", "Web"):
            with self.subTest(platform=platform):
                module, root, source, members, manifest, output = self.fixture(platform)
                self.run_package(module, root)
                with zipfile.ZipFile(output) as archive:
                    self.assertEqual(archive.namelist(), list(members))
                    self.assertNotIn("index.png.import", archive.namelist())
                report = json.loads((root / "artifacts" / f"{platform.lower()}-v0.5.1-package.json").read_text(encoding="utf-8"))
                self.assertTrue(report["build_manifest_verified"])

    def test_both_reject_old_version_empty_manifest_and_preserve_existing_zip(self):
        for platform in ("Windows", "Web"):
            with self.subTest(platform=platform):
                module, root, source, _, manifest, output = self.fixture(platform)
                output.write_bytes(b"prior release evidence")
                manifest.update(project_version="0.4.0", files=[])
                (source / "build-manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "version"):
                    self.run_package(module, root)
                self.assertEqual(output.read_bytes(), b"prior release evidence")

    def test_windows_rejects_stale_launcher_before_replacing_zip(self):
        module, root, source, _, _, output = self.fixture("Windows")
        output.write_bytes(b"previous package")
        (root / "Play.ps1").write_text("new fixed launcher", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "Play.ps1 is stale"):
            self.run_package(module, root)
        self.assertEqual(output.read_bytes(), b"previous package")

    def test_both_reject_missing_member(self):
        for platform in ("Windows", "Web"):
            with self.subTest(platform=platform):
                module, root, source, _, manifest, output = self.fixture(platform)
                manifest["files"].pop(0)
                (source / "build-manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "omits"):
                    self.run_package(module, root)
                self.assertFalse(output.exists())

    def test_both_reject_modified_runtime_bytes(self):
        for platform in ("Windows", "Web"):
            with self.subTest(platform=platform):
                module, root, source, members, _, output = self.fixture(platform)
                first = source / members[0]
                first.write_bytes(first.read_bytes() + b"changed after build")
                with self.assertRaisesRegex(ValueError, "differs"):
                    self.run_package(module, root)
                self.assertFalse(output.exists())

    def test_wrong_size_or_sha_is_rejected_independently(self):
        _, _, source, members, manifest, _ = self.fixture("Windows")
        original = manifest["files"][0].copy()
        for key, bad in (("bytes", original["bytes"] + 1), ("sha256", "0" * 64)):
            with self.subTest(field=key):
                manifest["files"][0] = {**original, key: bad}
                (source / "build-manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "differs"):
                    validate_export_manifest(source, "0.5.1", members)

    def test_duplicate_and_unsafe_manifest_names_are_rejected(self):
        _, _, source, members, manifest, _ = self.fixture("Windows")
        original = manifest["files"].copy()
        for bad in (original[0], {**original[0], "name": "../outside"}):
            manifest["files"] = original + [bad]
            (source / "build-manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaises(ValueError):
                validate_export_manifest(source, "0.5.1", members)

    def test_boolean_file_size_is_not_an_integer_size(self):
        _, _, source, members, manifest, _ = self.fixture("Windows")
        manifest["files"][0]["bytes"] = True
        (source / "build-manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "integers"):
            validate_export_manifest(source, "0.5.1", members)

    def test_powershell_utf8_bom_is_supported(self):
        _, _, source, members, manifest, _ = self.fixture("Windows")
        (source / "build-manifest.json").write_text(json.dumps(manifest), encoding="utf-8-sig")
        hashes = validate_export_manifest(source, "0.5.1", members)
        self.assertEqual(set(hashes), set(members))

    def test_crc_failure_does_not_replace_prior_output_for_either_platform(self):
        for platform in ("Windows", "Web"):
            with self.subTest(platform=platform):
                module, root, _, _, _, output = self.fixture(platform)
                output.write_bytes(b"prior release evidence")
                with mock.patch.object(zipfile.ZipFile, "testzip", return_value="damaged-member"), self.assertRaises(ValueError):
                    self.run_package(module, root)
                self.assertEqual(output.read_bytes(), b"prior release evidence")
                self.assertEqual(list((root / "artifacts").glob("*.zip")), [output])


if __name__ == "__main__":
    unittest.main(verbosity=2)
