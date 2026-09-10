"""Package only the Web export's runtime and notices; verify every extracted byte."""
from __future__ import annotations

import json
import re
import tempfile
import zipfile
from pathlib import Path

from package_common import digest, validate_export_manifest

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = (
    "index.html", "index.js", "index.wasm", "index.pck",
    "index.audio.position.worklet.js", "index.audio.worklet.js",
    "index.apple-touch-icon.png", "index.icon.png", "index.png",
)
NOTICES = (
    "THIRD_PARTY_NOTICES.md", "FONT-LICENSE.txt", "RAJDHANI-LICENSE.txt",
    "GODOT_LICENSE.txt", "GODOT_COPYRIGHT.txt",
    "CREDITS.md", "PRIVACY.md", "README-PLAY.txt", "build-manifest.json",
)


def main() -> None:
    match = re.search(r'^config/version="(\d+\.\d+\.\d+)"$', (ROOT / "project.godot").read_text(encoding="utf-8"), re.MULTILINE)
    if not match:
        raise ValueError("Expected a semantic project version")
    version = match.group(1)
    source = ROOT / "exports/web"
    files = RUNTIME + NOTICES + (("LICENSE",) if (ROOT / "LICENSE").is_file() else ())
    for name in ("CREDITS.md", "PRIVACY.md", "README-PLAY.txt", "THIRD_PARTY_NOTICES.md") + (("LICENSE",) if "LICENSE" in files else ()):
        if digest(ROOT / name) != digest(source / name):
            raise ValueError(f"Distribution {name} is stale; rebuild before packaging")
    hashes = validate_export_manifest(source, version, files)
    artifacts = ROOT / "artifacts"
    artifacts.mkdir(exist_ok=True)
    output = artifacts / f"Scrapstorm-Night-Shift-v{version}-Web.zip"
    with tempfile.NamedTemporaryFile(dir=artifacts, suffix=".zip", delete=False) as stream:
        temporary = Path(stream.name)
    try:
        with zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            for name in files:
                info = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                archive.writestr(info, (source / name).read_bytes())
        extracted = Path(tempfile.mkdtemp(prefix=f"web-v{version}-verified-", dir=artifacts))
        with zipfile.ZipFile(temporary) as archive:
            if archive.namelist() != list(files) or archive.testzip() is not None:
                raise ValueError("Web archive contents or CRC mismatch")
            for name in files:
                (extracted / name).write_bytes(archive.read(name))
        if hashes != {name: digest(extracted / name) for name in files}:
            raise ValueError("Web extracted files differ from the export")
        temporary.replace(output)
    finally:
        if temporary.exists():
            temporary.unlink()
    result = {
        "version": version, "zip": str(output), "zip_bytes": output.stat().st_size,
        "zip_sha256": digest(output), "files": hashes, "extracted": str(extracted),
        "hashes_match": True, "crc_passed": True, "build_manifest_verified": True, "license_selected": "LICENSE" in files,
        "scope": "Static Web folder ZIP only; no editor imports/source maps/saves. Serve over HTTP/HTTPS. Browser execution is a separate check.",
    }
    (artifacts / f"web-v{version}-package.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
