#!/usr/bin/env python3
"""Generates tileable material textures (albedo + normal + roughness) for Snowboard Legends 3D.
Method: scripted noise synthesis with fixed seeds (deterministic). Output: assets/textures/*.png
"""
import numpy as np
from PIL import Image
import os, sys

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
os.makedirs(OUT, exist_ok=True)
N = 512


def tile_noise(n, octaves, seed, base=4):
    rng = np.random.default_rng(seed)
    acc = np.zeros((n, n), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        f = base * (2 ** o)
        g = rng.random((f, f)).astype(np.float32)
        # bicubic-ish periodic upsample
        img = Image.fromarray((g * 255).astype(np.uint8)).resize((n, n), Image.BICUBIC)
        g2 = np.asarray(img, np.float32) / 255.0
        # wrap blend to keep tileable
        g2 = (g2 + np.roll(g2, n // 2, 0) + np.roll(g2, n // 2, 1)) / 3.0
        acc += g2 * amp
        tot += amp
        amp *= 0.5
    acc /= tot
    return (acc - acc.min()) / (np.ptp(acc) + 1e-6)


def normal_from_height(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    nz = np.ones_like(h)
    l = np.sqrt(dx * dx + dy * dy + nz * nz)
    n = np.stack([-dx / l, -dy / l, nz / l], -1)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def save(name, arr):
    Image.fromarray(arr).save(os.path.join(OUT, name + ".png"), optimize=True)


def colorize(h, c0, c1):
    c0 = np.array(c0, np.float32); c1 = np.array(c1, np.float32)
    return np.clip(c0 + (c1 - c0) * h[..., None], 0, 255).astype(np.uint8)


def snow(name, c0, c1, grooves=True, seed=1):
    h = tile_noise(N, 6, seed)
    if grooves:
        x = np.linspace(0, 1, N, endpoint=False)
        g = 0.5 + 0.5 * np.sin(x * np.pi * 2 * 24)  # groomed corduroy lines along V
        g = g[None, :] * (0.65 + 0.35 * tile_noise(N, 3, seed + 7))
        h2 = h * 0.45 + g * 0.55
    else:
        h2 = h
    save(name + "_albedo", colorize(h2, c0, c1))
    save(name + "_normal", normal_from_height(h2, 3.0 if grooves else 2.0))


def rock(name, c0, c1, seed):
    h = tile_noise(N, 7, seed, base=3)
    cracks = np.abs(tile_noise(N, 4, seed + 3, base=6) - 0.5) < 0.03
    h = np.where(cracks, h * 0.4, h)
    save(name + "_albedo", colorize(h, c0, c1))
    save(name + "_normal", normal_from_height(h, 6.0))


def wood(name, c0, c1, seed):
    y = np.linspace(0, 1, N, endpoint=False)
    n = tile_noise(N, 4, seed)
    rings = 0.5 + 0.5 * np.sin((y[:, None] * 40 + n * 6) * np.pi)
    planks = (np.floor(np.linspace(0, 4, N, endpoint=False))[None, :] % 2) * 0.15
    h = np.clip(rings * 0.7 + planks + n * 0.2, 0, 1)
    edge = (np.linspace(0, 4, N, endpoint=False) % 1.0)
    h = np.where((edge < 0.02)[None, :] | (edge > 0.98)[None, :], 0.0, h)
    save(name + "_albedo", colorize(h, c0, c1))
    save(name + "_normal", normal_from_height(h, 2.0))


def metal(name, c0, c1, seed):
    n = tile_noise(N, 5, seed)
    brushed = tile_noise(N, 2, seed + 1)[:, :1].repeat(N, 1) * 0.3
    h = np.clip(n * 0.5 + brushed, 0, 1)
    save(name + "_albedo", colorize(h, c0, c1))
    save(name + "_normal", normal_from_height(h, 1.0))


def main():
    snow("snow_day", (214, 226, 242), (252, 253, 255), True, 11)
    snow("snow_soft", (200, 215, 238), (248, 251, 255), False, 12)
    snow("snow_night", (120, 140, 190), (205, 215, 245), True, 13)
    snow("snow_ash", (170, 165, 170), (232, 228, 230), True, 14)
    snow("snow_storm", (190, 205, 222), (240, 246, 252), False, 15)
    snow("snow_sky", (215, 220, 250), (255, 250, 255), True, 16)
    snow("ice", (120, 190, 230), (205, 240, 255), False, 17)
    rock("rock_grey", (70, 74, 84), (150, 152, 160), 21)
    rock("rock_volcanic", (28, 22, 24), (92, 70, 66), 22)
    rock("rock_blue", (60, 80, 110), (140, 160, 190), 23)
    wood("wood_plank", (96, 58, 32), (170, 112, 64), 31)
    wood("bark", (58, 40, 30), (110, 80, 58), 32)
    metal("metal_steel", (90, 96, 104), (170, 178, 186), 41)
    metal("metal_rust", (90, 50, 30), (160, 100, 60), 42)
    print("textures ->", os.path.abspath(OUT), len(os.listdir(OUT)))


if __name__ == "__main__":
    main()
