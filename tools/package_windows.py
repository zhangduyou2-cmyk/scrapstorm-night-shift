"""Package the versioned Windows export and verify an extracted copy by SHA-256."""
from __future__ import annotations

import json
import re
import tempfile
import zipfile
from pathlib import Path

from package_common import digest, validate_export_manifest

ROOT = Path(__file__).resolve().parents[1]
FILES = (
    "Scrapstorm.exe", "Scrapstorm.pck", "THIRD_PARTY_NOTICES.md",
    "FONT-LICENSE.txt", "RAJDHANI-LICENSE.txt", "GODOT_LICENSE.txt", "GODOT_COPYRIGHT.txt",
    "CREDITS.md", "PRIVACY.md", "README-PLAY.txt", "Play.cmd", "Play.ps1", "build-manifest.json",
)


def main() -> None:
    match = re.search(r'^config/version="(\d+\.\d+\.\d+)"$',
                      (ROOT / "project.godot").read_text(encoding="utf-8"), re.MULTILINE)
    if match is None:
        raise ValueError("Expected a semantic project version")
    version = match.group(1)
    source = ROOT / "exports" / f"windows-v{version}"
    files = FILES + (("LICENSE",) if (ROOT / "LICENSE").is_file() else ())
    for name in ("CREDITS.md", "PRIVACY.md", "README-PLAY.txt", "THIRD_PARTY_NOTICES.md", "Play.cmd", "Play.ps1") + (("LICENSE",) if "LICENSE" in files else ()):
        if digest(ROOT / name) != digest(source / name):
            raise ValueError(f"Distribution {name} is stale; rebuild before packaging")
    artifacts = ROOT / "artifacts"
    artifacts.mkdir(exist_ok=True)
    hashes = validate_export_manifest(source, version, files)
    destination = artifacts / f"Scrapstorm-Night-Shift-v{version}-Windows.zip"
    with tempfile.NamedTemporaryFile(dir=artifacts, suffix=".zip", delete=False) as temporary:
        temporary_path = Path(temporary.name)
    try:
        with zipfile.ZipFile(temporary_path, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            for name in files:
                info = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                archive.writestr(info, (source / name).read_bytes())
        extracted = Path(tempfile.mkdtemp(prefix=f"windows-v{version}-verified-", dir=artifacts))
        with zipfile.ZipFile(temporary_path) as archive:
            if archive.namelist() != list(files) or archive.testzip() is not None:
                raise ValueError("Archive contents or CRC validation failed")
            # Only this exact flat allowlist can be extracted into the newly created directory.
            for name in files:
                (extracted / name).write_bytes(archive.read(name))
        if {name: digest(extracted / name) for name in files} != hashes:
            raise ValueError("Extracted files differ from the export")
        temporary_path.replace(destination)
    finally:
        if temporary_path.exists():
            temporary_path.unlink()
    result = {
        "version": version, "files": hashes, "zip": str(destination),
        "zip_bytes": destination.stat().st_size, "zip_sha256": digest(destination),
        "extracted": str(extracted), "hashes_match": True, "crc_passed": True, "build_manifest_verified": True,
        "license_selected": "LICENSE" in files,
        "note": f"CRC and all {len(files)} extracted file hashes verified. Runtime startup and publication approval are separate checks.",
    }
    (artifacts / f"windows-v{version}-package.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
