"""iOS / mobile app icons (opaque, as App Store requires) and launch image.
Composes the Cycles portrait of Niko (tools/blender/render_rider.py niko <png> victory 20 portrait 900)
over the game's mountain emblem on a sky gradient. Usage: python3 tools/gen_app_icons.py <niko_portrait.png>"""
import os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "ios")
SIZES = [1024, 180, 167, 152, 120, 87, 80, 76, 60, 58, 40]


def gradient(w, h, top, bot):
    g = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(g)
    for y in range(h):
        t = y / (h - 1)
        d.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
    return g


def master(portrait_path):
    N = 1024
    im = gradient(N, N, (60, 150, 240), (20, 50, 130)).convert("RGBA")
    d = ImageDraw.Draw(im)
    d.ellipse([640, 90, 900, 350], fill=(255, 205, 60, 255))                      # sun
    d.polygon([(-40, 1024), (330, 360), (520, 640), (650, 470), (1080, 1024)], fill=(28, 62, 150, 255))
    d.polygon([(330, 360), (420, 490), (380, 475), (330, 525), (285, 470), (250, 490)], fill=(255, 255, 255, 255))
    d.polygon([(650, 470), (720, 570), (685, 560), (650, 595), (615, 555)], fill=(255, 255, 255, 255))
    d.polygon([(-40, 1024), (-40, 860), (1080, 760), (1080, 1024)], fill=(236, 244, 255, 255))   # snow
    p = Image.open(portrait_path).convert("RGBA").resize((860, 860), Image.LANCZOS)
    sh = Image.new("RGBA", p.size, (0, 0, 0, 0))
    sh.putalpha(p.getchannel("A").point(lambda a: int(a * 0.45)))
    sh = sh.filter(ImageFilter.GaussianBlur(14))
    im.alpha_composite(sh, (100, 190))
    im.alpha_composite(p, (82, 150))
    return im.convert("RGB")   # no alpha channel (App Store rule)


def launch(icon):
    W, H = 2048, 2048
    im = gradient(W, H, (40, 110, 220), (15, 35, 100)).convert("RGBA")
    logo = Image.open(os.path.join(ROOT, "assets", "sprites", "ui", "logo.png")).convert("RGBA")
    logo = logo.resize((1440, 504), Image.LANCZOS)
    im.alpha_composite(logo, ((W - 1440) // 2, 700))
    return im.convert("RGB")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    m = master(sys.argv[1])
    for s in SIZES:
        m.resize((s, s), Image.LANCZOS).save(os.path.join(OUT, f"icon_{s}.png"))
    launch(m).save(os.path.join(OUT, "launch_2048.png"))
    print("icons", SIZES)
