#!/usr/bin/env python3
"""Synthesise the completion sound. Pure stdlib so it runs anywhere:

    python3 scripts/make_sounds.py

Writes Today/Resources/complete.wav — a short, soft marimba-like "dink" with a
tiny low thump underneath. Tweak the numbers, re-run, rebuild.
"""
import math
import os
import struct
import wave

SR = 48_000
OUT = os.path.join(os.path.dirname(__file__), "..", "Today", "Resources", "complete.wav")


def complete_sound():
    duration = 0.30
    fundamental = 740.0  # F#5
    # (frequency ratio, amplitude, decay time constant in seconds)
    partials = [(1.0, 1.0, 0.060), (2.005, 0.30, 0.040), (3.76, 0.10, 0.025)]
    thump_freq, thump_amp, thump_tau = 185.0, 0.55, 0.022

    samples = []
    for i in range(int(SR * duration)):
        t = i / SR
        attack = min(1.0, t / 0.0015)
        s = 0.0
        for ratio, amp, tau in partials:
            s += amp * math.exp(-t / tau) * math.sin(2 * math.pi * fundamental * ratio * t)
        s += thump_amp * math.exp(-t / thump_tau) * math.sin(2 * math.pi * thump_freq * (1.0 - 0.3 * t) * t)
        samples.append(attack * s)

    peak = max(abs(x) for x in samples)
    return [x / peak * 0.45 for x in samples]


def write_wav(path, samples):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(x * 32767)) for x in samples))


if __name__ == "__main__":
    write_wav(OUT, complete_sound())
    print("wrote", os.path.normpath(OUT))
