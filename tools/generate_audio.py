"""Rebuild the project's original synthetic effects using Python's standard library.

AI-assisted implementation: OpenAI Codex, 2026-09-07. No samples, music recordings,
third-party audio libraries, or paid services are used. Source-code / original-asset
public licensing remains a project-owner decision; this script grants no new license.
Run from any folder: python tools/generate_audio.py
"""

from __future__ import annotations

import math
import hashlib
import json
from pathlib import Path
import random
import struct
import wave


RATE = 22050
OUTPUT = Path(__file__).resolve().parents[1] / "assets" / "audio"


def chirp(t: float, duration: float, start: float, end: float) -> float:
    phase = 2 * math.pi * (start * t + (end - start) * t * t / (2 * duration))
    return math.sin(phase)


def envelope(t: float, duration: float, decay: float = 1.8) -> float:
    attack = min(1.0, t / 0.006)
    return attack * max(0.0, 1.0 - t / duration) ** decay


def synth(event: str, duration: float, seed: int) -> list[float]:
    rng = random.Random(seed)
    result: list[float] = []
    smoothed_noise = 0.0
    for frame in range(round(duration * RATE)):
        t = frame / RATE
        noise = rng.uniform(-1.0, 1.0)
        smoothed_noise += (noise - smoothed_noise) * 0.18
        value = 0.0
        if event == "ui":
            value = chirp(t, duration, 720, 1030) * envelope(t, duration, 2.0)
        elif event == "collect":
            value = (chirp(t, duration, 1300, 2000) + 0.22 * math.sin(2 * math.pi * 2700 * t)) * envelope(t, duration, 2.6)
        elif event == "blast":
            value = (0.8 * chirp(t, duration, 150, 38) + 0.65 * smoothed_noise + 0.12 * noise) * envelope(t, duration, 1.4)
        elif event == "hit":
            value = (0.5 * chirp(t, duration, 160, 60) + 0.35 * noise) * envelope(t, duration, 2.2)
        elif event == "dash":
            value = (0.7 * smoothed_noise + 0.17 * chirp(t, duration, 850, 200)) * envelope(t, duration, 1.3)
        elif event == "enemy_down":
            value = (0.5 * chirp(t, duration, 430, 150) + 0.35 * noise + 0.22 * math.sin(2 * math.pi * 1570 * t)) * envelope(t, duration, 3.0)
        elif event == "foam":
            # Soft pneumatic puff with rounded bubbles, below the pickup register.
            bubbles = 0.55 + 0.45 * math.sin(2 * math.pi * 24 * t) ** 2
            value = (0.85 * smoothed_noise + 0.24 * chirp(t, duration, 480, 170) * bubbles) * envelope(t, duration, 1.8)
        elif event == "arc":
            # Brief electrical crackle; the gate creates distinct little sparks.
            sparks = 0.35 + 0.65 * math.sin(2 * math.pi * 43 * t) ** 4
            value = (0.30 * chirp(t, duration, 1900, 540) + 0.28 * noise * sparks + 0.22 * smoothed_noise) * envelope(t, duration, 2.5)
        elif event == "warning":
            # Two stable, rounded pulses: recognition must not depend on variation.
            for begin in (0.0, 0.19):
                pulse_t = t - begin
                if 0 <= pulse_t < 0.16:
                    value += (math.sin(2 * math.pi * 740 * pulse_t) + 0.18 * math.sin(2 * math.pi * 1110 * pulse_t)) * envelope(pulse_t, 0.16, 1.2)
        elif event == "boss_charge":
            value = (0.65 * chirp(t, duration, 105, 320) + 0.24 * smoothed_noise) * envelope(t, duration, 0.8)
        elif event == "skill_pulse":
            # A low thrust, bright electrical rim, then a short second recoil.
            value = (0.85 * chirp(t, duration, 235, 62) + 0.17 * smoothed_noise) * envelope(t, duration, 1.7)
            value += 0.24 * chirp(t, duration, 1780, 560) * envelope(t, duration, 3.4)
            echo = t - 0.12
            if echo >= 0:
                value += 0.32 * chirp(echo, duration - 0.12, 185, 82) * envelope(echo, duration - 0.12, 2.8)
        elif event == "skill_singularity":
            # Falling carrier with an accelerating amplitude swirl and soft intake.
            swirl = 0.58 + 0.42 * math.sin(2 * math.pi * (5 * t + 13 * t * t)) ** 2
            value = (0.62 * chirp(t, duration, 470, 68) * swirl + 0.31 * smoothed_noise) * envelope(t, duration, 0.65)
            value += 0.13 * chirp(t, duration, 1100, 250) * envelope(t, duration, 1.6)
        elif event == "skill_overdrive":
            # Motor fundamental and harmonic rise under repeated mechanical ticks.
            motor = chirp(t, duration, 105, 365) + 0.27 * chirp(t, duration, 210, 730)
            ticks = 0.28 + 0.72 * math.sin(2 * math.pi * (15 * t + 16 * t * t)) ** 6
            value = (0.65 * motor + 0.20 * noise * ticks) * envelope(t, duration, 0.85)
        elif event == "singularity_burst":
            # Brief vacuum transient followed by a low collapse and upper rubble.
            value = (0.87 * chirp(t, duration, 108, 32) + 0.20 * smoothed_noise) * envelope(t, duration, 1.5)
            for begin, frequency in ((0.055, 860), (0.09, 1290), (0.145, 1780)):
                bit = t - begin
                if 0 <= bit < 0.19:
                    value += 0.11 * math.sin(2 * math.pi * frequency * bit) * envelope(bit, 0.19, 2.7)
        elif event == "skill_ready":
            # Two clean notes, deliberately distinct from the double danger pulse.
            for begin, frequency in ((0.0, 1174.66), (0.08, 1760.0)):
                note = t - begin
                if 0 <= note < 0.22:
                    value += (math.sin(2 * math.pi * frequency * note) + 0.10 * math.sin(4 * math.pi * frequency * note)) * envelope(note, 0.22, 1.8)
        elif event == "boss_break":
            # Inharmonic armor fracture, heavy body impact and a delayed plate fall.
            value = (0.64 * chirp(t, duration, 180, 48) + 0.36 * smoothed_noise) * envelope(t, duration, 1.8)
            for begin, frequencies, amount in ((0.0, (720, 1079, 1633), 0.23), (0.16, (430, 689, 1213), 0.15)):
                bit = t - begin
                if 0 <= bit < 0.33:
                    metal = sum(math.sin(2 * math.pi * frequency * bit) for frequency in frequencies) / 3.0
                    value += (metal + noise * 0.4) * amount * envelope(bit, 0.33, 2.8)
        elif event == "evolve":
            # A locking turbine sweep opens into a short original rising arpeggio.
            value = (0.18 * chirp(t, duration, 130, 460) + 0.10 * smoothed_noise) * envelope(t, duration, 0.9)
            for begin, frequency in ((0.035, 349.23), (0.16, 523.25), (0.285, 698.46), (0.41, 1046.50)):
                note = t - begin
                if 0 <= note < 0.42:
                    value += (math.sin(2 * math.pi * frequency * note) + 0.12 * math.sin(4 * math.pi * frequency * note)) * envelope(note, 0.42, 1.65)
        elif event == "install":
            # Two small latch impacts separated by a short servo movement.
            for begin, frequency in ((0.0, 620), (0.115, 370)):
                latch = t - begin
                if 0 <= latch < 0.115:
                    value += (0.60 * chirp(latch, 0.115, frequency, frequency * 0.55) + 0.24 * noise) * envelope(latch, 0.115, 2.5)
            value += 0.13 * chirp(t, duration, 220, 320) * envelope(t, duration, 1.8)
        else:
            melodies = {
                "start": [(0.0, 330), (0.11, 440), (0.22, 660)],
                "win": [(0.0, 392), (0.14, 523.25), (0.28, 659.25), (0.42, 783.99)],
                "lose": [(0.0, 330), (0.19, 261.63), (0.38, 196)],
                "unlock": [(0.0, 293.665), (0.12, 369.994), (0.24, 440), (0.39, 587.33)],
            }
            for begin, frequency in melodies[event]:
                note_t = t - begin
                note_duration = min(0.38, duration - begin)
                if 0 <= note_t < note_duration:
                    value += (math.sin(2 * math.pi * frequency * note_t) + 0.18 * math.sin(4 * math.pi * frequency * note_t)) * envelope(note_t, note_duration, 1.4)
        result.append(value)
    peak = max(abs(value) for value in result) or 1.0
    # Leave headroom before each event's additional runtime gain.
    return [value / peak * 0.65 for value in result]


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    durations = {
        "ui": 0.09, "start": 0.58, "collect": 0.12,
        "blast": 0.4, "hit": 0.2, "dash": 0.21,
        "enemy_down": 0.18, "win": 0.9, "lose": 0.85,
        # Append new events: the original nine keep their deterministic seeds.
        "foam": 0.27, "arc": 0.17,
        "warning": 0.39, "boss_charge": 0.54, "unlock": 0.98,
        # Append-only: v0.3's fourteen files retain seeds 17000 through 17013.
        "skill_pulse": 0.46, "skill_singularity": 0.78, "skill_overdrive": 0.66,
        "singularity_burst": 0.70, "skill_ready": 0.32,
        "boss_break": 0.64, "evolve": 0.92, "install": 0.29,
    }
    manifest = {"format": "PCM_S16LE mono 22050 Hz", "generator": "tools/generate_audio.py",
                "ai_assisted_by": "OpenAI Codex 2026-09-07", "public_reuse_license": "pending", "effects": {}}
    for index, (event, duration) in enumerate(durations.items()):
        samples = synth(event, duration, seed=17000 + index)
        pcm = b"".join(struct.pack("<h", round(value * 32767)) for value in samples)
        destination = OUTPUT / f"{event}.wav"
        with wave.open(str(destination), "wb") as audio:
            audio.setnchannels(1)
            audio.setsampwidth(2)
            audio.setframerate(RATE)
            audio.writeframes(pcm)
        integers = struct.unpack(f"<{len(samples)}h", pcm)
        measured = [value / 32768.0 for value in integers]
        manifest["effects"][event] = {
            "file": f"assets/audio/{event}.wav", "seed": 17000 + index,
            "frames": len(samples), "duration_seconds": len(samples) / RATE,
            "sha256": hashlib.sha256(destination.read_bytes()).hexdigest(),
            "peak": max(abs(value) for value in measured),
            "rms": math.sqrt(sum(value * value for value in measured) / len(measured)),
            "dc": sum(measured) / len(measured),
        }
        print(f"{destination.name}: {duration:.2f}s, {len(pcm) + 44} bytes")
    (OUTPUT / "sfx_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
