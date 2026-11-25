"""Builds the 12 boards (unique outline, kick, sidecut, bindings and deck graphics). Output: assets/models/boards/boards.glb
Each board is a root object named board_<id>; long axis = Blender -Y (travel), feet at y = -0.24 / +0.24."""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import bpy
from mathutils import Vector
from lib import *

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
P = math.pi

BOARDS = {
    # id: length, width, nose shape (round|pointed|twin|swallow|square), sidecut, kick, colors (deck, base, accent), graphic
    "starter": (1.48, 0.27, "round", 0.010, 0.07, "#ff7a1a", "#2a2a30", "#ffffff", "stripes"),
    "carver":  (1.60, 0.26, "pointed", 0.022, 0.06, "#1a5ad2", "#ffffff", "#ffd23a", "chevrons"),
    "rocket":  (1.66, 0.27, "pointed", 0.008, 0.05, "#d21a2a", "#1a1a22", "#ffb400", "flames"),
    "float":   (1.56, 0.30, "round", 0.012, 0.09, "#5ad2ff", "#ffffff", "#ffffff", "clouds"),
    "grip":    (1.52, 0.28, "square", 0.025, 0.06, "#3a3a44", "#ffd23a", "#3ad27a", "teeth"),
    "twin":    (1.50, 0.28, "twin", 0.014, 0.08, "#ffd23a", "#d23a8a", "#1a1a22", "dots"),
    "powder":  (1.62, 0.29, "swallow", 0.010, 0.10, "#ffffff", "#3a7aff", "#3a7aff", "snowflake"),
    "rail":    (1.46, 0.27, "twin", 0.012, 0.08, "#8a8f99", "#1a1a22", "#ff3a6e", "bolts"),
    "alpine":  (1.68, 0.24, "pointed", 0.024, 0.04, "#e0e6f0", "#d23a3a", "#1a5ad2", "mountain"),
    "aurora":  (1.58, 0.28, "round", 0.016, 0.07, "#2a1a5a", "#3ad2b0", "#7af0ff", "aurora"),
    "comet":   (1.62, 0.27, "pointed", 0.015, 0.06, "#1a1a3a", "#ffd23a", "#ffd23a", "stars"),
    "legend":  (1.64, 0.28, "swallow", 0.018, 0.07, "#ffcc33", "#1a1a22", "#ff3a3a", "crown"),
}


def C(h, r=0.4, m=0.0, e=None, es=1.0):
    return mat("B_" + h.strip("#") + f"_{int(r*10)}{int(m*10)}", hexc(h), r, m, hexc(e) if e else None, es)


def outline(L, W, nose, sidecut, n=48):
    """Half-outline points (x>=0) from tail (y=+L/2) to nose (y=-L/2)."""
    pts = []
    hl = L / 2
    for i in range(n + 1):
        t = i / n
        y = hl - t * L
        u = abs(y) / hl  # 0 centre .. 1 ends
        w = W / 2 - sidecut * (1 - u * u) * 1.0
        end_zone = 0.82
        if u > end_zone:
            e = (u - end_zone) / (1 - end_zone)
            front = y < 0
            shape = nose if front else ("round" if nose in ("pointed",) else nose)
            if shape == "round" or shape == "twin":
                w *= math.sqrt(max(0.0, 1 - e * e))
            elif shape == "pointed":
                w *= (1 - e) ** 0.8 if front else math.sqrt(max(0.0, 1 - e * e))
            elif shape == "square":
                w *= 1 - e ** 6 * 0.6
            elif shape == "swallow":
                w *= math.sqrt(max(0.0, 1 - e * e)) if front else (1 - 0.15 * e)
        pts.append((max(w, 0.004), y))
    return pts


def kick_z(y, L, kick):
    u = abs(y) / (L / 2)
    if u < 0.72:
        return 0.0
    e = (u - 0.72) / 0.28
    return kick * e * e


