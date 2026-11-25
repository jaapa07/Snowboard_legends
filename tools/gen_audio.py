#!/usr/bin/env python3
"""Original music and sound effects for Snowboard Legends 3D, synthesised from scratch with numpy (no samples,
no third-party material). Deterministic: the same script always produces the same files.

    python3 tools/gen_audio.py                    # everything: 37 SFX (.wav) + 12 looping songs (.ogg)
    python3 tools/gen_audio.py --sfx              # SFX only
    python3 tools/gen_audio.py --music [names]    # songs only (all, or e.g. menu track_lago_cristal)
    python3 tools/gen_audio.py --verify           # peak / RMS / duration / loop-seam report of the shipped files

Music: every song is an arrangement (intro / A / B / chorus / break ...) with a chord progression, voice-led pads,
bass line, drum kit, arpeggios and a generated-but-structured melody (motif, sequence, answer, cadence). Each part is
rendered with band-limited oscillators (PolyBLEP), filter envelopes (short-time FFT filters), FM bells/e-piano,
detuned supersaws etc., mixed on buses with sidechain ducking, a stereo algorithmic-IR reverb, ping-pong delay and a
look-ahead limiter. All bus effects are *circular* over the loop and note tails are folded back to the start, so the
OGG loops seamlessly (Godot plays it with `loop = true`, see scripts/core/audio_manager.gd).
44.1 kHz stereo, Vorbis q5 (ffmpeg/libvorbis, bit-exact flags). A small score (form, chords, melodies) is written to
source_art/audio/<song>.json as the editable source of each song.

SFX: 44.1 kHz mono 16-bit WAV, layered (transient + body + tone), peak -1 dBFS. The *_loop files are generated
circularly (periodic noise, LFOs with whole periods), so they loop without a crossfade.
"""
import bisect
import json
import os
import subprocess
import sys
import tempfile
import wave
import zlib

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
MUS_DIR = os.path.join(ROOT, "assets", "audio", "music")
SRC_DIR = os.path.join(ROOT, "source_art", "audio")
SR = 44100
CEIL = 10 ** (-1.0 / 20)          # -1 dBFS true ceiling before encoding
MUSIC_RMS_DB = -15.0              # loudness target of the music mixes
VORBIS_Q = "5"


def seeded(*key):
    return np.random.default_rng(zlib.crc32(repr(key).encode()))


# ============================================================================ DSP core
def ns(d):
    return int(round(d * SR))


def tarr(n):
    return np.arange(n) / SR


def resp(f, fc, q=0.7071, kind="lp", stages=1):
    """Analog 2-pole prototype (causal, minimum phase) evaluated on FFT bins."""
    fc = np.clip(fc, 10.0, 60000.0)
    s = 1j * f / fc
    den = 1 + s / q + s * s
    if kind == "lp":
        h = 1 / den
    elif kind == "hp":
        h = s * s / den
    else:
        h = (s / q) / den
    return h ** stages


def filt(x, kind, fc, q=0.7071, stages=1, circular=False):
    x = np.asarray(x, float)
    n = len(x)
    nfft = n if circular else 1 << (n + ns(0.25) - 1).bit_length()
    X = np.fft.rfft(x, nfft, axis=0)
    h = resp(np.fft.rfftfreq(nfft, 1 / SR), fc, q, kind, stages)
    if x.ndim == 2:
        h = h[:, None]
    return np.fft.irfft(X * h, nfft, axis=0)[:n]


