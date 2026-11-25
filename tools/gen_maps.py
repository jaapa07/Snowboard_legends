"""Illustrated course maps: the top-down Cycles render of each authored course (tools/blender/render_maps.py)
with a hand-styled overlay drawn from the course data: racing line with the split routes, start and finish,
item stations (red = offensive, blue = utility), lift line, landmarks and vegetation.
Usage: python3 tools/gen_maps.py <raw_render_dir>"""
import os, sys, json, math
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "sprites", "maps")
DATA = os.path.join(ROOT, "assets", "data", "tracks")
TRACKS = ["vale_pinheiros", "lago_cristal", "pico_vulcanico", "festival_boreal", "floresta_gigante", "estacao_abandonada",
          "tempestade_polar", "cume_celestial", "parque_manobras"]
S = 2          # supersampling of the overlay
N = 768        # card width (3:2 landscape)
NH = 512


def mapper(cam, n, nh):
    c, s_ = math.cos(cam["rot"]), math.sin(cam["rot"])
    sw, sh = cam["span"], cam["span"] * cam["h"] / cam["w"]
    def f(gx, gz):  # Godot (x, z) -> Blender (x, -z) -> camera frame -> pixel
        dx, dy = gx - cam["cx"], -gz - cam["cy"]
        u = (dx * c + dy * s_) / sw + 0.5
        v = 0.5 - (-dx * s_ + dy * c) / sh
        return (u * n, v * nh)
    return f


def star(d, c, r, fill, outline):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.45
        pts.append((c[0] + math.cos(a) * rr, c[1] + math.sin(a) * rr))
    d.polygon(pts, fill=fill, outline=outline, width=max(1, int(r * 0.18)))


