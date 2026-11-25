#!/usr/bin/env python3
"""Generates 2D sprites (RGBA PNG): VFX particles, medals, warning/direction indicators, illustrated course maps,
and a packed atlas with JSON metadata (pivots, padding, frames). Item icons / portraits / board thumbnails are
rendered from the 3D models with Blender (render_objects.py / render_rider.py)."""
import os, sys, json, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.dirname(__file__))
FX = os.path.join(ROOT, "assets", "sprites", "fx")
UI = os.path.join(ROOT, "assets", "sprites", "ui")
MAPS = os.path.join(ROOT, "assets", "sprites", "maps")
for d in (FX, UI, MAPS):
    os.makedirs(d, exist_ok=True)


def radial(n, inner=0.0, power=2.0):
    y, x = np.mgrid[0:n, 0:n] / (n - 1) * 2 - 1
    r = np.sqrt(x * x + y * y)
    return np.clip(1 - (r - inner) / (1 - inner), 0, 1) ** power


def save_rgba(path, rgb, alpha):
    a = (np.clip(alpha, 0, 1) * 255).astype(np.uint8)
    img = np.dstack([np.broadcast_to(np.array(rgb, np.uint8), a.shape + (3,)), a])
    Image.fromarray(img, "RGBA").save(path)


def star_poly(cx, cy, r1, r2, n=5, rot=-math.pi / 2):
    pts = []
    for i in range(n * 2):
        r = r1 if i % 2 == 0 else r2
        a = rot + i * math.pi / n
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