def tvfilt(x, fc, q=0.7071, kind="lp", stages=1, N=1024, hop=256):
    """Time-varying filter: STFT (hann, 75 % overlap, zero-padded frames) with a per-frame analog response."""
    x = np.asarray(x, float)
    if x.ndim == 2:
        return np.stack([tvfilt(x[:, c], fc, q, kind, stages, N, hop) for c in range(x.shape[1])], 1)
    n = len(x)
    fc = np.broadcast_to(np.asarray(fc, float), (n,))
    xp = np.concatenate([np.zeros(N), x, np.zeros(N + hop)])
    nfr = (len(xp) - N) // hop + 1
    idx = np.arange(N)[None, :] + hop * np.arange(nfr)[:, None]
    win = np.hanning(N + 1)[:-1]
    F = np.fft.rfft(xp[idx] * win, 2 * N, axis=1)
    centre = np.clip(np.arange(nfr) * hop + N // 2 - N, 0, n - 1)
    h = resp(np.fft.rfftfreq(2 * N, 1 / SR)[None, :], fc[centre][:, None], q, kind, stages)
    Y = np.fft.irfft(F * h, 2 * N, axis=1)
    k = 2 * N // hop
    Yr = Y.reshape(nfr, k, hop)
    acc = np.zeros((nfr + k, hop))
    for j in range(k):
        acc[j:j + nfr] += Yr[:, j, :]
    return acc.ravel()[N:N + n] / (N / (2 * hop))


def _phase(freq, n, ph0=0.0):
    f = np.broadcast_to(np.asarray(freq, float), (n,))
    inc = f / SR
    return (ph0 + np.cumsum(inc) - inc) % 1.0, np.maximum(inc, 1e-9)


def _blep(p, dt):
    out = np.zeros_like(p)
    m = p < dt
    t = p[m] / dt[m]
    out[m] = t + t - t * t - 1
    m = p > 1 - dt
    t = (p[m] - 1) / dt[m]
    out[m] = t * t + t + t + 1
    return out


def saw(freq, n, ph0=0.0):
    p, dt = _phase(freq, n, ph0)
    return 2 * p - 1 - _blep(p, dt)


def pulse(freq, n, width=0.5, ph0=0.0):
    p, dt = _phase(freq, n, ph0)
    p2 = (p + width) % 1.0
    return 0.5 * ((2 * p - 1 - _blep(p, dt)) - (2 * p2 - 1 - _blep(p2, dt)))


def sine(freq, n, ph0=0.0):
    p, _ = _phase(freq, n, ph0)
    return np.sin(2 * np.pi * p)


def tri(freq, n, ph0=0.0):
    p, _ = _phase(freq, n, ph0)
    return 2 * np.abs(2 * p - 1) - 1


def fm(fc_, ratio, index, n, ph0=0.0):
    """Two-operator FM: carrier fc_, modulator fc_*ratio, index (array or scalar)."""
    p, _ = _phase(fc_, n, ph0)
    pm, _ = _phase(np.asarray(fc_) * ratio, n)
    return np.sin(2 * np.pi * p + index * np.sin(2 * np.pi * pm))


def adsr(ng, a=0.005, d=0.1, s=0.7, r=0.1):
    nr = max(1, ns(r))
    t = tarr(ng + nr)
    e = np.minimum(t / max(a, 1e-4), 1.0) * (s + (1 - s) * np.exp(-np.maximum(t - a, 0) / max(d, 1e-4)))
    e *= np.exp(-np.maximum(t - ng / SR, 0) * 5 / max(r, 1e-4))
    k = max(1, nr // 6)
    e[-k:] *= np.linspace(1, 0, k)
    return e


def pdec(ng, tau, r=0.08, a=0.002):
    """Percussive envelope: exponential decay, cut by a release after the gate."""
    return adsr(ng, a, tau, 0.0, r)


def stereo(x):
    return np.stack([x, x], 1) if x.ndim == 1 else x


def pan(x, p):
    x = stereo(x)
    return x * np.array([min(1.0, 1 - p), min(1.0, 1 + p)])


def peak(x):
    return float(np.max(np.abs(x))) + 1e-12


def norm(x, pk=1.0):
    return x / peak(x) * pk


def midi_f(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def vib(n, f, depth=0.15, rate=5.5, delay=0.2):
    t = tarr(n)
    ramp = np.clip((t - delay) / 0.3, 0, 1)
    return f * 2 ** (depth * ramp * np.sin(2 * np.pi * rate * t) / 12)


def sliding_min(a, W):
    n = len(a)
    ap = np.concatenate([a, np.full((-n) % W, np.inf)])
    b = ap.reshape(-1, W)
    pre = np.minimum.accumulate(b, axis=1).ravel()
    suf = np.minimum.accumulate(b[:, ::-1], axis=1)[:, ::-1].ravel()
    m = n - W + 1
    return np.minimum(suf[:m], pre[W - 1:W - 1 + m])


def limiter(x, ceil=CEIL, look=0.008, hold=0.02):
    """Circular look-ahead brick-wall limiter: output peak <= ceil, gain never rises above what a peak needs."""
    a = np.max(np.abs(x), axis=1) if x.ndim == 2 else np.abs(x)
    g = np.minimum(1.0, ceil / np.maximum(a, 1e-9))
    W, H = max(2, ns(look)), max(2, ns(hold))
    m = sliding_min(np.concatenate([g, g[:W - 1]]), W)                 # min over [i, i+W)
    m = sliding_min(np.concatenate([m[-(H - 1):], m]), H)              # hold: min over (i-H, i]
    mp = np.concatenate([m[-(W - 1):], m])
    cs = np.concatenate([[0.0], np.cumsum(mp)])
    gain = (cs[W:W + len(m)] - cs[:len(m)]) / W                        # average over (i-W, i]
    y = x * (gain[:, None] if x.ndim == 2 else gain)
    return y, float(20 * np.log10(gain.min()))


def rms_db(x):
    return float(10 * np.log10(np.mean(np.asarray(x) ** 2) + 1e-20))


def active_rms_db(x, block=4410):
    ms = np.mean(x ** 2, axis=1) if x.ndim == 2 else x ** 2
    nb = len(ms) // block
    if nb == 0:
        return rms_db(x)
    b = ms[:nb * block].reshape(nb, block).mean(1)
    act = b > b.max() * 1e-3
    return float(10 * np.log10(b[act].mean() + 1e-20))


def write_wav(path, x, channels=1):
    x = np.clip(np.asarray(x), -1, 1)
    data = np.round(x * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def read_audio(path):
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-f", "f32le", "-ac", "2", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).reshape(-1, 2).astype(float)


# ============================================================================ instruments (return stereo arrays)
def I_square(f, ng, r):
    e = adsr(ng, 0.004, 0.15, 0.75, 0.10)
    n = len(e)
    t = tarr(n)
    x = pulse(vib(n, f, 0.18), n, 0.5 - 0.12 * np.sin(2 * np.pi * 0.8 * t))
    x = tvfilt(x, np.minimum(f * 3 + 1800 + 5000 * np.exp(-t / 0.15), 16000), 0.9)
    return stereo(x * e)


def I_chip(f, ng, r):
    e = adsr(ng, 0.002, 0.10, 0.65, 0.06)
    n = len(e)
    x = pulse(vib(n, f, 0.25, 6.5, 0.12), n, 0.25)
    return stereo(filt(x, "lp", 9000) * e * 0.9)


def I_pwm(f, ng, r):
    e = adsr(ng, 0.006, 0.2, 0.7, 0.12)
    n = len(e)
    t = tarr(n)
    x = pulse(vib(n, f, 0.15), n, 0.3 + 0.15 * np.sin(2 * np.pi * 2.2 * t + r.uniform(0, 6)))
    x = tvfilt(x, np.minimum(f * 2 + 1200 + 3500 * np.exp(-t / 0.2), 15000), 1.3)
    return stereo(x * e)


def I_saw_lead(f, ng, r):
    e = adsr(ng, 0.004, 0.25, 0.8, 0.12)
    n = len(e)
    t = tarr(n)
    fr = vib(n, f, 0.2)
    x = 0.5 * (saw(fr * 1.003, n, r.uniform()) + saw(fr * 0.997, n, r.uniform()))
    x = tvfilt(x, np.minimum(f * 2 + 1400 + 4500 * np.exp(-t / 0.2), 16000), 1.6)
    x = np.tanh(1.8 * x) / np.tanh(1.8)
    return pan(x * e, -0.05) * 0.5 + pan(np.roll(x * e, ns(0.009)), 0.05) * 0.5


def I_supersaw(f, ng, r, cutoff=7000, a=0.008, rel=0.22):
    e = adsr(ng, a, 0.3, 0.85, rel)
    n = len(e)
    det = [-0.011, -0.0065, -0.003, 0.0, 0.003, 0.0065, 0.011]
    pans = [-0.9, 0.6, -0.4, 0.0, 0.4, -0.6, 0.9]
    out = np.zeros((n, 2))
    for d, p in zip(det, pans):
        out += pan(saw(f * (1 + d), n, r.uniform()), p)
    out = filt(out / 3.0, "lp", cutoff, 0.8)
    return out * e[:, None]


def I_brass(f, ng, r):
    e = adsr(ng, 0.018, 0.3, 0.8, 0.14)
    n = len(e)
    t = tarr(n)
    fr = vib(n, f, 0.12, 5.0, 0.3)
    x = (saw(fr * 1.004, n, r.uniform()) + saw(fr * 0.996, n, r.uniform()) + 0.6 * pulse(fr, n, 0.4)) / 2.6
    fc = f * (1.5 + 6.5 * (1 - np.exp(-t / 0.045)) * (0.55 + 0.45 * np.exp(-t / 0.35)))
    x = tvfilt(x, np.minimum(fc, 15000), 1.0)
    return stereo(x * e)


def I_flute(f, ng, r):
    e = adsr(ng, 0.035, 0.12, 0.85, 0.12)
    n = len(e)
    fr = vib(n, f, 0.22, 5.2, 0.15)
    x = sine(fr, n) + 0.18 * sine(fr * 2, n) + 0.06 * sine(fr * 3, n)
    breath = filt(r.uniform(-1, 1, n), "bp", f * 2, 2.0) * (0.12 + 0.25 * np.exp(-tarr(n) / 0.05))
    return stereo((x + breath) * e * 0.8)


def I_bell(f, ng, r):
    n = ng + ns(1.2)
    t = tarr(n)
    x = fm(f, 3.5, 2.0 * np.exp(-t / 0.22) + 0.25, n) * np.exp(-t / 0.8)
    x += 0.35 * sine(f * 2, n) * np.exp(-t / 0.25)
    e = pdec(ng, 10.0, 0.6, 0.001)[:n]
    return stereo(x * e * 0.8)


def I_glass(f, ng, r):
    n = ng + ns(1.4)
    t = tarr(n)
    e = pdec(ng, 10.0, 0.8, 0.002)[:n]
    a = fm(f, 2.0, 1.1 * np.exp(-t / 0.4) + 0.15, n) * np.exp(-t / 1.4)
    b = fm(f * 1.004, 2.0, 1.1 * np.exp(-t / 0.4) + 0.15, n, 0.3) * np.exp(-t / 1.4)
    return np.stack([a, b], 1) * e[:, None] * 0.7


def I_marimba(f, ng, r):
    n = ng + ns(0.5)
    t = tarr(n)
    tau = 0.5 * (440 / f) ** 0.35
    x = sine(f, n) * np.exp(-t / tau) + 0.35 * sine(f * 3.93, n) * np.exp(-t / 0.06)
    x += 0.08 * sine(f * 9.2, n) * np.exp(-t / 0.012) if f * 9.2 < 20000 else 0
    e = pdec(ng, 10.0, 0.25, 0.001)[:n]
    return stereo(x * e)


def I_pluck(f, ng, r):
    n = ng + ns(0.35)
    t = tarr(n)
    x = 0.6 * saw(f, n, r.uniform()) + 0.4 * pulse(f * 1.002, n, 0.3)
    x = tvfilt(x, np.minimum(f * 1.3 + 7000 * np.exp(-t / 0.07), 17000), 1.1)
    e = pdec(ng, 0.35, 0.2, 0.001)[:n]
    return stereo(x * e)


def I_ep(f, ng, r):
    n = ng + ns(0.6)
    t = tarr(n)
    x = fm(f, 1.0, 1.5 * np.exp(-t / 0.45) + 0.2, n) * np.exp(-t / 1.6)
    if f * 14 < 19000:
        x += 0.2 * fm(f, 14.0, 0.6, n) * np.exp(-t / 0.025)
    e = pdec(ng, 10.0, 0.35, 0.002)[:n]
    trem = 0.15 * np.sin(2 * np.pi * 4.5 * t)
    return np.stack([x * (1 + trem), x * (1 - trem)], 1) * e[:, None] * 0.8


def I_organ(f, ng, r):
    e = adsr(ng, 0.004, 0.05, 1.0, 0.06)
    n = len(e)
    x = np.zeros(n)
    for h, w in ((1, 1.0), (2, 0.8), (3, 0.5), (4, 0.3), (6, 0.18), (8, 0.12)):
        if f * h < 18000:
            x += w * sine(f * h * (1 + 0.0007 * h), n, r.uniform())
    click = filt(r.uniform(-1, 1, n), "hp", 3000) * np.exp(-tarr(n) / 0.004) * 0.3
    x = (x / 2.4 + click) * e
    lfo = 0.12 * np.sin(2 * np.pi * 6.3 * tarr(n))
    return np.stack([x * (1 + lfo), x * (1 - lfo)], 1)


def _pad(f, ng, r, kinds, det, cutoff, a, rel, q=0.8):
    e = adsr(ng, a, 0.6, 0.85, rel)
    n = len(e)
    out = np.zeros((n, 2))
    for i, d in enumerate(det):
        fn = {"saw": saw, "tri": tri, "sine": sine}[kinds[i % len(kinds)]]
        out += pan(fn(f * (1 + d), n, r.uniform()), -0.8 if i % 2 == 0 else 0.8)
    out = filt(out / len(det) * 1.6, "lp", cutoff, q)
    return out * e[:, None]


def I_pad_saw(f, ng, r):
    return _pad(f, ng, r, ["saw"], [-0.006, -0.002, 0.002, 0.006], 2400, 0.25, 0.7)


def I_pad_warm(f, ng, r):
    return _pad(f, ng, r, ["saw", "tri"], [-0.004, 0.004, -0.001, 0.001], 1300, 0.3, 0.8)


def I_pad_glass(f, ng, r):
    out = _pad(f, ng, r, ["tri", "sine"], [-0.005, 0.005, -0.0015, 0.0015], 6000, 0.35, 1.2)
    n = len(out)
    sh = fm(f * 2, 3.0, 0.4, n, r.uniform()) * 0.15 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.7 * tarr(n)))
    return out + stereo(sh * adsr(ng, 0.5, 0.6, 0.85, 1.2)[:n])


def I_pad_dark(f, ng, r):
    out = _pad(f, ng, r, ["saw"], [-0.005, 0.005, -0.0015], 950, 0.4, 1.0, 1.2)
    n = len(out)
    return out + stereo(tri(f / 2, n) * 0.25 * adsr(ng, 0.4, 0.6, 0.85, 1.0)[:n])


def I_pad_super(f, ng, r):
    return I_supersaw(f, ng, r, cutoff=4200, a=0.02, rel=0.3) * 0.8


def I_stab_power(f, ng, r):
    e = adsr(ng, 0.003, 0.18, 0.6, 0.06)
    n = len(e)
    x = saw(f * 1.003, n, r.uniform()) + saw(f * 0.997, n, r.uniform())
    x = filt(np.tanh(2.5 * x), "lp", 3200, 0.9)
    return pan(x * e, -0.3) * 0.5 + pan(np.roll(x * e, ns(0.012)), 0.3) * 0.5


def I_bass_saw(f, ng, r):
    e = adsr(ng, 0.003, 0.2, 0.75, 0.05)
    n = len(e)
    t = tarr(n)
    x = saw(f, n) + 0.7 * sine(f, n)
    return stereo(tvfilt(x, 160 + f * 1.5 + 2200 * np.exp(-t / 0.09), 1.2) * e)


def I_bass_dist(f, ng, r):
    e = adsr(ng, 0.003, 0.2, 0.8, 0.05)
    n = len(e)
    x = np.tanh(3.0 * (saw(f, n) + saw(f * 1.006, n, 0.4)) / 2)
    x = filt(x, "lp", 2000, 1.0) + 0.8 * sine(f, n)
    return stereo(x * e)


def I_bass_sub(f, ng, r):
    e = adsr(ng, 0.006, 0.3, 0.85, 0.08)
    n = len(e)
    x = np.tanh(1.4 * (sine(f, n) + 0.3 * tri(f, n)))
    return stereo(x * e)


def I_bass_pick(f, ng, r):
    n = ng + ns(0.08)
    t = tarr(n)
    x = tvfilt(pulse(f, n, 0.35), 250 + f + 1600 * np.exp(-t / 0.05), 1.0) * 1.3 + 0.6 * sine(f, n)
    return stereo(x * pdec(ng, 0.55, 0.06, 0.002)[:n])


def I_bass_acid(f, ng, r):
    e = adsr(ng, 0.003, 0.15, 0.7, 0.04)
    n = len(e)
    t = tarr(n)
    x = tvfilt(saw(f, n), 180 + f + 2600 * np.exp(-t / 0.11), 4.0)
    return stereo((np.tanh(2.0 * x) + 0.5 * sine(f, n)) * e)


def I_bass_slap(f, ng, r):
    n = ng + ns(0.08)
    t = tarr(n)
    x = fm(f, 1.0, 3.0 * np.exp(-t / 0.04) + 0.5, n) + 0.6 * sine(f, n)
    return stereo(x * pdec(ng, 0.6, 0.06, 0.001)[:n])


INSTR = {k[2:]: v for k, v in list(globals().items()) if k.startswith("I_")}
_cache = {}


def render(inst, midi, ng):
    key = (inst, int(midi), int(ng))
    if key not in _cache:
        _cache[key] = INSTR[inst](midi_f(midi), int(ng), seeded(*key))
    return _cache[key]


# ============================================================================ drum kits
def make_kit(style, seed):
    r = seeded("kit", style, seed)

    def nz(n):
        return r.uniform(-1, 1, n)

    K = {}
    f0, f1, tp, td, drive = {"punch": (170, 50, 0.035, 0.22, 1.6), "rock": (140, 55, 0.03, 0.2, 1.8),
                             "soft": (120, 52, 0.03, 0.17, 1.2), "deep": (150, 42, 0.05, 0.42, 1.5),
                             "tight": (190, 58, 0.025, 0.15, 1.8)}[style]
    n = ns(0.6)
    t = tarr(n)
    fr = f1 + (f0 - f1) * np.exp(-t / tp)
    body = np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.exp(-t / td)
    click = filt(nz(n), "hp", 2500) * np.exp(-t / 0.003) * 0.45
    K["kick"] = norm(np.tanh(drive * (body + click)))
    n = ns(0.4)
    t = tarr(n)
    tone = (np.sin(2 * np.pi * 185 * t) * 0.6 + np.sin(2 * np.pi * 330 * t) * 0.3) * np.exp(-t / 0.045)
    w = nz(n)
    rattle = filt(w, "bp", 3500, 0.6) * np.exp(-t / (0.07 if style == "tight" else 0.11))
    snap = filt(w, "hp", 6000) * np.exp(-t / 0.035) * 0.6
    K["snare"] = norm(np.tanh(1.3 * (tone + rattle * 1.3 + snap)))
    n = ns(0.45)
    t = tarr(n)
    e = sum(np.exp(-np.maximum(t - o, 0) / 0.0045) * (t >= o) for o in (0, 0.011, 0.023))
    e = e + 0.6 * np.exp(-np.maximum(t - 0.03, 0) / 0.09) * (t >= 0.03)
    K["clap"] = norm(filt(nz(n), "bp", 1300, 1.0) * e)
    n = ns(0.7)
    t = tarr(n)
    metal = sum(np.sign(np.sin(2 * np.pi * fq * 1.6 * t + r.uniform(0, 6))) for fq in (205.3, 304.4, 369.6, 522.7, 540.0, 800.0))
    hs = filt(metal * 0.25 + nz(n) * 0.8, "hp", 7000, stages=2)
    K["hat"] = norm(hs[:ns(0.12)] * np.exp(-t[:ns(0.12)] / 0.028))
    K["ohat"] = norm(hs * np.exp(-t / 0.22))
    n = ns(2.4)
    t = tarr(n)
    cr = []
    for c in range(2):
        m2 = sum(np.sign(np.sin(2 * np.pi * fq * 2.3 * t + r.uniform(0, 6))) for fq in (205.3, 304.4, 369.6, 522.7, 540.0, 800.0))
        cr.append(filt(m2 * 0.2 + nz(n), "hp", 3800, stages=2) * (np.exp(-t / 0.75) * 0.8 + 0.6 * np.exp(-t / 0.08)))
    K["crash"] = norm(np.stack(cr, 1))
    for name, f in (("tom_hi", 210), ("tom_mid", 160), ("tom_lo", 118)):
        n = ns(0.5)
        t = tarr(n)
        fr = f * (1 + 0.6 * np.exp(-t / 0.03))
        x = np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.exp(-t / 0.2) + filt(nz(n), "bp", f * 4, 1.0) * np.exp(-t / 0.03) * 0.4
        K[name] = norm(np.tanh(1.3 * x))
    n = ns(0.12)
    t = tarr(n)
    K["shaker"] = norm(filt(nz(n), "hp", 5000) * (1 - np.exp(-t / 0.008)) * np.exp(-t / 0.035))
    n = ns(0.3)
    t = tarr(n)
    jm = sum(np.sign(np.sin(2 * np.pi * fq * t + r.uniform(0, 6))) for fq in (2730, 3410, 4520, 5390, 6860))
    K["tamb"] = norm(filt(jm * 0.3 + nz(n), "hp", 6000) * (np.exp(-t / 0.06) + 0.5 * np.exp(-np.maximum(t - 0.03, 0) / 0.08) * (t > 0.03)))
    n = ns(0.15)
    t = tarr(n)
    K["wood"] = norm(np.sin(2 * np.pi * 1050 * t) * np.exp(-t / 0.03) + 0.5 * np.sin(2 * np.pi * 1680 * t) * np.exp(-t / 0.018)
                     + filt(nz(n), "bp", 2500, 2) * np.exp(-t / 0.004))
    n = ns(0.5)
    t = tarr(n)
    K["clank"] = norm(fm(380, 1.414, 6 * np.exp(-t / 0.06) + 1.0, n) * np.exp(-t / 0.22) + filt(nz(n), "hp", 4000) * np.exp(-t / 0.02) * 0.5)
    n = ns(0.1)
    t = tarr(n)
    K["rim"] = norm(filt(nz(n), "bp", 2000, 3) * np.exp(-t / 0.008) + 0.6 * np.sin(2 * np.pi * 1600 * t) * np.exp(-t / 0.01))
    return K


def riser(d, seed):
    r = seeded("riser", seed)
    n = ns(d)
    t = tarr(n)
    fc = 300 * (7000 / 300) ** (t / d)
    x = np.stack([tvfilt(r.uniform(-1, 1, n), fc, 1.5, "bp"), tvfilt(r.uniform(-1, 1, n), fc * 1.05, 1.5, "bp")], 1)
    amp = (t / d) ** 2
    amp[-ns(0.01):] *= np.linspace(1, 0, ns(0.01))
    return norm(x * amp[:, None])


def boom():
    n = ns(1.4)
    t = tarr(n)
    fr = 38 + 40 * np.exp(-t / 0.08)
    x = np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.exp(-t / 0.5) + filt(seeded("boom").uniform(-1, 1, n), "lp", 400) * np.exp(-t / 0.12)
    return norm(stereo(np.tanh(1.5 * x)))


# ============================================================================ composition
PCS = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8,
       "A": 9, "A#": 10, "Bb": 10, "B": 11}
MODES = {"major": [0, 2, 4, 5, 7, 9, 11], "minor": [0, 2, 3, 5, 7, 8, 10], "dorian": [0, 2, 3, 5, 7, 9, 10],
         "mixo": [0, 2, 4, 5, 7, 9, 10], "lydian": [0, 2, 4, 6, 7, 9, 11]}
ROMAN = {"I": 0, "II": 2, "III": 4, "IV": 5, "V": 7, "VI": 9, "VII": 11}
QUAL = {"maj": [0, 4, 7], "min": [0, 3, 7], "dim": [0, 3, 6], "7": [0, 4, 7, 10], "maj7": [0, 4, 7, 11], "m7": [0, 3, 7, 10],
        "sus4": [0, 5, 7], "sus2": [0, 2, 7], "add9": [0, 4, 7, 14], "madd9": [0, 3, 7, 14]}


def parse_chord(sym):
    acc = 0
    while sym[0] in "b#":
        acc += -1 if sym[0] == "b" else 1
        sym = sym[1:]
    i = 0
    while i < len(sym) and sym[i] in "IViv":
        i += 1
    rn, suf = sym[:i], sym[i:]
    minor = rn.islower()
    q = {"": "min" if minor else "maj", "7": "m7" if minor else "7", "maj7": "maj7", "dim": "dim", "sus4": "sus4",
         "sus2": "sus2", "add9": "madd9" if minor else "add9"}[suf]
    return (ROMAN[rn.upper()] + acc) % 12, QUAL[q]


# melody rhythms: two bars of (16th step, length in 16ths)
RHYTHMS = {
    "pop": [[(0, 2), (2, 2), (4, 3), (7, 1), (8, 4), (12, 2), (14, 2)], [(0, 3), (3, 3), (6, 2), (8, 6), (14, 2)]],
    "syncop": [[(0, 3), (3, 3), (6, 2), (8, 2), (10, 2), (12, 4)], [(0, 2), (2, 2), (4, 2), (6, 4), (10, 6)]],
    "drive": [[(0, 2), (2, 2), (4, 2), (6, 2), (8, 2), (10, 2), (12, 4)], [(0, 4), (4, 2), (6, 2), (8, 8)]],
    "anthem": [[(0, 4), (4, 4), (8, 2), (10, 2), (12, 4)], [(0, 6), (6, 2), (8, 8)]],
    "bouncy": [[(0, 3), (3, 1), (4, 3), (7, 1), (8, 3), (11, 1), (12, 4)], [(0, 3), (3, 1), (4, 4), (8, 8)]],
    "lyric": [[(0, 6), (6, 2), (8, 4), (12, 4)], [(0, 3), (3, 3), (6, 10)]],
    "ska": [[(0, 2), (2, 2), (4, 1), (6, 2), (8, 2), (10, 1), (12, 2), (14, 2)], [(0, 2), (2, 4), (6, 2), (8, 8)]],
    "fast": [[(0, 1), (1, 1), (2, 2), (4, 2), (6, 1), (7, 1), (8, 2), (10, 2), (12, 4)], [(0, 2), (2, 2), (4, 4), (8, 4), (12, 4)]],
    "call": [[(2, 2), (4, 2), (6, 2), (8, 4), (12, 2), (14, 2)], [(0, 4), (4, 2), (6, 2), (8, 6)]],
}
CADENCES = [[(0, 4), (4, 4), (8, 8)], [(0, 3), (3, 3), (6, 10)], [(0, 2), (2, 2), (4, 4), (8, 8)]]

BASS = {
    "eighths": [(0, 2, "R"), (2, 2, "R"), (4, 2, "R"), (6, 2, "R"), (8, 2, "R"), (10, 2, "R"), (12, 2, "5"), (14, 2, "8")],
    "octave": [(i * 2, 2, "R" if i % 2 == 0 else "8") for i in range(8)],
    "offbeat": [(2, 2, "R"), (6, 2, "R"), (10, 2, "R"), (14, 2, "8")],
    "gallop": [(0, 2, "R"), (2, 1, "R"), (3, 1, "R"), (4, 2, "R"), (6, 1, "R"), (7, 1, "R"), (8, 2, "R"), (10, 1, "R"),
               (11, 1, "R"), (12, 2, "5"), (14, 1, "5"), (15, 1, "8")],
    "syncop": [(0, 3, "R"), (3, 3, "R"), (6, 2, "8"), (8, 2, "R"), (10, 2, "5"), (12, 2, "R"), (14, 2, "A")],
    "walk": [(0, 4, "R"), (4, 4, "3"), (8, 4, "5"), (12, 4, "A")],
    "funk": [(0, 2, "R"), (3, 1, "8"), (4, 2, "R"), (7, 1, "R"), (8, 2, "5"), (10, 2, "8"), (12, 1, "R"), (14, 2, "A")],
    "sub": [(0, 6, "R"), (6, 6, "R"), (12, 4, "5")],
    "long": [(0, 12, "R"), (12, 4, "5")],
}

STABS = {"offbeat": [(2, 1), (6, 1), (10, 1), (14, 1)], "pop": [(0, 3), (3, 3), (6, 2), (10, 2), (12, 3)],
         "disco": [(2, 2), (6, 2), (10, 2), (14, 2)], "power": [(0, 2), (3, 2), (6, 2), (8, 2), (11, 2), (14, 2)],
         "charleston": [(0, 3), (3, 5), (8, 3), (11, 5)], "hold": [(0, 16)]}

V = {"X": 1.0, "x": 0.8, "o": 0.55, "g": 0.3}
DRUMS = {
    "pop": {"main": {"kick": "X.....x.X.....o.", "snare": "....X.......X...", "hat": "x.o.x.o.x.o.x.o.", "ohat": "..............o."},
            "busy": {"kick": "X.....x.X.x...o.", "snare": "....X.......X..o", "clap": "....x.......x...", "hat": "xoxoxoxoxoxoxoxo",
                     "ohat": "..o...o...o...o."}},
    "rock": {"main": {"kick": "X.x...x.X.x...x.", "snare": "....X.......X...", "hat": "x.x.x.x.x.x.x.x."},
             "busy": {"kick": "X.x.X.x.X.x.X.x.", "snare": "....X.......X...", "hat": "xoxoxoxoxoxoxoxo", "ohat": "o.......o......."}},
    "four": {"main": {"kick": "X...X...X...X...", "clap": "....X.......X...", "hat": "..x...x...x...x.", "shaker": "goxogoxogoxogoxo"},
             "busy": {"kick": "X...X...X...X...", "clap": "....X.......X...", "snare": "....o.......o..g", "ohat": "..x...x...x...x.",
                      "hat": "xoxoxoxoxoxoxoxo"}},
    "half": {"main": {"kick": "X.........x.....", "snare": "........X.......", "hat": "x.x.x.x.x.x.x.x.", "shaker": "gogogogogogogogo"},
             "busy": {"kick": "X.....x...x.....", "snare": "....X.......X...", "hat": "xoxoxoxoxoxoxoxo", "ohat": "..............o.",
                      "shaker": "gogogogogogogogo"}},
    "disco": {"main": {"kick": "X...X...X...X...", "clap": "....X.......X...", "ohat": "..x...x...x...x.", "hat": "x.g.x.g.x.g.x.g.",
                       "tamb": "....o.......o..."},
              "busy": {"kick": "X...X...X...X...", "clap": "....X.......X...", "snare": "....o.......o...", "ohat": "..x...x...x...x.",
                       "hat": "xgxgxgxgxgxgxgxg", "tamb": "..o...o...o...o."}},
    "funk": {"main": {"kick": "X..x..x...x..o..", "snare": "....X..g.g..X...", "hat": "xoxoxoxoxoxoxoxo"},
             "busy": {"kick": "X..x..x...x..o..", "snare": "....X..g.g..X..g", "clap": "....x.......x...", "hat": "xoxoxoxoxoxoxoxo",
                      "ohat": "......o.......o."}},
    "ska": {"main": {"kick": "X.......X.x.....", "snare": "....X.......X...", "hat": "x.x.x.x.x.x.x.x."},
            "busy": {"kick": "X...X...X...X...", "snare": "....X.......X...", "hat": "x.x.x.x.x.x.x.x.", "ohat": "..x...x...x...x."}},
    "break": {"main": {"kick": "X.........x..x..", "snare": "....X..g.g..X...", "hat": "x.xox.x.x.xox.x."},
              "busy": {"kick": "X.x.......x..x..", "snare": "....X..g.g..X..g", "hat": "xoxoxoxoxoxoxoxo", "ohat": "..............x."}},
    "shuffle": {"main": {"kick": "X.....x...x.....", "snare": "....X.......X...", "hat": "x.o.x.o.x.o.x.o."},
                "busy": {"kick": "X.....x.X.x.....", "snare": "....X.......X..g", "hat": "x.o.x.o.x.o.x.o.", "ohat": "......o.......o."}},
}
DGAIN = {"kick": 1.0, "snare": 0.72, "clap": 0.5, "hat": 0.2, "ohat": 0.2, "shaker": 0.12, "tamb": 0.16, "crash": 0.32,
         "tom_hi": 0.55, "tom_mid": 0.55, "tom_lo": 0.6, "wood": 0.28, "clank": 0.22, "rim": 0.3}
DPAN = {"hat": 0.3, "ohat": 0.3, "shaker": -0.45, "tamb": -0.35, "tom_hi": -0.4, "tom_lo": 0.4, "wood": -0.4, "clank": 0.45, "rim": 0.2}
FILLS = [{"snare": "........o.x.xxXX"},
         {"tom_hi": "........Xx......", "tom_mid": "..........Xx....", "tom_lo": "............Xx..", "snare": "..............XX"},
         {"snare": "........X..x..X.", "kick": "........X..X..X.", "tom_lo": "...............X"},
         {"snare": "........xoxoXxXx", "kick": "........X...X..."}]
BUS_LEVEL = {"drums": 0.0, "bass": -3.0, "chords": -9.0, "lead": -4.5, "arp": -11.0, "fx": -16.0}
DUCK = {"bass": 0.25, "chords": 0.35, "arp": 0.25, "fx": 0.2, "lead": 0.08}
SEND = {"drums": 0.06, "bass": 0.0, "chords": 0.3, "lead": 0.22, "arp": 0.35, "fx": 0.3}


class Song:
    def __init__(self, name, c):
        self.name, self.c = name, c
        self.r = seeded("song", name)
        self.key = PCS[c["key"]]
        self.scale = MODES[c["mode"]]
        self.step = 60.0 / c["bpm"] / 4 * SR
        self.swing = c.get("swing", 0.0)
        self.bars = []
        for sec, nb in c["form"]:
            prog = c["prog"][sec.rstrip("0123456789")]
            for i in range(nb):
                parts = prog[i % len(prog)].split()
                self.bars.append({"sec": sec, "type": sec.rstrip("0123456789"), "i": i, "n": nb,
                                  "chords": [(j * 16 // len(parts),) + parse_chord(p) for j, p in enumerate(parts)]})
        self.L = int(round(len(self.bars) * 16 * self.step))
        self.TAIL = ns(4.0)
        self.bus = {b: np.zeros((self.L + self.TAIL, 2)) for b in BUS_LEVEL}
        self.kicks = []
        self.kit = make_kit(c.get("kit", "punch"), name)
        self.score = {"bpm": c["bpm"], "key": c["key"], "mode": c["mode"], "form": c["form"], "prog": c["prog"], "melodies": {}}

    # ---- timing / harmony helpers
    def pos(self, bar, step):
        b4 = (step // 4) * 4
        p = step - b4
        s = self.swing
        q = p * (2 + s) / 2 if p <= 2 else 2 + s + (p - 2) * (2 - s) / 2
        return int(round((bar * 16 + b4 + q) * self.step)) % self.L

    def chord_at(self, bar, step=0):
        ch = self.bars[bar % len(self.bars)]["chords"]
        cur = ch[0]
        for c in ch:
            if c[0] <= step:
                cur = c
        return cur

    def chord_pcs(self, ch):
        out = []
        for iv in ch[2]:
            pc = (self.key + ch[1] + iv) % 12
            if pc not in out:
                out.append(pc)
        return out

    def scale_pcs(self, ch):
        pcs = [(self.key + s) % 12 for s in self.scale]
        for c in self.chord_pcs(ch):
            if c not in pcs:
                pcs = [p for p in pcs if min((p - c) % 12, (c - p) % 12) != 1] + [c]
        return sorted(set(pcs))

    @staticmethod
    def nearest(m, pcs):
        for d in (0, -1, 1, -2, 2, -3, 3, -4, 4, -5, 5, -6, 6):
            if (m + d) % 12 in pcs:
                return m + d
        return m

    @staticmethod
    def sstep(m, k, pcs):
        notes = [x for x in range(m - 30, m + 31) if x % 12 in pcs]
        if k == 0:
            return Song.nearest(m, pcs)
        if m in notes:
            i = notes.index(m)
        elif k > 0:
            i = bisect.bisect_right(notes, m) - 1
        else:
            i = bisect.bisect_left(notes, m)
        return notes[max(0, min(len(notes) - 1, i + k))]

    def voicing(self, ch, prev, lo=55, hi=76):
        pcs = self.chord_pcs(ch)
        cands = []
        for base in range(lo, lo + 12):
            if base % 12 not in pcs:
                continue
            k = pcs.index(base % 12)
            notes = [base]
            for pc in pcs[k + 1:] + pcs[:k]:
                m = notes[-1] + 1
                while m % 12 != pc:
                    m += 1
                notes.append(m)
            if notes[-1] <= hi:
                cands.append(notes)
        if prev is None or not cands:
            return min(cands, key=lambda v: abs(np.mean(v) - 64)) if cands else [lo]
        return min(cands, key=lambda v: sum(min(abs(a - b) for b in prev) for a in v) + 0.3 * abs(np.mean(v) - 64))

    def bass_note(self, bar, step, tone):
        ch = self.chord_at(bar, step)
        root = 33 + ((self.key + ch[1] - 9) % 12)
        if tone == "R":
            return root
        if tone == "5":
            return root + 7
        if tone == "8":
            return root + 12
        if tone == "3":
            return root + ch[2][1]
        nxt = self.chord_at(bar + 1, 0)
        nroot = 33 + ((self.key + nxt[1] - 9) % 12)
        sp = self.scale_pcs(ch)
        for d in (-2, -1, 2):
            if (nroot + d) % 12 in sp and nroot + d != root:
                return nroot + d
        return root + 7

    # ---- placement
    def put(self, bus, x, at, gain=1.0, p=0.0):
        x = stereo(x)
        if p:
            x = pan(x, p)
        n = min(len(x), self.L + self.TAIL - at)
        self.bus[bus][at:at + n] += x[:n] * gain

    def note(self, bus, inst, midi, bar, step, length, vel=1.0, p=0.0, legato=0.92):
        ng = max(ns(0.03), int(length * self.step * legato))
        self.put(bus, render(inst, midi, ng), self.pos(bar, step), vel, p)

    def hit(self, name, bar, step, vel):
        if name == "kick":
            self.kicks.append(self.pos(bar, step))
        x = self.kit[name]
        h = self.r.normal(0, 1) * 0.0015 * SR if name in ("hat", "ohat", "shaker", "tamb") else 0
        at = (self.pos(bar, step) + int(h)) % self.L
        v = vel * (1 + self.r.normal(0, 0.05)) * DGAIN[name]
        self.put("drums", x, at, v, DPAN.get(name, 0.0))

    # ---- melody generator
    def melody(self, key, bars, rh_name, lo, hi):
        if key in self.score["melodies"]:
            return self.score["melodies"][key]
        r = seeded("melody", self.name, key)
        R1, R2 = RHYTHMS[rh_name]

        def contour(k, up_first):
            iv = [0]
            for j in range(1, k):
                sgn = 1 if (j < (k + 1) / 2) == up_first else -1
                if r.random() < 0.25:
                    sgn = -sgn
                iv.append(sgn * int(r.choice([0, 1, 1, 1, 2, 2, 3])))
            return iv

        m1, m2 = contour(len(R1), True), contour(len(R2), False)
        m2v = m2[:len(m2) // 2] + [-v for v in m2[len(m2) // 2:]]
        cad = CADENCES[int(r.integers(len(CADENCES)))]
        nb = len(bars)
        plan = [0, 1, 0, 2, 0, 1, 0, 3] if nb >= 8 else [0, 1, 0, 3]
        shifts = {0: 0, 2: 2, 4: 0, 6: -2}
        out, prev, anchor = [], None, None
        for bi, bar in enumerate(bars):
            kind = 3 if bi == nb - 1 else plan[bi % len(plan)]
            if kind == 3:
                ch = self.chord_at(bar, 8)
                cp, sp = self.chord_pcs(ch), self.scale_pcs(ch)
                fin = self.nearest(prev if prev else (lo + hi) // 2, [cp[0]])
                fin = fin + 12 if fin < lo else (fin - 12 if fin > hi else fin)
                d = -1 if (prev or fin) > fin else 1
                pitches = [self.sstep(fin, -2 * d, sp), self.sstep(fin, -d, sp), fin] if len(cad) == 3 else \
                    [self.sstep(fin, -3 * d, sp), self.sstep(fin, -2 * d, sp), self.sstep(fin, -d, sp), fin]
                for (st, ln), m in zip(cad, pitches):
                    out.append((bar, st, ln, m))
                prev = fin
                continue
            rh, iv = (R1, m1) if kind == 0 else ((R2, m2) if kind == 1 else (R2, m2v))
            for j, (st, ln) in enumerate(rh):
                ch = self.chord_at(bar, st)
                cp, sp = self.chord_pcs(ch), self.scale_pcs(ch)
                if j == 0 and kind == 0:
                    if anchor is None:
                        anchor = self.nearest((lo + hi) // 2 - 2, cp)
                    tgt = self.sstep(anchor, shifts.get(bi % 8, 0), sp)
                elif prev is None:
                    tgt = self.nearest((lo + hi) // 2, cp)
                else:
                    tgt = self.sstep(prev, iv[j], sp)
                    if not lo <= tgt <= hi:
                        tgt = self.sstep(prev, -iv[j], sp)
                if st % 4 == 0 or ln >= 4:
                    tgt = self.nearest(tgt, cp)
                while tgt > hi:
                    tgt -= 12
                while tgt < lo:
                    tgt += 12
                out.append((bar, st, ln, tgt))
                prev = tgt
        self.score["melodies"][key] = out
        return out

    # ---- arrangement
    def arrange(self):
        c = self.c
        bars = self.bars
        sections = []
        for b, bar in enumerate(bars):
            if bar["i"] == 0:
                sections.append((bar["sec"], bar["type"], list(range(b, b + bar["n"]))))
        lo, hi = c.get("lead_range", (67, 86))
        prev_voicing = None
        for si, (sec, typ, idx) in enumerate(sections):
            nxt_typ = sections[(si + 1) % len(sections)][1]
            # ----- melodies
            mel, minst = None, None
            if typ == "A":
                mel = self.melody("A", idx, c.get("lead_rh", "pop"), lo, hi)
                minst = [(c["lead"], 0, 1.0, 0.0)]
            elif typ == "B":
                mel = self.melody("B", idx, c.get("counter_rh", "lyric"), lo - 3, hi - 3)
                minst = [(c.get("counter", c["lead"]), 0, 0.95, 0.0)]
            elif typ == "C":
                mel = self.melody("C", idx, c.get("hook_rh", "anthem"), lo + 3, hi + 3)
                minst = [(h[0], h[1], h[2], h[3]) for h in c["hook"]]
            elif typ == "brk" and c.get("brk_inst"):
                mel = self.melody("brk", idx, "lyric", lo + 5, hi + 5)
                minst = [(c["brk_inst"], 0, 0.6, 0.15)]
            if mel:
                for k, (bar, st, ln, m) in enumerate(mel):
                    for inst, octv, vel, p in minst:
                        self.note("lead", inst, m + 12 * octv, bar, st, ln, vel * (1.0 if st % 4 == 0 else 0.88), p,
                                  0.98 if ln >= 4 else 0.85)
            # ----- harmony / bass / arp
            for k, b in enumerate(idx):
                bar = bars[b]
                chords = bar["chords"]
                for j, ch in enumerate(chords):
                    end = chords[j + 1][0] if j + 1 < len(chords) else 16
                    v = self.voicing(ch, prev_voicing)
                    prev_voicing = v
                    pad_inst = c["pad"] if typ != "C" else c.get("pad_c", c["pad"])
                    pad_vel = {"intro": 0.8, "A": 0.55 if c.get("stab") else 0.8, "B": 0.85, "C": 0.85, "brk": 1.0}[typ]
                    for m in v:
                        self.note("chords", pad_inst, m, b, ch[0], end - ch[0], pad_vel, 0.0, 1.0)
                    if c.get("stab") and typ in ("A", "C") or (c.get("stab") and typ == "B" and c.get("stab_b")):
                        sinst, spat = c["stab"]
                        for st, ln in STABS[spat]:
                            if ch[0] <= st < end:
                                for m in v:
                                    self.note("chords", sinst, m + c.get("stab_oct", 0) * 12, b, st, ln, 0.75, 0.0, 0.8)
                    if c.get("arp") and (typ in ("B", "C") or (typ in ("intro", "brk") and c.get("arp_intro", True))
                                         or (typ == "A" and (sec != "A" or c.get("arp_a")))):
                        ainst, apat = c["arp"]
                        tones = sorted(v) + [m + 12 for m in sorted(v)]
                        seqs = {"updown": [0, 1, 2, 3, 4, 3, 2, 1], "up": [0, 1, 2, 3, 4, 5, 4, 2], "broken": [0, 2, 1, 3, 2, 4, 3, 5]}
                        seq = seqs[apat]
                        rate = c.get("arp_rate", 1)
                        for st in range(ch[0], end, rate):
                            m = tones[seq[(st // rate) % len(seq)] % len(tones)] + 12 * c.get("arp_oct", 0)
                            self.note("arp", ainst, m, b, st, rate, 0.9 if st % 4 == 0 else 0.65, 0.25 if (st // rate) % 2 else -0.25, 0.8)
                pat = BASS["long"] if typ in ("intro", "brk") else BASS[c["bass_c"] if typ == "C" and c.get("bass_c") else c["bass"][1]]
                for st, ln, tone in pat:
                    self.note("bass", c["bass"][0], self.bass_note(b, st, tone), b, st, ln, 1.0 if st % 4 == 0 else 0.85, 0.0, 0.9)
                # ----- drums
                self.drum_bar(b, typ, k, len(idx), si, nxt_typ)
            # ----- section fx
            if typ == "C" or (typ == "A" and sections[si - 1][1] == "brk"):
                self.put("fx", boom(), self.pos(idx[0], 0), 0.9)
            if nxt_typ in ("C",) or typ == "brk":
                d = 2 * 16 * self.step / SR
                self.put("fx", riser(d, (self.name, si)), self.pos(idx[-1] - 1, 0), 0.8)
        if c.get("wind"):
            n = self.L
            r = seeded("wind", self.name)
            w = filt(r.uniform(-1, 1, (n, 2)), "bp", 600, 0.5, circular=True)
            t = np.arange(n) / n
            w *= (0.55 + 0.45 * np.sin(2 * np.pi * (3 * t + np.array([[0.0, 0.25]]).T.T)) ** 2)
            self.bus["fx"][:n] += norm(w) * 0.6

    def drum_bar(self, b, typ, k, nb, si, nxt_typ):
        c = self.c
        style = DRUMS[c["drums"]]
        last = k == nb - 1
        if typ == "brk":
            for st in range(0, 16, 2):
                self.hit("hat", b, st, 0.35 if st % 4 else 0.5)
            if k == 0:
                self.hit("kick", b, 0, 1.0)
                self.hit("crash", b, 0, 0.7)
            if last:
                for st in range(16):
                    self.hit("snare", b, st, 0.15 + 0.85 * (st / 15) ** 2)
            elif k == nb - 2:
                for st in range(0, 16, 2):
                    self.hit("snare", b, st, 0.1 + 0.25 * st / 16)
            return
        pat = dict(style["busy" if typ == "C" else "main"])
        if typ == "B" and "ohat" in style["busy"]:
            pat["ohat"] = style["busy"]["ohat"]
        for name, s in c.get("perc", {}).items():
            pat[name] = s
        if typ == "intro" and k < nb // 2:
            pat.pop("snare", None)
            pat.pop("clap", None)
        fill = None
        if last:
            fill = FILLS[int(seeded("fill", self.name, si).integers(len(FILLS)))]
        for name, s in pat.items():
            for st, ch in enumerate(s):
                if ch == "." or (fill and st >= 8 and name not in ("kick",) and name != "shaker"):
                    continue
                if fill and st >= 8 and name == "kick" and "kick" in fill:
                    continue
                self.hit(name, b, st, V[ch])
        if fill:
            for name, s in fill.items():
                for st, ch in enumerate(s):
                    if ch != ".":
                        self.hit(name, b, st, V[ch])
        if k == 0 and typ in ("intro", "A", "B", "C"):
            self.hit("crash", b, 0, {"intro": 0.6, "A": 0.8, "B": 0.7, "C": 1.0}[typ])
        if typ == "C" and k == nb // 2:
            self.hit("crash", b, 0, 0.6)

    # ---- mixdown
    def mix(self):
        L = self.L
        for b in self.bus:
            x = self.bus[b]
            x[:self.TAIL] += x[L:L + self.TAIL]
            self.bus[b] = x[:L].copy()
        B = self.bus
        B["chords"] = filt(B["chords"], "hp", 170, circular=True)
        B["lead"] = filt(B["lead"], "hp", 220, circular=True)
        B["arp"] = filt(B["arp"], "hp", 300, circular=True)
        B["bass"] = filt(B["bass"], "lp", 5000, circular=True)
        lv = dict(BUS_LEVEL, **self.c.get("levels", {}))
        for b in B:
            if np.any(B[b]):
                B[b] *= 10 ** ((lv[b] - active_rms_db(B[b])) / 20)
        # sidechain from the kick
        duck = np.zeros(L)
        kt = tarr(ns(0.35))
        shape = np.where(kt < 0.004, kt / 0.004, np.exp(-(kt - 0.004) / 0.1))
        for p in sorted(set(self.kicks)):
            n = len(shape)
            e = min(L, p + n)
            duck[p:e] += shape[:e - p]
            if p + n > L:
                duck[:p + n - L] += shape[L - p:]
        duck = np.minimum(duck, 1.0)
        dmul = self.c.get("duck", 1.0)
        for b, d in DUCK.items():
            B[b] = B[b] * (1 - d * dmul * duck)[:, None]
        # reverb (circular convolution with a synthetic stereo IR)
        rt = self.c.get("rt", 2.0)
        r = seeded("ir", self.name)
        ni = ns(min(rt * 1.2, 4.0))
        t = tarr(ni)
        ir = []
        for ch in range(2):
            nz = r.uniform(-1, 1, ni)
            lo_ = filt(nz, "lp", 600) * np.exp(-t * 6.9 / rt)
            mid = filt(filt(nz, "hp", 600), "lp", 4500) * np.exp(-t * 6.9 / (rt * 0.8))
            hi_ = filt(nz, "hp", 4500) * np.exp(-t * 6.9 / (rt * 0.4))
            x = (lo_ + mid + hi_) * np.minimum(t / 0.012, 1.0)
            pre = ns(0.018)
            x = np.concatenate([np.zeros(pre), x])[:ni]
            for d_, g_ in ((0.007, 0.5), (0.013, 0.35), (0.021, 0.3), (0.034, 0.25), (0.047, 0.18)):
                x[ns(d_ * (1.07 if ch else 1.0))] += g_ * (1 if r.random() < 0.5 else -1) * 3
            ir.append(x / np.sqrt(np.sum(x ** 2)))
        IR = np.zeros((L, 2))
        IR[:ni] = np.stack(ir, 1)
        send = dict(SEND, **self.c.get("send", {}))
        rin = sum(B[b] * send[b] for b in B)
        rin = filt(filt(rin.mean(1), "hp", 250, circular=True), "lp", 9000, circular=True)
        R = np.fft.rfft(rin)
        wet = np.stack([np.fft.irfft(R * np.fft.rfft(IR[:, ch]), L) for ch in range(2)], 1)
        # ping-pong delay (dotted eighth) on lead + arp
        din = (B["lead"] * 0.22 + B["arp"] * 0.15).mean(1)
        din = filt(filt(din, "hp", 400, circular=True), "lp", 5000, circular=True)
        dd = int(round(3 * self.step * self.c.get("delay_steps", 1.0)))
        dly = np.zeros((L, 2))
        for k in range(1, 7):
            dly[:, k % 2] += np.roll(din, k * dd) * (0.45 ** (k - 1))
        out = sum(B.values()) + wet * self.c.get("wet", 0.5) + dly * 0.6
        out = filt(out, "hp", 28, circular=True)
        out *= 10 ** ((MUSIC_RMS_DB - rms_db(out)) / 20)
        out, gr = limiter(out)
        return out, gr


def build_song(name, c):
    _cache.clear()
    s = Song(name, c)
    s.arrange()
    mix, gr = s.mix()
    os.makedirs(MUS_DIR, exist_ok=True)
    os.makedirs(SRC_DIR, exist_ok=True)
    with tempfile.TemporaryDirectory() as td:
        wav = os.path.join(td, name + ".wav")
        write_wav(wav, mix.ravel(), channels=2)
        ogg = os.path.join(MUS_DIR, name + ".ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", VORBIS_Q,
                        "-fflags", "+bitexact", "-flags:a", "+bitexact", "-map_metadata", "-1", ogg], check=True)
    sc = dict(s.score, melodies={k: [list(map(int, n)) for n in v] for k, v in s.score["melodies"].items()},
              bars=len(s.bars), seconds=round(s.L / SR, 3), samples=s.L,
              note="Score of the song generated by tools/gen_audio.py (melody notes: bar, 16th step, length in 16ths, MIDI).")
    with open(os.path.join(SRC_DIR, name + ".json"), "w") as f:
        json.dump(sc, f, indent=1)
    print("%-26s %5.1fs  bars %2d  limiter GR %.1f dB  rms %.1f dBFS  peak %.3f" % (name, s.L / SR, len(s.bars), gr, rms_db(mix), peak(mix)))


FORM_RACE = [("intro", 4), ("A", 8), ("B", 8), ("C", 8), ("brk", 4), ("A2", 8), ("C2", 8)]
SONGS = {
    # first course, sunny pine valley: happy pop-rock
    "track_vale_pinheiros": dict(
        bpm=144, key="D", mode="major", form=FORM_RACE, kit="punch", drums="pop",
        prog={"intro": ["I", "V", "vi", "IV"], "A": ["I", "V", "vi", "IV"], "B": ["IV", "V", "iii", "vi", "IV", "V", "ii", "V"],
              "C": ["I", "V", "vi", "IV"], "brk": ["vi", "IV", "I", "V"]},
        bass=("bass_saw", "eighths"), pad="pad_saw", stab=("pluck", "pop"), arp=("pluck", "updown"),
        lead="square", lead_rh="pop", counter="square", counter_rh="lyric", hook=[("supersaw", 0, 0.9, 0.0), ("bell", 1, 0.35, 0.2)],
        hook_rh="anthem", brk_inst="bell", rt=1.8),
    # frozen crystal lake: glassy, dreamy but driving (lydian II chord)
    "track_lago_cristal": dict(
        bpm=128, key="E", mode="lydian", form=FORM_RACE, kit="soft", drums="half",
        prog={"intro": ["Imaj7", "II", "vi", "V"], "A": ["Imaj7", "II", "vi", "V"], "B": ["IV", "II", "iii7", "vi"],
              "C": ["I", "II", "vi", "V"], "brk": ["IVmaj7", "II", "Imaj7", "V"]},
        bass=("bass_sub", "syncop"), pad="pad_glass", arp=("glass", "up"), arp_a=True,
        lead="bell", lead_rh="lyric", counter="flute", counter_rh="call", hook=[("pwm", 0, 0.85, 0.0), ("glass", 1, 0.5, -0.2)],
        hook_rh="bouncy", brk_inst="glass", rt=2.8, wet=0.7, levels={"arp": -9.0}),
    # volcano peak: aggressive minor rock
    "track_pico_vulcanico": dict(
        bpm=160, key="A", mode="minor", form=FORM_RACE, kit="rock", drums="rock",
        prog={"intro": ["i", "bVI", "bVII", "i"], "A": ["i", "bVI", "bVII", "i"], "B": ["iv", "v", "bVI", "bVII"],
              "C": ["i", "bVII", "bVI", "V"], "brk": ["bVI", "bVII", "i", "V"]},
        bass=("bass_dist", "gallop"), bass_c="eighths", pad="pad_dark", stab=("stab_power", "power"), stab_oct=-1,
        arp=("pluck", "broken"), lead="saw_lead", lead_rh="drive", counter="saw_lead", counter_rh="anthem",
        hook=[("supersaw", 0, 0.9, 0.0), ("saw_lead", -1, 0.45, 0.0)], hook_rh="fast", brk_inst="bell", rt=1.4, wet=0.4),
    # aurora night festival: disco / funk with brass and an arcade lead (triplet swing)
    "track_festival_boreal": dict(
        bpm=124, key="F", mode="mixo", swing=0.35, form=FORM_RACE, kit="tight", drums="disco",
        prog={"intro": ["I", "bVII", "IV", "I"], "A": ["I", "bVII", "IV", "I"], "B": ["vi", "IV", "bVII", "V"],
              "C": ["I", "bVII", "IV", "V"], "brk": ["IV", "bVII", "I", "V"]},
        bass=("bass_slap", "octave"), bass_c="funk", pad="pad_warm", stab=("brass", "charleston"),
        arp=("chip", "broken"), arp_oct=1, arp_rate=2, lead="chip", lead_rh="bouncy", counter="brass", counter_rh="syncop",
        hook=[("brass", 0, 0.9, 0.0), ("chip", 1, 0.45, 0.25)], hook_rh="call", brk_inst="ep", rt=1.6, duck=1.4),
    # giant forest: woody marimba + flute, laid-back shuffle
    "track_floresta_gigante": dict(
        bpm=122, key="G", mode="dorian", swing=0.4, form=[("intro", 4), ("A", 8), ("B", 8), ("C", 8), ("brk", 4), ("A2", 8), ("C2", 4)],
        kit="soft", drums="shuffle", perc={"wood": "..x.....x..x....", "shaker": "gogogogogogogogo"},
        prog={"intro": ["i", "IV", "i", "bVII"], "A": ["i", "IV", "i", "bVII"], "B": ["bIII", "IV", "v", "i"],
              "C": ["bVII", "IV", "i", "i"], "brk": ["bVI", "bVII", "i", "IV"]},
        bass=("bass_pick", "walk"), bass_c="syncop", pad="pad_warm", arp=("marimba", "broken"), arp_a=True,
        lead="flute", lead_rh="syncop", counter="marimba", counter_rh="bouncy", hook=[("flute", 0, 0.9, 0.0), ("marimba", 1, 0.45, 0.25)],
        hook_rh="pop", brk_inst="marimba", rt=2.2, levels={"arp": -9.5}),
    # abandoned station: mysterious breakbeat, acid bass, metallic clanks
    "track_estacao_abandonada": dict(
        bpm=134, key="C", mode="minor", swing=0.15, form=FORM_RACE, kit="tight", drums="break", perc={"clank": "......x.......x."},
        prog={"intro": ["i", "bVI", "bIII", "bVII"], "A": ["i", "bVI", "bIII", "bVII"], "B": ["iv", "i", "bVI", "V"],
              "C": ["i", "bVII", "bVI", "bVII"], "brk": ["bVI", "iv", "i", "V"]},
        bass=("bass_acid", "syncop"), bass_c="funk", pad="pad_dark", stab=("pluck", "offbeat"),
        arp=("bell", "broken"), arp_rate=2, lead="pwm", lead_rh="call", counter="ep", counter_rh="lyric",
        hook=[("saw_lead", 0, 0.9, 0.0), ("pwm", 1, 0.35, 0.2)], hook_rh="syncop", brk_inst="ep", rt=2.6, wet=0.6),
    # polar storm: epic, galloping, wind sweeps
    "track_tempestade_polar": dict(
        bpm=150, key="B", mode="minor", form=FORM_RACE, kit="deep", drums="rock", wind=True,
        prog={"intro": ["i", "bVI", "bIII", "bVII"], "A": ["i", "bVI", "bIII", "bVII"], "B": ["bVI", "bVII", "i", "i", "iv", "bVI", "bVII", "V"],
              "C": ["bVI", "bVII", "i", "V"], "brk": ["iv", "bVI", "i", "V"]},
        bass=("bass_saw", "gallop"), pad="pad_super", arp=("pluck", "updown"), arp_a=True,
        lead="saw_lead", lead_rh="anthem", counter="brass", counter_rh="lyric",
        hook=[("supersaw", 0, 0.9, 0.0), ("brass", -1, 0.5, 0.0)], hook_rh="drive", brk_inst="glass", rt=2.4,
        levels={"fx": -19.0}),
    # celestial summit: euphoric trance-pop
    "track_cume_celestial": dict(
        bpm=164, key="Eb", mode="major", form=FORM_RACE, kit="punch", drums="four",
        prog={"intro": ["IV", "V", "iii", "vi"], "A": ["IV", "V", "iii", "vi"], "B": ["ii", "IV", "V", "Vsus4 V"],
              "C": ["I", "V", "vi", "IV"], "brk": ["IV", "V", "vi", "V"]},
        bass=("bass_saw", "offbeat"), pad="pad_super", arp=("bell", "up"), arp_a=True, lead="supersaw", lead_rh="anthem",
        counter="pwm", counter_rh="call", hook=[("supersaw", 0, 0.95, 0.0), ("bell", 1, 0.4, 0.2)], hook_rh="fast",
        brk_inst="bell", rt=2.6, duck=1.6, wet=0.6),
    # trick park: fast ska-punk with organ skank and brass
    "track_parque_manobras": dict(
        bpm=152, key="A", mode="major", form=FORM_RACE, kit="rock", drums="ska",
        prog={"intro": ["I", "IV", "V", "IV"], "A": ["I", "IV", "V", "IV"], "B": ["vi", "IV", "I", "V"],
              "C": ["I", "iii", "IV", "V"], "brk": ["IV", "V", "vi", "V"]},
        bass=("bass_pick", "walk"), bass_c="eighths", pad="pad_warm", stab=("organ", "offbeat"), stab_b=True,
        arp=("chip", "updown"), arp_oct=1, arp_rate=2, lead="brass", lead_rh="ska", counter="chip", counter_rh="pop",
        hook=[("brass", 0, 0.9, 0.0), ("chip", 1, 0.4, 0.25)], hook_rh="bouncy", brk_inst="organ", rt=1.5, wet=0.4),
    "menu": dict(
        bpm=116, key="C", mode="major", form=[("intro", 4), ("A", 8), ("B", 8), ("C", 8), ("A2", 8)], kit="soft", drums="pop",
        prog={"intro": ["Imaj7", "vi7", "IVmaj7", "V"], "A": ["I", "vi", "IV", "V"], "B": ["IV", "V", "iii", "vi"], "C": ["IV", "V", "I", "vi", "ii", "IV", "Vsus4", "V"]},
        bass=("bass_pick", "syncop"), pad="pad_warm", stab=("ep", "charleston"), arp=("bell", "broken"), arp_rate=2,
        lead="marimba", lead_rh="bouncy", counter="flute", counter_rh="lyric", hook=[("square", 0, 0.8, 0.0), ("bell", 1, 0.4, 0.2)],
        hook_rh="pop", rt=2.0),
    "results": dict(
        bpm=96, key="F", mode="major", swing=0.3, form=[("intro", 4), ("A", 8), ("B", 8), ("A2", 8)], kit="soft", drums="half",
        prog={"intro": ["IVmaj7", "iii7", "ii7", "Imaj7"], "A": ["Imaj7", "vi7", "ii7", "V7"], "B": ["IVmaj7", "iii7", "vi7", "V7"]},
        bass=("bass_sub", "sub"), pad="pad_glass", stab=("ep", "charleston"), arp=("marimba", "broken"), arp_rate=2,
        lead="ep", lead_rh="lyric", counter="flute", counter_rh="lyric", hook=[("flute", 0, 0.9, 0.0)], rt=2.4, wet=0.6),
    "victory": dict(
        bpm=136, key="G", mode="major", form=[("A", 8), ("B", 8), ("C", 8)], kit="punch", drums="pop",
        prog={"A": ["I", "IV", "V", "I", "vi", "IV", "Vsus4", "V"], "B": ["IV", "V", "iii", "vi", "ii", "V", "I", "V"], "C": ["I", "V", "vi", "IV"]},
        bass=("bass_saw", "eighths"), pad="pad_saw", stab=("brass", "pop"), arp=("bell", "updown"),
        lead="brass", lead_rh="anthem", counter="square", counter_rh="pop", hook=[("supersaw", 0, 0.9, 0.0), ("brass", -1, 0.5, 0.0)],
        hook_rh="anthem", rt=1.8),
}


# ============================================================================ SFX
def _noise(name, n):
    return seeded("sfx", name).uniform(-1, 1, n)


def place(buf, x, t0, g=1.0):
    a = ns(t0)
    n = min(len(x), len(buf) - a)
    buf[a:a + n] += x[:n] * g
    return buf


def thump(d, f0, f1, tau_f, tau_a, name):
    n = ns(d)
    t = tarr(n)
    fr = f1 + (f0 - f1) * np.exp(-t / tau_f)
    return np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.exp(-t / tau_a) + filt(_noise(name + "c", n), "hp", 2000) * np.exp(-t / 0.002) * 0.3


def crunch(d, tau, name, fc=2200):
    n = ns(d)
    t = tarr(n)
    nz = _noise(name, n)
    grain = filt(np.abs(_noise(name + "g", n)) ** 3, "lp", 90)
    grain = grain / peak(grain)
    return filt(nz, "bp", fc, 0.8) * np.exp(-t / tau) * (0.35 + 0.65 * grain) + filt(nz, "lp", 900) * np.exp(-t / (tau * 1.8)) * 0.6


def whoosh(d, f0, f1, name, q=1.4, shape=0.35):
    n = ns(d)
    t = tarr(n)
    fc = f0 * (f1 / f0) ** (t / d)
    x = tvfilt(_noise(name, n), fc, q, "bp")
    e = np.sin(np.pi * np.clip(t / d, 0, 1) ** shape) ** 2
    return x * e


def tone_seq(notes, inst, gap, hold=0.1, vels=None):
    """notes: list of MIDI; returns mono sum of instrument notes spaced by `gap` seconds."""
    parts = []
    for i, m in enumerate(notes):
        x = INSTR[inst](midi_f(m), ns(hold if i < len(notes) - 1 else hold * 2), seeded("tone", inst, m, i)).mean(1)
        parts.append((i * gap, x * (vels[i] if vels else 1.0)))
    n = max(ns(t0) + len(x) for t0, x in parts)
    buf = np.zeros(n)
    for t0, x in parts:
        place(buf, x, t0)
    return buf


def shards(d, count, fmin, fmax, name, spread=0.3):
    r = seeded("shards", name)
    buf = np.zeros(ns(d))
    for i in range(count):
        t0 = r.exponential(spread / 3)
        if t0 > d - 0.15:
            continue
        f = r.uniform(fmin, fmax)
        tau = r.uniform(0.02, 0.1)
        n = ns(min(6 * tau, 0.5))
        x = np.sin(2 * np.pi * f * tarr(n) + r.uniform(0, 6)) * np.exp(-tarr(n) / tau) * r.uniform(0.3, 1.0) * np.exp(-t0 * 4)
        place(buf, x, t0)
    return buf


def fade_edges(x, fin=0.0008, fout=0.006):
    x = x.copy()
    a, b = max(1, ns(fin)), max(1, ns(fout))
    x[:a] *= np.linspace(0, 1, a)
    x[-b:] *= np.linspace(1, 0, b)
    return x


def make_sfx():
    os.makedirs(SFX_DIR, exist_ok=True)
    out = {}

    def S(name, x, pk=CEIL):
        x = np.asarray(x, float)
        x = x - np.mean(x) * np.hanning(len(x)) / np.mean(np.hanning(len(x)))   # remove DC without a step
        out[name] = fade_edges(norm(x, pk))

    def LOOP(name, x, pk=CEIL):
        out[name] = norm(x - x.mean(), pk)

    # ---- loops: 2.0 s, generated circularly (periodic noise, LFOs with whole periods over the loop)
    n = ns(2.0)
    t = tarr(n)
    w = filt(_noise("wind", n), "bp", 520, 0.45, circular=True)
    whistle = filt(_noise("wind_w", n), "bp", 820, 22, circular=True) * (0.5 + 0.5 * np.sin(2 * np.pi * 1.0 * t)) \
        + filt(_noise("wind_w2", n), "bp", 1240, 26, circular=True) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.5 * t + 2))
    LOOP("wind_loop", w * (0.7 + 0.3 * np.sin(2 * np.pi * 0.5 * t)) + whistle * 0.25)
    grain = filt(np.abs(_noise("carve_g", n)) ** 3, "lp", 45, circular=True)
    grain /= peak(grain)
    c = filt(_noise("carve", n), "bp", 1900, 0.7, circular=True) + 0.5 * filt(_noise("carve_h", n), "hp", 5000, circular=True)
    LOOP("carve_loop", c * (0.45 + 0.55 * grain) * (0.85 + 0.15 * np.sin(2 * np.pi * 4.0 * t)))
    g2 = filt(np.abs(_noise("snow_g", n)) ** 4, "lp", 70, circular=True)
    g2 /= peak(g2)
    LOOP("snow_loop", filt(_noise("snow", n), "lp", 1300, circular=True) * (0.6 + 0.4 * g2)
         + filt(_noise("snow_c", n), "bp", 3000, 1.2, circular=True) * g2 * 0.6)
    g3 = filt(np.abs(_noise("ice_g", n)) ** 2, "lp", 120, circular=True)
    g3 /= peak(g3)
    LOOP("ice_loop", (filt(_noise("ice", n), "hp", 3200, circular=True) * 0.6 + filt(_noise("ice_r", n), "bp", 6200, 3, circular=True))
         * (0.4 + 0.6 * g3) * (0.9 + 0.1 * np.sin(2 * np.pi * 6.0 * t)))

    # ---- movement
    jump = whoosh(0.34, 500, 3800, "jump", 1.3, 0.3) * 0.9
    n = ns(0.34)
    t = tarr(n)
    place(jump, filt(_noise("jump_p", n), "lp", 1600) * np.exp(-t / 0.03) * 0.9, 0)
    place(jump, sine(300 * 2 ** (t / 0.34 * 1.3), n) * np.exp(-t / 0.1) * 0.22, 0.005)
    S("jump", jump)
    land = np.zeros(ns(0.35))
    place(land, thump(0.35, 130, 52, 0.025, 0.07, "land"), 0)
    place(land, crunch(0.35, 0.06, "land_c"), 0.003, 0.8)
    S("land", land)
    lh = np.zeros(ns(0.6))
    place(lh, thump(0.6, 150, 40, 0.035, 0.14, "lh"), 0, 1.2)
    place(lh, crunch(0.6, 0.12, "lh_c", 1800), 0.002, 1.0)
    n = ns(0.6)
    t = tarr(n)
    place(lh, filt(_noise("lh_k", n), "bp", 1400, 4) * np.exp(-t / 0.012) * 0.8, 0.004)
    place(lh, filt(_noise("lh_s", n), "hp", 3000) * np.sin(np.pi * np.clip(t / 0.4, 0, 1)) * np.exp(-t / 0.15) * 0.35, 0.02)
    S("land_hard", np.tanh(1.4 * lh))
    cr = np.zeros(ns(1.15))
    for i, (t0, g) in enumerate(((0, 1.0), (0.17, 0.75), (0.31, 0.55), (0.43, 0.35))):
        place(cr, thump(0.4, 140, 45, 0.03, 0.09, "cr%d" % i), t0, g)
        place(cr, crunch(0.4, 0.08, "crc%d" % i, 1700), t0 + 0.003, g * 0.9)
    place(cr, whoosh(1.0, 3200, 700, "cr_spray", 0.8, 0.2), 0.02, 0.45)
    n = ns(0.75)
    t = tarr(n)
    wah = tvfilt(saw(480 * (150 / 480) ** (t / 0.75), n), 600 + 2500 * (0.5 + 0.5 * np.sin(2 * np.pi * 5 * t)), 3.0)
    place(cr, wah * np.exp(-t / 0.4) * 0.22, 0.08)
    S("crash", np.tanh(1.3 * cr))
    S("throw", whoosh(0.32, 2600, 900, "throw", 1.2, 0.25))

    # ---- impacts
    hit = np.zeros(ns(0.42))
    place(hit, thump(0.42, 190, 60, 0.02, 0.09, "hit"), 0, 1.1)
    n = ns(0.42)
    t = tarr(n)
    place(hit, filt(_noise("hit_s", n), "bp", 1800, 0.8) * np.exp(-t / 0.028), 0)
    bonk = fm(640 * (330 / 640) ** np.minimum(t / 0.12, 1), 1.5, 2.5 * np.exp(-t / 0.05), n) * np.exp(-t / 0.12)
    place(hit, bonk * 0.55, 0.004)
    S("hit", np.tanh(1.2 * hit))
    ib = shards(0.75, 45, 2500, 8500, "ice_burst", 0.35)
    n = ns(0.75)
    t = tarr(n)
    ib += filt(_noise("ib_c", n), "hp", 2000) * np.exp(-t / 0.018) * 1.2
    ib += thump(0.75, 120, 70, 0.02, 0.07, "ib") * 0.7
    ib += filt(_noise("ib_t", n), "hp", 5000) * np.exp(-t / 0.25) * 0.15
    S("ice_burst", ib)
    sb = shards(0.7, 35, 3000, 9500, "shield_break", 0.3)
    n = ns(0.7)
    t = tarr(n)
    sb += filt(_noise("sb_c", n), "hp", 2500) * np.exp(-t / 0.02)
    for f in (1046.5, 1318.5, 1568.0):
        sb += sine(f * 2 ** (-t / 0.7 * 0.9), n) * np.exp(-t / 0.22) * 0.25
    S("shield_break", sb)

    # ---- pickups / UI / jingles
    coin = np.zeros(ns(0.5))
    place(coin, (pulse(987.77, ns(0.075)) * 0.6 + sine(987.77, ns(0.075)) * 0.4) * np.exp(-tarr(ns(0.075)) / 0.08), 0)
    n = ns(0.42)
    t = tarr(n)
    place(coin, (pulse(1318.5, n) * 0.55 + sine(1318.5, n) * 0.45) * np.exp(-t / 0.16), 0.07)
    place(coin, fm(2637, 3.5, 1.2 * np.exp(-t / 0.05), n) * np.exp(-t / 0.12) * 0.2, 0.07)
    S("coin", filt(coin, "lp", 9000))
    buy = tone_seq([88, 92, 95], "bell", 0.05, 0.05) * 0.7
    n = ns(0.75)
    t = tarr(n)
    ching = fm(2637, 2.76, 2.0 * np.exp(-t / 0.1) + 0.3, n) * np.exp(-t / 0.3) + filt(_noise("ching", n), "hp", 7000) * np.exp(-t / 0.08) * 0.4
    b2 = np.zeros(ns(0.95))
    place(b2, buy, 0)
    place(b2, ching, 0.15, 0.8)
    S("buy", b2)
    bf = np.zeros(ns(0.5))
    for t0, f, d in ((0, 220, 0.12), (0.15, 174.6, 0.28)):
        n = ns(d)
        t = tarr(n)
        x = filt(pulse(f * (1 - 0.03 * t / d), n, 0.4) + 0.5 * saw(f * 1.01, n), "lp", 1400, 1.2) * adsr(n - ns(0.03), 0.004, 0.1, 0.7, 0.03)[:n]
        place(bf, x, t0)
    S("buy_fail", bf, CEIL * 0.85)
    S("gate", tone_seq([88], "bell", 0, 0.08) + 0.5 * tone_seq([100], "glass", 0, 0.05))
    S("perfect", tone_seq([84, 88, 91, 96, 100], "bell", 0.055, 0.06, [0.7, 0.75, 0.8, 0.9, 1.0])
      + np.pad(shards(0.9, 30, 4000, 9000, "perfect", 0.6) * 0.3, (0, 0)))
    S("lap", tone_seq([79, 83, 86, 91], "pluck", 0.08, 0.07) * 0.8 + tone_seq([79, 83, 86, 91], "bell", 0.08, 0.07) * 0.5)
    um = np.zeros(ns(0.07))
    n = ns(0.07)
    t = tarr(n)
    um += sine(1500 * (1 - 0.2 * t / 0.07), n) * np.exp(-t / 0.018)
    um += filt(_noise("ui_move", n), "bp", 4000, 2) * np.exp(-t / 0.003) * 0.5
    S("ui_move", um, CEIL * 0.8)
    S("ui_ok", tone_seq([88, 93], "marimba", 0.065, 0.06) + 0.35 * tone_seq([100, 105], "bell", 0.065, 0.05))
    S("ui_back", tone_seq([81, 76], "marimba", 0.065, 0.06), CEIL * 0.85)
    uo = np.zeros(ns(0.55))
    place(uo, whoosh(0.18, 700, 3500, "ui_open", 1.5, 0.4), 0, 0.6)
    place(uo, tone_seq([91], "bell", 0, 0.06), 0.09, 0.8)
    S("ui_open", uo, CEIL * 0.9)
    S("count", tone_seq([69], "square", 0, 0.22) * 0.8 + tone_seq([81], "bell", 0, 0.1) * 0.35)
    n = ns(1.0)
    go = np.zeros(n)
    for m in (81, 85, 88, 93):
        place(go, INSTR["square"](midi_f(m), ns(0.55), seeded("go", m)).mean(1), 0, 0.5)
        place(go, INSTR["bell"](midi_f(m + 12), ns(0.2), seeded("gob", m)).mean(1), 0, 0.18)
    place(go, whoosh(0.6, 1500, 9000, "go", 1.0, 0.2), 0, 0.25)
    S("count_go", go)
    fin = np.zeros(ns(1.9))
    for t0, notes, d in ((0.0, (79, 76), 0.09), (0.12, (79, 76), 0.09), (0.24, (79, 76), 0.09), (0.36, (84, 79, 76), 0.85)):
        for m in notes:
            place(fin, INSTR["brass"](midi_f(m), ns(d), seeded("fin", m, t0)).mean(1), t0, 0.45)
            place(fin, INSTR["supersaw"](midi_f(m), ns(d), seeded("fins", m, t0)).mean(1), t0, 0.15)
    kit = make_kit("punch", "sfx")
    place(fin, kit["crash"].mean(1), 0.36, 0.45)
    place(fin, kit["tom_lo"], 0.36, 0.6)
    for i, t0 in enumerate((0.0, 0.12, 0.24)):
        place(fin, kit["snare"], t0, 0.35)
    S("finish", fin)
    un = np.zeros(ns(1.5))
    place(un, tone_seq([84, 88, 91, 96], "bell", 0.075, 0.07), 0)
    n = ns(1.2)
    t = tarr(n)
    for m in (84, 88, 91, 96):
        place(un, INSTR["pad_glass"](midi_f(m), ns(0.7), seeded("un", m)).mean(1) * (1 + 0.3 * np.sin(2 * np.pi * 11 * tarr(ns(0.7) + ns(1.2))))[:ns(0.7) + ns(1.2)], 0.25, 0.4)
    place(un, whoosh(0.5, 1000, 8000, "unlock", 1.0, 0.6), 0.0, 0.25)
    place(un, shards(1.2, 25, 4000, 9000, "unlock", 0.8), 0.25, 0.25)
    S("unlock", un)

    # ---- items
    pg = np.zeros(ns(0.5))
    for i, (t0, f0, f1) in enumerate(((0.0, 620, 900), (0.14, 600, 860), (0.28, 700, 1050))):
        n = ns(0.11)
        t = tarr(n)
        fr = f0 + (f1 - f0) * np.sin(np.pi * t / 0.11)
        src = saw(fr, n) + 0.4 * pulse(fr * 0.5, n, 0.3)
        q = filt(src, "bp", 1100, 3) + 0.7 * filt(src, "bp", 2500, 4)
        place(pg, q * adsr(n - ns(0.02), 0.004, 0.05, 0.8, 0.02)[:n], t0)
    S("penguin", pg)
    md = np.zeros(ns(0.5))
    n = ns(0.3)
    t = tarr(n)
    place(md, fm(330, 1.41, 4 * np.exp(-t / 0.05) + 0.5, n) * np.exp(-t / 0.1) + thump(0.3, 140, 90, 0.02, 0.05, "md") * 0.8, 0)
    for t0 in (0.2, 0.33):
        nb = ns(0.06)
        place(md, filt(pulse(1760, nb, 0.5), "lp", 6000) * adsr(nb - ns(0.01), 0.002, 0.05, 0.8, 0.01)[:nb] * 0.35, t0)
    S("mine_drop", md)
    n = ns(1.3)
    t = tarr(n)
    fog = tvfilt(_noise("fog", n), 300 + 1200 * np.sin(np.pi * np.clip(t / 0.6, 0, 1)) ** 2 + 300 * np.exp(-t), 0.7)
    fog *= (1 - np.exp(-t / 0.08)) * np.exp(-t / 0.45)
    fog += filt(_noise("fog_r", n), "lp", 150) * np.exp(-t / 0.3) * 0.8
    S("fog", fog)
    n = ns(1.1)
    t = tarr(n)
    wv = tvfilt(_noise("wave", n), 400 + 2600 * np.sin(np.pi * np.clip(t / 0.7, 0, 1)) ** 1.5, 0.8)
    wv *= np.sin(np.pi * np.clip(t / 1.1, 0, 1) ** 0.5)
    wv += sine(70 * (40 / 70) ** (t / 1.1), n) * np.exp(-t / 0.35) * 0.9
    wv += filt(_noise("wave_s", n), "hp", 3500) * np.exp(-((t - 0.35) / 0.12) ** 2) * 0.5
    S("wave", np.tanh(1.2 * wv))
    n = ns(0.85)
    t = tarr(n)
    fr = 110 * (440 / 110) ** np.minimum(t / 0.55, 1)
    b = (saw(fr * 1.006, n) + saw(fr * 0.994, n) + saw(fr * 2, n) * 0.5) / 2.5
    b = tvfilt(b, 400 + 6000 * np.minimum(t / 0.5, 1), 1.6) * adsr(ns(0.55), 0.01, 0.3, 0.8, 0.3)[:n]
    bo = b + whoosh(0.85, 700, 6000, "boost", 1.0, 0.25) * 0.8 + thump(0.85, 120, 50, 0.03, 0.1, "boost") * 0.6
    S("boost", np.tanh(1.3 * bo))
    sh = np.zeros(ns(1.1))
    place(sh, tone_seq([84, 88, 91, 96], "glass", 0.045, 0.06), 0)
    n = ns(1.1)
    t = tarr(n)
    shim = sum(sine(midi_f(m), n) for m in (96, 100, 103)) * (0.6 + 0.4 * np.sin(2 * np.pi * 12 * t)) * np.sin(np.pi * np.clip(t / 1.1, 0, 1)) * 0.15
    S("shield", sh + shim)
    n = ns(0.6)
    t = tarr(n)
    fr = 170 * 2 ** (1.4 * t / 0.6) * (1 + 0.28 * np.exp(-t / 0.14) * np.sin(2 * np.pi * 21 * t))
    sp = (sine(fr, n) + 0.35 * tri(fr, n)) * np.exp(-t / 0.28) + thump(0.6, 120, 80, 0.02, 0.06, "spring") * 0.5
    S("spring", sp)
    n = ns(0.85)
    t = tarr(n)
    fr = 110 * (165 / 110) ** (t / 0.85)
    mg = tvfilt(saw(fr, n) + 0.5 * saw(fr * 1.5, n), 500 + 1700 * (0.5 + 0.5 * np.sin(2 * np.pi * 9 * t)), 3.5)
    mg *= adsr(ns(0.6), 0.05, 0.3, 0.8, 0.25)[:n]
    mg += shards(0.85, 12, 3000, 6000, "magnet", 0.8) * 0.4
    S("magnet", mg)
    rp = np.zeros(ns(0.85))
    for i in range(4):
        nn = ns(0.04)
        place(rp, filt(_noise("rp%d" % i, nn), "bp", 3200, 5) * np.exp(-tarr(nn) / 0.006), i * 0.055)
    place(rp, tone_seq([84, 88, 91], "marimba", 0.07, 0.06) + 0.4 * tone_seq([96, 100, 103], "bell", 0.07, 0.05), 0.24)
    S("repair", rp)
    n = ns(0.65)
    t = tarr(n)
    gr_ = filt(_noise("grind", n), "bp", 2800, 6) + 0.8 * filt(_noise("grind2", n), "bp", 5200, 8)
    jit = filt(np.abs(_noise("grind_j", n)), "lp", 60)
    gr_ = gr_ * (0.5 + 0.5 * jit / peak(jit)) + sine(1900 * (1 + 0.01 * np.sin(2 * np.pi * 7 * t)), n) * 0.08
    S("grind", gr_ * adsr(ns(0.5), 0.01, 0.2, 0.8, 0.15)[:n])
    n = ns(1.5)
    t = tarr(n)
    hum = filt(saw(50 * (1 + 0.01 * np.sin(2 * np.pi * 0.7 * t)), n) + 0.5 * saw(100, n), "lp", 320, 1.2)
    lift = hum * np.minimum(t / 0.25, 1) * np.minimum((1.5 - t) / 0.4, 1)
    for t0 in (0.35, 1.0):
        nn = ns(0.3)
        tt = tarr(nn)
        place(lift, fm(260, 1.41, 5 * np.exp(-tt / 0.04), nn) * np.exp(-tt / 0.08) * 0.6
              + filt(_noise("liftc%.2f" % t0, nn), "bp", 900, 2) * np.exp(-tt / 0.02) * 0.6, t0)
    S("lift", lift)
    for name, x in out.items():
        write_wav(os.path.join(SFX_DIR, name + ".wav"), x)
    return out


# ============================================================================ verification
def verify():
    print("== music (decoded OGG)")
    print("%-26s %7s %7s %7s %8s %9s %8s" % ("file", "sec", "peak", "rmsdB", "clipped", "seam/p99", "KB"))
    tot = 0
    ok = True
    for f in sorted(os.listdir(MUS_DIR)):
        if not f.endswith(".ogg"):
            continue
        p = os.path.join(MUS_DIR, f)
        x = read_audio(p)
        d = np.abs(np.diff(x, axis=0)).max(1)
        seam = np.abs(x[0] - x[-1]).max()
        p99 = np.percentile(d, 99)
        clipped = int(np.sum(np.abs(x) >= 0.999))
        kb = os.path.getsize(p) / 1024
        tot += kb
        sc = os.path.join(SRC_DIR, f[:-4] + ".json")
        exp = json.load(open(sc))["samples"] if os.path.exists(sc) else len(x)
        ok &= clipped == 0 and seam <= 2 * p99 and len(x) == exp
        print("%-26s %7.2f %7.3f %7.1f %8d %9.2f %8.0f %s" % (f, len(x) / SR, abs(x).max(), rms_db(x), clipped, seam / p99, kb,
                                                           "" if len(x) == exp else "LENGTH %d != %d" % (len(x), exp)))
    print("music total %.1f MB" % (tot / 1024))
    print("== sfx")
    tot = 0
    for f in sorted(os.listdir(SFX_DIR)):
        if not f.endswith(".wav"):
            continue
        p = os.path.join(SFX_DIR, f)
        with wave.open(p) as w:
            sr, ch = w.getframerate(), w.getnchannels()
            x = np.frombuffer(w.readframes(w.getnframes()), "<i2") / 32768.0
        tot += os.path.getsize(p) / 1024
        extra = ""
        if f.endswith("_loop.wav"):
            dd = np.abs(np.diff(x))
            extra = "seam/p99 %.2f" % (abs(x[0] - x[-1]) / np.percentile(dd, 99))
        clipped = int(np.sum(np.abs(x) >= 0.999))
        ok &= clipped == 0
        print("%-18s %5d Hz %dch %6.3fs peak %.3f rms %6.1f dB clipped %d %s" % (f, sr, ch, len(x) / sr, abs(x).max(), rms_db(x), clipped, extra))
    print("sfx total %.1f MB" % (tot / 1024))
    print("VERIFY", "OK" if ok else "FAILED")
    return ok


if __name__ == "__main__":
    args = sys.argv[1:]
    if "--verify" in args:
        sys.exit(0 if verify() else 1)
    do_sfx = not args or "--sfx" in args
    do_music = not args or "--music" in args
    names = [a for a in args if not a.startswith("--")] or list(SONGS)
    if do_sfx:
        print("sfx", len(make_sfx()))
    if do_music:
        for nm in names:
            build_song(nm, SONGS[nm])
