"""Synthesises the focus timer's chime (#137) into assets/sounds/chime.wav.

Two sine tones a fifth apart (E5, then B5 a moment later), each with a couple
of quiet overtones and a long exponential decay, so it sounds like a small
bell rather than a beep. Nothing sampled, nothing licensed.

    python3 tool/chime.py
"""

import math
import struct
import wave

RATE = 44100
LENGTH = 2.2
NOTES = [(0.0, 659.25), (0.18, 987.77)]  # (start in seconds, Hz)
OUT = "assets/sounds/chime.wav"


def sample(t: float) -> float:
    value = 0.0
    for start, freq in NOTES:
        if t < start:
            continue
        u = t - start
        attack = min(1.0, u / 0.012)
        env = attack * math.exp(-u * 2.6)
        value += env * (
            math.sin(2 * math.pi * freq * u)
            + 0.25 * math.sin(2 * math.pi * freq * 2.01 * u) * math.exp(-u * 3)
            + 0.08 * math.sin(2 * math.pi * freq * 3.02 * u) * math.exp(-u * 5)
        )
    return value


def main() -> None:
    frames = [sample(i / RATE) for i in range(int(RATE * LENGTH))]
    peak = max(abs(x) for x in frames)
    tail = int(RATE * 0.05)  # a last fade, so it never ends on a click
    with wave.open(OUT, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(
            b"".join(
                struct.pack(
                    "<h",
                    int(x / peak * 0.7 * 32767 * min(1, (len(frames) - i) / tail)),
                )
                for i, x in enumerate(frames)
            )
        )


if __name__ == "__main__":
    main()
