#!/usr/bin/env python3
"""Original audio for Snowboard Legends 3D, synthesised from scratch (numpy): SFX (.wav) and 11 looping music
tracks (.ogg via ffmpeg/libvorbis). Deterministic. No samples, no third-party material."""
import os, subprocess, math
import numpy as np
import wave

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SFX = os.path.join(ROOT, "assets", "audio", "sfx")
MUS = os.path.join(ROOT, "assets", "audio", "music")
SRC = os.path.join(ROOT, "source_art", "audio")
for d in (SFX, MUS, SRC):
    os.makedirs(d, exist_ok=True)
SR = 22050
rng = np.random.default_rng(7)


def t_(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, a=0.005, d=0.1, s=0.6, r=0.1, dur=None):
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    s_n = max(0, n - a_n - d_n - r_n)
    e = np.concatenate([np.linspace(0, 1, max(1, a_n)), np.linspace(1, s, max(1, d_n)), np.full(s_n, s), np.linspace(s, 0, max(1, r_n))])
    return e[:n] if len(e) >= n else np.pad(e, (0, n - len(e)))


def noise(n):
    return rng.uniform(-1, 1, n)


def lp(x, a):
    y = np.empty_like(x); acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc); y[i] = acc
    return y


def lp_fast(x, cutoff):
    # one-pole low-pass via FFT shaping (fast, smooth)
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1 / np.sqrt(1 + (f / cutoff) ** 4)
    return np.fft.irfft(X, len(x))


def hp_fast(x, cutoff):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1 / np.sqrt(1 + (cutoff / np.maximum(f, 1)) ** 4)
    return np.fft.irfft(X, len(x))


def osc(freq, dur, kind="sine", phase=0.0):
    t = t_(dur)
    f = np.broadcast_to(freq, t.shape) if np.ndim(freq) else np.full(t.shape, freq)
    ph = 2 * np.pi * np.cumsum(f) / SR + phase
    if kind == "sine":
        return np.sin(ph)
    if kind == "square":
        return np.sign(np.sin(ph)) * 0.6
    if kind == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1.0) - 1
    if kind == "tri":
        return 2 * np.abs(2 * ((ph / (2 * np.pi)) % 1.0) - 1) - 1
    if kind == "pulse":
        return np.where(((ph / (2 * np.pi)) % 1.0) < 0.25, 0.7, -0.7)


def write_wav(path, x, sr=SR):
    x = np.clip(x, -1, 1)
    data = (x * 32000).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr); w.writeframes(data.tobytes())


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def sfx(name, x):
    write_wav(os.path.join(SFX, name + ".wav"), norm(x))


