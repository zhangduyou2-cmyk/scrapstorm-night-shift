"""Create a deterministic allowlisted source ZIP and verify a clean extracted copy.

No Git history, local engines, caches, exports, screenshots or user saves are copied.
The default requires a passing strict public-tree check. --prepare permits ONLY a
missing root license for local review; it never permits secrets or personal paths.
License text presence is not legal approval, and this tool does not publish anything.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import tempfile
import zipfile

from check_repository import check_tree, public_files, sha256


def package(root: Path, output: Path, extract_to: Path | None = None, prepare: bool = False) -> dict:
    root, output = root.resolve(), output.resolve()
    checked = check_tree(root, public_tree=True)
    blockers = [item for item in checked["findings"] if item["severity"] == "error" and not (prepare and item["code"] == "license_pending")]
    if blockers:
        raise ValueError("Source packaging blocked: " + ", ".join(sorted({item["code"] for item in blockers})) )
    names, unsafe = public_files(root)
    if unsafe:
        raise ValueError("Unsafe source entries must be resolved explicitly before packaging")
    if output == root or (output.is_relative_to(root) and output.relative_to(root).as_posix() in names):
        raise ValueError("Output would replace a source input")
    if output.exists():
        raise ValueError("Output already exists; use a new path to preserve earlier evidence")
    if extract_to is not None:
        extract_to = extract_to.resolve()
        if extract_to.exists():
            raise ValueError("Extraction destination must be new; no directory will be overwritten or deleted")
        if extract_to == root or root.is_relative_to(extract_to):
            raise ValueError("Extraction destination cannot contain the source root")
    hashes = {name: sha256(root / name) for name in names}
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=output.parent, prefix="source-writing-", suffix=".zip", delete=False) as stream:
        temporary = Path(stream.name)
    try:
        with zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            for name in names:
                entry = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
                entry.compress_type = zipfile.ZIP_DEFLATED
                entry.create_system = 3
                entry.external_attr = 0o100644 << 16
                archive.writestr(entry, (root / name).read_bytes())
        if extract_to is None:
            extract_to = Path(tempfile.mkdtemp(prefix="source-verified-", dir=output.parent))
        else:
            extract_to.mkdir(parents=True)
        with zipfile.ZipFile(temporary) as archive:
            if archive.namelist() != names or archive.testzip() is not None:
                raise ValueError("Source archive member list or CRC mismatch")
            # Only members from our validated relative allowlist are written.
            # Do not use extractall() against arbitrary names.
            for name in names:
                destination = extract_to / name
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(archive.read(name))
        actual = {name: sha256(extract_to / name) for name in names}
        if hashes != actual or hashes != {name: sha256(root / name) for name in names}:
            raise ValueError("A source changed during packaging or the extracted bytes differ")
        clean_check = check_tree(extract_to, public_tree=True)
        clean_errors = [item for item in clean_check["findings"] if item["severity"] == "error" and not (prepare and item["code"] == "license_pending")]
        if clean_errors:
            raise ValueError("Clean extracted source check failed")
        temporary.replace(output)
    finally:
        # Remove only our own temporary file, never a caller-selected directory.
        if temporary.exists():
            temporary.unlink()
    return {"schema": 1, "version": checked["version"], "preparation_only": prepare,
            "public_tree_check_passed": checked["passed"], "clean_tree_check": clean_check,
            "zip_name": output.name, "zip_bytes": output.stat().st_size, "zip_sha256": sha256(output),
            "extracted_directory_name": extract_to.name, "files": hashes,
            "file_count": len(names), "hashes_match": True, "crc_passed": True,
            "excluded": ["Git history/metadata", "local engine/dependencies", "Godot caches", "exports/builds", "artifacts/captures", "user saves/credentials"],
            "limits": "Static source and byte verification only; deterministic ZIP bytes assume the same Python/zlib toolchain. Godot import/runtime/build and legal approval are separate. No local Git history was altered and nothing was published."}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path, required=True, help="New ZIP path; existing files are never overwritten")
    parser.add_argument("--extract-to", type=Path, help="New clean source directory, retained for import/build verification")
    parser.add_argument("--json", type=Path, help="Write per-file SHA-256 and clean-tree report")
    parser.add_argument("--prepare", action="store_true", help="Local preparation only: allow a missing root license, but no privacy/credential errors")
    args = parser.parse_args()
    result = package(args.root, args.output, args.extract_to, args.prepare)
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: result[key] for key in ("version", "preparation_only", "file_count", "zip_name", "zip_bytes", "zip_sha256", "extracted_directory_name", "hashes_match", "public_tree_check_passed")}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
