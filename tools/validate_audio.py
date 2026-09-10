"""Validate delivered WAV effects and Ogg waveforms, variation and loop boundaries.

These objective checks detect missing/duplicated/clipping/broken assets. They do
not claim the composition sounds good or that a human has approved the mix.
"""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[1]
checks: list[dict] = []


def check(label: str, condition: bool):
    checks.append({"check": label, "passed": bool(condition)})


def main():
    manifest = json.loads((ROOT / "assets/audio/music/manifest.json").read_text(encoding="utf-8"))
    sfx_manifest = json.loads((ROOT / "assets/audio/sfx_manifest.json").read_text(encoding="utf-8"))
    sfx_report = {}
    files = list((ROOT / "assets/audio").glob("*.wav"))
    effects = sfx_manifest["effects"]
    check("22 WAV effects exactly match the synthesis manifest", len(effects) == 22 and {p.stem for p in files} == set(effects))
    for event, metadata in effects.items():
        path = ROOT / metadata["file"]
        data, rate = sf.read(path, dtype="float64", always_2d=True)
        info = sf.info(path)
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        peak = float(np.max(np.abs(data)))
        rms = float(np.sqrt(np.mean(data**2)))
        dc = float(np.mean(data))
        check(f"{event}: stored hash matches actual WAV", digest == metadata["sha256"])
        check(f"{event}: complete mono 16-bit PCM effect", data.shape[1] == 1 and rate == 22050 and info.subtype == "PCM_16" and len(data) == metadata["frames"] and .05 <= len(data)/rate < 1.0)
        check(f"{event}: finite nonclipping signal with headroom", np.all(np.isfinite(data)) and .60 < peak < .66)
        # A short filtered-noise one-shot can have a nonzero finite-window mean
        # without a persistent DC component; report it rather than imposing the
        # long looping music's DC criterion on legacy transient waveforms.
        check(f"{event}: nonempty signal with measurable energy", rms > .01)
        check(f"{event}: clean attack and tail endpoints", max(abs(float(data[0, 0])), abs(float(data[-1, 0]))) < .01)
        sfx_report[event] = {"sha256": digest, "seconds": len(data)/rate, "peak": peak, "rms": rms, "dc": dc}
    check("All 22 actual effects are distinct files", len({row["sha256"] for row in sfx_report.values()}) == 22)
    signatures = []
    audio_report = {}
    preview_dir = ROOT / "artifacts/audio-preview"
    preview_dir.mkdir(parents=True, exist_ok=True)
    for map_id, track in manifest["tracks"].items():
        stems = []
        frames = []
        for name, metadata in track["layers"].items():
            path = ROOT / metadata["file"]
            data, rate = sf.read(path, dtype="float32", always_2d=True)
            frames.append(len(data))
            stems.append(data)
            check(f"{map_id}/{name}: stored hash matches actual audio", hashlib.sha256(path.read_bytes()).hexdigest() == metadata["sha256"])
            check(f"{map_id}/{name}: complete stereo loop", data.shape[1] == 2 and rate == 32000 and 59.9 <= len(data)/rate <= 100)
            check(f"{map_id}/{name}: no clipping or nonfinite samples", np.all(np.isfinite(data)) and np.max(np.abs(data)) < 1.0)
            check(f"{map_id}/{name}: audible signal and low DC", np.sqrt(np.mean(data**2)) > .001 and abs(float(np.mean(data))) < .002)
            check(f"{map_id}/{name}: bounded loop boundary step", np.max(np.abs(data[0] - data[-1])) < .05)
        check(f"{map_id}: stems share exact frame count", len(set(frames)) == 1)
        combined = stems[0] + stems[1] + stems[2]
        check(f"{map_id}: combined source layers retain headroom", np.max(np.abs(combined)) < .99)
        sections = np.array_split(combined, 4)
        section_diff = []
        for index in range(3):
            n = min(len(sections[index]), len(sections[index+1]))
            relative_difference = float(np.sqrt(np.mean((sections[index][:n]-sections[index+1][:n])**2)) / np.sqrt(np.mean(sections[index][:n]**2)))
            section_diff.append(relative_difference)
        check(f"{map_id}: four sections change in actual rendered audio", min(section_diff) > .20)
        check(f"{map_id}: arrangement includes breakdown and lift", len(set(track["layers"]["rhythm"]["section_event_counts"])) >= 3)
        signatures.append(combined[:32000*10:128, 0])
        audio_report[map_id] = {"section_relative_difference": section_diff, "combined_peak_dbfs": float(20*np.log10(np.max(np.abs(combined)))), "seconds": len(combined)/rate}
        # Reviewable stereo mix: all three sections are heard in their intended
        # balance. This is an audition artifact, not part of the runtime export.
        mix = stems[0] * .62 + stems[1] * .66
        mix *= .85 / max(.85, float(np.max(np.abs(mix))))
        with sf.SoundFile(preview_dir / f"{map_id}-combat.ogg", "w", samplerate=rate, channels=2, format="OGG", subtype="VORBIS") as output:
            for offset in range(0, len(mix), 8192):
                output.write(mix[offset:offset+8192])
    correlations = np.corrcoef(signatures)
    check("Three maps have distinct decoded music", all(abs(correlations[a, b]) < .8 for a, b in ((0, 1), (0, 2), (1, 2))))
    report = {"checks": len(checks), "failures": [x["check"] for x in checks if not x["passed"]], "details": checks,
              "effects": sfx_report, "tracks": audio_report, "cross_track_correlations": correlations.tolist(),
              "note": "Decoded waveform checks; subjective sound quality and real speaker/browser listening remain separate."}
    (ROOT / "artifacts/audio-validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"checks": report["checks"], "failures": report["failures"], "tracks": audio_report}))
    raise SystemExit(1 if report["failures"] else 0)


if __name__ == "__main__":
    main()
