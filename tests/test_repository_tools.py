"""Public-source boundary and packaging regression tests; no real secrets or profiles."""
from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from check_repository import allowed_path, check_tree, public_files
from package_source import package


def write(root: Path, name: str, content: str = "") -> None:
    path = root / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def fixture(root: Path) -> None:
    for name, content in {
        ".godot-version": "4.7.2\n", "README.md": "# Fixture v0.5.1\n[Scene](scenes/main.tscn)\n",
        "LICENSE": "Fixture text; presence only, not legal approval.\n",
        "THIRD_PARTY_NOTICES.md": "Fixture notices\n",
        "project.godot": 'config/version="0.5.1"\nconfig/features=PackedStringArray("4.7")\nrun/main_scene="res://scenes/main.tscn"\n',
        "export_presets.cfg": 'export_path="exports/windows-v0.5.1/Scrapstorm.exe"\napplication/file_version="0.5.1.0"\napplication/product_version="0.5.1.0"\ncustom_template/release=".tools/export_templates/4.7.2.stable/windows.exe"\n',
        "Play.cmd": "start exports/windows-v0.5.1/Scrapstorm.exe\n",
        "scenes/main.tscn": '[gd_scene]\n[ext_resource path="res://scripts/ui/main.gd"]\n',
        "scripts/ui/main.gd": "extends Node2D\n",
        "localization/strings.csv": "keys,en,zh_CN\nHELLO,Hello,你好\n",
    }.items():
        write(root, name, content)
    for sector in ("yard", "foundry", "reactor"):
        for layer in ("bed", "rhythm", "boss"):
            write(root, f"assets/audio/music/{sector}_{layer}.ogg", "fixture music bytes")


class RepositoryToolsTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="repository-boundary-test-")
        self.base = Path(self.temporary.name)
        self.root = self.base / "source"
        self.root.mkdir()
        fixture(self.root)

    def tearDown(self):
        self.temporary.cleanup()

    def codes(self, **options):
        return {row["code"] for row in check_tree(self.root, **options)["findings"]}

    def test_clean_tree_requires_no_git_or_local_engine(self):
        result = check_tree(self.root, public_tree=True)
        self.assertTrue(result["passed"], result["findings"])
        self.assertFalse(result["git_checkout"])

    def test_new_root_document_requires_explicit_classification(self):
        write(self.root, "unreviewed.md", "Review before public packaging")
        self.assertIn("unclassified_root_source", self.codes(public_tree=True))

    def test_public_tooling_document_lock_and_packages_are_included(self):
        required = ("tools/README.md", "tools/godot.lock.json", "tools/smoke_release.cjs", "tools/package_web.py")
        for name in required:
            write(self.root, name, "fixture")
        write(self.root, "README.md", "[Tools](tools/README.md)\n")
        names, _ = public_files(self.root)
        self.assertTrue(set(required).issubset(names))
        self.assertNotIn("missing_readme_target", self.codes(public_tree=True))
        report = package(self.root, self.base / "with-tools.zip")
        self.assertTrue(set(required).issubset(report["files"]))

    def test_missing_literal_resource_fails_with_case_sensitive_name(self):
        write(self.root, "scripts/ui/main.gd", 'extends Node2D\nconst K = preload("res://scripts/ui/Missing.gd")\n')
        self.assertIn("missing_resource", self.codes())

    def test_missing_dynamic_music_layer_is_not_silently_skipped(self):
        (self.root / "assets/audio/music/reactor_boss.ogg").unlink()
        self.assertIn("missing_music_layer", self.codes())

    def test_readme_broken_and_external_absolute_links_fail(self):
        write(self.root, "README.md", "[missing](docs/not-present.md)\n[local](/outside/file.md)\n")
        self.assertTrue({"missing_readme_target", "absolute_readme_link"}.issubset(self.codes()))

    def test_subdirectory_readme_parent_link_resolves(self):
        write(self.root, "docs/README.md", "[Home](../README.md)\n")
        self.assertNotIn("missing_readme_target", self.codes())

    def test_versions_disagree(self):
        write(self.root, "Play.cmd", "start exports/windows-v0.4.0/Scrapstorm.exe\n")
        self.assertIn("launch_version", self.codes())

    def test_delegating_launcher_uses_project_version(self):
        write(self.root, "Play.cmd", 'powershell -File "%~dp0Play.ps1" -PreferBuild\n')
        write(self.root, "Play.ps1", '$release = Select-String project.godot -Pattern "config/version="\n')
        self.assertNotIn("launch_version", self.codes())

    def test_high_confidence_token_is_redacted(self):
        token = "gh" + "p_" + "a" * 36
        write(self.root, "docs/leaked.md", token)
        result = check_tree(self.root)
        self.assertIn("secret_candidate", {row["code"] for row in result["findings"]})
        self.assertNotIn(token, json.dumps(result))

    def test_current_personal_path_is_not_hidden_in_public_mode(self):
        value = "C:" + "/Users/" + "fixture-person/game"
        write(self.root, "docs/local.md", value)
        result = check_tree(self.root, public_tree=True)
        findings = [row for row in result["findings"] if row["code"] == "personal_local_path"]
        self.assertEqual(findings[0]["severity"], "error")
        self.assertNotIn(value, json.dumps(result))

    def test_duplicate_translation_key_rejected(self):
        write(self.root, "localization/strings.csv", "keys,en,zh_CN\nA,a,a\nA,b,b\n")
        self.assertIn("translation_row", self.codes())

    def test_nested_git_marker_rejected(self):
        write(self.root, "docs/copied/.git", "gitdir: outside")
        self.assertIn("unsafe_entry", self.codes(public_tree=True))

    def test_allowlist_excludes_local_data_and_credentials(self):
        for name in (".git/config", ".tools/engine.exe", ".godot/cache", "artifacts/probe.json", "exports/game.pck", "captures/test.png", "tools/.env", "tools/private.key", "tools/profile.json", "tools/profile.json.bak", "tests/__pycache__/test.pyc"):
            write(self.root, name, "excluded")
            self.assertFalse(allowed_path(name), name)
        names, _ = public_files(self.root)
        self.assertFalse(any(name.startswith((".git/", ".tools/", "artifacts/", "exports/", "captures/")) for name in names))
        self.assertFalse(allowed_path("docs/../outside.md"))
        self.assertFalse(allowed_path("docs/..\\outside.md"))
        self.assertFalse(allowed_path("docs/file.md:alternate-stream"))

    def test_zip_is_deterministic_and_clean_extraction_verified(self):
        write(self.root, "artifacts/user-profile.json", "excluded")
        a = package(self.root, self.base / "first.zip", self.base / "first")
        b = package(self.root, self.base / "second.zip", self.base / "second")
        self.assertEqual(a["zip_sha256"], b["zip_sha256"])
        self.assertTrue(a["clean_tree_check"]["passed"])
        with zipfile.ZipFile(self.base / "first.zip") as archive:
            self.assertNotIn("artifacts/user-profile.json", archive.namelist())
            self.assertEqual(sorted(a["files"]), archive.namelist())

    def test_zip_never_overwrites_existing_output_or_extract_directory(self):
        output = self.base / "preserved.zip"
        output.write_bytes(b"preserve")
        with self.assertRaises(ValueError):
            package(self.root, output)
        self.assertEqual(output.read_bytes(), b"preserve")
        with self.assertRaises(ValueError):
            package(self.root, self.base / "new.zip", self.root)

    def test_preparation_allows_only_missing_license(self):
        (self.root / "LICENSE").unlink()
        with self.assertRaises(ValueError):
            package(self.root, self.base / "public.zip")
        prepared = package(self.root, self.base / "review.zip", prepare=True)
        self.assertTrue(prepared["preparation_only"])
        write(self.root, "docs/local.md", "C:" + "/Users/" + "fixture-person/game")
        with self.assertRaises(ValueError):
            package(self.root, self.base / "privacy-block.zip", prepare=True)

    def test_history_identity_is_masked_and_public_tree_skips_it(self):
        try:
            subprocess.run(["git", "init", "-q", str(self.root)], check=True, capture_output=True)
        except (OSError, subprocess.CalledProcessError):
            self.skipTest("Git unavailable")
        subprocess.run(["git", "-C", str(self.root), "add", "."], check=True, capture_output=True)
        email = "fixture" + "@example.invalid"
        subprocess.run(["git", "-C", str(self.root), "-c", "user.name=Fixture", "-c", "user.email=" + email, "commit", "-qm", "fixture"], check=True, capture_output=True)
        result = check_tree(self.root, history=True)
        self.assertTrue(result["history"]["needs_clean_public_history"])
        self.assertNotIn(email, json.dumps(result))
        public = check_tree(self.root, public_tree=True)
        self.assertEqual(public["history"]["status"], "not_requested")
        self.assertTrue(public["passed"])

    def test_new_git_repository_has_empty_history_not_a_crash(self):
        try:
            subprocess.run(["git", "init", "-q", str(self.root)], check=True, capture_output=True)
        except (OSError, subprocess.CalledProcessError):
            self.skipTest("Git unavailable")
        result = check_tree(self.root, history=True)
        self.assertEqual(result["history"]["commits"], 0)
        self.assertTrue(result["passed"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
