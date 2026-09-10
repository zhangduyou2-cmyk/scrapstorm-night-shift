"""Check the distributable source tree without printing secret values or personal metadata.

Python standard library only. Works in a checkout or an extracted source ZIP.
--public-tree checks current files strictly and never inspects old Git history.
--history additionally audits all reachable Git blobs and masked commit identities.
This is a bounded high-confidence check, not a guarantee that every secret is detected.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
from urllib.parse import unquote, urlsplit

ROOT_FILES = {
    ".editorconfig", ".gitattributes", ".gitignore", ".godot-version",
    "AGENTS.md", "Play.cmd", "Play.ps1", "README.md", "THIRD_PARTY_NOTICES.md",
    "project.godot", "export_presets.cfg", "LICENSE", "LICENSE.md", "LICENSE.txt",
    "ASSET_LICENSE.md", "LICENSE_ASSETS.md", "AUTHORS.md", "CONTRIBUTORS.md",
    "CONTRIBUTING.md", "SECURITY.md", "CODE_OF_CONDUCT.md", "CHANGELOG.md",
    "CREDITS.md", "PRIVACY.md", "README-PLAY.txt", "requirements-audio.txt",
    "package.json", "package-lock.json",
}
TREE_EXTENSIONS = {
    "assets": {".wav", ".ogg", ".png", ".jpg", ".webp", ".svg", ".otf", ".ttf", ".txt", ".md", ".json", ".import"},
    "docs": {".md", ".csv", ".png", ".jpg", ".webp", ".svg", ".txt", ".json"},
    "scripts": {".gd", ".uid"}, "scenes": {".tscn", ".tres"},
    "localization": {".csv", ".translation", ".import"},
    "tests": {".gd", ".py"}, "tools": {".py", ".ps1", ".cmd", ".cjs", ".gd", ".json", ".md"},
    ".github": {".md", ".yml", ".yaml", ".json", ".png", ".svg", ".txt"},
}
EXCLUDED_PARTS = {".git", ".godot", ".tools", ".import", "artifacts", "exports", "captures", "build", "builds", "node_modules", "__pycache__", ".venv", "venv", ".preproduction-local", ".playwright", ".pytest_cache", ".mypy_cache"}
TEXT_EXTENSIONS = {".gd", ".py", ".ps1", ".cmd", ".cjs", ".md", ".txt", ".csv", ".json", ".yml", ".yaml", ".godot", ".cfg", ".tscn", ".tres", ".svg", ".import", ".uid"}
SECRET_PATTERNS = {
    "private_key": re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----"),
    "github_token": re.compile(rb"\b(?:gh[pousr]_[A-Za-z0-9]{36,255}|github_pat_[A-Za-z0-9_]{60,255})\b"),
    "openai_project_key": re.compile(rb"\bsk-(?:proj-|svcacct-)[A-Za-z0-9_-]{40,}\b"),
    "aws_access_key": re.compile(rb"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b"),
}
# Explicit user-home paths or nonportable drive paths with CJK directory names.
# Generic Program Files examples are not treated as personal information.
PERSONAL_PATH = re.compile(r"(?<![A-Za-z])[A-Za-z]:[\\/](?:Users[\\/][^\s/\\]+|[^\s\"<>]*[\u4e00-\u9fff][^\s\"<>]*)|/(?:Users|home)/[A-Za-z0-9_.-]+/")
ABSOLUTE_RUNTIME_PATH = re.compile(r"[\"'][A-Za-z]:[\\/][^\"'\r\n]+[\"']")
RESOURCE_LITERAL = re.compile(r"[\"']\*?(res://[^\"'\r\n]+)[\"']")
MARKDOWN_LINK = re.compile(r"!?\[[^\]]*\]\(\s*(<[^>]+>|[^\s)]+)(?:\s+[\"'][^\n]*?[\"'])?\s*\)")


def sha256(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def local_data_name(name: str) -> bool:
    return bool(name == "profile.json" or name.startswith("profile.json.") or name == "settings.cfg" or re.fullmatch(r"settings-test-.*\.cfg", name))


def allowed_path(relative: str) -> bool:
    p = PurePosixPath(relative)
    if p.is_absolute() or ".." in p.parts or "\\" in relative or ":" in relative or any(part in EXCLUDED_PARTS for part in p.parts):
        return False
    if p.name.startswith(".env") or local_data_name(p.name) or p.suffix.lower() in {".key", ".pfx", ".p12", ".log", ".tmp"}:
        return False
    if len(p.parts) == 1:
        return relative in ROOT_FILES
    return p.parts[0] in TREE_EXTENSIONS and (p.suffix.lower() in TREE_EXTENSIONS[p.parts[0]] or p.name == ".gdignore")


def linklike(path: Path) -> bool:
    """Reject Windows junctions/reparse points as well as ordinary symlinks."""
    attributes = getattr(path.lstat(), "st_file_attributes", 0)
    return path.is_symlink() or bool(attributes & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400))


def public_files(root: Path) -> tuple[list[str], list[str]]:
    """Return the explicit source allowlist and unsafe filesystem entries; never follow links."""
    files, unsafe = [], []
    for entry in sorted(root.iterdir(), key=lambda p: p.name):
        if entry.name in EXCLUDED_PARTS:
            continue
        if linklike(entry):
            unsafe.append(entry.name)
            continue
        if entry.is_file() and allowed_path(entry.name):
            files.append(entry.name)
        elif entry.is_dir() and entry.name in TREE_EXTENSIONS:
            for directory, dirs, names in os.walk(entry, followlinks=False):
                for name in list(dirs):
                    p = Path(directory) / name
                    if linklike(p) or name == ".git":
                        unsafe.append(p.relative_to(root).as_posix())
                        dirs.remove(name)
                    elif name in EXCLUDED_PARTS:
                        dirs.remove(name)
                for name in names:
                    p = Path(directory) / name
                    relative = p.relative_to(root).as_posix()
                    if linklike(p) or name == ".git":
                        unsafe.append(relative)
                    elif allowed_path(relative):
                        files.append(relative)
    return sorted(files), sorted(unsafe)


def git(root: Path, *args: str, input_data: bytes | None = None) -> bytes:
    result = subprocess.run(["git", "-C", str(root), *args], input=input_data, capture_output=True, timeout=90)
    if result.returncode:
        # stderr may contain a credential-bearing remote URL; never echo it.
        raise RuntimeError("Git inspection failed; inspect local Git configuration separately")
    return result.stdout


def is_git_root(root: Path) -> bool:
    if not (root / ".git").exists():
        return False
    try:
        return Path(git(root, "rev-parse", "--show-toplevel").decode().strip()).resolve() == root.resolve()
    except (OSError, RuntimeError):
        return False


def scan_secret(data: bytes) -> list[dict]:
    return [{"kind": name, "line": data[:match.start()].count(b"\n") + 1}
            for name, pattern in SECRET_PATTERNS.items() for match in pattern.finditer(data)]


def check_tree(root: Path, public_tree: bool = False, history: bool = False) -> dict:
    root = root.resolve()
    findings: list[dict] = []
    def add(code: str, severity: str, path: str, message: str, **details):
        findings.append({"code": code, "severity": severity, "path": path, "message": message, **details})

    files, unsafe = public_files(root)
    selected = set(files)
    for entry in root.iterdir():
        if entry.is_file() and entry.suffix.lower() in TEXT_EXTENSIONS and entry.name not in ROOT_FILES and not entry.name.startswith(".env") and not local_data_name(entry.name):
            add("unclassified_root_source", "error", entry.name, "New root source/document must be explicitly classified in the public allowlist")
    caseless: dict[str, str] = {}
    for name in files:
        folded = name.casefold()
        if folded in caseless:
            add("case_collision", "error", name, "Source filenames collide on case-insensitive platforms", other=caseless[folded])
        caseless[folded] = name
    for name in unsafe:
        add("unsafe_entry", "error", name, "Symlink or nested Git entry is not allowed in the public tree")
    for name in ["project.godot", ".godot-version", "README.md", "export_presets.cfg", "scenes/main.tscn", "scripts/ui/main.gd", "localization/strings.csv", "THIRD_PARTY_NOTICES.md"]:
        if name not in selected:
            add("required_file", "error", name, "Required project source file is missing")
    if not any(name in selected for name in ["LICENSE", "LICENSE.md", "LICENSE.txt"]):
        add("license_pending", "error" if public_tree else "warning", "LICENSE", "Root project license is not present; legal selection is a separate release decision")
    total_bytes = 0
    for name in files:
        p = root / name
        size = p.stat().st_size
        total_bytes += size
        if size > 100 * 1024 * 1024:
            add("oversized_file", "error", name, "File exceeds 100 MiB", bytes=size)
        elif size > 50 * 1024 * 1024:
            add("large_file", "warning", name, "File exceeds 50 MiB", bytes=size)
        data = p.read_bytes()
        for finding in scan_secret(data):
            add("secret_candidate", "error", name, "High-confidence credential pattern; value redacted", **finding)
        if p.suffix.lower() not in TEXT_EXTENSIONS and name not in ROOT_FILES:
            continue
        if b"\0" in data:
            continue
        text = data.decode("utf-8-sig", errors="replace")
        for index, line in enumerate(text.splitlines(), 1):
            if PERSONAL_PATH.search(line):
                add("personal_local_path", "error" if public_tree else "warning", name, "Personal absolute filesystem path; value redacted", line=index)
            if p.suffix in {".gd", ".tscn", ".tres", ".godot"} and not name.startswith("tests/") and ABSOLUTE_RUNTIME_PATH.search(line):
                add("absolute_runtime_dependency", "error", name, "Runtime source contains a quoted external drive path; value redacted", line=index)
        if name == "project.godot" or name.startswith(("scripts/", "scenes/")):
            for match in RESOURCE_LITERAL.finditer(text):
                resource = match.group(1)[6:]
                if "%" in resource:
                    continue  # Known dynamic music paths are checked explicitly below.
                normalized = PurePosixPath(resource)
                if ".." in normalized.parts or resource not in selected:
                    add("missing_resource", "error", name, "Literal Godot resource is absent from the source allowlist", target=resource, line=text[:match.start()].count("\n") + 1)
        if p.name.lower().startswith("readme") and p.suffix.lower() == ".md":
            # Ignore fenced examples; validate actual inline README links, with exact case.
            prose = re.sub(r"```.*?```", "", text, flags=re.S)
            for match in MARKDOWN_LINK.finditer(prose):
                link = match.group(1).strip("<>")
                if link.startswith("#"):
                    continue
                parsed = urlsplit(link)
                if parsed.scheme in {"http", "https", "mailto"}:
                    if parsed.scheme != "mailto" and (not parsed.hostname or re.search(r"(?:YOUR[_-](?:USER|OWNER)|OWNER/REPO|example\.com)", link, re.I)):
                        add("placeholder_public_link", "error", name, "README contains a placeholder or malformed public URL")
                    continue
                if parsed.scheme or link.startswith(("/", "\\")):
                    add("absolute_readme_link", "error", name, "README link is not portable; value redacted")
                    continue
                relative = (PurePosixPath(name).parent / unquote(parsed.path)).as_posix()
                # Normalize parent traversal without consulting case-insensitive filesystem lookup.
                target = os.path.normpath(relative).replace("\\", "/")
                if target.startswith("../") or (target not in selected and not any(f.startswith(target.rstrip("/") + "/") for f in files)):
                    add("missing_readme_target", "error", name, "README link target is absent from source package", target=target)

    for sector in ("yard", "foundry", "reactor"):
        for layer in ("bed", "rhythm", "boss"):
            name = f"assets/audio/music/{sector}_{layer}.ogg"
            if name not in selected:
                add("missing_music_layer", "error", name, "Dynamic adaptive-score resource is absent")
    version = None
    if (root / "project.godot").is_file():
        project = (root / "project.godot").read_text(encoding="utf-8-sig")
        found = re.search(r'^config/version="(\d+\.\d+\.\d+)"$', project, re.M)
        version = found.group(1) if found else None
        if version is None:
            add("project_version", "error", "project.godot", "Expected semantic project version")
        else:
            for name, pattern in [("export_presets.cfg", r'application/(?:file|product)_version="([^"]+)"')]:
                if (root / name).is_file():
                    values = re.findall(pattern, (root / name).read_text(encoding="utf-8-sig"))
                    if values != [version + ".0", version + ".0"]:
                        add("export_version", "error", name, "Windows metadata version disagrees with project version")
            for name in ("Play.cmd", "export_presets.cfg"):
                if (root / name).is_file():
                    launcher_text = (root / name).read_text(encoding="utf-8-sig")
                    versions = re.findall(r'windows-v(\d+\.\d+\.\d+)', launcher_text)
                    delegated = name == "Play.cmd" and "Play.ps1" in launcher_text and (root / "Play.ps1").is_file()
                    if any(v != version for v in versions) or (not versions and not delegated):
                        add("launch_version", "error", name, "Windows export/launcher folder disagrees with project version")
                    if delegated:
                        script = (root / "Play.ps1").read_text(encoding="utf-8-sig")
                        hardcoded = re.findall(r'windows-v(\d+\.\d+\.\d+)', script)
                        if any(v != version for v in hardcoded) or (not hardcoded and not ("project.godot" in script and "config/version=" in script)):
                            add("launch_version", "error", "Play.ps1", "Delegated launcher must derive or match the project version")
            if (root / "README.md").is_file():
                advertised = re.search(r'\bv(\d+\.\d+\.\d+)\b', (root / "README.md").read_text(encoding="utf-8-sig"))
                if advertised and advertised.group(1) != version:
                    add("readme_version", "error", "README.md", "First advertised release differs from project version")
        if (root / ".godot-version").is_file():
            engine = (root / ".godot-version").read_text().strip()
            if not re.fullmatch(r"4\.\d+\.\d+", engine):
                add("engine_version", "error", ".godot-version", "Expected stable Godot semantic version")
            elif f'"{engine.rsplit(".", 1)[0]}"' not in project:
                add("engine_feature_version", "error", "project.godot", "Godot major/minor feature version differs from pinned engine")
            if (root / "export_presets.cfg").is_file():
                templates = re.findall(r'export_templates/([^/]+)/', (root / "export_presets.cfg").read_text())
                if not templates or any(v != engine + ".stable" for v in templates):
                    add("template_version", "error", "export_presets.cfg", "Export templates differ from pinned engine")
    if (root / "localization/strings.csv").is_file():
        with (root / "localization/strings.csv").open(encoding="utf-8-sig", newline="") as stream:
            rows = list(csv.reader(stream))
        if not rows or not {"en", "zh_CN"}.issubset(rows[0]):
            add("translation_header", "error", "localization/strings.csv", "English and Simplified Chinese columns are required")
        seen = set()
        for index, row in enumerate(rows[1:], 2):
            if not row:
                continue
            if row[0] in seen or len(row) != len(rows[0]):
                add("translation_row", "error", "localization/strings.csv", "Duplicate key or mismatched translation column count", line=index)
            seen.add(row[0])

    checkout = is_git_root(root)
    history_report = {"status": "not_requested", "needs_clean_public_history": False}
    if checkout:
        tracked = git(root, "ls-files", "-z").decode("utf-8").split("\0")[:-1]
        for name in tracked:
            if not allowed_path(name):
                add("tracked_outside_allowlist", "error", name, "Tracked file is outside the public source allowlist; classify it explicitly before packaging")
        # Gitlinks indicate a source dependency not included by this package policy.
        for row in git(root, "ls-files", "--stage").decode("utf-8").splitlines():
            if row.startswith("160000 "):
                add("git_submodule", "error", row.split("\t", 1)[-1], "Nested source dependency is not vendored in public package")
    if history and not public_tree:
        history_report = audit_history(root, findings) if checkout else {"status": "no_git_checkout", "needs_clean_public_history": False}
    report = {"schema": 1, "mode": "public_tree" if public_tree else "working_tree", "version": version,
              "git_checkout": checkout, "source_files": len(files), "source_bytes": total_bytes,
              "history": history_report, "findings": findings,
              "limits": "Known high-confidence credential formats only; values never printed. README local targets and URL syntax checked, not remote availability. Literal and known dynamic Godot resources checked, not arbitrary runtime expressions. License presence is not legal approval. No Git history is altered."}
    report["passed"] = not any(row["severity"] == "error" for row in findings)
    report["counts"] = {kind: sum(row["severity"] == kind for row in findings) for kind in ("error", "warning")}
    return report


def audit_history(root: Path, findings: list[dict]) -> dict:
    objects = git(root, "rev-list", "--objects", "--all").decode("utf-8").splitlines()
    if not objects:
        return {"status": "inspected_reachable_history", "commits": 0, "blobs": 0, "identities_masked": [], "personal_path_blobs": [], "secret_candidates": 0, "large_blobs": [], "needs_clean_public_history": False}
    names = dict(row.split(" ", 1) if " " in row else (row, "") for row in objects)
    info = git(root, "cat-file", "--batch-check=%(objectname) %(objecttype) %(objectsize)", input_data=("\n".join(names) + "\n").encode()).decode().splitlines()
    personal_blobs, secrets, large, scanned = [], [], [], 0
    process = subprocess.Popen(["git", "-C", str(root), "cat-file", "--batch"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    try:
        for row in info:
            oid, kind, size_text = row.split()
            if kind != "blob":
                continue
            size = int(size_text)
            process.stdin.write((oid + "\n").encode())
            process.stdin.flush()
            process.stdout.readline()
            data = process.stdout.read(size)
            process.stdout.read(1)
            if len(data) != size:
                raise RuntimeError("Incomplete Git blob inspection")
            scanned += 1
            path = names[oid]
            secrets.extend({"path": path, "object": oid[:12], **item} for item in scan_secret(data))
            if b"\0" not in data and PERSONAL_PATH.search(data.decode("utf-8", errors="replace")):
                personal_blobs.append({"path": path, "object": oid[:12]})
            if size > 50 * 1024 * 1024:
                large.append({"path": path, "object": oid[:12], "bytes": size})
    finally:
        process.stdin.close()
        process.stdout.close()
        process.wait(timeout=15)
    identities = {}
    commits = git(root, "log", "--all", "--format=%aN%x00%aE%x00%cN%x00%cE").decode("utf-8").splitlines()
    for row in commits:
        fields = row.split("\0")
        for offset in (0, 2):
            name, email = fields[offset:offset + 2]
            anonymous = hashlib.sha256((name + "\0" + email).encode()).hexdigest()[:12]
            category = "github_noreply" if email.endswith("@users.noreply.github.com") else "personal_or_other_email"
            identities[anonymous] = category
    needs_clean = bool(personal_blobs or any(value != "github_noreply" for value in identities.values()))
    if needs_clean:
        findings.append({"code": "historical_personal_metadata", "severity": "warning", "path": ".git", "message": "Existing reachable history contains personal paths or non-noreply identities; use an explicitly approved clean public history", "needs_clean_public_history": True})
    for item in secrets:
        findings.append({"code": "historical_secret_candidate", "severity": "error", "message": "Reachable history contains a high-confidence credential pattern; value redacted", **item})
    for item in large:
        findings.append({"code": "historical_large_blob", "severity": "warning", "message": "Reachable history contains a blob over 50 MiB", **item})
    return {"status": "inspected_reachable_history", "commits": len(commits), "blobs": scanned,
            "identities_masked": [{"identity_hash": key, "email_category": value} for key, value in sorted(identities.items())],
            "personal_path_blobs": personal_blobs, "secret_candidates": len(secrets), "large_blobs": large,
            "needs_clean_public_history": needs_clean}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--json", type=Path, help="Write a machine-readable report; contents omit absolute root and sensitive values")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--public-tree", action="store_true", help="Strict current public files; no old history inspection")
    mode.add_argument("--history", action="store_true", help="Additionally inspect reachable Git history and masked identities")
    args = parser.parse_args()
    report = check_tree(args.root, public_tree=args.public_tree, history=args.history)
    rendered = json.dumps(report, ensure_ascii=False, indent=2)
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(rendered + "\n", encoding="utf-8")
    print(rendered)
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