def board_mesh(bid, spec):
    L, W, nose, sc, kick, deck, base, acc, gfx = spec
    half = outline(L, W, nose, sc)
    rows = []
    T = 0.022
    verts, faces, fm = [], [], []
    for (w, y) in half:
        z = kick_z(y, L, kick)
        row = []
        for xf in (-1.0, -0.5, 0.0, 0.5, 1.0):
            x = w * xf
            if nose == "swallow" and y > L / 2 * 0.86 and abs(xf) < 0.01:
                yy = y - (y - L / 2 * 0.86) * 0.7
            else:
                yy = y
            row.append(len(verts)); verts.append((x, yy, z + T))
        for xf in (-1.0, -0.5, 0.0, 0.5, 1.0):
            row.append(len(verts)); verts.append((w * xf, y, z))
        rows.append(row)
    for i in range(len(rows) - 1):
        a, b = rows[i], rows[i + 1]
        for j in range(4):  # top deck
            faces.append((a[j], a[j + 1], b[j + 1], b[j])); fm.append(0)
            faces.append((b[5 + j], b[6 + j], a[6 + j], a[5 + j])); fm.append(1)
        faces.append((a[0], b[0], b[5], a[5])); fm.append(2)  # edges
        faces.append((a[9], b[9], b[4], a[4])); fm.append(2)
    faces.append(tuple(rows[0][k] for k in (0, 1, 2, 3, 4)) ); fm.append(2)
    faces.append(tuple(rows[-1][k] for k in (4, 3, 2, 1, 0))); fm.append(2)
    ob = mesh_from("board_" + bid, verts, faces, mats=[C(deck, 0.35), C(base, 0.3), C("#cfd4dc", 0.3, 0.9)], face_mats=fm)
    smooth(ob, 30)
    return ob


def decal(name, pts, z, material):
    v = [(x, y, z) for x, y in pts]
    return mesh_from(name, v, [tuple(range(len(v)))], material=material)


