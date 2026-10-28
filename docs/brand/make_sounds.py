#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = ["numpy>=2"]
# ///
"""Make the reminder sounds of Maru Pro (D112): uv run docs/brand/make_sounds.py

Each sound is synthesized here from sine waves, with no recording and no sample, so Maru owns it. The sounds are short
and soft: chimes, plucks, and bells, never an alarm. A second run gives the same files.

It writes App/Sounds/maru-<name>.caf: 16-bit linear PCM, 44.1 kHz, mono. iOS plays a notification sound from the app
bundle when it is shorter than 30 seconds and in this format. Needs `afconvert`, which macOS has.
"""

import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "App/Sounds"
RATE = 44100
PEAK = 0.7  # About -3 dBFS, so no sound is loud or clips.


def note(name):
    """The frequency of a note such as "A5", with A4 at 440 Hz."""
    steps = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    letter, accidental, octave = name[0], name[1:-1], int(name[-1])
    semitones = steps[letter] + (1 if accidental == "#" else 0) + 12 * (octave - 4)
    return 440.0 * 2 ** (semitones / 12)


def timeline(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def attack(t, seconds):
    """A raised-cosine fade-in, so a note starts with no click."""
    return np.where(t < seconds, 0.5 - 0.5 * np.cos(np.pi * np.clip(t / seconds, 0, 1)), 1.0)


def partials(freq, t, shape, hit=0.004):
    """A sum of partials. Each entry of `shape` is (frequency ratio, amplitude, decay time in seconds)."""
    sound = sum(amp * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t / decay) for ratio, amp, decay in shape)
    return sound * attack(t, hit)


def place(track, sound, at):
    start = int(at * RATE)
    end = min(len(track), start + len(sound))
    track[start:end] += sound[: end - start]


def dewdrop():
    """Two drops of water: a short sine with a small upward glide."""
    track = np.zeros(int(1.4 * RATE))
    for at, (low, high), amp in [(0.0, (1180, 1580), 1.0), (0.17, (1480, 1980), 0.55)]:
        t = timeline(0.9)
        glide = low + (high - low) * (1 - np.exp(-t / 0.025))
        phase = 2 * np.pi * np.cumsum(glide) / RATE
        drop = (np.sin(phase) + 0.08 * np.sin(2 * phase)) * np.exp(-t / 0.16) * attack(t, 0.003)
        place(track, amp * drop, at)
    return track


def petal():
    """Two soft mallet notes going up a fourth, as on a small marimba."""
    track = np.zeros(int(1.8 * RATE))
    mallet = [(1, 1.0, 0.45), (3.93, 0.12, 0.07), (9.2, 0.03, 0.02)]
    place(track, partials(note("E5"), timeline(1.6), mallet), 0.0)
    place(track, 0.9 * partials(note("A5"), timeline(1.6), mallet), 0.16)
    return track


def breeze():
    """Three slow sine notes going up, with a light vibrato."""
    track = np.zeros(int(2.6 * RATE))
    for i, name in enumerate(["D5", "F#5", "A5"]):
        t = timeline(2.1)
        freq = note(name) * (1 + 0.0015 * np.sin(2 * np.pi * 5 * t))
        phase = 2 * np.pi * np.cumsum(freq) / RATE
        tone = (np.sin(phase) + 0.12 * np.sin(2 * phase)) * np.exp(-t / 0.7) * attack(t, 0.04)
        place(track, 0.8 * tone, 0.22 * i)
    return track


def pebble():
    """Two small knocks of wood, the second one higher."""
    track = np.zeros(int(1.0 * RATE))
    knock = [(1, 1.0, 0.11), (2.76, 0.25, 0.04), (5.4, 0.06, 0.015)]
    place(track, partials(note("G5"), timeline(0.7), knock, hit=0.002), 0.0)
    place(track, 0.85 * partials(note("D6"), timeline(0.7), knock, hit=0.002), 0.13)
    return track


def sunrise():
    """A harp chord played up: C, E, G, and C."""
    track = np.zeros(int(2.6 * RATE))
    string = [(n, 1 / n ** 1.6, 1.1 / n ** 0.5) for n in range(1, 7)]
    for i, name in enumerate(["C5", "E5", "G5", "C6"]):
        place(track, 0.7 * partials(note(name), timeline(2.2), string, hit=0.003), 0.11 * i)
    return track


def lantern():
    """A soft bell that rings two notes going down a fourth: "ding-dong"."""
    track = np.zeros(int(3.0 * RATE))
    for at, name, amp in [(0.0, "A5", 1.0), (0.42, "E5", 0.85)]:
        t = timeline(2.5)
        carrier = note(name)
        # Frequency modulation with an inharmonic ratio gives the bell. The index falls, so the tone gets pure.
        index = 1.6 * np.exp(-t / 0.5)
        bell = np.sin(2 * np.pi * carrier * t + index * np.sin(2 * np.pi * carrier * 1.4 * t))
        place(track, amp * bell * np.exp(-t / 0.75) * attack(t, 0.004), at)
    return track


SOUNDS = {
    "dewdrop": dewdrop,
    "petal": petal,
    "breeze": breeze,
    "pebble": pebble,
    "sunrise": sunrise,
    "lantern": lantern,
}


def finish(track):
    """Scale to the peak, and fade the last 80 milliseconds to silence."""
    track = track / np.max(np.abs(track)) * PEAK
    fade = int(0.08 * RATE)
    track[-fade:] *= np.linspace(1, 0, fade)
    return np.round(track * 32767).astype("<i2")


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as folder:
        for name, make in SOUNDS.items():
            samples = finish(make())
            source = Path(folder) / f"{name}.wav"
            with wave.open(str(source), "wb") as file:
                file.setnchannels(1)
                file.setsampwidth(2)
                file.setframerate(RATE)
                file.writeframes(samples.tobytes())
            target = OUTPUT / f"maru-{name}.caf"
            subprocess.run(
                ["afconvert", "-f", "caff", "-d", f"LEI16@{RATE}", "-c", "1", str(source), str(target)], check=True
            )
            print(f"{target.relative_to(ROOT)}: {len(samples) / RATE:.1f} s")


if __name__ == "__main__":
    main()
