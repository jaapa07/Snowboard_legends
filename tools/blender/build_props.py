"""Builds props.glb (vegetation, structures, lift parts) and items.glb (10 power-ups, coin, stations).
Run: python tools/blender/build_props.py  (inside the bpy venv)"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
import bpy
from lib import *

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
P = math.pi


def C(h, r=0.6, m=0.0, e=None, es=1.0):
    return mat("M_" + h.strip("#"), hexc(h), r, m, hexc(e) if e else None, es)


def pine(name, h, r, layers, dark, light, snowy=True, trunk_h=None):
    parts = []
    th = trunk_h or h * 0.18
    parts.append(cyl(name + "_t", r * 0.12, th, (0, 0, th / 2), material=C("#5a3b26", 0.9), verts=8))
    for i in range(layers):
        t = i / layers
        z0 = th + (h - th) * t * 0.85
        rr = r * (1.0 - t * 0.75)
        hh = (h - th) / layers * 1.6
        parts.append(cyl(name + f"_c{i}", rr, hh, (0, 0, z0 + hh / 2), material=C(dark if i % 2 == 0 else light, 0.85), verts=9, r2=0.02))
        if snowy:
            parts.append(cyl(name + f"_s{i}", rr * 0.72, hh * 0.35, (0, 0, z0 + hh * 0.62), material=C("#f4f8ff", 0.5), verts=9, r2=rr * 0.25))
    o = join(parts, name)
    return o


def round_tree(name, h, r, leaf, trunk="#6b4a2e"):
    parts = [cyl(name + "_t", r * 0.14, h * 0.55, (0, 0, h * 0.275), material=C(trunk, 0.9), verts=8)]
    for i, (dx, dy, dz, s) in enumerate([(0, 0, h * 0.7, 1.0), (r * 0.5, 0.2, h * 0.6, 0.7), (-r * 0.45, -0.3, h * 0.62, 0.7), (0, 0, h * 0.92, 0.6)]):
        parts.append(sphere(name + f"_l{i}", r * s, (dx, dy, dz), material=C(leaf, 0.8), seg=10, rings=7))
    parts.append(sphere(name + "_snow", r * 0.75, (0, 0, h * 1.0), scale=(1, 1, 0.35), material=C("#f4f8ff", 0.5), seg=10, rings=6))
    return join(parts, name)


def giant_tree(name):
    parts = [cyl(name + "_t", 2.2, 26, (0, 0, 13), material=C("#4e3424", 0.95), verts=12, r2=1.4)]
    for k in range(5):
        a = k * 2 * P / 5
        parts.append(cyl(name + f"_root{k}", 0.7, 6, (math.cos(a) * 2.4, math.sin(a) * 2.4, 0.5), rot=(math.sin(a) * 1.2, -math.cos(a) * 1.2, 0), material=C("#4e3424", 0.95), verts=8, r2=0.2))
    for i in range(4):
        parts.append(cyl(name + f"_c{i}", 9 - i * 1.8, 7, (0, 0, 22 + i * 5), material=C("#1f5a3a" if i % 2 else "#2a6e46", 0.85), verts=11, r2=0.5))
        parts.append(cyl(name + f"_s{i}", (9 - i * 1.8) * 0.7, 2.2, (0, 0, 24.5 + i * 5), material=C("#f2f6ff", 0.5), verts=11, r2=2))
    return join(parts, name)


def build_props():
    objs = []
    # --- vegetation (6 trees, 4 bushes, 3 rocks, 4 snowbanks)
    objs.append(pine("tree_pine_a", 9, 2.6, 4, "#1e5b3c", "#25704a"))
    objs.append(pine("tree_pine_b", 14, 3.2, 5, "#174a33", "#1f5f40"))
    objs.append(pine("tree_pine_night", 10, 2.8, 4, "#15364a", "#1c4660"))
    objs.append(pine("tree_dead", 8, 1.6, 3, "#4a3a30", "#5a4636", snowy=True))
    objs.append(round_tree("tree_birch", 8, 2.2, "#cfa34a", trunk="#e8e2d6"))
    objs.append(giant_tree("tree_giant"))
    for i, (col, s) in enumerate([("#2b6a45", 1.0), ("#3b7a3a", 1.3), ("#1d4f39", 0.8), ("#6a8a9a", 1.1)]):
        parts = [sphere(f"b{i}_{k}", 0.9 * s, (dx * s, dy * s, 0.5 * s), material=C(col, 0.85), seg=9, rings=6)
                 for k, (dx, dy) in enumerate([(0, 0), (0.7, 0.3), (-0.6, 0.2), (0.1, -0.6)])]
        parts.append(sphere(f"b{i}_snow", 0.9 * s, (0, 0, 1.0 * s), scale=(1.3, 1.2, 0.35), material=C("#f4f8ff", 0.5), seg=9, rings=5))
        objs.append(join(parts, f"bush_{i}"))
    rock_specs = [("rock_grey", "#7a7f8c", (2.0, 1.6, 1.3)), ("rock_dark", "#3a302e", (2.6, 2.0, 1.8)), ("rock_ice", "#8fd0ee", (1.6, 1.4, 2.2))]
    for n, col, sc in rock_specs:
        r = sphere(n, 1.0, (0, 0, sc[2] * 0.4), scale=sc, material=C(col, 0.9), seg=7, rings=5)
        random.seed(hash(n) & 0xffff)
        for v in r.data.vertices:
            v.co *= 0.82 + random.random() * 0.36
        cap = sphere(n + "_cap", 1.0, (0, 0, sc[2] * 0.95), scale=(sc[0] * 0.7, sc[1] * 0.7, 0.3), material=C("#f4f8ff", 0.5), seg=7, rings=4)
        objs.append(join([r, cap], n))
    for i in range(4):
        sb = sphere(f"snowbank_{i}", 1.0, (0, 0, 0), scale=(3 + i, 1.6 + i * 0.3, 1.0 + i * 0.25), material=C("#eef4ff", 0.55), seg=12, rings=6)
        objs.append(sb)
    # --- fences (5)
    for i, (col, h) in enumerate([("#b06a3a", 1.1), ("#d23b3b", 0.9), ("#3a7ad2", 0.9), ("#8a8f99", 1.2), ("#e8b030", 1.0)]):
        parts = []
        for k in range(3):
            parts.append(cyl(f"f{i}p{k}", 0.08, h, (k * 2.0 - 2, 0, h / 2), material=C("#5a3b26"), verts=6))
        if i in (1, 2, 4):  # safety net / banner fences
            parts.append(box(f"f{i}net", (4.2, 0.04, h * 0.6), (0, 0, h * 0.6), material=C(col, 0.8)))
            for k in range(4):
                parts.append(box(f"f{i}st{k}", (0.45, 0.05, h * 0.6), (k * 1.0 - 1.5, 0.0, h * 0.6), material=C("#ffffff", 0.7)))
        else:
            for z in (0.35, 0.8):
                parts.append(box(f"f{i}r{z}", (4.2, 0.08, 0.12), (0, 0, z * h), material=C(col, 0.7, 0.4 if i == 3 else 0)))
        objs.append(join(parts, f"fence_{i}"))
    # --- signs (6): arrows L/R, jump, caution, items, lift
    sign_cols = [("sign_left", "#ff4d3a"), ("sign_right", "#ff4d3a"), ("sign_jump", "#ffb400"), ("sign_caution", "#ffd000"), ("sign_items", "#3ad27a"), ("sign_lift", "#3a8aff")]
    for n, col in sign_cols:
        parts = [cyl(n + "_p1", 0.08, 2.4, (-0.9, 0, 1.2), material=C("#cfd4dc", 0.4, 0.8), verts=6),
                 cyl(n + "_p2", 0.08, 2.4, (0.9, 0, 1.2), material=C("#cfd4dc", 0.4, 0.8), verts=6),
                 box(n + "_b", (2.4, 0.12, 1.2), (0, 0, 2.2), material=C(col, 0.5), bevel=0.04)]
        if n in ("sign_left", "sign_right"):
            s = -1 if n == "sign_left" else 1
            for k in range(3):
                parts.append(cyl(n + f"_ar{k}", 0.38, 0.06, (s * (k * 0.6 - 0.6), -0.08, 2.2), rot=(P / 2, 0, 0), material=C("#ffffff", 0.5), verts=3))
                parts[-1].rotation_euler = (P / 2, s * P / 2, 0)
        elif n == "sign_jump":
            parts.append(cyl(n + "_tri", 0.45, 0.06, (0, -0.08, 2.2), rot=(P / 2, 0, 0), material=C("#ffffff", 0.5), verts=3))
        elif n == "sign_caution":
            parts.append(box(n + "_ex", (0.16, 0.05, 0.6), (0, -0.08, 2.3), material=C("#1a1a1a")))
            parts.append(box(n + "_dot", (0.16, 0.05, 0.16), (0, -0.08, 1.85), material=C("#1a1a1a")))
        elif n == "sign_items":
            parts.append(sphere(n + "_orb", 0.35, (0, -0.15, 2.2), material=C("#ffffff", 0.3), seg=10, rings=6))
        else:
            parts.append(box(n + "_cab", (0.6, 0.05, 0.5), (0, -0.08, 2.15), material=C("#ffffff")))
        objs.append(join(parts, n))
    # --- flags / gates
    for i, col in enumerate(["#ff3a6e", "#2ab0ff", "#ffd23a"]):
        parts = [cyl(f"flag{i}p", 0.05, 2.0, (0, 0, 1.0), material=C("#eeeeee", 0.4, 0.5), verts=6),
                 box(f"flag{i}c", (0.9, 0.03, 0.6), (0.45, 0, 1.65), material=C(col, 0.7))]
        objs.append(join(parts, f"flag_{i}"))
    # --- lanterns (4)
    for i, (col, glow) in enumerate([("#ff5a3a", "#ffb070"), ("#ffd23a", "#fff0a0"), ("#3ad2ff", "#b0f0ff"), ("#d23aff", "#f0b0ff")]):
        parts = [cyl(f"ln{i}p", 0.07, 3.2, (0, 0, 1.6), material=C("#2a2a30", 0.5, 0.6), verts=6),
                 box(f"ln{i}arm", (0.9, 0.06, 0.06), (0.4, 0, 3.1), material=C("#2a2a30", 0.5, 0.6)),
                 sphere(f"ln{i}g", 0.3, (0.8, 0, 2.75), scale=(1, 1, 1.25), material=C(col, 0.4, 0, glow, 4.0), seg=10, rings=7)]
        objs.append(join(parts, f"lantern_{i}"))
    # --- rails (3)
    for i, (L, col) in enumerate([(10, "#c8ccd4"), (16, "#ff7a3a"), (8, "#5ad2ff")]):
        parts = [cyl(f"r{i}bar", 0.09, L, (0, 0, 0.9), rot=(P / 2, 0, 0), material=C(col, 0.3, 0.9), verts=10)]
        for k in range(int(L // 4) + 1):
            parts.append(cyl(f"r{i}l{k}", 0.06, 0.9, (0, -L / 2 + k * L / int(L // 4), 0.45), material=C("#555a66", 0.5, 0.8), verts=6))
        objs.append(join(parts, f"rail_{i}"))
    # --- ramps (4) kicker shapes
    for i, (w, l, h, col) in enumerate([(6, 5, 1.2, "#f2f6ff"), (8, 7, 1.8, "#e6eefc"), (4, 4, 1.0, "#c08850"), (10, 9, 2.4, "#f2f6ff")]):
        v = [(-w / 2, -l / 2, 0), (w / 2, -l / 2, 0), (w / 2, l / 2, 0), (-w / 2, l / 2, 0), (w / 2, l / 2, h), (-w / 2, l / 2, h)]
        f = [(0, 1, 2, 3), (0, 3, 5), (1, 4, 2), (0, 5, 4, 1), (3, 2, 4, 5)]
        o = mesh_from(f"ramp_{i}", v, [list(reversed(x)) for x in f], material=C(col, 0.6))
        objs.append(o)
    # --- bridges (3), tunnels (4), buildings (6)
    for i, (L, col) in enumerate([(16, "#8a5a32"), (24, "#6a6f7a"), (12, "#b03a3a")]):
        parts = [box(f"br{i}d", (6, L, 0.4), (0, 0, 0), material=C(col, 0.7)),
                 box(f"br{i}rl", (0.2, L, 1.0), (-3, 0, 0.7), material=C(col, 0.7)),
                 box(f"br{i}rr", (0.2, L, 1.0), (3, 0, 0.7), material=C(col, 0.7))]
        for k in range(int(L // 4)):
            parts.append(cyl(f"br{i}post{k}", 0.25, 8, (-3, -L / 2 + k * 4 + 2, -4), material=C("#4a3a30"), verts=6))
            parts.append(cyl(f"br{i}postr{k}", 0.25, 8, (3, -L / 2 + k * 4 + 2, -4), material=C("#4a3a30"), verts=6))
        objs.append(join(parts, f"bridge_{i}"))
    for i, (col, R) in enumerate([("#6a6f7a", 9), ("#4a3a30", 8), ("#8fd0ee", 10), ("#3a302e", 9)]):
        t = torus(f"tunnel_{i}", R, 1.2, (0, 0, 0), rot=(P / 2, 0, 0), material=C(col, 0.85), seg=20, cseg=6)
        t.scale = (1, 1, 1)
        objs.append(t)
    def house(n, w, d, h, wall, roof, chimney=True):
        parts = [box(n + "_w", (w, d, h), (0, 0, h / 2), material=C(wall, 0.8), bevel=0.05)]
        rv = [(-w / 2 - 0.4, -d / 2 - 0.4, h), (w / 2 + 0.4, -d / 2 - 0.4, h), (w / 2 + 0.4, d / 2 + 0.4, h), (-w / 2 - 0.4, d / 2 + 0.4, h), (0, -d / 2 - 0.4, h + w * 0.45), (0, d / 2 + 0.4, h + w * 0.45)]
        parts.append(mesh_from(n + "_r", rv, [(0, 1, 4), (2, 3, 5), (1, 2, 5, 4), (3, 0, 4, 5)], material=C(roof, 0.7)))
        sn = mesh_from(n + "_sn", [(a[0] * 1.02, a[1] * 1.02, a[2] + 0.15) for a in rv], [(1, 2, 5, 4), (3, 0, 4, 5)], material=C("#f4f8ff", 0.5))
        parts.append(sn)
        for k, x in enumerate((-w / 4, w / 4)):
            parts.append(box(n + f"_win{k}", (w * 0.18, 0.1, h * 0.25), (x, -d / 2 - 0.02, h * 0.6), material=C("#ffd98a", 0.3, 0, "#ffc860", 1.5)))
        parts.append(box(n + "_door", (w * 0.2, 0.1, h * 0.45), (0, -d / 2 - 0.02, h * 0.22), material=C("#4a2e1e")))
        if chimney:
            parts.append(box(n + "_ch", (0.6, 0.6, 1.6), (w * 0.25, 0, h + w * 0.3), material=C("#8a4a3a")))
        return join(parts, n)
    objs.append(house("building_chalet", 6, 5, 3.5, "#c08850", "#a0302a"))
    objs.append(house("building_cabin", 4.5, 4, 3, "#8a5a32", "#3a5a8a"))
    objs.append(house("building_shop", 7, 5, 4, "#e0d4c0", "#2a8a5a"))
    objs.append(house("building_station", 9, 6, 4.5, "#9aa3b0", "#d23a3a", chimney=False))
    objs.append(house("building_lodge", 10, 7, 5, "#6a4a32", "#2a3a5a"))
    objs.append(house("building_hut_metal", 5, 4, 3, "#7a8088", "#5a3a2a", chimney=False))
    # --- lift parts (tower, cabin variants x4, stations)
    tw = [cyl("tw_pole", 0.35, 18, (0, 0, 9), material=C("#9aa3b0", 0.4, 0.8), verts=10, r2=0.25),
          box("tw_arm", (6, 0.4, 0.4), (0, 0, 18), material=C("#9aa3b0", 0.4, 0.8)),
          cyl("tw_wheel1", 0.5, 0.2, (-2.6, 0, 17.6), rot=(P / 2, 0, 0), material=C("#333840", 0.5, 0.8), verts=12),
          cyl("tw_wheel2", 0.5, 0.2, (2.6, 0, 17.6), rot=(P / 2, 0, 0), material=C("#333840", 0.5, 0.8), verts=12)]
    objs.append(join(tw, "lift_tower"))
    for i, (col, accent) in enumerate([("#d23a3a", "#ffffff"), ("#3a8aff", "#ffd23a"), ("#ffd23a", "#2a2a30"), ("#3ad27a", "#ffffff")]):
        parts = [box(f"cab{i}b", (1.6, 1.6, 1.8), (0, 0, -2.4), material=C(col, 0.5), bevel=0.25, segs=2),
                 box(f"cab{i}w", (1.66, 1.2, 0.7), (0, 0, -2.1), material=C("#bfe6ff", 0.1, 0.2)),
                 box(f"cab{i}st", (1.7, 1.7, 0.18), (0, 0, -3.2), material=C(accent, 0.5)),
                 cyl(f"cab{i}hang", 0.06, 1.6, (0, 0, -0.7), material=C("#333840", 0.4, 0.8), verts=6),
                 box(f"cab{i}grip", (0.5, 0.3, 0.3), (0, 0, 0), material=C("#333840", 0.4, 0.8))]
        objs.append(join(parts, f"lift_cabin_{i}"))
    st = [box("ls_base", (10, 8, 0.6), (0, 0, 0.3), material=C("#9aa3b0", 0.6)),
          box("ls_roof", (11, 9, 0.5), (0, 0, 7), material=C("#d23a3a", 0.6), bevel=0.1),
          cyl("ls_wheel", 3.0, 0.5, (0, 0, 6.2), material=C("#333840", 0.4, 0.8), verts=24)]
    for x in (-4.5, 4.5):
        for y in (-3.5, 3.5):
            st.append(cyl(f"ls_col{x}{y}", 0.3, 6.6, (x, y, 3.6), material=C("#9aa3b0", 0.4, 0.8), verts=8))
    objs.append(join(st, "lift_station"))
    # gate arch (start/finish)
    arch = [cyl("ga_l", 0.4, 6, (-9, 0, 3), material=C("#2a2a30", 0.5, 0.5), verts=10),
            cyl("ga_r", 0.4, 6, (9, 0, 3), material=C("#2a2a30", 0.5, 0.5), verts=10),
            box("ga_b", (19, 0.5, 1.6), (0, 0, 6.2), material=C("#ff3a6e", 0.5), bevel=0.1),
            box("ga_c1", (2, 0.55, 1.6), (-6, 0, 6.2), material=C("#ffffff", 0.5)),
            box("ga_c2", (2, 0.55, 1.6), (6, 0, 6.2), material=C("#ffffff", 0.5))]
    objs.append(join(arch, "gate_arch"))
    # hazards: log and wagon
    lg = [cyl("log_body", 0.45, 6.0, (0, 0, 0.45), rot=(0, P / 2, 0), material=C("#6b4a2e", 0.9), verts=12),
          cyl("log_end1", 0.42, 0.05, (3.0, 0, 0.45), rot=(0, P / 2, 0), material=C("#c8a070", 0.9), verts=12),
          cyl("log_end2", 0.42, 0.05, (-3.0, 0, 0.45), rot=(0, P / 2, 0), material=C("#c8a070", 0.9), verts=12),
          sphere("log_snow", 0.5, (0, 0, 0.85), scale=(5.6, 0.8, 0.3), material=C("#f4f8ff", 0.5), seg=12, rings=5)]
    objs.append(join(lg, "log"))
    wg = [box("wg_body", (2.6, 7.0, 2.4), (0, 0, 1.9), material=C("#8a3a2a", 0.8, 0.3), bevel=0.1),
          box("wg_roof", (2.8, 7.2, 0.3), (0, 0, 3.2), material=C("#5a5f68", 0.6, 0.7), bevel=0.05),
          box("wg_snow", (2.7, 7.1, 0.25), (0, 0, 3.45), material=C("#f4f8ff", 0.5), bevel=0.1),
          box("wg_win", (2.65, 4.5, 0.8), (0, 0, 2.3), material=C("#2a3040", 0.2, 0.3)),
          box("wg_chassis", (2.2, 6.6, 0.4), (0, 0, 0.6), material=C("#2a2a30", 0.6, 0.6))]
    for y in (-2.4, 2.4):
        for x in (-1.0, 1.0):
            wg.append(cyl(f"wg_w{x}{y}", 0.45, 0.2, (x, y, 0.45), rot=(0, P / 2, 0), material=C("#2a2a30", 0.5, 0.8), verts=12))
    objs.append(join(wg, "wagon"))
    for o in objs:
        smooth(o, 35)
    return objs


def build_items():
    objs = []
    coin = [cyl("coin_body", 0.45, 0.12, (0, 0, 0), rot=(P / 2, 0, 0), material=C("#ffc21a", 0.25, 1.0, "#ff9a00", 0.4), verts=20),
            cyl("coin_star", 0.25, 0.14, (0, 0, 0), rot=(P / 2, 0, 0), material=C("#fff0a0", 0.2, 1.0), verts=5)]
    objs.append(join(coin, "coin"))
    # item station types: offensive (red), utility (blue)
    for n, col in (("station_offense", "#ff3a3a"), ("station_utility", "#3a9aff")):
        parts = [cyl(n + "_base", 1.6, 0.5, (0, 0, 0.25), material=C("#2a2a30", 0.5, 0.5), verts=16),
                 cyl(n + "_post", 0.25, 3.0, (0, 0, 1.75), material=C("#cfd4dc", 0.4, 0.8), verts=8),
                 box(n + "_box", (2.2, 2.2, 2.2), (0, 0, 4.2), material=C(col, 0.3, 0.1, col, 0.6), bevel=0.3, segs=3),
                 sphere(n + "_q", 0.5, (0, -1.15, 4.2), scale=(1, 0.3, 1), material=C("#ffffff", 0.3, 0, "#ffffff", 1.0), seg=12, rings=6)]
        objs.append(join(parts, n))
    # items
    objs.append(sphere("item_snowball", 0.45, material=C("#f6faff", 0.45), seg=14, rings=9))
    mine = [cyl("mine_b", 0.6, 0.25, material=C("#8fd0ee", 0.2, 0.1, "#4ab0ff", 0.6), verts=8),
            cyl("mine_sp", 0.15, 0.6, (0, 0, 0.3), material=C("#dff6ff", 0.1), verts=6, r2=0.0)]
    for k in range(6):
        a = k * P / 3
        mine.append(cyl(f"mine_s{k}", 0.1, 0.5, (math.cos(a) * 0.55, math.sin(a) * 0.55, 0.05), rot=(math.sin(a) * P / 2.2, -math.cos(a) * P / 2.2, 0), material=C("#dff6ff", 0.1), verts=5, r2=0))
    objs.append(join(mine, "item_icemine"))
    gust = [torus("gust_r1", 0.5, 0.08, material=C("#a0ffea", 0.3, 0, "#60ffd0", 2.0), seg=20, cseg=6),
            torus("gust_r2", 0.32, 0.06, (0, 0, 0.3), material=C("#a0ffea", 0.3, 0, "#60ffd0", 2.0), seg=16, cseg=6),
            cyl("gust_c", 0.12, 0.9, (0, 0, -0.2), material=C("#ffffff", 0.3, 0, "#ffffff", 1.0), verts=8, r2=0.0)]
    objs.append(join(gust, "item_gust"))
    objs.append(sphere("item_shield", 1.25, material=C("#7af0ff", 0.05, 0.0, "#5ad0ff", 0.8), seg=20, rings=12))
    peng = [sphere("pg_b", 0.45, (0, 0, 0.45), scale=(1, 0.9, 1.25), material=C("#1a1e2a", 0.6), seg=14, rings=9),
            sphere("pg_belly", 0.36, (0, -0.15, 0.42), scale=(0.9, 0.7, 1.1), material=C("#ffffff", 0.6), seg=12, rings=8),
            cyl("pg_beak", 0.1, 0.25, (0, -0.48, 0.65), rot=(P / 2, 0, 0), material=C("#ffa020", 0.5), verts=6, r2=0.0),
            sphere("pg_el", 0.07, (-0.14, -0.38, 0.8), material=C("#ffffff", 0.2), seg=8, rings=5),
            sphere("pg_er", 0.07, (0.14, -0.38, 0.8), material=C("#ffffff", 0.2), seg=8, rings=5),
            box("pg_scarf", (0.75, 0.7, 0.14), (0, 0, 0.62), material=C("#ff3a3a", 0.7), bevel=0.05),
            box("pg_fl", (0.25, 0.35, 0.06), (-0.15, -0.1, 0.02), material=C("#ffa020", 0.5)),
            box("pg_fr", (0.25, 0.35, 0.06), (0.15, -0.1, 0.02), material=C("#ffa020", 0.5))]
    objs.append(join(peng, "item_penguin"))
    fog = [sphere(f"fog{k}", 0.4 + k * 0.08, (math.cos(k * 2.1) * 0.4, math.sin(k * 2.1) * 0.4, k * 0.12), material=C("#c8b8e8", 0.9), seg=10, rings=6) for k in range(5)]
    objs.append(join(fog, "item_fog"))
    spring = [cyl("sp_base", 0.6, 0.15, (0, 0, 0.075), material=C("#3a3a44", 0.4, 0.8), verts=16),
              cyl("sp_top", 0.6, 0.15, (0, 0, 0.9), material=C("#ff3a6e", 0.4, 0.2), verts=16)]
    for k in range(5):
        spring.append(torus(f"sp_c{k}", 0.4, 0.06, (0, 0, 0.2 + k * 0.15), material=C("#cfd4dc", 0.3, 0.9), seg=14, cseg=5))
    objs.append(join(spring, "item_spring"))
    magnet = [torus("mg_u", 0.4, 0.14, rot=(P / 2, 0, 0), material=C("#e02a2a", 0.4, 0.3), seg=20, cseg=8),
              box("mg_tl", (0.3, 0.3, 0.25), (-0.4, 0, -0.1), material=C("#dfe3ea", 0.3, 0.9)),
              box("mg_tr", (0.3, 0.3, 0.25), (0.4, 0, -0.1), material=C("#dfe3ea", 0.3, 0.9))]
    for v in magnet[0].data.vertices:
        if v.co.z < -0.05:
            v.co.z = -0.05
    objs.append(join(magnet, "item_magnet"))
    wave = [mesh_from("wave", [(math.cos(a) * r, math.sin(a) * r, (0.6 if r > 1.0 else 0.0) + 0.3 * math.sin(a * 3)) for r in (0.5, 1.4) for a in [k * 2 * P / 24 for k in range(24)]],
                      [(k, (k + 1) % 24, 24 + (k + 1) % 24, 24 + k) for k in range(24)], material=C("#dff0ff", 0.4, 0, "#9ad0ff", 0.5))]
    objs.append(join(wave, "item_wave"))
    rep = [box("rp_box", (0.8, 0.6, 0.6), (0, 0, 0.3), material=C("#ffffff", 0.4), bevel=0.08),
           box("rp_cx", (0.5, 0.62, 0.14), (0, 0, 0.35), material=C("#3ad27a", 0.4)),
           box("rp_cz", (0.14, 0.62, 0.42), (0, 0, 0.35), material=C("#3ad27a", 0.4)),
           cyl("rp_h", 0.18, 0.08, (0, 0, 0.68), rot=(P / 2, 0, 0), material=C("#555a66", 0.4, 0.8), verts=10)]
    objs.append(join(rep, "item_repair"))
    for o in objs:
        smooth(o, 35)
    return objs


if __name__ == "__main__":
    reset()
    po = build_props()
    print("props tris", tri_count(po))
    save_blend(os.path.join(ROOT, "source_art", "blend", "props.blend"))
    export_glb(os.path.join(ROOT, "assets", "models", "props", "props.glb"))
    reset()
    io = build_items()
    print("items tris", tri_count(io))
    save_blend(os.path.join(ROOT, "source_art", "blend", "items.blend"))
    export_glb(os.path.join(ROOT, "assets", "models", "items", "items.glb"))
    print("OK")
