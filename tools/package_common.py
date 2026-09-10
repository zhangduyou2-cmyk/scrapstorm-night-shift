"""Validate flat export members against the build manifest before any archive is published."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def flat_name(value: object) -> bool:
    return isinstance(value, str) and bool(value) and value not in {".", ".."} and not any(character in value for character in ("/", "\\", ":", "\0"))


def validate_export_manifest(source: Path, version: str, members: tuple[str, ...]) -> dict[str, str]:
    """Return a verified hash snapshot of package members, including the manifest.

    The export manifest may describe extra generated files (e.g. Godot .import
    descriptors) excluded by a package's allowlist. Those are not claimed as ZIP
    members. Every actual member except the manifest itself must have exactly one
    well-formed entry matching the real bytes and SHA-256.
    """
    if len(members) != len(set(members)) or not all(flat_name(name) for name in members):
        raise ValueError("Package member allowlist must contain unique flat filenames")
    if "build-manifest.json" not in members:
        raise ValueError("Package allowlist must include its build manifest")
    raw = (source / "build-manifest.json").read_bytes()
    try:
        manifest = json.loads(raw.decode("utf-8-sig"))
    except (UnicodeError, json.JSONDecodeError) as error:
        raise ValueError("Build manifest must be valid UTF-8 JSON") from error
    if not isinstance(manifest, dict) or manifest.get("project_version") != version:
        raise ValueError("Build manifest project version is stale; rebuild before packaging")
    rows = manifest.get("files")
    if not isinstance(rows, list):
        raise ValueError("Build manifest files must be an array")
    entries: dict[str, dict] = {}
    for row in rows:
        if not isinstance(row, dict) or not flat_name(row.get("name")):
            raise ValueError("Build manifest contains an invalid filename")
        name = row["name"]
        if name == "build-manifest.json" or name in entries:
            raise ValueError("Build manifest contains a duplicate or self-referential member")
        if type(row.get("bytes")) is not int or row["bytes"] < 0:
            raise ValueError("Build manifest file sizes must be non-negative integers")
        if not isinstance(row.get("sha256"), str) or not re.fullmatch(r"[0-9a-fA-F]{64}", row["sha256"]):
            raise ValueError("Build manifest contains an invalid SHA-256")
        entries[name] = row
    hashes = {"build-manifest.json": hashlib.sha256(raw).hexdigest()}
    for name in members:
        if name == "build-manifest.json":
            continue
        row = entries.get(name)
        if row is None:
            raise ValueError(f"Build manifest omits required package member: {name}")
        path = source / name
        actual = digest(path)
        if path.stat().st_size != row["bytes"] or actual != row["sha256"].lower():
            raise ValueError(f"Build manifest differs from exported member: {name}; rebuild before packaging")
        hashes[name] = actual
    return {name: hashes[name] for name in members}