def build(tid, raw):
    cam = json.load(open(os.path.join(raw, f"{tid}.json")))
    data = json.load(open(os.path.join(DATA, f"{tid}.json")))
    n = N * S
    nh = NH * S
    base = Image.open(os.path.join(raw, f"{tid}.png")).convert("RGB").resize((n, nh), Image.LANCZOS)
    # snow grading: lift the greys toward a cold paper white so the relief reads like an illustrated chart
    from PIL import ImageEnhance, ImageOps
    base = ImageEnhance.Brightness(ImageEnhance.Contrast(base).enhance(1.25)).enhance(1.18)
    tint = Image.new("RGB", (n, nh), (214, 228, 250))
    base = Image.blend(base, ImageOps.autocontrast(base, cutoff=1), 0.5)
    base = Image.blend(base, tint, 0.22).convert("RGBA")
    m = mapper(cam, n, nh)
    ov = Image.new("RGBA", (n, nh), (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    # vegetation as small illustrated trees/bushes (positions come from the course data)
    for v in data.get("vegetation", []):
        x, y = m(v["pos"][0], v["pos"][2])
        k = v["kind"]
        r = (7 if "tree" in k else 5) * S * float(v.get("scale", 1.0)) ** 0.5
        col = (40, 120, 85, 235) if "tree" in k and "dead" not in k and "birch" not in k else ((150, 120, 90, 230) if "dead" in k else (90, 160, 95, 230))
        d.ellipse((x - r + S, y - r + 2 * S, x + r + S, y + r + 2 * S), fill=(0, 0, 0, 60))
        d.ellipse((x - r, y - r, x + r, y + r), fill=col, outline=(20, 50, 40, 200), width=S)
    # racing line (centre) with a white casing, routes around split dividers in orange
    pts = [m(s["p"][0], s["p"][2]) for s in data["samples"][::2]]
    d.line(pts, fill=(255, 255, 255, 230), width=11 * S, joint="curve")
    d.line(pts, fill=(60, 130, 230, 255), width=6 * S, joint="curve")
    samples = data["samples"]
    ds = float(data["ds"])
    for f in data["features"]:
        if f["type"] == "split":
            i0, i1 = int(f["s0"] / ds), min(len(samples) - 1, int(f["s1"] / ds))
            for side in (-1, 1):
                rp = []
                for smp in samples[i0:i1 + 1:2]:
                    off = side * (float(f["div"]) * 0.5 + smp["w"] * 0.25)
                    rp.append(m(smp["p"][0] + smp["r"][0] * off, smp["p"][2] + smp["r"][2] * off))
                d.line(rp, fill=(255, 160, 40, 255), width=4 * S, joint="curve")
    # lift line (dashed)
    lb, lt = data["lift"]["bottom"], data["lift"]["top"]
    a, b = m(lb[0], lb[2]), m(lt[0], lt[2])
    L = math.dist(a, b)
    for k in range(0, int(L), 14 * S):
        t0, t1 = k / L, min(1.0, (k + 7 * S) / L)
        d.line((a[0] + (b[0] - a[0]) * t0, a[1] + (b[1] - a[1]) * t0, a[0] + (b[0] - a[0]) * t1, a[1] + (b[1] - a[1]) * t1), fill=(40, 40, 50, 220), width=3 * S)
    # item stations
    for f in data["features"]:
        if f["type"] == "items":
            i = min(len(samples) - 1, int(float(f["s"]) / ds))
            smp = samples[i]
            for side, col in ((-1, (230, 60, 60, 255)), (1, (60, 120, 240, 255))):
                off = side * smp["w"] * 0.3
                x, y = m(smp["p"][0] + smp["r"][0] * off, smp["p"][2] + smp["r"][2] * off)
                d.rounded_rectangle((x - 7 * S, y - 7 * S, x + 7 * S, y + 7 * S), radius=3 * S, fill=col, outline=(255, 255, 255, 255), width=2 * S)
    # landmarks
    for f in data["features"]:
        if f["type"] == "landmark" and "pos" in f:
            star(d, m(f["pos"][0], f["pos"][2]), 11 * S, (255, 210, 60, 255), (60, 40, 10, 255))
    # start (green) and finish (checkered flag)
    sx, sy = m(samples[0]["p"][0], samples[0]["p"][2])
    d.ellipse((sx - 11 * S, sy - 11 * S, sx + 11 * S, sy + 11 * S), fill=(60, 210, 110, 255), outline=(255, 255, 255, 255), width=3 * S)
    fi = min(len(samples) - 1, int(float(data["finish_s"]) / ds))
    fx, fy = m(samples[fi]["p"][0], samples[fi]["p"][2])
    q = 5 * S
    for r_ in range(-2, 2):
        for c_ in range(-2, 2):
            col = (20, 20, 20, 255) if (r_ + c_) % 2 == 0 else (255, 255, 255, 255)
            d.rectangle((fx + c_ * q, fy + r_ * q, fx + (c_ + 1) * q, fy + (r_ + 1) * q), fill=col)
    d.rectangle((fx - 2 * q, fy - 2 * q, fx + 2 * q, fy + 2 * q), outline=(255, 255, 255, 255), width=2 * S)
    img = Image.alpha_composite(base, ov)
    # rounded card with a soft inner vignette
    mask = Image.new("L", (n, nh), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, n - 1, nh - 1), radius=36 * S, fill=255)
    vig = Image.new("RGBA", (n, nh), (0, 0, 0, 0))
    ImageDraw.Draw(vig).rounded_rectangle((0, 0, n - 1, nh - 1), radius=36 * S, outline=(10, 20, 50, 120), width=18 * S)
    vig = vig.filter(ImageFilter.GaussianBlur(10 * S))
    img = Image.alpha_composite(img, vig)
    ImageDraw.Draw(img).rounded_rectangle((0, 0, n - 1, nh - 1), radius=36 * S, outline=(255, 255, 255, 255), width=4 * S)
    out = Image.new("RGBA", (n, nh), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    out.resize((N, NH), Image.LANCZOS).save(os.path.join(OUT, f"{tid}.png"))
    print("map", tid)


if __name__ == "__main__":
    raw = sys.argv[1]
    for t in TRACKS:
        build(t, raw)
