"""Copy non-ignored source into a new directory, then install/test/export without local caches.

Requires Windows x64, Python 3.11+, Git and PowerShell 5.1+. The default downloads
the official pinned editor and templates (~1.37 GB). --archive-cache explicitly
reuses only archives; setup still checks both official hashes before extraction.
The directory and all failure evidence are retained for inspection.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
FORBIDDEN = {".git", ".godot", ".tools", ".preproduction-local", "artifacts", "captures", "exports", "__pycache__"}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive-cache", type=Path)
    parser.add_argument("--copy-only", action="store_true", help="Prepare source only; report does not claim validation")
    args = parser.parse_args()
    if sys.platform != "win32":
        parser.error("The supported reproduction target is Windows x64")
    files = subprocess.check_output(["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"], cwd=ROOT)
    paths = sorted(set(path for path in files.decode("utf-8").split("\0") if path))
    destination = Path(tempfile.mkdtemp(prefix="scrapstorm clean "))
    report = {"started_at_utc": datetime.now(timezone.utc).isoformat(), "source": str(ROOT),
              "destination": str(destination), "archive_cache": str(args.archive_cache) if args.archive_cache else None,
              "method": "Working-tree source snapshot, including non-ignored new files. No engine/import cache copied. Not a committed GitHub checkout or bit-for-bit build claim.",
              "source_files": [], "steps": [], "passed": False, "complete": False}
    artifacts = ROOT / "artifacts"
    artifacts.mkdir(exist_ok=True)
    report_path = artifacts / "clean-checkout-verification.json"

    def save():
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    save()
    try:
        for relative in paths:
            source = (ROOT / relative).resolve()
            if not source.is_relative_to(ROOT) or any(part in FORBIDDEN for part in Path(relative).parts):
                raise ValueError(f"Generated/private path in source selection: {relative}")
            if not source.is_file():
                continue # Working-tree deletions are intentionally absent.
            if (ROOT / relative).is_symlink():
                raise ValueError(f"Review symlink before source reproduction: {relative}")
            target = destination / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
            with target.open("rb") as stream:
                sha = hashlib.file_digest(stream, "sha256").hexdigest()
            report["source_files"].append({"path": relative, "sha256": sha, "bytes": target.stat().st_size})
        report["initial_cache_absent"] = not any((destination / name).exists() for name in FORBIDDEN)
        save()
        print(f"Clean source: {destination}", flush=True)
        if args.copy_only:
            return 0
        shell = shutil.which("powershell.exe")
        if not shell:
            raise RuntimeError("PowerShell 5.1+ is required")

        def step(name, command, timeout=2700):
            started = time.monotonic()
            print(f"[{name}] starting", flush=True)
            # pwsh's inherited module path cannot be reused by Windows PowerShell
            # through an intermediate Python process. Let that shell initialize its own.
            environment = {key: value for key, value in os.environ.items() if key.lower() != "psmodulepath"}
            process = subprocess.Popen(command, cwd=destination, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=environment)
            while True:
                try:
                    output, _ = process.communicate(timeout=15)
                    break
                except subprocess.TimeoutExpired:
                    elapsed = time.monotonic() - started
                    print(f"[{name}] running {elapsed:.0f}s", flush=True)
                    if elapsed > timeout:
                        subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], capture_output=True)
                        output, _ = process.communicate()
                        process.returncode = 124
                        break
            log = artifacts / f"clean-{name}.log"
            log.write_bytes(output)
            item = {"name": name, "exit": process.returncode, "seconds": round(time.monotonic() - started, 2), "log": str(log.relative_to(ROOT))}
            report["steps"].append(item)
            save()
            print(json.dumps(item), flush=True)
            if process.returncode != 0:
                raise RuntimeError(f"{name} failed; retained log: {log}")

        prefix = [shell, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File"]
        setup = prefix + ["tools/setup_godot.ps1", "-IncludeTemplates"]
        if args.archive_cache:
            setup += ["-DownloadDirectory", str(args.archive_cache.resolve())]
        step("setup", setup)
        step("tool-tests", [sys.executable, "-m", "unittest", "discover", "-s", "tools/tests", "-v"])
        step("regressions", [sys.executable, "tools/run_tests.py", "--label", "clean"], 1200)
        step("source-startup", prefix + ["Play.ps1", "-Smoke"], 120)
        step("exports", prefix + ["tools/build.ps1", "-Target", "All"], 900)
        report["regressions"] = json.loads((destination / "artifacts/clean-regressions.json").read_text(encoding="utf-8-sig"))
        report["installation"] = json.loads((destination / ".preproduction-local/godot-install.json").read_text(encoding="utf-8-sig"))
        report["exports"] = [json.loads(path.read_text(encoding="utf-8-sig")) for path in (destination / "exports").glob("*/build-manifest.json")]
        report["complete"] = True
        report["passed"] = report["regressions"]["passed"] and len(report["exports"]) == 2
    except Exception as error:
        report["error"] = str(error)
        print(str(error), file=sys.stderr)
    finally:
        report["finished_at_utc"] = datetime.now(timezone.utc).isoformat()
        save()
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
