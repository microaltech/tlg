#!/usr/bin/env python3
"""Generator musik latar & efek suara bernuansa gamelan (prosedural, orisinal).

Butuh numpy dan ffmpeg (dengan libvorbis). Jalankan ulang setelah mengubah
komposisi:

    python3 tools/gen_audio.py

Hasil: assets/audio/*.ogg. Untuk memakai musik/suara buatan komposer, cukup
timpa file .ogg dengan nama yang sama.
"""

import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 32000
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
rng = np.random.default_rng(7)


# --- Instrumen ------------------------------------------------------------

def env_exp(n, decay, attack=0.002):
    t = np.arange(n) / SR
    e = np.exp(-t / decay)
    a = int(attack * SR)
    if a > 0:
        e[:a] *= np.linspace(0, 1, a)
    return e


def partials(f, dur, ratios, amps, decays, attack=0.002, beat=0.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for r, a, d in zip(ratios, amps, decays):
        tone = np.sin(2 * np.pi * f * r * t + rng.uniform(0, 6.28))
        if beat:
            # "Ombak": dua bilah yang sedikit berbeda nada menghasilkan getaran khas gamelan.
            tone = 0.5 * tone + 0.5 * np.sin(2 * np.pi * (f * r + beat) * t)
        out += a * tone * env_exp(n, d, attack)
    return out


def saron(f, dur=1.6):
    return partials(f, dur, [1, 2.76, 5.4, 8.93], [1, 0.35, 0.15, 0.06], [0.9, 0.35, 0.15, 0.08], beat=2.2)


def bonang(f, dur=1.0):
    return partials(f, dur, [1, 2.0, 3.01, 4.16], [1, 0.45, 0.2, 0.08], [0.55, 0.3, 0.15, 0.08], beat=1.5)


def gender(f, dur=2.5):
    return partials(f, dur, [1, 2.0, 3.9], [1, 0.2, 0.05], [1.4, 0.6, 0.3], attack=0.006, beat=1.0)


def gong(f=46.0, dur=7.0):
    g = partials(f, dur, [1, 2.0, 2.92, 4.1], [1, 0.5, 0.25, 0.1], [3.5, 2.0, 1.2, 0.6], attack=0.02, beat=0.7)
    return g * 1.4


def kempul(f=98.0, dur=3.0):
    return partials(f, dur, [1, 2.0, 2.9], [1, 0.4, 0.15], [1.4, 0.8, 0.4], attack=0.01, beat=1.1)


def kendang_low(dur=0.35):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 75 + 85 * np.exp(-t / 0.04)
    phase = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(phase) * env_exp(n, 0.12, 0.001) * 1.2


def kendang_high(dur=0.12):
    n = int(dur * SR)
    noise = rng.standard_normal(n)
    noise = np.convolve(noise, np.ones(7) / 7, mode="same")
    t = np.arange(n) / SR
    body = np.sin(2 * np.pi * 320 * t) + 0.4 * np.sin(2 * np.pi * 610 * t)
    return (0.35 * noise + 0.7 * body) * env_exp(n, 0.035, 0.0005) * 0.7


def suling(f, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.2 * t) * np.clip(t / 0.4, 0, 1)
    phase = 2 * np.pi * np.cumsum(f * vib) / SR
    tone = np.sin(phase) + 0.18 * np.sin(2 * phase) + 0.05 * np.sin(3 * phase)
    breath = np.convolve(rng.standard_normal(n), np.ones(12) / 12, mode="same") * 0.08
    e = np.minimum(1, t / 0.08) * np.minimum(1, (dur - t) / 0.15).clip(0, 1)
    return (tone + breath) * e * 0.5


def noise_burst(dur, decay, smooth=1):
    n = int(dur * SR)
    x = rng.standard_normal(n)
    if smooth > 1:
        x = np.convolve(x, np.ones(smooth) / smooth, mode="same")
    return x * env_exp(n, decay, 0.001)


# --- Tangga nada ----------------------------------------------------------

def scale(base, cents):
    return [base * 2 ** (c / 1200) for c in cents]


# Slendro (5 nada hampir sama jarak) dan pelog bem (nada 1 2 3 5 6).
SLENDRO = [0, 240, 480, 720, 960]
PELOG = [0, 120, 270, 670, 785]


def note(sc, degree):
    """Derajat 1..5; 6..10 = oktaf atas."""
    octave, idx = divmod(degree - 1, 5)
    return sc[idx] * 2 ** octave


# --- Mixer ----------------------------------------------------------------

class Track:
    def __init__(self, seconds):
        self.n = int(seconds * SR)
        self.buf = np.zeros(self.n + SR * 8)

    def add(self, at, sound, gain=1.0):
        i = int(at * SR)
        self.buf[i:i + len(sound)] += sound * gain

    def loop(self):
        """Lipat ekor gema ke awal supaya loop mulus tanpa jeda."""
        out = self.buf[:self.n].copy()
        tail = self.buf[self.n:]
        out[:len(tail)] += tail[:self.n]
        return out

    def once(self, extra=0.0):
        return self.buf[:self.n + int(extra * SR)]


def master(x, level=0.8):
    x = x - np.mean(x)
    peak = np.max(np.abs(x)) or 1
    x = np.tanh(1.3 * x / peak) / np.tanh(1.3)
    return x * level


def fade_end(x, seconds=0.03):
    n = min(len(x), int(seconds * SR))
    x = x.copy()
    x[-n:] *= np.linspace(1, 0, n)
    return x


def save(name, x, quality=4):
    os.makedirs(OUT, exist_ok=True)
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        path = tmp.name
    try:
        with wave.open(path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        dst = os.path.join(OUT, name + ".ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "libvorbis",
                        "-q:a", str(quality), dst], check=True)
    finally:
        os.remove(path)


# --- Musik ----------------------------------------------------------------

def gamelan_piece(balungan, sc, beat, gongans, kendang_pattern, bonang_mode="double",
                  suling_line=None, saron_gain=0.55, bonang_gain=0.3):
    """Satu putaran gending: balungan (melodi inti), bonang (hiasan), kenong,
    kempul, gong, dan kendang. Dimainkan `gongans` kali lalu di-loop."""
    beats = len(balungan)
    total = beats * gongans * beat
    tr = Track(total)
    for g in range(gongans):
        start = g * beats * beat
        for i, deg in enumerate(balungan):
            t = start + i * beat
            if deg:
                tr.add(t, saron(note(sc, deg) * 2), saron_gain)
                tr.add(t, gender(note(sc, deg)), 0.25)
                # Bonang mengisi di antara ketukan dengan nada balungan berikutnya.
                nxt = balungan[(i + 1) % beats] or deg
                if bonang_mode == "double":
                    tr.add(t + beat / 2, bonang(note(sc, nxt) * 4), bonang_gain)
                    tr.add(t + beat, bonang(note(sc, nxt) * 4), bonang_gain * 0.8)
                elif bonang_mode == "run":
                    for k in range(4):
                        d = [deg, nxt, deg, nxt][k]
                        tr.add(t + k * beat / 4, bonang(note(sc, d) * 4, 0.6), bonang_gain * (1 if k % 2 == 0 else 0.7))
            if i % 4 == 3:
                tr.add(t, kempul(note(sc, deg or 1) / 2), 0.5)
        tr.add(start + (beats - 1) * beat, gong(), 0.9)
        for j, hit in enumerate(kendang_pattern * (beats * 2 // len(kendang_pattern))):
            t = start + j * beat / 2
            if hit == "D":
                tr.add(t, kendang_low(), 0.55)
            elif hit == "t":
                tr.add(t, kendang_high(), 0.4)
        if suling_line:
            for t_rel, deg, dur in suling_line:
                tr.add(start + t_rel * beat, suling(note(sc, deg) * 4, dur * beat), 0.22)
    return tr.loop()


def music_city():
    sc = scale(262, SLENDRO)
    bal = [3, 2, 3, 1, 3, 2, 1, 5, 2, 3, 5, 3, 2, 1, 2, 1]
    suling_line = [(0, 3, 2), (2.5, 5, 1.5), (4, 6, 3), (8, 5, 2), (10, 3, 2), (12.5, 2, 3)]
    return master(gamelan_piece(bal, sc, 0.75, 3, ["D", "", "t", "", "", "t", "D", ""], "double",
                                suling_line), 0.7)


def music_palace():
    sc = scale(247, PELOG)
    bal = [1, 2, 3, 5, 3, 2, 1, 2, 3, 5, 6, 5, 3, 2, 3, 1]
    sl = [(0, 5, 3), (3.5, 6, 2), (6, 8, 4), (10, 6, 2), (12, 5, 3.5)]
    return master(gamelan_piece(bal, sc, 0.95, 2, ["", "", "t", "", "", "", "t", ""], "double", sl,
                                saron_gain=0.35, bonang_gain=0.18), 0.6)


def music_battle():
    sc = scale(196, SLENDRO)
    bal = [6, 5, 3, 2, 3, 5, 6, 6, 6, 5, 3, 5, 2, 3, 2, 1]
    return master(gamelan_piece(bal, sc, 0.42, 4, ["D", "t", "t", "D", "t", "D", "t", "t"], "run",
                                saron_gain=0.6, bonang_gain=0.32), 0.75)


# --- Efek suara -----------------------------------------------------------

def sfx_click():
    return master(kendang_high(0.08) * 0.6 + bonang(1400, 0.08) * 0.15, 0.5)


def sfx_coin():
    tr = Track(0.6)
    for i, f in enumerate([1900, 2400, 2100, 2700]):
        tr.add(i * 0.06, partials(f, 0.4, [1, 2.4, 3.8], [1, 0.4, 0.2], [0.18, 0.1, 0.05]), 0.6)
    return master(tr.once(), 0.6)


def sfx_grain():
    tr = Track(0.6)
    tr.add(0, noise_burst(0.35, 0.09, 6), 0.5)
    tr.add(0.05, kendang_low(0.3), 0.6)
    tr.add(0.12, saron(784, 0.5), 0.5)
    return master(tr.once(), 0.55)


def sfx_recruit():
    tr = Track(0.9)
    for i, t in enumerate([0, 0.14, 0.28]):
        tr.add(t, kendang_low(), 0.9)
    tr.add(0.42, kempul(130, 0.8), 0.7)
    tr.add(0.42, bonang(520, 0.5), 0.4)
    return master(tr.once(), 0.6)


def sfx_upgrade():
    sc = scale(523, SLENDRO)
    tr = Track(0.9)
    for i, d in enumerate([1, 2, 3, 5, 6]):
        tr.add(i * 0.07, bonang(note(sc, d), 0.6), 0.6)
    return master(tr.once(), 0.6)


def sfx_attack():
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    whoosh = np.convolve(rng.standard_normal(n), np.ones(20) / 20, mode="same")
    whoosh *= np.sin(np.pi * np.clip(t / 0.25, 0, 1)) * (t < 0.25)
    tr = Track(1.0)
    tr.add(0, whoosh, 1.0)
    tr.add(0.22, partials(820, 0.7, [1, 2.7, 4.1, 6.3], [1, 0.6, 0.4, 0.2], [0.25, 0.15, 0.1, 0.06]), 0.8)
    tr.add(0.22, noise_burst(0.15, 0.03), 0.6)
    tr.add(0.22, kendang_low(), 0.8)
    return master(tr.once(), 0.75)


def sfx_win():
    sc = scale(392, SLENDRO)
    tr = Track(2.6)
    tr.add(0, gong(55, 3.0), 0.7)
    for i, d in enumerate([1, 2, 3, 5, 6, 8]):
        tr.add(0.1 + i * 0.11, saron(note(sc, d), 1.2), 0.6)
    tr.add(0.85, saron(note(sc, 8), 1.6), 0.5)
    tr.add(0.85, saron(note(sc, 6), 1.6), 0.4)
    return master(tr.once(), 0.75)


def sfx_lose():
    sc = scale(220, PELOG)
    tr = Track(2.0)
    for i, d in enumerate([5, 3, 2, 1]):
        tr.add(i * 0.22, gender(note(sc, d), 1.3), 0.7)
    tr.add(0.9, kempul(70, 1.2), 0.6)
    return master(tr.once(), 0.65)


def sfx_heart():
    sc = scale(784, PELOG)
    tr = Track(1.2)
    for i, d in enumerate([1, 3, 5, 6]):
        tr.add(i * 0.09, partials(note(sc, d), 0.8, [1, 3.0], [1, 0.2], [0.35, 0.1], attack=0.004), 0.5)
    return master(tr.once(), 0.5)


def sfx_birth():
    sc = scale(1046, SLENDRO)
    tr = Track(1.8)
    for i, d in enumerate([1, 3, 5, 3, 6, 8]):
        tr.add(i * 0.1, partials(note(sc, d), 1.0, [1, 2.0, 3.0], [1, 0.3, 0.1], [0.4, 0.2, 0.1]), 0.45)
    tr.add(0.6, gender(note(sc, 1) / 2, 1.2), 0.4)
    return master(tr.once(), 0.6)


def sfx_promote():
    sc = scale(262, SLENDRO)
    tr = Track(3.5)
    tr.add(0, gong(48, 4.0), 1.0)
    for i, d in enumerate([1, 2, 3, 5, 6, 8, 9, 10]):
        tr.add(0.2 + i * 0.09, bonang(note(sc, d) * 2, 0.9), 0.5)
    tr.add(1.0, saron(note(sc, 6) * 2, 2.0), 0.6)
    tr.add(1.0, saron(note(sc, 8) * 2, 2.0), 0.6)
    return master(tr.once(), 0.8)


def sfx_error():
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    tone = np.sign(np.sin(2 * np.pi * 140 * t)) * 0.3 + np.sin(2 * np.pi * 70 * t)
    return master(tone * env_exp(n, 0.08, 0.003), 0.45)


def main():
    save("music_city", music_city(), 3)
    save("music_palace", music_palace(), 3)
    save("music_battle", music_battle(), 3)
    for name, fn in [("click", sfx_click), ("coin", sfx_coin), ("grain", sfx_grain),
                     ("recruit", sfx_recruit), ("upgrade", sfx_upgrade), ("attack", sfx_attack),
                     ("win", sfx_win), ("lose", sfx_lose), ("heart", sfx_heart), ("birth", sfx_birth),
                     ("promote", sfx_promote), ("error", sfx_error)]:
        save("sfx_" + name, fade_end(fn()))
    print("Audio ditulis ke", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