def make_sfx():
    n = lambda d: int(SR * d)
    # loops (2 s, crossfaded ends so they loop cleanly)
    def loopify(x, xf=0.15):
        k = int(xf * SR); y = x.copy()
        y[:k] = y[:k] * np.linspace(0, 1, k) + x[-k:] * np.linspace(1, 0, k)
        return y[:-k]
    sfx("wind_loop", loopify(lp_fast(noise(n(2.2)), 700) * (0.8 + 0.2 * np.sin(t_(2.2) * 2 * np.pi * 0.9))))
    sfx("carve_loop", loopify(hp_fast(lp_fast(noise(n(2.2)), 3200), 500) * (0.75 + 0.25 * np.sin(t_(2.2) * 2 * np.pi * 3.0))))
    sfx("snow_loop", loopify(lp_fast(noise(n(2.2)), 1500)))
    sfx("ice_loop", loopify(hp_fast(noise(n(2.2)), 2500) * 0.6))
    # one-shots
    sfx("jump", lp_fast(noise(n(0.25)), 2500) * env(n(0.25), 0.005, 0.05, 0.4, 0.15) + osc(np.linspace(220, 440, n(0.25)), 0.25, "tri") * env(n(0.25), 0.005, 0.1, 0.2, 0.1) * 0.4)
    sfx("land", lp_fast(noise(n(0.3)), 1200) * env(n(0.3), 0.002, 0.08, 0.3, 0.2) + osc(80, 0.3) * env(n(0.3), 0.002, 0.1, 0.0, 0.1) * 0.8)
    sfx("land_hard", lp_fast(noise(n(0.45)), 900) * env(n(0.45), 0.002, 0.1, 0.4, 0.3) + osc(np.linspace(90, 50, n(0.45)), 0.45) * env(n(0.45), 0.002, 0.2, 0.0, 0.2))
    sfx("crash", lp_fast(noise(n(0.7)), 1500) * env(n(0.7), 0.002, 0.2, 0.4, 0.4) + osc(np.linspace(300, 80, n(0.7)), 0.7, "saw") * env(n(0.7), 0.002, 0.3, 0.0, 0.2) * 0.3)
    sfx("hit", osc(np.linspace(900, 200, n(0.3)), 0.3, "square") * env(n(0.3), 0.002, 0.1, 0.2, 0.15) * 0.6 + lp_fast(noise(n(0.3)), 3000) * env(n(0.3), 0.001, 0.05, 0.0, 0.05))
    sfx("ice_burst", hp_fast(noise(n(0.5)), 2000) * env(n(0.5), 0.001, 0.1, 0.2, 0.3) + sum(osc(f, 0.5) * env(n(0.5), 0.001, 0.2, 0.0, 0.2) * 0.2 for f in (1800, 2400, 3100)))
    coin = osc(1320, 0.08, "square") * env(n(0.08), 0.001, 0.02, 0.6, 0.02)
    sfx("coin", np.concatenate([coin, osc(1760, 0.18, "square") * env(n(0.18), 0.001, 0.05, 0.5, 0.12)]) * 0.6)
    sfx("buy", np.concatenate([osc(f, 0.07, "pulse") * env(n(0.07), 0.001, 0.01, 0.8, 0.02) for f in (660, 880, 1100, 1320)]))
    sfx("buy_fail", np.concatenate([osc(f, 0.15, "square") * env(n(0.15), 0.001, 0.02, 0.8, 0.05) for f in (220, 165)]) * 0.6)
    sfx("throw", lp_fast(noise(n(0.3)), 4000) * env(n(0.3), 0.01, 0.1, 0.3, 0.1) * np.linspace(0.3, 1, n(0.3)))
    sfx("penguin", np.concatenate([osc(np.linspace(700, 1100, n(0.12)), 0.12, "pulse") * env(n(0.12), 0.002, 0.03, 0.7, 0.04) for _ in range(3)]) * 0.6)
    sfx("mine_drop", osc(np.linspace(500, 300, n(0.2)), 0.2, "tri") * env(n(0.2), 0.001, 0.05, 0.3, 0.1) + hp_fast(noise(n(0.2)), 3000) * env(n(0.2), 0.001, 0.03, 0.0, 0.05) * 0.5)
    sfx("fog", lp_fast(noise(n(1.2)), 500) * env(n(1.2), 0.2, 0.3, 0.6, 0.5))
    sfx("wave", lp_fast(noise(n(0.8)), np.float64(900)) * env(n(0.8), 0.05, 0.2, 0.6, 0.4) + osc(np.linspace(120, 60, n(0.8)), 0.8) * env(n(0.8), 0.01, 0.4, 0.0, 0.3))
    sfx("boost", osc(np.linspace(200, 800, n(0.6)), 0.6, "saw") * env(n(0.6), 0.01, 0.2, 0.6, 0.2) * 0.5 + lp_fast(noise(n(0.6)), 3000) * env(n(0.6), 0.01, 0.2, 0.5, 0.2) * 0.5)
    sfx("shield", sum(osc(f, 0.7) * env(n(0.7), 0.02, 0.2, 0.5, 0.3) for f in (523, 659, 784, 1046)) * 0.4)
    sfx("shield_break", hp_fast(noise(n(0.4)), 2500) * env(n(0.4), 0.001, 0.1, 0.2, 0.2) + osc(np.linspace(1200, 400, n(0.4)), 0.4, "tri") * env(n(0.4), 0.001, 0.2, 0.0, 0.1))
    sfx("spring", osc(np.linspace(150, 900, n(0.35)) + 60 * np.sin(t_(0.35) * 2 * np.pi * 30), 0.35, "tri") * env(n(0.35), 0.002, 0.1, 0.5, 0.15))
    sfx("magnet", osc(220 + 30 * np.sin(t_(0.8) * 2 * np.pi * 8), 0.8, "saw") * env(n(0.8), 0.05, 0.2, 0.5, 0.3) * 0.4)
    sfx("repair", np.concatenate([osc(f, 0.09, "tri") * env(n(0.09), 0.001, 0.02, 0.8, 0.03) for f in (523, 784, 1046, 1568)]))
    sfx("grind", hp_fast(noise(n(0.6)), 3500) * env(n(0.6), 0.005, 0.1, 0.6, 0.2) + osc(1900, 0.6, "square") * 0.08)
    sfx("count", osc(880, 0.25, "square") * env(n(0.25), 0.002, 0.05, 0.6, 0.1) * 0.6)
    sfx("count_go", osc(1760, 0.6, "square") * env(n(0.6), 0.002, 0.1, 0.6, 0.3) * 0.6)
    sfx("lap", np.concatenate([osc(f, 0.12, "pulse") * env(n(0.12), 0.002, 0.03, 0.7, 0.04) for f in (784, 988, 1175)]))
    sfx("finish", np.concatenate([osc(f, d, "square") * env(n(d), 0.002, 0.05, 0.7, 0.05) for f, d in ((784, 0.12), (988, 0.12), (1175, 0.12), (1568, 0.5))]) * 0.6)
    sfx("perfect", np.concatenate([osc(f, 0.08, "tri") * env(n(0.08), 0.001, 0.02, 0.7, 0.03) for f in (1046, 1318, 1568, 2093)]))
    sfx("gate", osc(1318, 0.15, "tri") * env(n(0.15), 0.001, 0.05, 0.4, 0.08))
    sfx("ui_move", osc(990, 0.05, "pulse") * env(n(0.05), 0.001, 0.01, 0.5, 0.02) * 0.5)
    sfx("ui_ok", np.concatenate([osc(f, 0.06, "pulse") * env(n(0.06), 0.001, 0.01, 0.7, 0.02) for f in (880, 1320)]) * 0.6)
    sfx("ui_back", np.concatenate([osc(f, 0.06, "pulse") * env(n(0.06), 0.001, 0.01, 0.7, 0.02) for f in (660, 440)]) * 0.6)
    sfx("ui_open", osc(np.linspace(400, 900, n(0.15)), 0.15, "tri") * env(n(0.15), 0.002, 0.05, 0.5, 0.05))
    sfx("lift", osc(55, 1.5, "saw") * 0.25 * env(n(1.5), 0.2, 0.3, 0.7, 0.5) + lp_fast(noise(n(1.5)), 400) * 0.5 * env(n(1.5), 0.2, 0.3, 0.6, 0.5))
    sfx("unlock", np.concatenate([osc(f, 0.1, "square") * env(n(0.1), 0.001, 0.03, 0.7, 0.03) for f in (523, 659, 784, 1046, 1318)]) * 0.6)


