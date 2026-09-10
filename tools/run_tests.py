"""Run isolated Godot regressions; import first and fail on missing results/errors."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
SUITES = [
    "scripts/game/test_world.gd",
    *[f"tests/{name}.gd" for name in (
        "test_app", "test_demo_app", "test_demo_world", "test_standard_app",
        "test_standard_world", "review_standard_release", "test_abilities",
        "test_loadout", "test_profile", "test_profile_v05", "test_audio",
        "test_hangar_ui", "test_v04_mechanics", "test_v04_integration",
        "test_v05_hangar", "test_v05_shop", "test_v05_arsenal",
        "test_v05_boss_support", "test_boss_counter_loop", "test_boss_world_b",
        "test_archive_ui", "test_overtime", "test_overtime_app", "test_overtime_review",
    )],
]
ERROR_PATTERN = re.compile(r"(?:SCRIPT ERROR|ERROR):|ObjectDB instances leaked|resources still in use")
COUNT_PATTERN = re.compile(r'"checks"\s*:\s*(\d+)|(?:TESTS?:?\s*)(\d+)\s+checks|(\d+)\s+checks')


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def summarize(output: str, code: int) -> tuple[int | None, bool]:
    counts = COUNT_PATTERN.findall(output)
    count = int(next(value for value in counts[-1] if value)) if counts else None
    # Some custom fixtures may print a failure array without push_error/exit(1).
    failure_result = False
    for line in output.splitlines():
        start = line.find("{")
        if start >= 0:
            try:
                data = json.loads(line[start:])
            except json.JSONDecodeError:
                continue
            if isinstance(data, dict) and (data.get("failures") or data.get("passed") is False):
                failure_result = True
    passed = code == 0 and count is not None and count > 0 and not ERROR_PATTERN.search(output) and not failure_result
    return count, bool(passed)


def execute(command: list[str], timeout: int) -> tuple[str, int]:
    try:
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                                encoding="utf-8", errors="replace", timeout=timeout)
        return result.stdout + result.stderr, result.returncode
    except subprocess.TimeoutExpired as error:
        def decode(value):
            return value.decode("utf-8", "replace") if isinstance(value, bytes) else value or ""
        return decode(error.stdout) + decode(error.stderr) + "\nPROCESS TIMEOUT\n", 124
    except OSError as error:
        return f"PROCESS START FAILED: {error}\n", 127


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", default="local")
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--timeout", type=int, default=120)
    parser.add_argument("suites", nargs="*")
    args = parser.parse_args()
    if not re.fullmatch(r"[a-z0-9_-]+", args.label):
        parser.error("label must be lowercase letters, numbers, underscores or hyphens")
    if args.timeout < 1:
        parser.error("timeout must be positive")
    version = (ROOT / ".godot-version").read_text(encoding="utf-8-sig").strip()
    engine = (args.godot or ROOT / f".tools/godot/Godot_v{version}-stable_win64_console.exe").resolve()
    suites = args.suites or SUITES
    for script in suites:
        path = (ROOT / script).resolve()
        if not path.is_relative_to(ROOT) or not path.is_file() or path.suffix != ".gd":
            parser.error(f"Missing or unsafe project test script: {script}")
    artifacts = ROOT / "artifacts"
    artifacts.mkdir(exist_ok=True)
    (artifacts / ".gdignore").touch()
    report = {
        "started_at_utc": datetime.now(timezone.utc).isoformat(),
        "python": sys.version.split()[0], "engine_path": str(engine),
        "expected_engine": version, "expected_suites": suites, "suites": [],
        "passed": False, "complete": False, "checks": 0,
        "method": "Headless behavior assertions, isolated --test-settings profiles. No screenshots, ordinary-input play or performance approval.",
    }
    report_path = artifacts / f"{args.label}-regressions.json"

    def save():
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    save()
    version_output, version_code = execute([str(engine), "--headless", "--version"], 30)
    report["engine_version"] = version_output.strip()
    if version_code or not version_output.strip().startswith(f"{version}.stable.official."):
        report["setup_error"] = f"Expected official Godot {version}. Run tools/setup_godot.ps1. Output: {version_output}"
        save()
        print(report["setup_error"], file=sys.stderr)
        return 1
    report["engine_sha256"] = digest(engine)
    gui = engine.with_name(engine.name.replace("_console.exe", ".exe"))
    if gui != engine and gui.is_file():
        report["engine_gui_sha256"] = digest(gui)
    node_modules = ROOT / "node_modules"
    if node_modules.is_dir():
        (node_modules / ".gdignore").touch()
    import_output, import_code = execute([str(engine), "--headless", "--path", str(ROOT), "--editor", "--import"], 300)
    import_log = artifacts / f"{args.label}-import.log"
    import_log.write_text(import_output, encoding="utf-8")
    report["import"] = {"exit": import_code, "log": str(import_log.relative_to(ROOT))}
    if import_code or ERROR_PATTERN.search(import_output):
        report["setup_error"] = "Godot import failed; no suites were skipped as success."
        save()
        print(import_output, file=sys.stderr)
        return 1
    for script in suites:
        started = time.monotonic()
        output, code = execute([str(engine), "--headless", "--path", str(ROOT), "--script", script,
                                "--", "--test-settings"], args.timeout)
        log = f"{args.label}-{Path(script).stem}.log"
        (artifacts / log).write_text(output, encoding="utf-8")
        count, passed = summarize(output, code)
        item = {"script": script, "script_sha256": digest(ROOT / script), "exit": code,
                "checks": count, "seconds": round(time.monotonic() - started, 3),
                "passed": passed, "log": f"artifacts/{log}"}
        report["suites"].append(item)
        report["checks"] += count or 0
        print(json.dumps(item, ensure_ascii=False), flush=True)
        save()
    report["complete"] = len(report["suites"]) == len(suites)
    report["passed"] = report["complete"] and all(row["passed"] for row in report["suites"])
    report["finished_at_utc"] = datetime.now(timezone.utc).isoformat()
    save()
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
