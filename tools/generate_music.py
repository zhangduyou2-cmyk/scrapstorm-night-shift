"""Compose the three original Night Shift scores, without recordings or paid services.

Python 3 + numpy/scipy/soundfile. All notes, orchestration and synthesis are editable
here. Each 32-bar score has four arranged sections and three phase-aligned layers.
Circular note tails and delays preserve a continuous loop; no copied music is used.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from scipy.signal import butter, sosfilt
import soundfile as sf

RATE = 32000
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/audio/music"
SCORES = {
    "yard": {"title": "Afterhours Salvage", "bpm": 112, "seed": 270901, "key": 38,
             "style": "industrial breakbeat", "roots": [0, -4, 3, -2],
             "lead": [[12, 15, 19, 22, 19, 15], [14, 17, 19, 14, 10, 12],
                      [19, 22, 24, 22, 19, 15], [17, 14, 10, 14, 12, 7]]},
    "foundry": {"title": "Pressure Circuit", "bpm": 128, "seed": 270902, "key": 42,
                "style": "mechanical techno", "roots": [0, -4, 3, -2],
                "lead": [[12, 12, 19, 15, 14, 12], [10, 14, 17, 19, 17, 14],
                         [15, 19, 22, 19, 15, 14], [14, 10, 7, 10, 14, 12]]},
    "reactor": {"title": "Neon Induction", "bpm": 104, "seed": 270903, "key": 36,
                "style": "synthwave electro", "roots": [0, -4, 3, -2],
                "lead": [[24, 19, 22, 27, 26, 24], [22, 19, 15, 17, 19, 22],
                         [27, 26, 24, 22, 19, 15], [17, 19, 22, 19, 14, 12]]},
}


def hz(note: float) -> float:
    return 440.0 * 2.0 ** ((note - 69.0) / 12.0)


def voice(note: float, seconds: float, kind: str, rng: np.random.Generator) -> np.ndarray:
    n = max(32, round(seconds * RATE))
    t = np.arange(n, dtype=np.float64) / RATE
    f = hz(note)
    phase = 2 * np.pi * f * t
    if kind == "pad":
        y = np.zeros(n)
        for harmonic in range(1, 8):
            for detune in (-0.0031, 0.0027):
                y += np.sin(phase * harmonic * (1 + detune) + harmonic * 0.3) / harmonic ** 1.65
        envelope = np.minimum(t / 0.19, 1) * np.minimum((seconds - t) / 0.7, 1)
        y *= envelope * (0.86 + 0.07 * np.sin(2 * np.pi * 0.27 * t)) / 2.8
    elif kind == "bass":
        y = np.sin(phase) * 0.86
        for h in range(2, 7):
            y += np.sin(phase * h) * 0.25 / h * np.exp(-t * (h * 2.4))
        y *= np.minimum(t / 0.006, 1) * np.minimum((seconds - t) / 0.045, 1)
        y *= (0.65 + 0.35 * np.exp(-t * 7))
    elif kind == "bell":
        y = np.sin(phase + 1.8 * np.sin(phase * 2.001) * np.exp(-t * 9))
        y *= np.minimum(t / 0.005, 1) * np.exp(-t * 5.4) * np.minimum((seconds - t) / 0.07, 1)
    else:
        vibrato = 0.027 * np.sin(2 * np.pi * 5.3 * t) * np.minimum(t / 0.15, 1)
        y = np.sin(phase + vibrato)
        y += 0.26 * np.sin(phase * 2 + vibrato) + 0.13 * np.sin(phase * 3)
        y += 0.07 * np.sin(phase * 5) * np.exp(-t * 7)
        attack = 0.018 if kind == "lead" else 0.004
        envelope = np.minimum(t / attack, 1) * np.minimum((seconds - t) / 0.09, 1)
        y *= envelope * (0.40 + 0.60 * np.exp(-t * (3.2 if kind == "lead" else 8.0))) / 1.35
    return y.astype(np.float32)


def drum(kind: str, rng: np.random.Generator) -> np.ndarray:
    duration = {"kick": .46, "snare": .23, "hat": .075, "open": .25, "metal": .31, "tom": .29}[kind]
    t = np.arange(round(duration * RATE)) / RATE
    noise = rng.uniform(-1, 1, len(t))
    hp = noise - sosfilt(butter(2, 3800, fs=RATE, output="sos"), noise)
    if kind == "kick":
        phase = 2 * np.pi * (48 * t + 88 * .031 * (1 - np.exp(-t / .031)))
        y = np.sin(phase) * np.exp(-t * 12) + hp * np.exp(-t * 190) * .16
    elif kind == "snare":
        body = np.sin(2 * np.pi * 184 * t) * .36 * np.exp(-t * 23)
        y = body + noise * .51 * np.exp(-t * 27) + hp * .3 * np.exp(-t * 65)
    elif kind in ("hat", "open"):
        y = hp * np.exp(-t * (65 if kind == "hat" else 19)) * .47
    elif kind == "tom":
        y = np.sin(2 * np.pi * (102 * t + 37 * .06 * (1 - np.exp(-t / .06)))) * np.exp(-t * 17)
    else:
        y = sum(np.sin(2 * np.pi * f * t) / (i + 2) for i, f in enumerate((531, 811, 1267, 1711)))
        y = y * np.exp(-t * 23) + hp * .14 * np.exp(-t * 47)
    y *= np.minimum(t / .0015, 1) * np.minimum((duration - t) / .015, 1)
    return y.astype(np.float32)


class Arrangement:
    def __init__(self, map_id: str, spec: dict):
        self.map_id, self.spec = map_id, spec
        self.beat = 60 / spec["bpm"]
        self.length = round(128 * self.beat * RATE)
        self.rng = np.random.default_rng(spec["seed"])
        self.stems = {name: np.zeros((self.length, 2), np.float32) for name in ("bed", "rhythm", "boss")}
        self.events = {name: [] for name in self.stems}
        self.drums = {name: drum(name, self.rng) for name in ("kick", "snare", "hat", "open", "metal", "tom")}

    def put(self, stem: str, beat: float, samples: np.ndarray, gain: float, pan: float = 0, tag: str = ""):
        if stem == "boss":
            gain *= [.82, 1.0, .62, 1.22][min(int(beat // 32), 3)]
        start = round(beat * self.beat * RATE) % self.length
        stereo = samples[:, None] * np.array([np.sqrt((1-pan)/2), np.sqrt((1+pan)/2)], np.float32) * gain
        first = min(len(stereo), self.length - start)
        self.stems[stem][start:start+first] += stereo[:first]
        if first < len(stereo):
            self.stems[stem][:len(stereo)-first] += stereo[first:]
        self.events[stem].append((round(beat, 4), tag))

    def note(self, stem: str, beat: float, note: float, beats: float, kind: str, gain: float, pan: float = 0):
        self.put(stem, beat, voice(note, beats * self.beat + (.45 if kind == "pad" else .08), kind, self.rng), gain, pan, f"{kind}:{note}")

    def hit(self, stem: str, beat: float, kind: str, gain: float, pan: float = 0):
        self.put(stem, beat, self.drums[kind], gain, pan, kind)

    def arrange(self):
        key = self.spec["key"]
        for bar in range(32):
            section, local = divmod(bar, 8)
            phrase = local // 2
            chord_root = key + self.spec["roots"][phrase]
            # i9 / VImaj7 / IIImaj7 / VIIadd9, with close upper inversions.
            intervals = ([0, 3, 7, 14], [0, 4, 7, 11], [0, 4, 7, 11], [0, 4, 7, 14])[phrase]
            base = bar * 4
            if local % 2 == 0:
                for ci, interval in enumerate(intervals):
                    self.note("bed", base, chord_root + 24 + interval, 8, "pad", .070 if self.map_id != "reactor" else .095, (ci - 1.5) * .35)
            motif = self.spec["lead"][phrase]
            # The lead moves through a statement, answer, airy breakdown, final lift.
            if section != 2 or local >= 4:
                lead_times = [0, .75, 1.5, 2.5, 3.25, 3.75] if self.map_id == "yard" else [0, .5, 1.5, 2, 2.75, 3.5]
                if self.map_id == "reactor":
                    lead_times = [0, .75, 1.75, 2.5, 3, 3.5]
                for idx, offset in enumerate(lead_times):
                    if section == 0 and ((local % 2 == 1 and idx > 2) or idx == 5):
                        continue
                    transpose = 12 if section == 3 and local in (2, 6) else 0
                    chosen = motif[idx] if local % 2 == 0 else motif[(idx + 3) % 6]
                    self.note("bed", base + offset, key + 12 + chosen + transpose, .56 if idx == 0 else .33,
                              "bell" if self.map_id == "yard" else "lead", .085 if section != 2 else .050, -.14)
            if self.map_id == "reactor" or section in (1, 3):
                for step in range(8):
                    pitch = chord_root + 24 + intervals[(step + local) % 4]
                    self.note("bed", base + step * .5 + .25, pitch, .22, "arp", .028 if section != 2 else .015, .4)
            bass_pattern = {
                "yard": [(0, .70, 0), (1.5, .35, 0), (2.25, .45, 7), (3.25, .35, 0)],
                "foundry": [(.5, .32, 0), (1.5, .32, 0), (2.5, .32, 12), (3.25, .24, 7), (3.5, .30, 0)],
                "reactor": [(0, .65, 0), (.75, .40, 12), (1.5, .42, 0), (2, .65, 0), (3, .42, 7), (3.5, .3, 12)],
            }[self.map_id]
            for offset, length, interval in bass_pattern:
                if section == 2 and local < 4 and offset not in (0, .5, 2, 2.5):
                    continue
                self.note("rhythm", base + offset, chord_root + interval, length, "bass", .26)
            kicks = {"yard": [0, 1.5, 2.75] if local % 2 == 0 else [0, .75, 2.5, 3.75],
                     "foundry": [0, 1, 2, 3], "reactor": [0, 1.75, 2, 3.5]}[self.map_id]
            if section == 2 and local < 4:
                kicks = [0, 2] if local % 2 == 0 else [0]
            for beat in kicks:
                self.hit("rhythm", base + beat, "kick", .53)
            for beat in [1, 3]:
                self.hit("rhythm", base + beat, "snare", .30 if section != 2 else .14, .08)
            for step in range(8 if section != 3 else 16):
                if section == 2 and step % 2 == 1:
                    continue
                spacing = .5 if section != 3 else .25
                self.hit("rhythm", base + step * spacing + (.045 if self.map_id == "yard" and step % 2 else 0),
                         "hat", .14 if step % 2 else .10, -.32 if step % 2 else .3)
            if section in (1, 3):
                self.hit("rhythm", base + 2.5, "open", .13, .5)
                self.hit("rhythm", base + 3.25, "metal", .10, -.6)
            if local == 7:
                for step in range(4):
                    self.hit("rhythm", base + 3 + step * .25, "tom" if step % 2 else "snare", .17 + step * .02, (step-1.5)*.25)
            # A synchronized extra rhythm/ostinato layer is audible only in boss context.
            for step in range(8):
                self.note("boss", base + step * .5, chord_root + 12 + intervals[step % 4], .21, "arp", .065, (-1 if step % 2 else 1) * .28)
            for beat in [0, 2]:
                self.hit("boss", base + beat, "tom", .16, -.15)
            for beat in [.75, 1.75, 2.75, 3.5]:
                self.hit("boss", base + beat, "metal", .13, .3)
            if local in (3, 7):
                for beat in [2.75, 3, 3.25, 3.5, 3.75]:
                    self.hit("boss", base + beat, "snare", .1 + (beat-2.75)*.09, -.15)
        # Circular stereo delays and short room reflections, with no tail truncation.
        bed = self.stems["bed"]
        dry = bed.copy()
        for beats, gain in [(0.75, .25), (1.5, .12), (2.25, .065)]:
            bed += np.roll(dry[:, ::-1], round(beats * self.beat * RATE), axis=0) * gain
        for name in ("bed", "rhythm", "boss"):
            y = self.stems[name]
            dry = y.copy()
            for secs, gain in ((.071, .055), (.103, .041), (.139, .028)):
                y += np.roll(dry[:, ::-1], round(secs * RATE), axis=0) * gain
            # Keep pitched material audible against the drums, including the
            # boss ostinato. Shared peak control below preserves this balance.
            y *= {"bed": 1.85, "rhythm": .85, "boss": 2.9}[name]
            y -= np.mean(y, axis=0, keepdims=True)
            self.stems[name] = (np.tanh(y * 1.12) / 1.12).astype(np.float32)
        combined = sum(self.stems.values())
        gain = min(.78 / float(np.max(np.abs(combined))), 1.8)
        for name in self.stems:
            self.stems[name] *= gain

    def export(self) -> dict:
        self.arrange()
        report = {k: self.spec[k] for k in ("title", "bpm", "seed", "style")}
        report.update({"bars": 32, "section_bars": 8, "sample_rate": RATE, "channels": 2,
                       "duration_seconds": self.length / RATE, "section_names": ["statement", "drive", "breakdown", "final_lift"], "layers": {}})
        for name, audio in self.stems.items():
            path = OUT / f"{self.map_id}_{name}.ogg"
            # libsndfile's Windows Vorbis writer needs bounded write blocks; a
            # whole multi-minute buffer can overflow its native thread stack.
            with sf.SoundFile(path, "w", samplerate=RATE, channels=2, format="OGG", subtype="VORBIS") as target:
                for offset in range(0, len(audio), 8192):
                    target.write(audio[offset:offset + 8192])
            decoded, rate = sf.read(path, dtype="float32", always_2d=True)
            rms = float(np.sqrt(np.mean(decoded ** 2)))
            sections = np.array_split(decoded, 4)
            report["layers"][name] = {
                "file": path.relative_to(ROOT).as_posix(), "bytes": path.stat().st_size,
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "frames": len(decoded),
                "peak_dbfs": round(20 * np.log10(float(np.max(np.abs(decoded))) + 1e-12), 3),
                "rms_dbfs": round(20 * np.log10(rms + 1e-12), 3),
                "section_rms_dbfs": [round(20 * np.log10(float(np.sqrt(np.mean(part ** 2)))) + 1e-12, 3) for part in sections],
                "boundary_step": round(float(np.max(np.abs(decoded[0] - decoded[-1]))), 6),
                "dc_offset": round(float(np.mean(decoded)), 7), "events": len(self.events[name]),
                "section_event_counts": [sum(section * 32 <= event[0] < (section+1)*32 for event in self.events[name]) for section in range(4)],
            }
            # Godot supports looping Ogg streams; keep import policy in source control.
            import_path = path.with_suffix(".ogg.import")
            if import_path.exists():
                content = import_path.read_text(encoding="utf-8")
                content = content.replace("loop=false", "loop=true")
                import_path.write_text(content, encoding="utf-8")
        combined = sum(self.stems.values())
        report["combined_peak_dbfs"] = round(20 * np.log10(float(np.max(np.abs(combined)))), 3)
        report["measurement_note"] = "RMS dBFS is signal energy, not perceptual LUFS or a human listening approval."
        print(json.dumps({"map": self.map_id, "duration": report["duration_seconds"], "peak": report["combined_peak_dbfs"]}))
        return report


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {"format": 1, "created": "2026-09-07", "source": "tools/generate_music.py",
                "provenance": "Original AI-assisted composition and oscillator/noise synthesis by OpenAI Codex. No recordings, downloaded music or paid services.",
                "tracks": {map_id: Arrangement(map_id, spec).export() for map_id, spec in SCORES.items()}}
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