# ------------------------------------------------------------------ music
NOTE = {n: i for i, n in enumerate(["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"])}
SCALES = {"major": [0, 2, 4, 5, 7, 9, 11], "minor": [0, 2, 3, 5, 7, 8, 10], "dorian": [0, 2, 3, 5, 7, 9, 10], "mixo": [0, 2, 4, 5, 7, 9, 10],
          "lydian": [0, 2, 4, 6, 7, 9, 11], "pent": [0, 2, 4, 7, 9]}


def midi_f(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def drum_kick(n):
    t = np.arange(n) / SR
    return np.sin(2 * np.pi * np.cumsum(np.interp(t, [0, 0.12], [140, 45])) / SR) * np.exp(-t * 18)


def drum_snare(n):
    t = np.arange(n) / SR
    return (hp_fast(noise(n), 1200) * 0.8 + np.sin(2 * np.pi * 190 * t) * 0.4) * np.exp(-t * 22)


def drum_hat(n, open_=False):
    t = np.arange(n) / SR
    return hp_fast(noise(n), 6000) * np.exp(-t * (12 if open_ else 60))


def tone(m, dur, kind, a=0.005, rel=0.08, vib=0.0, det=0.0):
    nn = int(dur * SR)
    t = np.arange(nn) / SR
    f = midi_f(m) * (1 + vib * np.sin(2 * np.pi * 5.5 * t))
    x = osc(f, dur, kind)
    if det:
        x = x * 0.6 + osc(f * (1 + det), dur, kind) * 0.4
    return x * env(nn, a, 0.08, 0.7, rel)


def song(name, key, mode, bpm, prog, lead_kind, bass_kind, pad_kind, groove, seed, bars=16, swing=0.0, arp=True):
    r = np.random.default_rng(seed)
    beat = 60.0 / bpm
    total = int(bars * 4 * beat * SR)
    mix = np.zeros(total + SR * 2)
    root = NOTE[key] + 48
    sc = SCALES[mode]
    def deg(d, octv=0):
        o, i = divmod(d, len(sc))
        return root + sc[i] + 12 * (o + octv)
    def put(x, start, gain):
        s0 = int(start * SR); mix[s0:s0 + len(x)] += x * gain
    # motif: 8-step rhythm/contour reused with variation (A A' B A'')
    motif = [int(r.integers(0, 5)) for _ in range(8)]
    rhythm = [1 if r.random() < 0.65 else 0 for _ in range(16)]
    rhythm[0] = 1
    for b in range(bars):
        chord = prog[b % len(prog)]
        t0 = b * 4 * beat
        # pad / chords (triad on scale degree)
        for k in (0, 2, 4):
            put(tone(deg(chord + k, 1), 4 * beat, pad_kind, a=0.08, rel=0.3, det=0.004), t0, 0.07)
        # bass (root + fifth pattern by groove)
        for st, dd, ln in groove["bass"]:
            put(tone(deg(chord + dd, -1), ln * beat, bass_kind, rel=0.03), t0 + st * beat, 0.26)
        # arpeggio
        if arp:
            for i in range(8):
                put(tone(deg(chord + [0, 2, 4, 7][i % 4], 2), beat / 2, "tri", rel=0.05), t0 + i * beat / 2 + (swing * beat / 2 if i % 2 else 0), 0.05)
        # lead melody on sections
        section = (b // 4) % 4
        if section in (0, 1, 3) or bars <= 8:
            var = 0 if section == 0 else (2 if section == 1 else -1)
            for i in range(16):
                if not rhythm[i]:
                    continue
                d = chord + motif[i % 8] + (var if i >= 8 else 0)
                st = t0 + i * beat / 4 + (swing * beat / 4 if i % 2 else 0)
                ln = beat / 4 * (2 if i % 4 == 0 else 1)
                put(tone(deg(d, 2), ln, lead_kind, vib=0.004, rel=0.06), st, 0.11)
        else:
            # B section: long notes counter-melody
            for i in range(4):
                put(tone(deg(chord + [4, 2, 0, 1][i], 2), beat, lead_kind, a=0.02, vib=0.006, rel=0.1), t0 + i * beat, 0.1)
        # drums
        for st in groove["kick"]:
            put(drum_kick(int(0.3 * SR)), t0 + st * beat, 0.55)
        for st in groove["snare"]:
            put(drum_snare(int(0.25 * SR)), t0 + st * beat, 0.32)
        for i in range(8):
            put(drum_hat(int(0.08 * SR)), t0 + i * beat / 2 + (swing * beat / 2 if i % 2 else 0), 0.09 if i % 2 else 0.13)
        if b % 4 == 3:
            put(drum_hat(int(0.4 * SR), True), t0 + 3.5 * beat, 0.12)
    # seamless loop: fold the tail back onto the start
    tail = mix[total:]
    mix = mix[:total]
    mix[:len(tail)] += tail
    # gentle echo for space (wrapped too)
    d = int(beat * 0.75 * SR)
    mix = mix + np.roll(mix, d) * 0.22
    mix = np.tanh(mix * 1.4) * 0.85
    wav = os.path.join(SRC, name + ".wav")
    write_wav(wav, norm(mix, 0.85))
    ogg = os.path.join(MUS, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", ogg], check=True)
    return len(mix) / SR


G_STRAIGHT = {"kick": [0, 2], "snare": [1, 3], "bass": [(0, 0, 0.5), (0.5, 0, 0.5), (1.5, 4, 0.5), (2, 0, 0.5), (3, 4, 0.5), (3.5, 7, 0.5)]}
G_DRIVE = {"kick": [0, 1, 2, 3], "snare": [1, 3], "bass": [(i * 0.5, 0 if i % 4 else 7, 0.5) for i in range(8)]}
G_HALF = {"kick": [0, 2.5], "snare": [2], "bass": [(0, 0, 1.5), (2, 4, 1), (3, 2, 1)]}
G_SHUFFLE = {"kick": [0, 1.5, 2], "snare": [1, 3], "bass": [(0, 0, 0.75), (1, 2, 0.5), (1.5, 4, 0.5), (2, 0, 0.75), (3, 4, 0.5), (3.5, 5, 0.5)]}

SONGS = [
    ("track_vale_pinheiros", "D", "major", 142, [0, 4, 5, 3], "pulse", "tri", "saw", G_STRAIGHT, 11, 0.0),
    ("track_lago_cristal", "E", "lydian", 128, [0, 1, 5, 4], "tri", "sine", "sine", G_HALF, 12, 0.0),
    ("track_pico_vulcanico", "A", "minor", 156, [0, 5, 6, 4], "saw", "square", "saw", G_DRIVE, 13, 0.0),
    ("track_festival_boreal", "F", "mixo", 134, [0, 6, 3, 4], "square", "tri", "saw", G_SHUFFLE, 14, 0.18),
    ("track_floresta_gigante", "G", "dorian", 120, [0, 3, 0, 4], "tri", "sine", "saw", G_STRAIGHT, 15, 0.1),
    ("track_estacao_abandonada", "C", "minor", 138, [0, 3, 4, 2], "pulse", "saw", "square", G_SHUFFLE, 16, 0.12),
    ("track_tempestade_polar", "B", "minor", 150, [0, 5, 3, 6], "saw", "tri", "saw", G_DRIVE, 17, 0.0),
    ("track_cume_celestial", "Eb".replace("Eb", "D#"), "major", 160, [0, 5, 3, 4], "pulse", "square", "saw", G_DRIVE, 18, 0.0),
    ("track_parque_manobras", "A", "major", 146, [0, 3, 4, 3], "square", "tri", "saw", G_SHUFFLE, 19, 0.15),
    ("menu", "C", "major", 112, [0, 5, 3, 4], "tri", "sine", "saw", G_HALF, 21, 0.1),
    ("results", "F", "major", 100, [0, 3, 4, 0], "tri", "sine", "sine", G_HALF, 22, 0.0),
    ("victory", "G", "major", 132, [0, 3, 4, 0], "pulse", "tri", "saw", G_STRAIGHT, 23, 0.0),
]

if __name__ == "__main__":
    make_sfx()
    print("sfx", len(os.listdir(SFX)))
    for name, key, mode, bpm, prog, lk, bk, pk, gr, seed, sw in SONGS:
        bars = 8 if name == "victory" else 16
        d = song(name, key, mode, bpm, prog, lk, bk, pk, gr, seed, bars=bars, swing=sw)
        print(name, "%.1fs" % d)
