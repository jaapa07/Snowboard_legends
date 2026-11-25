"""Draws the UI padlock icons (locked / unlocked) as 128 px RGBA PNGs with Pillow (4x supersampled).
Usage: python3 tools/gen_ui_icons.py"""
import os
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "sprites", "ui")
S = 4
N = 128 * S

def lock(open_: bool) -> Image.Image:
    im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    o = (16, 26, 60, 255)            # outline
    body = (255, 196, 48, 255) if not open_ else (120, 230, 140, 255)
    shine = (255, 236, 150, 255) if not open_ else (190, 255, 200, 255)
    w = 14 * S
    # shackle
    sx0, sx1, sy0, sy1 = 34 * S, 94 * S, 10 * S, 74 * S
    if open_:
        sx0, sx1, sy0, sy1 = 58 * S, 118 * S, 4 * S, 68 * S
    d.arc((sx0, sy0, sx1, sy1), 180, 360, fill=o, width=w + 8 * S)
    d.arc((sx0 + 4 * S, sy0 + 4 * S, sx1 - 4 * S, sy1 - 4 * S), 180, 360, fill=(200, 210, 230, 255), width=w - 2 * S)
    my = (sy0 + sy1) // 2
    for x in ((sx0, sx0 + w + 8 * S) if not open_ else (sx1 - w - 8 * S, sx1),):
        pass
    d.rectangle((sx0, my, sx0 + w + 4 * S, 64 * S), fill=o)
    d.rectangle((sx1 - w - 4 * S, my, sx1, 64 * S if not open_ else my + 10 * S), fill=o)
    d.rectangle((sx0 + 4 * S, my, sx0 + w, 64 * S), fill=(200, 210, 230, 255))
    d.rectangle((sx1 - w, my, sx1 - 4 * S, (64 * S) if not open_ else my + 6 * S), fill=(200, 210, 230, 255))
    # body
    d.rounded_rectangle((18 * S, 56 * S, 110 * S, 122 * S), radius=16 * S, fill=o)
    d.rounded_rectangle((24 * S, 62 * S, 104 * S, 116 * S), radius=12 * S, fill=body)
    d.rounded_rectangle((30 * S, 66 * S, 98 * S, 76 * S), radius=5 * S, fill=shine)
    # keyhole
    d.ellipse((56 * S, 78 * S, 72 * S, 94 * S), fill=o)
    d.polygon([(59 * S, 90 * S), (69 * S, 90 * S), (72 * S, 108 * S), (56 * S, 108 * S)], fill=o)
    return im.resize((128, 128), Image.LANCZOS)

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    lock(False).save(os.path.join(OUT, "lock.png"))
    lock(True).save(os.path.join(OUT, "unlock.png"))
    print("wrote lock.png, unlock.png")