def fx():
    n = 64
    save_rgba(os.path.join(FX, "puff.png"), (255, 255, 255), radial(n, 0.0, 1.6) * 0.9)
    save_rgba(os.path.join(FX, "sparkle.png"), (255, 255, 255), np.maximum(radial(n, 0.0, 6.0), 0))
    # sparkle cross
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.polygon([(32, 2), (36, 28), (62, 32), (36, 36), (32, 62), (28, 36), (2, 32), (28, 28)], fill=(255, 255, 255, 255))
    im = im.filter(ImageFilter.GaussianBlur(1.2)); im.save(os.path.join(FX, "sparkle.png"))
    # flake: 6-arm snowflake
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    for k in range(6):
        a = k * math.pi / 3
        x2, y2 = 32 + math.cos(a) * 28, 32 + math.sin(a) * 28
        d.line([(32, 32), (x2, y2)], fill=(255, 255, 255, 255), width=4)
        for t in (0.55, 0.8):
            bx, by = 32 + math.cos(a) * 28 * t, 32 + math.sin(a) * 28 * t
            for s in (-1, 1):
                d.line([(bx, by), (bx + math.cos(a + s * 0.8) * 7, by + math.sin(a + s * 0.8) * 7)], fill=(255, 255, 255, 255), width=3)
    im.filter(ImageFilter.GaussianBlur(0.6)).save(os.path.join(FX, "flake.png"))
    # stylised impact star (yellow with outline)
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.polygon(star_poly(32, 33, 30, 13), fill=(60, 30, 0, 255))
    d.polygon(star_poly(32, 32, 26, 11), fill=(255, 220, 60, 255))
    d.polygon(star_poly(29, 28, 10, 4), fill=(255, 250, 200, 255))
    im.save(os.path.join(FX, "star.png"))
    # ice shard
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.polygon([(32, 2), (46, 30), (34, 62), (20, 34)], fill=(190, 240, 255, 240))
    d.polygon([(32, 2), (38, 30), (34, 62)], fill=(240, 252, 255, 255))
    im.save(os.path.join(FX, "shard.png"))
    # confetti (4 frames as an animated strip)
    strip = Image.new("RGBA", (n * 4, n), (0, 0, 0, 0)); d = ImageDraw.Draw(strip)
    for f in range(4):
        w = int(24 * abs(math.cos(f * math.pi / 4))) + 4
        d.rectangle([f * n + 32 - w // 2, 20, f * n + 32 + w // 2, 44], fill=(255, 255, 255, 255))
    strip.save(os.path.join(FX, "confetti_strip.png"))
    # warning / direction / impact sprites for HUD
    im = Image.new("RGBA", (128, 128), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.polygon([(64, 6), (124, 118), (4, 118)], fill=(30, 10, 10, 255)); d.polygon([(64, 18), (112, 110), (16, 110)], fill=(255, 70, 50, 255))
    d.rectangle([58, 44, 70, 84], fill=(255, 255, 255, 255)); d.ellipse([57, 92, 71, 106], fill=(255, 255, 255, 255))
    im.save(os.path.join(UI, "warning.png"))
    for name, flip in (("arrow_right", False), ("arrow_left", True)):
        im = Image.new("RGBA", (128, 128), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
        d.polygon([(10, 40), (70, 40), (70, 12), (120, 64), (70, 116), (70, 88), (10, 88)], fill=(20, 30, 60, 255))
        d.polygon([(18, 48), (78, 48), (78, 30), (110, 64), (78, 98), (78, 80), (18, 80)], fill=(255, 210, 40, 255))
        if flip:
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
        im.save(os.path.join(UI, name + ".png"))


def medals():
    for name, c1, c2 in (("medal_gold", (255, 200, 40), (255, 240, 160)), ("medal_silver", (180, 190, 205), (240, 245, 250)), ("medal_bronze", (200, 120, 60), (240, 190, 140))):
        im = Image.new("RGBA", (128, 160), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
        d.polygon([(34, 0), (58, 0), (70, 60), (46, 60)], fill=(220, 50, 70, 255))
        d.polygon([(94, 0), (70, 0), (58, 60), (82, 60)], fill=(50, 110, 220, 255))
        d.ellipse([14, 44, 114, 144], fill=(40, 25, 10, 255))
        d.ellipse([18, 48, 110, 140], fill=c1 + (255,))
        d.ellipse([30, 60, 98, 128], fill=c2 + (255,))
        d.polygon(star_poly(64, 94, 26, 11), fill=c1 + (255,))
        im.save(os.path.join(UI, name + ".png"))


def course_maps():
    from track_defs import TRACKS, ORDER
    from track_geom import centreline
    pal = {"day": ((120, 190, 120), (240, 248, 255)), "ice": ((130, 190, 230), (235, 248, 255)), "volcano": ((90, 60, 60), (240, 220, 210)),
           "night": ((40, 50, 110), (180, 190, 240)), "forest": ((60, 120, 70), (230, 245, 230)), "station": ((120, 125, 135), (235, 238, 242)),
           "storm": ((140, 160, 185), (245, 248, 252)), "sky": ((130, 100, 200), (255, 235, 250))}
    meta = {}
    for tid in ORDER + ["parque_manobras"]:
        tr = TRACKS[tid]; cl = centreline(tr)
        p = cl["pos"][:, [0, 2]]
        lo = p.min(0); hi = p.max(0); span = max(hi - lo)
        S = 512; m = 48
        def mp(v):
            q = (v - lo) / span * (S - 2 * m) + m
            # centre the shorter axis
            off = ((S - 2 * m) - (hi - lo) / span * (S - 2 * m)) / 2
            return (float(q[0] + off[0]), float(q[1] + off[1]))
        bgc, snow = pal[tr["theme"]]
        im = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
        d.rounded_rectangle([4, 4, S - 4, S - 4], 36, fill=bgc + (235,), outline=(255, 255, 255, 255), width=6)
        pts = [mp(v) for v in p[::2]]
        d.line(pts, fill=(20, 30, 60, 255), width=26, joint="curve")
        d.line(pts, fill=snow + (255,), width=18, joint="curve")
        for f in tr["features"]:
            if f["type"] == "split":
                a = mp(p[int(f["s0"] / 2)]); b = mp(p[min(len(p) - 1, int(f["s1"] / 2))])
                d.line([a, b], fill=(255, 150, 40, 255), width=6)
            if f["type"] == "items":
                c = mp(p[int(f["s"] / 2)]); d.ellipse([c[0] - 9, c[1] - 9, c[0] + 9, c[1] + 9], fill=(255, 80, 80, 255), outline=(255, 255, 255, 255), width=3)
            if f["type"] == "landmark":
                c = mp(p[int(f["s"] / 2)]); d.polygon(star_poly(c[0], c[1], 12, 5), fill=(255, 220, 60, 255))
        s0 = mp(p[0]); s1 = mp(p[-1])
        d.ellipse([s0[0] - 14, s0[1] - 14, s0[0] + 14, s0[1] + 14], fill=(60, 220, 120, 255), outline=(255, 255, 255, 255), width=4)
        d.rectangle([s1[0] - 13, s1[1] - 13, s1[0] + 13, s1[1] + 13], fill=(30, 30, 30, 255), outline=(255, 255, 255, 255), width=4)
        d.line([s1, s0], fill=(255, 255, 255, 140), width=3)  # lift line
        im.save(os.path.join(MAPS, tid + ".png"))
        meta[tid] = {"lo": lo.tolist(), "span": float(span), "size": S, "margin": m}
    json.dump(meta, open(os.path.join(MAPS, "maps.json"), "w"), indent=1)


def atlas():
    """Packs FX + UI sprites into one atlas with JSON metadata (pivot, padding, frames)."""
    files = [os.path.join(FX, f) for f in sorted(os.listdir(FX)) if f.endswith(".png") and f != "atlas.png"] + \
            [os.path.join(UI, f) for f in sorted(os.listdir(UI)) if f.endswith(".png") and not f.startswith("atlas")]
    pad = 4; W = 1024; x = y = row_h = 0
    placed = {}
    ims = [(f, Image.open(f).convert("RGBA")) for f in files]
    for f, im in ims:
        w, h = im.size
        if x + w + pad > W:
            x = 0; y += row_h + pad; row_h = 0
        placed[f] = (x, y, w, h); x += w + pad; row_h = max(row_h, h)
    H = 1 << (y + row_h).bit_length()
    at = Image.new("RGBA", (W, H), (0, 0, 0, 0)); meta = {"size": [W, H], "padding": pad, "sprites": {}}
    for f, im in ims:
        px, py, w, h = placed[f]; at.paste(im, (px, py))
        nm = os.path.splitext(os.path.basename(f))[0]
        frames = 4 if "strip" in nm else 1
        meta["sprites"][nm] = {"rect": [px, py, w, h], "pivot": [0.5, 0.5], "frames": frames, "frame_size": [w // frames, h]}
    at.save(os.path.join(UI, "atlas.png"))
    json.dump(meta, open(os.path.join(UI, "atlas.json"), "w"), indent=1)


def logo():
    W, H = 1200, 420
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    # mountain emblem
    d.polygon([(80, 360), (300, 60), (420, 220), (500, 140), (680, 360)], fill=(30, 60, 140, 255))
    d.polygon([(300, 60), (360, 140), (330, 130), (300, 160), (270, 125), (245, 135)], fill=(255, 255, 255, 255))
    d.polygon([(500, 140), (545, 200), (520, 195), (500, 215), (480, 190)], fill=(255, 255, 255, 255))
    d.ellipse([560, 40, 700, 180], fill=(255, 200, 40, 255))
    try:
        f1 = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 120)
        f2 = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 84)
    except Exception:
        f1 = f2 = ImageFont.load_default()
    for dx, dy, col in ((8, 8, (10, 20, 60, 255)), (0, 0, (255, 255, 255, 255))):
        d.text((140 + dx, 190 + dy), "SNOWBOARD", font=f1, fill=col, stroke_width=10 if dx == 0 else 0, stroke_fill=(20, 40, 110, 255))
    for dx, dy, col in ((6, 6, (10, 20, 60, 255)), (0, 0, (255, 120, 40, 255))):
        d.text((420 + dx, 310 + dy), "LEGENDS 3D", font=f2, fill=col, stroke_width=8 if dx == 0 else 0, stroke_fill=(255, 255, 255, 255))
    im.save(os.path.join(UI, "logo.png"))
    ic = im.crop((60, 30, 720, 390)).resize((256, 140))
    icon = Image.new("RGBA", (256, 256), (20, 50, 130, 255)); icon.paste(ic, (0, 58), ic); icon.save(os.path.join(UI, "icon.png"))


if __name__ == "__main__":
    fx(); medals(); course_maps(); logo(); atlas()
    print("sprites ok")
