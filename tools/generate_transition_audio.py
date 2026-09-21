"""Rebuild original, deterministic transition cues using only Python's standard library."""

from pathlib import Path
import math
import random
import struct
import wave


def build(kind, duration):
    rate = 24000
    rng = random.Random(4213)
    low_noise = 0.0
    samples = []
    for i in range(round(duration * rate)):
        t = i / rate
        noise = rng.uniform(-1, 1)
        low_noise += 0.09 * (noise - low_noise)
        attack = min(1.0, t / 0.008)
        release = min(1.0, (duration - t) / 0.08)
        if kind == "boss":
            # Damped ceramic modes above a low kiln-body knock; no sharp full-scale click.
            tone = sum(a * math.sin(2 * math.pi * f * t) * math.exp(-d * t)
                       for f, a, d in [(78, 0.45, 9), (213, 0.18, 14), (487, 0.09, 22)])
            sound = tone + low_noise * 0.7 * math.exp(-8 * t)
        else:
            # Air through an opening kiln, with a quiet low resonance and no rising whistle.
            envelope = math.sin(math.pi * t / duration) ** 1.4
            sound = envelope * (low_noise * 0.9 + math.sin(2 * math.pi * 64 * t) * 0.10)
        samples.append(round(max(-1, min(1, sound * attack * release)) * 32767))
    path = Path(__file__).resolve().parents[1] / "art" / "audio" / f"transition_{kind}.wav"
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(rate)
        output.writeframes(struct.pack(f"<{len(samples)}h", *samples))
    print(path)


if __name__ == "__main__":
    build("boss", 0.62)
    build("chapter", 0.68)