def graphics(bid, spec):
    L, W, nose, sc, kick, deck, base, acc, gfx = spec
    z = 0.0235
    m = C(acc, 0.4)
    m2 = C(base, 0.4)
    parts = []
    hw = W / 2 - 0.03
    if gfx == "stripes":
        for k in range(3):
            y0 = -0.55 + k * 0.08
            parts.append(decal(f"{bid}_g{k}", [(-hw, y0), (hw, y0), (hw, y0 + 0.04), (-hw, y0 + 0.04)], z, m))
    elif gfx == "chevrons":
        for k in range(4):
            y0 = -0.5 + k * 0.1
            parts.append(decal(f"{bid}_g{k}", [(-hw, y0 + 0.08), (0, y0), (hw, y0 + 0.08), (hw, y0 + 0.12), (0, y0 + 0.04), (-hw, y0 + 0.12)], z, m))
    elif gfx == "flames":
        for k in range(5):
            x = -hw + k * (2 * hw / 4)
            parts.append(decal(f"{bid}_g{k}", [(x - 0.03, -0.1), (x + 0.03, -0.1), (x + 0.01, -0.45 - 0.05 * (k % 2)), (x - 0.0, -0.55 + 0.06 * (k % 3))], z, m))
        parts.append(decal(f"{bid}_band", [(-hw, -0.1), (hw, -0.1), (hw, 0.0), (-hw, 0.0)], z, m))
    elif gfx in ("clouds", "dots", "stars", "snowflake", "bolts"):
        import random
        random.seed(len(bid) * 31 + ord(bid[0]))
        for k in range(9):
            cx = (random.random() - 0.5) * 1.6 * hw
            cy = (random.random() - 0.5) * (L * 0.62)
            if abs(cy) < 0.32 and abs(cy) > 0.16:
                cy += 0.18
            r = 0.025 + random.random() * 0.03
            nseg = {"clouds": 10, "dots": 12, "stars": 10, "snowflake": 12, "bolts": 4}[gfx]
            pts = []
            for i in range(nseg):
                a = 2 * P * i / nseg
                rr = r * (0.45 if gfx in ("stars", "snowflake") and i % 2 else 1.0)
                if gfx == "clouds":
                    rr = r * (1.0 + 0.25 * math.sin(a * 3))
                pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr * (1.6 if gfx == "bolts" else 1.0)))
            parts.append(decal(f"{bid}_g{k}", pts, z, m))
    elif gfx == "teeth":
        for k in range(8):
            y0 = -0.6 + k * 0.05
            parts.append(decal(f"{bid}_g{k}", [(-hw, y0), (-hw + 0.06, y0 + 0.025), (-hw, y0 + 0.05)], z, m))
            parts.append(decal(f"{bid}_h{k}", [(hw, y0 + 0.05), (hw - 0.06, y0 + 0.025), (hw, y0)], z, m))
    elif gfx == "mountain":
        parts.append(decal(f"{bid}_g0", [(-hw, -0.15), (-0.03, -0.45), (0.03, -0.38), (0.08, -0.48), (hw, -0.15)], z, m))
        parts.append(decal(f"{bid}_g1", [(-0.06, -0.4), (-0.03, -0.45), (0.0, -0.41)], z + 0.0005, C("#ffffff", 0.4)))
    elif gfx == "aurora":
        for k in range(3):
            pts = [(-hw + i * (2 * hw / 7), -0.45 + k * 0.07 + 0.03 * math.sin(i * 1.3 + k)) for i in range(8)]
            pts += [(x, y + 0.035) for x, y in reversed(pts)]
            parts.append(decal(f"{bid}_g{k}", pts, z, C(["#7af0ff", "#3ad2b0", "#b07aff"][k], 0.4, 0, ["#7af0ff", "#3ad2b0", "#b07aff"][k], 0.8)))
    elif gfx == "crown":
        parts.append(decal(f"{bid}_g0", [(-0.09, -0.3), (0.09, -0.3), (0.09, -0.42), (0.05, -0.36), (0.0, -0.46), (-0.05, -0.36), (-0.09, -0.42)], z, m))
        parts.append(decal(f"{bid}_g1", [(-hw, -0.52), (hw, -0.52), (hw, -0.5), (-hw, -0.5)], z, m2))
    for p in parts:
        for poly in p.data.polygons:
            pass
    return parts


def bindings(bid, acc):
    parts = []
    for k, y in enumerate((-0.24, 0.24)):
        ang = (0.25 if y < 0 else -0.1)
        b = box(f"{bid}_bind{k}", (0.24, 0.16, 0.025), (0, y, 0.035), rot=(0, 0, ang), material=C("#2a2a30", 0.5), bevel=0.01)
        hb = box(f"{bid}_hb{k}", (0.2, 0.025, 0.16), (0.0, y, 0.1), rot=(0.25, 0, ang), material=C("#2a2a30", 0.5), bevel=0.01)
        hb.location = Vector((0, y, 0.1)) + Vector((math.sin(-ang) * -0.0, 0, 0))
        hb.location.x = -0.09
        hb.rotation_euler = (0, -0.25, ang)
        hb.scale = (1, 1, 1)
        hb.data.transform(__import__("mathutils").Matrix.Rotation(P / 2, 4, "Z"))
        s1 = box(f"{bid}_s{k}", (0.03, 0.2, 0.02), (0.03, y, 0.12), rot=(0, 0, ang), material=C(acc, 0.5))
        parts += [b, hb, s1]
    return parts


def build():
    reset()
    roots = []
    for bid, spec in BOARDS.items():
        ob = board_mesh(bid, spec)
        g = graphics(bid, spec)
        bd = bindings(bid, spec[7])
        full = join([ob] + g + bd, "board_" + bid)
        smooth(full, 30)
        print(bid, "tris", tri_count([full]))
        roots.append(full)
    save_blend(os.path.join(ROOT, "source_art", "blend", "boards.blend"))
    export_glb(os.path.join(ROOT, "assets", "models", "boards", "boards.glb"))
    print("OK")


if __name__ == "__main__":
    build()
